#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/modus_release_validator.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT

python3 - "$root/tools/validate_release_artifacts.py" "$tmp" <<'PY'
import copy
import json
from pathlib import Path
import shutil
import subprocess
import sys

validator, temporary = sys.argv[1:]
temporary = Path(temporary)
candidate = temporary / "original"
candidate.mkdir()
for role, filename in (("client", "modus.bin"), ("server", "modus.bin"), ("editor", "modus.exe")):
    directory = candidate / role
    directory.mkdir()
    executable = directory / filename
    executable.write_text(f"{role} executable\n", encoding="utf-8")
    executable.chmod(0o600 if role == "editor" else 0o700)
    content = executable.with_suffix(".pck") if role != "server" else Path(str(executable) + ".pck")
    content.write_text(f"{role} content\n", encoding="utf-8")
(candidate / "signature.asc").write_text("fixture signature\n", encoding="utf-8")


def invoke(*arguments, passes=True):
    result = subprocess.run([sys.executable, validator, *map(str, arguments)], text=True, capture_output=True)
    output = result.stdout if passes else result.stderr
    assert result.returncode == (0 if passes else 1), (arguments, result.returncode, result.stdout, result.stderr)
    report = json.loads(output)
    assert report["outcome"] == ("passed" if passes else "failed"), report
    assert report["certified"] is False, report
    if not passes:
        assert isinstance(report["error"], str) and report["error"], report
    return report


def generate(version="0.9.5-beta.1+build.001", output=None, **options):
    arguments = ["--version", version, "--root", candidate,
                 "--client", candidate / "client/modus.bin", "--server", candidate / "server/modus.bin",
                 "--editor", candidate / "editor/modus.exe", "--signature", candidate / "signature.asc",
                 "--output", output if output is not None else candidate / "manifest.json",
                 "--commit", "a" * 40, "--godot-version", "4.6.stable"]
    return invoke(*arguments, **options)


generate()
manifest = json.loads((candidate / "manifest.json").read_text(encoding="utf-8"))
assert manifest["schema_version"] == 1
assert manifest["version"] == "0.9.5-beta.1+build.001"
assert manifest["commit"] == "a" * 40 and manifest["godot_version"] == "4.6.stable"
assert {(record["role"], record["kind"]) for record in manifest["artifacts"]} == {
    (role, kind) for role in ("client", "server", "editor") for kind in ("executable", "content")
}
assert manifest["signature"]["path"] == "signature.asc"
assert all(not Path(record["path"]).is_absolute() for record in manifest["artifacts"])
invoke("--verify", candidate / "manifest.json")

# A candidate is self-contained: no dependency on original absolute paths.
relocated = temporary / "relocated"
shutil.move(candidate, relocated)
candidate = relocated
invoke("--verify", candidate / "manifest.json")
external_manifest = temporary / "external.json"
shutil.copyfile(candidate / "manifest.json", external_manifest)
invoke("--verify", external_manifest, "--root", candidate)
invoke("--verify", candidate / "manifest.json", "--version", "1.0.0", passes=False)

for version in ("not-semver", "1.0.0-alpha..1", "1.0.0-01", "1.0.0-alpha.01", "1.0.0+"):
    generate(version, passes=False)

# Neither an exact output collision nor a hardlink alias may destroy a payload.
protected = candidate / "client/modus.bin"
original = protected.read_bytes()
generate(output=protected, passes=False)
assert protected.read_bytes() == original
alias = candidate / "alias.json"
alias.hardlink_to(protected)
generate(output=alias, passes=False)
assert protected.read_bytes() == original
alias.unlink()

# Sibling and appended PCK names are supported separately, never chosen ambiguously.
ambiguous = candidate / "client/modus.bin.pck"
ambiguous.write_text("ambiguous content\n", encoding="utf-8")
generate(passes=False)
ambiguous.unlink()

content = candidate / "client/modus.pck"
original_content = content.read_bytes()
content.write_bytes(b"X" + original_content[1:])
invoke("--verify", candidate / "manifest.json", passes=False)
content.unlink()
invoke("--verify", candidate / "manifest.json", passes=False)
generate(passes=False)
content.write_bytes(original_content)

protected.chmod(0o600)
invoke("--verify", candidate / "manifest.json", passes=False)
generate(passes=False)
protected.chmod(0o700)

signature = candidate / "signature.asc"
signature_bytes = signature.read_bytes()
signature.write_bytes(b"different signature\n")
invoke("--verify", candidate / "manifest.json", passes=False)
signature.write_bytes(signature_bytes)

outside = temporary / "outside.pck"
outside.write_bytes(original_content)
content.unlink()
content.symlink_to(outside)
invoke("--verify", candidate / "manifest.json", passes=False)
generate(passes=False)
content.unlink()
content.write_bytes(original_content)

# A symlinked directory is also forbidden, even when its target is under root.
client = candidate / "client"
client.rename(candidate / "real-client")
client.symlink_to(candidate / "real-client", target_is_directory=True)
invoke("--verify", candidate / "manifest.json", passes=False)
generate(passes=False)
client.unlink()
(candidate / "real-client").rename(client)

bad_manifest = candidate / "invalid.json"


def rejected_manifest(value):
    bad_manifest.write_text(json.dumps(value), encoding="utf-8")
    invoke("--verify", bad_manifest, passes=False)


# Corrupt schema and record types must yield structured errors, never tracebacks.
for value in ([], None, {**manifest, "schema_version": True}, {**manifest, "schema_version": 2},
              {**manifest, "certified": True}, {**manifest, "artifacts": {}},
              {**manifest, "version": 1}, {**manifest, "signature": "signature.asc"}):
    rejected_manifest(value)
missing_pair = copy.deepcopy(manifest)
missing_pair["artifacts"].pop()
rejected_manifest(missing_pair)
duplicate_pair = copy.deepcopy(manifest)
duplicate_pair["artifacts"][-1]["role"] = "client"
rejected_manifest(duplicate_pair)
duplicate_path = copy.deepcopy(manifest)
duplicate_path["artifacts"][-1].update({key: manifest["artifacts"][1][key] for key in ("path", "bytes", "sha256")})
rejected_manifest(duplicate_path)
for field, value in (("role", []), ("kind", None), ("bytes", True), ("bytes", 0),
                     ("sha256", "invalid"), ("path", "../outside.pck"), ("path", str(outside)),
                     ("path", "client/../outside.pck"), ("path", "C:\\outside.pck")):
    invalid = copy.deepcopy(manifest)
    invalid["artifacts"][0][field] = value
    rejected_manifest(invalid)
for text in ('{"schema_version":', '{"schema_version":1,"schema_version":1}'):
    bad_manifest.write_text(text, encoding="utf-8")
    invoke("--verify", bad_manifest, passes=False)
bad_manifest.write_bytes(b"\xff")
invoke("--verify", bad_manifest, passes=False)
invoke("--verify", candidate / "missing.json", passes=False)

# An escaped generation input must fail as well as escaped manifest records.
invoke("--version", "1.0.0", "--client", protected, "--server", candidate / "server/modus.bin",
       "--editor", candidate / "editor/modus.exe", "--signature", outside,
       "--output", candidate / "escaped.json", passes=False)
invoke("--verify", candidate / "manifest.json")
print("Release artifact validator self-check passed.")
PY
