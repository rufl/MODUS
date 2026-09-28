#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
godot_bin="${MODUS_GODOT_BIN:-godot}"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/modus-package-smoke.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT

set +e
timeout 120s "$godot_bin" --headless --audio-driver Dummy --path "$root" -- --package-smoke \
	>"$tmp/package-smoke.log" 2>&1
package_status=$?
timeout 120s "$godot_bin" --headless --audio-driver Dummy --path "$root" -- --capability-report \
	>"$tmp/capability-report.log" 2>&1
capability_status=$?
set -e

python3 - "$tmp/package-smoke.log" "$tmp/capability-report.log" "$package_status" "$capability_status" <<'PY'
from pathlib import Path
import json
import sys

package_log = Path(sys.argv[1]).read_text(encoding="utf-8", errors="replace")
capability_log = Path(sys.argv[2]).read_text(encoding="utf-8", errors="replace")
package_status = int(sys.argv[3])
capability_status = int(sys.argv[4])
assert package_status == 0, package_log
assert capability_status == 0, capability_log
assert "SCRIPT ERROR" not in package_log, package_log
assert "Package smoke" not in package_log or "missing" not in package_log, package_log
report = json.loads(next(line for line in reversed(capability_log.splitlines()) if line.startswith("{")))
assert report["status"] == "pass", report
assert report["contract_version"] == 1, report
assert report["native_classes"]["csg"] == "CSGShape3D", report
assert "walk" in report["capabilities"], report
print("Package smoke user-argument regression passed. Runtime capability-report regression passed.")
PY
