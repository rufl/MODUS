extends Node3D

var _base_material := _make_material(Color(0.38, 0.43, 0.45), 0.0, 0.92)
var _wood_material := _make_material(Color(0.48, 0.27, 0.12), 0.0, 0.96)
var _metal_material := _make_material(Color(0.27, 0.34, 0.38), 0.65, 0.42)
var _rust_material := _make_material(Color(0.68, 0.28, 0.12), 0.2, 0.74)
var _stone_material := _make_material(Color(0.25, 0.29, 0.31), 0.0, 1.0)
var _utility_material := _make_material(Color(0.76, 0.62, 0.18), 0.0, 0.78)
var _danger_material := _make_material(Color(0.72, 0.12, 0.08), 0.0, 0.82)
var _medical_material := _make_material(Color(0.72, 0.78, 0.68), 0.0, 0.9)


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.012, 0.018, 0.024, 1))
	_apply_mine_materials($MineProps, false)
	_apply_mine_materials($MineModular, true)


func _apply_mine_materials(node: Node, modular: bool) -> void:
	var mesh_instance := node as MeshInstance3D
	if mesh_instance != null and mesh_instance.mesh != null:
		mesh_instance.material_override = _material_for_name(mesh_instance.name, modular)
	for child in node.get_children():
		_apply_mine_materials(child, modular)


func _material_for_name(node_name: String, modular: bool) -> Material:
	var name_lower := node_name.to_lower()
	if name_lower.contains("rock") or name_lower.contains("gravel") or name_lower.contains("soil"):
		return _stone_material
	if name_lower.contains("barrel") or name_lower.contains("rust"):
		return _rust_material
	if (
		name_lower.contains("box")
		or name_lower.contains("shelving")
		or name_lower.contains("wagon")
	):
		return _wood_material
	if (
		name_lower.contains("locker")
		or name_lower.contains("generator")
		or name_lower.contains("metal")
	):
		return _metal_material
	if (
		name_lower.contains("tnt")
		or name_lower.contains("detonator")
		or name_lower.contains("button")
	):
		return _danger_material
	if name_lower.contains("medical") or name_lower.contains("helmet"):
		return _medical_material
	if (
		name_lower.contains("shovel")
		or name_lower.contains("petrol")
		or name_lower.contains("lamp")
	):
		return _utility_material
	if (
		modular
		and (
			name_lower.contains("rail")
			or name_lower.contains("elevator")
			or name_lower.contains("beam")
		)
	):
		return _metal_material
	if name_lower.contains("fence") or name_lower.contains("cable") or name_lower.contains("farol"):
		return _base_material
	return _base_material


func _make_material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material
