#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/modus-windows-acceptance-metadata.XXXXXX")"
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
evidence = temporary / "evidence"
evidence.mkdir()
lock = evidence / "toolchain.lock.json"
shutil.copy2(root / "tools/toolchain.lock.json", lock)
lock_hash = hashlib.sha256(lock.read_bytes()).hexdigest()
(evidence / "build-metadata.json").write_text(
    json.dumps({"toolchain_lock": "toolchain.lock.json", "toolchain_lock_sha256": lock_hash}),
    encoding="utf-8",
)
(evidence / "native-windows-acceptance.json").write_text(
    json.dumps(
        {
            "metadata": "build-metadata.json",
            "toolchain_lock": "toolchain.lock.json",
            "toolchain_lock_sha256": lock_hash,
        }
    ),
    encoding="utf-8",
)
validator = root / "tools/validate_windows_acceptance_metadata.ps1"

def invoke(passes: bool) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(
        ["pwsh", "-NoProfile", "-File", validator, "-EvidenceDirectory", evidence],
        text=True,
        capture_output=True,
    )
    assert (result.returncode == 0) is passes, (result.stdout, result.stderr)
    return result

passed = invoke(True)
assert "PASS: native acceptance metadata binds" in passed.stdout
metadata = evidence / "build-metadata.json"
metadata.write_text(
    metadata.read_text(encoding="utf-8").replace(lock_hash, "0" * 64),
    encoding="utf-8",
)
failed = invoke(False)
assert "Build metadata toolchain lock hash" in failed.stderr
print("Windows acceptance metadata binding regression passed.")
PY
