# MODUS Documentation

> **Documentation status: maintained reference.** Start with the published truth contract and consolidated status. Generated reports and historical files are local-only, not prerequisites for reading a fresh clone.

**Languages:** [English](README.md) · [Português (Brasil)](pt-BR/README.md)
**Version:** `0.9.5-beta` · **Engine:** Godot 4.7.2 toolchain · **Readiness:** **NOT READY**

The public-beta source baseline passed on commit `1367b270d651b1a2588044774a15f1dbeb2b8b51` (pipeline `36779150278`, quality `36779150276`). The [`v0.9.5-beta` prerelease](https://github.com/rufl/MODUS/releases/tag/v0.9.5-beta) provides unsigned Linux, Windows, and macOS archives with checksums. Signing, installers, native target acceptance, reviewed manual gameplay, and external Steam/WAN/Workshop proof remain open.

## Read First

1. [Documentation Truth Contract](DOCUMENTATION_TRUTH.md)
2. [Current Status](CURRENT_STATUS.md)
3. [Known-Limits Matrix](KNOWN_LIMITS_MATRIX.md)
4. [Release Evidence Bundle](RELEASE_EVIDENCE_BUNDLE.md)
5. [Ship-Readiness Estimate](SHIP_READINESS_ESTIMATE.md)
6. [Active Backlog](../BACKLOG.md)
7. [Documentation Index](INDEX.md)

## Evidence and Regeneration

Generated reports and raw logs are ignored local outputs, not committed evidence links. [Regenerating Local Reports](DOCUMENTATION_TRUTH.md#regenerating-local-reports) lists report paths, commands, and prerequisites. Missing manual/performance inputs on a fresh clone remain missing evidence, not a historical PASS.

Published context and curated artifacts:

- [ENet Host/Join](ENET_LOCAL_HOST_JOIN_SMOKE.md)
- [Editor Round Trip](EDITOR_ROUNDTRIP_PROOF.md)
- [Workshop Local Simulation](WORKSHOP_LOCAL_SIMULATION_PROOF.md)
- [Sample Mod and Package Validation](MODDING_SAMPLE_MOD.md)
- [Release Evidence Bundle](RELEASE_EVIDENCE_BUNDLE.md)
- [Known-Limits Matrix](KNOWN_LIMITS_MATRIX.md)
- [Provenance Inventory and Ledger](ATTRIBUTION.md)
- [CC0 Asset Search List](CC0_ASSET_SEARCH_LIST.md)

## Maintained References

- [Getting Started](getting_started.md)
- [Architecture](architecture.md)
- [Technical Reference](TECHNICAL_REFERENCE.md)
- [JSON/Data Ownership](technical/JSON_SCHEMAS.md)
- [Testing Inventory](../tests/README.md)
- [Test Runners](../tests/runners/README.md)
- [Manual Test Checklist](../tests/docs/MANUAL_PLAYER_EXPERIENCE_TESTS.md)
- [Modding](guides/MODDING.md)
- [Console](guides/CONSOLE.md)
- [Troubleshooting](troubleshooting.md)
- [Hardware Requirements](hardware_requirements.md)
- [Roadmap](ROADMAP.md)
- [Full Index](INDEX.md)

## Portuguese navigation

- [Índice português](pt-BR/INDEX.md)
- [Changelog português](../CHANGELOG.pt-BR.md)
- [README português](../README.pt-BR.md)

## Historical Material

Superseded working notes, generated reports, and raw logs are not tracked or included in fresh clones. They are not revalidated and never override current source or reviewed observations.

Curated media, licenses, maintained status and known limits, active backlogs and roadmaps, and the root changelog remain published. See the [publication policy](DOCUMENTATION_TRUTH.md#local-only-retention) for retention and evidence boundaries.

## Contribution Rule

When changing code or evidence:

1. Update the narrow maintained subsystem reference.
2. Update `docs/CURRENT_STATUS.md` with dated observations and explicit exclusions, not unexecuted commands or old local PASS results.
3. Refresh generated reports through their validators; keep reports and raw evidence local. Publish reviewed conclusions in maintained docs.
4. Record completed or retired backlog work and its proof boundary in root `CHANGELOG.md` before removing it from the active queue.
5. Run the documentation, project, and runner-manifest truth checks.

```bash
bash tools/check_documentation_truth.sh
bash tools/check_project_truth.sh
bash tools/check_headless_runner_manifest.sh
tools/generate_provenance_ledger.py --check
```
