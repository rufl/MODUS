#!/usr/bin/env python3
"""Prepare lean MODUS ZTASH receiver archives from release archives."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import shutil
import subprocess
import sys
import tarfile
import tempfile
import zipfile
from pathlib import Path, PurePosixPath

BUILD_ID = re.compile(r"[0-9a-f]{40}")
VERSION = re.compile(
    r"(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)"
    r"(?:-((?:0|[1-9][0-9]*|[0-9]*[A-Za-z-][0-9A-Za-z-]*)"
    r"(?:\.(?:0|[1-9][0-9]*|[0-9]*[A-Za-z-][0-9A-Za-z-]*))*))?"
    r"(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?"
)


class Failure(ValueError):
    pass


def digest(path: Path) -> str:
    hasher = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            hasher.update(chunk)
    return hasher.hexdigest()
def required_digest(path: Path, description: str) -> str:
    if not path.is_file() or path.is_symlink():
        raise Failure(f"{description} must be a regular file: {path}")
    return digest(path)


def safe_member(name: str) -> PurePosixPath:
    path = PurePosixPath(name)
    if path.is_absolute() or any(part in {"", ".", ".."} for part in path.parts):
        raise Failure(f"unsafe archive member: {name}")
    return path


def root_members(names: list[str], expected_root: str) -> dict[str, str]:
    members: dict[str, str] = {}
    prefix = expected_root + "/"
    for name in names:
        safe_member(name)
        if name.startswith(prefix) and name != prefix:
            relative = name[len(prefix) :]
            if "/" not in relative:
                members[relative] = name
    return members


def extract_archive(archive: Path, target: Path, expected_root: str, required: tuple[str, ...]) -> None:
    if archive.suffix == ".zip":
        with zipfile.ZipFile(archive) as source:
            members = root_members(source.namelist(), expected_root)
            missing = [name for name in required if name not in members]
            if missing:
                raise Failure(f"{archive.name} missing: {', '.join(missing)}")
            for name in required:
                destination = target / name
                destination.parent.mkdir(parents=True, exist_ok=True)
                with source.open(members[name]) as input_stream, destination.open("wb") as output:
                    shutil.copyfileobj(input_stream, output)
                info = source.getinfo(members[name])
                destination.chmod(0o755 if name in {"modus.bin", "modus.exe"} else 0o644)
        return
    if not archive.name.endswith(".tar.gz"):
        raise Failure(f"unsupported release archive: {archive}")
    with tarfile.open(archive, mode="r:gz") as source:
        names = [member.name for member in source.getmembers()]
        members = root_members(names, expected_root)
        missing = [name for name in required if name not in members]
        if missing:
            raise Failure(f"{archive.name} missing: {', '.join(missing)}")
        for name in required:
            member = source.getmember(members[name])
            if not member.isfile():
                raise Failure(f"{archive.name} member is not a regular file: {name}")
            destination = target / name
            destination.parent.mkdir(parents=True, exist_ok=True)
            input_stream = source.extractfile(member)
            if input_stream is None:
                raise Failure(f"unable to read {archive.name} member: {name}")
            with input_stream, destination.open("wb") as output:
                shutil.copyfileobj(input_stream, output)
            destination.chmod(0o755 if name == "modus.bin" else 0o644)


def run_package_tool(
    tool: Path,
    version: str,
    target: str,
    source: Path,
    icons: Path,
    output: Path,
    windows_launcher: Path | None = None,
) -> None:
    executable = source / ("modus.exe" if target.startswith("windows-") else "modus.bin")
    command = [
        sys.executable,
        str(tool),
        "package",
        "--version",
        version,
        "--target",
        target,
        "--executable",
        str(executable),
        "--content",
        str(source / "modus.pck"),
        "--readme",
        str(source / "README.md"),
        "--license",
        str(source / "LICENSE"),
        "--extra",
        f"{'ztash.ico' if target.startswith('windows-') else 'ztash.svg'}={icons / ('ztash.ico' if target.startswith('windows-') else 'ztash.svg')}",
        "--output",
        str(output),
    ]
    if target.startswith("windows-") and windows_launcher is not None:
        command.extend(("--windows-launcher", str(windows_launcher.absolute())))
    subprocess.run(command, check=True)


def prepare(args: argparse.Namespace) -> None:
    if VERSION.fullmatch(args.version) is None:
        raise Failure("version must be semantic version text")
    if BUILD_ID.fullmatch(args.build_id) is None:
        raise Failure("build-id must be 40 lowercase hexadecimal characters")
    root = args.root.absolute()
    windows_launcher = args.windows_launcher.absolute() if args.windows_launcher is not None else None
    if windows_launcher is not None and (not windows_launcher.is_file() or windows_launcher.is_symlink()):
        raise Failure(f"missing regular Windows launcher: {windows_launcher}")
    output = args.output.absolute()
    icons = args.icons.absolute()
    toolchain_lock = args.toolchain_lock.absolute()
    toolchain_lock_sha256 = required_digest(toolchain_lock, "toolchain lock")
    tool = args.package_tool.absolute()
    if not root.is_dir() or root.is_symlink():
        raise Failure(f"invalid release root: {root}")
    if output.exists() or output.is_symlink():
        raise Failure(f"refusing to replace existing ZTASH output: {output}")
    for icon in (icons / "ztash.svg", icons / "ztash.ico"):
        if not icon.is_file() or icon.is_symlink():
            raise Failure(f"missing regular ZTASH icon: {icon}")
    if not tool.is_file() or tool.is_symlink():
        raise Failure(f"missing package tool: {tool}")

    linux_archive = root / f"modus-{args.version}-linux-x86_64.tar.gz"
    windows_archive = root / f"modus-{args.version}-windows-x86_64.zip"
    for archive in (linux_archive, windows_archive):
        if not archive.is_file() or archive.is_symlink():
            raise Failure(f"missing release archive: {archive}")

    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="modus-ztash-", dir=output.parent) as temporary:
        staging = Path(temporary)
        linux_source = staging / "linux"
        windows_source = staging / "windows"
        extract_archive(
            linux_archive,
            linux_source,
            f"modus-{args.version}-linux-x86_64",
            ("modus.bin", "modus.pck", "README.md", "LICENSE"),
        )
        extract_archive(
            windows_archive,
            windows_source,
            f"modus-{args.version}-windows-x86_64",
            ("modus.exe", "modus.pck", "README.md", "LICENSE"),
        )

        package_root = staging / "packages"
        package_root.mkdir()
        linux_output = package_root / linux_archive.name
        windows_output = package_root / windows_archive.name
        run_package_tool(tool, args.version, "linux-x86_64", linux_source, icons, linux_output)
        run_package_tool(tool, args.version, "windows-x86_64", windows_source, icons, windows_output, windows_launcher)

        manifest = {
            "application": "modus",
            "artifacts": [
                {
                    "name": linux_output.name,
                    "sha256": digest(linux_output),
                    "size": linux_output.stat().st_size,
                    "target": "x86_64-linux",
                },
                {
                    "name": windows_output.name,
                    "sha256": digest(windows_output),
                    "size": windows_output.stat().st_size,
                    "target": "x86_64-windows-gnu",
                },
            ],
            "build_id": args.build_id,
            "schema": "ztash-release-v1",
            "version": args.version,
            "toolchain_lock_sha256": toolchain_lock_sha256,
        }
        (package_root / "ztash-release.json").write_text(
            json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8"
        )
        package_root.rename(output)
    print(f"PASS: ZTASH release {output}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--version", required=True)
    parser.add_argument("--build-id", required=True)
    parser.add_argument("--root", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--icons", type=Path, default=Path(__file__).parents[3] / "OVERZEER" / "packaging")
    parser.add_argument("--package-tool", type=Path, default=Path(__file__).with_name("package_overzeer.py"))
    parser.add_argument("--windows-launcher", type=Path, help="optional Windows wrapper for package smoke")
    parser.add_argument(
        "--toolchain-lock",
        type=Path,
        default=Path(__file__).with_name("toolchain.lock.json"),
        help="checked-in toolchain lock bound to the release metadata",
    )
    try:
        prepare(parser.parse_args())
    except (OSError, ValueError, tarfile.TarError, zipfile.BadZipFile, subprocess.CalledProcessError) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
