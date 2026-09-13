# MODUS Product and Evidence Roadmap

> **Documentation status: maintained reference.** This document expands the root roadmap by product area. It does not promote implementation presence into runtime or release proof.

**Updated:** September 11, 2026
**Current version:** `0.9.5-beta`  
**Current readiness:** NOT READY

## Current Evidence Boundary

- Historical August 4 full suite: 1440/1440 with 20,475 assertions and no risky/pending tests or GUT orphans; not the current-tree suite total.
- That aggregate completed in 702.76 seconds under a bounded 3600-second run, with six engine-exit ObjectDB leak diagnostics.
- Historical category observations: August 1 Unit 1056/1056 and Property 175/175; July 19 Integration 200/200; Benchmark skipped. Local `docs/AUTOMATED_TEST_LANES_REPORT.md` is not committed; regenerate it with `./tests/runners/run_tests_by_category.sh --report docs/AUTOMATED_TEST_LANES_REPORT.md`.
- Earlier source-shape/resource/editor-registry proof recorded 37/37 with 172 assertions and zero GUT orphans. September 9 focused repair observations now cover the four formerly missing loot-prop scenes; see [Current Status](CURRENT_STATUS.md).
- Manual gameplay: 0 imported evidence files / 0.00 recorded hours.
- Performance: one bounded 66.4-second, 130-sample showcase capture; production targets remain unproven.
- Release: blocked at `0.9.5-beta`.
Published readiness remains NOT READY. The two-validator-blocker snapshot covers manual evidence and release version only; the current 218-row provenance ledger is fully cleared, while packaging, external service, and target-runtime proof remain open. Local-only raw evidence and generated outputs do not certify a fresh clone; see [report regeneration](DOCUMENTATION_TRUTH.md#local-only-retention).

See [Documentation Truth](DOCUMENTATION_TRUTH.md) and [Current Status](CURRENT_STATUS.md) for details.

## Core Framework

| Area | Source status | Required proof/hardening |
| --- | --- | --- |
| GameManager services | Implemented with broad focused coverage | Clean aggregate lifecycle/order behavior |
| Data/config ownership | Implemented and reference-tested | Keep schemas and mod override examples synchronized |
| Save system | Focused tests pass | Manual save/load/corruption observation |
| Events/components/features | Implemented with focused tests | Aggregate suite stability and user-flow evidence |

## Gameplay and Showcase

| Area | Source status | Required proof/hardening |
| --- | --- | --- |
| Movement/combat/weapons/enemies | Eight-step automated golden-demo runtime smoke passes; 20-item F8 human recorder workflow is ready | Reviewed human feel, failure recovery, and tuning observations |
| Showcase | Structure tests pass; localized gamepad-ready welcome/evidence panel is focused-proven and captured at wide/narrow resolutions | Manual gameplay route, video, and issue log |
| AI/navigation | Focused tests pass in several lanes | Real map behavior, stress, and long-session stability |
| Splitscreen | Manager/gameplay/stress contracts pass | Real controllers, viewport/UI, audio, and performance evidence |

## Networking

| Area | Source status | Required proof/hardening |
| --- | --- | --- |
| ENet/profile startup | Profile startup and September focused real-ENet lifecycle/inventory/late-join checks have dated proof | Reviewed end-to-end sessions, latency/reconnect behavior, and dedicated clients |
| Authority/security | Validation, whitelist, and rate-limit code exist | Adversarial live-client and latency tests |
| Dedicated server | Headless/config paths exist | Real client/server session evidence |
| Lag compensation | Shared RTT-bounded player/enemy rewind and combat integration; focused physics/weapon proof passes | Client-view/interpolation calibration and representative high-latency sessions |
| Steam/GodotSteam | Conditional structures exist; authenticated local initialization has been observed | Two-account Steam, Workshop, relay/P2P, and public-service proof |

## Editor, Mods, and Workshop

| Area | Source status | Required proof/hardening |
| --- | --- | --- |
| Main menu and mod workflow | Artwork/showcase/help/responsive/focus/version/welcome/mod/skill-tree contracts pass 26/26 with 109 assertions; recorder/timer passes 2/2 with 21 assertions and a compact 800×600 capture | Run and review the manual menu/input observations |
| Level serialization/export | Focused round-trip passes | Live editor UI authoring workflow |
| Standalone undo/redo | Runtime-safe block placement now uses the shared editor fallback and supports place/undo/redo in focused proof; other standalone command paths remain | Complete and exercise remaining authoring commands |
| Mod loader/SDK | Focused integration/sample proof passes | Distribution packaging and multiplayer behavior |
| Workshop | Local simulation passes | Real Steam upload/download/browse/subscription |

## Map Generator

| Area | Source status | Required proof/hardening |
| --- | --- | --- |
| Generator correctness | September 13: 55/55 focused tests, 1,319 assertions | Broader content/configuration and cross-runtime/platform proof; no refreshed aggregate claim |
| Export | Generated 64×64 scene retains records/navigation/collision; authored three-room `.mdsl` survives exported Linux editor → game playback | Graphical/target-platform authoring acceptance and automatic realization of generated gameplay records |
| Seed/RNG | Revision 2 isolates global/gameplay/cosmetic streams; repeated seed reproduces tested gameplay and navigation | Pin generator/runtime/content; old seed layouts change, cross-version identity is not promised |
| Threaded pipeline | Cancellation after geometry preparation cannot abort a replacement generation | Broader UI, long-session and platform lifecycle proof |

Historical “all tasks complete” map-generator notes are implementation snapshots, not current production proof.

The [release and world-building plan](RELEASE_AND_WORLD_BUILDING_PLAN.md) records generator correctness and the implemented three-room module/editor gate. Canonical metadata and socket validation are shared by the generator schema and editor library; document-owned channels execute real key/switch/door/objective gameplay. Automatic generator realization, rule/voxel integration, the full composed mission, mission graphs, hubs and release integrations remain open.

Source and exported Linux editor → package → game smokes preserve geometry, root metadata and channels through save/reopen/resave and `.mdsl` extraction; the ownership and cursor defects are repaired. [Editor Round-Trip Proof](EDITOR_ROUNDTRIP_PROOF.md) records native artifacts and pressure-blocked graphical acceptance. Pinning, controlled regeneration, finished audiovisual review and persistent travel remain separate.

## Performance and Release

1. Capture display-synchronized solo gameplay.
2. Capture splitscreen and multiplayer sessions with player count/map/build context.
3. Test at least one lower-end target and one long session.
4. Review spikes, memory, gameplay anomalies, and teardown leaks—not only average FPS.
5. Build/package supported targets and produce a known-limits matrix.
6. Clear, exclude, or replace all remaining unverified provenance rows and inspect packaged notices.
7. Promote release wording only after all readiness validators and distribution-clearance checks agree.

## Exit Criteria for a 1.0 Candidate

- Complete filtered Godot/GUT suite at an accepted documented boundary.
- Complete batched lane summaries with no hidden/incomplete runner result.
- Reviewed manual evidence for the maintained golden-demo route.
- Contextualized performance evidence for declared supported modes/hardware.
- Proven multiplayer and packaging scope.
- Current docs contain no project-wide claims stronger than the evidence.
- `tools/validate_production_readiness.sh --run-godot-tests --strict` passes.
- `tools/generate_provenance_ledger.py --strict` passes and packaged notices are inspected.
