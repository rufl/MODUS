@tool
class_name PickupSpawnerActor
extends "res://shared/editor_core/actors/actor_base.gd"

enum PickupCategory { HEALTH, ARMOR, AMMO, WEAPON, POWERUP }

@export var pickup_category: PickupCategory = PickupCategory.HEALTH
@export var weapon_id: String = ""  # For weapon pickups
@export var item_id: String = "health_potion"  # For other pickups
@export_range(-1, 5) var rarity_tier: int = -1  # Optional ItemRarity tier
@export var respawn_time: float = 30.0
@export var auto_spawn: bool = true

var preview_mesh: Node3D = null
var spawn_area: Area3D = null
var hologram_material: StandardMaterial3D = null

var _current_pickup: PickupBase = null
var _respawn_timer: float = 0.0
var _phase: String = "inactive"
var _runtime_started: bool = false
var _restoring: bool = false


func _init() -> void:
	actor_category = "activator"
	actor_name = "Pickup Spawner"
	actor_description = "Spawns items and weapons"


func _on_actor_ready() -> void:
	if is_authoring():
		_create_visual()


func start_runtime() -> void:
	if _runtime_started or is_authoring():
		return
	_runtime_started = true
	super.start_runtime()
	if auto_spawn and _phase == "inactive":
		trigger()


func _has_authority() -> bool:
	return not multiplayer.has_multiplayer_peer() or multiplayer.is_server()


func _do_activate(_data: Dictionary) -> void:
	if _runtime_started and not is_authoring() and _has_authority() and _phase == "inactive":
		_spawn_pickup()


func _create_visual() -> void:
	# Holographic preview
	preview_mesh = CSGBox3D.new()
	preview_mesh.name = "PreviewMesh"
	preview_mesh.size = Vector3(0.5, 0.5, 0.5)
	preview_mesh.position.y = 1.0

	hologram_material = StandardMaterial3D.new()
	hologram_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hologram_material.albedo_color = _get_category_color()
	hologram_material.emission_enabled = true
	hologram_material.emission = _get_category_color()
	hologram_material.emission_energy_multiplier = 1.5
	preview_mesh.material = hologram_material
	add_child(preview_mesh)

	# Spawn platform
	var platform := CSGCylinder3D.new()
	platform.name = "SpawnPlatform"
	platform.radius = 0.6
	platform.height = 0.1
	platform.position.y = 0.05

	var platform_mat := StandardMaterial3D.new()
	platform_mat.albedo_color = Color(0.3, 0.3, 0.3)
	platform_mat.metallic = 0.8
	platform.material = platform_mat
	add_child(platform)


func _get_category_color() -> Color:
	match pickup_category:
		PickupCategory.HEALTH:
			return Color(0.2, 1.0, 0.3, 0.7)  # Green
		PickupCategory.ARMOR:
			return Color(0.3, 0.5, 1.0, 0.7)  # Blue
		PickupCategory.AMMO:
			return Color(1.0, 0.8, 0.2, 0.7)  # Yellow
		PickupCategory.WEAPON:
			return Color(1.0, 0.4, 0.2, 0.7)  # Orange
		PickupCategory.POWERUP:
			return Color(0.8, 0.2, 1.0, 0.7)  # Purple
		_:
			return Color(0.5, 0.5, 0.5, 0.7)


func _process(delta: float) -> void:
	super._process(delta)

	if not _runtime_started or is_authoring() or not _has_authority() or _restoring:
		return
	if _phase == "waiting":
		_respawn_timer = maxf(0.0, _respawn_timer - delta)
		if _respawn_timer <= 0:
			_spawn_pickup()


func _spawn_pickup(saved: Dictionary = {}, prepared: PickupBase = null) -> bool:
	if is_authoring() or (not _has_authority() and not is_applying_authoritative_state()) or is_instance_valid(_current_pickup):
		return false
	var scene := _get_pickup_scene()
	if not scene:
		push_error("[PickupSpawnerActor] No pickup scene for authored reward")
		return false
	_current_pickup = prepared if prepared else scene.instantiate() as PickupBase
	if not _current_pickup:
		return false
	if _current_pickup is HealthPickup and LootSvc.HEALTH_TIER_MAP.has(item_id):
		_current_pickup.tier = LootSvc.HEALTH_TIER_MAP[item_id]
	if rarity_tier >= 0:
		_current_pickup.rarity_tier = clampi(rarity_tier, 0, 5)
	_current_pickup.set_meta("editor_runtime_only", true)
	var system := _find_channel_system()
	_current_pickup.set_meta(
		"authored_actor_owner", system.get_binding_id(self) if system else actor_id
	)
	if system:
		_current_pickup.authored_document = system.document_root
	_current_pickup.transform = transform.translated_local(Vector3(0, 1, 0))
	get_parent().add_child(_current_pickup, true)
	if saved.is_empty():
		_current_pickup.global_transform = Transform3D(
			global_basis, global_position + Vector3(0, 1, 0)
		)
	else:
		_current_pickup.restore_motion_state(saved)
	_current_pickup.picked_up.connect(_on_pickup_collected)
	_phase = "available"
	_respawn_timer = 0.0
	return true


func _on_pickup_collected(collector: CharacterBody3D) -> void:
	if _restoring or not is_instance_valid(_current_pickup):
		return
	_current_pickup = null
	_phase = "waiting" if respawn_time > 0 and not one_shot else "collected"
	_respawn_timer = respawn_time if _phase == "waiting" else 0.0
	super._do_activate({"source": collector})


func capture_runtime_state() -> Dictionary:
	var state := super.capture_runtime_state()
	var pickup_state: Dictionary = {}
	if is_instance_valid(_current_pickup):
		pickup_state = _current_pickup.capture_motion_state()
	state.merge({"pickup_phase": _phase, "respawn_timer": _respawn_timer, "pickup": pickup_state})
	return state


func validate_runtime_state(state: Dictionary) -> bool:
	if not super.validate_runtime_state(state):
		return false
	if (
		not state.get("pickup_phase") is String
		or state.pickup_phase not in ["inactive", "available", "waiting", "collected"]
	):
		return false
	if not PickupBase._finite_number(state.get("respawn_timer")) or state.respawn_timer < 0:
		return false
	if not state.get("pickup") is Dictionary:
		return false
	if state.pickup_phase == "available":
		if not PickupBase.validate_motion_state(state.pickup):
			return false
		if _get_pickup_scene() == null:
			return false
	elif not state.pickup.is_empty():
		return false
	if state.pickup_phase == "waiting":
		if (
			respawn_time <= 0
			or one_shot
			or state.respawn_timer > respawn_time
			or state.activation_count < 1
		):
			return false
	elif state.respawn_timer != 0:
		return false
	if state.pickup_phase == "inactive" and (state.activation_count != 0 or state.is_active):
		return false
	if (
		state.pickup_phase == "available"
		and state.activation_count > 0
		and (one_shot or respawn_time <= 0)
	):
		return false
	if state.pickup_phase == "collected" and respawn_time > 0 and not one_shot:
		return false
	if state.pickup_phase == "collected" and state.activation_count < 1:
		return false
	if one_shot and state.activation_count > 1:
		return false
	return true


func restore_runtime_state(state: Dictionary) -> bool:
	if not validate_runtime_state(state) or is_authoring() or (
		not _has_authority() and not is_applying_authoritative_state()
	):
		return false
	var prepared: PickupBase = null
	if state.pickup_phase == "available":
		prepared = _get_pickup_scene().instantiate() as PickupBase
		if not prepared:
			return false
	_restoring = true
	if is_instance_valid(_current_pickup):
		_current_pickup.free()
	_current_pickup = null
	super.restore_runtime_state(state)
	_phase = state.pickup_phase
	_respawn_timer = float(state.respawn_timer)
	if prepared:
		_spawn_pickup(state.pickup, prepared)
	_restoring = false
	return true


func apply_runtime_update(state: Dictionary) -> bool:
	if not is_applying_authoritative_state() or not validate_runtime_state(state):
		return false
	if state.pickup_phase != _phase or not is_instance_valid(_current_pickup):
		return restore_runtime_state(state)
	super.restore_runtime_state(state)
	_respawn_timer = float(state.respawn_timer)
	return _current_pickup.restore_motion_state(state.pickup)


func _get_pickup_scene() -> PackedScene:
	var scene_path: String = ""

	match pickup_category:
		PickupCategory.HEALTH:
			scene_path = "res://game/scenes/items/pickups/health_pickup.tscn"
		PickupCategory.ARMOR:
			scene_path = "res://game/scenes/items/pickups/armor_pickup.tscn"
		PickupCategory.AMMO:
			scene_path = "res://game/scenes/items/pickups/ammo_pickup.tscn"
		PickupCategory.WEAPON:
			# Map weapon_id to scene
			match weapon_id:
				"shotgun":
					scene_path = "res://game/scenes/items/pickups/shotgun_pickup.tscn"
				"rocket_launcher":
					scene_path = "res://game/scenes/items/pickups/rocket_launcher_pickup.tscn"
				_:
					push_warning("[PickupSpawnerActor] Unknown weapon_id: %s" % weapon_id)
		PickupCategory.POWERUP:
			match item_id:
				"speed", "speed_powerup":
					scene_path = "res://game/scenes/items/pickups/speed_powerup.tscn"
				"damage", "damage_powerup":
					scene_path = "res://game/scenes/items/pickups/damage_powerup.tscn"
				"dodge", "dodge_powerup":
					scene_path = "res://game/scenes/items/pickups/dodge_powerup.tscn"
				"double_jump", "double_jump_powerup":
					scene_path = "res://game/scenes/items/pickups/double_jump_powerup.tscn"
				_:
					push_warning("[PickupSpawnerActor] Unknown powerup item_id: %s" % item_id)

	if scene_path.is_empty() or not ResourceLoader.exists(scene_path):
		return null

	return load(scene_path)


func get_inspector_properties() -> Array[Dictionary]:
	var props: Array[Dictionary] = super.get_inspector_properties()
	props.append_array(
		[
			{
				"name": "pickup_category",
				"type": TYPE_INT,
				"label": "Pickup Type",
				"hint": PROPERTY_HINT_ENUM,
				"hint_string": "Health,Armor,Ammo,Weapon,Powerup"
			},
			{
				"name": "weapon_id",
				"type": TYPE_STRING,
				"label": "Weapon ID",
				"description": "For weapon pickups (shotgun, rocket_launcher, etc.)"
			},
			{
				"name": "rarity_tier",
				"type": TYPE_INT,
				"label": "Rarity Tier",
				"hint": PROPERTY_HINT_RANGE,
				"hint_string": "-1,5"
			},
			{
				"name": "respawn_time",
				"type": TYPE_FLOAT,
				"label": "Respawn Time",
				"description": "Seconds before item respawns"
			},
			{
				"name": "auto_spawn",
				"type": TYPE_BOOL,
				"label": "Auto Spawn",
				"description": "Spawn item on level start"
			}
		]
	)
	return props
