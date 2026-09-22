class_name LevelGame
extends Node3D

const BUILTIN_LEVEL := "res://game/levels/breakwater_mission.tscn"
const GATE_LEVEL := "res://game/levels/breakwater_gate.tscn"
const HUB_LEVEL := "res://game/levels/breakwater_hub.tscn"
const GAME_SCENE := "res://game/levels/level_game.tscn"
const Packager := preload("res://shared/editor_core/data/level_packager.gd")

static var pending_document_path: String = ""
var session: LevelPlaySession
var _owns_network: bool = false


static func launch(path: String = BUILTIN_LEVEL) -> void:
	pending_document_path = path
	var tree := Engine.get_main_loop() as SceneTree
	var ui_service := UISystem.get_service()
	if ui_service and ui_service.ui_manager:
		ui_service.ui_manager.clear_all()
	tree.change_scene_to_file(GAME_SCENE)


func _ready() -> void:
	if not GameManager.is_initialized():
		await GameManager.ready
	if not _configure_network():
		return
	var path := pending_document_path if not pending_document_path.is_empty() else BUILTIN_LEVEL
	pending_document_path = ""
	if path.get_extension().to_lower() == "mdsl":
		var digest := FileAccess.get_sha256(path)
		if digest.is_empty():
			_show_error("Cannot read the selected level package.")
			return
		var extracted := Packager.extract_level(path, "user://level_packages/" + digest)
		if not extracted.success:
			_show_error(extracted.error_msg)
			return
		path = extracted.level_path
	var packed := ResourceLoader.load(path) as PackedScene
	if not packed:
		_show_error("Unable to load level document: " + path)
		return
	var source := packed.instantiate() as Node3D
	if not source or not "authoring_mode" in source:
		if source:
			source.free()
		_show_error("The package does not contain a LevelRoot document.")
		return
	source.authoring_mode = true
	var holder := Node3D.new()
	holder.visible = false
	holder.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(holder)
	holder.add_child(source)
	session = LevelPlaySession.new()
	session.name = "LevelSession"
	session.register_destination("breakwater_hub", HUB_LEVEL)
	session.register_destination("breakwater_station", BUILTIN_LEVEL)
	add_child(session)
	var started := await session.start_document(source)
	holder.queue_free()
	if not started:
		_show_error(session.error_message)


func _show_error(message: String) -> void:
	push_error("[LevelGame] " + message)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var dialog := AcceptDialog.new()
	dialog.title = "Level could not start"
	dialog.dialog_text = message
	dialog.confirmed.connect(_return_to_menu)
	dialog.canceled.connect(_return_to_menu)
	add_child(dialog)
	dialog.popup_centered(Vector2i(640, 220))


func _return_to_menu() -> void:
	get_tree().change_scene_to_file("res://game/main_entry.tscn")


func _configure_network() -> bool:
	var arguments := OS.get_cmdline_user_args()
	var host_index := arguments.find("--hub-host")
	var join_index := arguments.find("--hub-join")
	if host_index < 0 and join_index < 0:
		return true
	if host_index >= 0 and join_index >= 0:
		_show_error("Choose --hub-host PORT or --hub-join HOST PORT, not both.")
		return false
	var index := host_index if host_index >= 0 else join_index + 1
	if index + 1 >= arguments.size() or not arguments[index + 1].is_valid_int():
		_show_error("Hub networking requires an explicit integer port.")
		return false
	var port := int(arguments[index + 1])
	if port < 1 or port > 65535:
		_show_error("Hub networking port must be between 1 and 65535.")
		return false
	var network: Node = GameManager.get_core_system("network").network_manager
	if multiplayer.multiplayer_peer and not multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		_show_error("A multiplayer transport is already active.")
		return false
	var result: Error = (
		network.host_game(port)
		if host_index >= 0
		else network.join_game(arguments[join_index + 1], port)
	)
	if result != OK:
		_show_error("Hub network startup failed: " + error_string(result))
		return false
	_owns_network = true
	return true


func _exit_tree() -> void:
	# Destination travel never exits this root. Explicitly leaving the game does.
	if _owns_network:
		var network: Node = GameManager.get_core_system("network").network_manager
		network.disconnect_game()
