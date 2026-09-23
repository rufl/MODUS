@tool
class_name KeyPickupActor
extends "res://shared/editor_core/actors/actor_base.gd"

@export var key_id: String = "maintenance"

var _body: StaticBody3D
var _collision: CollisionShape3D


func _init() -> void:
	actor_category = "activator"
	actor_name = "Key Pickup"
	actor_description = "One-use key card for keyed switches and doors"
	one_shot = true


func _on_actor_ready() -> void:
	_body = StaticBody3D.new()
	_body.name = "KeyCard"
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.5, 0.12, 0.3)
	mesh.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.65, 0.12)
	material.emission_enabled = true
	material.emission = Color(0.8, 0.35, 0.04)
	mesh.material_override = material
	_body.add_child(mesh)
	_collision = CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = box.size
	_collision.shape = shape
	_body.add_child(_collision)
	add_child(_body)
	_update_visual()


func interact(player: Node = null) -> bool:
	if is_authoring() or not is_enabled or activation_count > 0 or key_id.is_empty():
		return false
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return false
	if not player or not player.has_method("collect_key") or not player.has_method("has_item"):
		return false
	player.collect_key(key_id)
	if not player.has_item(key_id):
		return false
	trigger(player)
	return is_active


func get_interaction_prompt() -> String:
	return "Collected" if is_active else "Collect %s" % key_id


func _on_activated(_data: Dictionary) -> void:
	_update_visual()


func _on_reset() -> void:
	_update_visual()


func _update_visual() -> void:
	if is_instance_valid(_body):
		_body.visible = not is_active
		_collision.set_deferred("disabled", is_active)


func restore_runtime_state(state: Dictionary) -> bool:
	if not super.restore_runtime_state(state):
		return false
	_update_visual()
	return true


func get_inspector_properties() -> Array[Dictionary]:
	var properties := super.get_inspector_properties()
	properties.append({"name": "key_id", "type": TYPE_STRING, "label": "Key ID"})
	return properties
