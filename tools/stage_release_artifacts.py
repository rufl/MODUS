#!/usr/bin/env python3
"""Stage a verified MODUS release candidate without publishing or certifying it."""

from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

VALIDATOR = Path(__file__).with_name("validate_release_artifacts.py")


def verify(manifest: Path, root: Path) -> None:
    result = subprocess.run(
        [
            sys.executable,
            str(VALIDATOR),
            "--verify",
            str(manifest),
            "--root",
            str(root),
        ],
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode:
        raise ValueError(result.stderr.strip() or "Artifact verification failed")


def stage(manifest_path: Path, root: Path, output: Path) -> None:
    manifest_text = manifest_path.read_text(encoding="utf-8")
    manifest = json.loads(manifest_text)
    # Validate the same snapshot we consume; do not reopen mutable input afterwards.
    with tempfile.TemporaryDirectory(prefix="modus-manifest-") as snapshot_dir:
        snapshot = Path(snapshot_dir) / "manifest.json"
        snapshot.write_text(manifest_text, encoding="utf-8")
        verify(snapshot, root)
    if not manifest.get("commit") or not manifest.get("godot_version"):
        raise ValueError(
            "Staging requires manifest commit and godot_version build identity"
        )
    if output.exists() or output.is_symlink():
        raise ValueError(f"Refusing to replace an existing destination: {output}")
    # The candidate owns a manifest beside its payload, never inside an artifact.
    records = list(manifest["artifacts"])
    if manifest.get("signature"):
        records.append(manifest["signature"])
    if any(Path(record["path"]).parts[0] == "manifest.json" for record in records):
        raise ValueError("Artifact paths conflict with the staged manifest.json")
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(
        prefix=".modus-stage-", dir=output.parent
    ) as temporary:
        candidate = Path(temporary) / "candidate"
        candidate.mkdir()
        for record in records:
            source = root / record["path"]
            destination = candidate / record["path"]
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, destination, follow_symlinks=False)
        # Retain the validated document, not a source file that may have changed.
        staged_manifest = candidate / "manifest.json"
        staged_manifest.write_text(
            json.dumps(manifest, indent=2) + "\n", encoding="utf-8"
        )
        verify(staged_manifest, candidate)
        # Claim the destination before committing, including against concurrent stages.
        output.mkdir()
        try:
            os.replace(candidate, output)
        except OSError:
            output.rmdir()
            raise
    print(
        json.dumps(
            {
                "outcome": "passed",
                "candidate": str(output),
                "version": manifest["version"],
                "commit": manifest["commit"],
                "certified": False,
                "published": False,
            },
            indent=2,
        )
    )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument(
        "--root", type=Path, help="Source payload root; defaults to manifest parent"
    )
    parser.add_argument(
        "--output", type=Path, required=True, help="New candidate directory"
    )
    args = parser.parse_args()
    try:
        root = (args.root or args.manifest.absolute().parent).absolute()
        stage(args.manifest.absolute(), root, args.output.absolute())
    except (OSError, ValueError) as error:
        print(
            json.dumps(
                {
                    "outcome": "failed",
                    "error": str(error),
                    "certified": False,
                    "published": False,
                },
                indent=2,
            ),
            file=sys.stderr,
        )
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
