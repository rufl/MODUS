# MODUS Current Status

> **Documentation status: maintained reference.** Updated 2026-10-05. This document separates source availability, focused observations, and release readiness. A passing check proves only the boundary it exercises.

## Baseline

| Item | Value |
| --- | --- |
| Project version | `0.9.5-beta` |
| Engine target | Godot `4.7.2` (`4.7+` project feature) |
| Public release | [`v0.9.5-beta`](https://github.com/rufl/MODUS/releases/tag/v0.9.5-beta) |
| Release source commit | `1367b270d651b1a2588044774a15f1dbeb2b8b51` |
| License | MIT for repository code; third-party assets retain their listed terms |
| Readiness | Experimental beta; not production-ready |

## Status vocabulary

- **Implemented:** source and data exist in the current tree.
- **Observed:** a named focused check or manual route exercised the stated boundary.
- **Open:** representative acceptance, security, scale, platform, or usability evidence is still missing.

Implemented does not imply observed. Observed does not imply production-ready.

## Capability matrix

| Capability | Implemented | Observed boundary | Important open work |
| --- | --- | --- | --- |
| First-person movement and combat | Movement states, weapons, damage, projectiles, effects, and physics services | Focused unit/property checks and the automated showcase route | Balance, broad hardware acceptance, long-session regressions |
| Inventory and loot | Item registries, pickups, drops, inventory operations, and loot tables | Deterministic focused tests and authored demo paths | Broader content progression and economy tuning |
| Enemies and matches | Enemy behaviors, match state, scores, timers, and authored encounters | Focused behavior checks and demo-world smoke paths | Representative encounter variety and extended sessions |
| Procedural worlds | Seeded generation, worker lifecycle, layout contracts, and authored world integration | Seed determinism, bounded generation, repeated cancellation/replacement checks, an eight-seed matrix with explicit failure reporting, and a bounded 128×128 soak covering two cancellation/replacement transitions with static-memory/object telemetry | Production-scale and low-end memory pressure, and cross-runtime determinism |
| ENet multiplayer | Host/join paths, dedicated-server code, authority checks, RPC allowlisting, rate limits, prediction, and reconnection support | Focused local lifecycle, inventory, reconnect, late-join, and authority observations | Representative Internet latency/loss, hostile clients, concurrency, and dedicated-client acceptance |
| Steam integration | Adapter and conditional initialization paths | Authenticated local initialization only | Two-account sessions, relay/P2P, public services, and Workshop transfer |
| Editor tooling | Embedded editor, standalone editor code, `.mdsl` export/import, and history operations | Focused save/export/reload and runtime-history checks | Full exported-app graphical workflow and wider content authoring acceptance |
| Modding | JSON/JSON5 data, registries, sample mods, override rules, and package validation | Local filesystem/package validation, enforced mod/save compatibility checks, rejected-manifest diagnostics, and sample-mod checks | Public distribution, schema migration, sandbox/security guarantees |
| UI and input | Main menu, settings, mod manager, gamepad-aware navigation, and showcase surfaces | Automated smoke captures at 800×600 and 1280×720 | Localization, broader accessibility review, unusual aspect ratios, full controller matrix |
| Performance | Benchmarks, budgets, telemetry hooks, and evidence validators | Bounded local measurements recorded by the maintained proof tools | Representative low-end hardware, multiplayer scale, and long-run telemetry |

## Public beta evidence

The public beta workflow produced Linux x86-64, Windows x86-64, and macOS universal archives plus a checksum manifest. Archive integrity and a bounded Linux headless startup were checked before publication.

| Asset | SHA-256 |
| --- | --- |
| `modus-0.9.5-beta-linux-x86_64.tar.gz` | `dc6fc0cb49aecdb8a075bdc45295a61b7622f340be3acb8d109608e074efb2b3` |
| `modus-0.9.5-beta-windows-x86_64.zip` | `77adbd95f005afdb0820215649b5b66b1d1c02c480a9b1b2d8c68cddfba1bd81` |
| `modus-0.9.5-beta-macos-universal.zip` | `0605a65ff3feff6a4705437d297c206162442788e564603ab1f85699691a0183` |
| `SHA256SUMS` | `42346a904f4114d769c5ada42595ca9454590018fd25a558da11a05678b63d48` |

The Windows archive contains an x86-64 PE executable. The macOS application contains x86-64 and arm64 Mach-O slices. These format checks do not replace native target acceptance.

## Release blockers

MODUS is not release-ready while these boundaries remain open:

1. signing and notarization for supported desktop platforms;
2. native Windows and macOS end-to-end acceptance on representative systems;
3. representative multiplayer latency, loss, scale, and adversarial testing;
4. full exported editor/mod workflow acceptance;
5. broader accessibility, controller, and localization validation;
6. low-end hardware and long-session performance evidence;

The public mod-package and save-data compatibility policy is now documented and enforced by the repository validator, runtime manifest paths, and save restoration guard. This closes the format-policy blocker only; distribution and native/runtime acceptance boundaries remain open.
## Evidence surfaces

- [Release Evidence Bundle](./RELEASE_EVIDENCE_BUNDLE.md)
- [Mod and Save Compatibility Policy](./MOD_COMPATIBILITY_POLICY.md)
- [Known Limits Matrix](./KNOWN_LIMITS_MATRIX.md)
- [Multiplayer Authority Model](./MULTIPLAYER_AUTHORITY_MODEL.md)
- [Performance Baseline Proof](./PERFORMANCE_BASELINE_PROOF.md)
- [Editor Round-Trip Proof](./EDITOR_ROUNDTRIP_PROOF.md)
- [Documentation Truth](./DOCUMENTATION_TRUTH.md)
- [Roadmap](./ROADMAP.md)

## Refreshing the baseline

Use focused checks for the area being changed. The non-graphical repository contracts are:

```bash
bash tools/check_project_truth.sh
bash tools/check_documentation_truth.sh
bash tools/check_headless_runner_manifest.sh
```

Graphical checks must run in a disposable isolated display environment. Full matrices are reserved for an explicit final verification run; aggregate historical results never certify an arbitrary later commit.
