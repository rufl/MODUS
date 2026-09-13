#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  tools/package_linux_portable.sh package --artifact-dir DIR --output FILE [--version VERSION]
  tools/package_linux_portable.sh install --archive FILE --prefix DIR
  tools/package_linux_portable.sh uninstall --prefix DIR
  tools/package_linux_portable.sh verify --prefix DIR

Creates a versioned Linux portable archive, installs it under a caller-owned
prefix, and removes only files recorded by the installation manifest. User
save/config data under XDG_DATA_HOME and XDG_CONFIG_HOME is never removed.
USAGE
}

command_name="${1:-}"
[[ -n "$command_name" ]] || { usage >&2; exit 64; }
shift

artifact_dir=""
output=""
archive=""
prefix=""
version="0.9.5-beta"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --artifact-dir) artifact_dir="${2:-}"; shift 2 ;;
    --output) output="${2:-}"; shift 2 ;;
    --archive) archive="${2:-}"; shift 2 ;;
    --prefix) prefix="${2:-}"; shift 2 ;;
    --version) version="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'Unknown argument: %s\n' "$1" >&2; usage >&2; exit 64 ;;
  esac
done

fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
require_dir() { [[ -d "$1" ]] || fail "directory not found: $1"; }
require_file() { [[ -s "$1" ]] || fail "file missing or empty: $1"; }

case "$command_name" in
  package)
    [[ -n "$artifact_dir" && -n "$output" ]] || { usage >&2; exit 64; }
    require_dir "$artifact_dir"
    require_file "$artifact_dir/modus.x86_64"
    require_file "$artifact_dir/modus.pck"
    [[ -x "$artifact_dir/modus.x86_64" ]] || fail "client executable is not executable"
    tmp_root="$(mktemp -d "${TMPDIR:-/tmp}/modus-portable.XXXXXX")"
    trap 'rm -rf "$tmp_root"' EXIT
    bundle="$tmp_root/modus-linux-${version}"
    mkdir -p "$bundle/bin" "$bundle/licenses"
    install -m 0755 "$artifact_dir/modus.x86_64" "$bundle/bin/modus"
    install -m 0644 "$artifact_dir/modus.pck" "$bundle/bin/modus.pck"
    install -m 0644 LICENSE "$bundle/LICENSE"
    if [[ -d docs/licenses ]]; then cp -a docs/licenses/. "$bundle/licenses/"; fi
    cat > "$bundle/MANIFEST" <<EOF
product=MODUS
version=$version
platform=linux-x86_64
binary=bin/modus
content=bin/modus.pck
save_policy=user-data-preserved
EOF
    mkdir -p "$(dirname "$output")"
    tar -C "$tmp_root" -czf "$output" "modus-linux-${version}"
    printf 'PASS: portable archive %s\n' "$output"
    ;;
  install)
    [[ -n "$archive" && -n "$prefix" ]] || { usage >&2; exit 64; }
    require_file "$archive"
    mkdir -p "$prefix"
    archive_root="$(tar -tzf "$archive" | sed -n '1s#/.*##p')"
    [[ -n "$archive_root" ]] || fail "archive has no root directory"
    install_root="$prefix/modus"
    stage="$(mktemp -d "${prefix}/.modus-install.XXXXXX")"
    trap 'rm -rf "$stage"' EXIT
    tar -xzf "$archive" -C "$stage"
    [[ -f "$stage/$archive_root/MANIFEST" ]] || fail "archive manifest missing"
    rm -rf "$install_root"
    mv "$stage/$archive_root" "$install_root"
    printf '%s\n' "$install_root" > "$prefix/.modus-install-manifest"
    printf 'PASS: installed %s\n' "$install_root"
    ;;
  uninstall)
    [[ -n "$prefix" ]] || { usage >&2; exit 64; }
    manifest="$prefix/.modus-install-manifest"
    require_file "$manifest"
    install_root="$(<"$manifest")"
    [[ "$install_root" == "$prefix/modus" ]] || fail "manifest points outside the owned install root"
    rm -rf "$install_root" "$manifest"
    printf 'PASS: removed owned install files; user data was not touched\n'
    ;;
  verify)
    [[ -n "$prefix" ]] || { usage >&2; exit 64; }
    manifest="$prefix/.modus-install-manifest"
    require_file "$manifest"
    install_root="$(<"$manifest")"
    [[ -x "$install_root/bin/modus" ]] || fail "installed executable missing"
    require_file "$install_root/bin/modus.pck"
    require_file "$install_root/MANIFEST"
    printf 'PASS: install manifest and payload are valid\n'
    ;;
  *)
    printf 'Unknown command: %s\n' "$command_name" >&2
    usage >&2
    exit 64
    ;;
esac
