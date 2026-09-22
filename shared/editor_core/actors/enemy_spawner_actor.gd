@tool
class_name EnemySpawnerActor
extends "res://shared/editor_core/actors/actor_base.gd"

enum EnemyBehavior { IDLE, PATROL, GUARD, HUNT }

@export var enemy_id: String = "grunt_basic"
@export_range(1, 4) var tier: int = 1
@export var behavior: EnemyBehavior = EnemyBehavior.IDLE
@export var patrol_radius: float = 5.0
@export var auto_spawn: bool = true
@export_range(1, 32) var spawn_count: int = 1
@export_range(0.0, 60.0) var spawn_interval: float = 0.5

var _mesh_instance: MeshInstance3D
var _direction_mesh: MeshInstance3D
var _label: Label3D
var _runtime_started: bool = false
var _encounter_started: bool = false
var _encounter_cleared: bool = false
var _spawn_timer: float = 0.0
var _records: Array[Dictionary] = []
var _enemies: Dictionary = {}
var _completion_source: Node
var _restoring: bool = false
var _loot: Array[PickupBase] = []


func _init() -> void:
	actor_category = "activator"
	actor_name = "Enemy Spawner"
	actor_description = "Spawns a bounded encounter; emits when every enemy is defeated"


func _on_actor_ready() -> void:
	if is_authoring():
		_setup_editor_visuals()


func start_runtime() -> void:
	if _runtime_started or is_authoring():
		return
	_runtime_started = true
	super.start_runtime()
	if auto_spawn and not _encounter_started:
		trigger()


func _has_authority() -> bool:
	return not multiplayer.has_multiplayer_peer() or multiplayer.is_server()


func _do_activate(data: Dictionary) -> void:
	if not _runtime_started or is_authoring() or not _has_authority() or _encounter_started:
		return
	if spawn_count < 1 or spawn_count > 32 or not is_finite(spawn_interval) or spawn_interval < 0:
		push_error("[EnemySpawnerActor] Invalid bounded encounter configuration")
		return
	if _enemy_data().is_empty():
		push_error("[EnemySpawnerActor] Unknown enemy archetype: " + enemy_id)
		return
	_encounter_started = true
	_completion_source = data.get("source") as Node
	_spawn_timer = 0.0
	_spawn_next()


func _process(delta: float) -> void:
	super._process(delta)
	if not _runtime_started or is_authoring() or not _has_authority() or _restoring:
		return
	for index: int in _enemies:
		var enemy: Enemy = _enemies[index]
		if (
			is_instance_valid(enemy)
			and _records[index].alive
			and (enemy.is_dead or enemy.health_component.is_dead)
		):
			_records[index] = _capture_enemy(enemy, index)
	if not _encounter_started or _encounter_cleared:
		return
	if _records.size() < spawn_count:
		_spawn_timer = maxf(0.0, _spawn_timer - delta)
		if _spawn_timer <= 0.0:
			_spawn_next()
	_finish_if_cleared()


func _enemy_data() -> Dictionary:
	var manager := get_node_or_null("/root/GameManager")
	var service: Node = manager.get_core_system("data") if manager else null
	if not service:
		return {}
	var data: Dictionary = service.get_enemy_data(enemy_id).duplicate(true)
	if not data.is_empty():
		data["id"] = enemy_id
		data["tier"] = tier
		if behavior == EnemyBehavior.PATROL:
			data["patrol"] = {"type": "random", "radius": patrol_radius, "hold_time": 2.0}
	return data


func _spawn_next() -> void:
	var index := _records.size()
	var enemy := _create_enemy(index)
	if not enemy:
		return
	_records.append(_capture_enemy(enemy, index))
	_spawn_timer = spawn_interval


func _create_enemy(index: int, saved: Dictionary = {}, prepared: Enemy = null) -> Enemy:
	var enemy := prepared if prepared else EnemyBuilder.create_enemy(_enemy_data()) as Enemy
	if not enemy:
		return null
	enemy.name = "EncounterEnemy_%d" % index
	enemy.set_meta("editor_runtime_only", true)
	var system := _find_channel_system()
	enemy.set_meta("authored_actor_owner", system.get_binding_id(self) if system else actor_id)
	if system:
		enemy.authored_document = system.document_root
	if not saved.is_empty():
		enemy.set_meta("authored_restored", true)
	enemy.transform = transform
	get_parent().add_child(enemy, true)
	enemy.global_transform = (
		global_transform if saved.is_empty() else PickupBase._decode_transform(saved.transform)
	)
	enemy.configure_authored_spawn(behavior, _completion_source)
	if not saved.is_empty():
		enemy.health_component.max_health = float(saved.max_health)
		enemy.health_component.current_health = float(saved.health)
		enemy.health_component.current_armor = float(saved.armor)
		enemy.health = float(saved.health)
		enemy.max_health = float(saved.max_health)
		enemy.velocity = Vector3(saved.velocity[0], saved.velocity[1], saved.velocity[2])
		enemy.spawn_coordinator.init_last_valid_position()
	_enemies[index] = enemy
	enemy.tree_exiting.connect(_on_enemy_exiting.bind(index, enemy))
	return enemy


func _on_enemy_exiting(index: int, enemy: Enemy) -> void:
	if _restoring or index >= _records.size():
		return
	# Despawning a living enemy is not a kill.
	_records[index] = _capture_enemy(enemy, index)
	_enemies.erase(index)
	if not _records[index].alive:
		_finish_if_cleared()


func _refresh_dead_records() -> void:
	for index: int in _enemies:
		var enemy: Enemy = _enemies[index]
		if is_instance_valid(enemy):
			_records[index] = _capture_enemy(enemy, index)


func _finish_if_cleared() -> void:
	if _encounter_cleared or not _encounter_started or _records.size() != spawn_count:
		return
	for record: Dictionary in _records:
		if record.alive:
			return
	_encounter_cleared = true
	super._do_activate(
		{
			"source":
			_completion_source if is_instance_valid(_completion_source) else _runtime_player()
		}
	)


func _runtime_player() -> Node3D:
	var system := _find_channel_system()
	if system and is_instance_valid(system.document_root):
		return system.document_root.runtime_player
	return null


func _capture_enemy(enemy: Enemy, index: int) -> Dictionary:
	var alive := not enemy.is_dead and not enemy.health_component.is_dead
	return {
		"index": index,
		"enemy_id": enemy_id,
		"tier": tier,
		"alive": alive,
		"transform": PickupBase._encode_transform(enemy.global_transform),
		"velocity": [enemy.velocity.x, enemy.velocity.y, enemy.velocity.z],
		"health": maxf(enemy.health_component.current_health, 0.0) if alive else 0.0,
		"max_health": enemy.health_component.max_health,
		"armor": enemy.health_component.current_armor
	}


func track_authored_loot(pickup: PickupBase) -> void:
	if _loot.has(pickup):
		return
	_loot.append(pickup)
	pickup.tree_exiting.connect(_forget_loot.bind(pickup))


func _forget_loot(pickup: PickupBase) -> void:
	if not _restoring:
		_loot.erase(pickup)


func _loot_table_id() -> String:
	var data := _enemy_data()
	return str(data.get("loot", {}).get("loot_table_id", data.get("loot_table_id", "")))


func capture_runtime_state() -> Dictionary:
	_refresh_dead_records()
	var state := super.capture_runtime_state()
	var drops: Array[Dictionary] = []
	var service := LootSvc.get_instance()
	for pickup: PickupBase in _loot:
		if is_instance_valid(pickup) and not pickup.collected and service:
			drops.append(service.capture_authored_drop(pickup))
	state.merge(
		{
			"encounter_started": _encounter_started,
			"encounter_cleared": _encounter_cleared,
			"spawn_timer": _spawn_timer,
			"enemies": _records.duplicate(true),
			"loot": drops
		}
	)
	return state


func validate_runtime_state(state: Dictionary) -> bool:
	if not super.validate_runtime_state(state):
		return false
	if not state.get("encounter_started") is bool or not state.get("encounter_cleared") is bool:
		return false
	if (
		not PickupBase._finite_number(state.get("spawn_timer"))
		or state.spawn_timer < 0
		or state.spawn_timer > spawn_interval
	):
		return false
	if not state.get("enemies") is Array or state.enemies.size() > spawn_count:
		return false
	var all_dead: bool = state.enemies.size() == spawn_count
	for index: int in state.enemies.size():
		var record: Variant = state.enemies[index]
		if (
			not record is Dictionary
			or not PickupBase._finite_number(record.get("index"))
			or record.index != index
		):
			return false
		if (
			record.get("enemy_id") != enemy_id
			or not PickupBase._finite_number(record.get("tier"))
			or record.tier != tier
		):
			return false
		if (
			not record.get("alive") is bool
			or not PickupBase._number_array(record.get("transform"), 12)
			or not PickupBase._number_array(record.get("velocity"), 3)
		):
			return false
		var determinant := PickupBase._decode_transform(record.transform).basis.determinant()
		if not is_finite(determinant) or absf(determinant) < 0.000001:
			return false
		for field: String in ["health", "max_health", "armor"]:
			if not PickupBase._finite_number(record.get(field)) or record[field] < 0:
				return false
		if (
			record.max_health <= 0
			or record.health > record.max_health
			or record.alive != (record.health > 0)
		):
			return false
		all_dead = all_dead and not record.alive
	if not state.encounter_started and (not state.enemies.is_empty() or state.spawn_timer != 0):
		return false
	if state.encounter_cleared and (not state.encounter_started or not all_dead):
		return false
	if state.activation_count != (1 if state.encounter_cleared else 0):
		return false
	if state.is_active and not state.encounter_cleared:
		return false
	if not state.get("loot") is Array:
		return false
	if not state.loot.is_empty():
		var service := LootSvc.get_instance()
		if not service:
			return false
		var table_id := _loot_table_id()
		var table := service._get_loot_table(table_id)
		var dead_count := 0
		for record: Dictionary in state.enemies:
			if not record.alive:
				dead_count += 1
		if not table or state.loot.size() > dead_count * table.max_items:
			return false
		for drop: Variant in state.loot:
			if not drop is Dictionary or not service.validate_authored_drop(drop, table_id):
				return false
	return state.enemies.is_empty() or not _enemy_data().is_empty()


func restore_runtime_state(state: Dictionary) -> bool:
	if not validate_runtime_state(state) or is_authoring() or (
		not _has_authority() and not is_applying_authoritative_state()
	):
		return false
	# Stage every living enemy before mutating the current encounter.
	var staged: Dictionary = {}
	var data := _enemy_data()
	for record: Dictionary in state.enemies:
		if record.alive:
			var enemy := EnemyBuilder.create_enemy(data) as Enemy
			if not enemy:
				for pending: Node in staged.values():
					pending.free()
				return false
			staged[int(record.index)] = enemy
	var staged_loot: Array[PickupBase] = []
	var service := LootSvc.get_instance()
	for drop: Dictionary in state.loot:
		var pickup := service.prepare_authored_drop(drop, _loot_table_id())
		if not pickup:
			for pending: Node in staged.values():
				pending.free()
			for pending: PickupBase in staged_loot:
				pending.free()
			return false
		staged_loot.append(pickup)
	_restoring = true
	for enemy: Node in _enemies.values():
		if is_instance_valid(enemy):
			enemy.free()
	_enemies.clear()
	for pickup: PickupBase in _loot:
		if is_instance_valid(pickup):
			pickup.free()
	_loot.clear()
	super.restore_runtime_state(state)
	_encounter_started = state.encounter_started
	_encounter_cleared = state.encounter_cleared
	_spawn_timer = float(state.spawn_timer)
	_records.assign(state.enemies.duplicate(true))
	_completion_source = _runtime_player()
	for record: Dictionary in _records:
		if record.alive:
			_create_enemy(int(record.index), record, staged[int(record.index)])
	for index: int in staged_loot.size():
		service.attach_authored_drop(staged_loot[index], state.loot[index], self)
	_restoring = false
	return true


func apply_runtime_update(state: Dictionary) -> bool:
	if not is_applying_authoritative_state() or not validate_runtime_state(state):
		return false
	# Rebuild only when encounter membership changes, not on every motion snapshot.
	if state.enemies.size() != _records.size() or state.loot.size() != _loot.size():
		return restore_runtime_state(state)
	for record: Dictionary in state.enemies:
		var index := int(record.index)
		if record.alive != _records[index].alive:
			return restore_runtime_state(state)
		if record.alive and not is_instance_valid(_enemies.get(index)):
			return restore_runtime_state(state)
	for index: int in _loot.size():
		var pickup := _loot[index]
		if not is_instance_valid(pickup) or pickup.collected:
			return restore_runtime_state(state)
		var previous := LootSvc.get_instance().capture_authored_drop(pickup)
		for key: String in ["table_id", "entry", "item_id", "owner_peer"]:
			if previous[key] != state.loot[index][key]:
				return restore_runtime_state(state)
	super.restore_runtime_state(state)
	_encounter_started = state.encounter_started
	_encounter_cleared = state.encounter_cleared
	_spawn_timer = float(state.spawn_timer)
	_records.assign(state.enemies.duplicate(true))
	for record: Dictionary in _records:
		if not record.alive:
			continue
		var enemy: Enemy = _enemies[int(record.index)]
		var pose := PickupBase._decode_transform(record.transform)
		enemy._target_position = pose.origin
		enemy._target_rotation = pose.basis.get_euler()
		enemy.health_component.max_health = float(record.max_health)
		enemy.health_component._apply_health_state(float(record.health), float(record.armor))
		enemy.health = float(record.health)
		enemy.max_health = float(record.max_health)
	for index: int in _loot.size():
		_loot[index].restore_motion_state(state.loot[index])
	return true


func _setup_editor_visuals() -> void:
	# Clear old
	for child in get_children():
		if child is MeshInstance3D or child is Label3D:
			child.queue_free()

	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.name = "EditorBox"
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(0.6, 1.8, 0.6)

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = _get_tier_color(tier)
	mat.albedo_color.a = 0.4
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	box.material = mat
	_mesh_instance.mesh = box
	_mesh_instance.position.y = 0.9
	add_child(_mesh_instance)

	# Direction indicator (Arrow)
	_direction_mesh = MeshInstance3D.new()
	_direction_mesh.name = "EditorArrow"
	var prism: PrismMesh = PrismMesh.new()
	prism.size = Vector3(0.4, 0.4, 0.1)

	var arrow_mat: StandardMaterial3D = StandardMaterial3D.new()
	arrow_mat.albedo_color = Color.WHITE
	_direction_mesh.mesh = prism
	_direction_mesh.material_override = arrow_mat
	_direction_mesh.rotation_degrees.x = -90
	_direction_mesh.position = Vector3(0, 1.0, -0.5)
	add_child(_direction_mesh)

	_label = Label3D.new()
	_label.name = "EditorLabel"
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.position = Vector3(0, 2.2, 0)
	_label.text = enemy_id + "\n(Tier " + str(tier) + ")"
	_label.font_size = 32
	add_child(_label)


func _get_tier_color(t: int) -> Color:
	match t:
		1:
			return Color(0.9, 0.9, 0.9)  # Basic
		2:
			return Color(0.2, 0.6, 1.0)  # Improved
		3:
			return Color(1.0, 0.6, 0.0)  # Elite
		4:
			return Color(1.0, 0.1, 0.1)  # Boss
		_:
			return Color.WHITE


func get_inspector_properties() -> Array[Dictionary]:
	var props: Array[Dictionary] = super.get_inspector_properties()
	props.append_array(
		[
			{
				"name": "enemy_id",
				"type": TYPE_STRING,
				"label": "Enemy ID",
				"description": "ID of the enemy to spawn from Database"
			},
			{
				"name": "tier",
				"type": TYPE_INT,
				"label": "Tier",
				"hint": PROPERTY_HINT_RANGE,
				"hint_string": "1,4"
			},
			{
				"name": "behavior",
				"type": TYPE_INT,
				"label": "Initial Behavior",
				"hint": PROPERTY_HINT_ENUM,
				"hint_string": "Idle,Patrol,Guard,Hunt"
			},
			{"name": "patrol_radius", "type": TYPE_FLOAT, "label": "Patrol Radius"},
			{"name": "auto_spawn", "type": TYPE_BOOL, "label": "Auto Spawn"},
			{
				"name": "spawn_count",
				"type": TYPE_INT,
				"label": "Wave Total",
				"hint": PROPERTY_HINT_RANGE,
				"hint_string": "1,32"
			},
			{"name": "spawn_interval", "type": TYPE_FLOAT, "label": "Spawn Interval"}
		]
	)
	return props
