# Changelog

> **Documentation status: maintained reference.** Public release history and unreleased repository changes.

Notable public changes to MODUS are recorded here. The project follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) conventions while it remains pre-1.0.

## [Unreleased]

### Added

- Branded repository landing page with direct beta downloads, architecture, evidence boundaries, and contribution paths.
- Structured bug and feature issue forms, pull-request checklist, Code of Conduct, contributor guide, security advisory path, ownership rules, and automated GitHub Actions dependency updates.
- Repository secret-scanning configuration with documented false-positive exclusions.

### Changed

- Renamed release archive and cleanup tooling around public MODUS concepts.
- Reduced release documentation to current public evidence, checksums, limitations, and reproducible commands.
- Clarified that local validation telemetry is opt-in and has no remote-service dependency.
- Replaced the main-menu warrior artwork with the procedural skyline across the game and public screenshots.
- Refreshed the public automated showcase video from the latest maintained route.

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
