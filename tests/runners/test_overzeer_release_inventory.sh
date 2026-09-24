#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/modus-overzeer-inventory.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT

python3 - "$root" "$tmp" <<'PY'
import gzip
import hashlib
import json
import subprocess
import sys
from pathlib import Path

root, temporary = map(Path, sys.argv[1:])
source = temporary / "source"
release = temporary / "release"
source.mkdir()
release.mkdir()
executable = source / "client.x86_64"
executable.write_text("#!/bin/sh\nprintf 'client passed\\n'\n")
executable.chmod(0o755)
content = source / "client.pck"
content.write_bytes(b"pck payload")
server = source / "server.x86_64"
server.write_text("server payload")
server.chmod(0o755)
server_pck = source / "server.pck"
server_pck.write_bytes(b"server pck")
editor = source / "editor.x86_64"
editor.write_text("editor payload")
editor.chmod(0o755)
editor_pck = source / "editor.pck"
editor_pck.write_bytes(b"editor pck")
readme = source / "README"
readme.write_text("dogfood candidate\n")
license_path = source / "LICENSE"
license_path.write_text("license\n")

package_tool = root / "tools/package_overzeer.py"
def package(target, output, extras):
    args = [
        sys.executable, str(package_tool), "package",
        "--version", "0.9.5-beta", "--target", target,
        "--executable", str(executable), "--content", str(content),
        "--readme", str(readme), "--license", str(license_path),
    ]
    for name, path in extras:
        args.extend(("--extra", f"{name}={path}"))
    subprocess.run([*args, "--output", str(output)], check=True)

for suffix in ("tar.zst", "tar.gz"):
    package("linux-x86_64", release / f"modus-0.9.5-beta-linux-x86_64.{suffix}",
            (("server", server), ("server.pck", server_pck),
             ("modus-editor", editor), ("modus-editor.pck", editor_pck)))
package("windows-x86_64", release / "modus-0.9.5-beta-windows-x86_64.tar.zst",
        (("modus-editor.exe", editor), ("modus-editor.pck", editor_pck)))
package("windows-x86_64", release / "modus-0.9.5-beta-windows-x86_64.zip",
        (("modus-editor.exe", editor), ("modus-editor.pck", editor_pck)))

validator = root / "tools/validate_overzeer_release.py"
inventory = temporary / "inventory.json"
subprocess.run([
    sys.executable, str(validator), "--version", "0.9.5-beta",
    "--build-id", "a" * 40, "--root", str(release), "--output", str(inventory),
], check=True)
data = json.loads(inventory.read_text())
assert data["schema"] == "modus.overzeer-release/v1"
assert data["build_id"] == "a" * 40
assert len(data["artifacts"]) == 4
assert {item["format"] for item in data["artifacts"]} == {"tar.zst", "tar.gz", "zip"}
assert all(item["signing"] == "unsigned" and item["bytes"] > 0 for item in data["artifacts"])
for item in data["artifacts"]:
    assert hashlib.sha256((release / item["archive"]).read_bytes()).hexdigest() == item["sha256"]

bad = temporary / "bad.json"
corrupt = release / "modus-0.9.5-beta-linux-x86_64.tar.gz"
raw = gzip.decompress(corrupt.read_bytes()).replace(b"server payload", b"tampered payload")
corrupt.write_bytes(gzip.compress(raw, mtime=0))
result = subprocess.run([
    sys.executable, str(validator), "--version", "0.9.5-beta",
    "--build-id", "a" * 40, "--root", str(release), "--output", str(bad),
], check=False, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
assert result.returncode != 0
assert not bad.exists()
print("OVERZEER release inventory, target-root, digest and tamper checks passed.")
PY
