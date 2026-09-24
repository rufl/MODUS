#!/usr/bin/env python3
"""Validate MODUS OVERZEER archives and write a deterministic release inventory."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
import tarfile
import tempfile
import zipfile
from pathlib import Path

BUILD_ID = re.compile(r"[0-9a-f]{40}")
VERSION = re.compile(
    r"(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)"
    r"(?:-((?:0|[1-9][0-9]*|[0-9]*[A-Za-z-][0-9A-Za-z-]*)"
    r"(?:\.(?:0|[1-9][0-9]*|[0-9]*[A-Za-z-][0-9A-Za-z-]*))*))?"
    r"(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?"
)


def fail(message: str) -> None:
    raise ValueError(message)


def digest(path: Path) -> str:
    value = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            value.update(chunk)
    return value.hexdigest()


def archive_specs(version: str) -> list[tuple[str, str, str, set[str], str]]:
    linux_root = f"modus-{version}-linux-x86_64"
    windows_root = f"modus-{version}-windows-x86_64"
    linux_names = {
        "LICENSE", "README.md", "SHA256SUMS", "modus", "modus.pck",
        "server", "server.pck", "modus-editor", "modus-editor.pck",
    }
    windows_names = {
        "LICENSE", "README.md", "SHA256SUMS", "modus.exe", "modus.pck",
        "modus-editor.exe", "modus-editor.pck",
    }
    return [
        (f"modus-{version}-linux-x86_64.tar.zst", "linux-x86_64", linux_root, linux_names, "tar.zst"),
        (f"modus-{version}-linux-x86_64.tar.gz", "linux-x86_64", linux_root, linux_names, "tar.gz"),
        (f"modus-{version}-windows-x86_64.tar.zst", "windows-x86_64", windows_root, windows_names, "tar.zst"),
        (f"modus-{version}-windows-x86_64.zip", "windows-x86_64", windows_root, windows_names, "zip"),
    ]


def read_checksums(lines: str, names: set[str]) -> dict[str, str]:
    checksums: dict[str, str] = {}
    for line in lines.splitlines():
        fields = line.split("  ", 1)
        if len(fields) != 2 or not re.fullmatch(r"[0-9a-f]{64}", fields[0]):
            fail("invalid SHA256SUMS entry")
        if fields[1] in checksums or fields[1] not in names - {"SHA256SUMS"}:
            fail("unexpected or duplicate SHA256SUMS path")
        checksums[fields[1]] = fields[0]
    if set(checksums) != names - {"SHA256SUMS"}:
        fail("SHA256SUMS does not cover the exact archive payload")
    return checksums


def validate_members(
    archive_path: Path,
    format_name: str,
    root: str,
    names: set[str],
) -> None:
    if format_name == "zip":
        with zipfile.ZipFile(archive_path) as archive:
            actual = set(archive.namelist())
            expected = {f"{root}/{name}" for name in names}
            if actual != expected:
                fail(f"archive members mismatch: {archive_path.name}")
            executable = next(name for name in names if name in {"modus", "modus.exe"})
            info = archive.getinfo(f"{root}/{executable}")
            if not ((info.external_attr >> 16) & 0o111):
                fail(f"archive executable is not executable: {archive_path.name}")
            payloads = {
                name: archive.read(f"{root}/{name}")
                for name in names - {"SHA256SUMS"}
            }
            checksums = read_checksums(archive.read(f"{root}/SHA256SUMS").decode("ascii"), names)
    else:
        with tempfile.TemporaryDirectory(prefix="modus-overzeer-inventory-") as temporary:
            tar_path = Path(temporary) / "archive.tar"
            if format_name == "tar.zst":
                with tar_path.open("wb") as output:
                    result = subprocess.run(
                        ["zstd", "--quiet", "-dc", str(archive_path)],
                        stdout=output,
                        stderr=subprocess.PIPE,
                        check=False,
                    )
                if result.returncode:
                    fail(result.stderr.decode("utf-8", errors="replace").strip() or "zstd extraction failed")
                mode = "r:"
            else:
                tar_path = archive_path
                mode = "r:gz"
            with tarfile.open(tar_path, mode=mode) as archive:
                actual = set(archive.getnames())
                expected = {f"{root}/{name}" for name in names}
                if actual != expected:
                    fail(f"archive members mismatch: {archive_path.name}")
                executable = next(name for name in names if name in {"modus", "modus.exe"})
                info = archive.getmember(f"{root}/{executable}")
                if not (info.mode & 0o111):
                    fail(f"archive executable is not executable: {archive_path.name}")
                payloads = {
                    name: archive.extractfile(f"{root}/{name}").read()
                    for name in names - {"SHA256SUMS"}
                }
                checksums = read_checksums(
                    archive.extractfile(f"{root}/SHA256SUMS").read().decode("ascii"), names
                )
    for name, payload in payloads.items():
        if hashlib.sha256(payload).hexdigest() != checksums[name]:
            fail(f"payload checksum mismatch: {archive_path.name}:{name}")


def validate(args: argparse.Namespace) -> None:
    if VERSION.fullmatch(args.version) is None:
        fail("version must be semantic version text")
    if BUILD_ID.fullmatch(args.build_id) is None:
        fail("build-id must be 40 lowercase hexadecimal characters")
    root = args.root.absolute()
    output = args.output.absolute()
    if not root.is_dir():
        fail(f"release root is missing: {root}")
    if output.exists() or output.is_symlink():
        fail(f"refusing to replace existing inventory: {output}")

    artifacts = []
    for filename, target, archive_root, names, format_name in archive_specs(args.version):
        archive = root / filename
        if not archive.is_file() or archive.is_symlink() or archive.stat().st_size == 0:
            fail(f"missing archive: {archive}")
        validate_members(archive, format_name, archive_root, names)
        artifacts.append({
            "archive": filename,
            "bytes": archive.stat().st_size,
            "format": format_name,
            "root": archive_root,
            "sha256": digest(archive),
            "signing": "unsigned",
            "target": target,
        })
    output.parent.mkdir(parents=True, exist_ok=True)
    inventory = {
        "artifacts": artifacts,
        "build_id": args.build_id,
        "schema": "modus.overzeer-release/v1",
        "version": args.version,
    }
    output.write_text(json.dumps(inventory, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"PASS: OVERZEER release inventory {output}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--version", required=True)
    parser.add_argument("--build-id", required=True)
    parser.add_argument("--root", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    try:
        validate(parser.parse_args())
    except (OSError, ValueError, tarfile.TarError, zipfile.BadZipFile) as error:
        print(f"FAIL: {error}")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
