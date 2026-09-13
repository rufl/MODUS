@tool
class_name DoorActor
extends "res://shared/editor_core/actors/actor_base.gd"

enum DoorType { SLIDE_X, SLIDE_Y, SLIDE_Z, ROTATE_Y, DOUBLE_SLIDE }  ## Slides along X axis  ## Slides up (raising door)  ## Slides along Z axis  ## Rotates around Y axis (swing door)  ## Two panels slide apart
enum OpenDirection { POSITIVE, NEGATIVE, AUTO }  ## Opens in positive axis direction  ## Opens in negative axis direction  ## Opens away from player

@export var door_type: DoorType = DoorType.SLIDE_Y
@export var open_direction: OpenDirection = OpenDirection.POSITIVE
@export var open_distance: float = 2.5
@export var open_angle: float = 90.0  ## For ROTATE_Y type
@export var open_duration: float = 0.5
@export var close_duration: float = 0.5
@export var auto_close: bool = false
@export var auto_close_delay: float = 3.0
@export var locked: bool = false
@export var required_key: String = ""
@export var door_size := Vector3(1.5, 2.5, 0.2)
@export var require_channel: bool = false

var door_mesh: Node3D = null

var _closed_transform: Transform3D
var _open_transform: Transform3D
var _current_tween: Tween = null
var _auto_close_timer: float = 0.0
var _second_leaf: Node3D
var _second_closed: Transform3D
var _second_open: Transform3D


func _init() -> void:
	actor_category = "mover"
	actor_name = "Door"
	actor_description = "Animated door that opens/closes"


func _on_actor_ready() -> void:
	_create_visual()
	_calculate_transforms()


func _create_visual() -> void:
	var leaf_size := door_size
	if door_type == DoorType.DOUBLE_SLIDE:
		leaf_size.x *= 0.5
	door_mesh = _create_leaf(leaf_size)
	door_mesh.name = "DoorLeaf"
	if door_type == DoorType.DOUBLE_SLIDE:
		door_mesh.position.x = -door_size.x * 0.25
		_second_leaf = _create_leaf(leaf_size)
		_second_leaf.name = "SecondDoorLeaf"
		_second_leaf.position.x = door_size.x * 0.25
	_closed_transform = door_mesh.transform


func _create_leaf(size: Vector3) -> AnimatableBody3D:
	var body := AnimatableBody3D.new()
	body.sync_to_physics = false
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.11, 0.21, 0.24)
	material.metallic = 0.7
	material.roughness = 0.4
	mesh.material_override = material
	body.add_child(mesh)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	add_child(body)
	return body


func _calculate_transforms() -> void:
	if not door_mesh:
		return

	# The closed pose is immutable while an animation is in flight.
	_open_transform = _closed_transform

	var direction: float = -1.0 if open_direction == OpenDirection.NEGATIVE else 1.0

	match door_type:
		DoorType.SLIDE_X:
			_open_transform.origin.x += open_distance * direction
		DoorType.SLIDE_Y:
			_open_transform.origin.y += open_distance * direction
		DoorType.SLIDE_Z:
			_open_transform.origin.z += open_distance * direction
		DoorType.ROTATE_Y:
			var angle: float = deg_to_rad(open_angle * direction)
			_open_transform = _open_transform.rotated(Vector3.UP, angle)
		DoorType.DOUBLE_SLIDE:
			_open_transform.origin.x -= open_distance * 0.5
			_second_closed = _second_leaf.transform
			_second_open = _second_closed
			_second_open.origin.x += open_distance * 0.5


func _process(delta: float) -> void:
	super._process(delta)

	# Handle auto-close
	if auto_close and is_active:
		_auto_close_timer -= delta
		if _auto_close_timer <= 0:
			deactivate()


func _on_activated(data: Dictionary) -> void:
	var source: Node = data.get("source")
	locked = false
	if open_direction == OpenDirection.AUTO and source is Node3D:
		var direction := (
			1.0 if (source.global_position - global_position).dot(-global_basis.z) >= 0.0 else -1.0
		)
		if door_type == DoorType.ROTATE_Y:
			_open_transform = _closed_transform.rotated(
				Vector3.UP, deg_to_rad(open_angle * direction)
			)
		elif door_type == DoorType.SLIDE_X:
			_open_transform.origin.x = _closed_transform.origin.x + open_distance * direction
		elif door_type == DoorType.SLIDE_Z:
			_open_transform.origin.z = _closed_transform.origin.z + open_distance * direction
	_animate_door(_open_transform, open_duration)
	_auto_close_timer = auto_close_delay


func _on_deactivated() -> void:
	_animate_door(_closed_transform, close_duration)


func trigger(source: Node = null, data: Dictionary = {}) -> void:
	if (
		locked
		and (
			required_key.is_empty()
			or not source
			or not source.has_method("has_item")
			or not source.has_item(required_key)
		)
	):
		return
	super.trigger(source, data)


func open_door(source: Node = null) -> void:
	trigger(source)


func close_door() -> void:
	deactivate()


func _animate_door(target: Transform3D, duration: float) -> void:
	if not door_mesh:
		return

	# Cancel existing tween
	if _current_tween and _current_tween.is_valid():
		_current_tween.kill()

	_current_tween = create_tween()
	_current_tween.set_trans(Tween.TRANS_SINE)
	_current_tween.set_ease(Tween.EASE_IN_OUT)
	_current_tween.tween_property(door_mesh, "transform", target, duration)
	if is_instance_valid(_second_leaf):
		_current_tween.parallel().tween_property(
			_second_leaf, "transform", _second_open if is_active else _second_closed, duration
		)


func interact(player: Node = null) -> bool:
	if require_channel:
		return false
	if is_active:
		deactivate()
	else:
		trigger(player, {"interacted": true})
	return is_active or not locked


func capture_runtime_state() -> Dictionary:
	var state := super.capture_runtime_state()
	state["locked"] = locked
	return state


func restore_runtime_state(state: Dictionary) -> bool:
	if not state.get("locked") is bool or not super.restore_runtime_state(state):
		return false
	locked = state["locked"]
	if _current_tween and _current_tween.is_valid():
		_current_tween.kill()
	door_mesh.transform = _open_transform if is_active else _closed_transform
	if is_instance_valid(_second_leaf):
		_second_leaf.transform = _second_open if is_active else _second_closed
	_auto_close_timer = auto_close_delay if is_active else 0.0
	return true


func get_inspector_properties() -> Array[Dictionary]:
	var props: Array[Dictionary] = super.get_inspector_properties()
	props.append_array(
		[
			{
				"name": "door_type",
				"type": TYPE_INT,
				"label": "Door Type",
				"hint": PROPERTY_HINT_ENUM,
				"hint_string": "Slide X,Slide Y,Slide Z,Rotate Y,Double Slide"
			},
			{
				"name": "open_direction",
				"type": TYPE_INT,
				"label": "Open Direction",
				"hint": PROPERTY_HINT_ENUM,
				"hint_string": "Positive,Negative,Auto"
			},
			{
				"name": "open_distance",
				"type": TYPE_FLOAT,
				"label": "Open Distance",
				"description": "How far the door moves when opening"
			},
			{
				"name": "open_angle",
				"type": TYPE_FLOAT,
				"label": "Open Angle",
				"description": "Rotation angle for swing doors"
			},
			{"name": "open_duration", "type": TYPE_FLOAT, "label": "Open Duration"},
			{
				"name": "auto_close",
				"type": TYPE_BOOL,
				"label": "Auto Close",
				"description": "Automatically close after delay"
			},
			{"name": "auto_close_delay", "type": TYPE_FLOAT, "label": "Auto Close Delay"},
			{"name": "locked", "type": TYPE_BOOL, "label": "Locked"},
			{"name": "door_size", "type": TYPE_VECTOR3, "label": "Door Size"},
			{"name": "require_channel", "type": TYPE_BOOL, "label": "Channel Only"},
			{"name": "required_key", "type": TYPE_STRING, "label": "Required Key"}
		]
	)
	return props
