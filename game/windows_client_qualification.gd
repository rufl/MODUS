extends RefCounted
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


func run(root: Node) -> Dictionary:
	_root = root
	_checks.clear()
	_failures.clear()

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
		"configured actions plus synthetic event path",
		input_result,
	)
	_record("save", _save_check(), "user-data write/read/delete", _save_details())
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

	return {
		"empty_actions": empty,
		"missing_actions": missing,
		"passed":
		missing.is_empty() and empty.is_empty() and synthetic_pressed and synthetic_released,
		"synthetic_pressed": synthetic_pressed,
		"synthetic_released": synthetic_released,
	}


func _save_check() -> bool:
	var path := "user://windows-client-qualification.json"
	var payload := {"marker": "windows-client-qualification", "value": 17}
	var writer := FileAccess.open(path, FileAccess.WRITE)
	if writer == null:
		return false
	writer.store_string(JSON.stringify(payload))
	writer.close()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	var passed: bool = (
		parsed is Dictionary
		and parsed.get("marker") == payload["marker"]
		and parsed.get("value") == 17
	)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	return passed


func _save_details() -> Dictionary:
	return {"path": "user://windows-client-qualification.json"}


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
