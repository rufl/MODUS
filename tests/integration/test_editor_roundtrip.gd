extends ModusGutTestBase

const LevelRootScript = preload("res://shared/editor_core/nodes/level_root.gd")
const SpawnPointScript = preload("res://shared/editor_core/nodes/spawn_point.gd")
const ActorBaseScript = preload("res://shared/editor_core/actors/actor_base.gd")
const SaveSystemScript = preload("res://shared/editor_core/data/level_save_system.gd")
const ModuleInstanceScript = preload("res://shared/editor_core/nodes/module_instance.gd")

const ROUNDTRIP_DIR := "user://editor_roundtrip_proof/"
const SAVE_PATH := ROUNDTRIP_DIR + "authored_level.tscn"
const EXPORT_DIR := ROUNDTRIP_DIR + "exported_mod/"


func test_editor_save_export_reload_preserves_key_actors() -> void:
	_cleanup_roundtrip_artifacts()
	DirAccess.make_dir_recursive_absolute(ROUNDTRIP_DIR)

	var authored_level := LevelRootScript.new()
	add_child_autofree(authored_level)
	authored_level.name = "RoundTripLevel"
	authored_level.level_name = "Round Trip Arena"
	authored_level.level_author = "MODUS Test Author"
	authored_level.level_tags = ["proof", "editor"]

	var player_spawn := SpawnPointScript.new()
	player_spawn.name = "PlayerSpawn"
	player_spawn.spawn_type = SpawnPointScript.SpawnType.PLAYER
	authored_level.add_child(player_spawn)
	player_spawn.owner = authored_level

	var enemy_spawn := SpawnPointScript.new()
	enemy_spawn.name = "EnemySpawn"
	enemy_spawn.spawn_type = SpawnPointScript.SpawnType.ENEMY
	enemy_spawn.enemy_id = "grunt_basic"
	authored_level.add_child(enemy_spawn)
	enemy_spawn.owner = authored_level

	var placed_actor := ActorBaseScript.new()
	placed_actor.name = "DoorTrigger"
	placed_actor.actor_id = "door_trigger"
	placed_actor.actor_category = "trigger"
	authored_level.add_child(placed_actor)
	placed_actor.owner = authored_level

	var save_system := SaveSystemScript.new()
	save_system.setup(authored_level)
	assert_true(save_system.save_level(SAVE_PATH, false), "Authored level should save")
	assert_true(FileAccess.file_exists(SAVE_PATH), "Saved scene should exist")

	var saved_scene := ResourceLoader.load(SAVE_PATH) as PackedScene
	assert_not_null(saved_scene, "Saved scene should reload as PackedScene")
	if not saved_scene:
		_cleanup_roundtrip_artifacts()
		return
	var reloaded_level := saved_scene.instantiate()
	assert_not_null(reloaded_level, "Saved scene should instantiate")
	assert_eq(reloaded_level.name, "RoundTripLevel")
	assert_eq(reloaded_level.get_node("PlayerSpawn").get_spawn_type(), "player")
	assert_eq(reloaded_level.get_node("EnemySpawn").enemy_id, "grunt_basic")
	assert_eq(reloaded_level.get_node("DoorTrigger").actor_id, "door_trigger")
	reloaded_level.free()

	assert_true(save_system.export_as_mod(EXPORT_DIR), "Level should export as a mod folder")
	var exported_level_path := EXPORT_DIR + "level.tscn"
	var exported_info_path := EXPORT_DIR + "level_info.json"
	assert_true(FileAccess.file_exists(exported_level_path), "Mod folder should contain level.tscn")
	assert_true(
		FileAccess.file_exists(exported_info_path), "Mod folder should contain level_info.json"
	)

	var exported_scene := ResourceLoader.load(exported_level_path) as PackedScene
	assert_not_null(exported_scene, "Exported scene should reload as PackedScene")
	if exported_scene:
		var exported_level := exported_scene.instantiate()
		assert_eq(exported_level.get_node("PlayerSpawn").get_spawn_type(), "player")
		assert_eq(exported_level.get_node("EnemySpawn").enemy_id, "grunt_basic")
		assert_eq(exported_level.get_node("DoorTrigger").actor_id, "door_trigger")
		exported_level.free()

	_cleanup_roundtrip_artifacts()


func test_module_channel_ids_and_execution_survive_root_relocation() -> void:
	var document := LevelRootScript.new()
	document.name = "Original"
	add_child_autofree(document)
	var pump := ModuleInstanceScript.new()
	pump.name = "PumpHall"
	pump.instance_id = "pump"
	document.add_child(pump)
	var control := ModuleInstanceScript.new()
	control.name = "ControlRoom"
	control.instance_id = "control"
	document.add_child(control)
	var source := ActorBaseScript.new()
	source.actor_id = "switch"
	pump.add_child(source)
	var target := ActorBaseScript.new()
	target.actor_id = "door"
	control.add_child(target)
	document.get_channel_system().create_connection(source, target, "power")
	document.prepare_for_save()
	assert_eq(document.channel_data.power.sources, ["pump/switch"])
	assert_eq(document.channel_data.power.targets, ["control/door"])
	var packed := PackedScene.new()
	assert_eq(packed.pack(document), OK)
	var restored: Node3D = packed.instantiate()
	restored.name = "Relocated"
	add_child_autofree(restored)
	var instigator := Node.new()
	add_child_autofree(instigator)
	var received: Array[Dictionary] = []
	restored.find_actor("control/door").activated.connect(
		func(data: Dictionary) -> void: received.append(data)
	)
	restored.find_actor("pump/switch").trigger(instigator, {"key": "maintenance"})
	assert_eq(restored.find_actor("control/door").activation_count, 1)
	assert_eq(received.size(), 1)
	assert_same(received[0].source, instigator, "Channels must preserve the interacting player")
	assert_eq(received[0].key, "maintenance")
	assert_eq(target.activation_count, 0, "Restored channels must not reach the author document")


func test_actor_checkpoint_restore_is_silent_and_cancels_pending_activation() -> void:
	var actor := ActorBaseScript.new()
	add_child_autofree(actor)
	actor.activation_delay = 0.5
	var events: Array[Dictionary] = []
	actor.activated.connect(func(data: Dictionary) -> void: events.append(data))
	actor.trigger(null, {"reward": "pending"})
	assert_true(
		actor.restore_runtime_state({"enabled": true, "is_active": true, "activation_count": 3})
	)
	actor._process(1.0)
	assert_eq(actor.activation_count, 3)
	assert_true(events.is_empty(), "Loading a checkpoint must not emit/replay actor activation")
	assert_false(
		actor.restore_runtime_state({"enabled": true, "is_active": false, "activation_count": -1})
	)
	assert_eq(actor.activation_count, 3)
	assert_true(actor.is_active, "Rejected state must leave the actor unchanged")


func test_delayed_activation_keeps_original_source_and_payload() -> void:
	var actor := ActorBaseScript.new()
	add_child_autofree(actor)
	var source := Node.new()
	add_child_autofree(source)
	actor.activation_delay = 0.5
	var events: Array[Dictionary] = []
	actor.activated.connect(func(data: Dictionary) -> void: events.append(data))
	actor.trigger(source, {"key": "maintenance"})
	actor._process(1.0)
	assert_eq(events.size(), 1)
	assert_same(events[0].source, source)
	assert_eq(events[0].key, "maintenance")


func _cleanup_roundtrip_artifacts() -> void:
	_remove_directory(ROUNDTRIP_DIR)


func _remove_directory(path: String) -> void:
	var dir := DirAccess.open(path)
	if not dir:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while not entry.is_empty():
		var entry_path := path.path_join(entry)
		if dir.current_is_dir():
			_remove_directory(entry_path)
		else:
			dir.remove(entry)
		entry = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(path)
