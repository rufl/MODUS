#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
tmp="$(mktemp -d /tmp/modus_release_validator.XXXXXX)"
trap 'rm -rf "$tmp"' EXIT

for role in client server editor; do
  printf '%s executable\n' "$role" >"$tmp/$role.bin"
  chmod +x "$tmp/$role.bin"
  printf '%s content\n' "$role" >"$tmp/$role.bin.pck"
done
printf 'fixture signature\n' >"$tmp/signature.asc"

"$root/tools/validate_release_artifacts.py" \
  --version 0.9.5-beta \
  --client "$tmp/client.bin" --server "$tmp/server.bin" --editor "$tmp/editor.bin" \
  --signature "$tmp/signature.asc" --output "$tmp/manifest.json" >/dev/null

python3 - "$tmp/manifest.json" <<'PY'
import json
import sys
manifest = json.load(open(sys.argv[1], encoding="utf-8"))

assert manifest["version"] == "0.9.5-beta"
assert len(manifest["artifacts"]) == 6
assert manifest["signature"].endswith("signature.asc")
assert manifest["certified"] is False
PY

set +e
"$root/tools/validate_release_artifacts.py" \
  --version not-semver \
  --client "$tmp/client.bin" --server "$tmp/server.bin" --editor "$tmp/editor.bin" \
  --output "$tmp/invalid.json" >/tmp/modus-release-invalid.out 2>&1
invalid_status=$?
set -e
[[ "$invalid_status" -eq 1 ]]
grep -Fq '"outcome": "failed"' /tmp/modus-release-invalid.out
grep -Fq '"certified": false' /tmp/modus-release-invalid.out
printf 'Release artifact validator self-check passed.\n'
