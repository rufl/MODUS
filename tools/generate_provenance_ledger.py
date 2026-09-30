#!/usr/bin/env python3
"""Generate MODUS's deterministic distribution-asset provenance ledger."""

from __future__ import annotations

import argparse
import csv
import hashlib
import io
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "docs/PROVENANCE_LEDGER.csv"
SCAN_ROOTS = ("game", "shared", "standalone", "mods")
ASSET_SUFFIXES = {
    ".dae",
    ".fbx",
    ".exr",
    ".flac",
    ".gdshader",
    ".glb",
    ".gltf",
    ".jpeg",
    ".jpg",
    ".mp3",
    ".obj",
    ".ogg",
    ".otf",
    ".png",
    ".res",
    ".svg",
    ".tga",
    ".tres",
    ".ttf",
    ".wav",
}
EXTRA_PATHS = ("shared/shaders/blood_pool.gd",)

KENNEY = {
    "game/art/textures/kenney_particle_pack/circle_05.png":
        "616c989de83cd805c80ed78f692c5a4cb754151edbb1d3550f20cc3a2857b706",
    "game/art/textures/kenney_particle_pack/star_05.png":
        "9113f3620bf54a4afc8560ed006e67363850aceb46bcac059f5199e43407cd3b",
    "game/art/textures/kenney_prototype_textures/dark/texture_09.png":
        "46e1233f862fb4da9e7ab6821bb5614f5574bfc39d3199606628b91f05f82e1d",
    "game/art/textures/kenney_prototype_textures/orange/texture_07.png":
        "e6f01b5ae1b315e2ae6dbe9c2ee3c22053479ecb4bed90910f1142d0563b8d83",
    "game/art/textures/kenney_prototype_textures/orange/texture_09.png":
        "6fb33751454dcfeb0181041e2e70d438bd3847be1fc8c72123a9477d22dc5c34",
}
ORIGINAL_ICONS = {
    "game/art/ui/icons/potion_health.svg":
        "ffb68a31efcc9ea6a2ab481a3dbbddc36377e4c7966fee515fe8af65c3f22f5b",
    "game/art/ui/icons/potion_health_large.svg":
        "2a07bdd3da77dca9c3920022a98c5aee90d6b824ed96221aa769bcc03a81afd5",
    "game/art/ui/icons/shield_boost.svg":
        "eed09cf9078b44ae30c1b276224fa552452892c60b102d311d2c1ea05d387627",
    "game/art/ui/icons/stim_speed.svg":
        "82bb500083df28c817688957d7dd264aada6f8b3e36f0159056a1d2241d85c78",
    "game/art/ui/icons/stim_damage.svg":
        "c68f57b7dc0105aeb224b095a8cd59800e69f3aad0b9190687dc9295bdc17f4f",
    "game/art/ui/icons/material_scrap.svg":
        "685fbd94e0b6f742c11c7c72923a397225f677f28aa6926d31c50ebb6bdbe375",
    "game/art/ui/icons/material_energy.svg":
        "a3cb626d7aca83f81d7fde518edbc4d144a7fb53d69748b30de37b5f6da4c42b",
    "game/art/ui/icons/ammo_pistol.svg":
        "97ee8f258fa8eacb236e441183d26de2bd47b5054c694d4139f9ad503c169b9c",
    "game/art/ui/icons/ammo_shells.svg":
        "a9e47cb2132ad30302be7de787b600cce216c14193bd4400c831db99b2bc1e87",
    "game/art/ui/icons/ammo_rockets.svg":
        "f96dd0d2dfabca50a929737e8269ea81f79b0c353c07ed46db01b8c89955a2c4",
}
LIQUID_PATHS = {
    "game/art/materials/liquids/retro_blood.tres",
    "game/art/materials/liquids/retro_lava.tres",
    "game/art/materials/liquids/retro_poison.tres",
    "game/art/materials/liquids/retro_water.tres",
    "game/art/shaders/enhanced_liquid.gdshader",
    "game/art/shaders/liquid.gdshader",
    "game/art/shaders/retro_blood.gdshader",
    "game/art/shaders/retro_lava.gdshader",
    "game/art/shaders/retro_poison.gdshader",
    "game/art/shaders/retro_water.gdshader",
}
SKYBOX_PATHS = {
    "game/world/actors/sky/clouds.gdshader",
    "game/world/actors/sky/retro_sky.gdshader",
    "game/world/actors/sky/retro_sky.tres",
    "game/world/actors/sky/retro_sky_mat.tres",
}
MIT_PROJECT_PATHS = {
    "game/art/models/skel/procedural_reference.glb",
    "game/core/network/default_network_config.tres",
    "game/default_bus_layout.tres",
    "game/scenes/world.tres",
    "game/scripts/features/effects/effects/gib_physics.tres",
    "shared/editor_core/icons/level_root.svg",
    "shared/editor_core/icons/plugin_icon.svg",
    "shared/editor_core/icons/spawn_enemy.svg",
    "shared/editor_core/icons/spawn_item.svg",
    "shared/editor_core/icons/spawn_player.svg",
    "shared/editor_core/icons/spawn_point.svg",
}
MIT_SHADER_PATHS = {
    "game/art/shaders/atmospheric_volume.gdshader",
    "game/art/shaders/blood_decal.gdshader",
    "game/art/shaders/blood_trail.gdshader",
    "game/art/shaders/blur.gdshader",
    "game/art/shaders/dark_camo.gdshader",
    "game/art/shaders/debris_shard.gdshader",
    "game/art/shaders/first_person_body.gdshader",
    "game/art/shaders/gib_meat.gdshader",
    "game/art/shaders/godmode.gdshader",
    "game/art/shaders/invisibility.gdshader",
    "game/art/shaders/post_process.gdshader",
    "game/art/shaders/retro_decal.gdshader",
    "game/art/shaders/retro_ember_trail.gdshader",
    "game/art/shaders/retro_particle.gdshader",
    "game/art/shaders/retro_smoke_trail.gdshader",
    "game/art/shaders/retro_tracer.gdshader",
    "game/art/shaders/screen_effects.gdshader",
    "game/art/shaders/smoke_fireball.gdshader",
    "game/art/shaders/spectator.gdshader",
    "game/art/shaders/water_advanced.gdshader",
    "shared/shaders/blood_pool.gdshader",
    "shared/shaders/blood_pool_retro.gdshader",
}
MIT_EFFECT_TEXTURE_PATHS = {
    "game/art/textures/blood_drip.png",
    "game/art/textures/decals/blood_splat.png",
    "game/art/textures/decals/bullet_hit.png",
    "game/art/textures/decals/burn_scorch.png",
    "game/art/textures/decals/hivelocity_hit.png",
    "game/art/textures/decals/mid_blood_splat.png",
    "game/art/textures/decals/smol_blood_splat.png",
}
MIT_WEAPON_ICON_PATHS = {
    "game/ui/icons/weapons/chaingun.svg",
    "game/ui/icons/weapons/grenade_launcher.svg",
    "game/ui/icons/weapons/knife.svg",
    "game/ui/icons/weapons/machinegun.svg",
    "game/ui/icons/weapons/nuker3000.svg",
    "game/ui/icons/weapons/pistol.svg",
    "game/ui/icons/weapons/railgun.svg",
    "game/ui/icons/weapons/rocket_launcher.svg",
    "game/ui/icons/weapons/shotgun.svg",
    "game/ui/icons/weapons/spinlaser.svg",
}
RETRO_TEXTURE_PATHS = {
    "shared/editor_core/textures/retro/floor_grating_01.png",
    "shared/editor_core/textures/retro/floor_tile_01.png",
    "shared/editor_core/textures/retro/wall_concrete_01.png",
    "shared/editor_core/textures/retro/wall_metal_01.png",
}

RETROURBAN_PREFIXES = (
    "game/art/textures/retro_urban/",
    "game/art/materials/retro_urban/",
)
PSX_FENCE_PREFIXES = (
    "game/art/models/fences/",
    "game/art/textures/fences/",
)
WRAD_ARMS_PREFIX = "game/art/models/first_person/wrad_arms/"
PSX_OFFICE_PREFIX = "game/art/models/office/"
BRACKEYS_VFX_PREFIX = "game/art/textures/vfx/brackeys/"
BINBUN_WATER_PREFIXES = (
    "game/art/shaders/third_party/binbun_water/",
    "game/art/models/third_party/binbun_water/",
    "game/art/materials/liquids/binbun_water",
)
BINBUN_WATER_SOURCE = "https://binbun3d.itch.io/godot-water-shader"
BINBUN_WATER_NOTICE = "docs/licenses/BINBUN_GODOT_WATER_CC0-1.0.txt"
BINBUN_SKIES_PREFIXES = (
    "game/art/shaders/third_party/binbun_skies/",
    "game/art/materials/sky/third_party/binbun_skies/",
)
BINBUN_SKIES_SOURCE = "https://binbun3d.itch.io/godot-skies"
BINBUN_SKIES_NOTICE = "docs/licenses/BINBUN_GODOT_SKIES_CC0-1.0.txt"
SEWERS_MODEL_PATH = "game/art/models/sewers/Sewers.dae"
SEWERS_SOURCE = "https://elbolilloduro.itch.io/sewers"
SEWERS_NOTICE = "docs/licenses/ELBOLILLODURO_SEWERS_CC0-1.0.txt"
KKRYY_STREET_PREFIX = "game/art/models/third_party/kkryy_street_furniture/"
KKRYY_STREET_SOURCE = "https://kkryy.itch.io/streetfurniture"
KKRYY_STREET_NOTICE = "docs/licenses/KKRYY_STREET_FURNITURE_CC0-1.0.txt"
ELBOLILLODURO_PSX_PREFIX = "game/art/models/third_party/elbolilloduro_psx_models/"
ELBOLILLODURO_PSX_SOURCE = (
    "https://elbolilloduro.itch.io/paquete-de-modelos-low-poly-estilo-psx-2"
)
ELBOLILLODURO_PSX_NOTICE = "docs/licenses/ELBOLILLODURO_PSX_MODELS_CC0-1.0.txt"
ELBOLILLODURO_MINE_PREFIX = "game/art/models/third_party/elbolilloduro_mine/"
ELBOLILLODURO_MINE_SOURCE = "https://elbolilloduro.itch.io/mine"
ELBOLILLODURO_MINE_NOTICE = "docs/licenses/ELBOLILLODURO_MINE_CC0-1.0.txt"
GODGOLDFEAR_INDUSTRIAL_PREFIX = "game/art/models/third_party/godgoldfear_industrial/"
GODGOLDFEAR_INDUSTRIAL_SOURCE = (
    "https://godgoldfear.itch.io/psx-industrial-environment-asset-pack"
)
GODGOLDFEAR_INDUSTRIAL_NOTICE = "docs/licenses/GODGOLDFEAR_INDUSTRIAL_CC-BY-4.0.txt"
CHILLY_DURANGO_RETRO_PREFIX = "game/art/models/third_party/chilly_durango_retro_machinery/"
CHILLY_DURANGO_RETRO_SOURCE = "https://chilly-durango.itch.io/3d-retro-plumbing-wiring"
CHILLY_DURANGO_RETRO_NOTICE = "docs/licenses/CHILLY_DURANGO_RETRO_MACHINERY_CC0-1.0.txt"
CLASSIC64_BREAKWATER_PREFIX = "game/art/models/third_party/classic64_breakwater/"
CLASSIC64_BREAKWATER_SOURCE = (
    "Creator-supplied Readme.txt in the uploaded Classic 64 Asset Pack 0.6 "
    "archive; https://creativecommons.org/share-your-work/public-domain/cc0/"
)
CLASSIC64_BREAKWATER_NOTICE = "docs/licenses/CLASSIC64_ASSET_LIBRARY_CC0-1.0.txt"

LOAFBRR_PIPES_PREFIX = "game/art/models/third_party/loafbrr_pipes/"
LOAFBRR_PIPES_SOURCE = "https://loafbrr.itch.io/pipes-asset-pack"
LOAFBRR_PIPES_NOTICE = "docs/licenses/LOAFBRR_PIPES_CC0-1.0.txt"
PRILDARILL_PREFIX = "game/art/models/third_party/prildarill_low_poly_assets/"
PRILDARILL_SOURCE = "https://prildarill.itch.io/low-poly-shelf"
PRILDARILL_NOTICE = "docs/licenses/PRILDARILL_LOW_POLY_FREE_USE.txt"
MCSTEEG_TRASH_PREFIX = "game/art/models/third_party/mcsteeg_trash_and_debris/"
MCSTEEG_SURVIVAL_PREFIX = "game/art/models/third_party/mcsteeg_survival/"
MCSTEEG_SOURCE = "https://mcsteeg.itch.io/trash-and-debris"
MCSTEEG_NOTICE = "docs/licenses/MCSTEEG_FREE_USE_GAME_ASSETS.txt"
LOOMING_LANDMARKS_PREFIX = "game/art/models/third_party/3dexter_looming_landmarks/"
LOOMING_LANDMARKS_SOURCE = "https://3dexter.itch.io/looming-landmarks-pack"
LOOMING_LANDMARKS_NOTICE = "docs/licenses/3DEXTER_LOOMING_LANDMARKS_CC-BY-4.0.txt"
LUKA_ALEKSIC_SOUND_PREFIX = "game/art/audio/sfx/luka_aleksic/"
LUKA_ALEKSIC_SOUND_SOURCE = "https://aleksicluka.itch.io/various-sound-effects"
LUKA_ALEKSIC_SOUND_NOTICE = "docs/licenses/LUKA_ALEKSIC_SOUND_EFFECTS_CC0-1.0.txt"
COOLER11_WAVES_PREFIX = "game/art/audio/breakwater/ocean_waves/"
COOLER11_WAVES_SOURCE = (
    "Very Simple Waves Pack/README.txt (creator cooler11; official itch.io URL "
    "not included in uploaded archive)"
)
COOLER11_WAVES_NOTICE = "docs/licenses/VERY_SIMPLE_WAVES_PACK_GAME_USE.txt"
AQUILARIUS_RETRO_PREFIX = "game/art/textures/third_party/aquilarius_retro/"
AQUILARIUS_RETRO_SOURCE = "https://aquilarius.itch.io/aquilariusrt"
AQUILARIUS_RETRO_NOTICE = "docs/licenses/AQUILARIUS_RETRO_TEXTURES_CC0-1.0.txt"
LVL11_QUAKE_PREFIX = "game/art/textures/third_party/lvl11_quake_sci_fi/"
LVL11_QUAKE_SOURCE = "https://level-eleven-games.itch.io/quake-like-texture-pack"
LVL11_QUAKE_NOTICE = "docs/licenses/LVL11_QUAKE_TEXTURES_CC0-1.0.txt"
DELVEN_TEXTURE_PREFIX = "game/art/textures/third_party/strideh_delven/"
DELVEN_TEXTURE_SOURCE = "https://strideh.itch.io/delven"
DELVEN_TEXTURE_NOTICE = "docs/licenses/STRIDEH_DELVEN_TEXTURES_GAME_USE.txt"
TORMENT_TEXTURE_PREFIX = "game/art/textures/third_party/strideh_torment/"
TORMENT_TEXTURE_SOURCE = "https://strideh.itch.io/torment"
TORMENT_TEXTURE_NOTICE = "docs/licenses/STRIDEH_TORMENT_TEXTURES_GAME_USE.txt"
STENCIL_DECAL_MASK_PREFIX = "game/art/textures/third_party/strideh_stencil_decals/"
STENCIL_DECAL_MASK_SOURCE = "https://strideh.itch.io/stencil-painted-decal-pack"
STENCIL_DECAL_MASK_NOTICE = "docs/licenses/STRIDEH_STENCIL_DECALS_GAME_USE.txt"
VINRAX_SKELETON_PREFIX = "game/art/models/third_party/vinrax_psx_skeleton/"
VINRAX_SKELETON_SOURCE = "https://vinrax.itch.io/psx-skeleton-character"
VINRAX_SKELETON_NOTICE = "docs/licenses/VINRAX_PSX_SKELETON_FREE_USE.txt"

GENERATED_MAP_OVERVIEW_PATHS = {
    "game/world/maps/overviews/map_overview.png",
}
BLOOD_POOL_PATHS = {
    "game/art/shaders/blood_pool.gdshader",
    "shared/shaders/blood_pool.gd",
}
QUATERNIUS_ANIMATION_PREFIX = "game/art/anims/"
QUATERNIUS_MODEL_PATHS = {
    "game/art/models/mannequin_mesh.glb",
    "game/art/models/mannequin_mesh_Mannequin.res",
    "game/art/models/pistol.glb",
}
QUATERNIUS_SOURCE = "https://quaternius.com/packs/universalanimationlibrary.html"
QUATERNIUS_NOTICE = "docs/licenses/QUATERNIUS_CC0-1.0.txt"
HERO_PATH = "game/art/ui/main_menu_warrior_lineup.png"
SUNO_ID = re.compile(rb"id=([0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12})")
BREAKWATER_ASSETS = {
    "game/levels/modules/breakwater/airlock.tres",
    "game/levels/modules/breakwater/pump_hall.tres",
    "game/levels/modules/breakwater/control_room.tres",
    "game/levels/modules/breakwater/mission/dock.tres",
    "game/levels/modules/breakwater/mission/hub.tres",
    "game/levels/modules/breakwater/mission/pump.tres",
    "game/levels/modules/breakwater/mission/intake.tres",
    "game/levels/modules/breakwater/mission/cavern.tres",
    "game/levels/modules/breakwater/mission/turbine.tres",
    "game/levels/modules/breakwater/mission/relay.tres",
    "game/levels/modules/breakwater/mission/return_landing.tres",
    "game/levels/modules/breakwater/mission/return.tres",
    "game/levels/modules/breakwater/mission/return_gallery.tres",
    "game/levels/modules/breakwater/mission/return_elbow.tres",
    "game/levels/modules/breakwater/materials/coast_water.tres",
    "game/levels/modules/breakwater/materials/salt_concrete.tres",
    "game/levels/modules/breakwater/materials/coast_rock.tres",
    "game/levels/modules/breakwater/materials/screen.tres",
    "game/levels/modules/breakwater/materials/glass.tres",
    "game/levels/modules/breakwater/materials/amber_light.tres",
    "game/levels/modules/breakwater/materials/cool_light.tres",
    "game/levels/modules/breakwater/materials/brass.tres",
    "game/levels/modules/breakwater/materials/teal_enamel.tres",
    "game/levels/modules/breakwater/materials/dark_metal.tres",
    "game/levels/modules/breakwater/materials/floor.tres",
    "game/levels/modules/breakwater/meshes/coast_coast_rock.obj",
    "game/levels/modules/breakwater/meshes/coast_coast_water.obj",
    "game/levels/modules/breakwater/meshes/control_room_cool_light.obj",
    "game/levels/modules/breakwater/meshes/control_room_screen.obj",
    "game/levels/modules/breakwater/meshes/control_room_teal_enamel.obj",
    "game/levels/modules/breakwater/meshes/control_room_brass.obj",
    "game/levels/modules/breakwater/meshes/control_room_amber_light.obj",
    "game/levels/modules/breakwater/meshes/control_room_dark_metal.obj",
    "game/levels/modules/breakwater/meshes/control_room_glass.obj",
    "game/levels/modules/breakwater/meshes/control_room_floor.obj",
    "game/levels/modules/breakwater/meshes/control_room_salt_concrete.obj",
    "game/levels/modules/breakwater/meshes/pump_hall_cool_light.obj",
    "game/levels/modules/breakwater/meshes/pump_hall_teal_enamel.obj",
    "game/levels/modules/breakwater/meshes/pump_hall_brass.obj",
    "game/levels/modules/breakwater/meshes/pump_hall_amber_light.obj",
    "game/levels/modules/breakwater/meshes/pump_hall_dark_metal.obj",
    "game/levels/modules/breakwater/meshes/pump_hall_floor.obj",
    "game/levels/modules/breakwater/meshes/pump_hall_salt_concrete.obj",
    "game/levels/modules/breakwater/meshes/airlock_cool_light.obj",
    "game/levels/modules/breakwater/meshes/airlock_teal_enamel.obj",
    "game/levels/modules/breakwater/meshes/airlock_brass.obj",
    "game/levels/modules/breakwater/meshes/airlock_amber_light.obj",
    "game/levels/modules/breakwater/meshes/airlock_dark_metal.obj",
    "game/levels/modules/breakwater/meshes/airlock_floor.obj",
    "game/levels/modules/breakwater/meshes/airlock_salt_concrete.obj",
    "game/levels/modules/breakwater/meshes/coastal_cavern_amber_light.obj",
    "game/levels/modules/breakwater/meshes/coastal_cavern_brass.obj",
    "game/levels/modules/breakwater/meshes/coastal_cavern_coast_rock.obj",
    "game/levels/modules/breakwater/meshes/coastal_cavern_coast_water.obj",
    "game/levels/modules/breakwater/meshes/coastal_cavern_dark_metal.obj",
    "game/levels/modules/breakwater/meshes/coastal_cavern_floor.obj",
    "game/levels/modules/breakwater/meshes/coastal_cavern_teal_enamel.obj",
    "game/levels/modules/breakwater/meshes/coastal_dock_amber_light.obj",
    "game/levels/modules/breakwater/meshes/coastal_dock_brass.obj",
    "game/levels/modules/breakwater/meshes/coastal_dock_dark_metal.obj",
    "game/levels/modules/breakwater/meshes/coastal_dock_glass.obj",
    "game/levels/modules/breakwater/meshes/coastal_dock_salt_concrete.obj",
    "game/levels/modules/breakwater/meshes/coastal_hub_amber_light.obj",
    "game/levels/modules/breakwater/meshes/coastal_hub_brass.obj",
    "game/levels/modules/breakwater/meshes/coastal_hub_cool_light.obj",
    "game/levels/modules/breakwater/meshes/coastal_hub_dark_metal.obj",
    "game/levels/modules/breakwater/meshes/coastal_hub_teal_enamel.obj",
    "game/levels/modules/breakwater/meshes/coastal_return_brass.obj",
    "game/levels/modules/breakwater/meshes/coastal_return_cool_light.obj",
    "game/levels/modules/breakwater/meshes/coastal_return_dark_metal.obj",
    "game/levels/modules/breakwater/meshes/coastal_return_teal_enamel.obj",
    "game/levels/modules/breakwater/meshes/coastal_return_elbow_brass.obj",
    "game/levels/modules/breakwater/meshes/coastal_return_elbow_cool_light.obj",
    "game/levels/modules/breakwater/meshes/coastal_return_elbow_dark_metal.obj",
    "game/levels/modules/breakwater/meshes/coastal_return_elbow_glass.obj",
    "game/levels/modules/breakwater/meshes/coastal_return_gallery_brass.obj",
    "game/levels/modules/breakwater/meshes/coastal_return_gallery_cool_light.obj",
    "game/levels/modules/breakwater/meshes/coastal_return_gallery_dark_metal.obj",
    "game/levels/modules/breakwater/meshes/coastal_return_gallery_glass.obj",
    "game/levels/modules/breakwater/meshes/coastal_return_landing_brass.obj",
    "game/levels/modules/breakwater/meshes/coastal_return_landing_cool_light.obj",
    "game/levels/modules/breakwater/meshes/coastal_return_landing_dark_metal.obj",
    "game/levels/modules/breakwater/meshes/coastal_return_landing_teal_enamel.obj",
    "game/levels/modules/breakwater/meshes/combat_drive_rotor.obj",
    "game/levels/modules/breakwater/meshes/combat_intake_brass.obj",
    "game/levels/modules/breakwater/meshes/combat_intake_dark_metal.obj",
    "game/levels/modules/breakwater/meshes/combat_intake_teal_enamel.obj",
    "game/levels/modules/breakwater/meshes/combat_relay_brass.obj",
    "game/levels/modules/breakwater/meshes/combat_relay_dark_metal.obj",
    "game/levels/modules/breakwater/meshes/combat_relay_teal_enamel.obj",
    "game/levels/modules/breakwater/meshes/combat_turbine_brass.obj",
    "game/levels/modules/breakwater/meshes/combat_turbine_dark_metal.obj",
    "game/levels/modules/breakwater/meshes/combat_turbine_teal_enamel.obj",
    "game/levels/modules/breakwater/meshes/combat_turbine_collision.tres",
    "game/art/audio/breakwater/black_start_exterior.tres",
    "game/art/audio/breakwater/black_start_shelter.tres",
    "game/art/audio/breakwater/black_start_pump.tres",
    "game/art/audio/breakwater/black_start_coolant.tres",
    "game/art/audio/breakwater/black_start_station.tres",
    "game/art/audio/breakwater/black_start_cavern.tres",
}

FIELDNAMES = (
    "path",
    "sha256",
    "bytes",
    "kind",
    "status",
    "author",
    "source",
    "license",
    "local_notice",
    "notes",
)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def asset_paths() -> list[Path]:
    paths: set[Path] = set()
    for root_name in SCAN_ROOTS:
        root = ROOT / root_name
        if not root.exists():
            continue
        for path in root.rglob("*"):
            if path.is_file() and path.suffix.lower() in ASSET_SUFFIXES:
                paths.add(path)
    for relative in EXTRA_PATHS:
        path = ROOT / relative
        if path.is_file():
            paths.add(path)
    return sorted(paths, key=lambda path: path.relative_to(ROOT).as_posix())


def classify(path: Path, digest: str) -> dict[str, str]:
    relative = path.relative_to(ROOT).as_posix()
    base = {
        "status": "review_required",
        "author": "unverified",
        "source": "unverified",
        "license": "unverified",
        "local_notice": "",
        "notes": "No repository-local provenance record currently clears this distributed asset.",
    }

    if relative.startswith(WRAD_ARMS_PREFIX):
        return {
            "status": "cleared",
            "author": "wriks",
            "source": "https://wriks.itch.io/wrad-arms",
            "license": "CC0-1.0",
            "local_notice": "docs/licenses/WRAD_ARMS_CC0-1.0.txt",
            "notes": (
                "WRAD ARMS first-person model or supplied skin texture; the "
                "canonical model is the imported arms.glb, with the pale texture "
                "also extracted by Godot from the model's embedded image."
            ),
        }
    if relative.startswith(BRACKEYS_VFX_PREFIX):
        return {
            "status": "cleared",
            "author": "Brackeys and credited creators",
            "source": "https://brackeysgames.itch.io/brackeys-vfx-bundle",
            "license": "CC0-1.0",
            "local_notice": "docs/licenses/BRACKEYS_VFX_CC0-1.0.txt",
            "notes": (
                "Brackeys VFX Bundle particle texture, flipbook, or pre-drawn "
                "spritesheet; the official pack page and bundled credits state "
                "that the repackaged/remixed assets are CC0."
            ),
        }
    if relative.startswith(PSX_OFFICE_PREFIX):
        return {
            "status": "cleared",
            "author": "valsekamerplant",
            "source": "https://valsekamerplant.itch.io/psx-style-opulent-office",
            "license": "CC0-1.0",
            "local_notice": "docs/licenses/PSX_OFFICE_CC0-1.0.txt",
            "notes": (
                "PSX style office prop; canonical GLB model imported from the "
                "OFFICE.zip archive. The official source page states CC0 and "
                "that textures are CC0 or creator-owned photographs."
            ),
        }
    if any(relative.startswith(prefix) for prefix in PSX_FENCE_PREFIXES):
        return {
            "status": "cleared",
            "author": "valsekamerplant",
            "source": "https://valsekamerplant.itch.io/psx-style-walls-fences",
            "license": "CC0-1.0",
            "local_notice": "docs/licenses/PSX_WALLS_FENCES_CC0-1.0.txt",
            "notes": (
                "PSX style modular walls and fences; canonical GLB model or "
                "source texture imported from the all_fences.zip archive. "
                "The official source page states CC0/Public Domain."
            ),
        }
    if any(relative.startswith(prefix) for prefix in RETROURBAN_PREFIXES):
        return {
            "status": "cleared",
            "author": "Binbun3D",
            "source": "https://binbun3d.itch.io/retrourban-free",
            "license": "CC-BY-4.0",
            "local_notice": "docs/licenses/RETOURBAN_CC-BY-4.0.txt",
            "notes": (
                "RetroUrban Free 128x128 urban texture map or derived Godot "
                "material resource; imported without changing source PNG pixels. "
                "Attribution to Binbun3D is required."
            ),
        }
    if relative in BREAKWATER_ASSETS:
        return {
            "status": "cleared",
            "author": "LichForge / AI-assisted original assets",
            "source": "Original Breakwater Station geometry, materials, module metadata and synthesized audio, 2026-09-13",
            "license": "MIT",
            "local_notice": "LICENSE",
            "notes": "Original baked OBJ and native Godot resources; audio deterministically synthesized by game/art/audio/breakwater/author_breakwater_audio.py with no recordings or third-party samples.",
        }
    if any(relative.startswith(prefix) for prefix in BINBUN_SKIES_PREFIXES):
        return {
            "status": "cleared",
            "author": "Binbun",
            "source": BINBUN_SKIES_SOURCE,
            "license": "CC0-1.0",
            "local_notice": BINBUN_SKIES_NOTICE,
            "notes": (
                "Binbun Godot Skies shader, procedural cloud/noise resource, or "
                "derived MODUS Sky preset imported from the uploaded CC0 source "
                "archive. The empty unused triplanar include is intentionally "
                "not distributed."
            ),
        }
    if relative.startswith(KKRYY_STREET_PREFIX):
        return {
            "status": "cleared",
            "author": "Kkryy",
            "source": KKRYY_STREET_SOURCE,
            "license": "CC0-1.0",
            "local_notice": KKRYY_STREET_NOTICE,
            "notes": (
                "Street Furniture FBX or PNG source file imported from the "
                "uploaded Street Furniture.zip archive. The official source "
                "page states CC0; Blender authoring files are not distributed."
            ),
        }
    if relative.startswith(ELBOLILLODURO_MINE_PREFIX):
        return {
            "status": "cleared",
            "author": "Elbolilloduro",
            "source": ELBOLILLODURO_MINE_SOURCE,
            "license": "CC0-1.0",
            "local_notice": ELBOLILLODURO_MINE_NOTICE,
            "notes": (
                "Texture-free derived COLLADA Mine prop or modular geometry "
                "from the uploaded Mine.rar archive. The official source page "
                "states the models are CC0; texture files identified as obtained "
                "from texturer.com and textures.com are not distributed."
            ),
        }
    if relative.startswith(ELBOLILLODURO_PSX_PREFIX):
        return {
            "status": "cleared",
            "author": "Elbolilloduro",
            "source": ELBOLILLODURO_PSX_SOURCE,
            "license": "CC0-1.0",
            "local_notice": ELBOLILLODURO_PSX_NOTICE,
            "notes": (
                "Texture-free derived COLLADA model geometry from the uploaded "
                "Models pack psx - new.rar archive. The source page states the "
                "models are CC0; source textures with separate terms are not "
                "distributed."
            ),
        }
    if relative.startswith(GODGOLDFEAR_INDUSTRIAL_PREFIX):
        return {
            "status": "cleared",
            "author": "godgoldfear",
            "source": GODGOLDFEAR_INDUSTRIAL_SOURCE,
            "license": "CC-BY-4.0",
            "local_notice": GODGOLDFEAR_INDUSTRIAL_NOTICE,
            "notes": (
                "PSX Industrial Environment FBX, diffuse texture, or normal "
                "texture imported from the uploaded Industrial_exterior_v1.zip "
                "archive. Source bytes are retained; attribution to godgoldfear "
                "is required."
            ),
        }
    if relative.startswith(CHILLY_DURANGO_RETRO_PREFIX):
        return {
            "status": "cleared",
            "author": "chilly_durango",
            "source": CHILLY_DURANGO_RETRO_SOURCE,
            "license": "CC0-1.0",
            "local_notice": CHILLY_DURANGO_RETRO_NOTICE,
            "notes": (
                "Low-poly retro plumbing, wiring, electrical, and machinery GLB "
                "conversion or retained PNG texture from the uploaded 3D Retro "
                "Plumbing & Wiring.zip archive. The official source page states "
                "the models and textures are CC0; source Blender files are not "
                "distributed."
            ),
        }
    if relative.startswith(CLASSIC64_BREAKWATER_PREFIX):
        return {
            "status": "cleared",
            "author": "Craig Snedeker / Classic64 Asset Library",
            "source": CLASSIC64_BREAKWATER_SOURCE,
            "license": "CC0-1.0",
            "local_notice": CLASSIC64_BREAKWATER_NOTICE,
            "notes": (
                "Selected low-poly industrial, electrical, machinery, rail, and "
                "confined-space sign GLB conversions from the uploaded Classic 64 "
                "Asset Pack 0.6 archive. The creator-supplied Readme points to "
                "CC0/public-domain dedication; source Blender files and "
                "unselected pack contents are not distributed. The Readme's "
                "direct-resale request is retained in the local notice."
            ),
        }
    if relative.startswith(LOAFBRR_PIPES_PREFIX):
        return {
            "status": "cleared",
            "author": "loafbrr",
            "source": LOAFBRR_PIPES_SOURCE,
            "license": "CC0-1.0",
            "local_notice": LOAFBRR_PIPES_NOTICE,
            "notes": (
                "Godot scene, material, texture, or glTF source imported from "
                "the uploaded PIpes_Pack_Godot_40.zip archive. The official "
                "source page states the pack is CC0."
            ),
        }
    if relative.startswith(PRILDARILL_PREFIX):
        return {
            "status": "cleared",
            "author": "Prildarill",
            "source": PRILDARILL_SOURCE,
            "license": "Free Use (creator permission; attribution retained)",
            "local_notice": PRILDARILL_NOTICE,
            "notes": (
                "Shelf, locker, tall-locker, or single/double door FBX model "
                "or supplied PNG texture imported from the user-uploaded "
                "Prildarill assets. The official source page permits use and "
                "modification; the creator's public comment says the same "
                "terms apply to all of the creator's models."
            ),
        }
    if relative.startswith(MCSTEEG_TRASH_PREFIX):
        return {
            "status": "cleared",
            "author": "MCSTEEG",
            "source": MCSTEEG_SOURCE,
            "license": "Free Use (commercial game use; no standalone redistribution)",
            "local_notice": MCSTEEG_NOTICE,
            "notes": (
                "Trash and Debris GLB runtime model or supplied PNG texture "
                "atlas/decals from the uploaded archive. MCSTEEG's official "
                "source page permits personal and commercial game use and "
                "prohibits redistributing the asset as one's own."
            ),
        }
    if relative.startswith(MCSTEEG_SURVIVAL_PREFIX):
        return {
            "status": "cleared",
            "author": "MCSTEEG",
            "source": MCSTEEG_SOURCE,
            "license": "Free Use (commercial game use; no standalone redistribution)",
            "local_notice": MCSTEEG_NOTICE,
            "notes": (
                "Survival COLLADA runtime model or supplied PNG/JPG texture "
                "from the uploaded Survival.rar archive. The MODUS author "
                "identifies the upload as another MCSTEEG pack and applies the "
                "same creator permission basis recorded in the local notice."
            ),
        }
    if relative.startswith(LOOMING_LANDMARKS_PREFIX):
        return {
            "status": "cleared",
            "author": "3Dexter3D",
            "source": LOOMING_LANDMARKS_SOURCE,
            "license": "CC BY 4.0",
            "local_notice": LOOMING_LANDMARKS_NOTICE,
            "notes": (
                "Wind Turbine GLB, supplied PNG texture, or Godot-extracted "
                "embedded texture map imported from the uploaded Looming "
                "Landmarks demo archive. The official source page releases "
                "the pack under CC BY 4.0 and requires creator attribution."
            ),
        }
    if relative.startswith(AQUILARIUS_RETRO_PREFIX):
        return {
            "status": "cleared",
            "author": "Aquilarius",
            "source": AQUILARIUS_RETRO_SOURCE,
            "license": "CC0-1.0",
            "local_notice": AQUILARIUS_RETRO_NOTICE,
            "notes": (
                "Aquilarius Retro Textures 128x128 PNG map imported from the "
                "uploaded archive. The official source page states CC0; the "
                "supplied archive contains 59 t*.png maps and no t17.png."
            ),
        }
    if relative.startswith(LVL11_QUAKE_PREFIX):
        return {
            "status": "cleared",
            "author": "Level Eleven Games",
            "source": LVL11_QUAKE_SOURCE,
            "license": "CC0-1.0",
            "local_notice": LVL11_QUAKE_NOTICE,
            "notes": (
                "Level Eleven Games Quake-like Sci-Fi 64x64 PNG texture "
                "imported from the uploaded archive. The creator clarified "
                "the page's CC0/public-domain dedication; the page metadata "
                "contains a conflicting CC BY 4.0 label retained in the notice."
            ),
        }
    if relative.startswith(DELVEN_TEXTURE_PREFIX):
        return {
            "status": "cleared",
            "author": "Bradley D. (Strideh)",
            "source": DELVEN_TEXTURE_SOURCE,
            "license": "Free Use (commercial game use; attribution and restrictions)",
            "local_notice": DELVEN_TEXTURE_NOTICE,
            "notes": (
                "Delven True Colour PNG texture imported from the uploaded "
                "archive. The creator permits free/commercial project use and "
                "modification, requires attribution for open-source redistribution, "
                "prohibits standalone resale, and prohibits generative-AI training."
            ),
        }
    if relative.startswith(TORMENT_TEXTURE_PREFIX):
        return {
            "status": "cleared",
            "author": "Bradley D. (Strideh)",
            "source": TORMENT_TEXTURE_SOURCE,
            "license": "Free Use (commercial game use; attribution and restrictions)",
            "local_notice": TORMENT_TEXTURE_NOTICE,
            "notes": (
                "Torment True Colour PNG texture imported from the uploaded "
                "archive. The creator permits free/commercial project use and "
                "modification, requires attribution for open-source redistribution, "
                "prohibits standalone resale, and prohibits generative-AI training."
            ),
        }
    if relative.startswith(STENCIL_DECAL_MASK_PREFIX):
        return {
            "status": "cleared",
            "author": "Bradley D. (Strideh)",
            "source": STENCIL_DECAL_MASK_SOURCE,
            "license": "Free Use (commercial game use; attribution and restrictions)",
            "local_notice": STENCIL_DECAL_MASK_NOTICE,
            "notes": (
                "Stencil Painted Decal Pack 1024x1024 grayscale PNG mask sheet "
                "imported from the uploaded archive. The creator permits "
                "free/commercial project use and modification, requires "
                "attribution for open-source redistribution, prohibits standalone "
                "resale, and prohibits generative-AI training."
            ),
        }
    if relative.startswith(VINRAX_SKELETON_PREFIX):
        return {
            "status": "cleared",
            "author": "Vinrax",
            "source": VINRAX_SKELETON_SOURCE,
            "license": "Free Use (creator permission; attribution required)",
            "local_notice": VINRAX_SKELETON_NOTICE,
            "notes": (
                "PSX Skeleton Character GLB, supplied 256x256 PNG texture, or "
                "Godot-extracted embedded texture map from the uploaded archive. "
                "The official source page permits project use with creator credit; "
                "the alternate FBX source is intentionally not distributed."
            ),
        }
    if relative == SEWERS_MODEL_PATH:
        return {
            "status": "cleared",
            "author": "Elbolilloduro",
            "source": SEWERS_SOURCE,
            "license": "CC0-1.0",
            "local_notice": SEWERS_NOTICE,
            "notes": (
                "Texture-free COLLADA geometry derived from the uploaded Sewer.rar "
                "model source. The official page identifies the models as CC0; "
                "the source archive's externally obtained textures are intentionally "
                "not distributed because their separate license terms are not retained."
            ),
        }
    if any(relative.startswith(prefix) for prefix in BINBUN_WATER_PREFIXES):
        return {
            "status": "cleared",
            "author": "Binbun",
            "source": BINBUN_WATER_SOURCE,
            "license": "CC0-1.0",
            "local_notice": BINBUN_WATER_NOTICE,
            "notes": (
                "Binbun Godot Water shader source, derived procedural-noise "
                "material, duck demo GLB, or duck texture imported from the "
                "uploaded CC0 source/demo archives. The original Blender files "
                "and source-side import metadata are intentionally excluded."
            ),
        }
    if relative.startswith(LUKA_ALEKSIC_SOUND_PREFIX):
        return {
            "status": "cleared",
            "author": "Luka Aleksic",
            "source": LUKA_ALEKSIC_SOUND_SOURCE,
            "license": "CC0-1.0",
            "local_notice": LUKA_ALEKSIC_SOUND_NOTICE,
            "notes": (
                "Luka Aleksic public-domain sound effect WAV imported from "
                "the uploaded sounds.zip archive. The source page states CC0; "
                "the creator's optional credit request is retained in the local notice."
            ),
        }
    if relative.startswith(COOLER11_WAVES_PREFIX):
        return {
            "status": "cleared",
            "author": "cooler11",
            "source": COOLER11_WAVES_SOURCE,
            "license": "Free Use (game use; no standalone redistribution)",
            "local_notice": COOLER11_WAVES_NOTICE,
            "notes": (
                "Very Simple Waves Pack WAV imported from the supplied archive. "
                "The included README permits free and commercial game use and "
                "modification, requests optional credit, and prohibits standalone "
                "or asset-pack redistribution."
            ),
        }
    if relative in LIQUID_PATHS:
        return {
            "status": "cleared",
            "author": "LichForge / user-generated AI-assisted artwork",
            "source": "Generated by the LichForge author for MODUS",
            "license": "MIT",
            "local_notice": "LICENSE",
            "notes": "User-confirmed original liquid shader/material work; no external asset source is claimed.",
        }
    if relative in SKYBOX_PATHS:
        return {
            "status": "cleared",
            "author": "LichForge / user-generated AI-assisted artwork",
            "source": "Generated by the LichForge author for MODUS",
            "license": "MIT",
            "local_notice": "LICENSE",
            "notes": "User-confirmed original AI-assisted skybox shader/material work; no external asset source is claimed.",
        }
    if relative in GENERATED_MAP_OVERVIEW_PATHS:
        return {
            "status": "cleared",
            "author": "LichForge",
            "source": "Generated by the MODUS map overview capture workflow",
            "license": "MIT",
            "local_notice": "LICENSE",
            "notes": "Generated level overview snapshot used by the minimap; not an external artwork dependency.",
        }
    if (
        relative in MIT_PROJECT_PATHS
        or relative in MIT_SHADER_PATHS
        or relative in MIT_EFFECT_TEXTURE_PATHS
        or relative in MIT_WEAPON_ICON_PATHS
        or relative in RETRO_TEXTURE_PATHS
    ):
        return {
            "status": "cleared",
            "author": "LichForge",
            "source": "Original project asset authored for MODUS",
            "license": "MIT",
            "local_notice": "LICENSE",
            "notes": "User-confirmed project-owned asset; no external asset source is claimed.",
        }
    if relative in ORIGINAL_ICONS:
        if digest != ORIGINAL_ICONS[relative]:
            base["notes"] = "Icon changed after the original-artwork provenance record."
            return base
        return {
            "status": "cleared",
            "author": "LichForge / OpenAI-assisted original artwork",
            "source": "Original editable SVG geometry authored for MODUS, 2026-09-09",
            "license": "MIT",
            "local_notice": "LICENSE",
            "notes": "Authorship and SPDX license embedded in the hash-pinned SVG source.",
        }

    if relative in KENNEY:
        if digest != KENNEY[relative]:
            base["notes"] = "File hash changed after the official-pack pixel-equivalence review."
            return base
        pack = "Particle Pack" if "particle_pack" in relative else "Prototype Textures"
        slug = "particle-pack" if pack == "Particle Pack" else "prototype-textures"
        return {
            "status": "cleared",
            "author": "Kenney",
            "source": f"https://kenney.nl/assets/{slug}",
            "license": "CC0-1.0",
            "local_notice": "docs/licenses/KENNEY_CC0-1.0.txt",
            "notes": (
                f"Pixel-identical to the corresponding PNG in the official Kenney {pack} "
                "ZIP; PNG encoding differs."
            ),
        }

    if relative in BLOOD_POOL_PATHS:
        return {
            "status": "cleared",
            "author": "Adrián (dip000), modified by LichForge",
            "source": (
                "https://github.com/dip000/my-godotshaders/tree/"
                "7a3e9bc685255d37f489e25b509fb56e185aa9fb/BloodyPool"
            ),
            "license": "MIT",
            "local_notice": "docs/licenses/DIP000_BLOODY_POOL_MIT.txt",
            "notes": (
                "Derived implementation reviewed against the pinned upstream BloodyPool source."
            ),
        }

    if relative.startswith(QUATERNIUS_ANIMATION_PREFIX) or relative in QUATERNIUS_MODEL_PATHS:
        return {
            "status": "cleared",
            "author": "Quaternius",
            "source": QUATERNIUS_SOURCE,
            "license": "CC0-1.0",
            "local_notice": QUATERNIUS_NOTICE,
            "notes": (
                "Universal Animation Library asset or Godot-derived resource; "
                "the official pack page states CC0 and commercial use."
            ),
        }

    if relative == HERO_PATH:
        return {
            "status": "cleared",
            "author": "LichForge / user-directed generated artwork",
            "source": "User-directed local image-generation workflow, 2026-08-01",
            "license": "Project-owned",
            "local_notice": "LICENSE",
            "notes": (
                "Generation provenance is retained in docs/ATTRIBUTION.md and release evidence."
            ),
        }

    if relative.startswith("game/art/audio/music/") and path.suffix.lower() == ".mp3":
        match = SUNO_ID.search(path.read_bytes())
        source = "Embedded metadata: made with Suno"
        if match:
            source += "; asset id " + match.group(1).decode("ascii")
        return {
            "status": "identified_review_required",
            "author": "rafael_dina (embedded metadata)",
            "source": source,
            "license": "commercial-use grant not retained locally",
            "local_notice": "",
            "notes": (
                "Retain account/plan-generation rights evidence or replace before distribution."
            ),
        }

    return base


def build_csv() -> tuple[str, dict[str, int]]:
    output = io.StringIO(newline="")
    writer = csv.DictWriter(output, fieldnames=FIELDNAMES, lineterminator="\n")
    writer.writeheader()
    counts: dict[str, int] = {}

    for path in asset_paths():
        relative = path.relative_to(ROOT).as_posix()
        digest = sha256(path)
        classification = classify(path, digest)
        status = classification["status"]
        counts[status] = counts.get(status, 0) + 1
        writer.writerow(
            {
                "path": relative,
                "sha256": digest,
                "bytes": path.stat().st_size,
                "kind": path.suffix.lower().lstrip(".") or "file",
                **classification,
            }
        )

    return output.getvalue(), counts


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true", help="fail if the ledger is stale")
    parser.add_argument("--strict", action="store_true", help="fail if any asset is not cleared")
    args = parser.parse_args()

    content, counts = build_csv()
    if args.check:
        if not OUTPUT.exists() or OUTPUT.read_text(encoding="utf-8") != content:
            print("Provenance ledger is stale; run tools/generate_provenance_ledger.py")
            return 1
    else:
        OUTPUT.write_text(content, encoding="utf-8")

    total = sum(counts.values())
    summary = ", ".join(f"{key}={counts[key]}" for key in sorted(counts))
    print(f"Provenance ledger: {total} assets ({summary})")
    if args.strict and counts.get("review_required", 0) + counts.get(
        "identified_review_required", 0
    ):
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
