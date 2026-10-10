# Changelog

> **Documentation status: maintained reference.** Public release history and unreleased repository changes.

Notable public changes to MODUS are recorded here. The project follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) conventions while it remains pre-1.0.

## [Unreleased]

### Added

- Branded repository landing page with direct beta downloads, architecture, evidence boundaries, and contribution paths.
- Structured bug and feature issue forms, pull-request checklist, Code of Conduct, contributor guide, security advisory path, ownership rules, and automated GitHub Actions dependency updates.
- Repository secret-scanning configuration with documented false-positive exclusions.
- Imported Hazard Pay's 40 PSX footstep recordings under a retained game-use notice, with eight surface banks and random per-playback override selection.

### Changed

- Renamed release archive and cleanup tooling around public MODUS concepts.
- Reduced release documentation to current public evidence, checksums, limitations, and reproducible commands.
- Clarified that local validation telemetry is opt-in and has no remote-service dependency.
- Defined and enforced the public mod-package compatibility fields and `GameStateManager` save-schema rejection contract.
- Bound map-generation monitors to their owning worker thread, preventing rapid cancellation/replacement cycles from finalizing the wrong generation.
- Exposed rejected mod-package paths and validation errors through the runtime `mod_rejected` signal and `ModLoader.get_rejected_mods()`.
- Added a headless procedural seed matrix validator covering eight bounded seeds across two deterministic passes with seed-specific failure reporting.
- Fixed cancelled map generations retaining the grid/context and worker-owned managers, and added a bounded 128×128 cancellation/replacement soak with memory/object telemetry.
- Replaced the main-menu warrior artwork with the procedural skyline across the game and public screenshots.
- Refreshed the public automated showcase video with unobscured texture-backed scenery and character exhibits from the maintained route.
- Restored the textured PSX skeleton exhibit to its native meter scale; the previous 0.08 scale reduced it to a nearly invisible 17 cm figure in the Showcase.
- Expanded the maintained Showcase and Breakwater demo maps to 72 collision-free imported model placements per profile, adding crowbars, conditioners, conference chair variants, an orange office chair, metal fence variants, and pipe boxes alongside the previous gas masks, hammers, flashlights, computer hardware, and authored exhibits.
- Expanded the Showcase demo's authored surface metadata so movement resolves concrete, metal, wood, grass, dirt, gravel, stairs, and stone footstep banks from scene materials.

- Replaced dummy save slots with SaveService/PlayerProgression discovery and canonical slot metadata.
- Made boot checks validate live memory, audio buses, ENet transport, and the maintained player scene, with explicit failure signaling.
- Replaced false-green HUD integration branches with awaited player-scene setup and authored HUD/service contract assertions.
- Added procedural wood-panel crack decals and removed the missing-asset TODO path.
- Removed the archived adapter property suite that only exercised placeholder classes; tightened movement, configuration, and undo/redo tests to fail on missing required behavior.
- Fixed TimerUtils.wait() to retain an awaitable active-tree fallback and renamed generated map materials from placeholder to procedural.
- Implemented optional hazard-entry 3D audio instead of leaving the body-entered callback inert.
- Fixed backpack retrieval to merge serialized slot/equipment data atomically, persist the authoritative inventory, and emit explicit ownership-denied feedback instead of silently returning.
- Converted recoverable splitscreen lifecycle, configuration, viewport, performance, controller-assignment, RPC-rate-limit, and server-tick diagnostics to typed runtime signals, preserving failure observability without polluting the engine warning/error channels.
- Removed test-suite orphaned-object and leaked `UndoRedo` instances, and added focused telemetry coverage for bounded server-tick overruns.

### Removed

- Obsolete release paths and unpublished integration references from the public tree.
- Retired the unused main-menu warrior source asset and provenance entry.

## [0.9.5-beta] - 2026-09-30

### Added

- Public beta archives for Linux x86-64, Windows x86-64, and macOS universal.
- Published SHA-256 manifest for every downloadable gameplay archive.
- Automated archive-integrity, executable-format, architecture, and bounded Linux headless-startup checks.
- Curated main-menu, showcase, mod-manager, and manual-evidence media at 1280×720 and 800×600.
- Automated 25-second showcase smoke capture.

### Changed

- Aligned the project version, export metadata, release tag, and public status documentation on `0.9.5-beta`.
- Consolidated capability evidence and known release blockers in maintained status documents.

### Security

- Kept public artifacts explicitly unsigned; signing and macOS notarization remain open release blockers.
- Published checksums for independent integrity verification.

## Earlier development

Before the first public beta, the repository accumulated the current movement, combat, inventory, loot, procedural generation, ENet, editor, modding, UI, and focused validation surfaces. Earlier development notes were intentionally consolidated: historical implementation activity is not evidence that the current checkout is release-ready.

[Unreleased]: https://github.com/rufl/MODUS/compare/v0.9.5-beta...HEAD
[0.9.5-beta]: https://github.com/rufl/MODUS/releases/tag/v0.9.5-beta
