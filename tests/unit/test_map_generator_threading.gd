extends ModusGutTestBase

const MapGeneratorScript: GDScript = preload("res://game/scripts/map_generator/map_generator.gd")
const LevelRootScript: GDScript = preload("res://shared/editor_core/nodes/level_root.gd")
const SpawnPointScript: GDScript = preload("res://shared/editor_core/nodes/spawn_point.gd")
const EnemySpawnerScript: GDScript = preload("res://shared/editor_core/actors/enemy_spawner_actor.gd")
const PickupSpawnerScript: GDScript = preload("res://shared/editor_core/actors/pickup_spawner_actor.gd")
const KeyPickupActorScript: GDScript = preload("res://shared/editor_core/actors/key_pickup_actor.gd")
const DoorActorScript: GDScript = preload("res://shared/editor_core/actors/door_actor.gd")
const SwitchActorScript: GDScript = preload("res://shared/editor_core/actors/switch_actor.gd")
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
	var enemy_actors: Array[EnemySpawnerActor] = []
	var item_actors: Array[PickupSpawnerActor] = []
	for child: Node in instance.get_children():
		if child is LevelSpawnPoint and child.spawn_type == SpawnPointScript.SpawnType.ENEMY:
			enemy_spawns.append(child)
		elif child is EnemySpawnerActor:
			enemy_actors.append(child)
		elif child is PickupSpawnerActor:
			item_actors.append(child)
	var monster_records: Array = metadata["gameplay"]["monsters"]
	var item_records: Array = metadata["gameplay"]["items"]
	assert_eq(enemy_spawns.size(), monster_records.size(), "Typed enemy markers remain available")
	assert_eq(enemy_actors.size(), monster_records.size(), "Every monster record needs an enemy actor")
	var supported_item_records: Array = []
	for record: Dictionary in item_records:
		if str(record.get("type", "")) in ["weapon", "ammo", "health", "armor", "powerup"]:
			supported_item_records.append(record)
	assert_eq(
		item_actors.size(),
		supported_item_records.size(),
		"Only catalog-backed item records need pickup actors"
	)
	for index in range(monster_records.size()):
		var record: Dictionary = monster_records[index]
		var marker_enemy_id := str(record.get("enemy_id", ""))
		var actor_enemy_id := marker_enemy_id
		if actor_enemy_id.is_empty():
			actor_enemy_id = "warlord" if record.get("type", "") == "boss" else "grunt_basic"
		assert_eq(enemy_spawns[index].get_meta("generation"), record)
		assert_eq(enemy_spawns[index].global_position, record["world_position"] + Vector3.UP)
		assert_eq(enemy_spawns[index].enemy_id, marker_enemy_id)
		var actor := enemy_actors[index]
		assert_eq(actor.name, "EnemySpawner_%d" % index, "Enemy actor names are stable")
		assert_eq(actor.actor_id, record.get("id"))
		assert_eq(actor.get_meta("generation"), record)
		assert_eq(actor.global_position, record["world_position"])
		assert_eq(actor.enemy_id, actor_enemy_id)
		assert_true(actor.auto_spawn)
		if record.get("type", "") == "boss":
			assert_eq(
				actor.get_meta("mission_objective"),
				{
					"description": "Defeat generated boss",
					"final": true,
					"order": 1000 + index
				},
				"Generated bosses link to the supported mission objective runtime"
			)
	var item_index := 0
	for item_record_index in range(item_records.size()):
		var record: Dictionary = item_records[item_record_index]
		var item_type := str(record.get("type", ""))
		if item_type not in ["weapon", "ammo", "health", "armor", "powerup"]:
			assert_eq(
				record.get("id", ""),
				"secret_reward_%d" % int(record.get("secret_room_id", -1)),
				"Unsupported secret rewards retain a stable generated record"
			)
			continue
		var item_id := str(record.get("item_id", ""))
		var category := PickupSpawnerActor.PickupCategory.HEALTH
		var weapon_id := str(record.get("weapon_id", ""))
		match item_type:
			"weapon":
				category = PickupSpawnerActor.PickupCategory.WEAPON
				weapon_id = weapon_id if not weapon_id.is_empty() else "shotgun"
				item_id = item_id if not item_id.is_empty() else "weapon_" + weapon_id
			"ammo":
				category = PickupSpawnerActor.PickupCategory.AMMO
				item_id = item_id if not item_id.is_empty() else "ammo_clip"
			"health":
				item_id = item_id if not item_id.is_empty() else "health_potion"
			"armor":
				category = PickupSpawnerActor.PickupCategory.ARMOR
				item_id = item_id if not item_id.is_empty() else "armor_pickup"
			"powerup":
				category = PickupSpawnerActor.PickupCategory.POWERUP
				item_id = item_id if not item_id.is_empty() else "speed_powerup"
		var actor := item_actors[item_index]
		item_index += 1
		assert_eq(
			actor.name,
			"PickupSpawner_%d" % item_record_index,
			"Item actor names are stable"
		)
		assert_eq(actor.actor_id, record.get("id"))
		assert_eq(actor.get_meta("generation"), record)
		assert_eq(actor.global_position, record.get("world_position", record.get("position")))
		assert_eq(actor.item_id, item_id)
		assert_eq(actor.pickup_category, category)
		assert_eq(actor.weapon_id, weapon_id)
		assert_true(actor.auto_spawn)
	var key_actors: Array[KeyPickupActor] = []
	var door_actors: Array[DoorActor] = []
	for child: Node in instance.get_children():
		if child is KeyPickupActor:
			key_actors.append(child)
		elif child is DoorActor:
			door_actors.append(child)
	var key_records: Array = metadata["gameplay"]["keys"]
	var door_records: Array = metadata["gameplay"]["locked_doors"]
	assert_eq(key_actors.size(), key_records.size(), "Every key record needs a key actor")
	assert_eq(door_actors.size(), door_records.size(), "Every locked door needs a door actor")
	for index in range(key_records.size()):
		var record: Dictionary = key_records[index]
		var color := str(record.get("color", "UNKNOWN"))
		var actor := key_actors[index]
		assert_eq(actor.name, "KeyPickup_%d" % index, "Key actor names are stable")
		assert_eq(actor.actor_id, actor.name)
		assert_eq(actor.key_id, "key_" + color.to_lower())
		assert_eq(actor.global_position, record["position"])
		assert_eq(actor.get_meta("generation"), record)
		assert_eq(actor.get_meta("key_color"), color)
		assert_eq(
			actor.get_meta("mission_objective"),
			{
				"description": "Collect generated %s key" % color.to_lower(),
				"order": index * 2
			}
		)
	for index in range(door_records.size()):
		var record: Dictionary = door_records[index]
		var color := str(record.get("color", "UNKNOWN"))
		var actor := door_actors[index]
		assert_eq(actor.name, "LockedDoor_%d" % index, "Locked door names are stable")
		assert_eq(actor.actor_id, actor.name)
		assert_true(actor.locked)
		assert_eq(actor.required_key, "key_" + color.to_lower())
		assert_eq(actor.global_position, record["position"])
		assert_eq(actor.get_meta("generation"), record)
		assert_eq(actor.get_meta("key_color"), color)
		assert_eq(
			actor.get_meta("mission_objective"),
			{
				"description": "Open generated %s door" % color.to_lower(),
				"requires": ["KeyPickup_%d" % index],
				"order": index * 2 + 1
			}
		)
	var extraction_record: Dictionary = metadata["gameplay"].get("extraction", {})
	assert_false(extraction_record.is_empty(), "Generated maps expose a valid extraction record")
	var extraction := instance.get_node_or_null("GeneratedExtraction") as SwitchActor
	assert_not_null(extraction, "Generated extraction uses the canonical switch actor")
	if extraction:
		assert_eq(extraction.actor_id, "generated_extraction")
		assert_eq(extraction.global_position, extraction_record["position"])
		assert_eq(extraction.get_meta("generation"), extraction_record)
		assert_eq(
			extraction.get_meta("mission_objective"),
			{
				"description": "Reach the generated extraction",
				"final": true,
				"requires": extraction_record["prerequisites"],
				"order": 2000
			}
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
