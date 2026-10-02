extends ModusGutTestBase
const DIRECTIONAL_BLOOD_SPRAY = preload(
	"res://game/scripts/features/effects/effects/directional_blood_spray.gd"
)
const DECAL_SPAWNER = preload("res://game/scripts/features/effects/decal_spawner.gd")
const BLOOD_HIT_SPAWNER = preload(
	"res://game/scripts/features/effects/effects/blood_hit_spawner.gd"
)
const SPRITE3D_DECAL = preload("res://game/scripts/features/effects/effects/sprite3d_decal.gd")
const EFFECT_POOL_MANAGER = preload(
	"res://game/scripts/features/effects/effects/effect_pool_manager.gd"
)
const VFX_TEXTURE_CATALOG = preload("res://game/scripts/features/effects/vfx_texture_catalog.gd")
const SKELETAL_CHARACTER_VISUALS = preload(
	"res://game/entities/common/skeletal_character_visuals.gd"
)


func before_each() -> void:
	await modus_setup()


func after_each() -> void:
	modus_teardown()


func test_deleted_decal_cancels_remaining_blood_drips() -> void:
	var spray: Node = DIRECTIONAL_BLOOD_SPRAY.new()
	add_child_autofree(spray)
	var decal := Sprite3D.new()
	add_child(decal)
	var emitted: Array[Node] = []
	var record_drip := func(node: Node) -> void:
		if node is GPUParticles3D:
			emitted.append(node)
			autofree(node)
	get_tree().node_added.connect(record_drip)
	spray._spawn_drip_trail(decal, 1.1)
	await wait_seconds(0.1)
	assert_eq(emitted.size(), 1, "A live decal emits its first drip")
	decal.free()
	await wait_seconds(1.05)
	get_tree().node_added.disconnect(record_drip)
	assert_eq(emitted.size(), 1, "Deleted decals produce no delayed blood particles")


func test_blood_decal_follows_moving_hit_surface() -> void:
	var spray: Node = DIRECTIONAL_BLOOD_SPRAY.new()
	add_child_autofree(spray)
	var carrier := Node3D.new()
	add_child_autofree(carrier)

	spray._spawn_blood_decal_on_surface(Vector3.ZERO, Vector3.FORWARD, carrier)
	assert_eq(carrier.get_child_count(), 1, "Surface decal is parented to its hit body")
	var decal := carrier.get_child(0) as Sprite3D
	var initial_position := decal.global_position
	carrier.global_position = Vector3(3, 0, 0)

	assert_true(
		decal.global_position.is_equal_approx(initial_position + Vector3(3, 0, 0)),
		"Surface decal follows a moving hit body instead of floating in world space"
	)


func test_pooled_decal_follows_moving_collision_body() -> void:
	var spawner: Node = DECAL_SPAWNER.new()
	add_child_autofree(spawner)
	var carrier := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3.ONE * 2.0
	collision.shape = shape
	carrier.add_child(collision)
	add_child_autofree(carrier)
	await wait_physics_frames(1)

	var decal: Sprite3D = spawner.spawn_decal(null, Vector3(0, 1, 0), Vector3.UP, Vector3.ONE, 30.0)
	assert_eq(decal.get_parent(), carrier, "Pooled decal is attached to the hit body")
	var initial_position: Vector3 = decal.global_position
	carrier.global_position = Vector3(3, 0, 0)

	assert_true(
		decal.global_position.is_equal_approx(initial_position + Vector3(3, 0, 0)),
		"Pooled decal follows a moving collision body instead of floating in world space"
	)


func test_droplet_blood_pool_follows_collision_body() -> void:
	var spawner: Node = BLOOD_HIT_SPAWNER.new()
	spawner.use_directional_spray = false
	add_child_autofree(spawner)
	var carrier := Node3D.new()
	add_child_autofree(carrier)

	spawner._spawn_shader_blood_pool(Vector3.ZERO, carrier)
	assert_eq(carrier.get_child_count(), 1, "Droplet blood pool is attached to its hit body")
	var pool := carrier.get_child(0) as Sprite3D
	var initial_position: Vector3 = pool.global_position
	carrier.global_position = Vector3(3, 0, 0)

	assert_true(
		pool.global_position.is_equal_approx(initial_position + Vector3(3, 0, 0)),
		"Droplet blood pool follows a moving collision body instead of floating in world space"
	)


func test_reusable_sprite_decal_follows_moving_surface() -> void:
	var carrier := Node3D.new()
	add_child_autofree(carrier)
	var decal: Sprite3D = SPRITE3D_DECAL.new()
	carrier.add_child(decal)

	decal.setup(null, Vector3.ZERO, Vector3.FORWARD, Vector2.ONE, 30.0, carrier)
	var initial_position: Vector3 = decal.global_position
	carrier.global_position = Vector3(3, 0, 0)

	assert_true(
		decal.global_position.is_equal_approx(initial_position + Vector3(3, 0, 0)),
		"Reusable Sprite3D decal follows its moving surface"
	)


func test_pooled_muzzle_flash_uses_catalog_texture() -> void:
	var manager: Node = EFFECT_POOL_MANAGER.new()
	manager.muzzle_flash_pool_size = 1
	manager.particle_pool_size = 0
	manager.light_pool_size = 0
	manager.shell_casing_pool_size = 0
	add_child_autofree(manager)
	await wait_physics_frames(1)

	var texture: Texture2D = VFX_TEXTURE_CATALOG.pick_muzzle_flash()
	assert_not_null(texture, "VFX catalog should resolve a muzzle texture")
	var flash: Node3D = manager.spawn_muzzle_flash(Vector3.ZERO, Color.ORANGE, 1.0, 1.0, texture)
	var mesh := flash.get_node("Mesh") as MeshInstance3D
	var material := mesh.get_surface_override_material(0) as StandardMaterial3D

	assert_eq(
		material.albedo_texture, texture, "Pooled muzzle flashes should use the catalog texture"
	)


func test_decal_spawner_enforces_quality_active_limit() -> void:
	var spawner: Node = DECAL_SPAWNER.new()
	add_child_autofree(spawner)
	spawner.set_quality(0)

	for _i in range(25):
		spawner.spawn_decal(null, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, 30.0)

	var stats: Dictionary = spawner.get_pool_stats()
	assert_eq(stats["active"], 20, "Low quality should cap active decals at 20")
	assert_lte(stats["total"], 50, "Decal pool should remain bounded")


func test_character_color_preserves_surface_texture() -> void:
	var visuals: Node = SKELETAL_CHARACTER_VISUALS.new()
	add_child_autofree(visuals)
	assert_eq(
		visuals.skeleton.find_children("*", "PhysicalBone3D", true, false).size(),
		0,
		"Ragdoll physics bodies should be deferred until ragdoll activation"
	)
	var mannequin := Node3D.new()
	visuals.mannequin_root = mannequin
	visuals.add_child(mannequin)

	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	var source_material := StandardMaterial3D.new()
	var source_texture := GradientTexture2D.new()
	source_material.albedo_texture = source_texture
	box.material = source_material
	mesh.mesh = box
	mannequin.add_child(mesh)

	visuals.character_color = Color(0.2, 0.4, 0.8)
	visuals._apply_color()

	var active_material := mesh.get_active_material(0) as StandardMaterial3D
	assert_not_null(active_material, "Colored mesh should retain a surface material")
	assert_eq(
		active_material.albedo_texture,
		source_texture,
		"Character tinting must preserve the imported albedo texture"
	)
	assert_null(
		mesh.material_override,
		"Character tinting should not replace all surfaces with a textureless override"
	)
