extends Node3D

var _psx_material := _make_material(Color(0.34, 0.42, 0.39), 0.0, 0.94)
var _street_materials := {
	"Barrel": _make_material(Color(0.75, 0.32, 0.12), 0.0, 0.9),
	"TrashCan": _make_material(Color(0.12, 0.38, 0.42), 0.0, 0.9),
	"GasMask": _make_material(Color(0.44, 0.62, 0.3), 0.0, 0.9),
	"Flashlight": _make_material(Color(0.9, 0.68, 0.2), 0.0, 0.86),
	"Box": _make_material(Color(0.55, 0.29, 0.12), 0.0, 0.95),
	"Crowbar": _make_material(Color(0.7, 0.2, 0.18), 0.55, 0.34),
	"Bottles": _make_material(Color(0.2, 0.55, 0.75), 0.0, 0.65),
}
var _industrial_material := _make_material(Color(0.34, 0.37, 0.4), 0.25, 0.72)
var _industrial_metal_material := _make_material(Color(0.22, 0.28, 0.32), 0.8, 0.34)
var _industrial_rust_material := _make_material(Color(0.58, 0.28, 0.12), 0.18, 0.76)
var _industrial_road_material := _make_material(Color(0.12, 0.15, 0.17), 0.0, 0.92)


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.012, 0.02, 0.028, 1))
	_apply_psx_material($PSXModels)
	for prop_name in _street_materials:
		_apply_material($StreetFurniture.get_node(prop_name), _street_materials[prop_name])
	_apply_industrial_materials($IndustrialExterior)


func _apply_material(node: Node, material: Material) -> void:
	var mesh_instance := node as MeshInstance3D
	if mesh_instance != null and mesh_instance.mesh != null:
		mesh_instance.material_override = material
	for child in node.get_children():
		_apply_material(child, material)


func _apply_industrial_materials(node: Node) -> void:
	var mesh_instance := node as MeshInstance3D
	if mesh_instance != null and mesh_instance.mesh != null:
		mesh_instance.material_override = _industrial_material_for_name(mesh_instance.name)
	for child in node.get_children():
		_apply_industrial_materials(child)


func _apply_psx_material(node: Node) -> void:
	var mesh_instance := node as MeshInstance3D
	if mesh_instance != null and mesh_instance.mesh != null:
		mesh_instance.material_override = _psx_material
	for child in node.get_children():
		_apply_psx_material(child)


func _industrial_material_for_name(node_name: String) -> Material:
	var name_lower := node_name.to_lower()
	if name_lower.contains("road") or name_lower.contains("asphalt") or name_lower.contains("wall"):
		return _industrial_road_material
	if name_lower.contains("barrel") or name_lower.contains("box") or name_lower.contains("cargo"):
		return _industrial_rust_material
	if (
		name_lower.contains("pipe")
		or name_lower.contains("metal")
		or name_lower.contains("fence")
		or name_lower.contains("generator")
	):
		return _industrial_metal_material
	return _industrial_material


func _make_material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material
