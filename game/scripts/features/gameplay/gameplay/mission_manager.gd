class_name MissionMgr
extends Node

signal mission_started(mission_id: String)
signal mission_completed(mission_id: String)
signal mission_failed(mission_id: String)
signal objective_updated(mission_id: String, objective_id: String, current: int, required: int)
signal mission_context_changed

const MISSIONS_PATH := "res://game/data/missions"
const DEFAULT_MISSION_ID := "mission_kill_all"

var active_mission_id: String = ""
var active_mission_data: Dictionary = {}
var objective_state: Dictionary = {}  # obj_id -> current_count
var objective_totals: Dictionary = {}  # obj_id -> initial/total_count
var available_missions: Dictionary = {}  # id -> data
var mission_level: Node3D
var completed_mission_id: String = ""
var document_error: String = ""
var _objectives_by_id: Dictionary = {}


static func get_instance() -> MissionMgr:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if not tree or not tree.root:
		return null
	var manager: Node = tree.root.get_node_or_null("GameManager")
	if not manager or not manager.has_method("get_core_system"):
		return null
	var gs := manager.get_core_system("gameplay") as GameplaySvc
	return gs.mission as MissionMgr if gs else null


## MissionManager
## Handles moddable missions, quests, and game loop objectives.
## Works as the "Loop Director" by checking win/loss conditions.

# Service preloads to resolve lints

# Data paths

# State

# Cache


func _ready() -> void:
	_load_all_missions()

	# Wait for parent GameplaySvc to finish initializing all services
	var gs := get_parent() as GameplaySvc
	if gs:
		if gs.has_signal("services_ready"):
			gs.services_ready.connect(_connect_signals, CONNECT_ONE_SHOT)
		else:
			# Fallback if signal doesn't exist
			call_deferred("_connect_signals")
	else:
		call_deferred("_connect_signals")


func _connect_signals() -> void:
	# Listen for match events
	var gs := GameManager.get_core_system("gameplay") as GameplaySvc
	if gs and gs.match_service:
		gs.match_service.match_started.connect(_on_match_started)

		# Check if match already started before we connected
		if gs.match_service.current_match_state == gs.match_service.MatchState.PLAYING:
			var logger: Variant = GameManager.get_core_system("logger")
			if logger and logger.has_method("info"):
				logger.info(
					"[MissionManager] Match already in progress, starting default mission", "Core"
				)
			# Start default mission
			if available_missions.has(DEFAULT_MISSION_ID):
				start_mission(DEFAULT_MISSION_ID)


func _exit_tree() -> void:
	# === SIGNAL HYGIENE ===
	var gs := GameManager.get_core_system("gameplay") as GameplaySvc
	if gs and gs.match_service and gs.match_service.match_started.is_connected(_on_match_started):
		gs.match_service.match_started.disconnect(_on_match_started)


func handle_match_started(settings: Dictionary) -> void:
	var logger: Variant = GameManager.get_core_system("logger")

	# Check if settings specify a mission, otherwise load default/random?
	var mission_id: String = settings.get("mission_id", "")

	# MVP: If no mission specified, try to find a default "kill_all" or similar
	if mission_id == "" and available_missions.has(DEFAULT_MISSION_ID):
		mission_id = DEFAULT_MISSION_ID
		if logger and logger.has_method("info"):
			logger.info(
				"[MissionManager] No mission specified, using default: %s" % mission_id, "Core"
			)

	if mission_id != "" and available_missions.has(mission_id):
		start_mission(mission_id)
	else:
		if logger and logger.has_method("warn"):
			logger.warn(
				(
					"[MissionManager] No valid mission to start. Available: %s"
					% str(available_missions.keys())
				),
				"Core"
			)
		else:
			push_warning(
				(
					"[MissionManager] No valid mission to start. Available: %s"
					% str(available_missions.keys())
				)
			)


func _on_match_started(settings: Dictionary) -> void:
	var logger: Variant = GameManager.get_core_system("logger")
	if logger and logger.has_method("info"):
		logger.info(
			"[MissionManager] Match started signal received with settings: %s" % str(settings),
			"Core"
		)
	else:
		print("[MissionManager] Match started signal received with settings: %s" % str(settings))
	handle_match_started(settings)


func _load_all_missions() -> void:
	available_missions.clear()

	var dir := DirAccess.open(MISSIONS_PATH)
	if not dir:
		var missing_logger: Variant = GameManager.get_core_system("logger")
		if missing_logger and missing_logger.has_method("info"):
			missing_logger.info(
				"[MissionManager] Missions directory unavailable; loaded 0 missions", "Core"
			)
		return
	if dir:
		dir.list_dir_begin()
		var file_name: String = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".json"):
				_load_mission_file(MISSIONS_PATH.path_join(file_name))
			file_name = dir.get_next()

	var logger: Variant = GameManager.get_core_system("logger")
	if logger and logger.has_method("info"):
		logger.info("[MissionManager] Loaded %d missions" % available_missions.size(), "Core")
	else:
		print("[MissionManager] Loaded %d missions" % available_missions.size())


func _load_mission_file(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return

	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	if err == OK:
		var data: Dictionary = json.data
		if "id" in data:
			available_missions[data.id] = data


func start_mission(mission_id: String) -> void:
	if not available_missions.has(mission_id):
		push_error("[MissionManager] Mission not found: " + mission_id)
		return

	_begin_mission(mission_id, available_missions[mission_id], null)


func _begin_mission(mission_id: String, definition: Dictionary, level: Node3D) -> void:
	active_mission_id = mission_id
	completed_mission_id = ""
	active_mission_data = definition.duplicate(true)
	mission_level = level
	mission_context_changed.emit()
	objective_state.clear()
	objective_totals.clear()
	_index_objectives()

	# Initialize objectives
	var objectives: Array = active_mission_data.get("objectives", [])
	for obj: Dictionary in objectives:
		var type: String = obj.get("type", "")
		if type == "eliminate_group":
			var group: String = obj.get("target_group", "enemies")
			var total := get_tree().get_nodes_in_group(group).size()
			objective_totals[obj.id] = total
			objective_state[obj.id] = 0
		elif type == "activate_actor":
			objective_totals[obj.id] = int(obj.get("required_count", 1))
			objective_state[obj.id] = 0

	var logger: Variant = GameManager.get_core_system("logger")
	if logger and logger.has_method("info"):
		logger.info(
			"[MissionManager] Started mission: " + active_mission_data.get("name", mission_id),
			"Core"
		)
	else:
		print("[MissionManager] Started mission: " + active_mission_data.get("name", mission_id))
	mission_started.emit(mission_id)

	# Start monitoring loop
	set_process(not objectives.is_empty())


func start_document_mission(level: Node3D) -> bool:
	var preview := build_document_state(level)
	document_error = preview.error
	if not preview.success:
		return false
	# Ordinary authored maps keep the normal match mission; travel explicitly
	# installs the preview's empty document-scoped state instead.
	if preview.state.definition.objectives.is_empty():
		return true
	_begin_mission(preview.state.active_id, preview.state.definition, level)
	return true


## Pure preview: no service state, signals, or actor activation changes.
func build_document_state(level: Node3D) -> Dictionary:
	if not level or not level.has_method("get_actor_identity"):
		return _document_error("Mission requires an authored level document.")
	var objectives: Array[Dictionary] = []
	var declarations: Dictionary = {}
	for node: Node in level.find_children("*", "", true, false):
		if not node.has_meta("mission_objective"):
			continue
		var authored: Variant = node.get_meta("mission_objective")
		if not authored is Dictionary or not "activation_count" in node:
			return _document_error("Objective must belong to a gameplay actor: " + str(node.name))
		var identity: String = level.get_actor_identity(node)
		if identity.is_empty() or declarations.has(identity):
			return _document_error("Objective actor identity is empty or duplicated: " + identity)
		for flag: String in ["optional", "final"]:
			if not authored.get(flag, false) is bool:
				return _document_error(identity + ": " + flag + " must be boolean.")
		if not authored.get("order", 0) is int:
			return _document_error(identity + ": order must be an integer.")
		if authored.has("requires") and not authored.requires is Array:
			return _document_error(identity + ": requires must be an array of actor identities.")
		declarations[identity] = authored
		objectives.append(
			{
				"id": identity,
				"type": "activate_actor",
				"target_actor": identity,
				"description": str(authored.get("description", node.name)),
				"required_count": 1,
				"requires": [],
				"optional": authored.get("optional", false),
				"final": authored.get("final", false),
				"order": authored.get("order", 0)
			}
		)
	for objective: Dictionary in objectives:
		var authored: Dictionary = declarations[objective.id]
		if authored.has("requires"):
			for prerequisite: Variant in authored.requires:
				if (
					not prerequisite is String
					or not declarations.has(prerequisite)
					or prerequisite == objective.id
					or objective.requires.has(prerequisite)
				):
					return _document_error(
						objective.id + ": invalid prerequisite " + str(prerequisite)
					)
				if not objective.optional and declarations[prerequisite].get("optional", false):
					return _document_error(
						objective.id + ": a required objective cannot depend on an optional objective."
					)
				objective.requires.append(prerequisite)
		elif objective.final:
			for prerequisite: Dictionary in objectives:
				if not prerequisite.final and not prerequisite.optional:
					objective.requires.append(prerequisite.id)
	var ordered := _order_document_objectives(objectives)
	if ordered.size() != objectives.size():
		return _document_error("Objective prerequisites contain a cycle.")
	var counts: Dictionary = {}
	var totals: Dictionary = {}
	for objective: Dictionary in ordered:
		counts[objective.id] = 0
		totals[objective.id] = int(objective.required_count)
	return {
		"success": true,
		"error": "",
		"state": {
			"active_id": str(level.get_meta("mission_id", "document_mission")),
			"completed_id": "",
			"definition": {
				"name": str(level.get("level_name")), "objectives": ordered, "ends_match": false
			},
			"state": counts,
			"totals": totals
		}
	}


func _document_error(message: String) -> Dictionary:
	return {"success": false, "error": message, "state": {}}


func _order_document_objectives(objectives: Array[Dictionary]) -> Array[Dictionary]:
	objectives.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return a.id < b.id if a.order == b.order else a.order < b.order
	)
	var remaining: Dictionary = {}
	var dependents: Dictionary = {}
	var by_id: Dictionary = {}
	var ready: Array[String] = []
	for objective: Dictionary in objectives:
		by_id[objective.id] = objective
		remaining[objective.id] = objective.requires.size()
		if objective.requires.is_empty():
			ready.append(objective.id)
		for prerequisite: String in objective.requires:
			if not dependents.has(prerequisite):
				dependents[prerequisite] = []
			dependents[prerequisite].append(objective.id)
	var ordered: Array[Dictionary] = []
	var index := 0
	while index < ready.size():
		var identity: String = ready[index]
		index += 1
		ordered.append(by_id[identity])
		if not dependents.has(identity):
			continue
		for dependent: String in dependents[identity]:
			remaining[dependent] -= 1
			if remaining[dependent] == 0:
				ready.append(dependent)
	return ordered


func _index_objectives() -> void:
	_objectives_by_id.clear()
	for objective: Dictionary in active_mission_data.get("objectives", []):
		_objectives_by_id[objective.id] = objective


func can_activate_actor(actor: Node) -> bool:
	if not is_instance_valid(mission_level) or not mission_level.is_ancestor_of(actor):
		return true
	var identity: String = mission_level.get_actor_identity(actor)
	var objective: Variant = _objectives_by_id.get(identity)
	if objective is Dictionary:
		for required: String in objective.get("requires", []):
			if int(objective_state.get(required, 0)) < int(objective_totals.get(required, 1)):
				return false
	return true


func capture_runtime_state() -> Dictionary:
	return {
		"active_id": active_mission_id,
		"completed_id": completed_mission_id,
		"definition": active_mission_data.duplicate(true),
		"state": objective_state.duplicate(),
		"totals": objective_totals.duplicate()
	}


func restore_runtime_state(state: Dictionary, level: Node3D = null) -> bool:
	if (
		not state.get("active_id") is String
		or not state.get("completed_id") is String
		or not state.get("definition") is Dictionary
		or not state.get("state") is Dictionary
		or not state.get("totals") is Dictionary
	):
		return false
	active_mission_id = state.active_id
	completed_mission_id = state.completed_id
	active_mission_data = state.definition.duplicate(true)
	objective_state = state.state.duplicate()
	objective_totals = state.totals.duplicate()
	mission_level = level
	mission_context_changed.emit()
	_index_objectives()
	set_process(
		(
			(not active_mission_id.is_empty() and not _objectives_by_id.is_empty())
			or (is_instance_valid(mission_level) and _has_pending_optional_objectives())
		)
	)
	if not active_mission_id.is_empty():
		mission_started.emit(active_mission_id)
	return true


func _check_actor_objective(objective: Dictionary) -> bool:
	if not is_instance_valid(mission_level):
		return false
	var actor: Node = mission_level.find_actor(objective.target_actor)
	if not is_instance_valid(actor) or not can_activate_actor(actor):
		return false
	var required: int = int(objective_totals[objective.id])
	var current: int = mini(int(actor.activation_count), required)
	if int(objective_state.get(objective.id, 0)) != current:
		objective_state[objective.id] = current
		objective_updated.emit(
			active_mission_id if not active_mission_id.is_empty() else completed_mission_id,
			objective.id,
			current,
			required
		)
	return current >= required


func _process(_delta: float) -> void:
	if (
		active_mission_id.is_empty()
		and (not is_instance_valid(mission_level) or not _has_pending_optional_objectives())
	):
		set_process(false)
		return

	# Check objectives
	var all_complete: bool = not active_mission_data.get("objectives", []).is_empty()
	var objectives: Array = active_mission_data.get("objectives", [])

	for obj: Dictionary in objectives:
		if active_mission_id.is_empty() and not obj.get("optional", false):
			continue
		var type: String = obj.get("type", "")
		var is_complete: bool = false

		if type == "eliminate_group":
			is_complete = _check_eliminate_group(obj)
		elif type == "activate_actor":
			is_complete = _check_actor_objective(obj)

		if not is_complete and not obj.get("optional", false):
			all_complete = false

	# Update Compass periodically
	_update_compass_markers()

	if all_complete and not active_mission_id.is_empty():
		_complete_mission()


func _has_pending_optional_objectives() -> bool:
	for objective: Dictionary in active_mission_data.get("objectives", []):
		if (
			objective.get("optional", false)
			and (
				int(objective_state.get(objective.id, 0))
				< int(objective_totals.get(objective.id, 1))
			)
		):
			return true
	return false


func _update_compass_markers() -> void:
	var compass_nodes: Array[Node] = get_tree().get_nodes_in_group("compass_bar")
	if compass_nodes.is_empty():
		return
	var compass: Node = compass_nodes[0]  # Assume one

	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")
	for enemy: Node in enemies:
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
			# Check dead state
			var is_dead: Variant = enemy.get("is_dead")
			if is_dead:
				compass.remove_marker(str(enemy.get_instance_id()))
				continue

			compass.add_marker(
				str(enemy.get_instance_id()), enemy.global_position, compass.MarkerType.ENEMY
			)


func _check_eliminate_group(obj: Dictionary) -> bool:
	var group_name: String = obj.get("target_group", "enemies")
	var required: int = obj.get("required_count", -1)

	var current_nodes: Array = get_tree().get_nodes_in_group(group_name)
	var living_count: int = 0

	for node: Node in current_nodes:
		if not node.is_queued_for_deletion():
			# Check specific "dead" property if it exists
			# Use safe access to avoid errors if property missing
			if node.get("is_dead") == false:
				living_count += 1
			elif not "is_dead" in node:
				# If no dead property, assume existence = alive
				living_count += 1

	# Emit Update for UI
	var total: int = objective_totals.get(obj.id, required)
	if required != -1:
		total = required

	var killed: int = maxi(0, int(objective_totals.get(obj.id, total)) - living_count)
	if int(objective_state.get(obj.id, -1)) != killed:
		objective_state[obj.id] = killed
		objective_updated.emit(active_mission_id, obj.id, killed, total)

	# If required is -1, we need 0 living.
	if required == -1:
		return living_count == 0

	return killed >= required


func _complete_mission() -> void:
	var logger: Variant = GameManager.get_core_system("logger")
	if logger and logger.has_method("info"):
		logger.info("[MissionManager] Mission Complete: " + active_mission_id, "Core")
	else:
		print("[MissionManager] Mission Complete: " + active_mission_id)
	completed_mission_id = active_mission_id
	mission_completed.emit(active_mission_id)
	active_mission_id = ""
	set_process(is_instance_valid(mission_level) and _has_pending_optional_objectives())
	if not active_mission_data.get("ends_match", true):
		return

	# Trigger Match End
	var gs := GameManager.get_core_system("gameplay") as GameplaySvc
	if gs and gs.match_service:
		# 1 = Generic Winner/Player Team
		if multiplayer.has_multiplayer_peer():
			gs.match_service.end_match.rpc(1)
		else:
			gs.match_service.end_match(1)


func abort_mission() -> void:
	if active_mission_id != "":
		var aborted_id := active_mission_id
		active_mission_id = ""
		mission_failed.emit(aborted_id)
		set_process(false)
