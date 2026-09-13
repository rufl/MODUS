#!/usr/bin/env python3
"""Check source-controlled Godot resource references without relying on .godot imports."""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

REFERENCE = re.compile(r'(?:\bpath\b|\bpreload\b)\s*[=:]\s*["\']res://([^"\']+)["\']')
ROOTS = ("game", "shared", "standalone", "mods")
TEXT_SUFFIXES = {".gd", ".tscn", ".tres", ".godot", ".cfg", ".json", ".json5"}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path("."))
    args = parser.parse_args()
    root = args.root.resolve()
    missing: list[dict[str, object]] = []
    references = 0
    for relative_root in ROOTS:
        scan_root = root / relative_root
        for source in scan_root.rglob("*"):
            if not source.is_file() or source.suffix.lower() not in TEXT_SUFFIXES:
                continue
            if "tests" in source.relative_to(root).parts:
                continue
            try:
                content = source.read_text(encoding="utf-8")
            except UnicodeDecodeError:
                continue
            for match in REFERENCE.finditer(content):
                references += 1
                target = root / match.group(1)
                if not target.is_file():
                    missing.append({"source": str(source.relative_to(root)), "target": f"res://{match.group(1)}"})
    if missing:
        print(json.dumps({"outcome": "failed", "references": references, "missing": missing, "certified": False}, indent=2), file=sys.stderr)
        return 1
    print(json.dumps({"outcome": "passed", "references": references, "missing": 0, "certified": False}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
