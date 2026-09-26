#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GODOT_BIN="${MODUS_GODOT_BIN:-godot}"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/modus-windows-qualification.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

set +e
"$GODOT_BIN" --headless --path "$ROOT" -- --windows-qualification >"$TMP/output.log" 2>&1
status=$?
set -e

python3 - "$TMP/output.log" "$status" <<'PY'
import json
import sys
from pathlib import Path

output = Path(sys.argv[1]).read_text(encoding="utf-8")
status = int(sys.argv[2])
prefix = "MODUS_WINDOWS_QUALIFICATION_JSON="
reports = [line.removeprefix(prefix) for line in output.splitlines() if line.startswith(prefix)]
assert reports, output
report = json.loads(reports[-1])
assert report["schema"] == "modus.windows-client-qualification/v1"
assert report["os"] != "Windows"
assert report["status"] == "fail"
assert status != 0
assert set(report["checks"]) == {"platform", "renderer", "input", "save", "network"}
assert report["checks"]["platform"]["status"] == "fail"
assert report["checks"]["renderer"]["status"] == "fail"
assert report["checks"]["save"]["status"] == "pass"
assert report["checks"]["save"]["details"]["save_service_available"]
assert report["checks"]["save"]["details"]["loaded_matches"]
assert report["checks"]["network"]["status"] == "pass"
print("Windows qualification native-boundary regression passed.")
PY
