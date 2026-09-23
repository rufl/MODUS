extends ModusGutTestBase

const LevelRootScript := preload("res://shared/editor_core/nodes/level_root.gd")
const ModuleAssemblyScript := preload("res://shared/editor_core/core/module_assembly.gd")
const ActorScript := preload("res://shared/editor_core/actors/actor_base.gd")
const KeyPickupActorScript := preload("res://shared/editor_core/actors/key_pickup_actor.gd")
const DoorActorScript := preload("res://shared/editor_core/actors/door_actor.gd")
const SwitchActorScript := preload("res://shared/editor_core/actors/switch_actor.gd")
const SecretWallActorScript := preload("res://shared/editor_core/actors/secret_wall_actor.gd")
const TravelActorScript := preload("res://shared/editor_core/actors/travel_actor.gd")
const PlayerHUDBridgeScript := preload("res://game/entities/player/components/player_hud_bridge.gd")
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
	assert_eq(key.get_interaction_prompt(), "Collect key_red")
	assert_eq(door.get_interaction_prompt(), "Locked (Requires key_red)")

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
	assert_eq(key.get_interaction_prompt(), "Collected")
	door.trigger(player)
	assert_eq(door.activation_count, 1, "Key completion unlocks the generated door")
	assert_false(door.locked)
	assert_eq(door.get_interaction_prompt(), "Close")
	_mission._process(0.0)
	assert_eq(_mission.objective_state["LockedDoor_0"], 1)
	assert_true(
		extraction.interact(player), "Extraction uses the public actor interaction contract"
	)
	_mission._process(0.0)
	assert_eq(_mission.objective_state["GeneratedExtraction"], 1)
	assert_eq(_mission.completed_mission_id, "generated_dependency_regression")


func test_hud_resolves_generated_actor_parent_from_collision_child() -> void:
	var bridge: PlayerHUDBridge = PlayerHUDBridgeScript.new()
	add_child_autofree(bridge)
	var door := DoorActor.new()
	var collision_body := StaticBody3D.new()
	door.add_child(collision_body)
	add_child_autofree(door)

	assert_eq(
		bridge._find_interactable(collision_body),
		door,
		"HUD should resolve generated actor parents, not only Interactable components"
	)


func test_generated_actor_collision_layers_support_world_and_interaction_rays() -> void:
	var key: KeyPickupActor = KeyPickupActorScript.new()
	add_child_autofree(key)
	var key_body: StaticBody3D = key.get_node("KeyCard")
	assert_eq(key_body.collision_layer, CollisionLayers.LAYER_INTERACTABLES)
	assert_eq(key_body.collision_mask, 0)

	var door: DoorActor = DoorActorScript.new()
	add_child_autofree(door)
	var door_leaf: AnimatableBody3D = door.get_node("DoorLeaf")
	assert_eq(
		door_leaf.collision_layer, CollisionLayers.LAYER_WORLD | CollisionLayers.LAYER_INTERACTABLES
	)

	var switch_actor: SwitchActor = SwitchActorScript.new()
	add_child_autofree(switch_actor)
	var switch_body: StaticBody3D = switch_actor.get_node("SwitchBody")
	assert_eq(switch_body.collision_layer, CollisionLayers.LAYER_INTERACTABLES)
	assert_eq(switch_body.collision_mask, 0)


func test_secret_and_travel_actor_prompts_and_collision_layers_are_discoverable() -> void:
	var secret_wall: SecretWallActor = SecretWallActorScript.new()
	secret_wall.trigger_type = SecretWallActor.TriggerType.INTERACT
	add_child_autofree(secret_wall)
	var secret_body: StaticBody3D = secret_wall.get_node("WallBody")
	assert_eq(
		secret_wall.get_interaction_prompt(),
		"Open Secret Wall",
		"Interact-triggered secrets expose an actionable prompt"
	)
	assert_eq(
		secret_body.collision_layer,
		CollisionLayers.LAYER_WORLD | CollisionLayers.LAYER_INTERACTABLES
	)

	var travel: TravelActor = TravelActorScript.new()
	add_child_autofree(travel)
	assert_eq(travel.get_interaction_prompt(), "Travel (Destination Unconfigured)")
	travel.destination_id = "mission_hub"
	assert_eq(travel.get_interaction_prompt(), "Travel to mission_hub")
	assert_eq(
		(travel.get_node("SwitchBody") as StaticBody3D).collision_layer,
		CollisionLayers.LAYER_INTERACTABLES
	)


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


func test_breakwater_station_is_an_authored_multi_room_cycle() -> void:
	var packed := load("res://game/levels/breakwater_mission.tscn") as PackedScene
	assert_not_null(packed, "The authored Breakwater mission must remain loadable")
	if packed == null:
		return
	var root := packed.instantiate() as Node3D
	add_child_autofree(root)
	var instances := ModuleAssemblyScript.get_instances(root)
	assert_eq(instances.size(), 11, "Breakwater must retain its authored room count")
	assert_eq(root.module_connections.size(), 12, "Breakwater must retain its authored route edges")
	if instances.is_empty():
		return

	var ids: Dictionary = {}
	for instance in instances:
		ids[instance.instance_id] = true
	var adjacency: Dictionary = {}
	for instance_id: String in ids:
		adjacency[instance_id] = []
	for connection: Dictionary in root.module_connections:
		var from_id := str(connection.get("from_instance", ""))
		var to_id := str(connection.get("to_instance", ""))
		assert_true(ids.has(from_id), "Every authored edge source must name a room")
		assert_true(ids.has(to_id), "Every authored edge target must name a room")
		if ids.has(from_id) and ids.has(to_id):
			adjacency[from_id].append(to_id)

	var reachable: Dictionary = {}
	var pending: Array[String] = ["dock"]
	while not pending.is_empty():
		var current: String = pending.pop_front()
		if reachable.has(current):
			continue
		reachable[current] = true
		for next_id: String in adjacency.get(current, []):
			if not reachable.has(next_id):
				pending.append(next_id)
	assert_eq(reachable.size(), instances.size(), "The authored route must reach every room")
	assert_gte(
		root.module_connections.size(),
		instances.size(),
		"A connected 11-room route needs a loop edge"
	)
