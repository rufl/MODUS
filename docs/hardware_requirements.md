# MODUS Hardware Evidence and Requirements

> **Documentation status: maintained reference.** No minimum or recommended shipping specification has been validated. This file records only observed evidence and unproven requirements.

**Languages:** [English](hardware_requirements.md) · [Português (Brasil)](pt-BR/HARDWARE_REQUIREMENTS.md)
**Updated:** September 29, 2026
**Version:** `0.9.5-beta` · **Toolchain:** Godot 4.7.2

## Supported Claim

MODUS requires a platform capable of running Godot 4.7 and the project's renderer/physics configuration. The repository does not yet have evidence for a customer-facing minimum, recommended, or optimal hardware specification.

Do not publish CPU, GPU, RAM, storage, player-count, resolution, or FPS requirements from older documentation. Those tables were estimates and included explicitly fabricated examples.

## Recorded Hardware Evidence

The published summary preserves one warmed bounded Showcase observation; its raw CSV remains local-only and is absent from fresh clones:

| Field | Recorded value |
| --- | --- |
| Date | September 27, 2026 |
| GPU | Intel Arc A770 through Mesa |
| Renderer | Godot compatibility renderer |
| Scene | `res://game/world/maps/showcase.tscn` |
| Duration | 69.90 seconds |
| Samples | 66 |
| Maximum frame time | 7.58 ms |
| Minimum observed FPS | 7.00 |

The capture was headless/unthrottled and validates evidence shape and duration, not a supported-hardware target or display-synchronized gameplay performance. Review [Performance Baseline Proof](PERFORMANCE_BASELINE_PROOF.md) before citing it.

## Unproven Areas

- Display-synchronized solo gameplay
- Splitscreen with real controllers
- Networked multiplayer with real peers
- Dedicated-server capacity
- Integrated GPUs and low-end discrete GPUs
- Windows, macOS, Steam Deck, and non-Mesa Linux configurations
- Long-session memory stability
- Heavy-combat and high-entity-count scenes
- Editor workload and map-generation workload
- Download size, installed size, and mod-storage recommendations
- Bandwidth and latency requirements

## How to Produce Valid Hardware Evidence

Record at least:

1. Commit/build identifier and Godot version.
2. Operating system, renderer, driver, CPU, GPU, RAM, and resolution.
3. Scene/map, game mode, player count, bot/entity count, and quality settings.
4. Capture duration, frame pacing, FPS distribution, memory, and notable warnings.
5. Whether the run was display-synchronized, headless, editor, debug, or export build.
6. Reproduction notes and the raw CSV/log artifact.

Place PerformanceLogger CSVs under `logs/performance_logs/`, review their context, and run:

```bash
tools/validate_performance_evidence.sh --strict
```

The validator writes ignored local output `docs/PERFORMANCE_EVIDENCE_REPORT.md`. Missing local CSVs must remain missing evidence; the historical table above is not a substitute input or a new PASS.

A validator PASS confirms evidence shape and duration only. Product requirements still require reviewed, repeatable runs across the declared support matrix.

## Current Recommendation

Use MODUS for development and evaluation on hardware that already runs Godot 4.7 comfortably. Determine project-specific requirements from your own exported build and content. Do not market the historical estimated tiers as tested specifications.
