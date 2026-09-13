# Manual Test Timing and CSV Evidence

> **Documentation status: maintained reference.** This page reflects `tests/manual/manual_test_timer.gd` and the test-only recorder. A timer log records human observations; it never creates gameplay passes automatically.

## Recommended workflow

Launch a normal graphical session from the repository root:

```bash
GODOT_BIN=Godot-4.7 tools/run_manual_showcase_session.sh \
  --tester "Reviewer Name" \
  --input "keyboard_mouse,gamepad_xbox" \
  --renderer gl_compatibility \
  --resolution 1280x720
```

The game opens at the maintained main menu. The recorder begins with the first bounded showcase item:

1. Press **F8** or **Gamepad Back** to hide the recorder and perform the displayed test.
2. Toggle the same control again to pause and review the result.
3. Add observation notes, then choose **Pass**, **Fail**, or **Skip**.
4. Fail and Skip require a reason; Pass notes are optional.
5. End the session normally so the summary and metadata are flushed.

The overlay is test-only and is not part of the shipped game route. It uses responsive safe margins, visible keyboard/gamepad focus, 48-pixel-or-larger logical actions, and a compact 800×600 layout.

## Evidence destination

The runner writes directly to:

```text
logs/manual_test_logs/<session>.csv
```

Use `--evidence-dir` only when evidence must be staged elsewhere. Direct `ManualTestTimer` users may set `output_directory` or `MODUS_MANUAL_EVIDENCE_DIR`; otherwise the fallback remains `user://manual_test_logs`.

`logs/` is ignored local evidence, not committed input or a fresh-clone fixture. Publication cleanup preserves existing CSVs byte-for-byte locally; do not delete them to make a gate pass. Publish reviewed, dated conclusions in maintained status/changelog entries. The validator below regenerates local-only `docs/MANUAL_EVIDENCE_REPORT.md`; neither that output nor an old PASS replaces a new reviewed session.

Each CSV includes:

- stable test IDs and pass/fail/skip/incomplete results;
- per-test duration and notes;
- tester, OS, renderer, resolution, input devices, scene route, and build identity;
- wall-session and active-test timing summaries.

## Truth boundary

`tools/validate_manual_evidence.sh` counts only completed test-row duration toward the configured threshold. Recorder setup time and idle overhead do not count. It rejects malformed rows, missing required metadata, fail/skip rows without notes, failed items, and incomplete/unknown results.

Run:

```bash
tools/validate_manual_evidence.sh --strict
```

Keep failed and skipped rows truthful. Fixing or accepting an observation requires a new reviewed session, not editing an old CSV into a pass.

## Black Start production acceptance

The September 13 production candidate is retained locally under `logs/breakwater_production/`. Its native client and `.mdsl` package are not a published release or fresh-clone dependency. Automation has not supplied human acceptance.

For a **human-operated** playthrough, use a dedicated disposable VM/container desktop with isolated display/session sockets. Inside that environment, run from the repository root:

```bash
logs/breakwater_production/install/client/modus.x86_64 \
  --rendering-method gl_compatibility -- \
  --level "$PWD/logs/breakwater_production/breakwater_black_start.mdsl"
```

Use normal damage, the default movement kit and no automation mods. Record tester, build/package SHA-256, input device, renderer, resolution, difficulty, active elapsed time, deaths, ammunition shortages and observations. `logs/breakwater_production/evidence.json` identifies the retained candidate. The existing showcase recorder does not automatically count this separate mission checklist.

| Check | Required human observation |
| --- | --- |
| Arrival and hub | Identify the pump-hall route from authored signs; inspect coastal framing, HUD readability and supplies without a debug marker. |
| Pump hall | Clear security, collect the key and restore auxiliary power. Judge cover, hit feedback, recovery supplies and the visible/audible power change. |
| Intake and cavern | Recognize the 2-second live / 3-second safe arc cycle; recover from contact. Walk the optional dry cavern route and inspect its lighting and water treatment. |
| Turbine atrium | Clear lower and ranged teams with finite ammunition; climb the ordinary ramp, restart cooling and observe moving machinery. |
| Relay crown | Recognize reinforcement entrances, use the final service point and transmit. Transmission must not complete the return journey for you. |
| Return lift | Wait beside the shaft and board the lowered deck. A descending deck stops above an obstructing character and resumes once clear. Save with F5 during travel, load with F9, then exit behind the lift at the upper floor. |
| Powered hub | Traverse the elevated gallery, reach Anchorage, confirm mission completion and reload a completed checkpoint without replaying rewards. |
| Secrets and recovery | Shoot and enter both cued caches; verify discovered/consumed state after reload. Confirm death followed by checkpoint loading does not cause a delayed second respawn. |
| Audiovisual comfort | Listen through the complete route, including loop transitions, weapons and reloads. Inspect all eleven rooms in motion; test SFX/Master mute, reduced motion and low/zero-particle settings. |
| Pacing and verdict | Record actual first-play time and difficulty. The 15–20 minute target remains unvalidated; automated route duration is not player pacing. Record Pass/Fail and concrete defects, not an inferred approval. |

All graphical verification must remain on a disposable isolated display, including the human review environment. These instructions do not authorize an agent to operate, capture or reconfigure the developer's active desktop.
