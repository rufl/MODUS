@tool
class_name PlatformActor
extends "res://shared/editor_core/actors/actor_base.gd"

enum PlatformMode { ONCE, LOOP, PING_PONG, WAIT_TRIGGER }  ## Moves to end and stops  ## Loops back to start  ## Bounces between endpoints  ## Waits at each point for trigger

@export var platform_mode: PlatformMode = PlatformMode.PING_PONG
@export var platform_size: Vector3 = Vector3(2, 0.3, 2)
@export var move_speed: float = 2.0
@export var wait_at_points: float = 1.0
@export var waypoints: PackedVector3Array = PackedVector3Array([Vector3.ZERO, Vector3(0, 3, 0)])
@export var start_moving: bool = true
@export var carry_passengers: bool = true

var platform_mesh: MeshInstance3D = null
var platform_body: StaticBody3D = null

var _current_waypoint: int = 0
var _direction: int = 1
var _is_moving: bool = false
var _wait_timer: float = 0.0
var _finished: bool = false
var _motion_collision := KinematicCollision3D.new()


func _init() -> void:
	actor_category = "mover"
	actor_name = "Moving Platform"
	actor_description = "Platform that moves along waypoints"


func _on_actor_ready() -> void:
	if waypoints.is_empty():
		waypoints.append(Vector3.ZERO)
	_create_platform()
	_current_waypoint = 1 if waypoints.size() > 1 else 0


func _create_platform() -> void:
	platform_body = AnimatableBody3D.new() if carry_passengers else StaticBody3D.new()
	platform_body.name = "PlatformBody"
	platform_body.collision_mask = CollisionLayers.MASK_DAMAGEABLE
	if platform_body is AnimatableBody3D:
		platform_body.sync_to_physics = true
	platform_body.position = waypoints[0]
	platform_body.set_meta("editor_runtime_only", true)
	add_child(platform_body)

	platform_mesh = MeshInstance3D.new()
	platform_mesh.name = "PlatformMesh"
	var box_mesh := BoxMesh.new()
	box_mesh.size = platform_size
	platform_mesh.mesh = box_mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.4, 0.4, 0.5)
	platform_mesh.material_override = material
	platform_mesh.set_meta("editor_runtime_only", true)
	platform_body.add_child(platform_mesh)

	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = platform_size
	collision.shape = box
	collision.set_meta("editor_runtime_only", true)
	platform_body.add_child(collision)


func _physics_process(delta: float) -> void:
	if is_authoring() or not is_enabled or not is_active or not _is_moving:
		return
	if waypoints.size() < 2 or move_speed <= 0.0:
		return
	if _wait_timer > 0.0:
		var waited := minf(_wait_timer, delta)
		_wait_timer -= waited
		delta -= waited
		if delta <= 0.0:
			return

	# AnimatableBody3D supplies floor velocity to move_and_slide(), including
	# the arrival tick. Never add platform velocity to passenger.velocity.
	var target := waypoints[_current_waypoint]
	var next_position := platform_body.position.move_toward(target, move_speed * delta)
	var motion := global_basis * (next_position - platform_body.position)
	if platform_body.test_move(platform_body.global_transform, motion, _motion_collision):
		for index: int in range(_motion_collision.get_collision_count()):
			var normal := _motion_collision.get_normal(index)
			# Rising decks carry bodies above them; other contacts must not
			# push a character through the world while following the path.
			if not (motion.y > 0.0 and normal.y < -0.7):
				return
	platform_body.position = next_position
	if platform_body.position.is_equal_approx(target):
		platform_body.position = target
		_on_waypoint_reached()


func _on_waypoint_reached() -> void:
	_wait_timer = maxf(wait_at_points, 0.0)
	match platform_mode:
		PlatformMode.ONCE:
			if _current_waypoint == waypoints.size() - 1:
				_is_moving = false
				_finished = true
				_wait_timer = 0.0
			else:
				_current_waypoint += 1
		PlatformMode.LOOP:
			_current_waypoint = (_current_waypoint + 1) % waypoints.size()
		PlatformMode.PING_PONG, PlatformMode.WAIT_TRIGGER:
			if _current_waypoint == waypoints.size() - 1:
				_direction = -1
			elif _current_waypoint == 0:
				_direction = 1
			_current_waypoint += _direction
			if platform_mode == PlatformMode.WAIT_TRIGGER:
				_is_moving = false


func _on_activated(_data: Dictionary) -> void:
	# The initial activation isn't an external request to start a parked lift.
	_is_moving = not _finished and waypoints.size() > 1
	if activation_count == 1 and starts_active and _data.is_empty():
		_is_moving = _is_moving and start_moving


func _on_deactivated() -> void:
	_is_moving = false


func capture_runtime_state() -> Dictionary:
	var state := super.capture_runtime_state()
	var offset := platform_body.position if platform_body else waypoints[0]
	state["platform"] = {
		"position": [offset.x, offset.y, offset.z],
		"target": _current_waypoint,
		"direction": _direction,
		"moving": _is_moving,
		"wait": _wait_timer,
		"finished": _finished
	}
	return state


func validate_runtime_state(state: Dictionary) -> bool:
	if not super.validate_runtime_state(state) or not state.get("platform") is Dictionary:
		return false
	var phase: Dictionary = state.platform
	if not phase.get("position") is Array or phase.position.size() != 3:
		return false
	for coordinate: Variant in phase.position:
		if not _finite_number(coordinate):
			return false
	if (
		not _finite_number(phase.get("target"))
		or float(phase.target) != floorf(float(phase.target))
	):
		return false
	if int(phase.target) < 0 or int(phase.target) >= waypoints.size():
		return false
	if not _finite_number(phase.get("direction")) or float(phase.direction) not in [-1.0, 1.0]:
		return false
	if not phase.get("moving") is bool or not phase.get("finished") is bool:
		return false
	if (
		not _finite_number(phase.get("wait"))
		or float(phase.wait) < 0.0
		or float(phase.wait) > maxf(wait_at_points, 0.0)
	):
		return false
	if phase.finished and (phase.moving or platform_mode != PlatformMode.ONCE):
		return false
	if phase.moving and (not state.is_active or waypoints.size() < 2):
		return false
	var offset := Vector3(phase.position[0], phase.position[1], phase.position[2])
	var target := int(phase.target)
	if waypoints.size() == 1:
		return target == 0 and offset.is_equal_approx(waypoints[0]) and not phase.moving
	if phase.finished:
		return target == waypoints.size() - 1 and offset.is_equal_approx(waypoints[-1])
	var direction := int(phase.direction)
	if platform_mode in [PlatformMode.ONCE, PlatformMode.LOOP] and direction != 1:
		return false
	var previous := target - direction
	if platform_mode == PlatformMode.LOOP and target == 0:
		previous = waypoints.size() - 1
	if previous < 0 or previous >= waypoints.size():
		return false
	# Reject a valid route coordinate paired with an unrelated movement phase.
	return (
		offset.distance_to(
			Geometry3D.get_closest_point_to_segment(offset, waypoints[previous], waypoints[target])
		)
		< 0.001
	)


func restore_runtime_state(state: Dictionary) -> bool:
	if not validate_runtime_state(state) or not super.restore_runtime_state(state):
		return false
	var phase: Dictionary = state.platform
	_current_waypoint = int(phase.target)
	_direction = int(phase.direction)
	_is_moving = phase.moving
	_wait_timer = float(phase.wait)
	_finished = phase.finished
	if platform_body:
		# Restoration is a teleport, not one tick of platform travel.
		if platform_body is AnimatableBody3D:
			platform_body.sync_to_physics = false
		platform_body.position = Vector3(phase.position[0], phase.position[1], phase.position[2])
		platform_body.reset_physics_interpolation()
		if platform_body is AnimatableBody3D:
			platform_body.sync_to_physics = true
	return true


func _finite_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))


func get_inspector_properties() -> Array[Dictionary]:
	var props: Array[Dictionary] = super.get_inspector_properties()
	props.append_array(
		[
			{
				"name": "platform_mode",
				"type": TYPE_INT,
				"label": "Mode",
				"hint": PROPERTY_HINT_ENUM,
				"hint_string": "Once,Loop,Ping Pong,Wait Trigger"
			},
			{"name": "platform_size", "type": TYPE_VECTOR3, "label": "Size"},
			{"name": "move_speed", "type": TYPE_FLOAT, "label": "Speed"},
			{"name": "wait_at_points", "type": TYPE_FLOAT, "label": "Wait Time"}
		]
	)
	return props


func get_gizmo_data() -> Dictionary:
	var data: Dictionary = super.get_gizmo_data()
	data["waypoints"] = waypoints
	data["show_path"] = true
	return data
