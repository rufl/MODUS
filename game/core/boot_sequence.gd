class_name BootSequence
extends Node

signal log_message(text: String)
signal progress_updated(percent: float)
signal boot_complete
signal boot_failed(reason: String)

const PLAYER_SCENE_PATH: String = "res://game/entities/player/player.tscn"
const REQUIRED_AUDIO_BUSES: Array[String] = ["Master", "SFX", "Music", "Ambient"]

var _started: bool = false


func start_sequence() -> void:
	if _started:
		return
	_started = true

	_log("Initializing System...")
	await get_tree().create_timer(0.5).timeout

	if not await _check_memory():
		_fail("Memory telemetry is unavailable.")
		return
	progress_updated.emit(0.25)

	if not await _check_audio():
		_fail("Audio subsystem is unavailable.")
		return
	progress_updated.emit(0.5)

	if not await _check_network():
		_fail("ENet multiplayer transport is unavailable.")
		return
	progress_updated.emit(0.75)

	if not await _check_resources():
		_fail("Required game resources are unavailable.")
		return
	progress_updated.emit(1.0)

	_log("System Ready.")
	await get_tree().create_timer(1.0).timeout
	boot_complete.emit()


func _log(text: String) -> void:
	log_message.emit(text)
	var game_manager: Node = get_node_or_null("/root/GameManager")
	var logger: Node = (
		game_manager.get_core_system("logger")
		if game_manager and game_manager.has_method("get_core_system")
		else null
	)
	if logger and logger.has_method("info"):
		logger.info("[BOOT] " + text, "BootSequence")


func _fail(reason: String) -> void:
	_log("System check failed: " + reason)
	boot_failed.emit(reason)


func _check_memory() -> bool:
	_log("Checking Memory Telemetry...")
	await get_tree().create_timer(0.2).timeout

	var memory_usage: int = OS.get_static_memory_usage()
	if memory_usage < 0:
		_log("  Static memory telemetry unavailable")
		return false

	_log("  Static memory: " + String.humanize_size(memory_usage))
	return true


func _check_audio() -> bool:
	_log("Checking Audio Interface...")
	await get_tree().create_timer(0.3).timeout

	var game_manager: Node = get_node_or_null("/root/GameManager")
	var audio_service: Node = (
		game_manager.get_core_system("audio")
		if game_manager and game_manager.has_method("get_core_system")
		else null
	)
	if not audio_service:
		_log("  Audio service: NOT FOUND")
		return false

	var missing_buses: Array[String] = []
	for bus_name: String in REQUIRED_AUDIO_BUSES:
		if AudioServer.get_bus_index(bus_name) < 0:
			missing_buses.append(bus_name)
	if not missing_buses.is_empty():
		_log("  Missing audio buses: " + ", ".join(missing_buses))
		return false

	_log("  Audio buses ready: " + str(AudioServer.bus_count))
	return true


func _check_network() -> bool:
	_log("Checking Network Transport...")
	await get_tree().create_timer(0.4).timeout

	if not ClassDB.class_exists("ENetMultiplayerPeer"):
		_log("  ENet Driver: NOT AVAILABLE")
		return false

	var peer := ENetMultiplayerPeer.new()
	if not peer:
		_log("  ENet Driver: FAILED TO INITIALIZE")
		return false
	peer.close()
	_log("  ENet Driver: AVAILABLE")
	return true


func _check_resources() -> bool:
	_log("Verifying Core Resources...")
	await get_tree().create_timer(0.5).timeout

	if not ResourceLoader.exists(PLAYER_SCENE_PATH):
		_log("  Player scene missing: " + PLAYER_SCENE_PATH)
		return false

	var player_scene: PackedScene = ResourceLoader.load(PLAYER_SCENE_PATH) as PackedScene
	if not player_scene:
		_log("  Player scene failed to load")
		return false

	_log("  Core Assets: OK")
	return true
