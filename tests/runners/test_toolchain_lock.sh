#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/modus_toolchain_lock.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT

python3 - "$root" "$tmp" <<'PY'
from __future__ import annotations

import shutil
import subprocess
import sys
from pathlib import Path

root, fixture_root = map(Path, sys.argv[1:])
relative_files = (
    "tools/toolchain.lock.json",
    ".github/workflows/ci.yml",
    ".github/workflows/code-quality.yml",
    "tools/scripts/install-gut.sh",
    "tools/godot/build.sh",
    "tools/godot/requirements.txt",
)
for relative in relative_files:
    destination = fixture_root / relative
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(root / relative, destination)

validator = root / "tools/validate_toolchain_lock.py"

def invoke(passes: bool) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(
        [sys.executable, validator, "--root", fixture_root],
        text=True,
        capture_output=True,
    )
    assert (result.returncode == 0) is passes, (result.stdout, result.stderr)
    return result

passed = invoke(True)
assert "Toolchain lock passed" in passed.stdout

ci = fixture_root / ".github/workflows/ci.yml"
ci.write_text(ci.read_text(encoding="utf-8").replace('GODOT_VERSION: "4.7.2"', 'GODOT_VERSION: "4.7.1"', 1), encoding="utf-8")
failed = invoke(False)
assert "GODOT_VERSION" in failed.stderr

shutil.copy2(root / ".github/workflows/ci.yml", ci)
lock = fixture_root / "tools/toolchain.lock.json"
lock.write_text(lock.read_text(encoding="utf-8").replace("6da99c4e9228d9bec3fb4bd1730a487770a989f0f511dac82a2897a964613385", "0" * 64, 1), encoding="utf-8")
failed = invoke(False)
assert "GUT archive hash" in failed.stderr

print("Toolchain lock regression passed.")
PY
