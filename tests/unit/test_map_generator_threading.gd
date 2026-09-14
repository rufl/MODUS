extends ModusGutTestBase

const MapGeneratorScript: GDScript = preload("res://game/scripts/map_generator/map_generator.gd")
const LevelRootScript: GDScript = preload("res://shared/editor_core/nodes/level_root.gd")
const SpawnPointScript: GDScript = preload("res://shared/editor_core/nodes/spawn_point.gd")
var map_generator: Node


func before_each() -> void:
	map_generator = MapGeneratorScript.new()
	add_child_autofree(map_generator)


func after_each() -> void:
	map_generator.cancel_generation()
	DirAccess.remove_absolute("user://generated_roundtrip.tscn")
	DirAccess.remove_absolute("user://generated_roundtrip.json")


func test_seeded_scene_roundtrip_retains_routes_and_gameplay() -> void:
	var config := GenerationConfig.new()
	config.map_size = Vector2i(64, 64)
	config.map_seed = "caller-owned-seed"
	seed(111)
	var first := await _generate("generator-correctness", config)
	if not first.has("scene"):
		return
	assert_eq(config.map_seed, "caller-owned-seed", "Generation must not mutate caller config")
	var scene: PackedScene = first["scene"]
	var metadata: Dictionary = first["metadata"]
	assert_eq(metadata["seed"], "generator-correctness", "Replay uses the effective seed argument")
	assert_false(metadata["gameplay"]["keys"].is_empty(), "Enabled keys must survive generation")
	assert_false(metadata["gameplay"]["secrets"].is_empty(), "Enabled secrets need real footprints")
	var destinations: Array[Vector3] = []
	for room: Room in map_generator.generation_context.rooms:
		var cell: Cell = map_generator.generation_context.grid[room.center.y][room.center.x]
		destinations.append(
			Vector3(room.center.x * 2.0 + 1.0, cell.height, room.center.y * 2.0 + 1.0)
		)
	for key: Dictionary in metadata["gameplay"]["keys"]:
		destinations.append(key["position"])
	for spawn: Dictionary in metadata["gameplay"]["monsters"]:
		destinations.append(spawn["world_position"])

	assert_true(
		map_generator.export_map(
			scene, "user://generated_roundtrip.tscn", GenerationConfig.ExportFormat.PACKED_SCENE
		)
	)
	var reloaded := (
		ResourceLoader.load(
			"user://generated_roundtrip.tscn", "PackedScene", ResourceLoader.CACHE_MODE_IGNORE
		)
		as PackedScene
	)
	assert_not_null(reloaded)
	if reloaded == null:
		return
	var world := SubViewport.new()
	world.own_world_3d = true
	world.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child_autofree(world)
	var instance := reloaded.instantiate() as Node3D
	world.add_child(instance)
	var region := instance.get_node("NavigationRegion") as NavigationRegion3D
	var vertices := region.navigation_mesh.get_vertices()
	var nav_map := world.find_world_3d().navigation_map
	NavigationServer3D.map_set_cell_size(nav_map, region.navigation_mesh.cell_size)
	NavigationServer3D.map_set_cell_height(nav_map, region.navigation_mesh.cell_height)
	NavigationServer3D.map_set_use_async_iterations(nav_map, false)
	NavigationServer3D.region_set_use_async_iterations(region.get_rid(), false)
	await get_tree().physics_frame
	await get_tree().process_frame
	NavigationServer3D.map_force_update(nav_map)
	assert_eq(
		instance.get_script().resource_path,
		LevelRootScript.resource_path,
		"Generated scene must use the canonical LevelRoot document script"
	)
	assert_eq(instance.name, "GeneratedMap")
	assert_true(instance.has_method("get_channel_system"))
	assert_true(instance.has_method("prepare_for_save"))
	var runtime_channel := instance.get_node_or_null("ChannelSystem")
	assert_not_null(runtime_channel, "LevelRoot must construct its runtime ChannelSystem")
	if runtime_channel:
		assert_true(runtime_channel.get_meta("editor_runtime_only", false))
		assert_eq(runtime_channel.owner, null, "Runtime-only channels must not be scene-owned")

	var player_spawn := instance.get_node("PlayerSpawn") as LevelSpawnPoint
	assert_not_null(player_spawn, "Generated player spawn must be a typed LevelSpawnPoint")
	if player_spawn == null:
		instance.free()
		return
	assert_eq(player_spawn.spawn_type, SpawnPointScript.SpawnType.PLAYER)
	var start := (player_spawn.global_position - Vector3.UP)
	for target in destinations:
		var path := NavigationServer3D.map_get_path(nav_map, start, target, true)
		assert_false(path.is_empty(), "Saved navigation supplies a route")
		if not path.is_empty():
			assert_lt(path[-1].distance_to(target), 1.0, "Route reaches the required room or spawn")
	var enemy_spawns: Array[LevelSpawnPoint] = []
	for child: Node in instance.get_children():
		if child is LevelSpawnPoint and child.spawn_type == SpawnPointScript.SpawnType.ENEMY:
			enemy_spawns.append(child)
	var monster_records: Array = metadata["gameplay"]["monsters"]
	assert_eq(enemy_spawns.size(), monster_records.size(), "Every generated record needs a typed enemy spawn")
	for index in range(enemy_spawns.size()):
		var enemy_spawn := enemy_spawns[index]
		var record: Dictionary = monster_records[index]
		assert_eq(enemy_spawn.get_meta("generation"), record, "Spawn retains its generation record")
		assert_eq(enemy_spawn.global_position, record["world_position"] + Vector3.UP)
		assert_eq(
			enemy_spawn.enemy_id,
			str(record.get("enemy_id", record.get("id", ""))),
			"Spawn retains its generated ID"
		)
	var saved_text_file := FileAccess.open("user://generated_roundtrip.tscn", FileAccess.READ)
	assert_not_null(saved_text_file)
	if saved_text_file:
		assert_false(
			saved_text_file.get_as_text().contains("ChannelSystem"),
			"Runtime-only ChannelSystem must not be serialized"
		)
		saved_text_file.close()
	var ray := PhysicsRayQueryParameters3D.create(start + Vector3.UP, start - Vector3.UP)
	var floor_hit := world.find_world_3d().direct_space_state.intersect_ray(ray)
	assert_false(floor_hit.is_empty(), "Packed collision supports the player spawn")
	instance.free()

	seed(999)
	for draw in range(100):
		randi()
	var second := await _generate("generator-correctness", config)
	if not second.has("scene"):
		return
	assert_eq(
		second["metadata"]["gameplay"], metadata["gameplay"], "Global RNG cannot alter gameplay"
	)
	var second_instance: Node = second["scene"].instantiate()
	var second_region := second_instance.get_node("NavigationRegion") as NavigationRegion3D
	assert_eq(
		second_region.navigation_mesh.get_vertices(), vertices, "Seeded navigable geometry repeats"
	)
	second_instance.free()


func test_cancelling_prepared_geometry_cannot_abort_replacement_generation() -> void:
	var config := GenerationConfig.new()
	config.map_size = Vector2i(64, 64)
	var state := {"cancelled": false, "completed": [], "failed": []}
	map_generator.generation_cancelled.connect(func() -> void: state["cancelled"] = true)
	map_generator.generation_completed.connect(
		func(_scene: PackedScene, metadata: Dictionary) -> void:
			state["completed"].append(metadata["seed"])
	)
	map_generator.generation_failed.connect(
		func(reason: String) -> void: state["failed"].append(reason)
	)
	map_generator.generation_progress.connect(
		func(phase: String, progress: float) -> void:
			if phase == "csg_geometry" and progress == 1.0 and not state["cancelled"]:
				map_generator.cancel_generation()
				map_generator.generate_map("generator-correctness", config)
	)
	map_generator.generate_map("cancelled-scene", config)
	var deadline := Time.get_ticks_msec() + 60000
	while map_generator.is_generating and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	assert_true(state["cancelled"])
	assert_eq(state["completed"], ["generator-correctness"], "Only the replacement may complete")
	assert_eq(state["failed"], [], "A cancelled continuation cannot abort the replacement")


func _generate(map_seed: String, config: GenerationConfig) -> Dictionary:
	var result := {}
	var completed := func(scene: PackedScene, metadata: Dictionary) -> void:
		result["scene"] = scene
		result["metadata"] = metadata
	var failed := func(reason: String) -> void: result["error"] = reason
	map_generator.generation_completed.connect(completed)
	map_generator.generation_failed.connect(failed)
	map_generator.generate_map(map_seed, config)
	var deadline := Time.get_ticks_msec() + 60000
	while result.is_empty() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	map_generator.generation_completed.disconnect(completed)
	map_generator.generation_failed.disconnect(failed)
	assert_true(result.has("scene"), "Generation must complete successfully: %s" % result)
	return result
