# Procedural Map Generator

> **Documentation status: maintained reference.** This page describes live source and bounded proof. Historical task-completion reports are local-only, absent from fresh clones, and never current readiness evidence.

## Entry point

`game/scripts/map_generator/map_generator.gd` is the `MapGenerator` autoload declared in `project.godot`. Its public orchestration surface includes:

- `generate_map(seed_str, generation_config)`;
- `cancel_generation()`;
- `generate_episode(base_seed, episode_length, generation_config)`;
- `export_map(...)`;
- performance-target and feature-availability queries.

Signals report generation start, progress, completion, failure, and cancellation.

## Source components

The directory contains grid, shape-grammar, hallway, cellular-automata, outdoor, cave, boss-arena, CSG, prefab, theme, navigation, gameplay placement, secret/key-lock, LOD, MultiMesh, occlusion, validation, export, batch, and debugging code. Data assets live under `game/data/map_generator/`.

Component existence does not prove that every optional phase contributes valid runtime geometry under every configuration.

## Threading boundary

The generator owns a worker `Thread`, cancellation flag, and explicit join on
exit. Scene-tree work is deferred to the main thread. The threaded directory
proof currently passes as a complete aggregate.

## Current focused evidence

- Generated boss runtime proof: 1/1 passed.
- Threaded generator aggregate: 8/8 passed.
- Aggregate coverage includes generation, cancellation/replacement, CSG
  fallback, navigation baking, gameplay placement, navigation reachability,
  generated boss defeat, extraction, and export/reload.
- Current focused and aggregate runs reported no ObjectDB teardown leak.

These results support the implemented generator contracts, but do not support
the old “all 40 tasks complete” or “production ready” conclusions.

## Minimal source usage

```gdscript
var config_script := preload("res://game/scripts/map_generator/generation_config.gd")
var config = config_script.new()

MapGenerator.generation_completed.connect(_on_generation_completed)
MapGenerator.generation_failed.connect(_on_generation_failed)
MapGenerator.generate_map("example-seed", config)
```

Use the actual `GenerationConfig` properties in source; do not copy old sample metadata/config fields without verifying them.

## Required closure work

- Exercise generated scenes in a normal graphical runtime.
- Capture generation time/memory on declared hardware; code targets are not measured guarantees.
- Run save/export/reload compatibility for generated artifacts across release targets.
- Verify multiplayer authority, hub/travel lifecycle, Steam lifecycle, and
  platform exports.
- Replace remaining placeholder weapon assets with production assets where
  available.

Until then, the truthful status is **broad implementation with green focused
generator evidence and unresolved graphical, performance, release, and
multiplayer evidence**.
