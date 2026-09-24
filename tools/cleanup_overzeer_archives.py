#!/usr/bin/env python3
"""Preview or remove stale MODUS OVERZEER archives from one release directory."""

from __future__ import annotations

import argparse
import re
from pathlib import Path

VERSION_TEXT = (
    r"(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)"
    r"(?:-([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?"
    r"(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?"
)
VERSION = re.compile(VERSION_TEXT)
ARCHIVE = re.compile(
    rf"^modus-(?P<version>{VERSION_TEXT})-(?P<target>(?:linux|windows)-[a-z0-9][a-z0-9._-]*)"
    r"\.(?P<format>tar\.zst|tar\.gz|zip)$"
)


def fail(message: str) -> None:
    raise ValueError(message)


def stale_archives(root: Path, keep_version: str) -> list[Path]:
    if VERSION.fullmatch(keep_version) is None:
        fail("keep-version must be semantic version text")
    if not root.is_dir() or root.is_symlink():
        fail(f"release root must be a regular directory: {root}")
    stale: list[Path] = []
    for path in sorted(root.iterdir()):
        if not path.is_file() or path.is_symlink():
            continue
        match = ARCHIVE.fullmatch(path.name)
        if match and match.group("version") != keep_version:
            stale.append(path)
    return stale


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, required=True)
    parser.add_argument("--keep-version", required=True)
    parser.add_argument("--apply", action="store_true")
    try:
        args = parser.parse_args()
        stale = stale_archives(args.root.absolute(), args.keep_version)
        action = "remove" if args.apply else "would-remove"
        for path in stale:
            print(f"{action}: {path}")
        if args.apply:
            for path in stale:
                path.unlink()
        print(f"PASS: {action} {len(stale)} obsolete OVERZEER archive(s)")
    except (OSError, ValueError) as error:
        print(f"FAIL: {error}")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
