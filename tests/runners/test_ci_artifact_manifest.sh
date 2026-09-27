#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/modus-ci-artifact-manifest.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT

python3 - "$root" "$tmp" <<'PY'
from __future__ import annotations

import hashlib
import json
import shutil
import subprocess
import sys
from pathlib import Path

root, temporary = map(Path, sys.argv[1:])
artifact = temporary / "artifact"
artifact.mkdir()
executable = artifact / "MODUS.exe"
content = artifact / "MODUS.pck"
executable.write_bytes(b"windows executable fixture\n")
content.write_bytes(b"pck fixture\n")
for path in (executable, content):
    path.chmod(0o700 if path == executable else 0o600)
(artifact / "SHA256SUMS").write_text(
    "".join(f"{hashlib.sha256(path.read_bytes()).hexdigest()}  {path.name}\n" for path in (executable, content)),
    encoding="utf-8",
)
lock = temporary / "toolchain.lock.json"
shutil.copy2(root / "tools/toolchain.lock.json", lock)
tool = root / "tools/generate_ci_artifact_manifest.py"
manifest_path = artifact / "manifest.json"

def invoke(output: Path, passes: bool) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(
        [
            sys.executable,
            tool,
            "--root",
            artifact,
            "--output",
            output,
            "--platform",
            "windows",
            "--preset",
            "Windows Desktop",
            "--executable",
            "MODUS.exe",
            "--commit",
            "a" * 40,
            "--godot-version",
            "4.7.2",
            "--toolchain-lock",
            lock,
        ],
        text=True,
        capture_output=True,
    )
    assert (result.returncode == 0) is passes, (result.stdout, result.stderr)
    return result

passed = invoke(manifest_path, True)
data = json.loads(manifest_path.read_text(encoding="utf-8"))
assert data["product"] == "MODUS"
assert data["toolchain_lock_sha256"] == hashlib.sha256(lock.read_bytes()).hexdigest()
assert data["artifacts"]["MODUS.exe"] == hashlib.sha256(executable.read_bytes()).hexdigest()
content.write_bytes(b"tampered\n")
failed = invoke(temporary / "tampered.json", False)
assert "SHA-256 mismatch" in failed.stderr
print("CI artifact manifest lock and tamper regression passed.")
PY
