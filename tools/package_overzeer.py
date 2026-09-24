#!/usr/bin/env python3
"""Build deterministic unsigned MODUS OVERZEER transfer archives."""

from __future__ import annotations

import argparse
import gzip
import hashlib
import os
import re
import shutil
import stat
import subprocess
import sys
import tarfile
import tempfile
import zipfile
from pathlib import Path, PurePosixPath

TARGET = re.compile(r"[a-z0-9][a-z0-9._-]*")
VERSION = re.compile(
    r"(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)"
    r"(?:-((?:0|[1-9][0-9]*|[0-9]*[A-Za-z-][0-9A-Za-z-]*)"
    r"(?:\.(?:0|[1-9][0-9]*|[0-9]*[A-Za-z-][0-9A-Za-z-]*))*))?"
    r"(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?"
)


def fail(message: str) -> None:
    raise ValueError(message)


def regular(path: Path) -> None:
    try:
        info = path.lstat()
    except OSError as error:
        fail(f"missing input: {path} ({error})")
    if not stat.S_ISREG(info.st_mode) or info.st_size <= 0:
        fail(f"input must be a non-empty regular file: {path}")


def digest(path: Path) -> str:
    hasher = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            hasher.update(chunk)
    return hasher.hexdigest()


def destination(value: str) -> str:
    path = PurePosixPath(value)
    if (
        not value
        or path.is_absolute()
        or any(part in ("", ".", "..") for part in value.split("/"))
        or "\\" in value
        or ":" in value
    ):
        fail(f"invalid archive path: {value}")
    return path.as_posix()


def require_zstd() -> None:
    if shutil.which("zstd") is None:
        fail("zstd executable is required")


def compress_zstd(source: Path, destination_path: Path) -> None:
    require_zstd()
    with destination_path.open("wb") as output:
        result = subprocess.run(
            [
                "zstd",
                "--quiet",
                "--no-progress",
                "--no-check",
                "--threads=1",
                "-3",
                "--stdout",
                str(source),
            ],
            stdout=output,
            stderr=subprocess.PIPE,
            check=False,
        )
    if result.returncode:
        message = result.stderr.decode("utf-8", errors="replace").strip()
        fail(message or "zstd compression failed")


def compress_gzip(source: Path, destination_path: Path) -> None:
    with source.open("rb") as input_stream, destination_path.open("wb") as raw_output:
        with gzip.GzipFile(fileobj=raw_output, mode="wb", filename="", mtime=0) as output:
            shutil.copyfileobj(input_stream, output, length=1024 * 1024)


def write_zip(
    stage: Path,
    root: str,
    entries: list[tuple[str, int]],
    output: Path,
) -> None:
    with zipfile.ZipFile(
        output,
        mode="w",
        compression=zipfile.ZIP_DEFLATED,
        compresslevel=9,
    ) as archive:
        for name, mode in [*entries, ("SHA256SUMS", 0o644)]:
            info = zipfile.ZipInfo(
                f"{root}/{name}",
                date_time=(1980, 1, 1, 0, 0, 0),
            )
            info.create_system = 3
            info.external_attr = (mode & 0xFFFF) << 16
            info.compress_type = zipfile.ZIP_DEFLATED
            with archive.open(info, mode="w") as target, (stage / name).open("rb") as source:
                shutil.copyfileobj(source, target, length=1024 * 1024)


def archive_format(output: Path, requested: str) -> str:
    if requested != "auto":
        return requested
    if output.name.endswith(".tar.zst"):
        return "tar.zst"
    if output.name.endswith(".tar.gz"):
        return "tar.gz"
    if output.suffix == ".zip":
        return "zip"
    fail("output must end in .tar.zst, .tar.gz or .zip")
    raise AssertionError("unreachable")


def add_member(archive: tarfile.TarFile, name: str, source: Path, mode: int) -> None:
    member = tarfile.TarInfo(name)
    member.mode = mode
    member.size = source.stat().st_size
    with source.open("rb") as stream:
        archive.addfile(member, stream)


def package(args: argparse.Namespace) -> None:
    if VERSION.fullmatch(args.version) is None:
        fail("version must be semantic version text")
    if TARGET.fullmatch(args.target) is None:
        fail("target must contain only lowercase letters, digits, '.', '_' or '-'")
    output = args.output.absolute()
    format_name = archive_format(output, args.format)
    required_suffix = {
        "tar.zst": ".tar.zst",
        "tar.gz": ".tar.gz",
        "zip": ".zip",
    }[format_name]
    if not output.name.endswith(required_suffix):
        fail(f"output must end in {required_suffix}")
    if output.exists() or output.is_symlink():
        fail(f"refusing to replace existing output: {output}")

    inputs: dict[str, Path] = {
        "README.md": args.readme.absolute(),
        "LICENSE": args.license.absolute(),
        "modus.exe" if args.target.startswith("windows-") else "modus": args.executable.absolute(),
        "modus.pck": args.content.absolute(),
    }
    for value in args.extra:
        if "=" not in value:
            fail(f"extra must be DEST=SOURCE: {value}")
        name, source = value.split("=", 1)
        name = destination(name)
        if name in inputs or name == "SHA256SUMS":
            fail(f"duplicate archive path: {name}")
        inputs[name] = Path(source).absolute()
    for name, source in inputs.items():
        regular(source)

    root = f"modus-{args.version}-{args.target}"
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="modus-overzeer-", dir=output.parent) as temporary:
        stage = Path(temporary) / root
        stage.mkdir()
        entries: list[tuple[str, int]] = []
        for name, source in sorted(inputs.items()):
            target = stage / name
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, target, follow_symlinks=False)
            mode = 0o755 if name in {"modus", "modus.exe"} else 0o644
            target.chmod(mode)
            entries.append((name, mode))
        checksums = "".join(
            f"{digest(stage / name)}  {name}\n" for name, _mode in entries
        )
        (stage / "SHA256SUMS").write_text(checksums, encoding="ascii")

        temporary_output = Path(temporary) / f"archive{required_suffix}"
        if format_name == "zip":
            write_zip(stage, root, entries, temporary_output)
        else:
            temporary_tar = Path(temporary) / "archive.tar"
            with tarfile.open(temporary_tar, mode="w", format=tarfile.USTAR_FORMAT) as archive:
                for name, mode in [*entries, ("SHA256SUMS", 0o644)]:
                    add_member(archive, f"{root}/{name}", stage / name, mode)
            if format_name == "tar.zst":
                compress_zstd(temporary_tar, temporary_output)
            else:
                compress_gzip(temporary_tar, temporary_output)
        os.replace(temporary_output, output)
    print(f"PASS: OVERZEER archive {output}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("package", choices=("package",))
    parser.add_argument("--version", required=True)
    parser.add_argument("--target", required=True)
    parser.add_argument("--executable", type=Path, required=True)
    parser.add_argument("--content", type=Path, required=True)
    parser.add_argument("--readme", type=Path, required=True)
    parser.add_argument("--license", type=Path, required=True)
    parser.add_argument("--extra", action="append", default=[])
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument(
        "--format",
        choices=("auto", "tar.zst", "tar.gz", "zip"),
        default="auto",
        help="archive format; inferred from --output by default",
    )
    try:
        package(parser.parse_args())
    except (OSError, ValueError, tarfile.TarError) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
