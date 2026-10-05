#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
python3 - "$root" <<'PY'
from __future__ import annotations

import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
audio_root = root / "game/art/audio/sfx/psx_footsteps"
config = (root / "game/config/gameplay/audio_overrides.json5").read_text(encoding="utf-8")
license_text = (root / "docs/licenses/HAZARD_PAY_PSX_FOOTSTEPS_GAME_USE.txt").read_text(encoding="utf-8")

expected_counts = {
    "concrete": 5,
    "dirt": 5,
    "grass": 6,
    "gravel": 5,
    "metal": 5,
    "stairs": 5,
    "stone": 4,
    "wood": 5,
}
all_assets = []
for surface, expected_count in expected_counts.items():
    assets = sorted((audio_root / surface).glob(f"{surface}_*.ogg"))
    assert len(assets) == expected_count, (surface, len(assets))
    assert [asset.name for asset in assets] == [
        f"{surface}_{index:02d}.ogg" for index in range(1, expected_count + 1)
    ]
    for asset in assets:
        assert asset.read_bytes()[:4] == b"OggS", asset
        assert asset.stat().st_size > 0, asset
    all_assets.extend(assets)
assert len(all_assets) == 40, len(all_assets)

for surface, expected_count in expected_counts.items():
    event = f'"footstep_{surface}"'
    match = re.search(event + r"\s*:\s*\[(.*?)\]", config, re.S)
    assert match, event
    paths = re.findall(r'"([^"]+\.ogg)"', match.group(1))
    expected_paths = [
        f"psx_footsteps/{surface}/{surface}_{index:02d}.ogg"
        for index in range(1, expected_count + 1)
    ]
    assert paths == expected_paths, (event, paths)
    assert all((root / "game/art/audio/sfx" / path).is_file() for path in paths)

for scene, surface in {
    "game/world/maps/comprehensive_showcase.tscn": "concrete",
    "game/world/maps/movement_lab.tscn": "stairs",
    "game/world/maps/hazards_arena.tscn": "stone",
    "game/world/maps/interactables_demo.tscn": "metal",
    "game/world/maps/traversal_course.tscn": "wood",
    "game/world/maps/projectile_range.tscn": "gravel",
    "game/world/maps/visual_tweaking_lab.tscn": "dirt",
}.items():
    text = (root / scene).read_text(encoding="utf-8")
    assert f'metadata/surface_type = "{surface}"' in text, (scene, surface)

for required in (
    "Source: https://hazardpay.itch.io/40-free-psx-crunchy-footsteps",
    "commercial and non-commercial",
    "prohibits repackaging or",
    "selling the sound files",
):
    assert required in license_text, required

print("Footstep asset, override-bank, and demo-surface integrity regression passed.")
PY
