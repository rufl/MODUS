extends ModusGutTestBase

const PlatformScript := preload("res://shared/editor_core/actors/platform_actor.gd")
const HazardScript := preload("res://shared/editor_core/actors/hazard_volume_actor.gd")
const SecretScript := preload("res://shared/editor_core/actors/secret_wall_actor.gd")
const TriggerScript := preload("res://shared/editor_core/actors/trigger_zone_actor.gd")


class Passenger:
	extends CharacterBody3D
	var damage_received: float = 0.0

	func _physics_process(delta: float) -> void:
		velocity.y -= 9.8 * delta
		move_and_slide()

	func take_damage(info: DamageInfo) -> void:
		damage_received += info.base_amount


class PrerequisiteZone:
	extends TriggerScript
	var prerequisite_complete: bool = false

	func _prerequisites_met() -> bool:
		return prerequisite_complete


func before_each() -> void:
	await modus_setup()


func after_each() -> void:
	modus_teardown()


func test_platform_carries_character_through_both_endpoints_without_velocity_runaway() -> void:
	var lift := PlatformScript.new()
	lift.waypoints = PackedVector3Array([Vector3.ZERO, Vector3(0, 2, 0)])
	lift.move_speed = 2.0
	lift.wait_at_points = 0.25
	add_child_autofree(lift)
	var passenger := Passenger.new()
	passenger.collision_layer = CollisionLayers.LAYER_PLAYERS
	passenger.collision_mask = CollisionLayers.LAYER_WORLD
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.25
	shape.shape = sphere
	passenger.add_child(shape)
	passenger.position = Vector3(0, 0.42, 0)
	add_child_autofree(passenger)
	for frame: int in range(12):
		await get_tree().physics_frame
	lift.start_runtime()
	lift.trigger(passenger)
	var highest := passenger.position.y
	var lowest_after_top := INF
	var maximum_speed := 0.0
	var largest_floor_gap := 0.0
	for frame: int in range(210):
		await get_tree().physics_frame
		highest = maxf(highest, passenger.position.y)
		maximum_speed = maxf(maximum_speed, passenger.velocity.length())
		largest_floor_gap = maxf(
			largest_floor_gap, absf(passenger.position.y - lift.platform_body.position.y - 0.4)
		)
		if highest > 2.2:
			lowest_after_top = minf(lowest_after_top, passenger.position.y)
	assert_gt(highest, 2.2, "Passenger reaches the upper landing")
	assert_lt(lowest_after_top, 0.6, "Passenger returns through the lower endpoint")
	assert_lt(
		maximum_speed, 5.0, "Platform floor motion must not accumulate into passenger velocity"
	)
	assert_lt(largest_floor_gap, 0.15, "Passenger stays on the lift during travel and reversal")


func test_descending_platform_waits_for_character_to_clear_instead_of_crushing_floor() -> void:
	var floor_body := StaticBody3D.new()
	var floor_collision := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(10, 0.3, 10)
	floor_collision.shape = floor_box
	floor_body.add_child(floor_collision)
	floor_body.position.y = -0.15
	add_child_autofree(floor_body)
	var lift := PlatformScript.new()
	lift.platform_size = Vector3(4, 0.3, 4)
	lift.waypoints = PackedVector3Array([Vector3(0, 3.85, 0), Vector3(0, -0.15, 0)])
	lift.move_speed = 1.5
	lift.wait_at_points = 0.25
	add_child_autofree(lift)
	var passenger := Passenger.new()
	passenger.collision_layer = CollisionLayers.LAYER_PLAYERS
	passenger.collision_mask = CollisionLayers.LAYER_WORLD
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 2.0
	shape.shape = capsule
	shape.position.y = 1.0
	passenger.add_child(shape)
	passenger.position.y = 0.01
	add_child_autofree(passenger)
	await wait_physics_frames(12)
	lift.start_runtime()
	lift.trigger()
	var lowest_player := passenger.position.y
	for frame: int in range(240):
		await get_tree().physics_frame
		lowest_player = minf(lowest_player, passenger.position.y)
	assert_gt(lowest_player, -0.01, "A waiting character never penetrates the shaft floor")
	assert_gt(lift.platform_body.position.y, 2.0, "The descending deck stops above the character")
	passenger.position.x = 3.0
	var lowest_deck := lift.platform_body.position.y
	for frame: int in range(180):
		await get_tree().physics_frame
		lowest_deck = minf(lowest_deck, lift.platform_body.position.y)
	assert_lt(lowest_deck, 0.0, "The lift resumes and reaches its lower stop once clear")


func test_wait_trigger_advances_instead_of_retriggering_same_waypoint() -> void:
	var lift := PlatformScript.new()
	lift.carry_passengers = false
	lift.platform_mode = PlatformScript.PlatformMode.WAIT_TRIGGER
	lift.waypoints = PackedVector3Array([Vector3.ZERO, Vector3.UP, Vector3.UP * 2.0])
	lift.wait_at_points = 0.0
	lift.move_speed = 1.0
	add_child_autofree(lift)
	lift.set_physics_process(false)
	lift.start_runtime()
	lift.trigger()
	lift._physics_process(1.0)
	assert_eq(lift.platform_body.position, Vector3.UP)
	lift._physics_process(1.0)
	assert_eq(lift.platform_body.position, Vector3.UP, "Wait-trigger mode parks until requested")
	lift.trigger()
	lift._physics_process(1.0)
	assert_eq(lift.platform_body.position, Vector3.UP * 2.0)
	lift.trigger()
	lift._physics_process(1.0)
	assert_eq(lift.platform_body.position, Vector3.UP, "Endpoint reverses to a valid next waypoint")


func test_single_waypoint_platform_remains_stationary_and_restores_json_state() -> void:
	var lift := PlatformScript.new()
	lift.waypoints = PackedVector3Array([Vector3(2, 3, 4)])
	add_child_autofree(lift)
	lift.set_physics_process(false)
	lift.start_runtime()
	lift.trigger()
	lift._physics_process(10.0)
	assert_eq(lift.platform_body.position, Vector3(2, 3, 4))
	var saved: Dictionary = JSON.parse_string(JSON.stringify(lift.capture_runtime_state()))
	assert_true(lift.restore_runtime_state(saved))
	saved.platform.target = 0.5
	assert_false(
		lift.restore_runtime_state(saved),
		"Fractional waypoint indices are rejected before mutation"
	)
	assert_eq(lift.platform_body.position, Vector3(2, 3, 4))


func test_blocked_occupied_trigger_retries_without_spending_one_shot_and_restores_silently(
) -> void:
	var zone := PrerequisiteZone.new()
	zone.one_shot = true
	add_child_autofree(zone)
	zone.set_physics_process(false)
	zone.start_runtime()
	var player := CharacterBody3D.new()
	player.add_to_group("player")
	add_child_autofree(player)
	watch_signals(zone)
	zone._on_body_entered(player)
	assert_eq(zone.activation_count, 0, "Arriving early does not spend the return trigger")
	zone.prerequisite_complete = true
	zone._physics_process(0.1)
	assert_eq(zone.activation_count, 1)
	assert_eq(get_signal_parameters(zone, "activated")[0].source, player)
	var saved: Dictionary = JSON.parse_string(JSON.stringify(zone.capture_runtime_state()))
	assert_true(zone.restore_runtime_state(saved))
	zone._on_body_entered(player)
	zone._physics_process(0.1)
	assert_signal_emit_count(
		zone, "activated", 1, "Restoring an overlapping one-shot does not duplicate output"
	)


func test_timed_hazard_safe_window_and_remaining_damage_delay_survive_restore() -> void:
	var hazard := HazardScript.new()
	hazard.active_duration = 1.0
	hazard.inactive_duration = 2.0
	hazard.damage_interval = 0.5
	hazard.damage_per_second = 20.0
	add_child_autofree(hazard)
	hazard.set_physics_process(false)
	hazard.start_runtime()
	var player := Passenger.new()
	player.add_to_group("player")
	add_child_autofree(player)
	player.set_physics_process(false)
	hazard._on_body_entered_hazard(player)
	hazard.trigger()
	hazard._physics_process(0.25)
	assert_eq(player.damage_received, 0.0)
	var saved: Dictionary = JSON.parse_string(JSON.stringify(hazard.capture_runtime_state()))
	assert_true(hazard.restore_runtime_state(saved))
	hazard._on_body_entered_hazard(player)
	hazard._physics_process(0.25)
	assert_eq(player.damage_received, 10.0, "Restore retains time until next damage tick")
	hazard._physics_process(0.5)
	assert_eq(player.damage_received, 20.0)
	hazard._physics_process(2.0)
	assert_eq(player.damage_received, 20.0, "Inactive traversal window causes no damage")
	hazard._physics_process(0.5)
	assert_eq(player.damage_received, 30.0)


func test_shootable_secret_reveals_collision_and_does_not_duplicate_reward_output_on_load() -> void:
	var secret := SecretScript.new()
	secret.trigger_type = SecretScript.TriggerType.SHOOTABLE
	secret.health = 20.0
	secret.show_secret_message = false
	add_child_autofree(secret)
	secret.set_process(false)
	secret.start_runtime()
	watch_signals(secret)
	secret.wall_body.take_damage(8.0, "bullet", null)
	var damaged: Dictionary = JSON.parse_string(JSON.stringify(secret.capture_runtime_state()))
	assert_true(secret.restore_runtime_state(damaged))
	secret.wall_body.take_damage(12.0, "bullet", null)
	await get_tree().process_frame
	assert_true(
		secret._wall_collision.disabled, "Combat destruction opens the physical reward passage"
	)
	assert_signal_emit_count(secret, "activated", 1)
	var opened: Dictionary = JSON.parse_string(JSON.stringify(secret.capture_runtime_state()))
	assert_true(secret.restore_runtime_state(opened))
	secret.wall_body.take_damage(100.0, "bullet", null)
	assert_signal_emit_count(
		secret, "activated", 1, "Loading and shooting an opened secret cannot duplicate its reward"
	)
	assert_true(secret.restore_runtime_state(damaged))
	await get_tree().process_frame
	assert_false(
		secret._wall_collision.disabled, "Loading an earlier checkpoint restores the closed passage"
	)


func test_weapon_hitscan_breaks_damageable_static_secret_wall() -> void:
	assert_not_null(CombatSvc.get_instance(), "Hitscan requires the canonical combat service")
	if not CombatSvc.get_instance():
		return
	var secret := SecretScript.new()
	secret.trigger_type = SecretScript.TriggerType.SHOOTABLE
	secret.health = 20.0
	secret.show_secret_message = false
	add_child_autofree(secret)
	secret.start_runtime()
	var player := CharacterBody3D.new()
	player.position = Vector3(0, 0, 3)
	add_child_autofree(player)
	var manager := WeaponManager.new()
	add_child_autofree(manager)
	manager.set_physics_process(false)
	manager.player = player
	var detector := WeaponHitDetector.new()
	manager.add_child(detector)
	detector.setup(player, null)
	manager.hit_detector = detector
	var weapon := WeaponData.new()
	weapon.damage = 20
	weapon.spread_angle = 0.0
	weapon.pellet_count = 1
	await get_tree().physics_frame
	await get_tree().physics_frame
	manager._fire_hitscan_server(weapon, player.global_position, Vector3.FORWARD)
	await get_tree().process_frame
	assert_true(
		secret._wall_collision.disabled,
		"A real hitscan through WeaponManager must break the static secret wall"
	)
	assert_eq(secret.activation_count, 1, "Combat discovery emits the reward channel once")
