#!/usr/bin/env python3
"""Local unsigned portable bundles with checked, transactional ownership."""

import argparse
import gzip
import hashlib
import io
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import stat
import subprocess
import sys
import tarfile
import tempfile
REPOSITORY = Path(__file__).resolve().parent.parent
RECEIPT = ".modus-install-manifest"
MAX_MANIFEST = 4 * 1024 * 1024
MAX_FILES = 10000
MAX_BYTES = 64 * 1024 * 1024 * 1024


def fail(message):
    raise ValueError(message)


def local_path(value):
    if not value or "\x00" in value or ".." in Path(value).parts:
        fail("invalid path: empty paths and parent traversal are forbidden")
    path = Path(os.path.abspath(value))
    safe_components(path)
    return path


def safe_components(path):
    for part in (*reversed(path.parents), path):
        if part.is_symlink():
            fail(f"symlink path is forbidden: {part}")
        if part != path and part.exists() and not part.is_dir():
            fail(f"path parent is not a directory: {part}")


def regular(path):
    safe_components(path)
    if not stat.S_ISREG(path.lstat().st_mode):
        fail(f"regular file required: {path}")


def version_value(value):
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._+\-]{0,127}", value):
        fail("invalid version: use 1-128 ASCII letters, digits, dots, +, - or _")
    return value

def zstd_archive(path):
    return path.name.endswith((".tar.zst", ".tzst", ".zst"))


def require_zstd():
    if shutil.which("zstd") is None:
        fail("zstd executable is required for .tar.zst archives")


def compress_zstd(source, destination):
    require_zstd()
    with destination.open("wb") as output:
        result = subprocess.run(
            [
                "zstd",
                "--quiet",
                "--no-progress",
                "--no-check",
                "--threads=1",
                "-19",
                "--stdout",
                str(source),
            ],
            stdout=output,
            stderr=subprocess.PIPE,
            check=False,
        )
    if result.returncode:
        fail(result.stderr.decode("utf-8", errors="replace").strip() or "zstd failed")


def decompress_zstd(source, destination):
    require_zstd()
    with destination.open("wb") as output:
        result = subprocess.run(
            [
                "zstd",
                "--quiet",
                "--no-progress",
                "--decompress",
                "--stdout",
                str(source),
            ],
            stdout=output,
            stderr=subprocess.PIPE,
            check=False,
        )
    if result.returncode:
        fail(
            result.stderr.decode("utf-8", errors="replace").strip()
            or "zstd decompression failed"
        )


def relative_path(value):
    if not isinstance(value, str) or not value or "\\" in value or "\x00" in value:
        fail("invalid manifest/archive path")
    parts = value.split("/")
    if any(part in ("", ".", "..") for part in parts):
        fail(f"unsafe manifest/archive path: {value!r}")
    if str(PurePosixPath(value)) != value:
        fail(f"noncanonical path: {value!r}")
    return value


def digest(path):
    value = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            value.update(chunk)
    return value.hexdigest()


def encoded(value):
    return (
        json.dumps(value, ensure_ascii=False, sort_keys=True, indent=2) + "\n"
    ).encode("utf-8")


def no_duplicate_keys(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            fail(f"duplicate JSON key: {key}")
        result[key] = value
    return result


def decode(data):
    return json.loads(data, object_pairs_hook=no_duplicate_keys)


def inventory(data):
    value = decode(data)
    if not isinstance(value, dict) or set(value) != {
        "schema_version",
        "product",
        "version",
        "platform",
        "files",
    }:
        fail("invalid manifest schema; legacy installs require manual migration")
    if (
        type(value["schema_version"]) is not int
        or value["schema_version"] != 1
        or value["product"] != "MODUS"
        or value["platform"] != "linux-x86_64"
    ):
        fail("unsupported portable manifest")
    if not isinstance(value["version"], str):
        fail("invalid manifest version")
    version_value(value["version"])
    entries = value["files"]
    if not isinstance(entries, list) or not 3 <= len(entries) <= MAX_FILES:
        fail("invalid owned-file inventory")
    result = {}
    for entry in entries:
        if not isinstance(entry, dict) or set(entry) != {
            "path",
            "bytes",
            "sha256",
            "mode",
        }:
            fail("invalid owned-file record")
        path = relative_path(entry["path"])
        if path not in (
            "bin/modus",
            "bin/modus.pck",
            "LICENSE",
        ) and not path.startswith("licenses/"):
            fail(f"unexpected owned-file path: {path}")
        if path in result:
            fail(f"duplicate owned-file path: {path}")
        expected_mode = 0o755 if path == "bin/modus" else 0o644
        if type(entry["mode"]) is not int or entry["mode"] != expected_mode:
            fail(f"invalid owned-file mode: {path}")
        if type(entry["bytes"]) is not int or not 0 <= entry["bytes"] <= MAX_BYTES:
            fail(f"invalid owned-file size: {path}")
        if not isinstance(entry["sha256"], str) or not re.fullmatch(
            r"[0-9a-f]{64}", entry["sha256"]
        ):
            fail(f"invalid owned-file hash: {path}")
        result[path] = entry
    for required in ("bin/modus", "bin/modus.pck", "LICENSE"):
        if required not in result or not result[required]["bytes"]:
            fail(f"required nonempty owned file missing: {required}")
    if sum(entry["bytes"] for entry in entries) > MAX_BYTES:
        fail("portable payload exceeds size limit")
    for path in result:
        if any(str(parent) in result for parent in PurePosixPath(path).parents):
            fail("owned file/directory collision")
    return value, result


def checked_bytes(path):
    regular(path)
    if path.stat().st_size > MAX_MANIFEST:
        fail(f"metadata exceeds size limit: {path}")
    return path.read_bytes()


def check_payload(root, entries):
    safe_components(root)
    if not root.is_dir():
        fail(f"installation directory missing: {root}")
    for name, entry in entries.items():
        path = root / name
        regular(path)
        info = path.stat()
        if (
            info.st_size != entry["bytes"]
            or stat.S_IMODE(info.st_mode) != entry["mode"]
            or digest(path) != entry["sha256"]
        ):
            fail(f"integrity check failed: {name}")


def installed(prefix):
    root = prefix / "modus"
    receipt_path = prefix / RECEIPT
    if not receipt_path.exists() and not receipt_path.is_symlink():
        if root.exists() or root.is_symlink():
            fail("ownership receipt missing; legacy installs require manual migration")
        return None
    data = checked_bytes(receipt_path)
    try:
        receipt = decode(data)
    except (ValueError, UnicodeError):
        fail("invalid ownership receipt; legacy installs require manual migration")
    if (
        not isinstance(receipt, dict)
        or set(receipt) != {"schema_version", "product", "manifest_sha256"}
        or type(receipt["schema_version"]) is not int
        or receipt["schema_version"] != 1
        or receipt["product"] != "MODUS"
    ):
        fail("invalid ownership receipt; legacy installs require manual migration")
    manifest_data = checked_bytes(root / "MANIFEST")
    if hashlib.sha256(manifest_data).hexdigest() != receipt["manifest_sha256"]:
        fail("ownership manifest integrity check failed")
    _, entries = inventory(manifest_data)
    check_payload(root, entries)
    if stat.S_IMODE((root / "MANIFEST").stat().st_mode) != 0o644:
        fail("ownership manifest mode changed")
    return entries


def package(args):
    version = version_value(args.version)
    source = local_path(args.artifact_dir)
    output = local_path(args.output)
    if not source.is_dir():
        fail(f"artifact directory missing: {source}")
    files = {
        "bin/modus": source / "modus.x86_64",
        "bin/modus.pck": source / "modus.pck",
        "LICENSE": REPOSITORY / "LICENSE",
    }
    licenses = REPOSITORY / "docs/licenses"
    safe_components(licenses)
    if licenses.exists():
        for base, directories, names in os.walk(licenses, followlinks=False):
            for name in directories:
                safe_components(Path(base) / name)
            for name in names:
                path = Path(base) / name
                files["licenses/" + path.relative_to(licenses).as_posix()] = path
    if len(files) > MAX_FILES:
        fail("too many payload files")
    for path in files.values():
        regular(path)
        if output == path or (output.exists() and os.path.samefile(output, path)):
            fail("output collides with package input")
    if not os.access(files["bin/modus"], os.X_OK):
        fail("client executable is not executable")
    with tempfile.TemporaryDirectory(prefix="modus-package-") as temporary:
        stage = Path(temporary)
        entries = []
        for name, source_path in sorted(files.items()):
            relative_path(name)
            target = stage / name
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source_path, target)
            mode = 0o755 if name == "bin/modus" else 0o644
            target.chmod(mode)
            entries.append(
                {
                    "path": name,
                    "bytes": target.stat().st_size,
                    "sha256": digest(target),
                    "mode": mode,
                }
            )
        manifest = encoded(
            {
                "schema_version": 1,
                "product": "MODUS",
                "version": version,
                "platform": "linux-x86_64",
                "files": entries,
            }
        )
        inventory(manifest)
        output.parent.mkdir(parents=True, exist_ok=True)
        with tempfile.NamedTemporaryFile(
            dir=output.parent, prefix=".modus-tar-", suffix=".tar", delete=False
        ) as stream:
            temporary_tar = Path(stream.name)
        with tempfile.NamedTemporaryFile(
            dir=output.parent, prefix=".modus-archive-", delete=False
        ) as stream:
            temporary_output = Path(stream.name)
        try:
            with temporary_tar.open("wb") as raw, tarfile.open(
                fileobj=raw, mode="w", format=tarfile.USTAR_FORMAT
            ) as archive:
                root = f"modus-linux-{version}"
                add_member(
                    archive,
                    root + "/MANIFEST",
                    io.BytesIO(manifest),
                    len(manifest),
                    0o644,
                )
                for entry in entries:
                    with (stage / entry["path"]).open("rb") as stream:
                        add_member(
                            archive,
                            root + "/" + entry["path"],
                            stream,
                            entry["bytes"],
                            entry["mode"],
                        )
            if zstd_archive(output):
                compress_zstd(temporary_tar, temporary_output)
            else:
                with temporary_tar.open("rb") as raw, temporary_output.open(
                    "wb"
                ) as output_stream, gzip.GzipFile(
                    filename="", mode="wb", fileobj=output_stream, mtime=0
                ) as zipped:
                    shutil.copyfileobj(raw, zipped)
            os.replace(temporary_output, output)
        finally:
            temporary_tar.unlink(missing_ok=True)
            temporary_output.unlink(missing_ok=True)
    print(f"PASS: portable archive {output}")


def add_member(archive, name, stream, size, mode):
    member = tarfile.TarInfo(name)
    member.size = size
    member.mode = mode
    archive.addfile(member, stream)


def unpack(archive_path, destination):
    regular(archive_path)
    if zstd_archive(archive_path):
        with tempfile.TemporaryDirectory(prefix="modus-unpack-") as temporary:
            tar_path = Path(temporary) / "archive.tar"
            decompress_zstd(archive_path, tar_path)
            return _unpack_tar(tar_path, destination, "r:")
    return _unpack_tar(archive_path, destination, "r:gz")


def _unpack_tar(archive_path, destination, mode):
    with tarfile.open(archive_path, mode=mode) as archive:
        members = {}
        total = 0
        roots = set()
        for member in archive:
            name = relative_path(member.name)
            if name in members:
                fail(f"duplicate archive path: {name}")
            if (
                len(members) >= MAX_FILES + 2
                or not member.isreg()
                or member.pax_headers
                or member.linkname
                or member.sparse is not None
            ):
                fail("archive forbids links, directories and extended metadata")
            if not 0 <= member.size <= MAX_BYTES or member.mode not in (0o644, 0o755):
                fail(f"invalid archive size/mode: {name}")
            total += member.size
            if total > MAX_BYTES + MAX_MANIFEST:
                fail("archive exceeds size limit")
            roots.add(name.split("/")[0])
            members[name] = member
        if len(roots) != 1:
            fail("archive must have exactly one root")
        root = roots.pop()
        manifest_member = members.get(root + "/MANIFEST")
        if (
            manifest_member is None
            or manifest_member.size > MAX_MANIFEST
            or manifest_member.mode != 0o644
        ):
            fail("archive manifest missing or invalid")
        with archive.extractfile(manifest_member) as stream:
            manifest_data = stream.read(MAX_MANIFEST + 1)
        manifest, entries = inventory(manifest_data)
        if root != f"modus-linux-{manifest['version']}":
            fail("archive root/version mismatch")
        if set(members) != {
            root + "/MANIFEST",
            *(root + "/" + name for name in entries),
        }:
            fail("archive members differ from owned-file inventory")
        for name, entry in entries.items():
            member = members[root + "/" + name]
            if member.size != entry["bytes"] or member.mode != entry["mode"]:
                fail(f"archive metadata differs from inventory: {name}")
        # Every name/type/size is checked before any payload is extracted.
        for name, entry in entries.items():
            target = destination / name
            target.parent.mkdir(parents=True, exist_ok=True)
            with archive.extractfile(members[root + "/" + name]) as stream, target.open(
                "xb"
            ) as output:
                shutil.copyfileobj(stream, output, 1024 * 1024)
            target.chmod(entry["mode"])
        (destination / "MANIFEST").write_bytes(manifest_data)
        (destination / "MANIFEST").chmod(0o644)
        check_payload(destination, entries)
        return entries, encoded(
            {
                "schema_version": 1,
                "product": "MODUS",
                "manifest_sha256": hashlib.sha256(manifest_data).hexdigest(),
            }
        )


def remove_owned(root, entries):
    directories = set()
    for name in [*entries, "MANIFEST"]:
        (root / name).unlink()
        directories.update((root / name).parents)
    # Only empty directories derived from owned paths may be removed.
    for directory in sorted(
        directories, key=lambda path: len(path.parts), reverse=True
    ):
        if directory != root and root in directory.parents:
            try:
                directory.rmdir()
            except OSError:
                pass


def replace_install(prefix, new_root, new_receipt, workspace):
    root = prefix / "modus"
    receipt = prefix / RECEIPT
    old_root = workspace / "previous-root"
    old_receipt = workspace / "previous-receipt"
    moved_root = moved_receipt = placed_root = placed_receipt = False
    try:
        if root.exists():
            os.replace(root, old_root)
            moved_root = True
        if receipt.exists():
            os.replace(receipt, old_receipt)
            moved_receipt = True
        if new_root is not None:
            os.replace(new_root, root)
            placed_root = True
        if new_receipt is not None:
            os.replace(new_receipt, receipt)
            placed_receipt = True
    except BaseException:
        if placed_receipt:
            receipt.unlink()
        if placed_root:
            os.replace(root, workspace / "failed-root")
        if moved_receipt:
            os.replace(old_receipt, receipt)
        if moved_root:
            os.replace(old_root, root)
        raise


def copy_regular(source, destination):
    regular(Path(source))
    return shutil.copy2(source, destination)


def change_install(args, installing):
    prefix = local_path(args.prefix)
    if prefix == Path(prefix.anchor):
        fail("filesystem root cannot be an installation prefix")
    archive_path = local_path(args.archive) if installing else None
    # Archive integrity is checked before creating/changing the installation prefix.
    with tempfile.TemporaryDirectory(prefix="modus-checked-") as temporary:
        payload = Path(temporary)
        new_entries, receipt_data = (
            unpack(archive_path, payload) if installing else ({}, None)
        )
        old_entries = installed(prefix)
        if old_entries is None and not installing:
            fail("installation ownership receipt missing")
        prefix.mkdir(parents=True, exist_ok=True)
        workspace = Path(tempfile.mkdtemp(prefix=".modus-transaction-", dir=prefix))
        try:
            candidate = workspace / "candidate"
            if old_entries is not None:
                shutil.copytree(
                    prefix / "modus",
                    candidate,
                    symlinks=True,
                    copy_function=copy_regular,
                )
                remove_owned(candidate, old_entries)
            else:
                candidate.mkdir()
            if installing:
                for name in [*new_entries, "MANIFEST"]:
                    target = candidate / name
                    safe_components(target)
                    if target.exists() or target.is_symlink():
                        fail(f"unowned path collision: {name}")
                    target.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copyfile(payload / name, target)
                    target.chmod(
                        0o644 if name == "MANIFEST" else new_entries[name]["mode"]
                    )
                check_payload(candidate, new_entries)
                receipt = workspace / "new-receipt"
                receipt.write_bytes(receipt_data)
                receipt.chmod(0o644)
            else:
                receipt = None
            replacement = candidate if any(candidate.iterdir()) else None
            replace_install(prefix, replacement, receipt, workspace)
        except BaseException:
            if (workspace / "previous-root").exists() or (
                workspace / "previous-receipt"
            ).exists():
                print(
                    f"FAIL: rollback incomplete; recovery retained at {workspace}",
                    file=sys.stderr,
                )
            else:
                shutil.rmtree(workspace)
            raise
        else:
            shutil.rmtree(workspace)
    if installing:
        print(f"PASS: installed {prefix / 'modus'}")
    else:
        print("PASS: removed owned files; unrelated files and user data preserved")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    bundle = commands.add_parser("package")
    bundle.add_argument("--artifact-dir", required=True)
    bundle.add_argument("--output", required=True)
    bundle.add_argument("--version", default="0.9.5-beta")
    install = commands.add_parser("install")
    install.add_argument("--archive", required=True)
    install.add_argument("--prefix", required=True)
    for command in ("verify", "uninstall"):
        commands.add_parser(command).add_argument("--prefix", required=True)
    args = parser.parse_args()
    try:
        if args.command == "package":
            package(args)
        elif args.command == "verify":
            if installed(local_path(args.prefix)) is None:
                fail("installation ownership receipt missing")
            print("PASS: install ownership, payload hashes, sizes and modes are valid")
        else:
            change_install(args, args.command == "install")
    except (OSError, ValueError, UnicodeError, tarfile.TarError, EOFError) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
