#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GODOT_BIN="${MODUS_GODOT_BIN:-godot}"

python3 - "$ROOT" "$GODOT_BIN" <<'PY'
import json
import selectors
import socket
import subprocess
import sys
import time
from pathlib import Path

root = Path(sys.argv[1])
godot = sys.argv[2]


def pick_port() -> int:
    sock = socket.socket()
    sock.bind(("127.0.0.1", 0))
    port = sock.getsockname()[1]
    sock.close()
    return port


def read_report(text: str) -> dict:
    prefix = "MODUS_WINDOWS_NETWORK_JSON="
    reports = [
        json.loads(line.removeprefix(prefix))
        for line in text.splitlines()
        if line.startswith(prefix)
    ]
    assert reports, text
    return reports[-1]


def run_pair(extra_args: list[str]) -> tuple[dict, dict]:
    port = pick_port()
    server = subprocess.Popen(
        [
            godot,
            "--headless",
            "--path",
            ".",
            "--",
            "--windows-qualification-network-server",
            "--windows-qualification-network-port",
            str(port),
            *extra_args,
        ],
        cwd=root,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    client = None
    try:
        selector = selectors.DefaultSelector()
        selector.register(server.stdout, selectors.EVENT_READ)
        ready = False
        deadline = time.monotonic() + 45
        while time.monotonic() < deadline and not ready:
            for _key, _mask in selector.select(0.5):
                line = server.stdout.readline()
                ready = line.startswith("MODUS_WINDOWS_NETWORK_READY=")
            if server.poll() is not None:
                break
        if not ready or server.poll() is not None:
            if server.poll() is None:
                server.kill()
            server.wait()
            raise AssertionError(server.stderr.read())

        client = subprocess.Popen(
            [
                godot,
                "--headless",
                "--path",
                ".",
                "--",
                "--windows-qualification-network-client",
                "--windows-qualification-network-address",
                "127.0.0.1",
                "--windows-qualification-network-port",
                str(port),
                *extra_args,
            ],
            cwd=root,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
        client_stdout, client_stderr = client.communicate(timeout=90)
        server_stdout, server_stderr = server.communicate(timeout=90)
        assert client.returncode == 0, client_stderr
        assert server.returncode == 0, server_stderr
        return read_report(client_stdout), read_report(server_stdout)
    finally:
        for process in (client, server):
            if process is not None and process.poll() is None:
                process.kill()
                process.wait()


client, server = run_pair([])
assert client["status"] == "pass", client
assert client["connection_established"]
assert client["application_probe_passed"]
assert client["probe_acknowledged"]
assert server["status"] == "pass", server
assert server["connection_established"]
assert server["application_probe_passed"]
assert server["probe_received"]

client, server = run_pair(
    [
        "--windows-qualification-network-reconnect",
        "--windows-qualification-network-soak-seconds",
        "1",
    ]
)
for report in (client, server):
    assert report["status"] == "pass", report
    assert report["connection_established"]
    assert report["reconnected"]
    assert report["soak_completed"]
client, server = run_pair(["--windows-qualification-network-host-loss"])
assert client["status"] == "pass", client
assert client["connection_established"]
assert client["application_probe_passed"]
assert client["disconnect_observed"]
assert client["host_loss_observed"]
assert server["status"] == "pass", server
assert server["connection_established"]
assert server["application_probe_passed"]
assert server["host_loss_triggered"]


print("Windows network qualification application/reconnect regression passed.")
PY
