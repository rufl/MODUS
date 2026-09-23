@tool
class_name SwitchActor
extends "res://shared/editor_core/actors/actor_base.gd"

enum SwitchType { TOGGLE, MOMENTARY, HOLD }  ## Stays in new state until triggered again  ## Automatically resets after duration  ## Only active while held/stood on

@export var switch_type: SwitchType = SwitchType.TOGGLE
@export var momentary_duration: float = 0.5
@export var require_key: String = ""  ## If set, requires this key item to use

var switch_mesh: Node3D = null

var _momentary_timer: float = 0.0


func _init() -> void:
	actor_category = "activator"
	actor_name = "Switch"
	actor_description = "Interactive switch that activates connected actors"


func _on_actor_ready() -> void:
	_create_visual()


func _create_visual() -> void:
	var body := StaticBody3D.new()
	body.collision_layer = CollisionLayers.LAYER_INTERACTABLES
	body.collision_mask = 0
	body.name = "SwitchBody"
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.65, 0.65, 0.18)
	mesh.mesh = box
	mesh.material_override = StandardMaterial3D.new()
	body.add_child(mesh)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = box.size
	collision.shape = shape
	body.add_child(collision)
	add_child(body)
	switch_mesh = mesh
	_update_visual()


func _process(delta: float) -> void:
	super._process(delta)

	# Handle momentary auto-reset
	if switch_type == SwitchType.MOMENTARY and is_active:
		_momentary_timer -= delta
		if _momentary_timer <= 0:
			deactivate()


func _on_activated(_data: Dictionary) -> void:
	if switch_type == SwitchType.MOMENTARY:
		_momentary_timer = momentary_duration

	_update_visual()


func _on_deactivated() -> void:
	_update_visual()


func _update_visual() -> void:
	if switch_mesh is MeshInstance3D:
		var material := switch_mesh.material_override as StandardMaterial3D
		material.albedo_color = Color(0.1, 0.85, 0.65) if is_active else Color(0.95, 0.45, 0.1)
		material.emission_enabled = true
		material.emission = material.albedo_color
		material.emission_energy_multiplier = 0.6


## Called when player interacts


func get_interaction_prompt() -> String:
	if not require_key.is_empty() and not is_active:
		return "Activate (Requires %s)" % require_key
	return "Deactivate" if is_active else "Activate"


func interact(player: Node = null) -> bool:
	if not is_enabled or is_authoring() or (one_shot and activation_count > 0):
		return false
	if not require_key.is_empty():
		if not player or not player.has_method("has_item") or not player.has_item(require_key):
			return false
	var mission := MissionMgr.get_instance()
	if mission and not mission.can_activate_actor(self):
		return false
	if switch_type == SwitchType.TOGGLE and is_active:
		deactivate()
	else:
		trigger(player, {"interacted": true})
	return true


## For hold-type: called when released


func release() -> void:
	if switch_type == SwitchType.HOLD:
		deactivate()


func restore_runtime_state(state: Dictionary) -> bool:
	if not super.restore_runtime_state(state):
		return false
	_momentary_timer = momentary_duration if is_active else 0.0
	_update_visual()
	return true


func get_inspector_properties() -> Array[Dictionary]:
	var props: Array[Dictionary] = super.get_inspector_properties()
	props.append_array(
		[
			{
				"name": "switch_type",
				"type": TYPE_INT,
				"label": "Switch Type",
				"hint": PROPERTY_HINT_ENUM,
				"hint_string": "Toggle,Momentary,Hold"
			},
			{
				"name": "momentary_duration",
				"type": TYPE_FLOAT,
				"label": "Momentary Duration",
				"description": "How long momentary switch stays active"
			},
			{
				"name": "require_key",
				"type": TYPE_STRING,
				"label": "Required Key",
				"description": "Key item needed to use this switch"
			}
		]
	)
	return props
