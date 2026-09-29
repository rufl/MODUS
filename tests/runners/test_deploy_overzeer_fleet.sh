#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/modus-overzeer-fleet.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/fleet/tools"
cat > "$TMP/fleet/tools/overzeer-fleet-dogfood.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$@" > "${FLEET_ARGS_FILE:?}"
SH
chmod +x "$TMP/fleet/tools/overzeer-fleet-dogfood.sh"
printf 'windows candidate\n' > "$TMP/modus-0.1.0-windows-x86_64.zip"
printf 'linux candidate\n' > "$TMP/modus-0.1.0-linux-x86_64.tar.gz"

FLEET_ARGS_FILE="$TMP/args" OVERZEER_ROOT="$TMP/fleet" \
  bash "$ROOT/tools/deploy_overzeer_fleet.sh" preview \
  --application modus --version 0.1.0 \
  --build-id aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa \
  --ddjarin-base-url https://ddjarin.example \
  --chopper-base-url https://chopper.example \
  --windows-package "$TMP/modus-0.1.0-windows-x86_64.zip" \
  --linux-package "$TMP/modus-0.1.0-linux-x86_64.tar.gz" \
  --ddjarin-token-file /tokens/ddjarin.token \
  --chopper-token-file /tokens/chopper.token

python3 - "$TMP/args" "$TMP" <<'PY'
import sys
from pathlib import Path

args = Path(sys.argv[1]).read_text().splitlines()
tmp = sys.argv[2]
expected = [
    "preview",
    "--application", "modus",
    "--version", "0.1.0",
    "--build-id", "a" * 40,
    "--ddjarin-base-url", "https://ddjarin.example",
    "--chopper-base-url", "https://chopper.example",
    "--windows-package", f"{tmp}/modus-0.1.0-windows-x86_64.zip",
    "--linux-package", f"{tmp}/modus-0.1.0-linux-x86_64.tar.gz",
    "--ddjarin-token-file", "/tokens/ddjarin.token",
    "--chopper-token-file", "/tokens/chopper.token",
]
assert args == expected, (args, expected)
print("OVERZEER fleet wrapper separate-endpoint forwarding passed.")
PY
