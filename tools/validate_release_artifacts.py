#!/usr/bin/env python3
"""Generate or verify portable, unsigned MODUS release artifact manifests."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import stat
import sys
from pathlib import Path, PurePosixPath

VERSION = re.compile(
    r"(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)"
    r"(?:-((?:0|[1-9][0-9]*|[0-9]*[A-Za-z-][0-9A-Za-z-]*)"
    r"(?:\.(?:0|[1-9][0-9]*|[0-9]*[A-Za-z-][0-9A-Za-z-]*))*))?"
    r"(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?"
)
ROLES = ("client", "server", "editor")
KINDS = ("executable", "content")


class ArgumentParser(argparse.ArgumentParser):
    def error(self, message: str) -> None:
        raise ValueError(message)


def digest(path: Path) -> str:
    hasher = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            hasher.update(chunk)
    return hasher.hexdigest()


def safe_path(path: Path) -> Path:
    """Keep lexical paths intact until every ancestor has been checked."""
    if ".." in path.parts:
        raise ValueError(f"path traversal is not allowed: {path}")
    path = path.absolute()
    for part in (*reversed(path.parents), path):
        if part.is_symlink():
            raise ValueError(f"symlinks are not allowed: {part}")
    return path


def contained_path(path: Path, root: Path) -> Path:
    path = safe_path(path)
    if not path.is_relative_to(root) or path == root:
        raise ValueError(f"artifact path must be contained in root {root}: {path}")
    relative = path.relative_to(root).as_posix()
    if "\\" in relative or ":" in relative:
        raise ValueError(f"artifact path is not portable: {path}")
    return path


def portable_path(value: object, root: Path) -> Path:
    if not isinstance(value, str) or not value or "\\" in value or ":" in value:
        raise ValueError("manifest path must be a non-empty relative POSIX path")
    path = PurePosixPath(value)
    if path.is_absolute() or any(part in ("", ".", "..") for part in value.split("/")):
        raise ValueError(f"manifest path is not canonical or escapes root: {value}")
    return contained_path(root / value, root)


def artifact(path: Path, root: Path, executable: bool = False) -> dict[str, object]:
    info = path.stat()
    if not stat.S_ISREG(info.st_mode) or info.st_size <= 0:
        raise ValueError(f"artifact must be a non-empty regular file: {path}")
    if executable and path.suffix.lower() != ".exe" and not info.st_mode & stat.S_IXUSR:
        raise ValueError(f"artifact is not executable: {path}")
    return {
        "path": path.relative_to(root).as_posix(),
        "bytes": info.st_size,
        "sha256": digest(path),
    }


def unique_path(path: Path, seen: set[tuple[int, int]]) -> None:
    info = path.stat()
    identity = (info.st_dev, info.st_ino)
    if identity in seen:
        raise ValueError(f"duplicate artifact or signature path: {path}")
    seen.add(identity)


def content_path(executable: Path, root: Path) -> Path:
    candidates = dict.fromkeys(
        (executable.with_suffix(".pck"), Path(str(executable) + ".pck"))
    )
    found = []
    for candidate in candidates:
        candidate = contained_path(candidate, root)
        if candidate.exists():
            found.append(candidate)
    if len(found) != 1:
        raise ValueError(f"expected one PCK for {executable}; found {len(found)}")
    return found[0]


def validate_identity(manifest: dict[str, object]) -> None:
    version = manifest.get("version")
    if not isinstance(version, str) or VERSION.fullmatch(version) is None:
        raise ValueError("version must be semantic version text")
    if "commit" in manifest and (
        not isinstance(manifest["commit"], str)
        or re.fullmatch(r"[0-9a-fA-F]{7,64}", manifest["commit"]) is None
    ):
        raise ValueError(
            "commit must be a hexadecimal Git commit SHA (7–64 characters)"
        )
    if "godot_version" in manifest and (
        not isinstance(manifest["godot_version"], str)
        or not manifest["godot_version"].strip()
    ):
        raise ValueError("godot_version must be non-empty version text")


def verify_record(
    record: object, root: Path, seen: set[tuple[int, int]], *, payload: bool
) -> tuple[str, str] | None:
    fields = {"path", "bytes", "sha256"} | ({"role", "kind"} if payload else set())
    if not isinstance(record, dict) or record.keys() != fields:
        raise ValueError("artifact or signature record has invalid fields")
    pair = None
    if payload:
        if record["role"] not in ROLES or record["kind"] not in KINDS:
            raise ValueError("artifact role or kind is invalid")
        pair = (record["role"], record["kind"])
    if type(record["bytes"]) is not int or record["bytes"] <= 0:
        raise ValueError("artifact bytes must be a positive integer")
    if (
        not isinstance(record["sha256"], str)
        or re.fullmatch(r"[0-9a-f]{64}", record["sha256"]) is None
    ):
        raise ValueError("artifact sha256 must be a lowercase SHA-256 hex digest")
    path = portable_path(record["path"], root)
    unique_path(path, seen)
    actual = artifact(path, root, executable=payload and record["kind"] == "executable")
    if actual["bytes"] != record["bytes"] or actual["sha256"] != record["sha256"]:
        raise ValueError(f"artifact size or SHA-256 mismatch: {record['path']}")
    return pair


def json_object(pairs: list[tuple[str, object]]) -> dict[str, object]:
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f"duplicate JSON field: {key}")
        result[key] = value
    return result


def verify(manifest_path: Path, root: Path) -> dict[str, object]:
    manifest_path = safe_path(manifest_path)
    if not manifest_path.is_file():
        raise ValueError(f"manifest must be a regular file: {manifest_path}")
    with manifest_path.open(encoding="utf-8") as stream:
        manifest = json.load(stream, object_pairs_hook=json_object)
    required = {"schema_version", "product", "version", "certified", "artifacts"}
    optional = {"commit", "godot_version", "signature"}
    if (
        not isinstance(manifest, dict)
        or not required <= manifest.keys()
        or manifest.keys() - required - optional
    ):
        raise ValueError("manifest has invalid or missing fields")
    if type(manifest["schema_version"]) is not int or manifest["schema_version"] != 1:
        raise ValueError("unsupported manifest schema_version (expected 1)")
    if manifest["product"] != "MODUS" or manifest["certified"] is not False:
        raise ValueError("manifest must describe MODUS with certified false")
    validate_identity(manifest)
    if not isinstance(manifest["artifacts"], list) or len(manifest["artifacts"]) != 6:
        raise ValueError(
            "manifest must contain exactly one executable and content artifact per role"
        )
    seen = set()
    pairs = set()
    for record in manifest["artifacts"]:
        pair = verify_record(record, root, seen, payload=True)
        if pair in pairs:
            raise ValueError(f"duplicate role/kind pair: {pair}")
        pairs.add(pair)
    if pairs != {(role, kind) for role in ROLES for kind in KINDS}:
        raise ValueError(
            "manifest must contain exactly one executable and content artifact per role"
        )
    if "signature" in manifest:
        verify_record(manifest["signature"], root, seen, payload=False)
    return manifest


def generate(args: argparse.Namespace, root: Path) -> dict[str, object]:
    manifest = {
        "schema_version": 1,
        "product": "MODUS",
        "version": args.version,
        "certified": False,
    }
    for option in ("commit", "godot_version"):
        if getattr(args, option) is not None:
            manifest[option] = getattr(args, option)
    validate_identity(manifest)
    records = []
    inputs = []
    seen = set()
    for role in ROLES:
        executable = contained_path(getattr(args, role), root)
        for kind, path in (
            ("executable", executable),
            ("content", content_path(executable, root)),
        ):
            unique_path(path, seen)
            records.append(
                {
                    "role": role,
                    "kind": kind,
                    **artifact(path, root, executable=kind == "executable"),
                }
            )
            inputs.append(path)
    manifest["artifacts"] = records
    if args.signature is not None:
        signature = contained_path(args.signature, root)
        unique_path(signature, seen)
        manifest["signature"] = artifact(signature, root)
        inputs.append(signature)
    output = safe_path(args.output)
    if output in inputs or (
        output.exists() and any(output.samefile(path) for path in inputs)
    ):
        raise ValueError("output must not overwrite an input artifact or signature")
    if output.exists() and not output.is_file():
        raise ValueError(f"output must be a regular file: {output}")
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    return manifest


def failure(message: str) -> int:
    print(
        json.dumps(
            {"outcome": "failed", "error": message, "certified": False}, indent=2
        ),
        file=sys.stderr,
    )
    return 1


def main() -> int:
    parser = ArgumentParser(description=__doc__)
    parser.add_argument("--verify", type=Path, metavar="MANIFEST")
    parser.add_argument(
        "--root", type=Path, help="payload root; defaults to manifest/output parent"
    )
    parser.add_argument("--version")
    for name in (*ROLES, "output", "signature"):
        parser.add_argument(f"--{name}", type=Path)
    parser.add_argument("--commit")
    parser.add_argument("--godot-version")
    try:
        args = parser.parse_args()
        generation_options = (
            "version",
            *ROLES,
            "output",
            "signature",
            "commit",
            "godot_version",
        )
        if args.verify is not None:
            if any(getattr(args, option) is not None for option in generation_options):
                raise ValueError(
                    "--verify is mutually exclusive with generation options"
                )
            root = safe_path(args.root if args.root is not None else args.verify.parent)
            manifest = verify(args.verify, root)
        else:
            missing = [
                f"--{option}"
                for option in ("version", *ROLES, "output")
                if getattr(args, option) is None
            ]
            if missing:
                raise ValueError("generation requires " + ", ".join(missing))
            root = safe_path(args.root if args.root is not None else args.output.parent)
            manifest = generate(args, root)
    except (ValueError, OSError, RuntimeError) as error:
        return failure(str(error))
    print(
        json.dumps(
            {
                "outcome": "passed",
                "version": manifest["version"],
                "artifactCount": len(manifest["artifacts"]),
                "signatureProvided": "signature" in manifest,
                "certified": False,
            },
            indent=2,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
