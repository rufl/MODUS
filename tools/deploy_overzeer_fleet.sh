#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
OVERZEER_ROOT="${OVERZEER_ROOT:-$ROOT/../../OVERZEER}"
FLEET="$OVERZEER_ROOT/tools/overzeer-fleet-dogfood.sh"
if [[ ! -x "$FLEET" ]]; then
  ZEER_ROOT="${ZEER_ROOT:-$ROOT/../../ZEER}"
  FLEET="$ZEER_ROOT/tools/zeer-fleet-dogfood.sh"
fi
ACTION=preview
APPLICATION="${OVERZEER_APPLICATION:-modus}"
VERSION="${OVERZEER_VERSION:-0.9.5-beta}"
BUILD_ID="${OVERZEER_BUILD_ID:-$(git -C "$ROOT" rev-parse HEAD)}"
BASE_URL="${OVERZEER_DOWNLOAD_BASE_URL:-}"
DDJARIN_BASE_URL="${OVERZEER_DDJARIN_DOWNLOAD_BASE_URL:-$BASE_URL}"
CHOPPER_BASE_URL="${OVERZEER_CHOPPER_DOWNLOAD_BASE_URL:-$BASE_URL}"
WINDOWS_PACKAGE="${OVERZEER_WINDOWS_PACKAGE:-$ROOT/build/release/modus-$VERSION-windows-x86_64.zip}"
LINUX_PACKAGE="${OVERZEER_LINUX_PACKAGE:-$ROOT/build/release/modus-$VERSION-linux-x86_64.tar.gz}"
TOKEN_FILE="${OVERZEER_TOKEN_FILE:-}"
DDJARIN_TOKEN_FILE="${OVERZEER_DDJARIN_TOKEN_FILE:-}"
CHOPPER_TOKEN_FILE="${OVERZEER_CHOPPER_TOKEN_FILE:-}"
usage() {
  cat <<'EOF'
Usage: tools/deploy_overzeer_fleet.sh [preview|deploy] [options]

Prepare or deploy the current MODUS Windows/Linux candidates through the
registered DDJARIN and CHOPPER OVERZEER receivers. Preview is the default.

Options:
  --application NAME       registered application (default: modus)
  --version VERSION        package version (default: 0.9.5-beta)
  --build-id ID            immutable build identity (default: current Git HEAD)
  --base-url HTTPS_URL     one HTTPS URL for both receivers
  --ddjarin-base-url URL   DDJARIN HTTPS metadata/download base URL
  --chopper-base-url URL   CHOPPER HTTPS metadata/download base URL
  --windows-package PATH   Windows .zip candidate
  --linux-package PATH     Linux .tar.gz candidate
  --token-file PATH        one owner-private token for both receivers
  --ddjarin-token-file PATH  DDJARIN owner-private token
  --chopper-token-file PATH  CHOPPER owner-private token
  --apply                  equivalent to deploy; requires OVERZEER_CONFIRM=DEPLOY
  --help

Credential files are never read by this wrapper. If token options are omitted,
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
    --base-url) BASE_URL="$2"; DDJARIN_BASE_URL="$2"; CHOPPER_BASE_URL="$2"; shift ;;
    --ddjarin-base-url) DDJARIN_BASE_URL="$2"; shift ;;
    --chopper-base-url) CHOPPER_BASE_URL="$2"; shift ;;
    --windows-package) WINDOWS_PACKAGE="$2"; shift ;;
    --linux-package) LINUX_PACKAGE="$2"; shift ;;
    --token-file) TOKEN_FILE="$2"; shift ;;
    --ddjarin-token-file) DDJARIN_TOKEN_FILE="$2"; shift ;;
    --chopper-token-file) CHOPPER_TOKEN_FILE="$2"; shift ;;
    --help|-h) usage; exit 0 ;;
    *) printf 'deploy_overzeer_fleet: unknown argument: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

[[ -x "$FLEET" ]] || {
  printf 'deploy_overzeer_fleet: missing executable fleet helper: %s\n' "$FLEET" >&2
  exit 1
}
[[ -n "$DDJARIN_BASE_URL" && -n "$CHOPPER_BASE_URL" ]] || {
  echo 'deploy_overzeer_fleet: --base-url or both receiver base URLs are required' >&2
  exit 2
}
for base_url in "$DDJARIN_BASE_URL" "$CHOPPER_BASE_URL"; do
  [[ "$base_url" == https://* ]] || {
    echo 'deploy_overzeer_fleet: receiver base URLs must use HTTPS' >&2
    exit 2
  }
done
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

args=("$ACTION" --application "$APPLICATION" --version "$VERSION" --build-id "$BUILD_ID" --ddjarin-base-url "$DDJARIN_BASE_URL" --chopper-base-url "$CHOPPER_BASE_URL" --windows-package "$WINDOWS_PACKAGE" --linux-package "$LINUX_PACKAGE")
[[ -z "$TOKEN_FILE" ]] || args+=(--token-file "$TOKEN_FILE")
[[ -z "$DDJARIN_TOKEN_FILE" ]] || args+=(--ddjarin-token-file "$DDJARIN_TOKEN_FILE")
[[ -z "$CHOPPER_TOKEN_FILE" ]] || args+=(--chopper-token-file "$CHOPPER_TOKEN_FILE")
"$FLEET" "${args[@]}"
