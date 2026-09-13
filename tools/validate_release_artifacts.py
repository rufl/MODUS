#!/usr/bin/env python3
"""Validate versioned MODUS client, server, and editor artifact inputs."""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import stat
import sys
from pathlib import Path

VERSION = re.compile(r"^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(?:-[0-9A-Za-z.-]+)?$")


def digest(path: Path) -> str:
    hasher = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            hasher.update(chunk)
    return hasher.hexdigest()


def artifact(path: Path, role: str) -> dict[str, object]:
    if not path.is_file() or path.stat().st_size == 0:
        raise ValueError(f"{role} artifact is missing or empty: {path}")
    if role != "content" and not (path.stat().st_mode & stat.S_IXUSR):
        raise ValueError(f"{role} artifact is not executable: {path}")
    return {"role": role, "path": str(path), "bytes": path.stat().st_size, "sha256": digest(path)}


def failure(message: str) -> int:
    print(json.dumps({"outcome": "failed", "error": message, "certified": False}, indent=2), file=sys.stderr)
    return 1


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--version", required=True)
    parser.add_argument("--client", type=Path, required=True)
    parser.add_argument("--server", type=Path, required=True)
    parser.add_argument("--editor", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--signature", type=Path)
    args = parser.parse_args()

    if not VERSION.fullmatch(args.version):
        return failure("--version must be semantic version text")
    if args.signature is not None and (not args.signature.is_file() or args.signature.stat().st_size == 0):
        return failure("--signature must name a non-empty detached signature")

    try:
        records = []
        for role, executable in (("client", args.client), ("server", args.server), ("editor", args.editor)):
            records.append(artifact(executable.resolve(), role))
            content = executable.with_suffix(executable.suffix + ".pck")
            if not content.is_file():
                sibling = executable.with_name(executable.name + ".pck")
                content = sibling if sibling.is_file() else executable.with_suffix(".pck")
            records.append(artifact(content.resolve(), "content"))
    except ValueError as error:
        return failure(str(error))

    manifest = {
        "product": "MODUS",
        "version": args.version,
        "artifacts": records,
        "signature": str(args.signature.resolve()) if args.signature else None,
        "certified": False,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"outcome": "passed", "version": args.version, "artifactCount": len(records), "signatureProvided": args.signature is not None, "certified": False}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
