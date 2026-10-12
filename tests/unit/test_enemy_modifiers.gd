extends ModusGutTestBase


class TestStatusEffects:
	extends StatusEffectManager

	func _spawn_effect_visual(_effect: StatusEffect) -> void:
		pass


class DamageTarget:
	extends Node3D

	var received: float = 0.0

	func take_damage(info: DamageInfo) -> void:
		received = info.base_amount


class HookSource:
	extends Node3D

	var hit_count: int = 0
	var last_target: Node
	var last_damage: float = 0.0

	func get_outgoing_damage_modifier() -> float:
		return 1.0

	func apply_on_hit_effects(target: Node3D, damage_dealt: float) -> void:
		hit_count += 1
		last_target = target
		last_damage = damage_dealt


class ModifierTarget:
	extends Node3D

	var ghostly_alpha: float = 1.0
	var multipliers: Dictionary = {}

	func apply_stat_multiplier(stat_name: String, multiplier: float) -> void:
		multipliers[stat_name] = multiplier

	func apply_ghostly_visual(alpha: float) -> void:
		ghostly_alpha = alpha


func before_each() -> void:
	await modus_setup()


func after_each() -> void:
	modus_teardown()


func test_unsupported_factories_now_create_runtime_modifiers() -> void:
	var ghostly := EnemyModifier.create_ghostly()
	var electrified := EnemyModifier.create_electrified()
	var vampiric := EnemyModifier.create_vampiric()

	assert_not_null(ghostly)
	assert_not_null(electrified)
	assert_not_null(vampiric)
	assert_almost_eq(ghostly.ghostly_alpha, 0.35, 0.001)
	assert_gt(electrified.chain_damage, 0.0)
	assert_gt(electrified.chain_radius, 0.0)
	assert_almost_eq(vampiric.lifesteal_fraction, 0.25, 0.001)


func test_ghostly_modifier_applies_transparency_contract() -> void:
	var target := ModifierTarget.new()
	add_child_autofree(target)

	var ghostly := EnemyModifier.create_ghostly()
	ghostly.apply_to(target)

	assert_almost_eq(target.ghostly_alpha, 0.35, 0.001)
	assert_eq(target.multipliers.get("speed", 0.0), 1.1)


func test_ghostly_modifier_changes_mesh_material() -> void:
	var enemy := Enemy.new()
	autofree(enemy)
	var visuals := Node3D.new()
	visuals.name = "Visuals"
	enemy.add_child(visuals)
	var mesh := MeshInstance3D.new()
	var material := StandardMaterial3D.new()
	material.albedo_color = Color.WHITE
	mesh.material_override = material
	visuals.add_child(mesh)

	enemy.apply_ghostly_visual(0.35)

	var applied_material := mesh.material_override as StandardMaterial3D
	assert_not_null(applied_material)
	if not applied_material:
		return
	assert_eq(applied_material.transparency, BaseMaterial3D.TRANSPARENCY_ALPHA)
	assert_almost_eq(applied_material.albedo_color.a, 0.35, 0.001)


func test_electrified_modifier_chains_damage_to_nearby_player() -> void:
	var source := Node3D.new()
	add_child_autofree(source)
	var primary_target := DamageTarget.new()
	primary_target.add_to_group("player")
	add_child_autofree(primary_target)
	var nearby_target := DamageTarget.new()
	nearby_target.position = Vector3(2.0, 0.0, 0.0)
	nearby_target.add_to_group("player")
	add_child_autofree(nearby_target)

	var electrified := EnemyModifier.create_electrified()
	electrified.apply_on_hit(source, primary_target, 20.0)

	assert_almost_eq(nearby_target.received, 8.0, 0.001)


func test_elemental_modifier_applies_status_on_hit() -> void:
	var source := Node3D.new()
	add_child_autofree(source)
	var target := Node3D.new()
	add_child_autofree(target)
	var status_manager := TestStatusEffects.new()
	status_manager.name = "StatusEffectManager"
	target.add_child(status_manager)
	await get_tree().process_frame

	var burning := EnemyModifier.create_burning()
	burning.apply_on_hit(source, target, 20.0)
	assert_true(status_manager.has_effect(StatusEffect.EffectType.BURN))

	var freezing := EnemyModifier.create_freezing()
	freezing.apply_on_hit(source, target, 20.0)
	assert_true(status_manager.has_effect(StatusEffect.EffectType.FREEZE))
	assert_almost_eq(freezing.on_hit_effect.movement_speed_modifier, 0.5, 0.001)


func test_vampiric_modifier_restores_source_health() -> void:
	var source := Node3D.new()
	add_child_autofree(source)
	var health := HealthComponent.new()
	health.name = "HealthComponent"
	source.add_child(health)
	await get_tree().process_frame
	health.current_health = 50.0

	var target := Node3D.new()
	add_child_autofree(target)
	var vampiric := EnemyModifier.create_vampiric()
	vampiric.apply_on_hit(source, target, 20.0)

	assert_almost_eq(health.current_health, 55.0, 0.001)


func test_combat_service_dispatches_enemy_on_hit_hooks() -> void:
	var combat := CombatSvc.new()
	add_child_autofree(combat)
	var source := HookSource.new()
	add_child_autofree(source)
	var target := DamageTarget.new()
	add_child_autofree(target)

	combat.apply_damage(target, 20.0, source, DamageInfo.DamageType.MELEE)

	assert_almost_eq(target.received, 20.0, 0.001)
	assert_eq(source.hit_count, 1)
	assert_eq(source.last_target, target)
	assert_almost_eq(source.last_damage, 20.0, 0.001)
