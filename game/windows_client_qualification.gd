extends Node
class_name WindowsClientQualification

const REPORT_SCHEMA := "modus.windows-client-qualification/v1"
const REPORT_PREFIX := "MODUS_WINDOWS_QUALIFICATION_JSON="
const REQUIRED_INPUT_ACTIONS = [
	"up",
	"down",
	"left",
	"right",
	"jump",
	"shoot",
	"aim",
	"interact",
	"reload",
	"pause",
]

var _root: Node
var _checks: Dictionary = {}
var _failures: Array[String] = []
var _physical_input_seen := PackedStringArray()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var keycode := int(event.physical_keycode)
		if keycode in [32, 69, 87]:
			_physical_input_seen.append(str(keycode))


func _has_argument(argument: String) -> bool:
	return argument in OS.get_cmdline_args() or argument in OS.get_cmdline_user_args()


func run(root: Node) -> Dictionary:
	_root = root
	_checks.clear()
	_failures.clear()

	if GameManager and not GameManager.is_initialized():
		await GameManager.ready

	var platform := OS.get_name()
	_record(
		"platform",
		platform == "Windows",
		"native operating system",
		{"os": platform, "required": "Windows"},
	)
	_record("renderer", _renderer_check(), "native window and renderer", _renderer_details())
	var input_result: Dictionary = await _input_check()
	_record(
		"input",
		bool(input_result.get("passed", false)),
		"configured actions, synthetic event path, and optional physical event",
		input_result,
	)
	var save_result: Dictionary = _save_check()
	_record(
		"save",
		bool(save_result.get("passed", false)),
		"SaveService encrypted slot roundtrip",
		save_result,
	)
	var content_result := {"passed": true, "requested": false, "status": "not_requested"}
	if _has_argument("--windows-qualification-content"):
		content_result = await _content_check()
	_record(
		"content_workflow",
		bool(content_result.get("passed", false)),
		"showcase scene, player movement, and GameStateManager save/load workflow",
		content_result,
	)
	var network_result: Dictionary = await _network_check()
	_record(
		"network",
		bool(network_result.get("passed", false)),
		"loopback ENet host/client handshake",
		network_result,
	)

	var report := {
		"checks": _checks,
		"failures": _failures,
		"os": platform,
		"schema": REPORT_SCHEMA,
		"status": "pass" if _failures.is_empty() else "fail",
	}
	print(REPORT_PREFIX + JSON.stringify(report))
	if _has_argument("--windows-qualification-content"):
		get_tree().quit(0 if report.get("status") == "pass" else 1)
	return report


func _record(name: String, passed: bool, evidence: String, details: Dictionary) -> void:
	_checks[name] = {
		"details": details,
		"evidence": evidence,
		"status": "pass" if passed else "fail",
	}
	if not passed:
		_failures.append(name)


func _renderer_check() -> bool:
	var details := _renderer_details()
	return (
		OS.get_name() == "Windows"
		and details.get("display_server", "") != "headless"
		and details.get("rendering_method", "") != ""
		and details.get("viewport_width", 0) > 0
		and details.get("viewport_height", 0) > 0
	)


func _renderer_details() -> Dictionary:
	var viewport := _root.get_viewport()
	var size := viewport.get_visible_rect().size if viewport else Vector2.ZERO
	return {
		"display_server": DisplayServer.get_name(),
		"rendering_method": str(RenderingServer.get_current_rendering_method()),
		"viewport_height": int(size.y),
		"viewport_width": int(size.x),
	}


func _input_check() -> Dictionary:
	var missing: Array[String] = []
	var empty: Array[String] = []
	for action in REQUIRED_INPUT_ACTIONS:
		if not InputMap.has_action(action):
			missing.append(action)
		elif InputMap.action_get_events(action).is_empty():
			empty.append(action)

	var synthetic_pressed := false
	var synthetic_released := false
	if missing.is_empty() and empty.is_empty():
		var event := InputEventKey.new()
		event.physical_keycode = 87
		event.pressed = true
		Input.parse_input_event(event)
		await _root.get_tree().process_frame
		synthetic_pressed = Input.is_action_pressed("up")
		event.pressed = false
		Input.parse_input_event(event)
		await _root.get_tree().process_frame
		synthetic_released = not Input.is_action_pressed("up")

	var physical_required := _has_argument("--windows-qualification-physical-input")
	var physical_passed := not physical_required
	if physical_required:
		print("Windows qualification: press W, E, or Space in the client window.")
		for _attempt in range(1200):
			if not _physical_input_seen.is_empty():
				physical_passed = true
				break
			await _root.get_tree().process_frame

	return {
		"empty_actions": empty,
		"missing_actions": missing,
		"passed":
		(
			missing.is_empty()
			and empty.is_empty()
			and synthetic_pressed
			and synthetic_released
			and physical_passed
		),
		"physical_input_events": _physical_input_seen,
		"physical_input_passed": physical_passed,
		"physical_input_requested": physical_required,
		"synthetic_pressed": synthetic_pressed,
		"synthetic_released": synthetic_released,
	}


func _save_check() -> Dictionary:
	var slot := "windows-client-qualification"
	var expected := {"marker": slot, "value": 17}
	var save_service: Node = (
		GameManager.get_core_system("save")
		if GameManager and GameManager.has_method("get_core_system")
		else null
	)
	var saved: bool = (
		save_service != null
		and save_service.has_method("save_data")
		and save_service.save_data(slot, expected.duplicate(true), {"qualification": true})
	)
	var loaded: Dictionary = save_service.load_data(slot) if saved else {}
	var loaded_matches: bool = (
		str(loaded.get("marker", "")) == slot and int(loaded.get("value", -1)) == 17
	)
	_cleanup_save_slot(slot)
	return {
		"loaded_matches": loaded_matches,
		"passed": saved and loaded_matches,
		"save_service_available": save_service != null,
		"slot": slot,
	}


func _content_check() -> Dictionary:
	var tree := _root.get_tree()
	var tree_root := tree.root
	if get_parent() != tree_root:
		get_parent().remove_child(self)
		tree_root.add_child(self)
		_root = tree_root

	var scene_error := tree.change_scene_to_file("res://game/world/maps/showcase.tscn")
	if scene_error != OK:
		return {
			"passed": false,
			"requested": true,
			"scene_loaded": false,
			"reason": "showcase scene failed to load: %s" % error_string(scene_error),
		}
	await tree.scene_changed
	await _wait_frames(30)
	var world: Node = tree.current_scene
	var scene_loaded := (
		world != null and world.scene_file_path == "res://game/world/maps/showcase.tscn"
	)
	if not scene_loaded or not world.has_method("spawn_player_node"):
		return {
			"passed": false,
			"requested": true,
			"scene_loaded": scene_loaded,
			"reason": "showcase world cannot spawn a player",
		}

	world.spawn_player_node(1, "windows_qualification")
	var player: Node3D = await _wait_for_player()
	var player_spawned := player != null
	var moved := false
	var save_loaded := false
	if player_spawned:
		player.global_position = Vector3(0, 2, 14)
		await _wait_frames(5)
		var start_position := player.global_position
		Input.action_press("up")
		await _wait_frames(30)
		Input.action_release("up")
		await _wait_frames(5)
		moved = start_position.distance_to(player.global_position) >= 0.5

		var pickup_scene := (
			load("res://game/scenes/items/pickups/health_pickup.tscn") as PackedScene
		)
		if pickup_scene:
			var pickup := pickup_scene.instantiate() as Node3D
			world.add_child(pickup)
			pickup.global_position = player.global_position
			await _wait_frames(60)

		var state_manager: Node = GameManager.get_core_system("state_manager")
		if state_manager:
			var slot := "windows-client-content-qualification"
			state_manager.delete_save(slot)
			var saved_position := player.global_position
			state_manager.save_game(slot)
			await _wait_frames(5)
			if state_manager.save_exists(slot):
				player.global_position += Vector3(9, 0, 0)
				await state_manager.load_game(slot)
				await _wait_frames(10)
				save_loaded = player.global_position.distance_to(saved_position) < 0.25
			state_manager.delete_save(slot)
	return {
		"moved": moved,
		"passed": scene_loaded and player_spawned and moved and save_loaded,
		"player_spawned": player_spawned,
		"requested": true,
		"save_loaded": save_loaded,
		"scene_loaded": scene_loaded,
	}


func _wait_for_player() -> Node3D:
	for _attempt in range(300):
		var player := _root.get_tree().get_first_node_in_group("player") as Node3D
		if player:
			return player
		await _root.get_tree().process_frame
	return null


func _wait_frames(count: int) -> void:
	for _frame in range(count):
		await _root.get_tree().process_frame


func _cleanup_save_slot(slot: String) -> void:
	for suffix in [".sav", ".meta", ".sav.staging", ".meta.staging", ".sav.backup", ".meta.backup"]:
		var path := ProjectSettings.globalize_path("user://saves/" + slot + suffix)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func _network_check() -> Dictionary:
	var server_root := Node.new()
	var client_root := Node.new()
	server_root.name = "WindowsQualificationServer"
	client_root.name = "WindowsQualificationClient"
	_root.add_child(server_root)
	_root.add_child(client_root)

	var server_api := SceneMultiplayer.new()
	var client_api := SceneMultiplayer.new()
	_root.get_tree().set_multiplayer(server_api, server_root.get_path())
	_root.get_tree().set_multiplayer(client_api, client_root.get_path())

	var server := ENetMultiplayerPeer.new()
	var client := ENetMultiplayerPeer.new()
	var server_error := server.create_server(0, 2)
	var client_error := ERR_UNAVAILABLE
	var connected := false
	var server_peer_connected := false
	var peer_count := 0
	if server_error == OK:
		server_api.multiplayer_peer = server
		var port := server.get_host().get_local_port()
		client_error = client.create_client("127.0.0.1", port)
		if client_error == OK:
			client_api.multiplayer_peer = client
			for _attempt in range(180):
				if client.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
					connected = true
					server_peer_connected = server.get_peer(client.get_unique_id()) != null
					if server_peer_connected:
						break
				await _root.get_tree().process_frame
			peer_count = server_api.get_peers().size()

		client_api.multiplayer_peer = OfflineMultiplayerPeer.new()
		server_api.multiplayer_peer = OfflineMultiplayerPeer.new()
	server.close()
	client.close()
	_root.remove_child(client_root)
	_root.remove_child(server_root)
	client_root.free()
	server_root.free()

	return {
		"client_error": error_string(client_error),
		"connected": connected,
		"passed": server_error == OK and client_error == OK and connected and server_peer_connected,
		"peer_count": peer_count,
		"server_error": error_string(server_error),
		"server_peer_connected": server_peer_connected,
	}


func run_network_role(root: Node, role: String, port: int) -> Dictionary:
	_root = root
	if GameManager and not GameManager.is_initialized():
		await GameManager.ready

	var peer := ENetMultiplayerPeer.new()
	var peer_error := (
		peer.create_server(port, 2) if role == "server" else peer.create_client("127.0.0.1", port)
	)
	var connected := false
	var listening := peer_error == OK
	if listening:
		_root.multiplayer.multiplayer_peer = peer
		if role == "server":
			print("MODUS_WINDOWS_NETWORK_READY=%d" % port)
		var deadline_msec := Time.get_ticks_msec() + 30000
		while Time.get_ticks_msec() < deadline_msec:
			if role == "client":
				connected = peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED
				if connected:
					break
			await _root.get_tree().process_frame
		_root.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	peer.close()

	var report := {
		"connected": connected,
		"listening": listening,
		"peer_count": 0,
		"port": port,
		"role": role,
		"schema": REPORT_SCHEMA,
		"status": "pass" if listening and (role == "server" or connected) else "fail",
		"transport": "ENet native multi-process loopback",
	}
	print("MODUS_WINDOWS_NETWORK_JSON=" + JSON.stringify(report))
	return report
