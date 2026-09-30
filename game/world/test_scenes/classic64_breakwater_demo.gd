extends Node3D

var _pump_material := _make_material(Color(0.28, 0.42, 0.44), 0.18, 0.72)
var _generator_material := _make_material(Color(0.68, 0.34, 0.12), 0.42, 0.54)
var _rail_material := _make_material(Color(0.32, 0.36, 0.4), 0.72, 0.38)
var _panel_material := _make_material(Color(0.2, 0.5, 0.48), 0.28, 0.5)
var _junction_material := _make_material(Color(0.26, 0.3, 0.34), 0.55, 0.42)
var _sign_material := _make_material(Color(0.92, 0.55, 0.08), 0.0, 0.72)


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.012, 0.018, 0.026, 1.0))
	_apply_material($PumpStation, _pump_material)
	_apply_material($Generator, _generator_material)
	_apply_material($GuardRail, _rail_material)
	_apply_material($ElectricalPanel, _panel_material)
	_apply_material($JunctionBox, _junction_material)
	_apply_material($ConfinedSpaceSign, _sign_material)


func _apply_material(node: Node, material: Material) -> void:
	var mesh_instance := node as MeshInstance3D
	if mesh_instance != null and mesh_instance.mesh != null:
		mesh_instance.material_override = material
	for child in node.get_children():
		_apply_material(child, material)


func _make_material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material
