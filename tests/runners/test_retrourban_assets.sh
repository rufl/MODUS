#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
python3 - "$root" <<'PY'
from __future__ import annotations

import re
import struct
import sys
from pathlib import Path

root = Path(sys.argv[1])
texture_root = root / "game/art/textures/retro_urban"
material_root = root / "game/art/materials/retro_urban"
license_path = root / "docs/licenses/RETOURBAN_CC-BY-4.0.txt"
pngs = sorted(texture_root.rglob("*.png"))
materials = sorted(material_root.glob("*.tres"))
assert len(pngs) == 240, len(pngs)
assert len(materials) == 40, len(materials)
for path in pngs:
    header = path.read_bytes()[:24]
    assert header[:8] == b"\x89PNG\r\n\x1a\n", path
    width, height = struct.unpack(">II", header[16:24])
    assert (width, height) == (128, 128), (path, width, height)
for material in materials:
    content = material.read_text(encoding="utf-8")
    references = re.findall(r'path="res://([^\"]+\.png)"', content)
    assert len(references) == 6, (material, references)
    for reference in references:
        assert (root / reference).is_file(), (material, reference)
license = license_path.read_text(encoding="utf-8")
for required in (
    "RetroUrban Free",
    "Binbun3D",
    "CC BY 4.0",
    "https://binbun3d.itch.io/retrourban-free",
):
    assert required in license, required
print("RetroUrban asset integrity regression passed.")
PY
python3 "$root/tools/validate_asset_integrity.py" --root "$root" >/dev/null
