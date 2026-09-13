class_name LevelPlaySession
extends Node3D

signal session_finished

const PLAYER_SCENE := preload("res://game/entities/player/player.tscn")
const ModuleAssemblyScript := preload("res://shared/editor_core/core/module_assembly.gd")

var document: Node3D
var player: Player
var navigation_region: NavigationRegion3D
var error_message: String = ""
var is_editor_preview: bool = false
var _mission: MissionMgr
var _previous_mission: Dictionary = {}
var _previous_mission_level: Node3D
var _previous_game_state: int
var _previous_mouse_mode: Input.MouseMode
var _document_signature: String
var _status: Label
var _notice: String = ""
var _started: bool = false


func start_document(source: Node3D) -> bool:
	if _started or not is_inside_tree() or not source or not source.has_method("prepare_for_save"):
		return _fail("A tree-attached level session requires an authored level document.")
	if (
		multiplayer.has_multiplayer_peer()
		and not multiplayer.multiplayer_peer is OfflineMultiplayerPeer
	):
		return _fail(
			"Document play sessions are offline; disconnect multiplayer before playtesting."
		)
	source.prepare_for_save()
	var channel_errors: Array[String] = source.get_channel_system().validate_data(
		source.channel_data
	)
	if not channel_errors.is_empty():
		return _fail("\n".join(channel_errors))
	var validation: Dictionary = ModuleAssemblyScript.validate_level(source)
	if not validation.valid:
		return _fail("\n".join(PackedStringArray(validation.errors)))
	var packed := PackedScene.new()
	var previous_mode := source.process_mode
	source.process_mode = Node.PROCESS_MODE_INHERIT
	var result := packed.pack(source)
	source.process_mode = previous_mode
	if result != OK:
		return _fail("Unable to clone document: " + error_string(result))
	document = packed.instantiate() as Node3D
	if not document:
		return _fail("Document has no spatial root.")
	document.authoring_mode = false
	document.process_mode = Node.PROCESS_MODE_INHERIT
	add_child(document)
	document.restore_runtime_bindings()
	var spawns: Array[Node3D] = document.get_spawn_points("player")
	if spawns.is_empty():
		return _fail("Place a player spawn before starting the level.")
	_mission = MissionMgr.get_instance()
	if not _mission:
		return _fail("The gameplay mission service is unavailable.")
	_previous_mission = _mission.capture_runtime_state()
	_previous_mission_level = _mission.mission_level
	_previous_game_state = GameManager.get_state()
	_previous_mouse_mode = Input.mouse_mode
	is_editor_preview = get_viewport() is SubViewport
	_started = true
	player = PLAYER_SCENE.instantiate() as Player
	player.name = "1"
	player.isolated_session = is_editor_preview
	player.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(player)
	player.global_transform = spawns[0].global_transform
	player.spawns = PackedVector3Array([player.global_position])

	var context := GenerationContext.new()
	var baker := NavigationMeshBaker.new()
	baker.initialize(context)
	baker.get_navigation_mesh().agent_max_slope = rad_to_deg(player.floor_max_angle)
	if not baker.bake_navigation_mesh(document):
		baker.initialize(null)
		return _fail("The authored collision produced no walkable navigation mesh.")
	navigation_region = baker.get_navigation_region()
	add_child(navigation_region)
	var navigation_map := get_world_3d().navigation_map
	NavigationServer3D.map_set_use_async_iterations(navigation_map, false)
	NavigationServer3D.region_set_use_async_iterations(navigation_region.get_rid(), false)
	NavigationServer3D.map_force_update(navigation_map)
	_document_signature = _make_document_signature()
	_create_status()
	_mission.objective_updated.connect(_on_objective_updated)
	_mission.mission_completed.connect(_on_mission_completed)
	if not _mission.start_document_mission(document):
		return _fail("The document contains an invalid objective declaration.")
	add_to_group("level_play_session")
	await get_tree().physics_frame
	player.process_mode = Node.PROCESS_MODE_INHERIT
	GameManager.change_state(GameManager.State.RUNNING)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_refresh_status()
	return true


func _fail(message: String) -> bool:
	error_message = message
	stop()
	return false


func stop() -> void:
	if is_instance_valid(_mission):
		if _mission.objective_updated.is_connected(_on_objective_updated):
			_mission.objective_updated.disconnect(_on_objective_updated)
		if _mission.mission_completed.is_connected(_on_mission_completed):
			_mission.mission_completed.disconnect(_on_mission_completed)
		if _started:
			var previous_level := (
				_previous_mission_level if is_instance_valid(_previous_mission_level) else null
			)
			_mission.restore_runtime_state(_previous_mission, previous_level)
	if _started:
		GameManager.change_state(_previous_game_state)
		Input.mouse_mode = _previous_mouse_mode
	_started = false
	remove_from_group("level_play_session")
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	document = null
	player = null
	navigation_region = null
	_status = null


func _exit_tree() -> void:
	stop()


func _input(event: InputEvent) -> void:
	if not _started or not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_ESCAPE and is_editor_preview:
		get_viewport().set_input_as_handled()
		session_finished.emit()
	elif event.keycode == KEY_F5 or event.keycode == KEY_F9:
		get_viewport().set_input_as_handled()
		var state_manager := GameManager.get_core_system("gameplay").get_node_or_null(
			"GameStateManager"
		)
		if not state_manager:
			_notice = "Checkpoint service unavailable"
		elif event.keycode == KEY_F5:
			_notice = (
				"Checkpoint saved"
				if state_manager.save_game("document_checkpoint")
				else "Checkpoint save failed"
			)
		else:
			_notice = (
				"Checkpoint restored"
				if await state_manager.load_game("document_checkpoint")
				else "Checkpoint load failed"
			)
		_refresh_status()


func _make_document_signature() -> String:
	var modules: Array = []
	for module: Node3D in ModuleAssemblyScript.get_instances(document):
		var definition: Resource = module.definition
		modules.append(
			{
				"instance": module.instance_id,
				"module": definition.module_id,
				"revision": definition.content_revision,
				"transform": var_to_str(module.transform)
			}
		)
	var hash_context := HashingContext.new()
	hash_context.start(HashingContext.HASH_SHA256)
	hash_context.update(
		(
			JSON
			. stringify(
				{
					"modules": modules,
					"connections": document.module_connections,
					"channels": document.channel_data
				}
			)
			. to_utf8_buffer()
		)
	)
	_hash_authored_node(document, hash_context)
	return hash_context.finish().hex_encode()


func _hash_authored_node(node: Node, hash_context: HashingContext) -> void:
	if node.get_meta("editor_runtime_only", false):
		return
	hash_context.update(
		var_to_bytes(
			[
				str(document.get_path_to(node)),
				node.get_class(),
				node.transform if node is Node3D else Transform3D.IDENTITY
			]
		)
	)
	for property: Dictionary in node.get_property_list():
		var usage: int = property.get("usage", 0)
		if not (usage & PROPERTY_USAGE_STORAGE and usage & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		var value: Variant = node.get(property.name)
		if not value is Object:
			hash_context.update(var_to_bytes([property.name, value]))
	if node is CollisionShape3D and node.shape:
		hash_context.update(node.shape.get_class().to_utf8_buffer())
		for property: Dictionary in node.shape.get_property_list():
			if not (int(property.get("usage", 0)) & PROPERTY_USAGE_STORAGE):
				continue
			var value: Variant = node.shape.get(property.name)
			if not value is Object:
				hash_context.update(var_to_bytes([property.name, value]))
	for child: Node in node.get_children():
		_hash_authored_node(child, hash_context)


func capture_runtime_state() -> Dictionary:
	var actors: Dictionary = {}
	for actor: Node in document.find_children("*", "", true, false):
		if actor is ActorBase:
			actors[document.get_actor_identity(actor)] = actor.capture_runtime_state()
	return {
		"version": 1,
		"document": _document_signature,
		"actors": actors,
		"mission": _mission.capture_runtime_state()
	}


func validate_runtime_state(state: Variant) -> bool:
	if (
		not state is Dictionary
		or state.get("version") != 1
		or state.get("document") != _document_signature
	):
		return false
	var current := capture_runtime_state()
	var actors: Variant = state.get("actors")
	var mission: Variant = state.get("mission")
	if (
		not actors is Dictionary
		or actors.size() != current.actors.size()
		or not mission is Dictionary
	):
		return false
	for identity: String in current.actors:
		if not actors.get(identity) is Dictionary:
			return false
		var expected: Dictionary = current.actors[identity]
		var saved: Dictionary = actors[identity]
		if expected.size() != saved.size():
			return false
		for field: String in expected:
			if expected[field] is int:
				if not _is_integer(saved.get(field)):
					return false
			elif typeof(saved.get(field)) != typeof(expected[field]):
				return false
		if saved.activation_count < 0:
			return false
	if not _same_json_value(mission.get("definition"), current.mission.definition):
		return false
	if not mission.get("active_id") is String or not mission.get("completed_id") is String:
		return false
	var mission_id: String = str(document.get_meta("mission_id", "document_mission"))
	if not (
		(mission.active_id == mission_id and mission.completed_id == "")
		or (mission.active_id == "" and mission.completed_id == mission_id)
	):
		return false
	if (
		not _same_json_value(mission.get("totals"), current.mission.totals)
		or not mission.get("state") is Dictionary
	):
		return false
	if mission.state.size() != current.mission.state.size():
		return false
	for identity: String in current.mission.state:
		var count: Variant = mission.state.get(identity)
		if not _is_integer(count) or count < 0 or count > int(mission.totals[identity]):
			return false
	return true


func restore_runtime_state(state: Dictionary) -> bool:
	if not validate_runtime_state(state):
		return false
	for identity: String in state.actors:
		var actor: Node = document.find_actor(identity)
		var actor_state: Dictionary = state.actors[identity].duplicate()
		actor_state.activation_count = int(actor_state.activation_count)
		if not actor.restore_runtime_state(actor_state):
			return false
	_mission.restore_runtime_state(state.mission, document)
	_refresh_status()
	return true


func _is_integer(value: Variant) -> bool:
	return value is int or (value is float and is_finite(value) and value == floor(value))


## JSON numbers are floats; compare their values without weakening container or boolean types.
func _same_json_value(saved: Variant, expected: Variant) -> bool:
	if expected is int or expected is float:
		return (saved is int or saved is float) and is_finite(saved) and saved == expected
	if typeof(saved) != typeof(expected):
		return false
	if expected is Dictionary:
		if saved.size() != expected.size():
			return false
		for key: Variant in expected:
			if not saved.has(key) or not _same_json_value(saved[key], expected[key]):
				return false
		return true
	if expected is Array:
		if saved.size() != expected.size():
			return false
		for index in expected.size():
			if not _same_json_value(saved[index], expected[index]):
				return false
		return true
	return saved == expected


func _create_status() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	_status = Label.new()
	_status.position = Vector2(28, 24)
	_status.add_theme_font_size_override("font_size", 21)
	_status.add_theme_color_override("font_color", Color(0.85, 0.95, 0.93))
	_status.add_theme_color_override("font_shadow_color", Color(0.01, 0.025, 0.03))
	_status.add_theme_constant_override("shadow_offset_x", 2)
	_status.add_theme_constant_override("shadow_offset_y", 2)
	layer.add_child(_status)


func _on_objective_updated(
	_mission_id: String, _objective: String, _current: int, _required: int
) -> void:
	_refresh_status()


func _on_mission_completed(_mission_id: String) -> void:
	_refresh_status()


func _refresh_status() -> void:
	if not is_instance_valid(_status):
		return
	var lines: PackedStringArray = [str(document.level_name)]
	for objective: Dictionary in _mission.active_mission_data.get("objectives", []):
		var complete: bool = (
			int(_mission.objective_state.get(objective.id, 0))
			>= int(_mission.objective_totals.get(objective.id, 1))
		)
		lines.append(("[done] " if complete else "[  ] ") + str(objective.description))
	if not _mission.completed_mission_id.is_empty():
		lines.append("MISSION COMPLETE")
	lines.append("E: interact   F5: save checkpoint   F9: load checkpoint")
	if is_editor_preview:
		lines.append("Esc: return to unchanged editor document")
	if not _notice.is_empty():
		lines.append(_notice)
	_status.text = "\n".join(lines)
