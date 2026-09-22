#!/usr/bin/env python3
"""Run real ENet travel peers with private user data and bounded process cleanup."""
import os
from pathlib import Path
import shutil
import signal
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[2]
SCENE = "res://tests/fixtures/hub_travel_peer.tscn"


def main() -> int:
    godot = os.environ.get("GODOT_BIN") or shutil.which("godot") or shutil.which("godot4")
    if not godot:
        raise SystemExit("Godot is required")
    with tempfile.TemporaryDirectory(prefix="modus-hub-network-") as temporary:
        directory = Path(temporary)
        processes: dict[str, subprocess.Popen] = {}
        logs = {}
        deadline = time.monotonic() + 90

        def start(role: str) -> None:
            environment = os.environ.copy()
            for name in ("HOME", "XDG_DATA_HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME", "XDG_RUNTIME_DIR"):
                private = directory / role / name
                private.mkdir(parents=True, mode=0o700)
                environment[name] = str(private)
            for name in ("DISPLAY", "WAYLAND_DISPLAY", "DBUS_SESSION_BUS_ADDRESS"):
                environment.pop(name, None)
            logs[role] = (directory / f"{role}.log").open("w+")
            processes[role] = subprocess.Popen(
                [godot, "--headless", "--audio-driver", "Dummy", "--max-fps", "60", "--path", str(ROOT), SCENE, "--", role, str(directory)],
                cwd=ROOT, env=environment, stdout=logs[role], stderr=subprocess.STDOUT,
                start_new_session=True,
            )

        def wait_file(name: str) -> None:
            while not (directory / name).exists():
                if time.monotonic() >= deadline or any(p.poll() is not None for p in processes.values()):
                    raise RuntimeError(f"Peer exited or timed out waiting for {name}")
                time.sleep(0.025)

        success = False
        try:
            start("host")
            wait_file("port")
            start("first")
            wait_file("start_late")
            start("late")
            for process in processes.values():
                process.wait(timeout=max(0.1, deadline - time.monotonic()))
            success = all(
                process.returncode == 0 and (directory / f"{role}_passed").exists()
                for role, process in processes.items()
            )
        except (RuntimeError, subprocess.TimeoutExpired) as error:
            print(error)
        finally:
            for process in processes.values():
                if process.poll() is None:
                    os.killpg(process.pid, signal.SIGTERM)
            for process in processes.values():
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    os.killpg(process.pid, signal.SIGKILL)
                    process.wait()
            for role, stream in logs.items():
                stream.seek(0)
                content = stream.read()
                stream.close()
                if "SCRIPT ERROR:" in content or "ERROR:" in content:
                    success = False
                print(f"--- {role} ---")
                if output := os.environ.get("HUB_TRAVEL_LOG_DIR"):
                    Path(output).mkdir(parents=True, exist_ok=True)
                    (Path(output) / f"{role}.log").write_text(content)
                lines = content.splitlines()
                seen = set()
                for index, line in enumerate(lines):
                    if "HUB TRAVEL" in line:
                        print(line)
                    elif "ERROR:" in line:
                        block = "\n".join(lines[index:index + 9])
                        if block not in seen:
                            print(block)
                            seen.add(block)
        print("Hub ENet travel: PASS" if success else "Hub ENet travel: FAIL")
        return 0 if success else 1


if __name__ == "__main__":
    raise SystemExit(main())
