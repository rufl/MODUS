extends ModusGutTestBase

## Player-facing HUD integration contracts.

var _player: CharacterBody3D
var _hud_layer: CanvasLayer


func before_each() -> void:
	await super.before_each()
	await _setup_test_scene()


func after_each() -> void:
	if _player and is_instance_valid(_player):
		_player.queue_free()
		await get_tree().process_frame
	_player = null
	_hud_layer = null
	super.after_each()


func _setup_test_scene() -> void:
	var player_scene: PackedScene = preload("res://game/entities/player/player.tscn")
	_player = player_scene.instantiate() as CharacterBody3D
	assert_not_null(_player, "Player scene must instantiate for HUD integration")
	if not _player:
		return

	get_tree().root.add_child(_player)
	await get_tree().process_frame
	_hud_layer = _player.get_node_or_null("HUDLayer") as CanvasLayer
	assert_not_null(_hud_layer, "Player scene must contain HUDLayer")


func test_hud_layer_is_visible_and_attached_to_player() -> void:
	assert_true(_hud_layer.visible, "HUD layer should be visible")
	assert_true(_hud_layer.is_inside_tree(), "HUD should be in scene tree")
	assert_eq(_hud_layer.get_parent(), _player, "HUD should be child of player")
	assert_gt(_hud_layer.get_child_count(), 0, "HUD layer should contain authored elements")


func test_crosshair_is_centered() -> void:
	var crosshair: Control = _hud_layer.get_node_or_null("Crosshair") as Control
	assert_not_null(crosshair, "Crosshair must be authored in the player HUD")
	if not crosshair:
		return

	assert_true(crosshair.visible, "Crosshair should be visible")
	assert_eq(crosshair.anchor_left, 0.5)
	assert_eq(crosshair.anchor_top, 0.5)
	assert_eq(crosshair.anchor_right, 0.5)
	assert_eq(crosshair.anchor_bottom, 0.5)


func test_health_ammo_and_damage_feedback_are_present() -> void:
	var health_hud: Control = _hud_layer.get_node_or_null("HealthHUD") as Control
	var ammo_hud: Control = _hud_layer.get_node_or_null("AmmoHUD") as Control
	var damage_indicator: Node = _hud_layer.get_node_or_null("DamageIndicatorManager")
	var blood_overlay: Node = _hud_layer.get_node_or_null("BloodOverlay")

	assert_not_null(health_hud, "Health HUD must be authored")
	assert_not_null(ammo_hud, "Ammo HUD must be authored")
	assert_not_null(damage_indicator, "Damage indicator must be authored")
	assert_not_null(blood_overlay, "Blood overlay must be authored")
	assert_true(damage_indicator.has_method("show_damage_from"))
	assert_true(blood_overlay.has_method("show_damage"))


func test_player_health_and_ammo_signals_are_exposed() -> void:
	var health_component: Node = _player.get_node_or_null("HealthComponent")
	var weapon_manager: Node = _player.get_node_or_null("WeaponManager")

	assert_not_null(health_component, "Player must expose HealthComponent")
	assert_true(health_component.has_signal("health_changed"))
	assert_not_null(weapon_manager, "Player must expose WeaponManager")
	assert_true(weapon_manager.has_signal("ammo_changed"))


func test_minimap_tracks_world_entities() -> void:
	var minimap: Node = _hud_layer.get_node_or_null("Minimap")

	assert_not_null(minimap, "Minimap must be authored in the player HUD")
	assert_true(minimap.is_inside_tree(), "Minimap should be in scene tree")
	assert_true(minimap.has_method("track_entity"), "Minimap must track world entities")
	assert_true(minimap.has_method("untrack_entity"), "Minimap must remove tracked entities")


func test_hud_layout_uses_authored_containers_and_readable_sizes() -> void:
	var health_container: Container = (
		_hud_layer.get_node_or_null("HealthHUD/VBoxContainer") as Container
	)
	var ammo_container: Container = (
		_hud_layer.get_node_or_null("AmmoHUD/VBoxContainer") as Container
	)
	var health_count: Label = (
		_hud_layer.get_node_or_null("HealthHUD/VBoxContainer/HealthCount") as Label
	)
	var ammo_count: Label = _hud_layer.get_node_or_null("AmmoHUD/VBoxContainer/AmmoCount") as Label

	assert_not_null(health_container, "Health HUD must use a container layout")
	assert_not_null(ammo_container, "Ammo HUD must use a container layout")
	assert_not_null(health_count, "Health HUD must expose a readable count label")
	assert_not_null(ammo_count, "Ammo HUD must expose a readable count label")
	assert_ge(health_count.get_theme_font_size("font_size"), 12)
	assert_ge(ammo_count.get_theme_font_size("font_size"), 12)


func test_effect_and_ui_services_expose_player_feedback_apis() -> void:
	var game_manager: Node = get_node_or_null("/root/GameManager")
	assert_not_null(game_manager, "GameManager must be available for HUD integration")
	if not game_manager:
		return

	var effects: Node = game_manager.get_core_system("effects")
	var audio: Node = game_manager.get_core_system("audio")
	var ui_service: Node = game_manager.get_core_system("ui")

	assert_not_null(effects, "Effects service must be registered")
	assert_true(effects.has_method("screen_flash"), "Effects service must expose screen flash")
	assert_not_null(audio, "Audio service must be registered")
	assert_true(
		audio.has_method("play_hit_marker"), "Audio service must expose hit marker feedback"
	)
	assert_not_null(ui_service, "UI service must be registered")
	assert_true(ui_service.has_method("open_screen"), "UI service must open player-facing screens")
