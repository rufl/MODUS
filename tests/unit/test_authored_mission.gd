extends ModusGutTestBase

const LevelRootScript := preload("res://shared/editor_core/nodes/level_root.gd")
const ActorScript := preload("res://shared/editor_core/actors/actor_base.gd")
const KeyPickupActorScript := preload("res://shared/editor_core/actors/key_pickup_actor.gd")
const DoorActorScript := preload("res://shared/editor_core/actors/door_actor.gd")
const SwitchActorScript := preload("res://shared/editor_core/actors/switch_actor.gd")
var _mission: MissionMgr
var _previous: Dictionary
var _previous_level: Node3D


func before_each() -> void:
	await modus_setup()
	_mission = MissionMgr.get_instance()
	_previous = _mission.capture_runtime_state()
	_previous_level = _mission.mission_level
	_mission.set_process(false)


func after_each() -> void:
	_mission.restore_runtime_state(_previous, _previous_level)
	modus_teardown()


func _document(names: Array[String]) -> Node3D:
	var document: Node3D = LevelRootScript.new()
	document.level_name = "Dependency regression"
	document.set_meta("mission_id", "dependency_regression")
	add_child_autofree(document)
	for actor_name: String in names:
		var actor := ActorScript.new()
		actor.name = actor_name
		actor.actor_id = actor_name
		actor.one_shot = true
		actor.set_meta("mission_objective", {"description": actor_name})
		document.add_child(actor)
	return document


func test_generated_progression_reaches_extraction_and_completes_mission() -> void:
	var document: Node3D = LevelRootScript.new()
	document.level_name = "Generated mission graph"
	document.set_meta("mission_id", "generated_dependency_regression")
	add_child_autofree(document)

	var key: KeyPickupActor = KeyPickupActorScript.new()
	key.name = "KeyPickup_0"
	key.actor_id = key.name
	key.key_id = "key_red"
	key.set_meta("mission_objective", {"description": "Collect generated red key", "order": 0})
	document.add_child(key)

	var door: DoorActor = DoorActorScript.new()
	door.name = "LockedDoor_0"
	door.actor_id = door.name
	door.locked = true
	door.required_key = "key_red"
	door.set_meta(
		"mission_objective",
		{"description": "Open generated red door", "requires": ["KeyPickup_0"], "order": 1}
	)
	document.add_child(door)

	var extraction: SwitchActor = SwitchActorScript.new()
	extraction.name = "GeneratedExtraction"
	extraction.actor_id = extraction.name
	extraction.one_shot = true
	extraction.set_meta(
		"mission_objective",
		{
			"description": "Reach the generated extraction",
			"final": true,
			"requires": ["LockedDoor_0"],
			"order": 2
		}
	)
	document.add_child(extraction)

	assert_true(_mission.start_document_mission(document))
	var objectives: Array = _mission.active_mission_data.get("objectives", [])
	assert_eq(objectives.size(), 3)
	assert_eq(
		objectives[0].get("id"),
		"KeyPickup_0",
		"Generated objectives retain key-before-door ordering"
	)
	assert_eq(objectives[1].get("id"), "LockedDoor_0")
	assert_eq(objectives[1].get("requires"), ["KeyPickup_0"])
	assert_eq(objectives[2].get("id"), "GeneratedExtraction")
	assert_eq(objectives[2].get("requires"), ["LockedDoor_0"])

	var player := Node.new()
	var player_script := GDScript.new()
	player_script.source_code = ("extends Node\nfunc has_item(_item_id: String) -> bool:\n\treturn true\n")
	assert_eq(player_script.reload(), OK)
	player.set_script(player_script)
	add_child_autofree(player)

	extraction.interact(player)
	assert_eq(
		extraction.activation_count, 0, "Extraction cannot activate before generated progression"
	)
	door.trigger(player)
	assert_eq(door.activation_count, 0, "Door cannot activate before its generated key")
	key.trigger(player)
	_mission._process(0.0)
	assert_eq(_mission.objective_state["KeyPickup_0"], 1)
	door.trigger(player)
	assert_eq(door.activation_count, 1, "Key completion unlocks the generated door")
	assert_false(door.locked)
	_mission._process(0.0)
	assert_eq(_mission.objective_state["LockedDoor_0"], 1)
	assert_true(
		extraction.interact(player), "Extraction uses the public actor interaction contract"
	)
	_mission._process(0.0)
	assert_eq(_mission.objective_state["GeneratedExtraction"], 1)
	assert_eq(_mission.completed_mission_id, "generated_dependency_regression")


func test_generated_manifest_accepts_branch_edges_outside_recovery_route() -> void:
	var manifest: Dictionary = {
		"version": 1,
		"seed_hash": 77,
		"start_room_id": 0,
		"goal_room_id": 3,
		"room_ids": [0, 1, 2, 3],
		"recovery_route": [0, 1, 3],
		"room_edges":
		[
			{"from_room_id": 0, "to_room_id": 1},
			{"from_room_id": 1, "to_room_id": 0},
			{"from_room_id": 0, "to_room_id": 2},
			{"from_room_id": 2, "to_room_id": 0},
			{"from_room_id": 1, "to_room_id": 3},
			{"from_room_id": 3, "to_room_id": 1},
			{"from_room_id": 2, "to_room_id": 3},
			{"from_room_id": 3, "to_room_id": 2}
		],
		"keys": [{"id": "KeyPickup_0", "color": "RED", "room_id": 1}],
		"locked_transitions":
		[
			{
				"id": "LockedDoor_0",
				"color": "RED",
				"room_id": 3,
				"key_id": "KeyPickup_0",
				"from_room_id": 1,
				"to_room_id": 3
			}
		],
		"objectives":
		[
			{"id": "KeyPickup_0", "order": 0, "requires": []},
			{"id": "LockedDoor_0", "order": 1, "requires": ["KeyPickup_0"]}
		]
	}
	assert_true(_mission.validate_progression_manifest(manifest).is_valid)
	manifest.room_edges.append({"from_room_id": 0, "to_room_id": 99})
	assert_false(_mission.validate_progression_manifest(manifest).is_valid)
	manifest.room_edges.pop_back()
	manifest.room_ids.append(4)
	assert_false(_mission.validate_progression_manifest(manifest).is_valid)


func test_document_without_objectives_preserves_the_normal_mission() -> void:
	_mission._begin_mission(
		"ordinary_authored",
		{"name": "Ordinary authored mission", "objectives": [], "ends_match": false},
		null
	)
	_mission.set_process(false)
	var expected := _mission.capture_runtime_state()
	var document: Node3D = LevelRootScript.new()
	document.level_name = "Ordinary authored level"
	add_child_autofree(document)

	assert_true(_mission.start_document_mission(document))
	assert_eq(
		_mission.capture_runtime_state(),
		expected,
		"Ordinary authored documents do not replace the normal mission"
	)


func test_invalid_dependency_graph_never_replaces_the_current_mission() -> void:
	var document := _document(["first", "second"])
	var first := document.get_node("first")
	var second := document.get_node("second")
	var first_id: String = document.get_actor_identity(first)
	var second_id: String = document.get_actor_identity(second)
	first.set_meta("mission_objective", {"requires": ["missing_actor"]})
	assert_false(_mission.start_document_mission(document))
	assert_eq(_mission.capture_runtime_state(), _previous)
	first.set_meta("mission_objective", {"requires": [second_id]})
	second.set_meta("mission_objective", {"requires": [first_id]})
	assert_false(
		_mission.start_document_mission(document),
		"Cyclic objectives must not create an unwinnable mission"
	)
	assert_eq(_mission.capture_runtime_state(), _previous)
	second.set_meta("mission_objective", {"optional": true})
	assert_false(
		_mission.start_document_mission(document),
		"The required route cannot depend on an optional secret"
	)
	assert_eq(_mission.capture_runtime_state(), _previous)


func test_prerequisites_survive_restore_and_secrets_do_not_block_or_repeat_completion() -> void:
	var document := _document(["return", "power", "key", "secret"])
	var goal: ActorBase = document.get_node("return")
	var power: ActorBase = document.get_node("power")
	var key: ActorBase = document.get_node("key")
	var secret: ActorBase = document.get_node("secret")
	var key_id: String = document.get_actor_identity(key)
	var power_id: String = document.get_actor_identity(power)
	var secret_id: String = document.get_actor_identity(secret)
	goal.set_meta("mission_objective", {"final": true, "requires": [power_id]})
	power.set_meta("mission_objective", {"requires": [key_id]})
	secret.set_meta("mission_objective", {"optional": true})
	assert_true(_mission.start_document_mission(document))
	_mission.set_process(false)
	watch_signals(_mission)
	goal.trigger()
	power.trigger()
	assert_eq(goal.activation_count, 0, "Early return cannot spend the final one-shot")
	assert_eq(power.activation_count, 0, "Power requires the real preceding objective")
	key.trigger()
	_mission._process(0.0)
	var checkpoint: Dictionary = JSON.parse_string(JSON.stringify(_mission.capture_runtime_state()))
	power.trigger()
	_mission._process(0.0)
	assert_true(_mission.can_activate_actor(goal))
	assert_true(_mission.restore_runtime_state(checkpoint, document))
	assert_false(
		_mission.can_activate_actor(goal),
		"Restoration reinstates saved prerequisites, not future progress"
	)
	_mission._process(0.0)
	goal.trigger()
	_mission._process(0.0)
	assert_eq(_mission.completed_mission_id, "dependency_regression")
	assert_eq(
		_mission.objective_state[secret_id],
		0,
		"Undiscovered secrets do not block the required route"
	)
	secret.trigger()
	_mission._process(0.0)
	assert_eq(
		_mission.objective_state[secret_id],
		1,
		"Secrets remain discoverable after the required route"
	)
	assert_signal_emit_count(_mission, "mission_completed", 1)


func test_generated_progression_manifest_survives_runtime_roundtrip() -> void:
	var document := _document(["extraction"])
	var extraction: Node = document.get_node("extraction")
	var extraction_id: String = str(document.get_actor_identity(extraction))
	var manifest := {
		"version": 1,
		"seed_hash": 42,
		"start_room_id": 0,
		"goal_room_id": 0,
		"objectives": [{"id": extraction_id, "order": 0, "requires": []}],
		"keys": [],
		"locked_transitions": [],
		"recovery_route": [0]
	}
	document.set_meta("generation", {"gameplay": {"mission_progression": manifest}})
	assert_true(_mission.start_document_mission(document))
	assert_eq(_mission.active_mission_data.progression_manifest, manifest)
	var checkpoint: Dictionary = JSON.parse_string(JSON.stringify(_mission.capture_runtime_state()))
	assert_true(_mission.restore_runtime_state(checkpoint, document))
	var expected_roundtrip: Dictionary = JSON.parse_string(JSON.stringify(manifest))
	assert_eq(_mission.active_mission_data.progression_manifest, expected_roundtrip)
