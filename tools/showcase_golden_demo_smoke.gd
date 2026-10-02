extends SceneTree

const SHOWCASE_SCENE := "res://game/world/maps/showcase.tscn"
const PLAYER_SCENE := "res://game/entities/player/player.tscn"
const ENEMY_SCENE := "res://game/entities/enemies/enemy.tscn"
const PICKUP_SCENE := "res://game/scenes/items/pickups/health_pickup.tscn"
const SAMPLE_MOD_ID := "modus_sdk_sample"
const SAMPLE_MOD_NAME := "MODUS SDK Sample"
const SAVE_SLOT := "showcase_smoke"
const REQUIRED_STEP_COUNT := 10
const GALLERY_START_POSITION := Vector3(20, 2, 55)
const GALLERY_GAMEPLAY_TARGET := Vector3(20, 2, 28)
const GALLERY_OVERVIEW_POSITION := Vector3(20, 8, 56)
const GALLERY_OVERVIEW_TARGET := Vector3(20, 2, 24)
const TEXTURED_CHARACTER_POSITION := Vector3(37.5, 1.5, 14.5)
const TEXTURED_CHARACTER_TARGET := Vector3(35.625, 1.1, 9.375)

var _results: Array[Dictionary] = []
var _steps_box: VBoxContainer
var _status_label: Label


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _wait_frames(10)
	var game_manager: Node = root.get_node_or_null("GameManager")
	if not game_manager:
		_record("services", false, "GameManager autoload is unavailable")
		await _finish()
		return

	var scene_error := change_scene_to_file(SHOWCASE_SCENE)
	if scene_error != OK:
		_record("scene", false, "Showcase scene failed to load: %s" % error_string(scene_error))
		await _finish()
		return

	await scene_changed
	await _wait_frames(30)
	var world: Node = current_scene
	_configure_capture_rendering(world)
	_create_overlay(world)
	_record(
		"scene",
		world != null and world.scene_file_path == SHOWCASE_SCENE,
		"Maintained showcase scene loaded"
	)

	var asset_dressing: Node = world.get_node_or_null("AssetDressing") if world else null
	var asset_contract: Dictionary = (
		asset_dressing.get_asset_usage_contract()
		if asset_dressing and asset_dressing.has_method("get_asset_usage_contract")
		else {}
	)
	var texture_assets_ready := (
		bool(asset_contract.get("valid", false))
		and int(asset_contract.get("spawned_models", 0)) > 0
		and int(asset_contract.get("spawned_materials", 0)) > 0
		and int(asset_contract.get("spawned_textures", 0)) > 0
	)
	_record(
		"texture_assets",
		texture_assets_ready,
		"Texture-backed model, material, and image exhibits loaded"
	)

	var map_scatter: Node = world.get_node_or_null("MapAssetScatter") if world else null
	var scatter_contract: Dictionary = (
		map_scatter.get_asset_usage_contract()
		if map_scatter and map_scatter.has_method("get_asset_usage_contract")
		else {}
	)
	var map_assets_ready: bool = (
		bool(scatter_contract.get("valid", false))
		and str(scatter_contract.get("profile", "")) == "showcase"
		and int(scatter_contract.get("spawned_models", 0)) >= 40
	)
	_record(
		"map_asset_scatter",
		map_assets_ready,
		(
			"%d collision-free imported model props loaded across demo zones"
			% int(scatter_contract.get("spawned_models", 0))
		)
	)
	if not world or not world.has_method("spawn_player_node"):
		_record("player", false, "Showcase world cannot spawn a player")
		await _finish()
		return

	world.spawn_player_node(1, "player")
	var player: Node3D = await _wait_for_player()
	var player_ready := player != null and player.weapon_manager != null
	_record("player", player_ready, "Player spawned with gameplay components")
	if not player_ready:
		await _finish()
		return

	var hud := player.get_node_or_null("HUDLayer") as CanvasLayer
	if hud:
		hud.visible = false

	player.global_position = GALLERY_START_POSITION
	player.camera.look_at(GALLERY_GAMEPLAY_TARGET, Vector3.UP)
	await _wait_frames(5)
	if _signal_video_ready():
		await create_timer(1.0).timeout
	var start_position: Vector3 = player.global_position
	Input.action_press("up")
	await _wait_frames(30)
	Input.action_release("up")
	await _wait_frames(5)
	var moved_distance := start_position.distance_to(player.global_position)
	_record("movement", moved_distance >= 0.5, "Input moved the player %.2f m" % moved_distance)

	var enemy: Node3D = load(ENEMY_SCENE).instantiate()
	enemy.name = "GoldenSmokeEnemy"
	world.add_child(enemy)
	await _wait_frames(60)
	enemy.set_process(false)
	enemy.set_physics_process(false)
	var forward: Vector3 = -player.camera.global_transform.basis.z
	enemy.global_position = player.global_position + forward * 5.0
	player.camera.look_at(enemy.global_position + Vector3(0, 0.9, 0), Vector3.UP)
	if enemy.health_component:
		enemy.health_component.max_health = 1.0
		enemy.health_component.current_health = 1.0
	await _wait_frames(5)

	var shots_before: int = world.match_stats.get("shots_fired", 0)
	var kills_before: int = world.match_stats.get("enemies_killed", 0)
	player.weapon_manager.fire(true, true)
	await _wait_frames(120)
	var fired: bool = world.match_stats.get("shots_fired", 0) > shots_before
	var defeated: bool = (
		world.match_stats.get("enemies_killed", 0) > kills_before
		or not is_instance_valid(enemy)
		or enemy.is_dead
	)
	_record("weapon", fired, "Weapon fire reached the gameplay event path")
	_record("enemy", defeated, "The fired shot defeated a live enemy")

	var health_before := 50.0
	player.health = health_before
	var pickups_before: int = world.match_stats.get("items_collected", 0)
	var pickup: Node3D = load(PICKUP_SCENE).instantiate()
	pickup.name = "GoldenSmokePickup"
	world.add_child(pickup)
	pickup.global_position = player.global_position
	await _wait_frames(60)
	var pickup_collected: bool = (
		player.health > health_before
		and world.match_stats.get("items_collected", 0) > pickups_before
	)
	_record("pickup", pickup_collected, "Health pickup was collected and applied")

	var state_manager: Node = game_manager.get_core_system("state_manager")
	var save_passed := false
	if state_manager:
		state_manager.delete_save(SAVE_SLOT)
		var saved_position: Vector3 = player.global_position
		state_manager.save_game(SAVE_SLOT)
		await _wait_frames(5)
		if state_manager.save_exists(SAVE_SLOT):
			player.global_position += Vector3(9, 0, 0)
			await state_manager.load_game(SAVE_SLOT)
			await _wait_frames(10)
			save_passed = player.global_position.distance_to(saved_position) < 0.25
		state_manager.delete_save(SAVE_SLOT)
	_record("save_load", save_passed, "Encrypted slot save restored the player position")

	var mod_loader: Node = game_manager.get_core_system("mod_loader")
	var mod_passed := false
	if mod_loader:
		var original_enabled := false
		for mod_info: Dictionary in mod_loader.get_installed_mods():
			if mod_info.get("id", "") == SAMPLE_MOD_ID:
				original_enabled = mod_info.get("enabled", false)
				break
		mod_loader.set_mod_enabled(SAMPLE_MOD_ID, true)
		mod_loader.reload_mods()
		await _wait_frames(10)
		mod_passed = mod_loader.is_mod_loaded(SAMPLE_MOD_NAME)
		mod_loader.set_mod_enabled(SAMPLE_MOD_ID, original_enabled)
		mod_loader.reload_mods()
	_record("mod_loading", mod_passed, "Bundled SDK sample loaded through ModLoader")

	_prepare_capture_view(player)
	await create_timer(3.0).timeout
	player.global_position = GALLERY_OVERVIEW_POSITION
	player.camera.look_at(GALLERY_OVERVIEW_TARGET, Vector3.UP)
	await _finish()


func _wait_for_player() -> Node3D:
	for _frame in range(300):
		var players := get_nodes_in_group("player")
		if not players.is_empty():
			var player := players[0] as Node3D
			if player and "weapon_manager" in player and player.weapon_manager:
				return player
		await process_frame
	return null


func _wait_frames(count: int) -> void:
	for _frame in range(count):
		await process_frame


func _configure_capture_rendering(world: Node) -> void:
	var world_environment := world.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if world_environment and world_environment.environment:
		var environment := world_environment.environment.duplicate() as Environment
		environment.background_mode = Environment.BG_COLOR
		environment.background_color = Color(0.015, 0.02, 0.035)
		environment.background_energy_multiplier = 0.35
		environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		environment.ambient_light_color = Color(0.55, 0.62, 0.72)
		environment.ambient_light_energy = 0.15
		environment.fog_enabled = false
		world_environment.environment = environment

		var camera_attributes := CameraAttributesPractical.new()
		camera_attributes.exposure_multiplier = 0.1
		camera_attributes.auto_exposure_enabled = false
		world_environment.camera_attributes = camera_attributes

	var sun := world.get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	if sun:
		sun.light_energy = 0.35


func _signal_video_ready() -> bool:
	var path := OS.get_environment("MODUS_GOLDEN_SMOKE_VIDEO_READY")
	if path.is_empty():
		return false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not file:
		return false
	file.store_string("ready\n")
	file.close()
	return true


func _record(step: String, passed: bool, note: String) -> void:
	_results.append({"step": step, "status": "PASS" if passed else "FAIL", "note": note})
	print("GOLDEN_STEP|%s|%s|%s" % [step, "PASS" if passed else "FAIL", note])
	if _steps_box:
		var row := Label.new()
		row.text = "%s  %s" % ["PASS" if passed else "FAIL", note]
		row.add_theme_font_size_override("font_size", 15)
		row.add_theme_color_override(
			"font_color", Color(0.55, 0.95, 0.68) if passed else Color(1.0, 0.55, 0.55)
		)
		row.custom_minimum_size.x = 410
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_steps_box.add_child(row)


func _create_overlay(world: Node) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 200
	world.add_child(layer)

	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(overlay)

	var panel := PanelContainer.new()
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.offset_left = -494.0
	panel.offset_top = 24.0
	panel.offset_right = -24.0
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.025, 0.035, 0.06, 0.96)
	panel_style.border_color = Color(0.24, 0.48, 0.76, 0.95)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(12)
	panel_style.shadow_color = Color(0, 0, 0, 0.55)
	panel_style.shadow_size = 20
	panel_style.shadow_offset = Vector2(0, 8)
	panel.add_theme_stylebox_override("panel", panel_style)
	overlay.add_child(panel)

	var margins := MarginContainer.new()
	margins.add_theme_constant_override("margin_left", 22)
	margins.add_theme_constant_override("margin_right", 22)
	margins.add_theme_constant_override("margin_top", 20)
	margins.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margins)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	margins.add_child(content)

	var title := Label.new()
	title.text = "MODUS GOLDEN DEMO"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.94, 0.97, 1.0))
	content.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Automated framework-loop smoke"
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", Color(0.62, 0.75, 0.9))
	content.add_child(subtitle)
	content.add_child(HSeparator.new())

	_steps_box = VBoxContainer.new()
	_steps_box.add_theme_constant_override("separation", 5)
	content.add_child(_steps_box)

	content.add_child(HSeparator.new())
	_status_label = Label.new()
	_status_label.text = "RUNNING"
	_status_label.add_theme_font_size_override("font_size", 18)
	_status_label.add_theme_color_override("font_color", Color(0.9, 0.78, 0.4))
	content.add_child(_status_label)

	var boundary := Label.new()
	boundary.text = "Automated runtime proof. Manual feel, multiplayer, and release approval remain separate."
	boundary.add_theme_font_size_override("font_size", 12)
	boundary.add_theme_color_override("font_color", Color(0.62, 0.68, 0.78))
	boundary.custom_minimum_size.x = 410
	boundary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(boundary)


func _prepare_capture_view(player: Node3D) -> void:
	Input.action_release("up")
	player.set_process(false)
	player.set_physics_process(false)
	player.global_position = TEXTURED_CHARACTER_POSITION
	player.camera.look_at(TEXTURED_CHARACTER_TARGET, Vector3.UP)
	player.visuals.visible = false
	player.weapon_holder.visible = false
	var hud: CanvasLayer = player.get_node_or_null("HUDLayer")
	if hud:
		hud.visible = false
	for enemy: Node in get_nodes_in_group("enemies"):
		if is_instance_valid(enemy):
			enemy.visible = false


func _finish() -> void:
	var passed := _results.size() == REQUIRED_STEP_COUNT
	for result: Dictionary in _results:
		if result.status != "PASS":
			passed = false
			break

	if _status_label:
		_status_label.text = "OVERALL PASS" if passed else "OVERALL FAIL"
		_status_label.add_theme_color_override(
			"font_color", Color(0.55, 0.95, 0.68) if passed else Color(1.0, 0.55, 0.55)
		)

	await create_timer(3.0).timeout
	_save_capture()
	_write_result(passed)
	print("GOLDEN_RESULT|%s" % ("PASS" if passed else "FAIL"))
	await _wait_frames(5)
	quit(0 if passed else 1)


func _save_capture() -> void:
	var path := OS.get_environment("MODUS_GOLDEN_SMOKE_CAPTURE")
	if path.is_empty() or DisplayServer.get_name() == "headless":
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var image := root.get_texture().get_image()
	image.save_png(path)


func _write_result(passed: bool) -> void:
	var path := OS.get_environment("MODUS_GOLDEN_SMOKE_JSON")
	if path.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not file:
		return
	file.store_string(
		JSON.stringify(
			{
				"status": "PASS" if passed else "FAIL",
				"generated": Time.get_datetime_string_from_system(),
				"scene": SHOWCASE_SCENE,
				"steps": _results,
				"boundary": "Automated runtime smoke; not manual gameplay or release approval."
			},
			"  "
		)
	)
	file.close()
