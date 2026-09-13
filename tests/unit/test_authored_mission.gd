extends ModusGutTestBase

const LevelRootScript := preload("res://shared/editor_core/nodes/level_root.gd")
const ActorScript := preload("res://shared/editor_core/actors/actor_base.gd")

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
