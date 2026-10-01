# MODUS Release Evidence Bundle

> **Documentation status: maintained reference.** Updated 2026-09-30. This bundle makes public beta evidence easy to inspect without turning bounded checks into broad readiness claims.

## Release identity

| Field | Value |
| --- | --- |
| Tag | [`v0.9.5-beta`](https://github.com/rufl/MODUS/releases/tag/v0.9.5-beta) |
| Source commit | `1367b270d651b1a2588044774a15f1dbeb2b8b51` |
| Engine | Godot `4.7.2-stable` |
| License | MIT for repository code; see [Attribution](ATTRIBUTION.md) for third-party terms |
| Distribution boundary | Unsigned beta archives; macOS is not notarized |

## Published artifacts

| Artifact | Size (bytes) | SHA-256 |
| --- | ---: | --- |
| `modus-0.9.5-beta-linux-x86_64.tar.gz` | 131,401,146 | `dc6fc0cb49aecdb8a075bdc45295a61b7622f340be3acb8d109608e074efb2b3` |
| `modus-0.9.5-beta-windows-x86_64.zip` | 141,246,788 | `77adbd95f005afdb0820215649b5b66b1d1c02c480a9b1b2d8c68cddfba1bd81` |
| `modus-0.9.5-beta-macos-universal.zip` | 152,177,480 | `0605a65ff3feff6a4705437d297c206162442788e564603ab1f85699691a0183` |
| `SHA256SUMS` | — | `42346a904f4114d769c5ada42595ca9454590018fd25a558da11a05678b63d48` |

Verify after downloading:

```bash
sha256sum --check SHA256SUMS
```

Windows PowerShell provides `Get-FileHash`; macOS provides `shasum -a 256`.

## What the release workflow established

- Linux, Windows, and macOS exports completed from the tagged source.
- Release archives opened successfully and matched their manifest structure.
- The Linux binary completed a bounded headless startup smoke.
- The Windows client was identified as PE32+ x86-64.
- The macOS application contained x86-64 and arm64 Mach-O slices.
- Checksums were generated from the final uploaded files.

## What it did not establish

- code signing, notarization, or reputation with platform security systems;
- native Windows or macOS gameplay acceptance;
- graphical quality across drivers, displays, or accessibility configurations;
- public-service multiplayer, Steam, or Workshop behavior;
- security certification, performance certification, or production readiness.

## Curated visual evidence

| Surface | 1280×720 | 800×600 | Purpose |
| --- | --- | --- | --- |
| Main menu | [PNG](media/release/main_menu_1280x720.png) | [PNG](media/release/main_menu_800x600.png) | Primary navigation over the procedural skyline |
| Showcase welcome | [PNG](media/release/showcase_welcome_1280x720.png) | [PNG](media/release/showcase_welcome_800x600.png) | Guided evidence route |
| Mod manager | [PNG](media/release/mod_manager_1280x720.png) | [PNG](media/release/mod_manager_800x600.png) | Mod discovery/management surface |
| Evidence recorder | [PNG](media/release/manual_evidence_recorder_1280x720.png) | [PNG](media/release/manual_evidence_recorder_800x600.png) | Manual observation contract |

The [latest automated showcase smoke capture](media/release/golden_demo_smoke_1280x720.mp4) is evidence of the scripted route completing, not proof of game feel or production rendering quality.

## Reproduction surfaces

```bash
bash tools/check_project_truth.sh
bash tools/check_documentation_truth.sh
bash tests/runners/test_release_archive_package.sh
```

The release workflow is defined in [`.github/workflows/beta-release.yml`](../.github/workflows/beta-release.yml). Archive construction lives in [`tools/package_release_archive.py`](../tools/package_release_archive.py). Graphical reruns require a disposable isolated display environment.

For the complete capability boundary, read [Current Status](./CURRENT_STATUS.md) and the [Known Limits Matrix](./KNOWN_LIMITS_MATRIX.md).
