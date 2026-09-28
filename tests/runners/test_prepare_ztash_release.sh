#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/modus-ztash-preparer.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

python3 - "$TMP" "$ROOT" <<'PY'
from pathlib import Path
import sys
import tarfile
import zipfile

root = Path(sys.argv[1])
project_root = Path(sys.argv[2])
release = root / "release"
release.mkdir()
version = "0.1.0"
linux_root = f"modus-{version}-linux-x86_64"
windows_root = f"modus-{version}-windows-x86_64"
linux_files = {
    "modus.bin": b"linux executable",
    "modus.pck": b"linux content",
    "README.md": b"readme",
    "LICENSE": b"license",
}
windows_files = {
    "modus.exe": b"windows executable",
    "modus.pck": b"windows content",
    "README.md": b"readme",
    "LICENSE": b"license",
}
with tarfile.open(release / f"modus-{version}-linux-x86_64.tar.gz", "w:gz") as archive:
    for name, content in linux_files.items():
        info = tarfile.TarInfo(f"{linux_root}/{name}")
        info.size = len(content)
        info.mode = 0o755 if name == "modus.bin" else 0o644
        archive.addfile(info, __import__("io").BytesIO(content))
with zipfile.ZipFile(release / f"modus-{version}-windows-x86_64.zip", "w") as archive:
    for name, content in windows_files.items():
        archive.writestr(f"{windows_root}/{name}", content)
PY
printf 'Windows launcher fixture\n' > "$TMP/windows-launcher.exe"

python3 "$ROOT/tools/prepare_ztash_release.py" \
  --version 0.1.0 \
  --build-id 0123456789abcdef0123456789abcdef01234567 \
  --root "$TMP/release" \
  --output "$TMP/ztash" \
  --windows-launcher "$TMP/windows-launcher.exe"

python3 - "$TMP/ztash" "$ROOT" <<'PY'
import hashlib
import json
import sys
import tarfile
import zipfile
from pathlib import Path

root = Path(sys.argv[1])
manifest = json.loads((root / "ztash-release.json").read_text())
project_root = Path(sys.argv[2])
assert manifest["schema"] == "ztash-release-v1"
assert manifest["build_id"] == "0123456789abcdef0123456789abcdef01234567"
expected_lock_hash = hashlib.sha256((project_root / "tools/toolchain.lock.json").read_bytes()).hexdigest()
assert {item["target"] for item in manifest["artifacts"]} == {"x86_64-linux", "x86_64-windows-gnu"}
assert manifest["toolchain_lock_sha256"] == expected_lock_hash
for item in manifest["artifacts"]:
    archive = root / item["name"]
    assert archive.stat().st_size == item["size"]
    assert hashlib.sha256(archive.read_bytes()).hexdigest() == item["sha256"]
    if archive.suffix == ".zip":
        names = set(zipfile.ZipFile(archive).namelist())
        assert any(name.endswith("/modus.exe") for name in names)
        assert any(name.endswith("/modus-real.exe") for name in names)
        assert any(name.endswith("/ztash.ico") for name in names)
    else:
        names = set(tarfile.open(archive, "r:gz").getnames())
        assert any(name.endswith("/modus") for name in names)
        assert any(name.endswith("/ztash.svg") for name in names)
print("ZTASH release preparer regression passed.")
PY
