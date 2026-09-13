@tool
class_name SecretWallActor
extends "res://shared/editor_core/actors/actor_base.gd"

enum TriggerType { CHANNEL, PROXIMITY, SHOOTABLE, INTERACT }  ## Activated via channel system (switches, buttons)  ## Opens when player gets close  ## Opens when shot  ## Opens when player presses E
enum MoveType { SLIDE_X, SLIDE_Y, SLIDE_Z, ROTATE_Y, LOWER, RAISE }  ## Slides along X axis  ## Slides up/down  ## Slides along Z axis  ## Rotates around Y axis  ## Lowers into floor  ## Raises into ceiling

@export var trigger_type: TriggerType = TriggerType.CHANNEL
@export var move_type: MoveType = MoveType.SLIDE_X
@export var move_direction: Vector3 = Vector3.RIGHT
@export var move_distance: float = 2.0
@export var move_speed: float = 1.0
@export var one_time_use: bool = true
@export var show_secret_message: bool = true
@export var secret_message: String = "Secret discovered!"
@export_group("Proximity Settings")
@export var proximity_range: float = 3.0
@export var proximity_check_interval: float = 0.5
@export_group("Shootable Settings")
@export var health: float = 10.0


class WallBody:
	extends AnimatableBody3D

	func take_damage(info: Variant, _type: Variant = null, source: Node = null) -> void:
		get_parent().take_damage(info, source)


var wall_mesh: MeshInstance3D = null
var wall_body: StaticBody3D = null
var _wall_collision: CollisionShape3D = null
var _closed_transform: Transform3D
var _open_transform: Transform3D
var _is_open: bool = false
var _open_progress: float = 0.0
var _proximity_timer: float = 0.0
var _current_health: float = 0.0
var _runtime_started: bool = false


func _init() -> void:
	actor_category = "mover"
	actor_name = "Secret Wall"
	actor_description = "Hidden wall that opens when triggered"


func _on_actor_ready() -> void:
	_create_visual()
	_calculate_transforms()
	_current_health = maxf(health, 0.0)


func start_runtime() -> void:
	if is_authoring():
		return
	_runtime_started = true
	super.start_runtime()


func _create_visual() -> void:
	wall_body = WallBody.new()
	wall_body.name = "WallBody"
	wall_body.collision_layer = CollisionLayers.LAYER_WORLD | CollisionLayers.LAYER_DEBRIS
	wall_body.set_meta("editor_runtime_only", true)
	add_child(wall_body)
	wall_mesh = MeshInstance3D.new()
	wall_mesh.name = "WallMesh"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(2.0, 2.5, 0.2)
	wall_mesh.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.5, 0.5, 0.5)
	wall_mesh.material_override = material
	wall_mesh.set_meta("editor_runtime_only", true)
	wall_body.add_child(wall_mesh)
	_wall_collision = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = mesh.size
	_wall_collision.shape = box
	_wall_collision.set_meta("editor_runtime_only", true)
	wall_body.add_child(_wall_collision)


func _calculate_transforms() -> void:
	_closed_transform = Transform3D.IDENTITY
	_open_transform = _closed_transform
	match move_type:
		MoveType.SLIDE_X:
			_open_transform.origin.x += move_distance * move_direction.x
		MoveType.SLIDE_Y, MoveType.RAISE:
			_open_transform.origin.y += move_distance
		MoveType.SLIDE_Z:
			_open_transform.origin.z += move_distance * move_direction.z
		MoveType.ROTATE_Y:
			_open_transform = _open_transform.rotated(Vector3.UP, PI * 0.5)
		MoveType.LOWER:
			_open_transform.origin.y -= move_distance


func _process(delta: float) -> void:
	if is_authoring() or not _runtime_started:
		return
	super._process(delta)
	if not is_enabled:
		return
	if _is_open and _open_progress < 1.0:
		_open_progress = minf(
			1.0, _open_progress + delta * maxf(move_speed, 0.01) / maxf(absf(move_distance), 0.01)
		)
		_update_wall()
	if trigger_type == TriggerType.PROXIMITY and not _is_open:
		_proximity_timer += delta
		if _proximity_timer >= maxf(proximity_check_interval, 0.01):
			_proximity_timer = 0.0
			_check_proximity()


func _check_proximity() -> void:
	for player: Node in get_tree().get_nodes_in_group("player"):
		if (
			player is Node3D
			and global_position.distance_to(player.global_position) <= proximity_range
		):
			open_wall(player)
			break


func take_damage(info: Variant, source: Node = null) -> void:
	if info is DamageInfo:
		receive_damage(
			info.final_damage if info.final_damage > 0.0 else info.base_amount, info.source
		)
	elif info is int or info is float:
		receive_damage(float(info), source)


func receive_damage(amount: float, source: Node = null) -> void:
	if (
		is_authoring()
		or not _runtime_started
		or not is_enabled
		or _is_open
		or trigger_type != TriggerType.SHOOTABLE
	):
		return
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	if not is_finite(amount) or amount <= 0.0:
		return
	_current_health = maxf(0.0, _current_health - amount)
	if _current_health <= 0.0:
		open_wall(source)


func _do_activate(data: Dictionary) -> void:
	if (
		is_authoring()
		or not _runtime_started
		or _is_open
		or (one_time_use and activation_count > 0)
	):
		return
	super._do_activate(data)


func _on_activated(data: Dictionary) -> void:
	_is_open = true
	_update_wall()
	var source: Node = data.get("source")
	if show_secret_message and is_instance_valid(source):
		_show_secret_notification(source)


func open_wall(source: Node = null) -> void:
	trigger(source, {"secret": true})


func _update_wall() -> void:
	if wall_body:
		wall_body.transform = _closed_transform.interpolate_with(_open_transform, _open_progress)
	if _wall_collision:
		_wall_collision.set_deferred("disabled", _is_open)


func _show_secret_notification(player: Node) -> void:
	if player.has_method("show_notification"):
		player.show_notification(secret_message)
	elif GameManager and GameManager.has_method("show_message"):
		GameManager.show_message(secret_message)


func interact(player: Node = null) -> bool:
	if (
		is_authoring()
		or not _runtime_started
		or not is_enabled
		or _is_open
		or trigger_type != TriggerType.INTERACT
	):
		return false
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return false
	open_wall(player)
	return true


func capture_runtime_state() -> Dictionary:
	var state := super.capture_runtime_state()
	state["secret"] = {
		"open": _is_open,
		"progress": _open_progress,
		"health": _current_health,
		"proximity_timer": _proximity_timer
	}
	return state


func validate_runtime_state(state: Dictionary) -> bool:
	if not super.validate_runtime_state(state) or not state.get("secret") is Dictionary:
		return false
	var saved: Dictionary = state.secret
	if not saved.get("open") is bool:
		return false
	for key: String in ["progress", "health", "proximity_timer"]:
		var value: Variant = saved.get(key)
		if (
			not (value is int or value is float)
			or not is_finite(float(value))
			or float(value) < 0.0
		):
			return false
	if float(saved.progress) > 1.0 or float(saved.health) > maxf(health, 0.0):
		return false
	if not saved.open and float(saved.progress) != 0.0:
		return false
	if saved.open != (int(state.activation_count) > 0):
		return false
	return float(saved.proximity_timer) <= maxf(proximity_check_interval, 0.01)


func restore_runtime_state(state: Dictionary) -> bool:
	if not validate_runtime_state(state) or not super.restore_runtime_state(state):
		return false
	_is_open = state.secret.open
	_open_progress = float(state.secret.progress)
	_current_health = float(state.secret.health)
	_proximity_timer = float(state.secret.proximity_timer)
	_update_wall()
	return true


func get_inspector_properties() -> Array[Dictionary]:
	var props: Array[Dictionary] = super.get_inspector_properties()
	props.append_array(
		[
			{
				"name": "trigger_type",
				"type": TYPE_INT,
				"label": "Trigger Type",
				"hint": PROPERTY_HINT_ENUM,
				"hint_string": "Channel,Proximity,Shootable,Interact"
			},
			{
				"name": "move_type",
				"type": TYPE_INT,
				"label": "Movement Type",
				"hint": PROPERTY_HINT_ENUM,
				"hint_string": "Slide X,Slide Y,Slide Z,Rotate Y,Lower,Raise"
			},
			{
				"name": "move_distance",
				"type": TYPE_FLOAT,
				"label": "Move Distance",
				"description": "How far the wall moves when opening"
			},
			{
				"name": "move_speed",
				"type": TYPE_FLOAT,
				"label": "Move Speed",
				"description": "Speed of movement (units per second)"
			},
			{
				"name": "one_time_use",
				"type": TYPE_BOOL,
				"label": "One Time Use",
				"description": "Can only be opened once"
			},
			{"name": "show_secret_message", "type": TYPE_BOOL, "label": "Show Secret Message"},
			{"name": "secret_message", "type": TYPE_STRING, "label": "Secret Message"},
			{"name": "proximity_range", "type": TYPE_FLOAT, "label": "Proximity Range"},
			{"name": "health", "type": TYPE_FLOAT, "label": "Health (Shootable)"}
		]
	)
	return props
