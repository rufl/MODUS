class_name LevelAssetDressing
extends Node3D

## Runtime dressing contract for authored levels.
##
## Imported model and texture families are deliberately instantiated here
## instead of remaining editor-only registry entries. The gallery uses one or
## more visual representatives from each imported family; texture-heavy packs
## are shown as display cards so dressing remains readable and performant.
## Models are visual-only: dressing must never change gameplay collision.

const CONTRACT_VERSION := 1
const DISPLAY_PLATFORM_SIZE := Vector3(48.0, 0.4, 32.0)
const DISPLAY_PLATFORM_POSITION := Vector3(0.0, -0.28, 2.0)
const DISPLAY_PLATFORM_MATERIAL_PATH := "res://game/art/materials/retro_urban/cleanpavement_cleanpavement_04.tres"

const IMPORTED_ASSET_FAMILIES: Array[String] = [
	"fences",
	"office",
	"retro_urban",
	"brackeys_vfx",
	"3dexter_looming_landmarks",
	"mcsteeg_survival",
	"mcsteeg_trash_and_debris",
	"chilly_durango_retro_machinery",
	"loafbrr_pipes",
	"elbolilloduro_mine",
	"elbolilloduro_psx_models",
	"godgoldfear_industrial",
	"kkryy_street_furniture",
	"prildarill_low_poly_assets",
	"binbun_water",
	"vinrax_psx_skeleton",
	"aquilarius_retro",
	"lvl11_quake_sci_fi",
	"strideh_delven",
	"strideh_torment",
	"strideh_stencil_decals",
]

const MODEL_ASSETS: Array[Dictionary] = [
	{
		"id": "metal_fence_security",
		"path": "res://game/art/models/fences/metal_fence/metalfence_both_sides_topbar.glb",
		"position": Vector3(-8.0, 0.0, 7.0),
		"rotation_degrees": Vector3(0.0, 90.0, 0.0),
		"scale": Vector3(1.6, 1.6, 1.6),
	},
	{
		"id": "brick_wall_gate",
		"path": "res://game/art/models/fences/brick_fence/brick_wall_gate.glb",
		"position": Vector3(-3.5, 0.0, 7.0),
		"rotation_degrees": Vector3.ZERO,
		"scale": Vector3(2.1, 2.1, 2.1),
	},
	{
		"id": "drystone_wall",
		"path": "res://game/art/models/fences/drystone_wall/drystone_wall.glb",
		"position": Vector3(1.5, 0.0, 7.0),
		"rotation_degrees": Vector3.ZERO,
		"scale": Vector3(2.0, 2.0, 2.0),
	},
	{
		"id": "wooden_fence",
		"path": "res://game/art/models/fences/low_wooden_fence/wooden_fence_closed.glb",
		"position": Vector3(5.5, 0.0, 7.0),
		"rotation_degrees": Vector3(0.0, -90.0, 0.0),
		"scale": Vector3(1.8, 1.8, 1.8),
	},
	{
		"id": "plaster_wall_fenced",
		"path": "res://game/art/models/fences/plaster_wall/plaster_wall_fenced.glb",
		"position": Vector3(8.5, 0.0, 7.0),
		"rotation_degrees": Vector3(0.0, 90.0, 0.0),
		"scale": Vector3(1.8, 1.8, 1.8),
	},
	{
		"id": "office_desk",
		"path": "res://game/art/models/office/desks/desk1.glb",
		"position": Vector3(-6.0, 0.0, -2.5),
		"rotation_degrees": Vector3(0.0, 180.0, 0.0),
		"scale": Vector3(1.55, 1.55, 1.55),
	},
	{
		"id": "office_chair",
		"path": "res://game/art/models/office/chairs/office_chair_blue.glb",
		"position": Vector3(-6.0, 0.0, -0.8),
		"rotation_degrees": Vector3(0.0, 180.0, 0.0),
		"scale": Vector3(1.5, 1.5, 1.5),
	},
	{
		"id": "office_monitor",
		"path": "res://game/art/models/office/computers/computer_monitor.glb",
		"position": Vector3(-6.0, 1.0, -2.4),
		"rotation_degrees": Vector3(0.0, 180.0, 0.0),
		"scale": Vector3(1.4, 1.4, 1.4),
	},
	{
		"id": "office_keyboard",
		"path": "res://game/art/models/office/computers/computer_keyboard.glb",
		"position": Vector3(-6.0, 0.92, -1.95),
		"rotation_degrees": Vector3(0.0, 180.0, 0.0),
		"scale": Vector3(1.35, 1.35, 1.35),
	},
	{
		"id": "office_file_cabinet",
		"path": "res://game/art/models/office/file_cabinets/file_cabinet_small.glb",
		"position": Vector3(-2.5, 0.0, -3.0),
		"rotation_degrees": Vector3.ZERO,
		"scale": Vector3(1.35, 1.35, 1.35),
	},
	{
		"id": "office_bookcase",
		"path": "res://game/art/models/office/book_things/book_case_small.glb",
		"position": Vector3(0.0, 0.0, -3.0),
		"rotation_degrees": Vector3.ZERO,
		"scale": Vector3(1.25, 1.25, 1.25),
	},
	{
		"id": "office_couch",
		"path": "res://game/art/models/office/couches/couch_blue.glb",
		"position": Vector3(4.0, 0.0, -2.5),
		"rotation_degrees": Vector3(0.0, 180.0, 0.0),
		"scale": Vector3(1.35, 1.35, 1.35),
	},
	{
		"id": "office_water_cooler",
		"path": "res://game/art/models/office/extras/water_cooler.glb",
		"position": Vector3(6.5, 0.0, -0.5),
		"rotation_degrees": Vector3.ZERO,
		"scale": Vector3(1.5, 1.5, 1.5),
	},
	{
		"id": "office_wall_clock",
		"path": "res://game/art/models/office/extras/wall_clock.glb",
		"position": Vector3(6.5, 2.8, 1.0),
		"rotation_degrees": Vector3(0.0, 90.0, 0.0),
		"scale": Vector3(1.8, 1.8, 1.8),
	},
	{
		"id": "office_whiteboard",
		"path": "res://game/art/models/office/extras/whiteboard.glb",
		"position": Vector3(2.0, 0.0, 6.1),
		"rotation_degrees": Vector3(0.0, 180.0, 0.0),
		"scale": Vector3(1.35, 1.35, 1.35),
	},
	{
		"id": "office_coffee_machine",
		"path": "res://game/art/models/office/extras/coffee_machine.glb",
		"position": Vector3(3.7, 1.1, -2.4),
		"rotation_degrees": Vector3.ZERO,
		"scale": Vector3(1.2, 1.2, 1.2),
	},
	{
		"id": "office_desk_lamp",
		"path": "res://game/art/models/office/extras/circular_desklamp.glb",
		"position": Vector3(-4.8, 1.0, -2.5),
		"rotation_degrees": Vector3.ZERO,
		"scale": Vector3(1.1, 1.1, 1.1),
	},
	{
		"id": "office_mug",
		"path": "res://game/art/models/office/extras/mug.glb",
		"position": Vector3(-5.0, 1.0, -2.1),
		"rotation_degrees": Vector3.ZERO,
		"scale": Vector3(1.2, 1.2, 1.2),
	},
	{
		"id": "office_paper_stack",
		"path": "res://game/art/models/office/stationary/paper_stack.glb",
		"position": Vector3(-7.0, 0.97, -2.2),
		"rotation_degrees": Vector3.ZERO,
		"scale": Vector3(1.2, 1.2, 1.2),
	},
	{
		"id": "office_pen",
		"path": "res://game/art/models/office/stationary/pen.glb",
		"position": Vector3(-6.6, 1.0, -2.0),
		"rotation_degrees": Vector3(0.0, 20.0, 0.0),
		"scale": Vector3(1.2, 1.2, 1.2),
	},
	{
		"id": "landmark_wind_turbine",
		"path": "res://game/art/models/third_party/3dexter_looming_landmarks/WindTurbine.glb",
		"position": Vector3(-18.0, 0.0, 12.0),
		"rotation_degrees": Vector3(0.0, 180.0, 0.0),
		"scale": Vector3(0.08, 0.08, 0.08),
	},
	{
		"id": "survival_camp",
		"path": "res://game/art/models/third_party/mcsteeg_survival/Survival.dae",
		"position": Vector3(-12.0, 0.0, 12.0),
		"rotation_degrees": Vector3.ZERO,
		"scale": Vector3(0.05, 0.05, 0.05),
	},
	{
		"id": "trash_debris_pile",
		"path": "res://game/art/models/third_party/mcsteeg_trash_and_debris/TrashAndDebris.glb",
		"position": Vector3(-6.0, 0.0, 12.0),
		"rotation_degrees": Vector3(0.0, 35.0, 0.0),
		"scale": Vector3(0.65, 0.65, 0.65),
	},
	{
		"id": "retro_generator",
		"path": "res://game/art/models/third_party/chilly_durango_retro_machinery/models/retro_generator.glb",
		"position": Vector3(-1.5, 0.0, 12.0),
		"rotation_degrees": Vector3(0.0, 20.0, 0.0),
		"scale": Vector3(1.5, 1.5, 1.5),
	},
	{
		"id": "retro_pump",
		"path": "res://game/art/models/third_party/chilly_durango_retro_machinery/models/retro_pump.glb",
		"position": Vector3(2.5, 0.0, 12.0),
		"rotation_degrees": Vector3(0.0, -20.0, 0.0),
		"scale": Vector3(1.5, 1.5, 1.5),
	},
	{
		"id": "retro_pipe_valve",
		"path": "res://game/art/models/third_party/chilly_durango_retro_machinery/models/retro_pipe_valve.glb",
		"position": Vector3(5.5, 0.0, 12.0),
		"rotation_degrees": Vector3(0.0, 30.0, 0.0),
		"scale": Vector3(1.5, 1.5, 1.5),
	},
	{
		"id": "pipe_set_1",
		"path": "res://game/art/models/third_party/loafbrr_pipes/Scenes/pipeSet/pipe_set_1.tscn",
		"position": Vector3(9.0, 0.0, 12.0),
		"rotation_degrees": Vector3(0.0, 180.0, 0.0),
		"scale": Vector3(1.0, 1.0, 1.0),
	},
	{
		"id": "pipe_valve_group",
		"path": "res://game/art/models/third_party/loafbrr_pipes/Scenes/Valves/valve_a_grp.tscn",
		"position": Vector3(13.0, 0.0, 12.0),
		"rotation_degrees": Vector3(0.0, 15.0, 0.0),
		"scale": Vector3(0.6, 0.6, 0.6),
	},
	{
		"id": "pipe_utility_box",
		"path": "res://game/art/models/third_party/loafbrr_pipes/Scenes/Boxes/pipes_box_aa.tscn",
		"position": Vector3(16.5, 0.0, 12.0),
		"rotation_degrees": Vector3(0.0, -15.0, 0.0),
		"scale": Vector3(0.8, 0.8, 0.8),
	},
	{
		"id": "mine_props",
		"path": "res://game/art/models/third_party/elbolilloduro_mine/mine_props.dae",
		"position": Vector3(-17.0, 0.0, -8.5),
		"rotation_degrees": Vector3(0.0, 180.0, 0.0),
		"scale": Vector3(0.05, 0.05, 0.05),
	},
	{
		"id": "psx_models",
		"path": "res://game/art/models/third_party/elbolilloduro_psx_models/models.dae",
		"position": Vector3(-10.5, 0.0, -8.5),
		"rotation_degrees": Vector3(0.0, 180.0, 0.0),
		"scale": Vector3(0.08, 0.08, 0.08),
	},
	{
		"id": "industrial_exterior",
		"path": "res://game/art/models/third_party/godgoldfear_industrial/IndustrialHorror_PS_like.fbx",
		"position": Vector3(-3.5, 0.0, -8.5),
		"rotation_degrees": Vector3(0.0, 180.0, 0.0),
		"scale": Vector3(0.07, 0.07, 0.07),
	},
	{
		"id": "street_barrel",
		"path": "res://game/art/models/third_party/kkryy_street_furniture/Barrel.fbx",
		"position": Vector3(4.0, 0.0, -8.5),
		"rotation_degrees": Vector3(0.0, 25.0, 0.0),
		"scale": Vector3(1.2, 1.2, 1.2),
	},
	{
		"id": "prildarill_shelf",
		"path": "res://game/art/models/third_party/prildarill_low_poly_assets/Shelf.fbx",
		"position": Vector3(8.5, 0.0, -8.5),
		"rotation_degrees": Vector3(0.0, 180.0, 0.0),
		"scale": Vector3(0.8, 0.8, 0.8),
	},
	{
		"id": "psx_skeleton",
		"path": "res://game/art/models/third_party/vinrax_psx_skeleton/skeleton.glb",
		"position": Vector3(12.5, 0.0, -8.5),
		"rotation_degrees": Vector3(0.0, 180.0, 0.0),
		"scale": Vector3(0.08, 0.08, 0.08),
	},
	{
		"id": "water_duck",
		"path": "res://game/art/models/third_party/binbun_water/duck.glb",
		"position": Vector3(17.0, 0.0, -8.5),
		"rotation_degrees": Vector3(0.0, 25.0, 0.0),
		"scale": Vector3(1.5, 1.5, 1.5),
	},
]

const MATERIAL_ASSETS: Array[Dictionary] = [
	{
		"id": "retro_asphalt",
		"path": "res://game/art/materials/retro_urban/asphalt_asphalt_03.tres",
		"position": Vector3(-7.0, 0.04, 3.0),
		"size": Vector3(2.2, 0.08, 2.2),
	},
	{
		"id": "retro_asphalt_road",
		"path": "res://game/art/materials/retro_urban/asphaltroad_asphaltroad_02.tres",
		"position": Vector3(-4.5, 0.04, 3.0),
		"size": Vector3(2.2, 0.08, 2.2),
	},
	{
		"id": "retro_clean_pavement",
		"path": "res://game/art/materials/retro_urban/cleanpavement_cleanpavement_04.tres",
		"position": Vector3(-2.0, 0.04, 3.0),
		"size": Vector3(2.2, 0.08, 2.2),
	},
	{
		"id": "retro_concrete",
		"path": "res://game/art/materials/retro_urban/concrete_concrete_06.tres",
		"position": Vector3(0.5, 0.04, 3.0),
		"size": Vector3(2.2, 0.08, 2.2),
	},
	{
		"id": "retro_concrete_slabs",
		"path": "res://game/art/materials/retro_urban/concreteslabs_concreteslabs_02.tres",
		"position": Vector3(3.0, 0.04, 3.0),
		"size": Vector3(2.2, 0.08, 2.2),
	},
	{
		"id": "retro_rough_pavement",
		"path": "res://game/art/materials/retro_urban/roughpavement_roughpavement_01.tres",
		"position": Vector3(5.5, 0.04, 3.0),
		"size": Vector3(2.2, 0.08, 2.2),
	},
]

const TEXTURE_ASSETS: Array[Dictionary] = [
	{
		"id": "aquilarius_retro_tile",
		"path": "res://game/art/textures/third_party/aquilarius_retro/t1.png",
		"position": Vector3(-18.0, 2.2, 16.0),
		"rotation_degrees": Vector3(0.0, 180.0, 0.0),
		"size": Vector2(3.0, 2.5),
		"color": Color(0.76, 0.9, 1.0, 1.0),
	},
	{
		"id": "lvl11_quake_sci_fi_tile",
		"path": "res://game/art/textures/third_party/lvl11_quake_sci_fi/flr_painted_Q_G.png",
		"position": Vector3(-13.5, 2.2, 16.0),
		"rotation_degrees": Vector3(0.0, 180.0, 0.0),
		"size": Vector2(3.0, 2.5),
		"color": Color(1.0, 0.82, 0.62, 1.0),
	},
	{
		"id": "strideh_delven_tile",
		"path": "res://game/art/textures/third_party/strideh_delven/true_colour/dlv_woodgen1.png",
		"position": Vector3(-9.0, 2.2, 16.0),
		"rotation_degrees": Vector3(0.0, 180.0, 0.0),
		"size": Vector2(3.0, 2.5),
		"color": Color(0.92, 0.78, 0.62, 1.0),
	},
	{
		"id": "strideh_torment_tile",
		"path": "res://game/art/textures/third_party/strideh_torment/true_colour/str_wasteland1.png",
		"position": Vector3(-4.5, 2.2, 16.0),
		"rotation_degrees": Vector3(0.0, 180.0, 0.0),
		"size": Vector2(3.0, 2.5),
		"color": Color(1.0, 0.72, 0.55, 1.0),
	},
	{
		"id": "strideh_stencil_mask",
		"path": "res://game/art/textures/third_party/strideh_stencil_decals/masks/MaskAlphabet.png",
		"position": Vector3(0.0, 2.2, 16.0),
		"rotation_degrees": Vector3(0.0, 180.0, 0.0),
		"size": Vector2(3.0, 2.5),
		"color": Color(0.95, 0.95, 0.9, 1.0),
	},
	{
		"id": "trash_debris_decal",
		"path": "res://game/art/models/third_party/mcsteeg_trash_and_debris/TrashAndDebris_LitterDecal_1.png",
		"position": Vector3(4.5, 2.2, 16.0),
		"rotation_degrees": Vector3(0.0, 180.0, 0.0),
		"size": Vector2(3.0, 2.5),
		"color": Color(0.88, 0.82, 0.7, 1.0),
	},
	{
		"id": "chilly_generator_texture",
		"path": "res://game/art/models/third_party/chilly_durango_retro_machinery/models/retro_generator_Generator-Texture.png",
		"position": Vector3(9.0, 2.2, 16.0),
		"rotation_degrees": Vector3(0.0, 180.0, 0.0),
		"size": Vector2(3.0, 2.5),
		"color": Color(0.82, 0.92, 1.0, 1.0),
	},
	{
		"id": "loafbrr_pipe_texture",
		"path": "res://game/art/models/third_party/loafbrr_pipes/Textures/Pipe3/Pipe3_albedo.png",
		"position": Vector3(13.5, 2.2, 16.0),
		"rotation_degrees": Vector3(0.0, 180.0, 0.0),
		"size": Vector2(3.0, 2.5),
		"color": Color(0.78, 0.9, 0.84, 1.0),
	},
	{
		"id": "industrial_wall_texture",
		"path": "res://game/art/models/third_party/godgoldfear_industrial/Wall.png",
		"position": Vector3(18.0, 2.2, 16.0),
		"rotation_degrees": Vector3(0.0, 180.0, 0.0),
		"size": Vector2(3.0, 2.5),
		"color": Color(0.84, 0.76, 0.66, 1.0),
	},
	{
		"id": "survival_backpack_texture",
		"path": "res://game/art/models/third_party/mcsteeg_survival/Backpack.png",
		"position": Vector3(-13.5, 2.2, 12.8),
		"rotation_degrees": Vector3(0.0, 180.0, 0.0),
		"size": Vector2(3.0, 2.5),
		"color": Color(0.72, 0.9, 0.76, 1.0),
	},
	{
		"id": "prildarill_door_texture",
		"path": "res://game/art/models/third_party/prildarill_low_poly_assets/doorandframe.png",
		"position": Vector3(-9.0, 2.2, 12.8),
		"rotation_degrees": Vector3(0.0, 180.0, 0.0),
		"size": Vector2(3.0, 2.5),
		"color": Color(0.92, 0.82, 0.98, 1.0),
	},
	{
		"id": "street_furniture_texture",
		"path": "res://game/art/models/third_party/kkryy_street_furniture/barrel.png",
		"position": Vector3(-4.5, 2.2, 12.8),
		"rotation_degrees": Vector3(0.0, 180.0, 0.0),
		"size": Vector2(3.0, 2.5),
		"color": Color(1.0, 0.76, 0.62, 1.0),
	},
	{
		"id": "vinrax_skeleton_texture",
		"path": "res://game/art/models/third_party/vinrax_psx_skeleton/skeleton_d.png",
		"position": Vector3(0.0, 2.2, 12.8),
		"rotation_degrees": Vector3(0.0, 180.0, 0.0),
		"size": Vector2(3.0, 2.5),
		"color": Color(0.88, 0.9, 0.76, 1.0),
	},
	{
		"id": "wind_turbine_texture",
		"path": "res://game/art/models/third_party/3dexter_looming_landmarks/WindTurbineBake.png",
		"position": Vector3(4.5, 2.2, 12.8),
		"rotation_degrees": Vector3(0.0, 180.0, 0.0),
		"size": Vector2(3.0, 2.5),
		"color": Color(0.8, 0.9, 1.0, 1.0),
	},
	{
		"id": "binbun_water_texture",
		"path": "res://game/art/models/third_party/binbun_water/texture.png",
		"position": Vector3(9.0, 2.2, 12.8),
		"rotation_degrees": Vector3(0.0, 180.0, 0.0),
		"size": Vector2(3.0, 2.5),
		"color": Color(0.68, 0.9, 1.0, 1.0),
	},
]

const VFX_ASSETS: Array[Dictionary] = [
	{
		"id": "vfx_fire_flipbook",
		"path": "res://game/art/textures/vfx/brackeys/flipbooks/fire_03_8x8.tga",
		"position": Vector3(-6.5, 2.0, 5.0),
		"h_frames": 8,
		"v_frames": 8,
		"color": Color(1.0, 0.48, 0.18, 0.9),
	},
	{
		"id": "vfx_smoke_flipbook",
		"path": "res://game/art/textures/vfx/brackeys/flipbooks/wispy_smoke_02_8x8.tga",
		"position": Vector3(-2.0, 2.0, 5.0),
		"h_frames": 8,
		"v_frames": 8,
		"color": Color(0.76, 0.82, 0.86, 0.72),
	},
	{
		"id": "vfx_flame_flipbook",
		"path": "res://game/art/textures/vfx/brackeys/flipbooks/flame_01_16x4.tga",
		"position": Vector3(2.5, 2.0, 5.0),
		"h_frames": 16,
		"v_frames": 4,
		"color": Color(1.0, 0.72, 0.24, 0.9),
	},
	{
		"id": "vfx_electric_ring",
		"path": "res://game/art/textures/vfx/brackeys/predrawn/electric_ring_6x5.png",
		"position": Vector3(6.5, 2.0, 5.0),
		"h_frames": 6,
		"v_frames": 5,
		"color": Color(0.25, 0.85, 1.0, 0.9),
	},
]

var load_errors: Array[String] = []
var spawned_model_count := 0
var spawned_material_count := 0
var spawned_texture_count := 0
var spawned_vfx_count := 0
var _built := false


func _ready() -> void:
	call_deferred("_build")


func _build() -> void:
	if _built:
		return
	_built = true
	_spawn_display_platform()
	for entry: Dictionary in MODEL_ASSETS:
		_spawn_model(entry)
	for entry: Dictionary in MATERIAL_ASSETS:
		_spawn_material(entry)
	for entry: Dictionary in TEXTURE_ASSETS:
		_spawn_texture(entry)
	for entry: Dictionary in VFX_ASSETS:
		_spawn_vfx(entry)
	set_meta("asset_usage_contract", get_asset_usage_contract())




func _spawn_display_platform() -> void:
	var material := ResourceLoader.load(DISPLAY_PLATFORM_MATERIAL_PATH) as Material
	if material == null:
		load_errors.append(
			"Display platform material failed to load: %s" % DISPLAY_PLATFORM_MATERIAL_PATH
		)
		return
	var platform := MeshInstance3D.new()
	platform.name = "AssetDisplayPlatform"
	platform.position = DISPLAY_PLATFORM_POSITION
	platform.set_meta("asset_id", "asset_display_platform")
	platform.set_meta("asset_path", DISPLAY_PLATFORM_MATERIAL_PATH)
	platform.set_meta("asset_family", "material")
	var mesh := BoxMesh.new()
	mesh.size = DISPLAY_PLATFORM_SIZE
	mesh.material = material
	platform.mesh = mesh
	add_child(platform)
	platform.add_to_group("level_asset_material")


func get_asset_usage_contract() -> Dictionary:
	return {
		"version": CONTRACT_VERSION,
		"valid": _built and load_errors.is_empty(),
		"asset_families": IMPORTED_ASSET_FAMILIES.duplicate(),
		"model_assets": _asset_ids(MODEL_ASSETS),
		"material_assets": _asset_ids(MATERIAL_ASSETS),
		"texture_assets": _asset_ids(TEXTURE_ASSETS),
		"vfx_assets": _asset_ids(VFX_ASSETS),
		"spawned_models": spawned_model_count,
		"spawned_materials": spawned_material_count,
		"spawned_textures": spawned_texture_count,
		"spawned_vfx": spawned_vfx_count,
		"errors": load_errors.duplicate(),
	}


func _asset_ids(entries: Array[Dictionary]) -> Array[String]:
	var ids: Array[String] = []
	for entry: Dictionary in entries:
		ids.append(str(entry.get("id", "")))
	return ids


func _spawn_model(entry: Dictionary) -> void:
	var path := str(entry.get("path", ""))
	var packed := ResourceLoader.load(path) as PackedScene
	if packed == null:
		load_errors.append("Model %s failed to load: %s" % [entry.get("id", ""), path])
		return
	var instance := packed.instantiate()
	instance.name = "Asset_%s" % entry.get("id", "model")
	instance.set_meta("asset_id", entry.get("id", ""))
	instance.set_meta("asset_path", path)
	instance.set_meta("asset_family", "model")
	instance.position = entry.get("position", Vector3.ZERO)
	instance.rotation_degrees = entry.get("rotation_degrees", Vector3.ZERO)
	instance.scale = entry.get("scale", Vector3.ONE)
	add_child(instance)
	_disable_collision(instance)
	instance.add_to_group("level_asset_model")
	spawned_model_count += 1


func _spawn_material(entry: Dictionary) -> void:
	var path := str(entry.get("path", ""))
	var material := ResourceLoader.load(path) as Material
	if material == null:
		load_errors.append("Material %s failed to load: %s" % [entry.get("id", ""), path])
		return
	var panel := MeshInstance3D.new()
	panel.name = "Material_%s" % entry.get("id", "material")
	panel.position = entry.get("position", Vector3.ZERO)
	panel.set_meta("asset_id", entry.get("id", ""))
	panel.set_meta("asset_path", path)
	panel.set_meta("asset_family", "material")
	var mesh := BoxMesh.new()
	mesh.size = entry.get("size", Vector3.ONE)
	mesh.material = material
	panel.mesh = mesh
	panel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(panel)
	panel.add_to_group("level_asset_material")
	spawned_material_count += 1


func _spawn_texture(entry: Dictionary) -> void:
	var path := str(entry.get("path", ""))
	var texture := ResourceLoader.load(path) as Texture2D
	if texture == null:
		load_errors.append("Texture %s failed to load: %s" % [entry.get("id", ""), path])
		return
	var panel := MeshInstance3D.new()
	panel.name = "Texture_%s" % entry.get("id", "texture")
	panel.position = entry.get("position", Vector3.ZERO)
	panel.rotation_degrees = entry.get("rotation_degrees", Vector3.ZERO)
	panel.set_meta("asset_id", entry.get("id", ""))
	panel.set_meta("asset_path", path)
	panel.set_meta("asset_family", "texture")
	var mesh := QuadMesh.new()
	mesh.size = entry.get("size", Vector2(2.0, 2.0))
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = entry.get("color", Color.WHITE)
	material.albedo_texture = texture
	mesh.material = material
	panel.mesh = mesh
	panel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(panel)
	panel.add_to_group("level_asset_texture")
	spawned_texture_count += 1


func _spawn_vfx(entry: Dictionary) -> void:
	var path := str(entry.get("path", ""))
	var texture := ResourceLoader.load(path) as Texture2D
	if texture == null:
		load_errors.append("VFX %s failed to load: %s" % [entry.get("id", ""), path])
		return
	var particles := GPUParticles3D.new()
	particles.name = "VFX_%s" % entry.get("id", "vfx")
	particles.position = entry.get("position", Vector3.ZERO)
	particles.amount = 18
	particles.lifetime = 1.8
	particles.preprocess = 1.0
	particles.emitting = true
	particles.visibility_aabb = AABB(Vector3(-3.0, -2.0, -3.0), Vector3(6.0, 6.0, 6.0))
	particles.set_meta("asset_id", entry.get("id", ""))
	particles.set_meta("asset_path", path)
	particles.set_meta("asset_family", "vfx")
	var process_material := ParticleProcessMaterial.new()
	process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process_material.emission_sphere_radius = 0.25
	process_material.direction = Vector3.UP
	process_material.spread = 28.0
	process_material.initial_velocity_min = 0.15
	process_material.initial_velocity_max = 0.5
	process_material.gravity = Vector3(0.0, 0.15, 0.0)
	particles.process_material = process_material
	var quad := QuadMesh.new()
	quad.size = Vector2(1.4, 1.4)
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.billboard_keep_scale = true
	material.vertex_color_use_as_albedo = true
	material.albedo_color = entry.get("color", Color.WHITE)
	material.albedo_texture = texture
	material.particles_anim_h_frames = int(entry.get("h_frames", 1))
	material.particles_anim_v_frames = int(entry.get("v_frames", 1))
	material.particles_anim_loop = true
	quad.material = material
	particles.draw_pass_1 = quad
	add_child(particles)
	particles.add_to_group("level_asset_vfx")
	spawned_vfx_count += 1


func _disable_collision(node: Node) -> void:
	if node is CollisionShape3D:
		(node as CollisionShape3D).disabled = true
	elif node is CollisionPolygon3D:
		(node as CollisionPolygon3D).disabled = true
	elif node is PhysicsBody3D:
		var body := node as PhysicsBody3D
		body.collision_layer = 0
		body.collision_mask = 0
	for child: Node in node.get_children():
		_disable_collision(child)
