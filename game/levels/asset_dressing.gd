class_name LevelAssetDressing
extends Node3D

## Runtime dressing contract for authored levels.
##
## The imported fence, office, RetroUrban material, and Brackeys VFX families
## are deliberately instantiated here instead of being editor-only registry
## entries. Models are visual-only: dressing must never change gameplay collision.

const CONTRACT_VERSION := 1
const DISPLAY_PLATFORM_SIZE := Vector3(24.0, 0.4, 18.0)
const DISPLAY_PLATFORM_POSITION := Vector3(0.0, -0.28, 2.0)
const DISPLAY_PLATFORM_MATERIAL_PATH := "res://game/art/materials/retro_urban/cleanpavement_cleanpavement_04.tres"

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
		"model_assets": _asset_ids(MODEL_ASSETS),
		"material_assets": _asset_ids(MATERIAL_ASSETS),
		"vfx_assets": _asset_ids(VFX_ASSETS),
		"spawned_models": spawned_model_count,
		"spawned_materials": spawned_material_count,
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
