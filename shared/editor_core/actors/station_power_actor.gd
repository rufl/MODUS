@tool
class_name StationPowerActor
extends "res://shared/editor_core/actors/actor_base.gd"

## Presentation notification, deliberately separate from gameplay/channel activation.
signal power_applied(powered: bool, restored: bool)

@export var target_group: String = ""
@export_range(0.0, 16.0) var off_energy: float = 0.1
@export_range(0.0, 16.0) var on_energy: float = 1.2
@export var off_color: Color = Color(1.0, 0.67, 0.34)
@export var on_color: Color = Color(0.55, 0.86, 0.9)

var _lights: Array[Light3D] = []


func _init() -> void:
	actor_name = "Station Power"
	actor_category = "effect"
	actor_description = "Powers light and presentation groups inside this authored document"


func start_runtime() -> void:
	if is_authoring():
		return
	_collect_lights()
	super.start_runtime()
	_apply_power(true)


func _collect_lights() -> void:
	_lights.clear()
	var document := get_level_document()
	if not document or target_group.is_empty():
		return
	for node: Node in get_tree().get_nodes_in_group(target_group):
		if node is Light3D and document.is_ancestor_of(node):
			_lights.append(node)


func _on_activated(_data: Dictionary) -> void:
	_apply_power()


func _on_deactivated() -> void:
	_apply_power()


func _apply_power(restored: bool = false) -> void:
	for light: Light3D in _lights:
		if is_instance_valid(light):
			light.light_energy = on_energy if is_active else off_energy
			light.light_color = on_color if is_active else off_color
	power_applied.emit(is_active, restored)


func restore_runtime_state(state: Dictionary) -> bool:
	if not super.restore_runtime_state(state):
		return false
	_apply_power(true)
	return true


func _on_reset() -> void:
	_apply_power(true)


func get_inspector_properties() -> Array[Dictionary]:
	var properties := super.get_inspector_properties()
	properties.append_array(
		[
			{"name": "target_group", "type": TYPE_STRING, "label": "Document light group"},
			{"name": "off_energy", "type": TYPE_FLOAT, "label": "Unpowered light energy"},
			{"name": "on_energy", "type": TYPE_FLOAT, "label": "Powered light energy"},
			{"name": "off_color", "type": TYPE_COLOR, "label": "Unpowered light color"},
			{"name": "on_color", "type": TYPE_COLOR, "label": "Powered light color"}
		]
	)
	return properties
