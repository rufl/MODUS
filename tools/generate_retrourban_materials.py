#!/usr/bin/env python3
"""Generate reusable Godot materials for the imported RetroUrban texture sets."""

from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TEXTURE_ROOT = ROOT / "game/art/textures/retro_urban"
MATERIAL_ROOT = ROOT / "game/art/materials/retro_urban"
MAP_SUFFIXES = {
    "basecolor": "_basecolor.png",
    "metallic": "_metallic.png",
    "roughness": "_roughness.png",
    "ao": "_ambientocclusion.png",
    "normal": "_normal.png",
    "height": "_height.png",
}


def material_id(basecolor: Path) -> str:
    relative = basecolor.relative_to(TEXTURE_ROOT)
    family = relative.parts[0].lower()
    stem = basecolor.stem.removesuffix("_basecolor").lower()
    return f"{family}_{stem}"


def display_name(basecolor: Path) -> str:
    relative = basecolor.relative_to(TEXTURE_ROOT)
    family = relative.parts[0]
    stem = basecolor.stem.removesuffix("_basecolor").replace("_", " ")
    return f"RetroUrban / {family} / {stem}"


def resource_text(basecolor: Path) -> str:
    paths = {
        key: basecolor.with_name(basecolor.name.removesuffix("_basecolor.png") + suffix)
        for key, suffix in MAP_SUFFIXES.items()
    }
    refs = {
        key: f'ExtResource("{index}_{key}")'
        for index, key in enumerate(MAP_SUFFIXES, start=1)
    }
    ext_resources = "\n".join(
        f'[ext_resource type="Texture2D" path="res://{path.relative_to(ROOT).as_posix()}" id="{index}_{key}"]'
        for index, (key, path) in enumerate(paths.items(), start=1)
    )
    return (
        "[gd_resource type=\"StandardMaterial3D\" load_steps=7 format=3]\n\n"
        f"{ext_resources}\n\n"
        "[resource]\n"
        f"resource_name = \"{display_name(basecolor)}\"\n"
        f"albedo_texture = {refs['basecolor']}\n"
        f"metallic_texture = {refs['metallic']}\n"
        f"roughness_texture = {refs['roughness']}\n"
        "ao_enabled = true\n"
        f"ao_texture = {refs['ao']}\n"
        "normal_enabled = false\n"
        f"normal_texture = {refs['normal']}\n"
        "heightmap_enabled = false\n"
        f"heightmap_texture = {refs['height']}\n"
        "texture_filter = 1\n"
        "uv1_triplanar = true\n"
    )


def main() -> int:
    MATERIAL_ROOT.mkdir(parents=True, exist_ok=True)
    basecolors = sorted(TEXTURE_ROOT.rglob("*_basecolor.png"))
    if not basecolors:
        raise SystemExit("No RetroUrban basecolor maps found")
    generated: set[Path] = set()
    for basecolor in basecolors:
        paths = [
            basecolor.with_name(basecolor.name.removesuffix("_basecolor.png") + suffix)
            for suffix in MAP_SUFFIXES.values()
        ]
        missing = [path for path in paths if not path.is_file()]
        if missing:
            raise SystemExit(f"Missing map set for {basecolor}: {missing}")
        output = MATERIAL_ROOT / f"{material_id(basecolor)}.tres"
        output.write_text(resource_text(basecolor), encoding="utf-8")
        generated.add(output)
    for stale in MATERIAL_ROOT.glob("*.tres"):
        if stale not in generated:
            stale.unlink()
    print(f"Generated {len(generated)} RetroUrban materials.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
