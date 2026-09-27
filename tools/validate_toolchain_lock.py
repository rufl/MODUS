#!/usr/bin/env python3
"""Validate the release toolchain pins used by local and CI workflows."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any

HEX_SHA256 = re.compile(r"^[0-9a-f]{64}$")
VERSION = re.compile(r"^[0-9]+\.[0-9]+\.[0-9]+$")


class LockError(ValueError):
    """A checked-in toolchain contract is invalid or has drifted."""


def mapping(value: Any, name: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        raise LockError(f"{name} must be an object")
    return value


def exact_keys(value: dict[str, Any], expected: set[str], name: str) -> None:
    if set(value) != expected:
        raise LockError(f"{name} fields must be {sorted(expected)}")


def version(value: Any, name: str) -> str:
    if not isinstance(value, str) or VERSION.fullmatch(value) is None:
        raise LockError(f"{name} must be a numeric semantic version")
    return value


def parse_python_version(value: Any) -> str:
    if not isinstance(value, str) or re.fullmatch(r"[0-9]+\.[0-9]+", value) is None:
        raise LockError("python.version must be a numeric major.minor version")
    return value


def sha256(value: Any, name: str) -> str:
    if not isinstance(value, str) or HEX_SHA256.fullmatch(value) is None:
        raise LockError(f"{name} must be a lowercase SHA-256 digest")
    return value


def read_text(root: Path, relative: str) -> str:
    path = root / relative
    try:
        return path.read_text(encoding="utf-8")
    except OSError as error:
        raise LockError(f"cannot read {relative}: {error}") from error


def require_text(text: str, needle: str, source: str) -> None:
    if needle not in text:
        raise LockError(f"{source} is missing pinned text: {needle}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--root",
        type=Path,
        default=Path(__file__).resolve().parents[1],
        help="repository root (default: project root)",
    )
    args = parser.parse_args()
    root = args.root.resolve()

    try:
        lock_path = root / "tools/toolchain.lock.json"
        with lock_path.open(encoding="utf-8") as stream:
            lock = json.load(stream)
        lock = mapping(lock, "toolchain lock")
        exact_keys(lock, {"schema_version", "python", "godot", "gut", "gdtoolkit", "scons"}, "toolchain lock")
        if lock.get("schema_version") != 1:
            raise LockError("unsupported toolchain lock schema_version")

        python_lock = mapping(lock["python"], "python")
        exact_keys(python_lock, {"version"}, "python")
        python_version = parse_python_version(python_lock["version"])

        godot_lock = mapping(lock["godot"], "godot")
        exact_keys(
            godot_lock,
            {
                "version",
                "release",
                "patched_source_revision",
                "linux_x86_64_archive",
                "export_templates_archive",
            },
            "godot",
        )
        godot_version = version(godot_lock["version"], "godot.version")
        release = godot_lock["release"]
        if release != f"{godot_version}-stable":
            raise LockError("godot.release must match godot.version")
        revision = godot_lock["patched_source_revision"]
        if not isinstance(revision, str) or re.fullmatch(r"[0-9a-f]{40}", revision) is None:
            raise LockError("godot.patched_source_revision must be a 40-character lowercase Git SHA")
        archive = mapping(godot_lock["linux_x86_64_archive"], "godot.linux_x86_64_archive")
        exact_keys(archive, {"name", "sha256"}, "godot.linux_x86_64_archive")
        archive_name = archive["name"]
        if archive_name != f"Godot_v{release}_linux.x86_64.zip":
            raise LockError("Godot archive name does not match the locked release")
        archive_sha256 = sha256(archive["sha256"], "godot.linux_x86_64_archive.sha256")
        templates = mapping(godot_lock["export_templates_archive"], "godot.export_templates_archive")
        exact_keys(templates, {"name", "sha256"}, "godot.export_templates_archive")
        templates_name = templates["name"]
        if templates_name != f"Godot_v{release}_export_templates.tpz":
            raise LockError("Godot export-templates archive name does not match the locked release")
        templates_sha256 = sha256(templates["sha256"], "godot.export_templates_archive.sha256")

        gut_lock = mapping(lock["gut"], "gut")
        exact_keys(gut_lock, {"version", "archive_sha256"}, "gut")
        gut_version = version(gut_lock["version"], "gut.version")
        gut_sha256 = sha256(gut_lock["archive_sha256"], "gut.archive_sha256")

        gdtoolkit_lock = mapping(lock["gdtoolkit"], "gdtoolkit")
        exact_keys(gdtoolkit_lock, {"version"}, "gdtoolkit")
        gdtoolkit_version = version(gdtoolkit_lock["version"], "gdtoolkit.version")

        scons_lock = mapping(lock["scons"], "scons")
        exact_keys(scons_lock, {"version", "sha256"}, "scons")
        scons_version = version(scons_lock["version"], "scons.version")
        scons_hashes = scons_lock["sha256"]
        if not isinstance(scons_hashes, list) or not scons_hashes:
            raise LockError("scons.sha256 must be a non-empty list")
        scons_hashes = {sha256(value, "scons.sha256 entry") for value in scons_hashes}

        ci = read_text(root, ".github/workflows/ci.yml")
        quality = read_text(root, ".github/workflows/code-quality.yml")
        gut_script = read_text(root, "tools/scripts/install-gut.sh")
        godot_build = read_text(root, "tools/godot/build.sh")
        requirements = read_text(root, "tools/godot/requirements.txt")

        require_text(ci, f'GODOT_VERSION: "{godot_version}"', ".github/workflows/ci.yml")
        require_text(ci, f'GODOT_LINUX_ARCHIVE_SHA256: "{archive_sha256}"', ".github/workflows/ci.yml")
        require_text(
            ci,
            f'GODOT_EXPORT_TEMPLATES_SHA256: "{templates_sha256}"',
            ".github/workflows/ci.yml",
        )
        for source, text in ((".github/workflows/ci.yml", ci), (".github/workflows/code-quality.yml", quality)):
            versions = re.findall(r"gdtoolkit==([0-9]+\.[0-9]+\.[0-9]+)", text)
            if not versions or set(versions) != {gdtoolkit_version}:
                raise LockError(f"{source} gdtoolkit pins drift from {gdtoolkit_version}: {versions}")
            require_text(text, f"python-version: '{python_version}'", source)
        require_text(ci, 'archive="Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip"', ".github/workflows/ci.yml")
        require_text(ci, 'Godot_v${GODOT_VERSION}-stable_export_templates.tpz', ".github/workflows/ci.yml")

        gut_version_match = re.search(r'^gut_version="([^"]+)"$', gut_script, re.MULTILINE)
        gut_hash_match = re.search(r'^gut_archive_sha256="([^"]+)"$', gut_script, re.MULTILINE)
        if not gut_version_match or gut_version_match.group(1) != gut_version:
            raise LockError("tools/scripts/install-gut.sh GUT version drifted")
        if not gut_hash_match or gut_hash_match.group(1) != gut_sha256:
            raise LockError("tools/scripts/install-gut.sh GUT archive hash drifted")
        require_text(
            gut_script,
            'https://github.com/bitwes/Gut/archive/refs/tags/v${gut_version}.tar.gz',
            "tools/scripts/install-gut.sh",
        )

        revision_match = re.search(r'^revision="([^"]+)"$', godot_build, re.MULTILINE)
        release_match = re.search(r'^release="([^"]+)"$', godot_build, re.MULTILINE)
        if not revision_match or revision_match.group(1) != revision:
            raise LockError("tools/godot/build.sh Godot source revision drifted")
        if not release_match or release_match.group(1) != release:
            raise LockError("tools/godot/build.sh Godot release drifted")

        require_text(requirements, f"SCons=={scons_version}", "tools/godot/requirements.txt")
        requirement_hashes = set(re.findall(r"--hash=sha256:([0-9a-f]{64})", requirements))
        if requirement_hashes != scons_hashes:
            raise LockError("tools/godot/requirements.txt SCons hashes drifted")
    except (OSError, json.JSONDecodeError, LockError) as error:
        print(f"Toolchain lock check failed: {error}", file=sys.stderr)
        return 1

    print(
        "Toolchain lock passed: "
        f"Godot {godot_version} ({release}), GUT {gut_version}, "
        f"gdtoolkit {gdtoolkit_version}, SCons {scons_version}."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
