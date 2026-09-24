#!/usr/bin/env bash
set -euo pipefail

ROOT=$(mktemp -d /tmp/modus-cleanup-test.XXXXXX)
trap 'rm -rf "$ROOT"' EXIT

python3 - "$ROOT" <<'PY'
from pathlib import Path
import sys

root = Path(sys.argv[1])
for name in (
    "modus-0.9.4-beta-linux-x86_64.tar.zst",
    "modus-0.9.4-beta-windows-x86_64.zip",
    "modus-0.9.5-beta-linux-x86_64.tar.zst",
    "modus-0.9.5-beta-windows-x86_64.zip",
    "overzeer-release.json",
):
    (root / name).write_bytes(b"fixture")
PY

PREVIEW=$(python3 tools/cleanup_overzeer_archives.py \
    --root "$ROOT" --keep-version 0.9.5-beta)
case "$PREVIEW" in
    *"would-remove: $ROOT/modus-0.9.4-beta-linux-x86_64.tar.zst"*) ;;
    *) echo "preview omitted stale Linux archive" >&2; exit 1 ;;
esac
case "$PREVIEW" in
    *"would-remove: $ROOT/modus-0.9.4-beta-windows-x86_64.zip"*) ;;
    *) echo "preview omitted stale Windows archive" >&2; exit 1 ;;
esac
test -f "$ROOT/modus-0.9.4-beta-linux-x86_64.tar.zst"
test -f "$ROOT/modus-0.9.5-beta-linux-x86_64.tar.zst"

python3 tools/cleanup_overzeer_archives.py \
    --root "$ROOT" --keep-version 0.9.5-beta --apply >/dev/null

test ! -e "$ROOT/modus-0.9.4-beta-linux-x86_64.tar.zst"
test ! -e "$ROOT/modus-0.9.4-beta-windows-x86_64.zip"
test -f "$ROOT/modus-0.9.5-beta-linux-x86_64.tar.zst"
test -f "$ROOT/modus-0.9.5-beta-windows-x86_64.zip"
test -f "$ROOT/overzeer-release.json"

if python3 tools/cleanup_overzeer_archives.py \
    --root "$ROOT" --keep-version not-a-version >/dev/null 2>&1; then
    echo "expected invalid version to fail" >&2
    exit 1
fi

printf 'PASS: cleanup preview, apply, preservation, and validation\n'
