#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GODOT_BIN="${MODUS_GODOT_BIN:-godot}"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/modus-windows-qualification.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

set +e
"$GODOT_BIN" --headless --path "$ROOT" -- --windows-qualification >"$TMP/output.log" 2>&1
status=$?
"$GODOT_BIN" --headless --path "$ROOT" -- --windows-qualification --windows-qualification-content \
	>"$TMP/content-output.log" 2>&1
content_status=$?
set -e

python3 - "$TMP/output.log" "$status" "$TMP/content-output.log" "$content_status" <<'PY'
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
assert set(report["checks"]) == {"platform", "renderer", "input", "save", "content_workflow", "network"}
assert report["checks"]["platform"]["status"] == "fail"
assert report["checks"]["renderer"]["status"] == "fail"
assert report["checks"]["input"]["status"] == "pass"
assert not report["checks"]["input"]["details"]["physical_input_requested"]
assert report["checks"]["save"]["status"] == "pass"
assert report["checks"]["save"]["details"]["save_service_available"]
assert report["checks"]["save"]["details"]["loaded_matches"]
content_output = Path(sys.argv[3]).read_text(encoding="utf-8")
content_status = int(sys.argv[4])
content_reports = [
	line.removeprefix(prefix)
	for line in content_output.splitlines()
	if line.startswith(prefix)
]
assert content_reports, content_output
content_report = json.loads(content_reports[-1])
assert content_status != 0
assert content_report["status"] == "fail"
assert content_report["checks"]["content_workflow"]["status"] == "pass"
assert content_report["checks"]["content_workflow"]["details"]["scene_loaded"]
assert content_report["checks"]["content_workflow"]["details"]["player_ready"]
assert content_report["checks"]["content_workflow"]["details"]["player_spawned"]
assert content_report["checks"]["content_workflow"]["details"]["moved"]
assert content_report["checks"]["content_workflow"]["details"]["weapon_fired"]
assert content_report["checks"]["content_workflow"]["details"]["enemy_defeated"]
assert content_report["checks"]["content_workflow"]["details"]["pickup_collected"]
assert content_report["checks"]["content_workflow"]["details"]["save_loaded"]
assert content_report["checks"]["content_workflow"]["details"]["mod_loaded"]
assert report["checks"]["content_workflow"]["status"] == "pass"
assert report["checks"]["content_workflow"]["details"]["status"] == "not_requested"
assert report["checks"]["network"]["status"] == "pass"
print("Windows qualification native-boundary regression passed.")
PY
