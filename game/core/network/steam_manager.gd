class_name SteamManager
extends Node

const Constants = preload("res://game/core/constants.gd")

signal steam_initialized
signal steam_auth_ticket_validated(steam_id: int, response: int)
signal lobby_created(lobby_id: int)
signal lobby_joined(lobby_id: int)
signal lobby_join_failed(reason: String)
signal lobby_list_received(lobbies: Array)
signal lobby_member_joined(steam_id: int)
signal lobby_member_left(steam_id: int)
signal persona_state_changed(steam_id: int)
signal achievement_unlocked(achievement_name: String)

const AUTH_SESSION_UNAVAILABLE := -1
const AUTH_SESSION_METHOD_UNAVAILABLE := -2
const AUTH_SESSION_INVALID_TICKET := -3

const LOBBY_TYPE_PRIVATE := 0
const LOBBY_TYPE_FRIENDS := 1
const LOBBY_TYPE_PUBLIC := 2
const LOBBY_TYPE_INVISIBLE := 3

var _steam_available: bool = false
var _is_server: bool = false
var _current_lobby_id: int = 0
var _steam_id: int = 0
var _steam_username: String = ""


## Helper to safely log messages
func _log_info(message: String, category: String = "Core") -> void:
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm:
		var logger: Variant = gm.get_core_system("logger")
		if logger and logger.has_method("info"):
			logger.info(message, category)
			return
	print(message)


func _ready() -> void:
	_steam_available = _check_steam_available()

	if _steam_available:
		# We don't auto-init here because we might be a dedicated server
		# which requires different initialization.
		# Client init happens in _initialize_steam() called explicitly or via check.
		# For now, we assume client init unless told otherwise, but we'll safe check.
		if not DisplayServer.get_name() == "headless":
			_initialize_steam_client()
	else:
		_log_info("[SteamManager] Steam not available - using fallback networking")


func _check_steam_available() -> bool:
	# Check if GodotSteam is present
	return Engine.has_singleton("Steam") or ClassDB.class_exists("Steam")


func _steam_has_any_method(steam: Object, method_names: Array[String]) -> bool:
	if not steam:
		return false
	for method_name: String in method_names:
		if steam.has_method(method_name):
			return true
	return false


func _steam_call_first(steam: Object, method_names: Array[String], args: Array) -> Variant:
	if not steam:
		return null
	for method_name: String in method_names:
		if steam.has_method(method_name):
			return steam.callv(method_name, args)
	return null


func _steam_result_succeeded(result: Variant) -> bool:
	if result is Dictionary:
		return int(result.get("status", 0)) == 1
	if result is bool:
		return result
	if result is int:
		return result == 1 or result == OK
	# GodotSteam setters/logon methods commonly return void.
	return result == null


## Initialize Steam for a Client
func _initialize_steam_client() -> void:
	if not _steam_available:
		return

	var steam: Object = Engine.get_singleton("Steam")
	var init_result: Variant = steam.steamInit(false)
	var init_success := false
	var init_verbal := "unknown result"
	if init_result is Dictionary:
		init_success = int(init_result.get("status", 0)) == 1
		init_verbal = str(init_result.get("verbal", init_verbal))
	elif init_result is bool:
		init_success = init_result
		init_verbal = "Steam API returned false"
	if not init_success:
		push_error("[SteamManager] Steam init failed: %s" % init_verbal)
		_steam_available = false
		return

	_steam_id = steam.getSteamID()
	_steam_username = steam.getPersonaName()
	_log_info("[SteamManager] Logged in as: %s (ID: %d)" % [_steam_username, _steam_id])

	_connect_steam_signals()
	steam_initialized.emit()


## Initialize Steam for a Dedicated Server
##
## Returns true when the Steam Game Server API was initialized and the
## configured login/heartbeat calls were dispatched. Authentication completion
## remains asynchronous and is reported by the GodotSteam callbacks.
func initialize_steam_server(data: Dictionary) -> bool:
	_is_server = false
	if not _steam_available or not Engine.has_singleton("Steam"):
		return false

	var steam: Object = Engine.get_singleton("Steam")
	var ip: String = data.get("ip", "0.0.0.0")
	var game_port: int = data.get("steam_game_port", 27015)
	var query_port: int = data.get("steam_query_port", 27016)
	var server_mode: int = data.get("server_mode", 1)  # 1 = Auth, 2 = NoAuth, 3 = Password
	var version: String = data.get("version", Constants.GAME_VERSION)
	var init_methods: Array[String] = ["initGameServer", "gameServerInit"]
	if not _steam_has_any_method(steam, init_methods):
		push_error("[SteamManager] GodotSteam has no Game Server initialization method")
		return false

	var init_result: Variant = _steam_call_first(
		steam, init_methods, [ip, game_port, query_port, server_mode, version]
	)
	if not _steam_result_succeeded(init_result):
		push_error("[SteamManager] Failed to initialize Steam Game Server")
		return false

	_steam_call_first(
		steam, ["setGameServerModDir", "gameServer_SetModDir", "gameServerSetModDir"], ["modus"]
	)
	_steam_call_first(
		steam, ["setGameServerProduct", "gameServer_SetProduct", "gameServerSetProduct"], ["modus"]
	)
	_steam_call_first(
		steam,
		["setGameDescription", "gameServer_SetGameDescription", "gameServerSetGameDescription"],
		[data.get("description", "MODUS Server")]
	)
	_steam_call_first(
		steam,
		["setServerName", "gameServer_SetServerName", "gameServerSetServerName"],
		[data.get("name", "Unconfigured Server")]
	)
	_steam_call_first(
		steam,
		["setMaxPlayerCount", "gameServer_SetMaxPlayerCount", "gameServerSetMaxPlayerCount"],
		[data.get("max_players", 16)]
	)
	_steam_call_first(steam, ["setPasswordProtected", "gameServer_SetPasswordProtected"], [false])
	_steam_call_first(steam, ["setDedicatedServer", "gameServer_SetDedicatedServer"], [true])

	var token: String = data.get("steam_server_token", "")
	var login_methods: Array[String] = (
		["logOn", "gameServer_LogOn", "gameServerLogOn"]
		if token != ""
		else ["logOnAnonymous", "gameServer_LogOnAnonymous", "gameServerLogOnAnonymous"]
	)
	if not _steam_has_any_method(steam, login_methods):
		push_error("[SteamManager] GodotSteam has no Game Server login method")
		return false
	_steam_call_first(steam, login_methods, [token] if token != "" else [])

	var heartbeat_methods: Array[String] = [
		"enableHeartbeats",
		"gameServer_EnableHeartbeats",
		"gameServerEnableHeartbeats",
	]
	if not _steam_has_any_method(steam, heartbeat_methods):
		push_error("[SteamManager] GodotSteam has no Game Server heartbeat method")
		return false
	_steam_call_first(steam, heartbeat_methods, [true])
	_is_server = true

	_log_info(
		"Steam Dedicated Server Initialized on ports %d/%d" % [game_port, query_port],
		"SteamManager"
	)
	return true


## Compatibility entrypoint used by DedicatedServer.
func init_game_server(
	game_port: int, max_players: int, server_name: String, description: String
) -> bool:
	return initialize_steam_server(
		{
			"steam_game_port": game_port,
			"steam_query_port": game_port + 1,
			"max_players": max_players,
			"name": server_name,
			"description": description,
		}
	)


func _connect_steam_signals() -> void:
	var steam: Object = Engine.get_singleton("Steam")
	# Standard Lobbies - with safety checks
	if not steam.lobby_created.is_connected(_on_lobby_created):
		steam.lobby_created.connect(_on_lobby_created)
	if not steam.lobby_joined.is_connected(_on_lobby_joined):
		steam.lobby_joined.connect(_on_lobby_joined)
	if not steam.lobby_match_list.is_connected(_on_lobby_match_list):
		steam.lobby_match_list.connect(_on_lobby_match_list)
	if not steam.lobby_chat_update.is_connected(_on_lobby_chat_update):
		steam.lobby_chat_update.connect(_on_lobby_chat_update)
	if not steam.persona_state_change.is_connected(_on_persona_state_change):
		steam.persona_state_change.connect(_on_persona_state_change)
	_connect_first_signal(
		steam,
		["validate_auth_ticket_response", "validate_auth_ticket_response_t"],
		Callable(self, "_on_validate_auth_ticket_response")
	)


func _connect_first_signal(steam: Object, signal_names: Array[String], callback: Callable) -> bool:
	if not steam:
		return false
	for signal_name: String in signal_names:
		if steam.has_signal(signal_name):
			if not steam.is_connected(signal_name, callback):
				steam.connect(signal_name, callback)
			return true
	return false


func _process(_delta: float) -> void:
	pump_callbacks()


## Pump Steam callbacks for the active client or dedicated-server profile.
## Returns false when Steam or the profile's callback API is unavailable.
func pump_callbacks() -> bool:
	if not _steam_available:
		return false
	var steam: Object = Engine.get_singleton("Steam")
	if not steam:
		return false

	var callback_methods: Array[String] = (
		["gameServerRunCallbacks", "gameServer_RunCallbacks", "game_server_run_callbacks"]
		if _is_server
		else ["runCallbacks", "run_callbacks"]
	)
	if not _steam_has_any_method(steam, callback_methods):
		return false
	_steam_call_first(steam, callback_methods, [])
	return true


# ============================================================================
# PUBLIC API - Steam Status
# ============================================================================

## Check if Steam is running and available


func is_steam_running() -> bool:
	return _steam_available and Engine.get_singleton("Steam") != null


## Get current user's Steam ID


func get_steam_id() -> int:
	return _steam_id


## Get current user's display name


func get_persona_name() -> String:
	if _steam_available:
		return _steam_username
	return "Player"


## Get friend's display name by Steam ID


func get_friend_persona_name(steam_id: int) -> String:
	if _steam_available:
		var steam: Object = Engine.get_singleton("Steam")
		return steam.getFriendPersonaName(steam_id)
	return "Player_%d" % steam_id


# ============================================================================
# PUBLIC API - Lobbies
# ============================================================================

## Create a new Steam lobby


func create_lobby(max_players: int = 8, lobby_type: int = LOBBY_TYPE_PUBLIC) -> void:
	if not _steam_available:
		push_error("[SteamManager] Cannot create lobby - Steam not available")
		return

	_log_info("[SteamManager] Creating lobby (max %d players)..." % max_players)
	var steam: Object = Engine.get_singleton("Steam")
	steam.createLobby(lobby_type, max_players)


## Join an existing lobby


func join_lobby(lobby_id: int) -> void:
	if not _steam_available:
		push_error("[SteamManager] Cannot join lobby - Steam not available")
		return

	_log_info("[SteamManager] Joining lobby: %d" % lobby_id)
	var steam: Object = Engine.get_singleton("Steam")
	steam.joinLobby(lobby_id)


## Leave current lobby


func leave_lobby() -> void:
	if _current_lobby_id == 0:
		return

	if _steam_available:
		_log_info("[SteamManager] Leaving lobby: %d" % _current_lobby_id)
		var steam: Object = Engine.get_singleton("Steam")
		steam.leaveLobby(_current_lobby_id)

	_current_lobby_id = 0


## Get current lobby ID (0 if not in a lobby)


func get_current_lobby_id() -> int:
	return _current_lobby_id


## Request list of available lobbies


func request_lobby_list() -> void:
	if not _steam_available:
		lobby_list_received.emit([])
		return

	_log_info("[SteamManager] Requesting lobby list...")
	var steam: Object = Engine.get_singleton("Steam")
	# Add default filter to find only our game's lobbies
	steam.addRequestLobbyListStringFilter("game", "modus", steam.LOBBY_COMPARISON_EQUAL)
	steam.requestLobbyList()


## Set lobby metadata (host only)


func set_lobby_data(key: String, value: String) -> bool:
	if _current_lobby_id == 0 or not _steam_available:
		return false

	var steam: Object = Engine.get_singleton("Steam")
	return steam.setLobbyData(_current_lobby_id, key, value)


## Get lobby metadata


func get_lobby_data(lobby_id: int, key: String) -> String:
	if not _steam_available:
		return ""

	var steam: Object = Engine.get_singleton("Steam")
	return steam.getLobbyData(lobby_id, key)


## Get number of members in a lobby


func get_lobby_member_count(lobby_id: int) -> int:
	if not _steam_available:
		return 0

	var steam: Object = Engine.get_singleton("Steam")
	return steam.getNumLobbyMembers(lobby_id)


## Get Steam ID of lobby member by index


func get_lobby_member_by_index(lobby_id: int, member_index: int) -> int:
	if not _steam_available:
		return 0

	var steam: Object = Engine.get_singleton("Steam")
	return steam.getLobbyMemberByIndex(lobby_id, member_index)


## Add a lobby list filter (string match)


func add_lobby_list_string_filter(key: String, value: String, comparison: int = 0) -> void:
	if not _steam_available:
		return

	var steam: Object = Engine.get_singleton("Steam")
	steam.addRequestLobbyListStringFilter(key, value, comparison)


# ============================================================================
# PUBLIC API - Auth & Dedicated Server
# ============================================================================


## Get an Auth Ticket to send to the server.
## The returned buffer is normalized to Array for RPC validation.
func get_auth_ticket() -> Dictionary:
	if not _steam_available:
		return {}

	var steam: Object = Engine.get_singleton("Steam")
	var ticket_methods: Array[String] = ["getAuthSessionTicket", "get_auth_session_ticket"]
	if not _steam_has_any_method(steam, ticket_methods):
		return {}
	return _normalize_auth_ticket(_steam_call_first(steam, ticket_methods, []))


func _normalize_auth_ticket(result: Variant) -> Dictionary:
	if result is Dictionary:
		var ticket_id: int = int(result.get("id", result.get("ticket_id", 0)))
		var buffer: Array = _normalize_auth_ticket_buffer(
			result.get("buffer", result.get("ticket", []))
		)
		if ticket_id > 0 and not buffer.is_empty():
			return {"id": ticket_id, "buffer": buffer}
		return {}

	if result is Array and result.size() >= 2:
		var array_id: int = int(result[0])
		var array_buffer: Array = _normalize_auth_ticket_buffer(result[1])
		if array_id > 0 and not array_buffer.is_empty():
			return {"id": array_id, "buffer": array_buffer}
	return {}


func _normalize_auth_ticket_buffer(buffer: Variant) -> Array:
	if buffer is Array:
		return buffer
	if buffer is PackedByteArray:
		var normalized: Array = []
		for byte: int in buffer:
			normalized.append(byte)
		return normalized
	return []


## Begin Auth Session (Server Side).
## A zero result means asynchronous validation started successfully.
func begin_auth_session(steam_id: int, ticket: Array) -> int:
	if not _steam_available:
		return AUTH_SESSION_UNAVAILABLE
	if steam_id <= 0 or ticket.is_empty():
		return AUTH_SESSION_INVALID_TICKET

	var steam: Object = Engine.get_singleton("Steam")
	var auth_methods: Array[String] = ["beginAuthSession", "begin_auth_session"]
	if not _steam_has_any_method(steam, auth_methods):
		return AUTH_SESSION_METHOD_UNAVAILABLE

	var result: Variant = _steam_call_first(steam, auth_methods, [ticket, ticket.size(), steam_id])
	if result is int:
		return result
	if result is bool:
		return 0 if result else AUTH_SESSION_METHOD_UNAVAILABLE
	return AUTH_SESSION_METHOD_UNAVAILABLE


## End Auth Session.
func end_auth_session(steam_id: int) -> void:
	if not _steam_available or steam_id <= 0:
		return

	var steam: Object = Engine.get_singleton("Steam")
	_steam_call_first(steam, ["endAuthSession", "end_auth_session"], [steam_id])


# ============================================================================
# PUBLIC API - Achievements
# ============================================================================

## Unlock a Steam achievement


func unlock_achievement(achievement_name: String) -> bool:
	if not _steam_available:
		_log_info("[SteamManager] Achievement unlocked (local): %s" % achievement_name)
		return true

	# Only unlock if not already achieved
	if is_achievement_unlocked(achievement_name):
		return true

	_log_info("[SteamManager] Unlocking achievement: %s" % achievement_name)
	var steam: Object = Engine.get_singleton("Steam")
	steam.setAchievement(achievement_name)
	steam.storeStats()

	achievement_unlocked.emit(achievement_name)
	return true


## Check if achievement is unlocked


func is_achievement_unlocked(achievement_name: String) -> bool:
	if not _steam_available:
		return false

	var steam: Object = Engine.get_singleton("Steam")
	var result: Dictionary = steam.getAchievement(achievement_name)
	if result.has("achieved"):
		return result["achieved"]
	return false


## Reset all achievements (for testing)


func reset_all_achievements() -> void:
	if not _steam_available:
		return

	_log_info("[SteamManager] Resetting all achievements...")
	var steam: Object = Engine.get_singleton("Steam")
	steam.resetAllStats(true)


# ============================================================================
# STEAM CALLBACKS
# ============================================================================


func _on_lobby_created(result: int, lobby_id: int) -> void:
	if result == 1:  # k_EResultOK
		_current_lobby_id = lobby_id
		_log_info("[SteamManager] Lobby created: %d" % lobby_id)

		# Set default lobby data
		set_lobby_data("game", "modus")
		set_lobby_data("version", Constants.GAME_VERSION)
		set_lobby_data("name", get_persona_name() + "'s Game")

		# Allow join via friends list
		var steam: Object = Engine.get_singleton("Steam")
		steam.setLobbyJoinable(lobby_id, true)

		lobby_created.emit(lobby_id)
	else:
		push_error("[SteamManager] Failed to create lobby: %d" % result)


func _on_lobby_joined(lobby_id: int, _permissions: int, _locked: bool, result: int) -> void:
	if result == 1:  # k_EResultOK
		_current_lobby_id = lobby_id
		_log_info("[SteamManager] Joined lobby: %d" % lobby_id)
		lobby_joined.emit(lobby_id)
	else:
		push_error("[SteamManager] Failed to join lobby: %d" % result)
		lobby_join_failed.emit("Join failed with result %d" % result)


func _on_lobby_match_list(lobbies: Array) -> void:
	_log_info("[SteamManager] Found %d lobbies" % lobbies.size())
	lobby_list_received.emit(lobbies)


func _on_lobby_chat_update(
	_lobby_id: int, changed_id: int, _making_change_id: int, chat_state: int
) -> void:
	# chat_state 1=Joined, 2=Left, 4=Disconnect, 8=Kicked, 16=Banned
	if chat_state == 1:
		lobby_member_joined.emit(changed_id)
	elif chat_state == 2 or chat_state == 4:
		lobby_member_left.emit(changed_id)


func _on_persona_state_change(steam_id: int, _flags: int) -> void:
	persona_state_changed.emit(steam_id)


func _on_validate_auth_ticket_response(
	steam_id: int, auth_session_response: int, _owner_steam_id: int
) -> void:
	steam_auth_ticket_validated.emit(steam_id, auth_session_response)


# ============================================================================
# NETWORKING INTEGRATION
# ============================================================================


## Return the detected Steam/ENet transport capabilities.
func get_transport_capabilities() -> Dictionary:
	var steam_service := is_steam_running()
	var peer_class := ClassDB.class_exists("SteamMultiplayerPeer")
	var reason := "ready"
	if not steam_service:
		reason = "steam_service_unavailable"
	elif not peer_class:
		reason = "steam_peer_class_unavailable"
	return {
		"steam_service": steam_service,
		"steam_peer_class": peer_class,
		"steam_transport": steam_service and peer_class,
		"enet_transport": true,
		"reason": reason,
	}


## Return true only when Steam transport can be attempted safely.
func is_steam_transport_available() -> bool:
	return bool(get_transport_capabilities().get("steam_transport", false))


## Get a multiplayer peer (Steam or ENet fallback).


func create_multiplayer_peer_host(_port: int = 9999) -> MultiplayerPeer:
	var capabilities: Dictionary = get_transport_capabilities()
	if not capabilities.steam_transport:
		push_warning("[SteamManager] Cannot create Steam host - %s" % capabilities.reason)
		return null

	# Use Steam networking
	var steam_peer_class: MultiplayerPeer = ClassDB.instantiate("SteamMultiplayerPeer")
	if not steam_peer_class:
		push_error("[SteamManager] Failed to instantiate SteamMultiplayerPeer")
		return null

	_log_info("[SteamManager] Creating Steam Host...")
	# 0 for using the SteamNetworkingSockets, 0 is EServerMode.eServerModeNoAuthentication
	var err: int = steam_peer_class.create_host(0)
	if err == OK:
		return steam_peer_class

	push_error("[SteamManager] Failed to create Steam Host: %d" % err)
	return null


## Get a multiplayer peer for clients


func create_multiplayer_peer_client(host: String, _port: int = 9999) -> MultiplayerPeer:
	var capabilities: Dictionary = get_transport_capabilities()
	if not capabilities.steam_transport:
		push_warning("[SteamManager] Cannot create Steam client - %s" % capabilities.reason)
		return null

	if not host.is_valid_int():
		push_warning("[SteamManager] Invalid Steam ID: %s" % host)
		return null

	# Use Steam networking if host is a SteamID
	_log_info("[SteamManager] Connecting to Steam Host: %s" % host)

	# Version check if in lobby
	if _current_lobby_id != 0:
		var lobby_version: String = get_lobby_data(_current_lobby_id, "version")
		if not lobby_version.is_empty() and lobby_version != Constants.GAME_VERSION:
			push_error(
				(
					"[SteamManager] Version mismatch! Client: %s, Server: %s"
					% [Constants.GAME_VERSION, lobby_version]
				)
			)
			return null

	var steam_peer_class: MultiplayerPeer = ClassDB.instantiate("SteamMultiplayerPeer")
	if not steam_peer_class:
		push_error("[SteamManager] Failed to instantiate SteamMultiplayerPeer")
		return null

	var err: int = steam_peer_class.create_client(host.to_int(), 0)
	if err == OK:
		return steam_peer_class

	push_error("[SteamManager] Failed to create Steam Client: %d" % err)
	return null


## Get multiplayer peer (fallback to ENet if Steam unavailable)


func get_multiplayer_peer() -> MultiplayerPeer:
	if is_steam_transport_available():
		var steam_peer: MultiplayerPeer = ClassDB.instantiate("SteamMultiplayerPeer")
		if steam_peer:
			return steam_peer

	# Fallback to ENet
	var enet_peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	return enet_peer


## Check if Steam is available


func is_steam_available() -> bool:
	return _steam_available
