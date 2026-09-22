#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/modus-release-stage.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT

python3 - "$root" "$tmp" <<'PY'
import json
import shutil
import subprocess
import sys
from pathlib import Path

root, temporary = map(Path, sys.argv[1:])
source = temporary / "exports"
source.mkdir()
for role in ("client", "server", "editor"):
    executable = source / role / f"{role}.x86_64"
    executable.parent.mkdir()
    executable.write_text(f"#!/bin/sh\nprintf '{role} launch passed\\n'\n")
    executable.chmod(0o755)
    executable.with_suffix(".pck").write_text(f"{role} content")
manifest = source / "manifest.json"
subprocess.run([
    sys.executable, str(root / "tools/validate_release_artifacts.py"),
    "--version", "0.9.5-beta", "--commit", "a" * 40, "--godot-version", "4.7.2",
    "--client", str(source / "client/client.x86_64"),
    "--server", str(source / "server/server.x86_64"),
    "--editor", str(source / "editor/editor.x86_64"), "--output", str(manifest),
], check=True, capture_output=True, text=True)

def stage(output, passed):
    result = subprocess.run([
        sys.executable, str(root / "tools/stage_release_artifacts.py"),
        "--manifest", str(manifest), "--output", str(output),
    ], capture_output=True, text=True)
    assert (result.returncode == 0) == passed, result.stdout + result.stderr
    if not passed:
        assert json.loads(result.stderr)["outcome"] == "failed", result.stderr
    assert not list(temporary.glob(".modus-stage-*")), "staging scratch leaked"

candidate = temporary / "MODUS-0.9.5-beta"
stage(candidate, True)
relocated = temporary / "relocated candidate ü"
candidate.rename(relocated)
shutil.rmtree(source / "editor")  # Candidate must not refer back to source exports.
subprocess.run([
    sys.executable, str(root / "tools/validate_release_artifacts.py"),
    "--verify", str(relocated / "manifest.json"),
], check=True, capture_output=True, text=True)
launched = subprocess.check_output([str(relocated / "editor/editor.x86_64")], text=True)
assert launched == "editor launch passed\n"
shutil.copytree(relocated / "editor", source / "editor")

sentinel = relocated / "user-note"
sentinel.write_text("preserve me")
stage(relocated, False)
assert sentinel.read_text() == "preserve me"
assert (relocated / "server/server.pck").read_text() == "server content"

(source / "server/server.pck").write_text("tampered")
rejected = temporary / "rejected"
stage(rejected, False)
assert not rejected.exists(), "failed verification published a partial candidate"
(source / "server/server.pck").write_text("server content")
identity = json.loads(manifest.read_text())
del identity["commit"]
manifest.write_text(json.dumps(identity))
stage(rejected, False)
assert not rejected.exists(), "unidentified candidate was published"
print("Release staging self-check passed: relocation, launch, refusal, tamper, identity.")
PY
