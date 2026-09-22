class_name LevelTravelNetwork
extends Node

signal travel_finished(success: bool, error: String)
signal join_finished(success: bool, error: String)

const PREPARE_TIMEOUT_MS := 10000
const JOIN_RETRY_MS := 1000
const SNAPSHOT_INTERVAL := 0.2
const MAX_PACKET_BYTES := 2 * 1024 * 1024
const MAX_VALUE_COUNT := 65536
const MAX_DEPTH := 24
const MAX_TOKEN := 0x7ffffffffffffffe

var session: Node
var pending: bool = false
var last_error: String = ""
var generation: int = 0
var _network: MultiplayerAPI
var _token: int = 0
var _active_token: int = 0
var _last_received_token: int = 0
var _deadline: int = 0
var _participants: Dictionary = {}
var _admitted: Dictionary = {}
var _joining: Dictionary = {}
var _expected_commits: Dictionary = {}
var _expected_rosters: Dictionary = {}
var _disconnected_during_travel: Array[int] = []
var _queued_joins: Dictionary = {}
var _join_attempt_at: Dictionary = {}
var _join_requested: bool = false
var _next_join_request: int = 0
var _client_admitted: bool = false
var _client_join: bool = false
var _staged_generation: int = 0
var _staged_id: String = ""
var _staged_signature: String = ""
var _current_id: String = ""
var _current_signature: String = ""
var _snapshot_elapsed: float = 0.0
var _snapshot_sequence: int = 0
var _last_snapshot_sequence: int = -1
var _exiting: bool = false


func _ready() -> void:
	if not is_instance_valid(session):
		session = get_parent()
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_multiplayer_authority(1)
	_network = multiplayer
	_network.peer_connected.connect(_on_peer_connected)
	_network.peer_disconnected.connect(_on_peer_disconnected)
	_network.connected_to_server.connect(_on_connected_to_server)
	_network.connection_failed.connect(_on_connection_lost)
	_network.server_disconnected.connect(_on_connection_lost)
	request_join.call_deferred()


func _exit_tree() -> void:
	_exiting = true
	# Parent disposal owns staged children; never free siblings during tree exit.
	if pending and _host():
		for peer_id: int in _participants:
			if _known_peer(peer_id):
				_abort.rpc_id(peer_id, _active_token, "Session closed.")
	pending = false
	if _host():
		for peer_id: int in _joining:
			if _known_peer(peer_id):
				_abort.rpc_id(peer_id, int(_joining[peer_id].token), "Session closed.")
	if _network:
		for entry: Array in [
			[_network.peer_connected, _on_peer_connected],
			[_network.peer_disconnected, _on_peer_disconnected],
			[_network.connected_to_server, _on_connected_to_server],
			[_network.connection_failed, _on_connection_lost],
			[_network.server_disconnected, _on_connection_lost],
		]:
			if entry[0].is_connected(entry[1]):
				entry[0].disconnect(entry[1])
	_joining.clear()
	_queued_joins.clear()
	_admitted.clear()
	_expected_commits.clear()
	_expected_rosters.clear()
	_join_attempt_at.clear()


func _connected() -> bool:
	return (
		is_inside_tree()
		and _network != null
		and _network.has_multiplayer_peer()
		and not _network.multiplayer_peer is OfflineMultiplayerPeer
		and (
			_network.multiplayer_peer.get_connection_status()
			== MultiplayerPeer.CONNECTION_CONNECTED
		)
	)


func _host() -> bool:
	return (
		_network != null
		and _network.has_multiplayer_peer()
		and (
			_network.multiplayer_peer.get_connection_status()
			== MultiplayerPeer.CONNECTION_CONNECTED
		)
		and _network.is_server()
	)


func _known_peer(peer_id: int) -> bool:
	if not _connected() or peer_id <= 1 or not _network.get_peers().has(peer_id):
		return false
	var transport := _network.multiplayer_peer
	if transport is ENetMultiplayerPeer:
		var connection: ENetPacketPeer = transport.get_peer(peer_id)
		return connection != null and connection.get_state() == ENetPacketPeer.STATE_CONNECTED
	return true


func _authority_message() -> bool:
	return _connected() and not _host() and _network.get_remote_sender_id() == 1


func _new_token() -> int:
	if _token >= MAX_TOKEN:
		return 0
	_token += 1
	return _token


## The host has staged and validated the destination before entering this method.
## No participant replaces its current document until every remaining peer is ready.
func synchronize_travel(offer: Dictionary) -> bool:
	if pending or not is_inside_tree() or not is_instance_valid(session) or not _host():
		last_error = "Only an idle authority can start travel."
		return false
	var packet := _encode(offer)
	if packet.is_empty() or not _valid_offer(offer):
		session.abort_staged_travel()
		last_error = "Travel offer is invalid or exceeds the network limit."
		return false
	_active_token = _new_token()
	if _active_token == 0 or generation >= MAX_TOKEN:
		session.abort_staged_travel()
		last_error = "Travel transaction counter exhausted."
		return false
	pending = true
	last_error = ""
	_deadline = Time.get_ticks_msec() + PREPARE_TIMEOUT_MS
	session.set_travel_frozen(true)
	# Join validation describes the previous world. Cancel it before preparing travel.
	for peer_id: int in _joining.keys():
		if _known_peer(peer_id):
			_abort.rpc_id(peer_id, int(_joining[peer_id].token), "Travel superseded joining.")
			_queued_joins[peer_id] = true
	_joining.clear()
	_participants.clear()
	_disconnected_during_travel.clear()
	var transaction := _active_token
	# A subsequent prepare must not race an earlier commit's admission reply.
	while pending and _active_token == transaction and not _expected_commits.is_empty():
		await get_tree().process_frame
	if not pending or _active_token != transaction or _exiting:
		return false
	for peer_id: int in _admitted.keys():
		if _known_peer(peer_id):
			_participants[peer_id] = false
			_prepare.rpc_id(peer_id, _active_token, generation + 1, false, packet)
	while pending and _active_token == transaction and not _all_ready():
		if Time.get_ticks_msec() >= _deadline:
			cancel_travel("Travel preparation timed out.")
			break
		await get_tree().process_frame
	if not pending or _active_token != transaction or _exiting:
		return false
	if not session.commit_staged_travel():
		cancel_travel("The authority could not commit the staged destination.")
		return false
	for peer_id: int in _disconnected_during_travel:
		session.remove_peer_player(peer_id)
	_disconnected_during_travel.clear()
	generation += 1
	_current_id = offer.descriptor.id
	_current_signature = offer.descriptor.signature
	_snapshot_sequence = 0
	# Commit is the irrevocable boundary. Reliable messages are ordered with aborts
	# and subsequent prepares; a missing commit reply must never roll back the host.
	var roster_packet := _encode(session.capture_player_roster())
	for peer_id: int in _participants:
		if _known_peer(peer_id):
			_expect_commit(peer_id, transaction)
			_commit.rpc_id(peer_id, transaction, generation, _snapshot_sequence, roster_packet)
	_participants.clear()
	pending = false
	session.set_travel_frozen(false)
	travel_finished.emit(true, "")
	_drain_joins.call_deferred()
	return true


func _all_ready() -> bool:
	for ready: bool in _participants.values():
		if not ready:
			return false
	return true


func cancel_travel(reason: String = "Travel cancelled.") -> void:
	if not pending:
		return
	last_error = reason.left(256)
	if _host():
		for peer_id: int in _participants:
			if _known_peer(peer_id):
				_abort.rpc_id(peer_id, _active_token, last_error)
		_participants.clear()
	elif _connected():
		_ready_reply.rpc_id(1, _active_token, _staged_generation, false)
	_clear_stage()
	if _client_join:
		_client_join = false
		join_finished.emit(false, last_error)
	else:
		travel_finished.emit(false, last_error)
	if _host() and not _exiting:
		_drain_joins.call_deferred()


func _clear_stage() -> void:
	pending = false
	if is_instance_valid(session):
		session.abort_staged_travel()
		session.set_travel_frozen(false)


## Safe before tree entry and while connecting; retries only the fixed join request.
func request_join() -> void:
	_join_requested = true
	_next_join_request = 0
	_try_request_join()


func _try_request_join() -> void:
	if not _join_requested or not _connected() or _host() or pending or _client_admitted:
		return
	var now := Time.get_ticks_msec()
	if now < _next_join_request:
		return
	_next_join_request = now + JOIN_RETRY_MS
	_request_current.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable")
func _request_current() -> void:
	var sender := _network.get_remote_sender_id()
	if not _host() or not _known_peer(sender) or _admitted.has(sender) or _joining.has(sender):
		return
	var now := Time.get_ticks_msec()
	if now < int(_join_attempt_at.get(sender, 0)):
		return
	_join_attempt_at[sender] = now + JOIN_RETRY_MS
	_queued_joins[sender] = true
	if not pending:
		_drain_joins()


func _drain_joins() -> void:
	if pending or _exiting or not _host() or not is_instance_valid(session):
		return
	for peer_id: int in _queued_joins.keys():
		_queued_joins.erase(peer_id)
		if not _known_peer(peer_id) or _admitted.has(peer_id) or _joining.has(peer_id):
			continue
		var offer: Dictionary = session.get_travel_offer()
		if not _valid_offer(offer):
			# The session may still be starting. The client retries after it is ready.
			continue
		var packet := _encode(offer)
		var transaction := _new_token()
		if packet.is_empty() or transaction == 0:
			continue
		_current_id = offer.descriptor.id
		_current_signature = offer.descriptor.signature
		_joining[peer_id] = {
			"token": transaction,
			"generation": generation,
			"deadline": Time.get_ticks_msec() + PREPARE_TIMEOUT_MS,
		}
		_prepare.rpc_id(peer_id, transaction, generation, true, packet)


@rpc("authority", "call_remote", "reliable")
func _prepare(
	transaction: int, offered_generation: int, joining: bool, packet: PackedByteArray
) -> void:
	if not _authority_message() or transaction <= _last_received_token or transaction > MAX_TOKEN:
		return
	if offered_generation < 0 or offered_generation > MAX_TOKEN:
		return
	if pending or (joining and _client_admitted) or (not joining and not _client_admitted):
		_ready_reply.rpc_id(1, transaction, offered_generation, false)
		return
	if not joining and offered_generation != generation + 1:
		_ready_reply.rpc_id(1, transaction, offered_generation, false)
		return
	_last_received_token = transaction
	var offer: Variant = _decode(packet)
	if not offer is Dictionary or not _valid_offer(offer):
		_ready_reply.rpc_id(1, transaction, offered_generation, false)
		return
	var result: Dictionary = session.stage_travel_offer(offer)
	if not result.get("success", false):
		session.abort_staged_travel()
		last_error = str(result.get("error", "Destination validation refused.")).left(256)
		_ready_reply.rpc_id(1, transaction, offered_generation, false)
		if joining:
			_join_requested = false
			join_finished.emit(false, last_error)
		return
	_active_token = transaction
	_staged_generation = offered_generation
	_staged_id = offer.descriptor.id
	_staged_signature = offer.descriptor.signature
	_client_join = joining
	pending = true
	# Give the host its complete preparation interval, including reply transit.
	_deadline = Time.get_ticks_msec() + PREPARE_TIMEOUT_MS * 2
	session.set_travel_frozen(true)
	_ready_reply.rpc_id(1, transaction, offered_generation, true)


@rpc("any_peer", "call_remote", "reliable")
func _ready_reply(transaction: int, offered_generation: int, accepted: bool) -> void:
	var sender := _network.get_remote_sender_id()
	if not _host() or not _known_peer(sender) or transaction <= 0 or transaction > MAX_TOKEN:
		return
	if pending and transaction == _active_token and offered_generation == generation + 1:
		if not _participants.has(sender):
			return
		if Time.get_ticks_msec() >= _deadline:
			cancel_travel("Travel preparation timed out.")
			return
		if not accepted:
			cancel_travel("A peer refused the destination.")
		else:
			_participants[sender] = true
		return
	if pending or not _joining.has(sender):
		return
	var joining: Dictionary = _joining[sender]
	if (
		transaction != joining.token
		or offered_generation != joining.generation
		or offered_generation != generation
	):
		return
	_joining.erase(sender)
	if not accepted or Time.get_ticks_msec() >= int(joining.deadline):
		_abort.rpc_id(sender, transaction, "Join validation refused or expired.")
		return
	# Only a validated client is represented by a live player on the authority.
	session.ensure_peer_player(sender)
	_admitted[sender] = true
	_expect_commit(sender, transaction)
	_commit.rpc_id(
		sender,
		transaction,
		generation,
		_snapshot_sequence,
		_encode(session.capture_player_roster())
	)
	_broadcast_roster()


@rpc("authority", "call_remote", "reliable")
func _commit(
	transaction: int, committed_generation: int, sequence: int, roster_packet: PackedByteArray
) -> void:
	if (
		not _authority_message()
		or not pending
		or transaction != _active_token
		or committed_generation != _staged_generation
	):
		return
	var roster: Variant = _decode(roster_packet)
	if not roster is Array or sequence < 0 or sequence > MAX_TOKEN:
		_commit_reply.rpc_id(1, transaction, committed_generation, false)
		cancel_travel("Invalid committed player roster.")
		return
	var was_join := _client_join
	if not session.commit_staged_travel():
		_commit_reply.rpc_id(1, transaction, committed_generation, false)
		cancel_travel("The staged destination could not be committed.")
		return
	generation = committed_generation
	_current_id = _staged_id
	_current_signature = _staged_signature
	_last_snapshot_sequence = sequence
	pending = false
	_client_join = false
	_client_admitted = true
	_join_requested = false
	last_error = ""
	var restored: bool = session.apply_player_roster(roster)
	if not restored:
		_client_admitted = false
	session.set_travel_frozen(false)
	_commit_reply.rpc_id(1, transaction, generation, restored)
	if was_join:
		join_finished.emit(restored, "" if restored else "Player roster could not be restored.")
	else:
		travel_finished.emit(restored, "" if restored else "Player roster could not be restored.")


@rpc("any_peer", "call_remote", "reliable")
func _commit_reply(transaction: int, committed_generation: int, success: bool) -> void:
	var sender := _network.get_remote_sender_id()
	if not _host() or not _known_peer(sender) or not _expected_commits.has(sender):
		return
	var expected: Dictionary = _expected_commits[sender]
	if transaction != expected.token or committed_generation != expected.generation:
		return
	_expected_commits.erase(sender)
	if not success or Time.get_ticks_msec() >= int(expected.deadline):
		_evict_uncommitted_peer(sender, transaction)

	else:
		session.set_peer_replication(sender, true)


func _expect_commit(peer_id: int, transaction: int) -> void:
	_expected_commits[peer_id] = {
		"token": transaction,
		"generation": generation,
		"deadline": Time.get_ticks_msec() + PREPARE_TIMEOUT_MS,
	}


func _evict_uncommitted_peer(peer_id: int, transaction: int) -> void:
	_admitted.erase(peer_id)
	_participants.erase(peer_id)
	if pending:
		_disconnected_during_travel.append(peer_id)
	session.remove_peer_player(peer_id)
	if _known_peer(peer_id):
		_reset_join.rpc_id(peer_id, transaction)
	_broadcast_roster()


@rpc("authority", "call_remote", "reliable")
func _reset_join(transaction: int) -> void:
	if not _authority_message() or transaction != _active_token:
		return
	if pending:
		_clear_stage()
	_client_join = false
	_client_admitted = false
	request_join()


@rpc("authority", "call_remote", "reliable")
func _abort(transaction: int, reason: String) -> void:
	if not _authority_message() or not pending or transaction != _active_token:
		return
	last_error = reason.left(256)
	var was_join := _client_join
	_clear_stage()
	_client_join = false
	if was_join:
		join_finished.emit(false, last_error)
	else:
		travel_finished.emit(false, last_error)


func _broadcast_roster() -> void:
	if pending or not _connected() or not _host() or _snapshot_sequence >= MAX_TOKEN:
		return
	var packet := _encode(session.capture_player_roster())
	if packet.is_empty():
		return
	_snapshot_sequence += 1
	for peer_id: int in _admitted:
		if _known_peer(peer_id):
			_expected_rosters[peer_id] = _snapshot_sequence
			_receive_roster.rpc_id(
				peer_id, generation, _current_id, _current_signature, _snapshot_sequence, packet
			)


@rpc("authority", "call_remote", "reliable")
func _receive_roster(
	world_generation: int,
	destination_id: String,
	signature: String,
	sequence: int,
	packet: PackedByteArray
) -> void:
	if (
		not _accept_current(world_generation, destination_id, signature)
		or sequence < _last_snapshot_sequence
		or sequence > MAX_TOKEN
	):
		return
	var roster: Variant = _decode(packet)
	if roster is Array and session.apply_player_roster(roster):
		_last_snapshot_sequence = sequence
		_roster_ready.rpc_id(1, world_generation, sequence)


@rpc("any_peer", "call_remote", "reliable")
func _roster_ready(world_generation: int, sequence: int) -> void:
	var sender := _network.get_remote_sender_id()
	if not _host() or pending or world_generation != generation or not _admitted.has(sender):
		return
	if not _known_peer(sender) or _expected_rosters.get(sender, -1) != sequence:
		return
	_expected_rosters.erase(sender)
	session.set_peer_replication(sender, true)


func _accept_current(world_generation: int, destination_id: String, signature: String) -> bool:
	return (
		_authority_message()
		and _client_admitted
		and not pending
		and world_generation == generation
		and destination_id == _current_id
		and signature == _current_signature
	)


@rpc("authority", "call_remote", "reliable", 1)
func _receive_snapshot(
	world_generation: int,
	destination_id: String,
	signature: String,
	sequence: int,
	packet: PackedByteArray
) -> void:
	if (
		not _accept_current(world_generation, destination_id, signature)
		or sequence <= _last_snapshot_sequence
		or sequence > MAX_TOKEN
	):
		return
	var snapshot: Variant = _decode(packet)
	if (
		not snapshot is Dictionary
		or not snapshot.get("runtime") is Dictionary
		or not snapshot.get("players") is Array
	):
		return
	if session.apply_runtime_update(snapshot.runtime):
		session.apply_player_roster(snapshot.players)
		_last_snapshot_sequence = sequence


func _process(delta: float) -> void:
	if _exiting:
		return
	_try_request_join()
	var now := Time.get_ticks_msec()
	if pending and now >= _deadline:
		cancel_travel("Travel preparation timed out.")
	if not _host() or not _connected():
		return
	for peer_id: int in _joining.keys():
		if now >= int(_joining[peer_id].deadline):
			if _known_peer(peer_id):
				_abort.rpc_id(peer_id, int(_joining[peer_id].token), "Join preparation timed out.")
			_joining.erase(peer_id)
	for peer_id: int in _expected_commits.keys():
		if now >= int(_expected_commits[peer_id].deadline):
			var transaction: int = _expected_commits[peer_id].token
			_expected_commits.erase(peer_id)
			_evict_uncommitted_peer(peer_id, transaction)
	if pending or _admitted.is_empty():
		return
	_snapshot_elapsed += delta
	if _snapshot_elapsed < SNAPSHOT_INTERVAL:
		return
	_snapshot_elapsed = 0.0
	if _snapshot_sequence >= MAX_TOKEN:
		return
	_snapshot_sequence += 1
	var packet := _encode(
		{
			"runtime": session.capture_runtime_state(),
			"players": session.capture_player_roster(),
		}
	)
	if packet.is_empty():
		return
	for peer_id: int in _admitted:
		if _known_peer(peer_id) and not _expected_commits.has(peer_id):
			_receive_snapshot.rpc_id(
				peer_id, generation, _current_id, _current_signature, _snapshot_sequence, packet
			)


func _on_peer_connected(_peer_id: int) -> void:
	# Do not send to a peer until its matching persistent RPC node requests joining.
	_try_request_join()


func _on_peer_disconnected(peer_id: int) -> void:
	if not _host():
		if peer_id == 1:
			_on_connection_lost()
		return
	_queued_joins.erase(peer_id)
	_joining.erase(peer_id)
	_expected_commits.erase(peer_id)
	_expected_rosters.erase(peer_id)
	_participants.erase(peer_id)
	if _admitted.erase(peer_id) and is_instance_valid(session):
		if pending:
			_disconnected_during_travel.append(peer_id)
		session.remove_peer_player(peer_id)
		_broadcast_roster()
	_join_attempt_at.erase(peer_id)


func _on_connected_to_server() -> void:
	_last_received_token = 0
	_client_admitted = false
	request_join()


func _on_connection_lost() -> void:
	if pending:
		last_error = "Connection to the authority was lost."
		var was_join := _client_join
		_clear_stage()
		_client_join = false
		if was_join:
			join_finished.emit(false, last_error)
		else:
			travel_finished.emit(false, last_error)
	_client_admitted = false
	_join_requested = false
	_participants.clear()
	_joining.clear()
	_queued_joins.clear()
	_admitted.clear()
	_expected_commits.clear()
	_join_attempt_at.clear()


func _valid_offer(offer: Dictionary) -> bool:
	var descriptor: Variant = offer.get("descriptor")
	return (
		descriptor is Dictionary
		and descriptor.get("id") is String
		and not descriptor.id.is_empty()
		and descriptor.id.length() <= 256
		and descriptor.get("path") is String
		and descriptor.path.length() <= 2048
		and descriptor.get("signature") is String
		and descriptor.signature.length() <= 256
		and descriptor.get("required_capabilities") is Array
		and offer.get("spawn_id") is String
		and offer.spawn_id.length() <= 256
		and offer.get("runtime") is Dictionary
		and offer.get("players") is Array
	)


func _encode(value: Variant) -> PackedByteArray:
	var remaining: Array[int] = [MAX_VALUE_COUNT]
	if not _safe_value(value, 0, remaining):
		return PackedByteArray()
	var packet := var_to_bytes(value)
	return packet if packet.size() <= MAX_PACKET_BYTES else PackedByteArray()


func _decode(packet: PackedByteArray) -> Variant:
	if packet.is_empty() or packet.size() > MAX_PACKET_BYTES:
		return null
	# bytes_to_var never enables object decoding (unlike bytes_to_var_with_objects).
	var value: Variant = bytes_to_var(packet)
	var remaining: Array[int] = [MAX_VALUE_COUNT]
	return value if _safe_value(value, 0, remaining) else null


func _safe_value(value: Variant, depth: int, remaining: Array[int]) -> bool:
	remaining[0] -= 1
	if remaining[0] < 0 or depth > MAX_DEPTH:
		return false
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_VECTOR2I, TYPE_RECT2I, TYPE_VECTOR3I, TYPE_VECTOR4I:
			return true
		TYPE_FLOAT:
			return is_finite(value)
		TYPE_STRING, TYPE_STRING_NAME, TYPE_NODE_PATH:
			return str(value).length() <= MAX_PACKET_BYTES
		TYPE_VECTOR2, TYPE_VECTOR3, TYPE_VECTOR4, TYPE_QUATERNION, TYPE_BASIS, TYPE_TRANSFORM2D, TYPE_TRANSFORM3D:
			return value.is_finite()
		TYPE_COLOR:
			return (
				is_finite(value.r)
				and is_finite(value.g)
				and is_finite(value.b)
				and is_finite(value.a)
			)
		TYPE_ARRAY:
			if value.size() > remaining[0]:
				return false
			for item: Variant in value:
				if not _safe_value(item, depth + 1, remaining):
					return false
			return true
		TYPE_DICTIONARY:
			if value.size() * 2 > remaining[0]:
				return false
			for key: Variant in value:
				if (
					not (key is String or key is StringName)
					or not _safe_value(key, depth + 1, remaining)
					or not _safe_value(value[key], depth + 1, remaining)
				):
					return false
			return true
		TYPE_PACKED_BYTE_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_STRING_ARRAY, TYPE_PACKED_VECTOR2_ARRAY, TYPE_PACKED_VECTOR3_ARRAY, TYPE_PACKED_VECTOR4_ARRAY, TYPE_PACKED_COLOR_ARRAY:
			return value.size() <= MAX_VALUE_COUNT
	return false
