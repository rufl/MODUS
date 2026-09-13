@tool
class_name HazardVolumeActor
extends "res://shared/editor_core/actors/actor_base.gd"

enum HazardType { LAVA, ACID, ELECTRIC, POISON }

@export var hazard_type: HazardType = HazardType.LAVA
@export var damage_per_second: float = 20.0
@export var damage_interval: float = 0.5
@export var volume_size: Vector3 = Vector3(2.0, 1.0, 2.0)
@export var active_duration: float = 0.0
@export var inactive_duration: float = 0.0
@export var recovery_anchor: NodePath = NodePath("")

var hazard_mesh: Node3D = null
var damage_area: Area3D = null
var particles: GPUParticles3D = null

var _damage_timer: float = 0.0
var _entities_in_zone: Array[Node] = []
var _cycle_time: float = 0.0
var _energized: bool = false


func _init() -> void:
	actor_category = "hazard"
	actor_name = "Hazard Volume"
	actor_description = "Damage zone (lava, acid, etc.)"


func _on_actor_ready() -> void:
	_create_visual()
	_create_damage_area()
	_create_particles()
	_damage_timer = maxf(damage_interval, 0.01)
	_update_hazard_visual(false)


func _create_visual() -> void:
	# Hazard volume mesh
	hazard_mesh = CSGBox3D.new()
	hazard_mesh.name = "HazardMesh"
	hazard_mesh.size = volume_size
	hazard_mesh.position.y = volume_size.y * 0.5

	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = _get_hazard_color()
	mat.emission_enabled = true
	mat.emission = _get_hazard_emission()
	mat.emission_energy_multiplier = 2.0
	hazard_mesh.material = mat
	add_child(hazard_mesh)


func _get_hazard_color() -> Color:
	match hazard_type:
		HazardType.LAVA:
			return Color(1.0, 0.3, 0.1, 0.6)  # Red-orange
		HazardType.ACID:
			return Color(0.3, 1.0, 0.2, 0.6)  # Green
		HazardType.ELECTRIC:
			return Color(0.3, 0.5, 1.0, 0.6)  # Blue
		HazardType.POISON:
			return Color(0.5, 0.2, 0.8, 0.6)  # Purple
		_:
			return Color(1.0, 0.0, 0.0, 0.6)


func _get_hazard_emission() -> Color:
	match hazard_type:
		HazardType.LAVA:
			return Color(1.0, 0.5, 0.2)
		HazardType.ACID:
			return Color(0.5, 1.0, 0.3)
		HazardType.ELECTRIC:
			return Color(0.5, 0.7, 1.0)
		HazardType.POISON:
			return Color(0.7, 0.4, 1.0)
		_:
			return Color(1.0, 0.0, 0.0)


func _create_damage_area() -> void:
	damage_area = Area3D.new()
	damage_area.name = "DamageArea"
	damage_area.monitoring = not is_authoring()
	damage_area.collision_layer = 0
	damage_area.collision_mask = CollisionLayers.LAYER_PLAYERS | CollisionLayers.LAYER_ENEMIES
	add_child(damage_area)

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = volume_size
	shape.shape = box
	shape.position.y = volume_size.y * 0.5
	shape.set_meta("editor_runtime_only", true)
	damage_area.add_child(shape)

	damage_area.body_entered.connect(_on_body_entered_hazard)
	damage_area.body_exited.connect(_on_body_exited_hazard)


func _create_particles() -> void:
	particles = GPUParticles3D.new()
	particles.name = "HazardParticles"
	particles.amount = 64
	particles.lifetime = 2.0
	particles.emitting = false
	particles.position.y = volume_size.y * 0.5
	add_child(particles)

	var process_mat := ParticleProcessMaterial.new()
	process_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process_mat.emission_box_extents = volume_size * 0.5
	process_mat.direction = Vector3(0, 1, 0)
	process_mat.initial_velocity_min = 0.5
	process_mat.initial_velocity_max = 1.5
	process_mat.gravity = Vector3(0, -2.0, 0)
	process_mat.color = _get_hazard_color()
	particles.process_material = process_mat


func _physics_process(delta: float) -> void:
	if is_authoring() or not is_enabled or not is_active:
		return
	var interval := maxf(damage_interval, 0.01)
	var remaining := delta
	# Split at both pulse and damage boundaries, so a frame crossing the safe
	# window cannot damage a player during the inactive part of the cycle.
	while remaining > 0.0:
		var pulsed := active_duration > 0.0 and inactive_duration > 0.0
		var hot := not pulsed or _cycle_time < active_duration
		var boundary := remaining
		if pulsed:
			boundary = (
				(active_duration if hot else active_duration + inactive_duration) - _cycle_time
			)
		var step := minf(remaining, boundary)
		if hot:
			step = minf(step, _damage_timer)
			_damage_timer -= step
		_cycle_time += step
		remaining -= step
		if hot and _damage_timer <= 0.000001:
			_deal_damage()
			_damage_timer = interval
		if pulsed and _cycle_time >= active_duration + inactive_duration:
			_cycle_time = 0.0
			_damage_timer = interval
		elif not pulsed:
			_cycle_time = 0.0
	_update_hazard_visual(_is_hot())


func _is_hot() -> bool:
	return (
		is_enabled
		and is_active
		and (active_duration <= 0.0 or inactive_duration <= 0.0 or _cycle_time < active_duration)
	)


func _update_hazard_visual(hot: bool) -> void:
	_energized = hot
	if hazard_mesh:
		var material := hazard_mesh.get("material") as StandardMaterial3D
		if material:
			var color := _get_hazard_color()
			color.a = 0.6 if hot else 0.12
			material.albedo_color = color
			material.emission_energy_multiplier = 2.0 if hot else 0.05
	if particles:
		particles.emitting = hot and not is_authoring()


func _on_activated(_data: Dictionary) -> void:
	_cycle_time = 0.0
	_damage_timer = maxf(damage_interval, 0.01)
	_update_hazard_visual(_is_hot())


func _on_deactivated() -> void:
	_update_hazard_visual(false)


func _on_body_entered_hazard(body: Node3D) -> void:
	if is_authoring():
		return
	if body.is_in_group("player") or body.is_in_group("enemies") or body.is_in_group("enemy"):
		if body not in _entities_in_zone:
			_entities_in_zone.append(body)


func _on_body_exited_hazard(body: Node3D) -> void:
	_entities_in_zone.erase(body)


func _deal_damage() -> void:
	if is_authoring() or not is_enabled or not is_active:
		return
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	var combat := CombatSvc.get_instance()
	var amount := maxf(damage_per_second, 0.0) * maxf(damage_interval, 0.01)
	var damage_type := DamageInfo.DamageType.FIRE
	if hazard_type == HazardType.POISON or hazard_type == HazardType.ACID:
		damage_type = DamageInfo.DamageType.POISON
	elif hazard_type == HazardType.ELECTRIC:
		damage_type = DamageInfo.DamageType.ENERGY
	for entity: Node in _entities_in_zone.duplicate():
		if not is_instance_valid(entity):
			_entities_in_zone.erase(entity)
			continue
		if combat:
			combat.apply_damage(entity, amount, self, damage_type)
		elif entity.has_method("take_damage"):
			var info := DamageInfo.create(amount, damage_type, self)
			info.final_damage = amount
			entity.take_damage(info)
		if (
			not recovery_anchor.is_empty()
			and entity is CharacterBody3D
			and entity.is_in_group("player")
		):
			var anchor := get_node_or_null(recovery_anchor) as Node3D
			if anchor:
				entity.global_transform = anchor.global_transform
				entity.velocity = Vector3.ZERO
				entity.reset_physics_interpolation()
				_entities_in_zone.erase(entity)


func capture_runtime_state() -> Dictionary:
	var state := super.capture_runtime_state()
	state["hazard"] = {"cycle_time": _cycle_time, "damage_timer": _damage_timer}
	return state


func validate_runtime_state(state: Dictionary) -> bool:
	if not super.validate_runtime_state(state) or not state.get("hazard") is Dictionary:
		return false
	var phase: Dictionary = state.hazard
	for key: String in ["cycle_time", "damage_timer"]:
		var value: Variant = phase.get(key)
		if (
			not (value is int or value is float)
			or not is_finite(float(value))
			or float(value) < 0.0
		):
			return false
	if float(phase.damage_timer) > maxf(damage_interval, 0.01):
		return false
	if active_duration > 0.0 and inactive_duration > 0.0:
		return float(phase.cycle_time) < active_duration + inactive_duration
	return float(phase.cycle_time) == 0.0


func restore_runtime_state(state: Dictionary) -> bool:
	if not validate_runtime_state(state) or not super.restore_runtime_state(state):
		return false
	_cycle_time = float(state.hazard.cycle_time)
	_damage_timer = float(state.hazard.damage_timer)
	_entities_in_zone.clear()
	if damage_area and not is_authoring():
		for body: Node3D in damage_area.get_overlapping_bodies():
			_on_body_entered_hazard(body)
	_update_hazard_visual(_is_hot())
	return true


func get_inspector_properties() -> Array[Dictionary]:
	var props: Array[Dictionary] = super.get_inspector_properties()
	props.append_array(
		[
			{
				"name": "hazard_type",
				"type": TYPE_INT,
				"label": "Hazard Type",
				"hint": PROPERTY_HINT_ENUM,
				"hint_string": "Lava,Acid,Electric,Poison"
			},
			{"name": "damage_per_second", "type": TYPE_FLOAT, "label": "Damage/Second"},
			{"name": "volume_size", "type": TYPE_VECTOR3, "label": "Volume Size"}
		]
	)
	return props
