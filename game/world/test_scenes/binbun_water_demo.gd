extends Node3D

const DUCK_MATERIAL: Material = preload(
	"res://game/art/models/third_party/binbun_water/duck_material.tres"
)


func _ready() -> void:
	_apply_duck_material($Ducks/SmoothDuck)
	_apply_duck_material($Ducks/ToonDuck)


func _apply_duck_material(node: Node) -> void:
	var mesh_instance := node as MeshInstance3D
	if mesh_instance:
		mesh_instance.material_override = DUCK_MATERIAL
	for child in node.get_children():
		_apply_duck_material(child)
