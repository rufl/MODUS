#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
python3 - "$root" <<'PY'
from __future__ import annotations

import struct
import sys
from pathlib import Path

root = Path(sys.argv[1])
model_root = root / "game/art/models/fences"
texture_root = root / "game/art/textures/fences"
license_path = root / "docs/licenses/PSX_WALLS_FENCES_CC0-1.0.txt"
expected_families = {
    "brick_fence": 7,
    "drystone_wall": 9,
    "low_wooden_fence": 16,
    "metal_fence": 7,
    "plackard_wall": 24,
    "plaster_wall": 9,
    "white_picket_fence": 7,
}
models_by_family = {
    family.name: sorted(family.glob("*.glb"))
    for family in model_root.iterdir()
    if family.is_dir()
}
assert set(models_by_family) == set(expected_families), sorted(models_by_family)
for family, expected_count in expected_families.items():
    assert len(models_by_family[family]) == expected_count, (family, len(models_by_family[family]))
models = [model for models in models_by_family.values() for model in models]
assert len(models) == 79, len(models)
assert not list(model_root.rglob("*.fbx")), "FBX duplicates must not enter the canonical runtime tree"
assert not any(
    path.suffix.lower() in {".png", ".jpg", ".jpeg"}
    for path in model_root.rglob("*")
    if path.is_file()
), "GLB import must keep embedded textures; extracted duplicates are not canonical assets"
for model in models:
    sidecar = Path(f"{model}.import")
    assert sidecar.is_file(), sidecar
    assert "gltf/embedded_image_handling=3" in sidecar.read_text(encoding="utf-8"), sidecar
    header = model.read_bytes()[:12]
    magic, version, declared_length = struct.unpack("<4sII", header)
    assert magic == b"glTF", model
    assert version == 2, (model, version)
    assert declared_length == model.stat().st_size, (model, declared_length, model.stat().st_size)
textures = sorted(
    path
    for path in texture_root.iterdir()
    if path.is_file() and path.suffix.lower() in {".png", ".jpg", ".jpeg"}
)
assert len(textures) == 34, len(textures)
assert all(path.suffix.lower() in {".png", ".jpg", ".jpeg"} for path in textures)
assert all(path.stat().st_size > 0 for path in textures)
license = license_path.read_text(encoding="utf-8")
for required in (
    "PSX style modular walls & fences",
    "valsekamerplant",
    "CC0",
    "https://valsekamerplant.itch.io/psx-style-walls-fences",
):
    assert required in license, required
print("Fence asset integrity regression passed.")
PY
python3 "$root/tools/validate_asset_integrity.py" --root "$root" >/dev/null
