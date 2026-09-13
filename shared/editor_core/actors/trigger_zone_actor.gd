@tool
class_name TriggerZoneActor
extends "res://shared/editor_core/actors/actor_base.gd"

enum TriggerMode { ON_ENTER, ON_EXIT, WHILE_INSIDE, ON_ENTER_EXIT }  ## Activate when entity enters  ## Activate when entity exits  ## Stay active while entity is inside  ## Activate on enter, deactivate on exit
enum FilterType { PLAYER_ONLY, ENEMIES_ONLY, ANY_ENTITY, SPECIFIC_GROUP }  ## Only player can trigger  ## Only enemies can trigger  ## Any physics body can trigger  ## Only specific group can trigger

@export var trigger_mode: TriggerMode = TriggerMode.ON_ENTER
@export var filter_type: FilterType = FilterType.PLAYER_ONLY
@export var filter_group: String = ""  ## For SPECIFIC_GROUP filter
@export var zone_size: Vector3 = Vector3(2, 2, 2)
@export var show_in_editor: bool = true

var _area: Area3D
var _collision_shape: CollisionShape3D
var _entities_inside: Array[Node] = []
var _accepted_inside: Array[String] = []
var _runtime_started: bool = false
var _restore_overlap_frames: int = 0


func _init() -> void:
	actor_category = "trigger"
	actor_name = "Trigger Zone"
	actor_description = "Invisible zone that triggers when entities enter"


func _on_actor_ready() -> void:
	_create_zone()


func start_runtime() -> void:
	if is_authoring():
		return
	_runtime_started = true
	super.start_runtime()


func _create_zone() -> void:
	# Create Area3D for detection
	_area = Area3D.new()
	_area.name = "TriggerArea"
	_area.monitoring = not is_authoring()
	_area.collision_layer = 0
	_area.collision_mask = (
		CollisionLayers.LAYER_PLAYERS | CollisionLayers.LAYER_ENEMIES
		if filter_type in [FilterType.PLAYER_ONLY, FilterType.ENEMIES_ONLY]
		else 0xFFFFFFFF
	)
	_area.monitorable = false
	add_child(_area)

	# Collision shape
	_collision_shape = CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = zone_size
	_collision_shape.shape = box_shape
	_collision_shape.set_meta("editor_runtime_only", true)
	_area.add_child(_collision_shape)

	# Connect signals
	_area.body_entered.connect(_on_body_entered)
	_area.body_exited.connect(_on_body_exited)

	# Editor visualization
	if is_authoring() and show_in_editor:
		_create_visual()


func _create_visual() -> void:
	var visual := CSGBox3D.new()
	visual.name = "EditorVisual"
	visual.size = zone_size
	visual.use_collision = false

	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.2, 0.6, 0.9, 0.2)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	visual.material = material

	add_child(visual)

	# Hide in game unless debug
	if not Engine.is_editor_hint():
		visual.visible = show_in_editor


func _on_body_entered(body: Node3D) -> void:
	if is_authoring() or not _passes_filter(body):
		return
	if body not in _entities_inside:
		_entities_inside.append(body)
	_try_enter(body)


func _try_enter(body: Node3D) -> void:
	if (
		not _runtime_started
		or _restore_overlap_frames > 0
		or not is_enabled
		or (one_shot and activation_count > 0)
		or trigger_mode == TriggerMode.ON_EXIT
	):
		return
	if _body_identity(body) in _accepted_inside:
		return
	if trigger_mode == TriggerMode.WHILE_INSIDE and is_active:
		_accepted_inside.append(_body_identity(body))
		return
	trigger(body, {"event": "enter", "entity": body})


func _physics_process(_delta: float) -> void:
	if is_authoring() or not _runtime_started:
		return
	if _restore_overlap_frames > 0:
		_restore_overlap_frames -= 1
		if _restore_overlap_frames > 0:
			return
		_entities_inside.clear()
		var present: Array[String] = []
		for body: Node3D in _area.get_overlapping_bodies():
			if _passes_filter(body):
				_entities_inside.append(body)
				present.append(_body_identity(body))
		for index: int in range(_accepted_inside.size() - 1, -1, -1):
			if _accepted_inside[index] not in present:
				_accepted_inside.remove_at(index)
	# A player can enter the return zone before its prerequisite completes.
	# Retry unaccepted occupants, never completed one-shot or accepted entries.
	for index: int in range(_entities_inside.size() - 1, -1, -1):
		var body := _entities_inside[index]
		if not is_instance_valid(body):
			_entities_inside.remove_at(index)
		elif body is Node3D:
			_try_enter(body)


func trigger(source: Node = null, data: Dictionary = {}) -> void:
	if not _runtime_started or not _prerequisites_met():
		return
	super.trigger(source, data)


func _do_activate(data: Dictionary) -> void:
	if not _runtime_started or not _prerequisites_met():
		return
	var source: Node = data.get("source")
	if is_instance_valid(source) and source in _entities_inside:
		var identity := _body_identity(source)
		if identity in _accepted_inside:
			return
		_accepted_inside.append(identity)
	super._do_activate(data)


func _prerequisites_met() -> bool:
	var mission := MissionMgr.get_instance()
	return not mission or mission.can_activate_actor(self)


func _body_identity(body: Node) -> String:
	if body.is_in_group("player"):
		return "player:%d" % body.get_multiplayer_authority()
	return str(body.get_path())


func _on_body_exited(body: Node3D) -> void:
	if is_authoring() or body not in _entities_inside:
		return
	_entities_inside.erase(body)
	_accepted_inside.erase(_body_identity(body))
	if not _runtime_started or _restore_overlap_frames > 0:
		return
	match trigger_mode:
		TriggerMode.ON_EXIT:
			trigger(body, {"event": "exit", "entity": body})
		TriggerMode.ON_ENTER_EXIT, TriggerMode.WHILE_INSIDE:
			if is_active and _entities_inside.is_empty():
				deactivate()


func capture_runtime_state() -> Dictionary:
	var state := super.capture_runtime_state()
	state["trigger"] = {"accepted_inside": _accepted_inside.duplicate()}
	return state


func validate_runtime_state(state: Dictionary) -> bool:
	if not super.validate_runtime_state(state) or not state.get("trigger") is Dictionary:
		return false
	if not state.trigger.get("accepted_inside") is Array:
		return false
	var seen: Array[String] = []
	for identity: Variant in state.trigger.accepted_inside:
		if not identity is String or identity.is_empty() or identity in seen:
			return false
		seen.append(identity)
	return true


func restore_runtime_state(state: Dictionary) -> bool:
	if not validate_runtime_state(state) or not super.restore_runtime_state(state):
		return false
	_accepted_inside.assign(state.trigger.accepted_inside)
	# Area overlap lists lag teleported checkpoint bodies by a physics tick.
	_restore_overlap_frames = 2
	return true


func _passes_filter(body: Node) -> bool:
	match filter_type:
		FilterType.PLAYER_ONLY:
			return body.is_in_group("player")
		FilterType.ENEMIES_ONLY:
			return body.is_in_group("enemy") or body.is_in_group("enemies")
		FilterType.ANY_ENTITY:
			return true
		FilterType.SPECIFIC_GROUP:
			return body.is_in_group(filter_group)
	return false


## Update zone size dynamically


func set_zone_size(new_size: Vector3) -> void:
	zone_size = new_size
	if _collision_shape and _collision_shape.shape is BoxShape3D:
		_collision_shape.shape.size = new_size

	# Update visual
	var visual: Node = get_node_or_null("EditorVisual")
	if visual and visual is CSGBox3D:
		visual.size = new_size


func get_inspector_properties() -> Array[Dictionary]:
	var props: Array[Dictionary] = super.get_inspector_properties()
	props.append_array(
		[
			{
				"name": "trigger_mode",
				"type": TYPE_INT,
				"label": "Trigger Mode",
				"hint": PROPERTY_HINT_ENUM,
				"hint_string": "On Enter,On Exit,While Inside,Enter/Exit"
			},
			{
				"name": "filter_type",
				"type": TYPE_INT,
				"label": "Filter Type",
				"hint": PROPERTY_HINT_ENUM,
				"hint_string": "Player Only,Enemies Only,Any Entity,Specific Group"
			},
			{
				"name": "filter_group",
				"type": TYPE_STRING,
				"label": "Filter Group",
				"description": "Group name for Specific Group filter"
			},
			{
				"name": "zone_size",
				"type": TYPE_VECTOR3,
				"label": "Zone Size",
				"description": "Size of the trigger zone"
			},
			{
				"name": "show_in_editor",
				"type": TYPE_BOOL,
				"label": "Show Zone Visual",
				"description": "Show zone boundary in editor"
			}
		]
	)
	return props


func get_gizmo_data() -> Dictionary:
	var data: Dictionary = super.get_gizmo_data()
	data["shape"] = "box"
	data["size"] = zone_size
	data["color"] = Color(0.2, 0.6, 0.9, 0.3)
	return data
