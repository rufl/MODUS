extends ModusGutTestBase

const NavigationMeshBaker = preload("res://game/scripts/map_generator/navigation_mesh_baker.gd")
const ValidationSystem = preload("res://game/scripts/map_generator/validation_system.gd")
const GenerationContext = preload("res://game/scripts/map_generator/generation_context.gd")
const Cell = preload("res://game/scripts/map_generator/cell.gd")
const Room = preload("res://game/scripts/map_generator/room.gd")

var context: GenerationContext
var baker: NavigationMeshBaker
var validator: ValidationSystem
var other_geometry: CSGCombiner3D


func before_each() -> void:
	context = GenerationContext.new()
	baker = NavigationMeshBaker.new()
	validator = ValidationSystem.new()
	context.grid_size = Vector2i(18, 4)
	for y in range(4):
		var row: Array[Cell] = []
		for x in range(18):
			row.append(Cell.new(Cell.Type.ROOM))
		context.grid.append(row)
	context.player_start_position = Vector2i(2, 1)
	for room_x in [2, 14]:
		var room := Room.new(context.rooms.size(), Vector2i(room_x, 1))
		room.cells.append(room.center)
		room.entrance_points.append(room.center + Vector2i.RIGHT)
		context.rooms.append(room)
	context.csg_root = CSGCombiner3D.new()
	context.csg_root.use_collision = true
	add_child(context.csg_root)
	baker.initialize(context)


func after_each() -> void:
	if is_instance_valid(context.csg_root):
		context.csg_root.free()
	if is_instance_valid(context.navigation_region):
		context.navigation_region.free()
	if is_instance_valid(other_geometry):
		other_geometry.free()
	other_geometry = null
	baker = null
	context = null
	validator = null


func _floor(root: CSGCombiner3D, center: Vector3, size: Vector3) -> void:
	var floor_box := CSGBox3D.new()
	floor_box.size = size
	floor_box.position = center
	root.add_child(floor_box)


func _prepare_geometry() -> void:
	await get_tree().physics_frame
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().process_frame


func test_real_connected_bake_validates_without_attached_region() -> void:
	_floor(context.csg_root, Vector3(18, -0.1, 4), Vector3(36, 0.2, 8))
	await _prepare_geometry()
	assert_true(baker.bake_navigation_mesh())
	var result := validator.validate_navigation_mesh(context)
	assert_true(result.is_valid, result.error_message)
	assert_true(baker.is_position_on_navmesh(Vector3(29, 0, 3)))


func test_prefab_collision_blocks_an_otherwise_connected_floor() -> void:
	_floor(context.csg_root, Vector3(18, -0.1, 4), Vector3(36, 0.2, 8))
	var wall := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2, 5, 8)
	collision.shape = shape
	wall.add_child(collision)
	wall.position = Vector3(18, 2.5, 4)
	context.csg_root.add_child(wall)
	await _prepare_geometry()
	assert_true(baker.bake_navigation_mesh())
	assert_false(validator.validate_navigation_mesh(context).is_valid)


func test_moving_door_does_not_permanently_disconnect_baked_floor() -> void:
	_floor(context.csg_root, Vector3(18, -0.1, 4), Vector3(36, 0.2, 8))
	var door := AnimatableBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2, 5, 8)
	collision.shape = shape
	door.add_child(collision)
	door.position = Vector3(18, 2.5, 4)
	context.csg_root.add_child(door)
	await _prepare_geometry()
	assert_true(baker.bake_navigation_mesh())
	var result := validator.validate_navigation_mesh(context)
	assert_true(result.is_valid, result.error_message)


func test_shootable_cache_does_not_permanently_disconnect_baked_floor() -> void:
	_floor(context.csg_root, Vector3(18, -0.1, 4), Vector3(36, 0.2, 8))
	var secret := SecretWallActor.new()
	secret.position = Vector3(18, 1.5, 4)
	secret.rotation.y = PI / 2.0
	secret.scale = Vector3(4.0, 1.2, 1.0)
	context.csg_root.add_child(secret)
	await _prepare_geometry()
	assert_true(baker.bake_navigation_mesh())
	var result := validator.validate_navigation_mesh(context)
	assert_true(
		result.is_valid,
		"A closed secret must retain a baked route that becomes traversable when opened"
	)


func test_disconnected_island_fails_even_with_unrelated_bridge_geometry() -> void:
	_floor(context.csg_root, Vector3(6, -0.1, 4), Vector3(12, 0.2, 8))
	_floor(context.csg_root, Vector3(30, -0.1, 4), Vector3(12, 0.2, 8))
	other_geometry = CSGCombiner3D.new()
	other_geometry.add_to_group("navigation_geometry")
	add_child(other_geometry)
	_floor(other_geometry, Vector3(18, -0.1, 4), Vector3(36, 0.2, 8))
	await _prepare_geometry()
	assert_true(baker.bake_navigation_mesh())
	# Both endpoints lie on real polygons; only an actual route check detects this.
	assert_true(baker.is_position_on_navmesh(Vector3(29, 0, 3)))
	assert_false(validator.validate_navigation_mesh(context).is_valid)


func test_isolated_navigation_queries_release_maps_on_success_and_failure() -> void:
	_floor(context.csg_root, Vector3(18, -0.1, 4), Vector3(36, 0.2, 8))
	await _prepare_geometry()
	assert_true(baker.bake_navigation_mesh())
	var maps_before := NavigationServer3D.get_maps()
	assert_true(validator.validate_navigation_mesh(context).is_valid)
	context.monster_spawns = [{"position": Vector3(100, 0, 100)}]
	assert_false(validator.validate_navigation_mesh(context).is_valid)
	await _prepare_geometry()
	assert_eq(NavigationServer3D.get_maps(), maps_before)


func test_one_invalid_monster_among_many_is_rejected() -> void:
	_floor(context.csg_root, Vector3(18, -0.1, 4), Vector3(36, 0.2, 8))
	await _prepare_geometry()
	assert_true(baker.bake_navigation_mesh())
	for i in range(11):
		context.monster_spawns.append({"position": Vector3(5 + i, 0, 3)})
	assert_true(validator.validate_monster_spawns(context).is_valid)
	context.monster_spawns[10] = {
		"position": Vector3(100, 0, 100), "world_position": Vector3(5, 0, 3)
	}
	assert_false(validator.validate_monster_spawns(context).is_valid)


func test_monster_on_disconnected_island_is_rejected() -> void:
	_floor(context.csg_root, Vector3(6, -0.1, 4), Vector3(12, 0.2, 8))
	_floor(context.csg_root, Vector3(30, -0.1, 4), Vector3(12, 0.2, 8))
	await _prepare_geometry()
	assert_true(baker.bake_navigation_mesh())
	context.monster_spawns = [{"position": Vector2i(14, 1), "world_position": Vector3(29, 0, 3)}]
	assert_false(validator.validate_monster_spawns(context).is_valid)


func test_empty_geometry_and_empty_mesh_fail() -> void:
	await _prepare_geometry()
	assert_false(baker.bake_navigation_mesh())
	assert_push_error_count(1)
	assert_false(validator.validate_navigation_mesh(context).is_valid)


func test_missing_geometry_and_missing_mesh_fail() -> void:
	context.csg_root.free()
	context.csg_root = null
	assert_false(baker.bake_navigation_mesh())
	assert_push_error_count(1)
	context.navigation_region.navigation_mesh = null
	assert_false(validator.validate_navigation_mesh(context).is_valid)


func test_detached_geometry_is_not_implicitly_attached() -> void:
	_floor(context.csg_root, Vector3(18, -0.1, 4), Vector3(36, 0.2, 8))
	remove_child(context.csg_root)
	assert_false(baker.bake_navigation_mesh())
	assert_push_error_count(1)
	assert_false(context.csg_root.is_inside_tree())


func test_reinitialization_reclaims_unowned_region() -> void:
	var old_context := context
	var old_region := context.navigation_region
	context = GenerationContext.new()
	baker.initialize(context)
	assert_false(is_instance_valid(old_region))
	assert_null(old_context.navigation_region)
	old_context.csg_root.free()
