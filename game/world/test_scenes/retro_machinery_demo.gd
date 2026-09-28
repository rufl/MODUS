extends Node3D

const ASSET_ROOT := "res://game/art/models/third_party/chilly_durango_retro_machinery/textures/"

var _breaker_material := _make_texture_material("Fuse-Box-Texture.png")
var _generator_material := _make_texture_material("Generator-Texture.png")
var _pipe_material := _make_texture_material("Pipe-Texture.png")
var _pump_material := _make_texture_material("Pump-Texture.png")
var _switch_material := _make_texture_material("Switch-Texture.png")
var _transformer_material := _make_texture_material("Transformer-Texture.png")
var _turbine_material := _make_texture_material("Turbine-Texture.png")
var _wire_material := _make_texture_material("Wires-Texture.png")


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.012, 0.016, 0.022, 1.0))
	_apply_material($Generator, _generator_material)
	_apply_material($Transformer, _transformer_material)
	_apply_material($Turbine, _turbine_material)
	_apply_material($Pump, _pump_material)
	_apply_material($Pipes, _pipe_material)
	_apply_material($PipeValve, _pipe_material)
	_apply_material($Wires, _wire_material)
	_apply_material($CircuitBreaker, _breaker_material)
	_apply_material($Switches, _switch_material)


func _apply_material(node: Node, material: Material) -> void:
	var mesh_instance := node as MeshInstance3D
	if mesh_instance != null and mesh_instance.mesh != null:
		mesh_instance.material_override = material
	for child in node.get_children():
		_apply_material(child, material)


func _make_texture_material(filename: String) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.albedo_texture = load(ASSET_ROOT + filename)
	return material
