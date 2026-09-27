#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
godot_bin="${MODUS_GODOT_BIN:-godot}"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/modus-package-smoke.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT

set +e
timeout 120s "$godot_bin" --headless --audio-driver Dummy --path "$root" -- --package-smoke \
    >"$tmp/package-smoke.log" 2>&1
status=$?
set -e

python3 - "$tmp/package-smoke.log" "$status" <<'PY'
from pathlib import Path
import sys

log = Path(sys.argv[1]).read_text(encoding="utf-8", errors="replace")
status = int(sys.argv[2])
assert status == 0, log
assert "SCRIPT ERROR" not in log, log
assert "Package smoke" not in log or "missing" not in log, log
print("Package smoke user-argument regression passed.")
PY
