extends Node
class_name WindowsClientQualification

const REPORT_SCHEMA := "modus.windows-client-qualification/v1"
const REPORT_PREFIX := "MODUS_WINDOWS_QUALIFICATION_JSON="
const SHOWCASE_SCENE := "res://game/world/maps/showcase.tscn"
const BUTTON_SCENE := "res://game/scenes/environment/interactables/button_stand.tscn"
const ENEMY_SCENE := "res://game/entities/enemies/enemy.tscn"
const PICKUP_SCENE := "res://game/scenes/items/pickups/health_pickup.tscn"
const SAMPLE_MOD_ID := "modus_sdk_sample"
const SAMPLE_MOD_NAME := "MODUS SDK Sample"
const PHYSICAL_INPUT_TIMEOUT_SECONDS := 10.0
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
var _physical_button_pressed := false
var _network_probe_received_count := 0
var _network_probe_acknowledged_count := 0
var _network_probe_sent_count := 0
var _network_probe_last_nonce := 0
var _network_probe_last_acknowledged_nonce := 0
var _physical_input_events := {
	"E":
	{
		"action": "interact",
		"pressed": 0,
		"released": 0,
		"action_pressed": false,
		"action_released": false
	},
	"SPACE":
	{
		"action": "jump",
		"pressed": 0,
		"released": 0,
		"action_pressed": false,
		"action_released": false
	},
	"W":
	{
		"action": "up",
		"pressed": 0,
		"released": 0,
		"action_pressed": false,
		"action_released": false
	},
}


func _input(event: InputEvent) -> void:
	if not event is InputEventKey or event.echo:
		return
	var key_name := _physical_key_name(event as InputEventKey)
	if key_name.is_empty():
		return
	var state: Dictionary = _physical_input_events[key_name]
	var action := str(state.get("action", ""))
	if event.pressed:
		state["pressed"] = int(state.get("pressed", 0)) + 1
		state["action_pressed"] = Input.is_action_pressed(action)
	else:
		state["released"] = int(state.get("released", 0)) + 1
		state["action_released"] = not Input.is_action_pressed(action)
	_physical_input_events[key_name] = state


func _physical_key_name(event: InputEventKey) -> String:
	match int(event.physical_keycode if event.physical_keycode != 0 else event.keycode):
		69:
			return "E"
		32:
			return "SPACE"
		87:
			return "W"
	return ""


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
	if _has_argument("--windows-qualification-physical-input"):
		var physical_result: Dictionary = await _physical_outcome_check()
		input_result["missing_physical_keys"] = physical_result.get("missing_physical_keys", [])
		input_result["physical_input_events"] = _physical_input_events
		input_result["physical_input_outcomes"] = physical_result.get("outcomes", {})
		input_result["physical_input_passed"] = bool(physical_result.get("passed", false))
		input_result["passed"] = (
			bool(input_result.get("passed", false)) and bool(physical_result.get("passed", false))
		)
	_record(
		"input",
		bool(input_result.get("passed", false)),
		"configured actions, synthetic event path, and optional physical outcomes",
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
	if (
		_has_argument("--windows-qualification-content")
		or _has_argument("--windows-qualification-physical-input")
	):
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
		var press_event := InputEventKey.new()
		press_event.physical_keycode = 87
		press_event.pressed = true
		Input.parse_input_event(press_event)
		await _root.get_tree().process_frame
		synthetic_pressed = Input.is_action_pressed("up")
		var release_event := InputEventKey.new()
		release_event.physical_keycode = 87
		release_event.pressed = false
		Input.parse_input_event(release_event)
		await _root.get_tree().process_frame
		synthetic_released = not Input.is_action_pressed("up")

	var physical_required := _has_argument("--windows-qualification-physical-input")
	var physical_passed := not physical_required
	var missing_physical: Array[String] = []
	if physical_required:
		missing_physical.append_array(["W", "SPACE", "E"])
	return {
		"empty_actions": empty,
		"missing_actions": missing,
		"missing_physical_keys": missing_physical,
		"passed":
		(
			missing.is_empty()
			and empty.is_empty()
			and synthetic_pressed
			and synthetic_released
			and physical_passed
		),
		"physical_input_events": _physical_input_events,
		"physical_input_passed": physical_passed,
		"physical_input_requested": physical_required,
		"synthetic_pressed": synthetic_pressed,
		"synthetic_released": synthetic_released,
	}


func _physical_outcome_check() -> Dictionary:
	var tree := _root.get_tree()
	var tree_root := tree.root
	if get_parent() != tree_root:
		get_parent().remove_child(self)
		tree_root.add_child(self)
		_root = tree_root

	var scene_error := tree.change_scene_to_file(SHOWCASE_SCENE)
	if scene_error != OK:
		return {
			"missing_physical_keys": ["W", "SPACE", "E"],
			"outcomes":
			{
				"interaction_e": false,
				"jump_space": false,
				"movement_w": false,
			},
			"passed": false,
			"reason": "showcase scene failed to load: %s" % error_string(scene_error),
		}
	await tree.scene_changed
	await _wait_frames(30)
	var world: Node = tree.current_scene
	var scene_loaded := world != null and world.scene_file_path == SHOWCASE_SCENE
	if not scene_loaded or not world.has_method("spawn_player_node"):
		return {
			"missing_physical_keys": ["W", "SPACE", "E"],
			"outcomes":
			{
				"interaction_e": false,
				"jump_space": false,
				"movement_w": false,
			},
			"passed": false,
			"reason": "showcase world cannot spawn a player",
		}

	world.spawn_player_node(1, "windows_physical_qualification")
	var player: Node3D = await _wait_for_player()
	var player_ready := (
		player != null and "weapon_manager" in player and player.get("weapon_manager") != null
	)
	if not player_ready:
		return {
			"missing_physical_keys": ["W", "SPACE", "E"],
			"outcomes":
			{
				"interaction_e": false,
				"jump_space": false,
				"movement_w": false,
			},
			"passed": false,
			"player_ready": false,
			"reason": "physical qualification player did not become ready",
		}

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	player.global_position = Vector3(0, 2, 14)
	await _wait_frames(10)

	_reset_physical_key("W")
	var movement_start := player.global_position
	print("Windows qualification: hold and release W for movement outcome.")
	var w_pressed := await _wait_for_physical_press("W")
	await _wait_for_physical_release("W")
	await _wait_frames(5)
	var movement_outcome := w_pressed and movement_start.distance_to(player.global_position) >= 0.25

	await _wait_frames(20)
	_reset_physical_key("SPACE")
	var jump_start_y := player.global_position.y
	var jump_count_before := int(player.get("jump_count"))
	var max_jump_y := jump_start_y
	print("Windows qualification: press and release Space for jump outcome.")
	var space_pressed := await _wait_for_physical_press("SPACE")
	for _frame in range(45):
		max_jump_y = maxf(max_jump_y, player.global_position.y)
		await _root.get_tree().process_frame
	var space_released := await _wait_for_physical_release("SPACE")
	var player_body := player as CharacterBody3D
	var jump_outcome := (
		space_pressed
		and space_released
		and (
			int(player.get("jump_count")) > jump_count_before
			or max_jump_y - jump_start_y >= 0.1
			or (player_body != null and player_body.velocity.y > 0.1)
		)
	)

	var interaction_outcome := false
	var e_pressed := false
	var e_released := false
	var button_scene := load(BUTTON_SCENE) as PackedScene
	var button: Node3D
	if button_scene:
		button = button_scene.instantiate() as Node3D
		button.name = "WindowsPhysicalQualificationButton"
		world.add_child(button)
		var camera: Camera3D = player.get("camera") as Camera3D
		if camera:
			button.global_position = (
				player.global_position + (-camera.global_transform.basis.z * 2.0)
			)
			button.global_position.y = player.global_position.y
			camera.look_at(button.global_position + Vector3(0, 0.8, 0), Vector3.UP)
		if button.has_signal("pressed"):
			button.connect("pressed", Callable(self, "_on_physical_button_pressed"))
		await _wait_frames(15)
		_physical_button_pressed = false
		_reset_physical_key("E")
		print("Windows qualification: press and release E for interaction outcome.")
		e_pressed = await _wait_for_physical_press("E")
		e_released = await _wait_for_physical_release("E")
		await _wait_frames(10)
		interaction_outcome = e_pressed and e_released and _physical_button_pressed
		if is_instance_valid(button):
			button.queue_free()

	var missing_physical: Array[String] = []
	for key_name: String in _physical_input_events:
		var state: Dictionary = _physical_input_events[key_name]
		if (
			int(state.get("pressed", 0)) < 1
			or int(state.get("released", 0)) < 1
			or not bool(state.get("action_pressed", false))
			or not bool(state.get("action_released", false))
		):
			missing_physical.append(key_name)
	return {
		"missing_physical_keys": missing_physical,
		"outcomes":
		{
			"interaction_e": interaction_outcome,
			"jump_space": jump_outcome,
			"movement_w": movement_outcome,
		},
		"passed":
		(
			scene_loaded
			and player_ready
			and missing_physical.is_empty()
			and movement_outcome
			and jump_outcome
			and interaction_outcome
		),
		"player_ready": player_ready,
		"scene_loaded": scene_loaded,
	}


func _reset_physical_key(key_name: String) -> void:
	var state: Dictionary = _physical_input_events[key_name]
	state["pressed"] = 0
	state["released"] = 0
	state["action_pressed"] = false
	state["action_released"] = false
	_physical_input_events[key_name] = state


func _wait_for_physical_press(key_name: String) -> bool:
	var deadline := Time.get_ticks_msec() + int(PHYSICAL_INPUT_TIMEOUT_SECONDS * 1000.0)
	while Time.get_ticks_msec() < deadline:
		var state: Dictionary = _physical_input_events[key_name]
		if int(state.get("pressed", 0)) > 0:
			return true
		await _root.get_tree().process_frame
	return false


func _wait_for_physical_release(key_name: String) -> bool:
	var deadline := Time.get_ticks_msec() + int(PHYSICAL_INPUT_TIMEOUT_SECONDS * 1000.0)
	while Time.get_ticks_msec() < deadline:
		var state: Dictionary = _physical_input_events[key_name]
		if int(state.get("released", 0)) > 0:
			return true
		await _root.get_tree().process_frame
	return false


func _on_physical_button_pressed(_interactor: Node) -> void:
	_physical_button_pressed = true


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

	var scene_error := tree.change_scene_to_file(SHOWCASE_SCENE)
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
	var scene_loaded := world != null and world.scene_file_path == SHOWCASE_SCENE
	if not scene_loaded or not world.has_method("spawn_player_node"):
		return {
			"passed": false,
			"requested": true,
			"scene_loaded": scene_loaded,
			"reason": "showcase world cannot spawn a player",
		}

	world.spawn_player_node(1, "windows_qualification")
	var player: Node3D = await _wait_for_player()
	var player_ready := (
		player != null and "weapon_manager" in player and player.get("weapon_manager") != null
	)
	var moved := false
	var weapon_fired := false
	var enemy_defeated := false
	var pickup_collected := false
	var save_loaded := false
	var mod_loaded := false
	if player_ready:
		player.global_position = Vector3(0, 2, 14)
		await _wait_frames(5)
		var start_position := player.global_position
		Input.action_press("up")
		await _wait_frames(30)
		Input.action_release("up")
		await _wait_frames(5)
		moved = start_position.distance_to(player.global_position) >= 0.5

		var stats_before: Dictionary = world.get("match_stats")
		var enemy: Node3D
		var enemy_scene := load(ENEMY_SCENE) as PackedScene
		if enemy_scene:
			enemy = enemy_scene.instantiate() as Node3D
			enemy.name = "WindowsQualificationEnemy"
			world.add_child(enemy)
			await _wait_frames(60)
			enemy.set_process(false)
			enemy.set_physics_process(false)
			var camera: Camera3D = player.get("camera") as Camera3D
			if camera:
				enemy.global_position = (
					player.global_position + (-camera.global_transform.basis.z * 5.0)
				)
				camera.look_at(enemy.global_position + Vector3(0, 0.9, 0), Vector3.UP)
			var health_component: Node = enemy.get("health_component") as Node
			if health_component:
				health_component.set("max_health", 1.0)
				health_component.set("current_health", 1.0)
			await _wait_frames(5)
			var shots_before := int(stats_before.get("shots_fired", 0))
			var kills_before := int(stats_before.get("enemies_killed", 0))
			var weapon_manager: Node = player.get("weapon_manager") as Node
			if weapon_manager and weapon_manager.has_method("fire"):
				weapon_manager.fire(true, true)
				await _wait_frames(120)
				var stats_after: Dictionary = world.get("match_stats")
				weapon_fired = int(stats_after.get("shots_fired", 0)) > shots_before
				enemy_defeated = (
					int(stats_after.get("enemies_killed", 0)) > kills_before
					or not is_instance_valid(enemy)
					or bool(enemy.get("is_dead"))
				)

		var health_before := 50.0
		player.set("health", health_before)
		var pickups_before := int(stats_before.get("items_collected", 0))
		var pickup_scene := load(PICKUP_SCENE) as PackedScene
		if pickup_scene:
			var pickup := pickup_scene.instantiate() as Node3D
			pickup.name = "WindowsQualificationPickup"
			world.add_child(pickup)
			pickup.global_position = player.global_position
			await _wait_frames(60)
			var pickup_stats: Dictionary = world.get("match_stats")
			pickup_collected = (
				float(player.get("health")) > health_before
				and int(pickup_stats.get("items_collected", 0)) > pickups_before
			)
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

		var mod_loader: Node = GameManager.get_core_system("mod_loader")
		if mod_loader:
			var original_enabled := false
			for mod_info: Dictionary in mod_loader.get_installed_mods():
				if mod_info.get("id", "") == SAMPLE_MOD_ID:
					original_enabled = bool(mod_info.get("enabled", false))
					break
			mod_loader.set_mod_enabled(SAMPLE_MOD_ID, true)
			mod_loader.reload_mods()
			await _wait_frames(10)
			mod_loaded = mod_loader.is_mod_loaded(SAMPLE_MOD_NAME)
			mod_loader.set_mod_enabled(SAMPLE_MOD_ID, original_enabled)
			mod_loader.reload_mods()
	return {
		"enemy_defeated": enemy_defeated,
		"mod_loaded": mod_loaded,
		"moved": moved,
		"passed":
		(
			scene_loaded
			and player_ready
			and moved
			and weapon_fired
			and enemy_defeated
			and pickup_collected
			and save_loaded
			and mod_loaded
		),
		"player_ready": player_ready,
		"player_spawned": player != null,
		"pickup_collected": pickup_collected,
		"requested": true,
		"save_loaded": save_loaded,
		"scene_loaded": scene_loaded,
		"weapon_fired": weapon_fired,
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
					var connected_peers := server_api.get_peers()
					peer_count = connected_peers.size()
					server_peer_connected = connected_peers.has(client.get_unique_id())
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


func _reset_network_probe() -> void:
	_network_probe_received_count = 0
	_network_probe_acknowledged_count = 0
	_network_probe_sent_count = 0
	_network_probe_last_nonce = 0
	_network_probe_last_acknowledged_nonce = 0


@rpc("any_peer", "call_remote", "reliable")
func _receive_network_probe(nonce: int) -> void:
	if not multiplayer.is_server():
		return
	_network_probe_received_count += 1
	var sender_id := multiplayer.get_remote_sender_id()
	if sender_id > 0:
		_receive_network_probe_ack.rpc_id(sender_id, nonce)


@rpc("authority", "call_remote", "reliable")
func _receive_network_probe_ack(nonce: int) -> void:
	_network_probe_acknowledged_count += 1
	_network_probe_last_acknowledged_nonce = nonce


func _send_network_probe_to_server() -> void:
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		return
	_network_probe_last_nonce = Time.get_ticks_msec()
	_network_probe_sent_count += 1
	_receive_network_probe.rpc_id(1, _network_probe_last_nonce)


func run_network_role(
	root: Node,
	role: String,
	port: int,
	address: String = "127.0.0.1",
	soak_seconds: int = 0,
	require_reconnect: bool = false
) -> Dictionary:
	_root = root
	if GameManager and not GameManager.is_initialized():
		await GameManager.ready

	_reset_network_probe()
	soak_seconds = maxi(soak_seconds, 0)
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var peer_error: Error = (
		peer.create_server(port, 2) if role == "server" else peer.create_client(address, port)
	)
	var reconnect_error: Error = OK
	var connected := false
	var connection_established := false
	var listening := peer_error == OK
	var connection_count := 0
	var disconnect_observed := false
	var reconnect_started := false
	var session_deadline_msec := 0
	var next_probe_msec := 0
	var probe_settle_deadline_msec := 0
	var peer_count := 0
	if listening:
		_root.multiplayer.multiplayer_peer = peer
		if role == "server":
			print("MODUS_WINDOWS_NETWORK_READY=%d" % port)
		var deadline_msec := Time.get_ticks_msec() + 30000 + soak_seconds * 1000
		while Time.get_ticks_msec() < deadline_msec:
			var now_msec := Time.get_ticks_msec()
			if role == "client":
				var connection_status := peer.get_connection_status()
				if connection_status == MultiplayerPeer.CONNECTION_CONNECTED:
					if not connected:
						connected = true
						connection_established = true
						connection_count += 1
						next_probe_msec = 0
					if next_probe_msec == 0 or now_msec >= next_probe_msec:
						_send_network_probe_to_server()
						next_probe_msec = now_msec + 1000
					var current_probe_acknowledged := (
						_network_probe_last_nonce != 0
						and _network_probe_last_acknowledged_nonce == _network_probe_last_nonce
					)
					if current_probe_acknowledged:
						if require_reconnect and connection_count == 1 and not reconnect_started:
							reconnect_started = true
							connected = false
							_root.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
							peer.close()
							await _wait_frames(2)
							peer = ENetMultiplayerPeer.new()
							reconnect_error = peer.create_client(address, port)
							if reconnect_error == OK:
								_root.multiplayer.multiplayer_peer = peer
								next_probe_msec = 0
							else:
								break
						elif not require_reconnect or connection_count >= 2:
							if soak_seconds > 0 and session_deadline_msec == 0:
								session_deadline_msec = now_msec + soak_seconds * 1000
							elif soak_seconds == 0:
								break
				elif connected:
					disconnect_observed = true
					connected = false
			else:
				connected = _network_probe_received_count > 0
				if connected:
					connection_established = true
				if connected and session_deadline_msec == 0:
					if (
						soak_seconds > 0
						and (not require_reconnect or _network_probe_received_count >= 2)
					):
						session_deadline_msec = now_msec + soak_seconds * 1000
					elif soak_seconds == 0 and not require_reconnect:
						if probe_settle_deadline_msec == 0:
							probe_settle_deadline_msec = now_msec + 500
						elif now_msec >= probe_settle_deadline_msec:
							break
				if require_reconnect and _network_probe_received_count >= 2 and soak_seconds == 0:
					break
			if session_deadline_msec > 0 and now_msec >= session_deadline_msec:
				break
			await _root.get_tree().process_frame
		if _root.multiplayer.multiplayer_peer != null:
			var peer_api := _root.multiplayer
			peer_count = peer_api.get_peers().size()
			_root.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
		else:
			peer_count = 0
		peer.close()

	var probe_acknowledged := (
		_network_probe_acknowledged_count > 0
		and _network_probe_last_acknowledged_nonce == _network_probe_last_nonce
	)
	var application_probe_passed := (
		_network_probe_received_count > 0 if role == "server" else probe_acknowledged
	)
	var reconnected := (
		connection_count >= 2 if role == "client" else _network_probe_received_count >= 2
	)
	var soak_completed := (
		soak_seconds == 0
		or (session_deadline_msec > 0 and Time.get_ticks_msec() >= session_deadline_msec)
	)
	var transport_ready := listening and reconnect_error == OK
	var role_passed := (
		transport_ready and (role == "server" or (connection_established and probe_acknowledged))
	)
	if require_reconnect:
		role_passed = role_passed and reconnected
	if soak_seconds > 0:
		role_passed = role_passed and soak_completed
	var report := {
		"address": address,
		"connection_established": connection_established,
		"application_probe_passed": application_probe_passed,
		"connected": connected,
		"disconnect_observed": disconnect_observed,
		"listening": listening,
		"peer_count": peer_count,
		"port": port,
		"probe_acknowledged": probe_acknowledged,
		"probe_received": _network_probe_received_count > 0,
		"probe_sent": _network_probe_sent_count > 0,
		"reconnected": reconnected,
		"reconnect_required": require_reconnect,
		"reconnect_error": error_string(reconnect_error),
		"role": role,
		"schema": REPORT_SCHEMA,
		"soak_completed": soak_completed,
		"soak_seconds": soak_seconds,
		"status": "pass" if role_passed else "fail",
		"transport": "ENet native multi-process",
	}
	print("MODUS_WINDOWS_NETWORK_JSON=" + JSON.stringify(report))
	return report
