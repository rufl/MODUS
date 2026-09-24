#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
OVERZEER_ROOT="${OVERZEER_ROOT:-$ROOT/../../OVERZEER}"
FLEET="$OVERZEER_ROOT/tools/overzeer-fleet-dogfood.sh"
ACTION=preview
APPLICATION="${OVERZEER_APPLICATION:-modus}"
VERSION="${OVERZEER_VERSION:-0.9.5-beta}"
BUILD_ID="${OVERZEER_BUILD_ID:-$(git -C "$ROOT" rev-parse HEAD)}"
BASE_URL="${OVERZEER_DOWNLOAD_BASE_URL:-}"
WINDOWS_PACKAGE="${OVERZEER_WINDOWS_PACKAGE:-$ROOT/build/release/modus-$VERSION-windows-x86_64.zip}"
LINUX_PACKAGE="${OVERZEER_LINUX_PACKAGE:-$ROOT/build/release/modus-$VERSION-linux-x86_64.tar.gz}"
TOKEN_FILE="${OVERZEER_TOKEN_FILE:-}"

usage() {
  cat <<'EOF'
Usage: tools/deploy_overzeer_fleet.sh [preview|deploy] [options]

Prepare or deploy the current MODUS Windows/Linux candidates through the
registered DDJARIN and CHOPPER OVERZEER receivers. Preview is the default.

Options:
  --application NAME       registered application (default: modus)
  --version VERSION        package version (default: 0.9.5-beta)
  --build-id ID            immutable build identity (default: current Git HEAD)
  --base-url HTTPS_URL     package metadata/download base URL (required)
  --windows-package PATH   Windows .zip candidate
  --linux-package PATH     Linux .tar.gz candidate
  --token-file PATH        one owner-private token for both receivers
  --apply                  equivalent to deploy; requires OVERZEER_CONFIRM=DEPLOY
  --help

Credential files are never read by this wrapper. If --token-file is omitted,
the OVERZEER fleet helper resolves private tokens from its canonical oztok
root: C:/lichforge/oztok on Windows shells or $HOME/lichforge/oztok on POSIX.
EOF
}

while (($#)); do
  case "$1" in
    preview|deploy) ACTION="$1" ;;
    --application) APPLICATION="$2"; shift ;;
    --version) VERSION="$2"; shift ;;
    --build-id) BUILD_ID="$2"; shift ;;
    --base-url) BASE_URL="$2"; shift ;;
    --windows-package) WINDOWS_PACKAGE="$2"; shift ;;
    --linux-package) LINUX_PACKAGE="$2"; shift ;;
    --token-file) TOKEN_FILE="$2"; shift ;;
    --apply) ACTION=deploy ;;
    --help|-h) usage; exit 0 ;;
    *) printf 'deploy_overzeer_fleet: unknown argument: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

[[ -x "$FLEET" ]] || {
  printf 'deploy_overzeer_fleet: missing executable fleet helper: %s\n' "$FLEET" >&2
  exit 1
}
[[ -n "$BASE_URL" ]] || {
  echo 'deploy_overzeer_fleet: --base-url or OVERZEER_DOWNLOAD_BASE_URL is required' >&2
  exit 2
}
[[ "$BASE_URL" == https://* ]] || {
  echo 'deploy_overzeer_fleet: base URL must use HTTPS' >&2
  exit 2
}
[[ -f "$WINDOWS_PACKAGE" && ! -L "$WINDOWS_PACKAGE" ]] || {
  printf 'deploy_overzeer_fleet: missing Windows package: %s\n' "$WINDOWS_PACKAGE" >&2
  exit 1
}
[[ -f "$LINUX_PACKAGE" && ! -L "$LINUX_PACKAGE" ]] || {
  printf 'deploy_overzeer_fleet: missing Linux package: %s\n' "$LINUX_PACKAGE" >&2
  exit 1
}
case "$WINDOWS_PACKAGE" in *.zip) ;; *) echo 'deploy_overzeer_fleet: Windows package must be .zip' >&2; exit 2 ;; esac
case "$LINUX_PACKAGE" in *.tar.gz) ;; *) echo 'deploy_overzeer_fleet: Linux package must be .tar.gz' >&2; exit 2 ;; esac

args=("$ACTION" --application "$APPLICATION" --version "$VERSION" --build-id "$BUILD_ID" --base-url "$BASE_URL" --windows-package "$WINDOWS_PACKAGE" --linux-package "$LINUX_PACKAGE")
[[ -z "$TOKEN_FILE" ]] || args+=(--token-file "$TOKEN_FILE")
"$FLEET" "${args[@]}"
