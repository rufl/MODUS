extends Node3D

var _concrete_material := _make_material(Color(0.25, 0.28, 0.3), 0.0, 0.88)
var _brick_material := _make_material(Color(0.38, 0.2, 0.14), 0.0, 0.92)
var _metal_material := _make_material(Color(0.16, 0.2, 0.22), 0.78, 0.3)
var _debris_material := _make_material(Color(0.25, 0.17, 0.1), 0.0, 0.96)


func _ready() -> void:
	_apply_review_materials($Sewers)

func _apply_review_materials(node: Node) -> void:
	var mesh_instance := node as MeshInstance3D
	if mesh_instance != null and mesh_instance.mesh != null:
		if mesh_instance.name.to_lower() == "debris":
			# The source's scene-wide debris mesh spans the full export bounds;
			# hide it so this review stays centered on the tunnel modules and props.
			mesh_instance.visible = false
		else:
			mesh_instance.material_override = _material_for_name(mesh_instance.name)
	for child in node.get_children():
		_apply_review_materials(child)


func _material_for_name(node_name: String) -> Material:
	var name_lower := node_name.to_lower()
	if name_lower.contains("pipe") or name_lower.contains("door") or name_lower.contains("metal"):
		return _metal_material
	if name_lower.contains("brick") or name_lower.contains("serwers"):
		return _brick_material
	if name_lower.contains("trash") or name_lower.contains("debris") or name_lower.contains("garbage"):
		return _debris_material
	return _concrete_material


func _make_material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material
