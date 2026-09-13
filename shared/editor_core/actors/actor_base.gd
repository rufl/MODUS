@tool
class_name ActorBase
extends Node3D

signal activated(data: Dictionary)
signal deactivated
signal state_changed(new_state: bool)

@export var actor_id: String = ""
@export var actor_name: String = "Actor"
@export var actor_category: String = "generic"
@export var actor_description: String = ""
@export var output_channel: String = ""
@export var input_channels: PackedStringArray = []
@export var is_enabled: bool = true
@export var starts_active: bool = false
@export var one_shot: bool = false
@export var activation_delay: float = 0.0
@export var deactivation_delay: float = 0.0
@export var cooldown: float = 0.0

var is_active: bool = false
var activation_count: int = 0

var _cooldown_timer: float = 0.0
var _delay_timer: float = 0.0
var _is_delaying: bool = false
var _pending_action: String = ""  # "activate" or "deactivate"
var _pending_data: Dictionary = {}
var _initial_activation_pending: bool = false
var _actor_runtime_started: bool = false


func _ready() -> void:
	# Mark as editor-placed
	set_meta("level_editor_placed", true)
	set_meta("actor_type", actor_category)

	# Generated geometry is rebuilt on every instance, not serialized into it.
	var authored_children := get_children()
	_on_actor_ready()
	for child: Node in get_children():
		if child not in authored_children:
			child.set_meta("editor_runtime_only", true)

	var system := _find_channel_system()
	if system:
		system.get_binding_id(self)
		if not output_channel.is_empty():
			system.connect_source(self, output_channel)
		for channel: String in input_channels:
			system.connect_target(self, channel)
	if not is_authoring():
		_initial_activation_pending = starts_active
		var document := get_level_document()
		if not document or not document.get_meta("document_runtime_session", false):
			call_deferred("start_runtime")
	if is_authoring():
		set_process(false)
		set_physics_process(false)
		set_process_input(false)
		set_process_unhandled_input(false)


## Documents start actors only after navigation, player and mission initialization.
func start_runtime() -> void:
	if _actor_runtime_started or is_authoring():
		return
	_actor_runtime_started = true
	_activate_initial_state()


func _activate_initial_state() -> void:
	if _initial_activation_pending:
		_initial_activation_pending = false
		trigger()


func _process(delta: float) -> void:
	# Handle cooldown
	if _cooldown_timer > 0:
		_cooldown_timer -= delta

	# Handle delayed activation
	if _is_delaying:
		_delay_timer -= delta
		if _delay_timer <= 0:
			_is_delaying = false
			var action := _pending_action
			var data := _pending_data
			_pending_action = ""
			_pending_data = {}
			if action == "activate":
				_do_activate(data)
			elif action == "deactivate":
				_do_deactivate()


## Override in subclasses for custom ready logic


func _on_actor_ready() -> void:
	pass


## Trigger activation from external source


func trigger(source: Node = null, data: Dictionary = {}) -> void:
	if not is_enabled or is_authoring():
		return
	var mission := MissionMgr.get_instance()
	if mission and not mission.can_activate_actor(self):
		return

	if one_shot and activation_count > 0:
		return

	if _cooldown_timer > 0 or _is_delaying:
		return

	var payload := data.duplicate()
	payload["source"] = source

	# Handle delay
	if activation_delay > 0 and not _is_delaying:
		_is_delaying = true
		_delay_timer = activation_delay
		_pending_action = "activate"
		_pending_data = payload
		return

	_do_activate(payload)


## Internal activation


func _do_activate(data: Dictionary) -> void:
	if is_authoring():
		return
	is_active = true
	activation_count += 1

	if cooldown > 0:
		_cooldown_timer = cooldown

	# Notify
	activated.emit(data)
	state_changed.emit(true)

	# Override point
	_on_activated(data)

	# Emit to output channel
	_emit_to_channel(true, data)


## Override in subclasses


func _on_activated(_data: Dictionary) -> void:
	pass


## Deactivate the actor


func deactivate() -> void:
	if not is_active or is_authoring() or _is_delaying:
		return

	# Handle delay
	if deactivation_delay > 0 and not _is_delaying:
		_is_delaying = true
		_delay_timer = deactivation_delay
		_pending_action = "deactivate"
		return

	_do_deactivate()


## Internal deactivation


func _do_deactivate() -> void:
	if is_authoring():
		return
	is_active = false

	deactivated.emit()
	state_changed.emit(false)

	_on_deactivated()

	_emit_to_channel(false, {})


## Override in subclasses


func _on_deactivated() -> void:
	pass


## Toggle state


func toggle() -> void:
	if is_active:
		deactivate()
	else:
		trigger(null, {})


## Emit to output channel


func _emit_to_channel(value: bool, data: Dictionary) -> void:
	var channel_system: Node = _find_channel_system()
	if channel_system:
		channel_system.emit_from(self, value, data)


## Find ChannelSystem in tree


func _find_channel_system() -> Node:
	var current: Node = get_parent()
	while current:
		if current.has_method("get_channel_system"):
			return current.get_channel_system()
		current = current.get_parent()
	return null


func get_level_document() -> Node3D:
	var current: Node = get_parent()
	while current:
		if current is Node3D and current.has_method("get_actor_identity"):
			return current
		current = current.get_parent()
	return null


func is_authoring() -> bool:
	if Engine.is_editor_hint():
		return true
	var current: Node = get_parent()
	while current:
		if "authoring_mode" in current:
			return bool(current.get("authoring_mode"))
		current = current.get_parent()
	return false


## Handle input from channel


func receive_channel_input(channel: String, data: Dictionary) -> void:
	# Membership is owned by ChannelSystem, including visual-editor connections.
	var value: bool = data.get("value", true)
	if value:
		trigger(data.get("source"), data)
	else:
		deactivate()


## Reset to initial state


func reset() -> void:
	is_active = starts_active
	activation_count = 0
	_cooldown_timer = 0.0
	_delay_timer = 0.0
	_is_delaying = false
	_pending_action = ""
	_pending_data = {}

	_on_reset()


func capture_runtime_state() -> Dictionary:
	return {"enabled": is_enabled, "is_active": is_active, "activation_count": activation_count}


func validate_runtime_state(state: Dictionary) -> bool:
	if not state.get("enabled") is bool or not state.get("is_active") is bool:
		return false
	var count: Variant = state.get("activation_count")
	return (
		(count is int or (count is float and is_finite(count) and count == floor(count)))
		and count >= 0
	)


func restore_runtime_state(state: Dictionary) -> bool:
	if not validate_runtime_state(state):
		return false
	is_enabled = state.enabled
	is_active = state.is_active
	activation_count = int(state.activation_count)
	_cooldown_timer = 0.0
	_delay_timer = 0.0
	_is_delaying = false
	_pending_action = ""
	_pending_data = {}
	_initial_activation_pending = false
	return true


## Override for custom reset


func _on_reset() -> void:
	pass


## Get inspector properties for editor UI


func get_inspector_properties() -> Array[Dictionary]:
	return [
		{
			"name": "is_enabled",
			"type": TYPE_BOOL,
			"label": "Enabled",
			"description": "Whether this actor responds to triggers"
		},
		{
			"name": "starts_active",
			"type": TYPE_BOOL,
			"label": "Starts Active",
			"description": "Whether this actor is active when the level starts"
		},
		{
			"name": "one_shot",
			"type": TYPE_BOOL,
			"label": "One Shot",
			"description": "If true, can only be activated once"
		},
		{
			"name": "activation_delay",
			"type": TYPE_FLOAT,
			"label": "Activation Delay",
			"description": "Delay before activation (seconds)"
		},
		{
			"name": "cooldown",
			"type": TYPE_FLOAT,
			"label": "Cooldown",
			"description": "Time before can be triggered again"
		},
		{
			"name": "output_channel",
			"type": TYPE_STRING,
			"label": "Output Channel",
			"description": "Channel to emit to when activated"
		}
	]


## Get gizmo data for editor visualization


func get_gizmo_data() -> Dictionary:
	return {
		"type": "actor",
		"category": actor_category,
		"color": _get_category_color(),
		"icon": _get_category_icon(),
		"connections": _get_connection_targets()
	}


func _get_category_color() -> Color:
	match actor_category:
		"activator":
			return Color(0.4, 0.8, 0.4)  # Green
		"effect":
			return Color(0.8, 0.8, 0.4)  # Yellow
		"hazard":
			return Color(0.9, 0.3, 0.1)  # Orange-red
		"mover":
			return Color(0.6, 0.4, 0.8)  # Purple
		"trigger":
			return Color(0.4, 0.6, 0.8)  # Blue
		_:
			return Color(0.5, 0.5, 0.5)  # Gray


func _get_category_icon() -> String:
	match actor_category:
		"activator":
			return "⚡"
		"effect":
			return "✨"
		"hazard":
			return "☠️"
		"mover":
			return "🚪"
		"trigger":
			return "🎯"
		_:
			return "📦"


func _get_connection_targets() -> Array[NodePath]:
	var targets: Array[NodePath] = []
	var system := _find_channel_system()
	if system:
		for connection: Dictionary in system.get_node_connections(self):
			if connection.role == "source" and is_instance_valid(connection.other):
				targets.append(get_path_to(connection.other))
	return targets
