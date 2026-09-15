@tool
class_name ModuleInstance
extends Node3D

@export var definition: PrefabMetadata
@export var instance_id: String = ""
@export var pinned: bool = false


func get_local_bounds() -> AABB:
	if definition == null:
		return AABB()
	return AABB(
		Vector3(-definition.dimensions.x * 0.5, 0, -definition.dimensions.z * 0.5),
		definition.dimensions
	)


func get_socket(socket_id: String) -> Dictionary:
	if definition:
		for socket in definition.sockets:
			if socket.get("id", "") == socket_id:
				return socket
	return {}
