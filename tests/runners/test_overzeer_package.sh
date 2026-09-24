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
import zipfile
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

def command(target, output):
    return [
        sys.executable,
        str(root / "tools/package_overzeer.py"),
        "package",
        "--version", "0.9.5-beta",
        "--target", target,
        "--executable", str(executable),
        "--content", str(content),
        "--readme", str(readme),
        "--license", str(license_path),
        "--extra", f"server={server}",
        "--extra", f"server.pck={server_pck}",
        "--output", str(output),
    ]

def expected_names(root_name, executable_name, include_server):
    names = {
        f"{root_name}/LICENSE",
        f"{root_name}/README.md",
        f"{root_name}/SHA256SUMS",
        f"{root_name}/{executable_name}",
        f"{root_name}/modus.pck",
    }
    if include_server:
        names.update({f"{root_name}/server", f"{root_name}/server.pck"})
    return names

def inspect_archive(archive_path, format_name, root_name, executable_name, include_server):
    expected = expected_names(root_name, executable_name, include_server)
    if format_name == "zip":
        with zipfile.ZipFile(archive_path) as archive:
            assert set(archive.namelist()) == expected
            info = archive.getinfo(f"{root_name}/{executable_name}")
            assert (info.external_attr >> 16) & 0o111
            payload = archive.read(f"{root_name}/{executable_name}")
            checksums = archive.read(f"{root_name}/SHA256SUMS").decode()
    else:
        tar_path = temporary / f"{archive_path.name}.tar"
        if format_name == "tar.zst":
            with tar_path.open("wb") as output:
                subprocess.run(["zstd", "--quiet", "-dc", str(archive_path)], stdout=output, check=True)
            mode = "r:"
        else:
            mode = "r:gz"
            tar_path = archive_path
        with tarfile.open(tar_path, mode=mode) as archive:
            assert set(archive.getnames()) == expected
            info = archive.getmember(f"{root_name}/{executable_name}")
            assert info.mode & 0o111
            payload = archive.extractfile(info).read()
            checksums = archive.extractfile(f"{root_name}/SHA256SUMS").read().decode()
    assert payload
    assert f"{hashlib.sha256(payload).hexdigest()}  {executable_name}\n" in checksums

linux_root = "modus-0.9.5-beta-linux-x86_64"
for format_name in ("tar.zst", "tar.gz"):
    first = temporary / f"linux-first.{format_name}"
    second = temporary / f"linux-second.{format_name}"
    subprocess.run([*command("linux-x86_64", first)], check=True)
    subprocess.run([*command("linux-x86_64", second)], check=True)
    assert first.read_bytes() == second.read_bytes(), f"{format_name} archive is not reproducible"
    inspect_archive(first, format_name, linux_root, "modus", True)

windows_root = "modus-0.9.5-beta-windows-x86_64"
windows_first = temporary / "windows-first.zip"
windows_second = temporary / "windows-second.zip"
subprocess.run([*command("windows-x86_64", windows_first)], check=True)
subprocess.run([*command("windows-x86_64", windows_second)], check=True)
assert windows_first.read_bytes() == windows_second.read_bytes(), "zip archive is not reproducible"
inspect_archive(windows_first, "zip", windows_root, "modus.exe", True)
print("OVERZEER tar.zst, tar.gz and zip reproducibility and manifest checks passed.")
PY
