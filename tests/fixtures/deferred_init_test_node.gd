extends Node

var logger: Variant = null


func _ready() -> void:
	var game_manager: Node = get_node_or_null("/root/GameManager")
	if game_manager and game_manager.has_method("get_core_system"):
		logger = game_manager.get_core_system("logger")
