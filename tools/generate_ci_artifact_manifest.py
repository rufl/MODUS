#!/usr/bin/env python3
"""Generate a hash-bound manifest for one CI export artifact directory."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path

SHA256 = re.compile(r"^[0-9a-f]{64}$")
COMMIT = re.compile(r"^[0-9a-f]{40}$")


class ManifestError(ValueError):
    """The export directory cannot produce a trustworthy manifest."""


def digest(path: Path) -> str:
    value = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            value.update(chunk)
    return value.hexdigest()


def regular_file(path: Path, description: str) -> Path:
    if not path.is_file() or path.is_symlink() or path.stat().st_size <= 0:
        raise ManifestError(f"{description} must be a non-empty regular file: {path}")
    return path


def read_sums(path: Path) -> dict[str, str]:
    checksums: dict[str, str] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        fields = line.split(maxsplit=1)
        if len(fields) != 2 or SHA256.fullmatch(fields[0]) is None:
            raise ManifestError(f"invalid SHA256SUMS entry: {line}")
        name = Path(fields[1]).name
        if fields[1] != name or name in checksums:
            raise ManifestError(f"invalid or duplicate artifact path: {fields[1]}")
        checksums[name] = fields[0]
    if not checksums:
        raise ManifestError("SHA256SUMS must contain artifact entries")
    return checksums


def generate(args: argparse.Namespace) -> dict[str, object]:
    root = args.root
    if not root.is_dir() or root.is_symlink():
        raise ManifestError(f"artifact root must be a directory: {root}")
    root = root.resolve()
    if not args.platform or not args.preset or not args.godot_version:
        raise ManifestError("platform, preset and Godot version are required")
    if COMMIT.fullmatch(args.commit) is None:
        raise ManifestError("commit must be a 40-character lowercase Git SHA")
    executable = Path(args.executable)
    if executable.name != args.executable or not args.executable or "/" in args.executable or "\\" in args.executable:
        raise ManifestError("executable must be a file name")
    executable_path = regular_file(root / executable.name, "export executable")
    content_name = f"{executable.stem}.pck"
    content_path = regular_file(root / content_name, "export content")
    sums_path = regular_file(root / "SHA256SUMS", "SHA256SUMS")
    checksums = read_sums(sums_path)
    expected = {executable.name, content_name}
    if set(checksums) != expected:
        raise ManifestError(f"SHA256SUMS must cover exactly {sorted(expected)}")
    for path in (executable_path, content_path):
        if checksums[path.name] != digest(path):
            raise ManifestError(f"SHA-256 mismatch for {path.name}")
    if args.toolchain_lock.is_symlink():
        raise ManifestError(f"toolchain lock must not be a symlink: {args.toolchain_lock}")
    lock = regular_file(args.toolchain_lock, "toolchain lock")
    if args.output.is_symlink():
        raise ManifestError(f"manifest output must not be a symlink: {args.output}")
    output = args.output.resolve()
    if output in {executable_path.resolve(), content_path.resolve(), sums_path.resolve(), lock.resolve()}:
        raise ManifestError("manifest output must not overwrite an input")
    manifest = {
        "artifacts": checksums,
        "commit": args.commit,
        "godot_version": args.godot_version,
        "platform": args.platform,
        "preset": args.preset,
        "product": "MODUS",
        "toolchain_lock_sha256": digest(lock),
    }
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    return manifest


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--platform", required=True)
    parser.add_argument("--preset", required=True)
    parser.add_argument("--executable", required=True)
    parser.add_argument("--commit", required=True)
    parser.add_argument("--godot-version", required=True)
    parser.add_argument(
        "--toolchain-lock",
        type=Path,
        default=Path(__file__).with_name("toolchain.lock.json"),
    )
    try:
        manifest = generate(parser.parse_args())
    except (ManifestError, OSError, ValueError) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        return 1
    print(
        "PASS: CI artifact manifest "
        f"{manifest['platform']} bound to toolchain lock {manifest['toolchain_lock_sha256']}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
