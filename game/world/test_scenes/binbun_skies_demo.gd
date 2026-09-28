extends Node3D

@export var binbun_sky: Sky

@onready var world_environment: WorldEnvironment = $WorldEnvironment


func _ready() -> void:
	var renderer := RenderingServer.get_current_rendering_method()
	if renderer in ["forward_plus", "mobile"] and binbun_sky:
		world_environment.environment.sky = binbun_sky
		world_environment.environment.background_mode = Environment.BG_SKY
	else:
		push_warning(
			"[BinbunSkiesDemo] Sky shaders require Forward+/Mobile; "
			+ "the Compatibility renderer keeps the procedural fallback."
		)
