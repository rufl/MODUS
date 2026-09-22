extends Node

const ORIGIN := "res://tests/fixtures/hub_travel_origin.tscn"
const DESTINATION := "res://tests/fixtures/hub_travel_destination.tscn"
var session: LevelPlaySession
var peer: ENetMultiplayerPeer
var role: String
var evidence: String
var failed: bool = false


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	role = args[0]
	evidence = args[1]
	if not GameManager.is_initialized():
		await GameManager.ready
	await get_tree().process_frame
	peer = ENetMultiplayerPeer.new()
	if role == "host":
		_check(peer.create_server(0, 4) == OK, "Host binds ENet")
	else:
		_check(
			(
				peer.create_client(
					"127.0.0.1", int(FileAccess.get_file_as_string(evidence.path_join("port")))
				)
				== OK
			),
			"Client connects"
		)
	multiplayer.multiplayer_peer = peer
	session = LevelPlaySession.new()
	session.name = "Session"
	session.register_destination("travel_origin", ORIGIN)
	session.register_destination("travel_destination", DESTINATION)
	add_child(session)
	if role == "host":
		await _host()
	else:
		await _client()
	session.free()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	peer.close()
	_mark(role + "_passed" if not failed else role + "_failed")
	_mark(role + "_closed")
	get_tree().quit(1 if failed else 0)


func _host() -> void:
	_check(await session.travel_to("travel_origin", "arrival"), session.error_message)
	if not session.document:
		return
	var participant := session.player
	session.document.find_actor("power").trigger(participant)
	_check(session.document.find_actor("key").interact(participant), "Host collects persistent key")
	participant.health_component.set_health(50.0, 7.0)
	var supplies: PickupSpawnerActor = session.document.find_actor("supplies")
	participant.global_position = supplies._current_pickup.global_position
	_check(supplies._current_pickup.collect_for_player(participant, 1), "Host consumes supply")
	var encounter: EnemySpawnerActor = session.document.find_actor("encounter")
	encounter.trigger(participant)
	var enemy: Enemy = encounter._enemies[0]
	enemy.take_damage(10000.0, 1, Vector3.ZERO, 0.0, "bullet", participant)
	encounter._process(0.0)
	MissionMgr.get_instance()._process(0.0)
	_check(await session.travel_to("travel_destination"), session.error_message)
	session.document.find_actor("encounter").trigger(participant)
	_check(await session.travel_to("travel_origin"), session.error_message)
	FileAccess.open(evidence.path_join("port"), FileAccess.WRITE).store_string(
		str(peer.host.get_local_port())
	)
	if not await _wait_file("first_ready"):
		return
	_check(session.get_session_players().size() == 2, "Validated first client has one player")
	var original := session.document
	_mark("reject_content")
	if not await _wait_file("content_rejected_ready"):
		return
	_check(
		not await session.travel_to("travel_destination"), "Client content mismatch aborts travel"
	)
	_check(
		session.document == original and session.player == participant,
		"Refusal keeps live world and party"
	)
	_check(multiplayer.multiplayer_peer == peer, "Refusal keeps transport")
	_mark("repair_content")
	if not await _wait_file("content_repaired"):
		return
	_check(await session.travel_to("travel_destination"), session.error_message)
	session.set_travel_frozen(true)
	_mark("destination_committed")
	if not await _wait_file("first_traveled"):
		return
	_mark("start_late")
	if not await _wait_file("late_ready"):
		return
	_check(session.get_session_players().size() == 3, "Late join adds one validated player")
	_check(
		session.document.find_actor("encounter")._enemies.size() == 1,
		"One living encounter survives revisits and late join"
	)
	_check(await session.travel_to("travel_origin"), session.error_message)
	_mark("return_committed")
	if not await _wait_file("first_returned") or not await _wait_file("late_returned"):
		return
	_check(
		session.document.find_actor("supplies").capture_runtime_state().pickup_phase == "collected",
		"No duplicate reward after group revisit"
	)
	_check(multiplayer.multiplayer_peer == peer, "Three destinations share one ENet transport")
	_mark("hold_prepare")
	if not await _wait_file("late_paused"):
		return
	_mark("disconnect_during_travel")
	if not await _wait_file("first_armed"):
		return
	_check(
		await session.travel_to("travel_destination"),
		"Travel commits for remaining peers after a preparation disconnect"
	)
	_check(
		session.get_session_players().size() == 2,
		"Disconnected player is absent from the committed roster"
	)
	if not await _wait_file("late_final"):
		return
	_mark("finish")
	await _wait_file("late_done")


func _client() -> void:
	var joined: Array = await session.travel_network.join_finished
	_check(joined[0], str(joined[1]))
	if not joined[0]:
		return
	var participant := session.player
	_check(
		participant.get_multiplayer_authority() == multiplayer.get_unique_id(),
		"Local player restored after admission"
	)
	var host_player := session.get_node("1") as Player
	_check(host_player.has_item("hub_key"), "Late join restores host keys")
	_check(host_player.health_component.current_armor == 7.0, "Late join restores armor")
	if role == "first":
		_check_origin()
		_mark("first_ready")
		if not await _wait_file("reject_content"):
			return
		var altered := load(DESTINATION).instantiate() as Node3D
		altered.authoring_mode = true
		altered.level_name += " mismatched content"
		altered.prepare_for_save()
		var packed := PackedScene.new()
		_check(packed.pack(altered) == OK, "Prepare different client content")
		altered.free()
		session._sources.travel_destination = packed
		_mark("content_rejected_ready")
		if not await _wait_file("repair_content"):
			return
		_check(
			session.current_destination_id == "travel_origin",
			"Refusing client remains in old world"
		)
		session._sources.erase("travel_destination")
		_mark("content_repaired")
		if not await _wait_destination("travel_destination"):
			return
		_check(session.player == participant, "Client player survives travel")
		_check(
			session.document.find_actor("encounter")._enemies.size() == 1,
			"Travel restores living encounter"
		)
		_mark("first_traveled")
	else:
		_check(
			session.current_destination_id == "travel_destination",
			"Late client joins current destination, not entry map"
		)
		_check(
			session.document.find_actor("encounter")._enemies.size() == 1,
			"Late join restores living encounter"
		)
		_mark("late_ready")
	if not await _wait_destination("travel_origin"):
		return
	_check_origin()
	_check(session.player == participant, "Client player survives group revisit")
	_check(multiplayer.multiplayer_peer == peer, "Client never reconnects during travel")
	_mark(role + "_returned")
	if role == "first":
		if not await _wait_file("disconnect_during_travel"):
			return
		_mark("first_armed")
		var deadline := Time.get_ticks_msec() + 20000
		while not session.travel_network.pending and Time.get_ticks_msec() < deadline:
			await get_tree().process_frame
		_check(
			session.travel_network.pending, "Disconnect occurs during preparation, not after commit"
		)
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
		peer.close()
		return
	if not await _wait_file("hold_prepare"):
		return
	get_tree().multiplayer_poll = false
	_mark("late_paused")
	await _wait_file("first_closed")
	get_tree().multiplayer_poll = true
	if not await _wait_destination("travel_destination"):
		return
	_check(
		session.get_session_players().size() == 2,
		"Remaining client restores roster without disconnected peer"
	)
	_mark("late_final")
	await _wait_file("finish")
	_mark(role + "_done")
	await _wait_file("host_closed")


func _check_origin() -> void:
	_check(session.current_destination_id == "travel_origin", "Restored origin destination")
	_check(session.document.find_actor("power").activation_count == 1, "Restored objective actor")
	_check(
		MissionMgr.get_instance().completed_mission_id == "travel_origin",
		"Restored objective completion"
	)
	_check(
		session.document.find_actor("supplies").capture_runtime_state().pickup_phase == "collected",
		"Restored consumed supply"
	)
	_check(
		session.document.find_actor("encounter").capture_runtime_state().encounter_cleared,
		"Restored cleared encounter"
	)


func _wait_destination(identity: String) -> bool:
	var deadline := Time.get_ticks_msec() + 20000
	while session.current_destination_id != identity or session.travel_network.pending:
		if Time.get_ticks_msec() >= deadline:
			_check(false, "Timed out waiting for destination: " + identity)
			return false
		await get_tree().process_frame
	return true


func _wait_file(filename: String) -> bool:
	var deadline := Time.get_ticks_msec() + 20000
	while not FileAccess.file_exists(evidence.path_join(filename)):
		if Time.get_ticks_msec() >= deadline:
			_check(false, "Timed out waiting for: " + filename)
			return false
		await get_tree().process_frame
	return true


func _mark(filename: String) -> void:
	FileAccess.open(evidence.path_join(filename), FileAccess.WRITE).store_string("done")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error("HUB TRAVEL " + role + ": " + message)
	else:
		print("HUB TRAVEL ", role, ": ", message)
