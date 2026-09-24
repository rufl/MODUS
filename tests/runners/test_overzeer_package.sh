#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/modus-overzeer-package.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT

python3 - "$root" "$tmp" <<'PY'
import hashlib
import subprocess
import sys
import tarfile
from pathlib import Path

root, temporary = map(Path, sys.argv[1:])
source = temporary / "source"
source.mkdir()
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
readme = source / "README"
readme.write_text("dogfood candidate\n")
license_path = source / "LICENSE"
license_path.write_text("license\n")

common = [
    sys.executable,
    str(root / "tools/package_overzeer.py"),
    "package",
    "--version", "0.9.5-beta",
    "--target", "linux-x86_64",
    "--executable", str(executable),
    "--content", str(content),
    "--readme", str(readme),
    "--license", str(license_path),
    "--extra", f"server={server}",
    "--extra", f"server.pck={server_pck}",
]
first = temporary / "first.tar.zst"
second = temporary / "second.tar.zst"
subprocess.run([*common, "--output", str(first)], check=True)
subprocess.run([*common, "--output", str(second)], check=True)
assert first.read_bytes() == second.read_bytes(), "archive is not reproducible"
extract = temporary / "extract"
extract.mkdir()
archive_tar = temporary / "archive.tar"
with archive_tar.open("wb") as output:
    subprocess.run(["zstd", "--quiet", "-dc", str(first)], stdout=output, check=True)
with tarfile.open(archive_tar, mode="r:") as archive:
    names = archive.getnames()
    expected_root = "modus-0.9.5-beta-linux-x86_64"
    assert set(names) == {
        f"{expected_root}/LICENSE",
        f"{expected_root}/README",
        f"{expected_root}/SHA256SUMS",
        f"{expected_root}/modus",
        f"{expected_root}/modus.pck",
        f"{expected_root}/server",
        f"{expected_root}/server.pck",
    }
    archive.extractall(extract)

payload = extract / "modus-0.9.5-beta-linux-x86_64"
assert (payload / "modus").stat().st_mode & 0o111
for name in ("LICENSE", "README", "modus", "modus.pck", "server", "server.pck"):
    expected = hashlib.sha256((payload / name).read_bytes()).hexdigest()
    recorded = next(line.split()[0] for line in (payload / "SHA256SUMS").read_text().splitlines() if line.endswith(f"  {name}"))
    assert expected == recorded, name
print("OVERZEER package reproducibility and manifest checks passed.")
PY
