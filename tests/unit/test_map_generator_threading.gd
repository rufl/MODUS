extends ModusGutTestBase

const MapGeneratorScript: GDScript = preload("res://game/scripts/map_generator/map_generator.gd")
const LevelRootScript: GDScript = preload("res://shared/editor_core/nodes/level_root.gd")
const GenerationContextScript: GDScript = preload(
	"res://game/scripts/map_generator/generation_context.gd"
)
const CellScript: GDScript = preload("res://game/scripts/map_generator/cell.gd")
const SpawnPointScript: GDScript = preload("res://shared/editor_core/nodes/spawn_point.gd")
const EnemySpawnerScript: GDScript = preload(
	"res://shared/editor_core/actors/enemy_spawner_actor.gd"
)
const PickupSpawnerScript: GDScript = preload(
	"res://shared/editor_core/actors/pickup_spawner_actor.gd"
)
const KeyPickupActorScript: GDScript = preload(
	"res://shared/editor_core/actors/key_pickup_actor.gd"
)
const DoorActorScript: GDScript = preload("res://shared/editor_core/actors/door_actor.gd")
const SwitchActorScript: GDScript = preload("res://shared/editor_core/actors/switch_actor.gd")
const PlayerScene: PackedScene = preload("res://game/entities/player/player.tscn")
var _mission: MissionMgr
var _previous_mission: Dictionary
var _previous_mission_level: Node3D
var map_generator: Node


func before_each() -> void:
	map_generator = MapGeneratorScript.new()
	add_child_autofree(map_generator)
	_mission = MissionMgr.get_instance()
	if _mission:
		_previous_mission = _mission.capture_runtime_state()
		_previous_mission_level = _mission.mission_level


func after_each() -> void:
	if _mission and not _previous_mission.is_empty():
		_mission.restore_runtime_state(_previous_mission, _previous_mission_level)
	map_generator.cancel_generation()
	DirAccess.remove_absolute("user://generated_roundtrip.tscn")
	DirAccess.remove_absolute("user://generated_roundtrip.json")


func test_generated_boss_session_completes_after_lethal_defeat_and_extraction() -> void:
	assert_not_null(_mission, "Generated session requires the production MissionManager")
	if not _mission:
		return

	var context: GenerationContext = GenerationContextScript.new()
	var cell: Cell = CellScript.new(Cell.Type.ROOM)
	cell.room_id = 0
	context.grid = [[cell]]
	context.grid_size = Vector2i.ONE
	context.player_start_position = Vector2i.ZERO
	context.exit_position = Vector2i.ZERO
	context.monster_spawns = [
		{
			"id": "boss_0",
			"type": "boss",
			"enemy_id": "warlord",
			"tier": 4,
			"world_position": Vector3(4.0, 0.0, 4.0)
		}
	]
	map_generator.theme_manager.set_theme(GenerationConfig.ThemeType.TECH)
	map_generator.generation_context = context

	var gameplay_metadata: Dictionary = map_generator._build_gameplay_metadata()
	assert_eq(gameplay_metadata["monsters"], context.monster_spawns)
	assert_eq(
		gameplay_metadata["extraction"]["prerequisites"],
		["boss_0"],
		"Generated extraction metadata must require the generated boss"
	)
	var generated_scene: PackedScene = map_generator._build_map_scene(
		{"seed": "generated-boss-session", "gameplay": gameplay_metadata}
	)
	assert_not_null(generated_scene, "Generated boss session must pack")
	if not generated_scene:
		return

	var document := generated_scene.instantiate() as Node3D
	assert_not_null(document, "Generated boss session must instantiate")
	if not document:
		return
	document.set_meta("mission_id", "generated_boss_session")
	document.set_meta("document_runtime_session", true)
	add_child_autofree(document)

	var runtime_boss := document.get_node("EnemySpawner_0") as EnemySpawnerActor
	var runtime_extraction := document.get_node("GeneratedExtraction") as SwitchActor
	assert_not_null(runtime_boss, "Generated scene must contain its production boss spawner")
	assert_not_null(runtime_extraction, "Generated scene must contain its production extraction")
	if not runtime_boss or not runtime_extraction:
		return
	assert_eq(
		runtime_boss.position,
		Vector3(4.0, 1.0, 4.0),
		"Generated enemy actor must place its body origin one unit above ground metadata"
	)
	assert_eq(
		runtime_boss.get_meta("mission_objective"),
		{"description": "Defeat generated boss", "final": true, "order": 1000},
		"Boss objective must come from generated metadata"
	)
	assert_eq(
		runtime_extraction.get_meta("mission_objective"),
		{
			"description": "Reach the generated extraction",
			"final": true,
			"requires": ["boss_0"],
			"order": 2000
		}
	)

	var player := PlayerScene.instantiate() as Player
	assert_not_null(player, "Generated session must use the production player")
	if not player:
		return
	player.name = "GeneratedBossSessionPlayer"
	player.isolated_session = true
	add_child_autofree(player)
	await get_tree().process_frame
	document.runtime_player = player

	assert_true(_mission.start_document_mission(document))
	assert_eq(_mission.objective_state.get("boss_0", -1), 0)
	assert_eq(_mission.objective_state.get("generated_extraction", -1), 0)
	runtime_boss.start_runtime()
	runtime_extraction.start_runtime()
	await get_tree().process_frame

	var spawned_bosses: Dictionary = runtime_boss.get("_enemies")
	assert_eq(spawned_bosses.size(), 1, "Generated boss objective must spawn one boss")
	var spawned_boss := spawned_bosses.get(0) as Enemy
	assert_not_null(spawned_boss, "Generated boss objective must expose its production enemy")
	if not spawned_boss:
		return
	assert_eq(
		Vector2(spawned_boss.global_position.x, spawned_boss.global_position.z),
		Vector2(4.0, 4.0),
		"Generated boss must retain its authored horizontal spawn"
	)
	assert_gt(
		spawned_boss.global_position.y,
		0.5,
		"Generated boss must not start below the playable floor"
	)
	assert_false(
		runtime_extraction.interact(player),
		"Generated extraction must remain gated before lethal boss defeat"
	)
	assert_eq(_mission.objective_state.get("generated_extraction", -1), 0)

	var health := spawned_boss.get_node_or_null("HealthComponent") as HealthComponent
	assert_not_null(health, "Generated boss must expose production health")
	if not health:
		return
	spawned_boss.take_damage(DamageInfo.create(health.current_health, DamageInfo.DamageType.BULLET))
	await get_tree().process_frame
	await get_tree().process_frame
	_mission._process(0.0)
	assert_eq(_mission.objective_state.get("boss_0", -1), 1)
	assert_eq(_mission.objective_state.get("generated_extraction", -1), 0)
	assert_true(runtime_extraction.interact(player), "Extraction must activate after boss defeat")
	_mission._process(0.0)
	assert_eq(_mission.objective_state.get("generated_extraction", -1), 1)
	assert_eq(_mission.completed_mission_id, "generated_boss_session")


func test_small_seeded_generation_emits_level_root_and_objective_records() -> void:
	var config := GenerationConfig.new()
	config.map_size = Vector2i(32, 32)
	config.outdoor_bias = 0.0
	config.cave_bias = 0.0
	config.prefab_detail_level = 0.0
	config.prop_density = 0.0
	config.decorative_density = 0.0
	config.enable_lod = false
	config.enable_occlusion_culling = false
	config.use_multimesh = false
	config.monster_density = 0.0
	config.minimum_monsters = 0
	config.item_density = 0.0
	config.enable_secrets = false
	config.enable_key_locks = true
	config.enable_boss_arena = true

	var result := await _generate("focused-procedural-session", config)
	assert_true(result.has("scene"), "Production generation must emit a PackedScene")
	if not result.has("scene"):
		return
	var metadata: Dictionary = result["metadata"]
	var gameplay: Dictionary = metadata.get("gameplay", {})
	assert_eq(metadata.get("seed"), "focused-procedural-session")
	assert_eq(metadata.get("map_size"), [32, 32])
	assert_false(gameplay.get("keys", []).is_empty(), "Generation must emit key records")
	assert_false(
		gameplay.get("locked_doors", []).is_empty(), "Generation must emit locked-door records"
	)
	assert_false(gameplay.get("extraction", {}).is_empty(), "Generation must emit extraction data")

	var generated := result["scene"].instantiate() as Node3D
	assert_not_null(generated, "Generated output must instantiate")
	if not generated:
		return
	add_child_autofree(generated)
	assert_eq(
		generated.get_script().resource_path,
		LevelRootScript.resource_path,
		"Generated output must be a LevelRoot"
	)
	var key := generated.get_node_or_null("KeyPickup_0")
	assert_not_null(key, "Generated LevelRoot must contain the production key actor")
	if key:
		assert_eq(
			key.get_meta("mission_objective", {}).get("order", -1),
			0,
			"Generated key must expose an ordered mission objective"
		)
	var door := generated.get_node_or_null("LockedDoor_0")
	assert_not_null(door, "Generated LevelRoot must contain the production door actor")
	if door:
		assert_eq(
			door.get_meta("mission_objective", {}).get("requires", []),
			["KeyPickup_0"],
			"Generated door objective must require the generated key"
		)
	var extraction := generated.get_node_or_null("GeneratedExtraction")
	assert_not_null(extraction, "Generated LevelRoot must contain extraction actor")
	if extraction:
		assert_eq(
			extraction.get_meta("mission_objective", {}).get("final", false),
			true,
			"Extraction actor must expose a final mission objective"
		)


func test_generated_enemy_objectives_preserve_regular_and_boss_semantics() -> void:
	var regular: Dictionary = map_generator._generated_enemy_objective(
		{"type": "monster", "supported": true, "optional": true}, 2
	)
	assert_eq(regular.get("description"), "Defeat generated enemy")
	assert_eq(regular.get("order"), 102)
	assert_true(regular.get("optional", false))
	assert_false(regular.get("final", false), "Regular enemies must not be final objectives")

	var boss: Dictionary = map_generator._generated_enemy_objective({"type": "boss"}, 3)
	assert_eq(boss.get("description"), "Defeat generated boss")
	assert_eq(boss.get("order"), 1003)
	assert_true(boss.get("final", false), "Boss objectives remain final")

	var disabled: Dictionary = map_generator._generated_enemy_objective(
		{"type": "monster", "supported": true, "disabled": true}, 4
	)
	assert_true(disabled.is_empty(), "Disabled generated enemies must not create objectives")


func test_generated_high_value_reward_resolves_catalog_and_rarity() -> void:
	var item_config: Dictionary = map_generator._generated_item_config(
		{"type": "high_value", "item_tier": "rare", "secret_room_id": 4}
	)
	assert_true(item_config.get("supported", false))
	assert_eq(item_config.get("category"), PickupSpawnerActor.PickupCategory.POWERUP)
	assert_eq(item_config.get("item_id"), "damage_powerup")
	assert_eq(item_config.get("rarity_tier"), 2)

	var unknown: Dictionary = map_generator._generated_item_config({"type": "unknown"})
	assert_false(unknown.get("supported", true), "Unknown records remain unsupported")


func test_generated_high_value_reward_spawns_runtime_damage_powerup() -> void:
	var record := {
		"id": "secret_reward_4",
		"position": Vector3(9.0, 0.0, 11.0),
		"world_position": Vector3(9.0, 0.0, 11.0),
		"type": "high_value",
		"item_tier": "rare",
		"secret_room_id": 4
	}
	var item_config: Dictionary = map_generator._generated_item_config(record)
	assert_true(item_config.get("supported", false))

	# Build through MapGenerator's production scene path so item configuration
	# and secret objective metadata come from the generated actor construction.
	map_generator.theme_manager.set_theme(GenerationConfig.ThemeType.TECH)
	var context: GenerationContext = GenerationContextScript.new()
	var cell: Cell = CellScript.new(Cell.Type.ROOM)
	context.grid = [[cell]]
	context.grid_size = Vector2i.ONE
	context.player_start_position = Vector2i.ZERO
	context.item_spawns = [record]
	map_generator.generation_context = context
	var generated_scene: PackedScene = map_generator._build_map_scene(
		{"seed": "high-value-runtime", "gameplay": {"items": [record]}}
	)
	assert_not_null(generated_scene, "Generated high-value scene must pack successfully")
	if not generated_scene:
		return

	var generated := generated_scene.instantiate() as Node3D
	assert_not_null(generated, "Generated high-value scene must instantiate")
	if not generated:
		return
	add_child_autofree(generated)
	await get_tree().process_frame

	var pickup_actor := generated.get_node_or_null("PickupSpawner_0") as PickupSpawnerActor
	assert_not_null(pickup_actor, "Generated scene must contain a production pickup spawner")
	if not pickup_actor:
		return
	assert_eq(pickup_actor.pickup_category, PickupSpawnerActor.PickupCategory.POWERUP)
	assert_eq(pickup_actor.item_id, "damage_powerup")
	assert_eq(pickup_actor.rarity_tier, 2)
	assert_eq(pickup_actor.get_meta("rarity_tier"), 2)
	var spawned := pickup_actor.get("_current_pickup") as PickupBase
	assert_not_null(spawned, "Generated high-value actor must spawn a real PickupBase")
	if not spawned:
		return
	assert_true(spawned is DamagePowerup, "High-value rewards resolve to damage_powerup")
	assert_eq(spawned.rarity_tier, 2, "Spawned reward must retain rare tier 2")
	assert_eq(
		pickup_actor.get_meta("mission_objective"),
		{
			"description": "Discover generated secret reward",
			"secret_room_id": 4,
			"optional": true,
			"order": 9000
		},
		"Generated secret reward must expose optional objective metadata"
	)


func test_bounded_seeded_monster_generation_exposes_regular_objectives() -> void:
	var config := GenerationConfig.new()
	config.map_size = Vector2i(64, 64)
	config.outdoor_bias = 0.0
	config.cave_bias = 0.0
	config.prefab_detail_level = 0.0
	config.prop_density = 0.0
	config.decorative_density = 0.0
	config.enable_lod = false
	config.enable_occlusion_culling = false
	config.use_multimesh = false
	# 64x64 at 0.05 density yields exactly two monsters; the floor keeps the
	# nonzero contract explicit without allowing an unbounded encounter.
	config.monster_density = 0.05
	config.minimum_monsters = 2
	config.item_density = 0.0
	config.enable_secrets = false
	config.enable_key_locks = false
	# MapGenerator's production path does not guarantee that a boss marker is
	# inserted for a bounded generation. This case intentionally covers regular
	# combat only; the dedicated semantic test above covers boss objectives.
	config.enable_boss_arena = false

	var result := await _generate("bounded-monster-objectives", config)
	assert_true(result.has("scene"), "Production generation must complete")
	if not result.has("scene"):
		return
	var records: Array = result["metadata"].get("gameplay", {}).get("monsters", [])
	assert_eq(records.size(), 2, "Bounded configuration must emit two monster records")
	for record: Dictionary in records:
		assert_eq(record.get("type"), "monster")

	var generated := result["scene"].instantiate() as Node3D
	assert_not_null(generated, "Generated output must instantiate")
	if not generated:
		return
	add_child_autofree(generated)

	var enemy_actors: Array[EnemySpawnerActor] = []
	for child: Node in generated.get_children():
		if child is EnemySpawnerActor:
			enemy_actors.append(child)
	assert_eq(enemy_actors.size(), records.size(), "Every generated record needs an enemy actor")
	for index in range(records.size()):
		var record: Dictionary = records[index]
		var actor := enemy_actors[index]
		assert_eq(actor.get_meta("generation"), record)
		assert_eq(
			actor.get_meta("mission_objective"),
			map_generator._generated_enemy_objective(record, index),
			"Generated regular enemies expose their production mission objective"
		)
		assert_false(actor.get_meta("mission_objective").get("final", false))

	# With boss arenas disabled, this bounded production run must remain regular
	# combat only. Boss records, when generated by a future arena path, retain
	# final objective semantics through _generated_enemy_objective (tested above).
	assert_true(
		(
			records
			. filter(func(record: Dictionary) -> bool: return record.get("type") == "boss")
			. is_empty()
		),
		"Regular-only bounded configuration must not synthesize a boss"
	)


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
	var start := player_spawn.global_position - Vector3.UP
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
	assert_eq(
		enemy_actors.size(), monster_records.size(), "Every monster record needs an enemy actor"
	)
	var supported_item_records: Array = []
	for record: Dictionary in item_records:
		if (
			str(record.get("type", ""))
			in ["weapon", "ammo", "health", "armor", "powerup", "high_value"]
		):
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
		assert_eq(actor.global_position, record["world_position"] + Vector3.UP)
		assert_eq(actor.enemy_id, actor_enemy_id)
		assert_true(actor.auto_spawn)
		if record.get("type", "") == "boss":
			assert_eq(
				actor.get_meta("mission_objective"),
				{"description": "Defeat generated boss", "final": true, "order": 1000 + index},
				"Generated bosses link to the supported mission objective runtime"
			)
	var item_index := 0
	for item_record_index in range(item_records.size()):
		var record: Dictionary = item_records[item_record_index]
		var item_type := str(record.get("type", ""))
		if item_type not in ["weapon", "ammo", "health", "armor", "powerup", "high_value"]:
			assert_eq(
				record.get("id", ""),
				"secret_reward_%d" % int(record.get("secret_room_id", -1)),
				"Unsupported secret rewards retain a stable generated record"
			)
			continue
		var item_id := str(record.get("item_id", ""))
		var category := PickupSpawnerActor.PickupCategory.HEALTH
		var weapon_id := str(record.get("weapon_id", ""))
		var expected_rarity_tier := int(
			map_generator._generated_item_config(record).get("rarity_tier", -1)
		)
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
			"high_value":
				category = PickupSpawnerActor.PickupCategory.POWERUP
				item_id = "damage_powerup"
				expected_rarity_tier = 2
		var actor := item_actors[item_index]
		item_index += 1
		assert_eq(actor.name, "PickupSpawner_%d" % item_record_index, "Item actor names are stable")
		assert_eq(actor.actor_id, record.get("id"))
		assert_eq(actor.get_meta("generation"), record)
		assert_eq(actor.global_position, record.get("world_position", record.get("position")))
		assert_eq(actor.item_id, item_id)
		assert_eq(actor.pickup_category, category)
		assert_eq(actor.weapon_id, weapon_id)
		assert_eq(actor.rarity_tier, expected_rarity_tier)
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
			{"description": "Collect generated %s key" % color.to_lower(), "order": index * 2}
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
