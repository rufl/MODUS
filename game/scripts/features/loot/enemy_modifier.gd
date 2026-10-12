class_name EnemyModifier
extends Resource

## Just stats (Extra Strong, Tank)
## Adds damage type / effect (Fire Enchanted)
## Behavior change (Extra Fast)
enum ModifierType { STAT_BOOST, ELEMENTAL, UTILITY }

@export var modifier_name: String = "Elite"
@export var prefix: String = "Elite"  ## Name prefix e.g. "Burning" Zombie
@export var color: Color = Color.RED
@export var type: ModifierType = ModifierType.STAT_BOOST
@export_group("Stat Multipliers")
@export var health_mult: float = 1.0
@export var damage_mult: float = 1.0
@export var speed_mult: float = 1.0
@export var scale_mult: float = 1.0
@export var xp_mult: float = 1.0
@export_group("Effects")
@export var on_hit_effect: StatusEffect = null
@export var visual_effect: PackedScene = null
@export_group("Runtime Effects")
@export_range(0.0, 1.0, 0.05) var ghostly_alpha: float = 1.0
@export var chain_damage: float = 0.0
@export var chain_radius: float = 0.0
@export_range(0.0, 1.0, 0.05) var lifesteal_fraction: float = 0.0


func apply_to(enemy: Node3D) -> void:
	# Apply stats
	if enemy.has_method("apply_stat_multiplier"):
		enemy.apply_stat_multiplier("health", health_mult)
		enemy.apply_stat_multiplier("damage", damage_mult)
		enemy.apply_stat_multiplier("speed", speed_mult)
		enemy.apply_stat_multiplier("scale", scale_mult)

	if ghostly_alpha < 1.0 and enemy.has_method("apply_ghostly_visual"):
		enemy.apply_ghostly_visual(ghostly_alpha)

	# Apply visuals
	if visual_effect:
		var vfx: Node3D = visual_effect.instantiate()
		enemy.add_child(vfx)
	# Apply name prefix (if label exists)
	# (Logic to be handled by enemy wrapper)


## Apply status, chain, and lifesteal effects after a confirmed hit.
func apply_on_hit(source: Node3D, target: Node3D, damage_dealt: float) -> void:
	if not is_instance_valid(source) or not is_instance_valid(target) or source == target:
		return
	var target_health := target.get_node_or_null("HealthComponent") as HealthComponent
	if (
		("is_dead" in target and target.is_dead)
		or (
			target_health
			and (
				target_health.is_dead
				or target_health.current_health <= 0.0
				or target_health.invincible
			)
		)
	):
		return

	if on_hit_effect:
		var status_manager := target.get_node_or_null("StatusEffectManager") as StatusEffectManager
		if status_manager:
			var effect := on_hit_effect.create_copy()
			effect.source_id = source.get_instance_id()
			status_manager.apply_effect(effect)

	if is_finite(chain_damage) and chain_damage > 0.0:
		_apply_chain_damage(source, target)

	if (
		is_finite(damage_dealt)
		and damage_dealt > 0.0
		and is_finite(lifesteal_fraction)
		and lifesteal_fraction > 0.0
	):
		var health := source.get_node_or_null("HealthComponent") as HealthComponent
		if health:
			health.heal(
				damage_dealt * clampf(lifesteal_fraction, 0.0, 1.0), source.get_instance_id()
			)


func _apply_chain_damage(source: Node3D, primary_target: Node3D) -> void:
	var combat_service := CombatSvc.get_instance()
	if not combat_service or not source.get_tree():
		return

	var radius: float = maxf(chain_radius, 0.0)
	if radius <= 0.0:
		return
	var radius_squared: float = radius * radius
	for candidate: Node in source.get_tree().get_nodes_in_group("player"):
		if (
			candidate == primary_target
			or candidate == source
			or not candidate is Node3D
			or not is_instance_valid(candidate)
		):
			continue
		var candidate_3d := candidate as Node3D
		if (
			source.global_position.distance_squared_to(candidate_3d.global_position)
			> radius_squared
		):
			continue
		combat_service.apply_damage(
			candidate_3d,
			chain_damage,
			source,
			DamageInfo.DamageType.ENERGY,
			null,
			false,
			-1,
			candidate_3d.global_position,
			Vector3.UP,
			false
		)


# Factory methods for common affixes


static func create_frenzied() -> EnemyModifier:
	var m: EnemyModifier = EnemyModifier.new()
	m.modifier_name = "Frenzied"
	m.prefix = "Frenzied"
	m.color = Color.ORANGE_RED
	m.type = ModifierType.STAT_BOOST
	m.damage_mult = 1.5
	m.speed_mult = 1.5
	m.health_mult = 0.8  # Glass cannon
	return m


static func create_tank() -> EnemyModifier:
	var m: EnemyModifier = EnemyModifier.new()
	m.modifier_name = "Tank"
	m.prefix = "Armored"
	m.color = Color.SLATE_GRAY
	m.type = ModifierType.STAT_BOOST
	m.health_mult = 2.5
	m.scale_mult = 1.2
	m.speed_mult = 0.7
	return m


static func create_ghostly() -> EnemyModifier:
	var m: EnemyModifier = EnemyModifier.new()
	m.modifier_name = "Ghostly"
	m.prefix = "Ghostly"
	m.color = Color(0.65, 0.8, 1.0)
	m.type = ModifierType.UTILITY
	m.ghostly_alpha = 0.35
	m.speed_mult = 1.1
	return m


## Elemental Affixes - Apply status effects on hit


static func create_burning() -> EnemyModifier:
	var m: EnemyModifier = EnemyModifier.new()
	m.modifier_name = "Burning"
	m.prefix = "Burning"
	m.color = Color.ORANGE
	m.type = ModifierType.ELEMENTAL
	m.damage_mult = 1.2
	# Create burn effect for on_hit
	var burn: StatusEffect = StatusEffect.new()
	burn.effect_name = "Burn"
	burn.effect_type = StatusEffect.EffectType.BURN
	burn.duration = 3.0
	burn.damage_per_tick = 5.0
	burn.tick_interval = 0.5
	m.on_hit_effect = burn
	return m


static func create_freezing() -> EnemyModifier:
	var m: EnemyModifier = EnemyModifier.new()
	m.modifier_name = "Freezing"
	m.prefix = "Freezing"
	m.color = Color.LIGHT_BLUE
	m.type = ModifierType.ELEMENTAL
	# Create freeze/slow effect for on_hit
	var freeze: StatusEffect = StatusEffect.new()
	freeze.effect_name = "Freeze"
	freeze.effect_type = StatusEffect.EffectType.FREEZE
	freeze.duration = 2.0
	freeze.movement_speed_modifier = 0.5
	m.on_hit_effect = freeze
	return m


static func create_poisonous() -> EnemyModifier:
	var m: EnemyModifier = EnemyModifier.new()
	m.modifier_name = "Poisonous"
	m.prefix = "Poisonous"
	m.color = Color.LIME_GREEN
	m.type = ModifierType.ELEMENTAL
	# Create poison DoT effect for on_hit
	var poison: StatusEffect = StatusEffect.new()
	poison.effect_name = "Poison"
	poison.effect_type = StatusEffect.EffectType.POISON
	poison.duration = 5.0
	poison.damage_per_tick = 3.0
	poison.tick_interval = 1.0
	poison.stacks = true
	poison.max_stacks = 5
	m.on_hit_effect = poison
	return m


static func create_electrified() -> EnemyModifier:
	var m: EnemyModifier = EnemyModifier.new()
	m.modifier_name = "Electrified"
	m.prefix = "Electrified"
	m.color = Color.CYAN
	m.type = ModifierType.ELEMENTAL
	m.damage_mult = 1.15
	m.chain_damage = 8.0
	m.chain_radius = 4.0
	var shock: StatusEffect = StatusEffect.new()
	shock.effect_name = "Electrified"
	shock.effect_type = StatusEffect.EffectType.STUN
	shock.duration = 0.35
	shock.tick_interval = 0.0
	shock.can_act = false
	shock.effect_color = Color.CYAN
	m.on_hit_effect = shock
	return m


static func create_vampiric() -> EnemyModifier:
	var m: EnemyModifier = EnemyModifier.new()
	m.modifier_name = "Vampiric"
	m.prefix = "Vampiric"
	m.color = Color.DARK_RED
	m.type = ModifierType.UTILITY
	m.damage_mult = 1.1
	m.lifesteal_fraction = 0.25
	return m


## Get a random supported modifier for elite enemies.
static func get_random_modifier() -> EnemyModifier:
	var options: Array[Callable] = [
		create_frenzied,
		create_tank,
		create_burning,
		create_freezing,
		create_poisonous,
		create_ghostly,
		create_electrified,
		create_vampiric
	]
	return options[randi() % options.size()].call()
