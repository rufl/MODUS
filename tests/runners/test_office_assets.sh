#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
python3 - "$root" <<'PY'
from __future__ import annotations

import json
import struct
import sys
from collections import Counter
from pathlib import Path

root = Path(sys.argv[1])
model_root = root / "game/art/models/office"
license_path = root / "docs/licenses/PSX_OFFICE_CC0-1.0.txt"
expected_families = {
    "book_things": 13,
    "carpet_floor": 8,
    "chairs": 13,
    "computers": 8,
    "couches": 15,
    "desks": 28,
    "dividers": 48,
    "extras": 18,
    "file_cabinets": 19,
    "stationary": 10,
}
models_by_family = {
    family.name: sorted(family.glob("*.glb"))
    for family in model_root.iterdir()
    if family.is_dir()
}
assert set(models_by_family) == set(expected_families), sorted(models_by_family)
for family, expected_count in expected_families.items():
    assert len(models_by_family[family]) == expected_count, (family, len(models_by_family[family]))
models = [model for family_models in models_by_family.values() for model in family_models]
assert len(models) == 180, len(models)
assert not list(model_root.rglob("*.fbx")), "FBX duplicates must not enter the canonical runtime tree"
assert not any(
    path.suffix.lower() in {".png", ".jpg", ".jpeg"}
    for path in model_root.rglob("*")
    if path.is_file()
), "GLB import must keep embedded textures; extracted duplicates are not canonical assets"
image_mimes: Counter[str] = Counter()
for model in models:
    sidecar = Path(f"{model}.import")
    assert sidecar.is_file(), sidecar
    assert "gltf/embedded_image_handling=3" in sidecar.read_text(encoding="utf-8"), sidecar
    data = model.read_bytes()
    magic, version, declared_length = struct.unpack("<4sII", data[:12])
    assert magic == b"glTF", model
    assert version == 2, (model, version)
    assert declared_length == len(data), (model, declared_length, len(data))
    offset = 12
    while offset < len(data):
        chunk_length, chunk_type = struct.unpack_from("<II", data, offset)
        chunk = data[offset + 8 : offset + 8 + chunk_length]
        offset += 8 + chunk_length
        if chunk_type == 0x4E4F534A:
            document = json.loads(chunk.rstrip(b" \t\r\n\x00"))
            assert document.get("asset", {}).get("version") == "2.0", model
            image_mimes.update(image.get("mimeType", "missing") for image in document.get("images", []))
            break
assert image_mimes == Counter({"image/jpeg": 143, "image/png": 38}), image_mimes
license = license_path.read_text(encoding="utf-8")
for required in (
    "PSX style office pack",
    "valsekamerplant",
    "CC0",
    "https://valsekamerplant.itch.io/psx-style-opulent-office",
    "391eeaf906a60822a4704e65effdee75962a539ae88bfe6a3f20852879eea409",
):
    assert required in license, required
print("Office asset integrity regression passed.")
PY
python3 "$root/tools/validate_asset_integrity.py" --root "$root" >/dev/null
