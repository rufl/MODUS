extends ModusGutTestBase

# Test MODUS Framework Steam integration
# Converted from legacy Dictionary format to GUT assertions


func before_each() -> void:
	await modus_setup()


func after_each() -> void:
	modus_teardown()


func _get_steam_manager() -> Node:
	var ns := NetworkSvc.get_service()
	if ns:
		return ns.steam_manager
	return null


# =============================================================================
# STEAM MANAGER AVAILABILITY
# =============================================================================


func test_steam_manager_exists() -> void:
	var steam := _get_steam_manager()
	assert_not_null(steam, "SteamManager should be found in NetworkService")


func test_steam_manager_has_required_methods() -> void:
	var steam := _get_steam_manager()
	assert_not_null(steam, "SteamManager should be available")

	if not steam:
		return

	var required_methods: Array[String] = [
		"create_lobby",
		"join_lobby",
		"leave_lobby",
		"request_lobby_list",
		"get_multiplayer_peer",
		"initialize_steam_server",
		"init_game_server",
		"shutdown_steam_server",
		"pump_callbacks",
		"get_auth_ticket",
		"begin_auth_session",
		"end_auth_session",
		"get_transport_capabilities",
		"is_steam_transport_available",
	]

	for method_name: String in required_methods:
		assert_true(
			steam.has_method(method_name), "SteamManager should have method: %s" % method_name
		)


# =============================================================================
# STEAM SIGNALS
# =============================================================================


func test_steam_manager_has_signals() -> void:
	var steam := _get_steam_manager()
	assert_not_null(steam, "SteamManager should be available")

	if not steam:
		return

	var required_signals: Array[String] = [
		"steam_initialized",
		"lobby_created",
		"lobby_joined",
		"lobby_join_failed",
		"lobby_list_received",
	]

	for signal_name: String in required_signals:
		assert_true(
			steam.has_signal(signal_name), "SteamManager should have signal: %s" % signal_name
		)


# =============================================================================
# ENET FALLBACK
# =============================================================================


func test_get_multiplayer_peer_returns_peer() -> void:
	var steam := _get_steam_manager()
	assert_not_null(steam, "SteamManager should be available")

	if not steam:
		return
	var peer: Variant = steam.get_multiplayer_peer()

	assert_true(peer != null, "get_multiplayer_peer() should return a peer")
	if not steam.is_steam_transport_available():
		assert_true(
			peer is ENetMultiplayerPeer,
			"Unavailable Steam transport must return an ENet fallback peer"
		)


func test_transport_capabilities_are_explicit() -> void:
	var steam := _get_steam_manager()
	assert_not_null(steam, "SteamManager should be available")
	if not steam:
		return

	var capabilities: Dictionary = steam.get_transport_capabilities()
	for key: String in [
		"steam_service",
		"steam_peer_class",
		"steam_transport",
		"enet_transport",
		"reason",
		"native_dependencies",
	]:
		assert_true(capabilities.has(key), "Transport capabilities should expose %s" % key)
	assert_true(capabilities.enet_transport, "ENet must remain available as fallback")
	assert_ne(str(capabilities.reason), "", "Transport capability reason should be explicit")
	var dependencies: Dictionary = capabilities.get("native_dependencies", {})
	assert_true(dependencies.has("godotsteam"))
	assert_true(dependencies.has("steam_multiplayer_peer"))
	assert_eq(dependencies.get("voxel_tools", {}).get("fallback"), "csg")
	assert_eq(
		capabilities.steam_transport,
		steam.is_steam_transport_available(),
		"Steam transport status must match the explicit capability contract"
	)


func test_steam_available_check() -> void:
	var steam := _get_steam_manager()
	assert_not_null(steam, "SteamManager should be available")

	if not steam:
		return

	# Should have a method to check if Steam is available
	if steam.has_method("is_steam_available"):
		var _available: bool = steam.is_steam_available()
		# Just verify it returns without crashing
		assert_true(true, "is_steam_available() should not crash")


func test_dedicated_server_contract_fails_closed_without_steam() -> void:
	var steam := _get_steam_manager()
	assert_not_null(steam, "SteamManager should be available")
	if not steam:
		return

	var original_available: bool = steam._steam_available
	steam._steam_available = false
	assert_false(
		steam.init_game_server(27015, 16, "Test Server", "Test Description"),
		"Dedicated server startup must fail closed when Steam is unavailable"
	)
	steam._steam_available = original_available


func test_dedicated_server_profile_preserves_steam_config() -> void:
	var server := DedicatedServer.new()
	server.config = {
		"port": 28015,
		"steam_query_port": 28016,
		"max_players": 24,
		"server_name": "Acceptance Server",
		"steam_server_description": "Acceptance Description",
		"steam_server_mode": 2,
		"steam_server_token": "token-fixture",
	}
	var profile: Dictionary = server._build_steam_server_profile()
	server.free()

	assert_eq(profile.get("game_port"), 28015)
	assert_eq(profile.get("query_port"), 28016)
	assert_eq(profile.get("max_players"), 24)
	assert_eq(profile.get("server_name"), "Acceptance Server")
	assert_eq(profile.get("description"), "Acceptance Description")
	assert_eq(profile.get("server_mode"), 2)
	assert_eq(profile.get("server_token"), "token-fixture")


func test_dedicated_server_shutdown_clears_server_profile() -> void:
	var steam := _get_steam_manager()
	assert_not_null(steam, "SteamManager should be available")
	if not steam:
		return

	var original_available: bool = steam._steam_available
	var original_server: bool = steam._is_server
	steam._steam_available = false
	steam._is_server = true
	assert_true(
		steam.shutdown_steam_server(),
		"Shutdown should clear an active server profile even when Steam is unavailable"
	)
	assert_false(steam._is_server, "Shutdown should clear the server callback profile")
	steam._steam_available = original_available
	steam._is_server = original_server


func test_callback_pump_fails_closed_without_steam() -> void:
	var steam := _get_steam_manager()
	assert_not_null(steam, "SteamManager should be available")
	if not steam:
		return

	var original_available: bool = steam._steam_available
	steam._steam_available = false
	assert_false(
		steam.pump_callbacks(), "Callback pumping must fail closed when Steam is unavailable"
	)
	steam._steam_available = original_available


func test_auth_contract_fails_closed_without_steam() -> void:
	var steam := _get_steam_manager()
	assert_not_null(steam, "SteamManager should be available")
	if not steam:
		return

	var original_available: bool = steam._steam_available
	steam._steam_available = false
	assert_eq(steam.get_auth_ticket(), {}, "Unavailable Steam must not emit an auth ticket")
	assert_eq(
		steam.begin_auth_session(123, [1, 2, 3]),
		steam.AUTH_SESSION_UNAVAILABLE,
		"Unavailable Steam must not accept auth sessions"
	)
	steam.end_auth_session(123)
	steam._steam_available = original_available


# =============================================================================
# LOBBY CONSTANTS
# =============================================================================


func test_lobby_type_constants_exist() -> void:
	var steam := _get_steam_manager()
	assert_not_null(steam, "SteamManager should be available")

	if not steam:
		return

	# Check for lobby type constants
	var expected_constants: Array[String] = [
		"LOBBY_TYPE_PRIVATE",
		"LOBBY_TYPE_FRIENDS",
		"LOBBY_TYPE_PUBLIC",
	]

	for const_name: String in expected_constants:
		assert_true(const_name in steam, "SteamManager should have constant: %s" % const_name)


# =============================================================================
# STEAM ID & USERNAME
# =============================================================================


func test_steam_id_accessors() -> void:
	var steam := _get_steam_manager()
	assert_not_null(steam, "SteamManager should be available")

	if not steam:
		return

	# Check for Steam ID accessor
	if steam.has_method("get_steam_id"):
		var _id: int = steam.get_steam_id()
		# Just verify it doesn't crash
		assert_true(true, "get_steam_id() should not crash")
	elif "_steam_id" in steam:
		var _id: int = steam._steam_id
		assert_true(true, "_steam_id property should be accessible")


func test_steam_username_accessors() -> void:
	var steam := _get_steam_manager()
	assert_not_null(steam, "SteamManager should be available")

	if not steam:
		return

	# Check for username accessor
	if steam.has_method("get_steam_username"):
		var _name: String = steam.get_steam_username()
		assert_true(true, "get_steam_username() should not crash")
	elif "_steam_username" in steam:
		var _name: String = steam._steam_username
		assert_true(true, "_steam_username property should be accessible")
