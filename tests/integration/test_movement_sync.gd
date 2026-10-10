extends ModusGutTestBase

# Test MODUS Framework Movement Synchronization
# Converted from legacy Dictionary format to GUT assertions


func before_each() -> void:
	await modus_setup()


func after_each() -> void:
	modus_teardown()


func test_advanced_movement_exists() -> void:
	## Verify AdvancedMovement class/script exists
	var script_path: String = "res://game/entities/player/advanced_movement.gd"

	assert_true(
		ResourceLoader.exists(script_path), "advanced_movement.gd should exist at expected path"
	)

	if not ResourceLoader.exists(script_path):
		return

	var script: Script = load(script_path)
	assert_not_null(script, "Should be able to load advanced_movement.gd")


func test_bunny_hop_config() -> void:
	## Verify bunny hop configuration is present in gameplay config
	assert_gamecore_subsystem_exists("config")

	var gm: Node = get_node_or_null("/root/GameManager")
	var config: Node = gm.get_core_system("config") if gm else null
	assert_not_null(config, "Configuration service should be available")
	if not config:
		return

	var movement_cfg: Dictionary = config.get_value("gameplay.movement", {})
	assert_false(movement_cfg.is_empty(), "gameplay.movement config section should be found")

	var advanced_cfg: Dictionary = movement_cfg.get("advanced_movement", {})
	assert_true(advanced_cfg.get("enabled", false), "Advanced movement should be enabled")

	var bhop_cfg: Dictionary = advanced_cfg.get("bunny_hop", {})
	assert_false(bhop_cfg.is_empty(), "Bunny hop configuration should be present")
	assert_true(bhop_cfg.get("enabled", false), "Bunny hop should be enabled")
	assert_gt(float(bhop_cfg.get("speed_cap", 0.0)), 0.0, "Bunny hop speed cap should be positive")
	assert_gt(
		float(bhop_cfg.get("timing_window", 0.0)), 0.0, "Bunny hop timing window should be positive"
	)


func test_double_jump_properties() -> void:
	## Verify double jump state is represented by the movement component
	var script_path: String = "res://game/entities/player/components/player_movement_component.gd"

	assert_true(ResourceLoader.exists(script_path), "player_movement_component.gd should exist")
	if not ResourceLoader.exists(script_path):
		return

	var script: Script = load(script_path)
	assert_not_null(script, "Should be able to load player_movement_component.gd")
	if not script:
		return

	var source_code: String = script.source_code
	assert_true(source_code.contains("has_double_jump"), "Movement should expose double-jump state")
	assert_true(source_code.contains("jump_count"), "Movement should track jump count")
	assert_true(
		source_code.contains("elif has_double_jump and jump_count < 2"),
		"Movement should contain the double-jump branch"
	)
	assert_true(
		source_code.contains("func _perform_jump(is_double"), "Movement should expose jump helper"
	)


func test_air_strafe_config() -> void:
	## Verify air strafe settings exist
	assert_gamecore_subsystem_exists("config")

	var gm: Node = get_node_or_null("/root/GameManager")
	var config: Node = gm.get_core_system("config") if gm else null
	assert_not_null(config, "Configuration service should be available")
	if not config:
		return

	var movement_cfg: Dictionary = config.get_value("gameplay.movement", {})
	var advanced_cfg: Dictionary = movement_cfg.get("advanced_movement", {})
	var air_cfg: Dictionary = advanced_cfg.get("air_movement", {})

	assert_false(air_cfg.is_empty(), "Air movement configuration should be present")
	assert_gt(
		float(air_cfg.get("air_acceleration", 0.0)), 0.0, "Air acceleration should be positive"
	)
	assert_gt(
		float(air_cfg.get("air_strafe_speed", 0.0)), 0.0, "Air strafe speed should be positive"
	)
	assert_gt(float(air_cfg.get("max_air_speed", 0.0)), 0.0, "Maximum air speed should be positive")
	assert_gt(
		float(air_cfg.get("air_control_power", 0.0)), 0.0, "Air control power should be positive"
	)


func test_slide_config() -> void:
	## Verify slide mechanic configuration
	assert_gamecore_subsystem_exists("config")

	var gm: Node = get_node_or_null("/root/GameManager")
	var config: Node = gm.get_core_system("config") if gm else null
	assert_not_null(config, "Configuration service should be available")
	if not config:
		return

	var movement_cfg: Dictionary = config.get_value("gameplay.movement", {})
	var advanced_cfg: Dictionary = movement_cfg.get("advanced_movement", {})
	var slide_cfg: Dictionary = advanced_cfg.get("slide", {})

	assert_false(slide_cfg.is_empty(), "Slide configuration should be present")
	assert_true(slide_cfg.get("enabled", false), "Slide should be enabled")
	assert_gt(float(slide_cfg.get("speed", 0.0)), 0.0, "Slide speed should be positive")
	assert_gt(float(slide_cfg.get("duration", 0.0)), 0.0, "Slide duration should be positive")
	assert_gt(float(slide_cfg.get("cooldown", 0.0)), 0.0, "Slide cooldown should be positive")
	assert_gt(float(slide_cfg.get("friction", 0.0)), 0.0, "Slide friction should be positive")


func test_movement_sync_rpc_pattern() -> void:
	## Verify player movement sync follows RPC pattern
	var player_path: String = "res://game/entities/player/player.gd"

	assert_true(ResourceLoader.exists(player_path), "player.gd should exist")

	if not ResourceLoader.exists(player_path):
		return

	var script: Script = load(player_path)
	var source_code: String = script.source_code if script else ""

	# Check for multiplayer sync patterns
	var has_authority_check: bool = source_code.contains("is_multiplayer_authority()")
	var has_rpc: bool = source_code.contains("@rpc(")

	assert_true(has_authority_check, "Player should have is_multiplayer_authority() check")
	assert_true(has_rpc, "Player should have @rpc functions for sync")


func test_jump_state_exists() -> void:
	## Verify jump state machine state exists
	var jump_paths: Array = [
		"res://game/entities/player/components/states/inair_state.gd",
		"res://game/entities/player/components/states/jump_state.gd"
	]

	var found_jump_state: bool = false

	for path: String in jump_paths:
		if ResourceLoader.exists(path):
			found_jump_state = true
			break

	if not found_jump_state:
		# Check for embedded jumping logic in player if no separate state
		var player_path: String = "res://game/entities/player/player.gd"
		if ResourceLoader.exists(player_path):
			var script: Script = load(player_path)
			var source: String = script.source_code if script else ""
			if source.contains("jump") or source.contains("_jump"):
				found_jump_state = true

	assert_true(found_jump_state, "Jump state or jump logic should be found")


func test_velocity_sync() -> void:
	## Verify velocity synchronization capability
	var player_path: String = "res://game/entities/player/player.gd"

	assert_true(ResourceLoader.exists(player_path), "player.gd should exist")

	if not ResourceLoader.exists(player_path):
		return

	var script: Script = load(player_path)
	var source: String = script.source_code if script else ""

	# Check for velocity syncing (networked physics)
	var sync_patterns: Array = [
		"velocity", "sync_movement", "_sync_position", "MultiplayerSynchronizer"
	]

	var found_sync: bool = false
	for pattern: String in sync_patterns:
		if source.contains(pattern):
			found_sync = true
			break

	assert_true(found_sync, "Velocity sync pattern should be found in player")
