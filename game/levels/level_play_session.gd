class_name LevelPlaySession
extends Node3D

signal session_finished
signal destination_changed(destination_id: String)

const PLAYER_SCENE := preload("res://game/entities/player/player.tscn")
const ModuleAssemblyScript := preload("res://shared/editor_core/core/module_assembly.gd")
const MAX_DESTINATIONS := 64

var document: Node3D
var player: Player
var navigation_region: NavigationRegion3D
var error_message: String = ""
var is_editor_preview: bool = false
var current_destination_id: String = ""
var current_spawn_id: String = ""
var destinations: Dictionary = {}
var travel_network: LevelTravelNetwork
var _mission: MissionMgr
var _previous_mission: Dictionary = {}
var _previous_mission_level: Node3D
var _previous_game_state: int
var _previous_mouse_mode: Input.MouseMode
var _document_signature: String
var _baseline_mission: Dictionary = {}
var _status: Label
var _notice: String = ""
var _started: bool = false
var _initialized: bool = false
var _frozen: bool = false
var _travel_busy: bool = false
var _exiting: bool = false
var _sources: Dictionary = {}
var _visits: Dictionary = {}
var _stage: LevelDestination
var _staged_players: Array = []
var _pending_campaign: Dictionary = {}


func _ready() -> void:
	travel_network = LevelTravelNetwork.new()
	travel_network.name = "TravelNetwork"
	travel_network.session = self
	add_child(travel_network)


func _initialize_session() -> bool:
	if _initialized:
		return true
	_mission = MissionMgr.get_instance()
	if not _mission:
		error_message = "The gameplay mission service is unavailable."
		return false
	_previous_mission = _mission.capture_runtime_state()
	_previous_mission_level = _mission.mission_level
	_previous_game_state = GameManager.get_state()
	_previous_mouse_mode = Input.mouse_mode
	is_editor_preview = get_viewport() is SubViewport
	_mission.objective_updated.connect(_on_objective_updated)
	_mission.mission_completed.connect(_on_mission_completed)
	_initialized = true
	return true


func register_destination(identity: String, path: String) -> bool:
	if identity.is_empty() or identity.length() > 256 or destinations.size() >= MAX_DESTINATIONS:
		return false
	if not (path.begins_with("res://") or path.begins_with("user://")) or ".." in path:
		return false
	if path.get_extension() != "tscn" or not ResourceLoader.exists(path, "PackedScene"):
		return false
	if destinations.has(identity):
		return destinations[identity].path == path
	destinations[identity] = {"id": identity, "path": path}
	return true


func start_document(source: Node3D) -> bool:
	if _started or not is_inside_tree() or not source or not source.has_method("prepare_for_save"):
		return _fail("A tree-attached level session requires an authored level document.")
	if not _initialize_session():
		return false
	if is_editor_preview and _is_networked():
		return _fail("Editor playtests require an offline session.")
	source.prepare_for_save()
	var packed := PackedScene.new()
	var previous_mode := source.process_mode
	source.process_mode = Node.PROCESS_MODE_INHERIT
	var result := packed.pack(source)
	source.process_mode = previous_mode
	if result != OK:
		return _fail("Unable to clone document: " + error_string(result))
	var identity := str(
		source.get_meta("destination_id", source.get_meta("mission_id", "document"))
	)
	_sources[identity] = packed
	destinations[identity] = {"id": identity, "path": source.scene_file_path}
	if _is_networked() and not multiplayer.is_server():
		travel_network.request_join()
		return true
	return await travel_to(identity)


func _is_networked() -> bool:
	return (
		multiplayer.has_multiplayer_peer()
		and not multiplayer.multiplayer_peer is OfflineMultiplayerPeer
	)


func is_travel_pending() -> bool:
	return _travel_busy or (travel_network != null and travel_network.pending)


func travel_to(identity: String, spawn_id: String = "") -> bool:
	if is_travel_pending() or (_is_networked() and not multiplayer.is_server()):
		return false
	if not destinations.has(identity) or not _initialize_session():
		error_message = "Unknown destination: " + identity
		return false
	_travel_busy = true
	error_message = ""
	set_travel_frozen(true)
	var saved: Dictionary = _visits.get(identity, {})
	var descriptor: Dictionary = destinations[identity]
	if identity == current_destination_id:
		saved = capture_runtime_state()
	var offer := {
		"descriptor": descriptor,
		"spawn_id": spawn_id,
		"runtime": saved,
		"players": capture_player_roster()
	}
	var prepared := stage_travel_offer(offer)
	if not prepared.success:
		error_message = prepared.error
		_notice = error_message
		_refresh_status()
		_travel_busy = false
		set_travel_frozen(false)
		return false
	# Arrival moves the existing players, never restores their older destination inventory.
	for record: Dictionary in _staged_players:
		record.position = [
			_stage.spawn_transform.origin.x,
			_stage.spawn_transform.origin.y,
			_stage.spawn_transform.origin.z
		]
		var rotation := _stage.spawn_transform.basis.get_euler()
		record.rotation = [rotation.x, rotation.y, rotation.z]
	offer = {
		"descriptor": _stage.descriptor,
		"spawn_id": _stage.spawn_id,
		"runtime": _stage.runtime,
		"players": _staged_players
	}
	var success := await travel_network.synchronize_travel(offer)
	_travel_busy = false
	set_travel_frozen(false)
	if not success:
		error_message = travel_network.last_error
	_notice = error_message
	_refresh_status()
	return success


func stage_travel_offer(offer: Dictionary) -> Dictionary:
	abort_staged_travel()
	if not _initialize_session():
		return {"success": false, "error": error_message, "missing": [], "fallback": []}
	if (
		not offer.get("descriptor") is Dictionary
		or not offer.get("spawn_id") is String
		or not offer.get("runtime") is Dictionary
	):
		return {
			"success": false, "error": "Malformed destination offer.", "missing": [], "fallback": []
		}
	var identity: Dictionary = offer.descriptor
	if not identity.get("id") is String or not identity.get("path") is String:
		return {
			"success": false,
			"error": "Malformed destination identity.",
			"missing": [],
			"fallback": []
		}
	if not destinations.has(identity.id) or destinations[identity.id].path != identity.path:
		return {
			"success": false,
			"error": "Destination is not in the local campaign catalog.",
			"missing": [],
			"fallback": []
		}
	var state_manager: Node = GameManager.get_core_system("state_manager")
	if not state_manager or not state_manager.validate_session_players(offer.get("players")):
		return {
			"success": false,
			"error": "Invalid destination player state.",
			"missing": [],
			"fallback": []
		}
	var packed: PackedScene = _sources.get(identity.id)
	if not packed and not identity.path.is_empty():
		packed = (
			ResourceLoader.load(identity.path, "PackedScene", ResourceLoader.CACHE_MODE_REPLACE)
			as PackedScene
		)
	if not packed:
		return {
			"success": false,
			"error": "Destination content is unavailable.",
			"missing": [],
			"fallback": []
		}
	_stage = LevelDestination.new()
	if not _stage.prepare(self, packed, identity, offer.spawn_id, offer.runtime):
		var message := _stage.error
		var capability_result := _stage.capability_validation
		_stage = null
		return {
			"success": false,
			"error": message,
			"missing": capability_result.get("missing", []),
			"fallback": capability_result.get("fallback", [])
		}
	_staged_players = offer.players.duplicate(true)
	return {"success": true, "error": "", "missing": [], "fallback": []}


func commit_staged_travel() -> bool:
	if not _stage or not is_instance_valid(_stage.document):
		return false
	var stage := _stage
	_stage = null
	if _started and is_instance_valid(document):
		_visits[current_destination_id] = capture_runtime_state()
	if not _pending_campaign.is_empty():
		_visits.clear()
		for identity: String in _pending_campaign.destinations:
			var entry: Dictionary = _pending_campaign.destinations[identity]
			destinations[identity] = entry.descriptor.duplicate(true)
			_visits[identity] = entry.runtime.duplicate(true)
		_pending_campaign.clear()
	var old_document := document
	var old_viewport: SubViewport = (
		old_document.get_parent() if is_instance_valid(old_document) else null
	)
	if is_instance_valid(old_document):
		old_document.runtime_player = null
		remove_child(old_viewport)
	document = stage.document
	navigation_region = stage.navigation
	# Share the committed World3D without exiting/re-entering the staged subtree:
	# encounter ownership, loot tracking and component signals remain intact.
	stage.viewport.name = "Destination"
	# Keep the old scenario alive until Godot has rebound the viewport visibility mask.
	var _staging_world := stage.viewport.find_world_3d()
	stage.viewport.own_world_3d = false
	stage.viewport.process_mode = Node.PROCESS_MODE_INHERIT
	stage.viewport = null
	stage.document = null
	stage.navigation = null
	stage.discard()
	current_destination_id = stage.descriptor.id
	current_spawn_id = stage.spawn_id
	_document_signature = stage.descriptor.signature
	_baseline_mission = stage.baseline
	destinations[current_destination_id] = stage.descriptor.duplicate(true)
	document.set_meta("travel_session", self)
	_mission.restore_runtime_state(stage.runtime.mission, document)
	if not _started:
		_started = true
		add_to_group("level_play_session")
		_create_status()
	if _staged_players.is_empty() and (not _is_networked() or multiplayer.is_server()):
		ensure_peer_player(1)
		player.global_transform = stage.spawn_transform
	else:
		apply_player_roster(_staged_players)
	_staged_players = []
	document.runtime_player = player
	var navigation_map := get_world_3d().navigation_map
	for actor: Node in document.find_children("*", "", true, false):
		if actor is ActorBase:
			actor.start_runtime()
		elif actor is Enemy and actor.movement_component and actor.movement_component.nav_agent:
			actor.movement_component.nav_agent.set_navigation_map(navigation_map)
	navigation_region.enabled = true
	NavigationServer3D.map_set_use_async_iterations(navigation_map, false)
	NavigationServer3D.region_set_use_async_iterations(navigation_region.get_rid(), false)
	NavigationServer3D.map_force_update(navigation_map)
	if is_instance_valid(old_viewport):
		old_viewport.free()
	GameManager.change_state(GameManager.State.RUNNING)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	set_travel_frozen(_frozen)
	_refresh_status()
	destination_changed.emit(current_destination_id)
	return true


func abort_staged_travel() -> void:
	if _stage:
		_stage.discard()
	_stage = null
	_staged_players = []
	_pending_campaign.clear()


func set_travel_frozen(frozen: bool) -> void:
	var resuming := _frozen and not frozen
	_frozen = frozen
	if frozen and multiplayer.is_server():
		for peer_id: int in multiplayer.get_peers():
			set_peer_replication(peer_id, false)
	if is_instance_valid(document):
		document.process_mode = Node.PROCESS_MODE_DISABLED if frozen else Node.PROCESS_MODE_INHERIT
	for participant: Player in get_session_players():
		participant.process_mode = (
			Node.PROCESS_MODE_DISABLED if frozen else Node.PROCESS_MODE_INHERIT
		)
		var predictor := (
			participant.get_node_or_null("PlayerMovementPredictor") as PlayerMovementPredictor
		)
		if predictor:
			predictor.set_session_boundary(frozen, travel_network.generation)
		var interpolator := (
			participant.get_node_or_null("RemoteInterpolator") as RemoteEntityInterpolator
		)
		if interpolator and interpolator.snapshot_buffer:
			interpolator.snapshot_buffer.snapshots.clear()
		if participant.network_sync:
			participant.network_sync.set_target_position(participant.global_position)
			participant.network_sync.set_target_rotation(participant.rotation)
	if is_instance_valid(_mission) and frozen:
		_mission.set_process(false)
	elif _started and is_instance_valid(_mission):
		_mission.set_process(true)

	if resuming and travel_network and multiplayer.is_server():
		travel_network._broadcast_roster()


func set_peer_replication(peer_id: int, enabled: bool) -> void:
	for participant: Player in get_session_players():
		for synchronizer: MultiplayerSynchronizer in participant.find_children(
			"*", "MultiplayerSynchronizer", true, false
		):
			synchronizer.set_visibility_for(peer_id, enabled)


func get_session_players() -> Array[Player]:
	var participants: Array[Player] = []
	for child: Node in get_children():
		if child is Player:
			participants.append(child)
	return participants


func ensure_peer_player(peer_id: int) -> void:
	if peer_id <= 0 or get_node_or_null(str(peer_id)):
		return
	var participant := PLAYER_SCENE.instantiate() as Player
	participant.name = str(peer_id)
	participant.isolated_session = is_editor_preview
	participant.session_managed = true
	participant.disable_mode = CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE
	participant.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(participant)
	if not participant.interaction_component:
		PlayerComponentFactory._setup_interaction(participant)
	if is_instance_valid(document):
		var points: Array[Node3D] = document.get_spawn_points("player")
		for point: Node3D in points:
			if str(point.get_meta("spawn_id", document.get_path_to(point))) == current_spawn_id:
				participant.global_transform = point.global_transform
				break
	participant.spawns = PackedVector3Array([participant.global_position])
	if peer_id == multiplayer.get_unique_id():
		player = participant
	elif player == null and peer_id == 1:
		player = participant
	participant.process_mode = Node.PROCESS_MODE_DISABLED if _frozen else Node.PROCESS_MODE_INHERIT
	var predictor := (
		participant.get_node_or_null("PlayerMovementPredictor") as PlayerMovementPredictor
	)
	if predictor:
		predictor.set_session_boundary(_frozen, travel_network.generation)


func remove_peer_player(peer_id: int) -> void:
	var participant := get_node_or_null(str(peer_id))
	if participant is Player:
		participant.free()


func capture_player_roster() -> Array:
	var state_manager: Node = GameManager.get_core_system("state_manager")
	return state_manager.capture_session_players(self) if state_manager else []


func apply_player_roster(records: Array) -> bool:
	var state_manager: Node = GameManager.get_core_system("state_manager")
	if not state_manager or not state_manager.validate_session_players(records):
		return false
	var present: Dictionary = {}
	for record: Dictionary in records:
		var peer_id := int(record.peer_id)
		var arriving := _frozen or not get_node_or_null(str(peer_id))
		present[peer_id] = true
		ensure_peer_player(peer_id)
		if arriving:
			var participant := get_node(str(peer_id)) as Player
			participant.global_position = Vector3(
				record.position[0], record.position[1], record.position[2]
			)
			participant.global_rotation = Vector3(
				record.rotation[0], record.rotation[1], record.rotation[2]
			)
			participant.velocity = Vector3.ZERO
			participant.spawns = PackedVector3Array([participant.global_position])
	for participant: Player in get_session_players():
		if not present.has(participant.get_multiplayer_authority()):
			participant.free()
	state_manager.restore_session_players(records, self)
	if is_instance_valid(document):
		document.runtime_player = player
	return true


func get_travel_offer() -> Dictionary:
	if not _started:
		return {}
	return {
		"descriptor": destinations[current_destination_id].duplicate(true),
		"spawn_id": current_spawn_id,
		"runtime": capture_runtime_state(),
		"players": capture_player_roster()
	}


func capture_runtime_state() -> Dictionary:
	return LevelRuntimeState.capture(
		document, _document_signature, _mission.capture_runtime_state()
	)


func validate_runtime_state(state: Variant) -> bool:
	return (
		_started
		and LevelRuntimeState.validate(document, _document_signature, _baseline_mission, state)
	)


func restore_runtime_state(state: Dictionary) -> bool:
	if not validate_runtime_state(state):
		return false
	document.set_meta("applying_authoritative_state", true)
	var restored := LevelRuntimeState.restore_actors(document, state)
	document.remove_meta("applying_authoritative_state")
	if not restored:
		return false
	_mission.restore_runtime_state(state.mission, document)
	_refresh_status()
	return true


func apply_runtime_update(state: Dictionary) -> bool:
	if _frozen or not validate_runtime_state(state):
		return false
	document.set_meta("applying_authoritative_state", true)
	var restored := LevelRuntimeState.restore_actors(document, state, true)
	document.remove_meta("applying_authoritative_state")
	if (
		restored
		and not LevelRuntimeState._same_json_value(state.mission, _mission.capture_runtime_state())
	):
		_mission.restore_runtime_state(state.mission, document)
		_refresh_status()
	return restored


func capture_campaign_state() -> Dictionary:
	var entries: Dictionary = {}
	for identity: String in _visits:
		entries[identity] = {
			"descriptor": destinations[identity].duplicate(true),
			"runtime": _visits[identity].duplicate(true)
		}
	if _started:
		entries[current_destination_id] = {
			"descriptor": destinations[current_destination_id].duplicate(true),
			"runtime": capture_runtime_state()
		}
	return {
		"version": 1,
		"current_id": current_destination_id,
		"spawn_id": current_spawn_id,
		"destinations": entries,
		"players": capture_player_roster()
	}


func validate_campaign_state(state: Variant) -> bool:
	if (
		not state is Dictionary
		or state.get("version") != 1
		or not state.get("current_id") is String
		or not state.get("spawn_id") is String
		or not state.get("destinations") is Dictionary
	):
		return false
	if (
		state.destinations.is_empty()
		or state.destinations.size() > MAX_DESTINATIONS
		or not state.destinations.has(state.current_id)
	):
		return false
	var state_manager: Node = GameManager.get_core_system("state_manager")
	if not state_manager or not state_manager.validate_session_players(state.get("players")):
		return false
	for identity: Variant in state.destinations:
		if not identity is String or not destinations.has(identity):
			return false
		var entry: Variant = state.destinations[identity]
		if (
			not entry is Dictionary
			or not entry.get("descriptor") is Dictionary
			or not entry.get("runtime") is Dictionary
		):
			return false
		if (
			entry.descriptor.get("id") != identity
			or entry.descriptor.get("path") != destinations[identity].path
		):
			return false
		var packed: PackedScene = _sources.get(identity)
		if not packed:
			packed = load(destinations[identity].path) as PackedScene
		if not packed:
			return false
		var candidate := LevelDestination.new()
		var arrival: String = state.spawn_id if identity == state.current_id else ""
		var valid := candidate.prepare(self, packed, entry.descriptor, arrival, entry.runtime)
		candidate.discard()
		if not valid:
			return false
	return true


func restore_campaign_state(state: Dictionary) -> bool:
	if (
		is_travel_pending()
		or (_is_networked() and not multiplayer.is_server())
		or not validate_campaign_state(state)
	):
		return false
	_travel_busy = true
	set_travel_frozen(true)
	var entry: Dictionary = state.destinations[state.current_id]
	var offer := {
		"descriptor": entry.descriptor,
		"spawn_id": state.spawn_id,
		"runtime": entry.runtime,
		"players": state.players
	}
	var prepared := stage_travel_offer(offer)
	if not prepared.success:
		_travel_busy = false
		set_travel_frozen(false)
		return false
	_pending_campaign = state.duplicate(true)
	var success := await travel_network.synchronize_travel(offer)
	_travel_busy = false
	set_travel_frozen(false)
	return success


func _fail(message: String) -> bool:
	error_message = message
	stop()
	return false


func stop() -> void:
	if travel_network and not _exiting:
		travel_network.cancel_travel()
	if _exiting:
		# The parent frees its entire subtree after exit notifications complete.
		_stage = null
	else:
		abort_staged_travel()
	if is_instance_valid(_mission):
		if _mission.objective_updated.is_connected(_on_objective_updated):
			_mission.objective_updated.disconnect(_on_objective_updated)
		if _mission.mission_completed.is_connected(_on_mission_completed):
			_mission.mission_completed.disconnect(_on_mission_completed)
		if _initialized:
			_mission.restore_runtime_state(
				_previous_mission,
				_previous_mission_level if is_instance_valid(_previous_mission_level) else null
			)
	if _initialized:
		GameManager.change_state(_previous_game_state)
		Input.mouse_mode = _previous_mouse_mode
	_initialized = false
	_started = false
	remove_from_group("level_play_session")
	if not _exiting:
		for child: Node in get_children():
			if child != travel_network:
				child.free()
	document = null
	player = null
	navigation_region = null
	_status = null
	_visits.clear()
	_sources.clear()
	destinations.clear()


func _exit_tree() -> void:
	_exiting = true
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


func _create_status() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	_status = Label.new()
	_status.position = Vector2(28, 24)
	_status.add_theme_font_size_override("font_size", 21)
	_status.add_theme_color_override("font_color", Color(0.85, 0.95, 0.93))
	_status.add_theme_color_override("font_shadow_color", Color(0.01, 0.025, 0.03))
	_status.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_status.offset_left = 28
	_status.offset_right = -28
	_status.offset_top = 24
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
	var required_total := 0
	var required_complete := 0
	var optional_total := 0
	var optional_complete := 0
	var next_objective := ""
	var next_order := 0
	for objective: Dictionary in _mission.active_mission_data.get("objectives", []):
		var complete: bool = (
			int(_mission.objective_state.get(objective.id, 0))
			>= int(_mission.objective_totals.get(objective.id, 1))
		)
		if objective.get("optional", false):
			optional_total += 1
			optional_complete += int(complete)
			continue
		required_total += 1
		required_complete += int(complete)
		if not complete and (next_objective.is_empty() or objective.get("order", 0) < next_order):
			var actor: Node = document.find_actor(objective.target_actor)
			if actor and _mission.can_activate_actor(actor):
				next_objective = str(objective.description)
				next_order = int(objective.get("order", 0))
	if not next_objective.is_empty():
		lines.append("Next: " + next_objective)
	var progress := "Objectives: %d/%d" % [required_complete, required_total]
	if optional_total > 0:
		progress += "   Secrets: %d/%d" % [optional_complete, optional_total]
	lines.append(progress)
	if not _mission.completed_mission_id.is_empty():
		lines.append("MISSION COMPLETE")
	lines.append("E: interact   F5: save checkpoint   F9: load checkpoint")
	if is_editor_preview:
		lines.append("Esc: return to unchanged editor document")
	if not _notice.is_empty():
		lines.append(_notice)
	_status.text = "\n".join(lines)
