#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
python3 - "$root" <<'PY'
from __future__ import annotations

import struct
import sys
from collections import Counter
from pathlib import Path

root = Path(sys.argv[1])
texture_root = root / "game/art/textures/vfx/brackeys"
license_path = root / "docs/licenses/BRACKEYS_VFX_CC0-1.0.txt"
expected_groups = {
    "predrawn": (".png", 14),
    "flipbooks": (".tga", 14),
    "particles/alpha": (".png", 93),
    "particles/opaque": (".png", 92),
}

assert texture_root.is_dir(), texture_root
actual_groups: dict[str, list[Path]] = {}
for relative_group, (suffix, expected_count) in expected_groups.items():
    group = texture_root / relative_group
    files = sorted(group.glob(f"*{suffix}"))
    assert len(files) == expected_count, (relative_group, len(files), expected_count)
    actual_groups[relative_group] = files

assets = [asset for files in actual_groups.values() for asset in files]
assert len(assets) == 213, len(assets)
discovered = sorted(
    path for path in texture_root.rglob("*") if path.is_file() and path.suffix.lower() in {".png", ".tga"}
)
assert set(assets) == set(discovered), sorted(str(path.relative_to(texture_root)) for path in set(discovered) - set(assets))
assert not list(texture_root.rglob(".DS_Store")), "macOS metadata must not enter the canonical VFX tree"
assert not [
    path
    for path in texture_root.rglob("*")
    if path.is_file() and path.suffix.lower() not in {".png", ".tga", ".import"}
], "canonical VFX tree contains an unexpected file type"

formats: Counter[str] = Counter()
for asset in assets:
    sidecar = Path(f"{asset}.import")
    assert sidecar.is_file(), sidecar
    sidecar_text = sidecar.read_text(encoding="utf-8")
    assert 'importer="texture"' in sidecar_text, sidecar
    assert 'type="CompressedTexture2D"' in sidecar_text, sidecar
    assert f"source_file=\"res://{asset.relative_to(root).as_posix()}\"" in sidecar_text, sidecar

    data = asset.read_bytes()
    if asset.suffix.lower() == ".png":
        assert data[:8] == b"\x89PNG\r\n\x1a\n", asset
        assert data[12:16] == b"IHDR", asset
        width, height = struct.unpack(">II", data[16:24])
        assert width > 0 and height > 0, (asset, width, height)
        formats["PNG"] += 1
    else:
        assert len(data) >= 18, asset
        image_type = data[2]
        width, height, bits = struct.unpack("<HHB", data[12:14] + data[14:16] + data[16:17])
        assert image_type == 2, (asset, image_type)
        assert width > 0 and height > 0, (asset, width, height)
        assert bits in {24, 32}, (asset, bits)
        formats["TGA"] += 1

license_text = license_path.read_text(encoding="utf-8")
for required in (
    "Brackeys' VFX Bundle",
    "CC0",
    "https://brackeysgames.itch.io/brackeys-vfx-bundle",
    "https://github.com/RPicster/Godot-particle-and-vfx-textures",
    "https://unity.com/blog/engine-platform/free-vfx-image-sequences-flipbooks",
    "ac0fbf5d5a07688a5d4d35fd0bbae783597d819a3d8a92893b05eb69ddb144c5",
):
    assert required in license_text, required

assert formats == Counter({"PNG": 199, "TGA": 14}), formats
print("Brackeys VFX asset integrity regression passed.")
PY
python3 "$root/tools/validate_asset_integrity.py" --root "$root" >/dev/null
