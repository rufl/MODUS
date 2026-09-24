#!/usr/bin/env bash
set -euo pipefail

root="$(cd -- "$(dirname -- "$0")/../.." && pwd)"
PYTHONDONTWRITEBYTECODE=1 python3 - "$root" <<'PY'
import argparse
import hashlib
import importlib.util
import io
import json
import os
from pathlib import Path
import shutil
import stat
import subprocess
import sys
import tarfile
import tempfile
from unittest import mock

repository = Path(sys.argv[1])
cli = repository / "tools/package_linux_portable.sh"
spec = importlib.util.spec_from_file_location("portable", repository / "tools/package_linux_portable.py")
portable = importlib.util.module_from_spec(spec)
spec.loader.exec_module(portable)

with tempfile.TemporaryDirectory(prefix="modus portable régression ") as temporary:
    work = Path(temporary)
    prefix = work / "préfix with spaces"
    artifact = work / "client files"
    artifact.mkdir()
    binary = artifact / "modus.x86_64"
    binary.write_text("#!/bin/sh\nprintf 'fixture one\\n'\n")
    binary.chmod(0o755)
    (artifact / "modus.pck").write_bytes(b"content one\n")
    xdg = work / "user data"
    saves = xdg / "modus/save.dat"
    saves.parent.mkdir(parents=True)
    saves.write_bytes(b"irreplaceable save")
    config = work / "user config/modus/settings.cfg"
    config.parent.mkdir(parents=True)
    config.write_bytes(b"irreplaceable config")
    environment = dict(os.environ, XDG_DATA_HOME=str(xdg), XDG_CONFIG_HOME=str(config.parent.parent))

    def run(*args, success=True):
        result = subprocess.run([str(cli), *map(str, args)], cwd=work, env=environment, capture_output=True, text=True)
        assert (result.returncode == 0) == success, (args, result.returncode, result.stdout, result.stderr)
        return result

    def snapshot(path):
        result = {}
        if not path.exists():
            return result
        for base, dirs, files in os.walk(path, followlinks=False):
            for name in dirs + files:
                item = Path(base) / name
                key = item.relative_to(path).as_posix()
                info = item.lstat()
                if item.is_symlink():
                    result[key] = ("symlink", os.readlink(item))
                elif item.is_file():
                    result[key] = ("file", stat.S_IMODE(info.st_mode), item.read_bytes())
                else:
                    result[key] = ("directory", stat.S_IMODE(info.st_mode))
        return result

    archive = work / "first candidate.tar.gz"
    run("package", "--artifact-dir", artifact, "--output", archive, "--version", "1.2.3-test")
    identical = work / "identical.tar.gz"
    run("package", "--artifact-dir", artifact, "--output", identical, "--version", "1.2.3-test")
    assert archive.read_bytes() == identical.read_bytes(), "bundle is not reproducible"
    zstd_archive = work / "first candidate.tar.zst"
    run("package", "--artifact-dir", artifact, "--output", zstd_archive, "--version", "1.2.3-test")
    zstd_identical = work / "identical.tar.zst"
    run("package", "--artifact-dir", artifact, "--output", zstd_identical, "--version", "1.2.3-test")
    assert zstd_archive.read_bytes() == zstd_identical.read_bytes(), "zstd bundle is not reproducible"
    zstd_prefix = work / "zstd prefix"
    run("install", "--archive", zstd_archive, "--prefix", zstd_prefix)
    run("verify", "--prefix", zstd_prefix)
    run("uninstall", "--prefix", zstd_prefix)
    run("package", "--artifact-dir", artifact, "--output", work / "invalid.tar.gz", "--version", "../../outside", success=False)
    run("install", "--archive", archive, "--prefix", work / "traversal/../escape", success=False)
    unmanaged = work / "unmanaged"
    (unmanaged / "modus").mkdir(parents=True)
    (unmanaged / "modus/keep").write_text("unmanaged payload")
    before = snapshot(unmanaged)
    run("install", "--archive", archive, "--prefix", unmanaged, success=False)
    assert snapshot(unmanaged) == before
    (unmanaged / ".modus-install-manifest").write_text(str(unmanaged / "modus") + "\n")
    before = snapshot(unmanaged)
    error = run("uninstall", "--prefix", unmanaged, success=False)
    assert "legacy" in error.stderr
    assert snapshot(unmanaged) == before

    prefix.mkdir()
    (prefix / "outside.txt").write_bytes(b"prefix neighbor")
    run("install", "--archive", archive, "--prefix", prefix)
    run("verify", "--prefix", prefix)
    root = prefix / "modus"
    (root / "bin/user notes.txt").write_bytes(b"unowned nested file")
    (root / "unrelated").mkdir()
    (root / "unrelated/keep.txt").write_bytes(b"unowned file")
    (root / "saves").symlink_to(saves.parent, target_is_directory=True)
    assert (root / "LICENSE").read_bytes() == (repository / "LICENSE").read_bytes()

    binary.write_text("#!/bin/sh\nprintf 'fixture two\\n'\n")
    (artifact / "modus.pck").write_bytes(b"content two\n")
    second = work / "second.tar.gz"
    run("package", "--artifact-dir", artifact, "--output", second, "--version", "1.2.4-test")
    before = snapshot(prefix)
    actual_replace = portable.os.replace

    def fail_commit(source, destination):
        if Path(destination) == prefix / ".modus-install-manifest" and Path(source).name == "new-receipt":
            raise OSError("injected receipt commit failure")
        return actual_replace(source, destination)

    with mock.patch.object(portable.os, "replace", side_effect=fail_commit):
        try:
            portable.change_install(argparse.Namespace(prefix=str(prefix), archive=str(second)), True)
        except OSError as error:
            assert "injected" in str(error)
        else:
            raise AssertionError("transaction failure did not propagate")
    assert snapshot(prefix) == before, "failed commit did not restore previous installation"
    run("verify", "--prefix", prefix)
    run("install", "--archive", second, "--prefix", prefix)
    run("verify", "--prefix", prefix)
    assert (root / "bin/modus.pck").read_bytes() == b"content two\n"
    assert subprocess.check_output([str(root / "bin/modus")], text=True) == "fixture two\n"
    assert (root / "bin/user notes.txt").read_bytes() == b"unowned nested file"
    assert (root / "saves").is_symlink()

    with tarfile.open(second, "r:gz") as stream:
        records = [(member, stream.extractfile(member).read()) for member in stream]
    bundle_root = records[0][0].name.split("/")[0]

    def bad_archive(name, mutate):
        destination = work / (name + ".tar.gz")
        entries = [(tarfile.TarInfo(member.name), data, member.mode) for member, data in records]
        entries = mutate(entries)
        with tarfile.open(destination, "w:gz") as stream:
            for member, data, mode in entries:
                member.mode = mode
                member.size = len(data) if member.isreg() else 0
                stream.addfile(member, io.BytesIO(data) if member.isreg() else None)
        baseline = snapshot(prefix)
        run("install", "--archive", destination, "--prefix", prefix, success=False)
        assert snapshot(prefix) == baseline, name + " modified installation"
        assert saves.read_bytes() == b"irreplaceable save"
        assert config.read_bytes() == b"irreplaceable config"

    def added(path, kind=tarfile.REGTYPE):
        def mutate(entries):
            member = tarfile.TarInfo(path)
            member.type = kind
            member.linkname = str(saves) if kind in (tarfile.SYMTYPE, tarfile.LNKTYPE) else ""
            return entries + [(member, b"malicious", 0o644)]
        return mutate

    bad_archive("traversal", added(bundle_root + "/../../escaped"))
    bad_archive("absolute", added(str(work / "escaped")))
    bad_archive("extra-root", added("another-root/extra"))
    bad_archive("unowned-extra", added(bundle_root + "/extra"))
    bad_archive("symlink", added(bundle_root + "/link", tarfile.SYMTYPE))
    bad_archive("hardlink", added(bundle_root + "/link", tarfile.LNKTYPE))
    bad_archive("fifo", added(bundle_root + "/pipe", tarfile.FIFOTYPE))
    bad_archive("duplicate", lambda entries: entries + [entries[1]])
    bad_archive("mutation", lambda entries: [(member, b"X" * len(data) if member.name.endswith("/bin/modus.pck") else data, mode) for member, data, mode in entries])
    bad_archive("size-mismatch", lambda entries: [(member, data + b"extra" if member.name.endswith("/bin/modus.pck") else data, mode) for member, data, mode in entries])
    assert not (work / "escaped").exists()
    truncated = work / "truncated.tar.gz"
    truncated.write_bytes(second.read_bytes()[:40])
    baseline = snapshot(prefix)
    run("install", "--archive", truncated, "--prefix", prefix, success=False)
    assert snapshot(prefix) == baseline

    def refused_operations():
        baseline = snapshot(prefix)
        for command in ("verify", "uninstall"):
            run(command, "--prefix", prefix, success=False)
            assert snapshot(prefix) == baseline
        run("install", "--archive", second, "--prefix", prefix, success=False)
        assert snapshot(prefix) == baseline

    content = root / "bin/modus.pck"
    original = content.read_bytes()
    content.write_bytes(b"tampered")
    refused_operations()
    content.write_bytes(original)
    content.chmod(0o600)
    refused_operations()
    content.chmod(0o644)
    manifest_path = root / "MANIFEST"
    manifest_data = manifest_path.read_bytes()
    manifest = json.loads(manifest_data)
    manifest["files"][0]["path"] = "../../outside.txt"
    manifest_path.write_text(json.dumps(manifest))
    refused_operations()
    # Even with a matching receipt hash, unsafe ownership paths must be rejected.
    receipt_path = prefix / ".modus-install-manifest"
    receipt_data = receipt_path.read_bytes()
    receipt = json.loads(receipt_data)
    receipt["manifest_sha256"] = hashlib.sha256(manifest_path.read_bytes()).hexdigest()
    receipt_path.write_text(json.dumps(receipt))
    refused_operations()
    manifest_path.write_bytes(manifest_data)
    receipt_path.write_bytes(receipt_data)
    for metadata in (manifest_path, receipt_path):
        original = metadata.read_bytes()
        external = work / "external metadata"
        external.write_bytes(original)
        metadata.unlink()
        metadata.symlink_to(external)
        refused_operations()
        assert external.read_bytes() == original
        metadata.unlink()
        metadata.write_bytes(original)
        metadata.chmod(0o644)
    bin_dir = root / "bin"
    moved_bin = work / "external bin"
    bin_dir.rename(moved_bin)
    bin_dir.symlink_to(moved_bin, target_is_directory=True)
    refused_operations()
    bin_dir.unlink()
    moved_bin.rename(bin_dir)

    # An unowned directory occupying a newly introduced license is a collision.
    third = work / "collision.tar.gz"
    collision_name = "licenses/new-notice.txt"
    manifest = json.loads(manifest_data)
    manifest["files"].append({"path": collision_name, "bytes": 3, "mode": 0o644, "sha256": hashlib.sha256(b"new").hexdigest()})
    with tarfile.open(third, "w:gz") as stream:
        for member, data in records:
            if member.name.endswith("/MANIFEST"):
                data = json.dumps(manifest).encode()
            copy = tarfile.TarInfo(member.name)
            copy.mode = member.mode
            copy.size = len(data)
            stream.addfile(copy, io.BytesIO(data))
        copy = tarfile.TarInfo(bundle_root + "/" + collision_name)
        copy.mode = 0o644
        copy.size = 3
        stream.addfile(copy, io.BytesIO(b"new"))
    collision = root / collision_name
    collision.mkdir()
    (collision / "keep").write_bytes(b"unowned collision")
    baseline = snapshot(prefix)
    run("install", "--archive", third, "--prefix", prefix, success=False)
    assert snapshot(prefix) == baseline
    run("verify", "--prefix", prefix)
    run("uninstall", "--prefix", prefix)
    assert not (root / "bin/modus").exists()
    assert not (root / "MANIFEST").exists()
    assert not receipt_path.exists()
    assert (prefix / "outside.txt").read_bytes() == b"prefix neighbor"
    assert (root / "bin/user notes.txt").read_bytes() == b"unowned nested file"
    assert (root / "unrelated/keep.txt").read_bytes() == b"unowned file"
    assert (collision / "keep").read_bytes() == b"unowned collision"
    assert (root / "saves").is_symlink()
    assert saves.read_bytes() == b"irreplaceable save"
    assert config.read_bytes() == b"irreplaceable config"
    run("verify", "--prefix", prefix, success=False)
    clean_prefix = work / "clean prefix"
    run("install", "--archive", archive, "--prefix", clean_prefix)
    run("uninstall", "--prefix", clean_prefix)
    assert not (clean_prefix / "modus").exists()

print("Linux portable package lifecycle regression checks passed.")
PY
