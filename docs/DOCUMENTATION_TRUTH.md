# MODUS Documentation Truth Contract

> **Documentation status: maintained reference.** This file defines publication policy. Committed summaries record dated, bounded observations; locally generated reports describe individual invocations, not checkout guarantees.

**Languages:** [English](DOCUMENTATION_TRUTH.md) · [Português (Brasil)](pt-BR/DOCUMENTATION_TRUTH.md)
**Updated:** September 30, 2026
**Version:** `0.9.5-beta`  
**Engine:** Godot 4.7.2 toolchain (Godot 4.7 line)
**Overall readiness:** **NOT READY**

## Canonical Published Sources

Use these maintained files when documents disagree:

1. [Current Status](CURRENT_STATUS.md) for the consolidated implementation and dated evidence snapshot.
2. [Known-Limits Matrix](KNOWN_LIMITS_MATRIX.md) for exclusions and unresolved runtime, manual, external, and distribution proof.
3. [Active Backlog](../BACKLOG.md) and [Roadmap](../ROADMAP.md) for open work and acceptance boundaries.
4. [Root Changelog](../CHANGELOG.md) for completed or retired work and its historical proof scope.
5. [Release Evidence Bundle](RELEASE_EVIDENCE_BUNDLE.md) for curated captures, provenance, package hashes and release exclusions.

The public-beta source baseline passed on commit `1367b270d651b1a2588044774a15f1dbeb2b8b51` (pipeline `36779150278`, quality `36779150276`). Documentation-only commits run through the same GitHub Actions workflows. The September 29 strict headless aggregate remains the latest published full automated result: 1,671/1,671 tests with 22,982 assertions across 149 scripts in 1,103.095 seconds, with two GUI-required files skipped. The public `v0.9.5-beta` prerelease is an unsigned client distribution; signing, installers, native target acceptance, reviewed manual gameplay, and external-service gates remain open.

## Public beta publication boundary

The public [`v0.9.5-beta` GitHub prerelease](https://github.com/rufl/MODUS/releases/tag/v0.9.5-beta) is a maintained distribution fact, not a production-readiness claim. Its release evidence, package bytes, SHA-256 values, archive checks, Linux smoke result and unsigned/notarization-unavailable limitations are recorded in the [Release Evidence Bundle](RELEASE_EVIDENCE_BUNDLE.md). Do not describe the beta as signed, notarized, installer-backed, natively approved or shipped.

## Local-Only Retention

GitHub publishes source, active tests and CI, licenses, curated documentation and media, and maintained guides. A fresh clone intentionally excludes local working material.

Untracked working notes, raw logs, generated reports, historical audits, and retired one-off scripts are neither required checkout inputs nor public navigation targets. Do not publish an obsolete file merely to restore an old link, and never make current workflows depend on material outside version control.

Preserve old evidence without relabeling it as a fresh run. Keep concise, dated conclusions and explicit exclusions in maintained status and changelog entries. Local retention is not a backup guarantee; use an appropriate external evidence store for material that must survive checkout loss.

## Regenerating Local Reports

Run commands from the repository root with the documented dependencies installed. Reports and raw logs are ignored local outputs, not committed links. Missing local evidence is expected on a fresh clone and must be reported as missing or blocked, never replaced with a historical PASS. Review each command's actual exit status and report before updating published summaries.

| Local output | Regeneration command | Boundary |
| --- | --- | --- |
| `docs/AUTOMATED_TEST_LANES_REPORT.md` | `./tests/runners/run_tests_by_category.sh --report docs/AUTOMATED_TEST_LANES_REPORT.md` | Executed lanes only; skipped/incomplete lanes remain explicit |
| `docs/MAIN_PLAYER_PATH_SMOKE.md` | `tools/run_main_player_path_smoke.sh --strict` | Main-menu startup only |
| `docs/SHOWCASE_LAUNCH_SMOKE.md` | `tools/run_main_player_path_smoke.sh --target world --report docs/SHOWCASE_LAUNCH_SMOKE.md --strict` | World-scene startup only |
| `docs/GOLDEN_DEMO_SMOKE.md` | `tools/run_showcase_golden_demo_smoke.sh --strict` | Controlled automated gameplay; not human feel |
| `docs/MANUAL_EVIDENCE_REPORT.md` | `tools/validate_manual_evidence.sh --strict` | Requires reviewed local ManualTestTimer CSVs |
| `docs/PERFORMANCE_EVIDENCE_REPORT.md` | `tools/validate_performance_evidence.sh --strict` | Requires contextualized local PerformanceLogger CSVs; validates evidence shape |
| `docs/RELEASE_READINESS_REPORT.md` | `tools/validate_release_readiness.sh --strict` | Version gate, not release approval |
| `docs/PRODUCTION_READINESS_REPORT.md` | `tools/validate_production_readiness.sh --run-godot-tests --strict` | Local gate aggregate, not legal/distribution clearance |

The full automated runner is `./tests/runners/run_all_tests_headless.sh`; its new logs stay under `logs/`. Capture new manual evidence with `tools/run_manual_showcase_session.sh --tester NAME --input DEVICES` and follow the [manual checklist](../tests/docs/MANUAL_PLAYER_EXPERIENCE_TESTS.md). For a new performance capture, use `godot --path . --script tools/run_performance_evidence_capture.gd` and the [performance guide](guides/performance_optimization.md). Regeneration creates a new observation; it cannot recreate or certify the old run's bytes, hardware, or result.

## Documentation Classes

### Maintained Reference

Describes a live subsystem, workflow, command, or consolidated project boundary. Subsystem details must match source. Project-wide readiness and test-total claims defer to the published sources above. Relative Markdown links must resolve within the published tracked tree; local output paths belong in code spans with regeneration instructions, not links.

### Generated Evidence

Describes one validator invocation. A PASS applies only to that validator's scope. The performance evidence validator, for example, checks CSV duration and structure; it does not prove stable gameplay or target hardware performance. Generated reports remain local and do not override published status until their observations and exclusions have been reviewed.

### Historical Snapshot

Preserves an audit, implementation checkpoint, fix session, draft release note, old instruction set, or previous result locally. Its body is not revalidated during publication cleanup and may contain superseded paths, APIs, counts, estimates, outcomes, and instructions. Do not edit a retained historical file merely to add a classification banner or repair a link; describe its historical scope in the maintained index instead. Historical material never overrides current source or newly observed evidence.

## Claim Rules

- “Implemented” means a live source path exists; it does not imply runtime or UX proof.
- “Tested” names the executed command, date, observed result, and exclusions.
- “Runtime proof” identifies the launched scene/path and observed behavior.
- “Manual proof” requires reviewed human observations and recorded evidence.
- “Performance proof” states hardware, renderer, duration, and exclusions.
- “Steam proof” requires GodotSteam, a running Steam client, an app ID, authorization, and a real API result.
- “Production ready,” “release ready,” and “complete” are prohibited as project-wide present-tense claims while required gates remain blocked.
- A subsystem completion claim needs explicit scope and published evidence context; a local-only path is not accessible proof for readers of a fresh clone.

## Verification

```bash
bash tools/check_documentation_truth.sh
bash tools/check_project_truth.sh
bash tools/check_headless_runner_manifest.sh
tools/generate_provenance_ledger.py --check
```

The documentation check validates Git-tracked Markdown, including staged additions. Tracked historical snapshots and generated reports fail even if force-added through ignore rules. Retained local files cannot satisfy published Markdown links. Keep local outputs out of the index rather than changing their classification to make the check pass.

Set `GODOT_BIN` to an available Godot 4.7 binary when it is not on PATH; temporary local paths are not repository dependencies. Run the relevant runtime or evidence commands separately when refreshing an observed boundary.
