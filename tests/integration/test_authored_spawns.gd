extends ModusGutTestBase

const SpawnPointScript := preload("res://shared/editor_core/nodes/spawn_point.gd")
const LevelRootScript := preload("res://shared/editor_core/nodes/level_root.gd")
const EnemySpawnerActorScript := preload("res://shared/editor_core/actors/enemy_spawner_actor.gd")
const PickupSpawnerActorScript := preload("res://shared/editor_core/actors/pickup_spawner_actor.gd")
const KeyPickupActorScript := preload("res://shared/editor_core/actors/key_pickup_actor.gd")
const DoorActorScript := preload("res://shared/editor_core/actors/door_actor.gd")
const SpawnManagerScript := preload("res://game/world/enemy_spawn_manager.gd")
const PlayerScene := preload("res://game/entities/player/player.tscn")

class SpawnWorld:
	extends "res://game/world/world.gd"

	# Exercise production spawning without starting a listening server or menus.
	func _ready() -> void:
		pass

	func _exit_tree() -> void:
		pass


class PickupRecipient:
	extends CharacterBody3D

	var health: int = 25
	var max_health: int = 100
	var armor: int = 0
	var max_armor: int = 100
	var blood_overlay: Control = null
	var inventory: Inventory = null
	var ammo_by_weapon: Dictionary = {}

	func add_ammo_for_weapon(weapon_type: int, amount: int) -> void:
		ammo_by_weapon[weapon_type] = ammo_by_weapon.get(weapon_type, 0) + amount

class GeneratedPlayer:
	extends CharacterBody3D

	var collected_keys: Dictionary = {}

	func collect_key(key_id: String) -> void:
		collected_keys[key_id] = true

	func has_item(item_id: String) -> bool:
		return collected_keys.has(item_id)


func test_generated_key_collection_unlocks_dependent_door() -> void:
	var document: Node3D = LevelRootScript.new()
	document.name = "GeneratedCompletionLevel"
	document.level_name = "Generated Completion"
	document.set_meta("mission_id", "generated_completion")
	document.set_meta("document_runtime_session", true)
	_world.add_child(document)

	var key: KeyPickupActor = KeyPickupActorScript.new()
	key.name = "KeyPickup_0"
	key.actor_id = key.name
	key.key_id = "key_red"
	key.set_meta("mission_objective", {"description": "Collect generated red key", "order": 0})
	document.add_child(key)

	var door: DoorActor = DoorActorScript.new()
	door.name = "LockedDoor_0"
	door.actor_id = door.name
	door.locked = true
	door.required_key = "key_red"
	door.set_meta(
		"mission_objective",
		{
			"description": "Open generated red door",
			"requires": ["KeyPickup_0"],
			"order": 1
		}
	)
	document.add_child(door)

	var player := GeneratedPlayer.new()
	_world.add_child(player)
	await get_tree().process_frame
	assert_true(_mission.start_document_mission(document))
	key.start_runtime()
	door.start_runtime()
	await get_tree().process_frame

	assert_false(door.interact(player), "Door must remain locked before key collection")
	assert_eq(door.activation_count, 0)
	assert_true(key.interact(player), "Generated key must collect through its interaction API")
	_mission._process(0.0)
	assert_eq(_mission.objective_state.get("KeyPickup_0", -1), 1)
	assert_true(door.interact(player), "Generated door must unlock with the collected key")
	_mission._process(0.0)
	assert_eq(door.activation_count, 1)
	assert_false(door.locked)
	assert_eq(_mission.objective_state.get("LockedDoor_0", -1), 1)





var _mission: MissionMgr
var _previous_mission: Dictionary
var _previous_mission_level: Node3D


var _world: Node
var _level: Node3D
var _markers: Node3D
var _manager: EnemySpawnManager
var _stats: Dictionary


func before_each() -> void:
	await modus_setup()
	_mission = MissionMgr.get_instance()
	_previous_mission = _mission.capture_runtime_state()
	_previous_mission_level = _mission.mission_level
	_world = Node.new()
	add_child_autofree(_world)
	_level = LevelRootScript.new()
	_level.position = Vector3(30, 0, 40)
	_level.rotation.y = 0.6
	_world.add_child(_level)
	_markers = Node3D.new()
	_markers.position = Vector3(2, 0, 3)
	_level.add_child(_markers)
	_stats = {}
	_manager = SpawnManagerScript.new()
	_world.add_child(_manager)
	_manager.setup(_world, _stats)


func after_each() -> void:
	if is_instance_valid(_mission):
		_mission.restore_runtime_state(_previous_mission, _previous_mission_level)
	modus_teardown()

func _item_marker(item_id: String, pos: Vector3, delay: float = 0.0) -> LevelSpawnPoint:
	var marker: LevelSpawnPoint = SpawnPointScript.new()
	marker.spawn_type = LevelSpawnPoint.SpawnType.ITEM
	marker.item_id = item_id
	marker.respawn_time = delay
	marker.position = pos
	marker.rotation = Vector3(0.1, 0.3, 0.2)
	_markers.add_child(marker)
	return marker


func _pickups() -> Array[Node3D]:
	var pickups: Array[Node3D] = []
	for child: Node in _world.get_children():
		if child is PickupBase and not child.is_queued_for_deletion():
			pickups.append(child)
	return pickups


func test_generated_actor_runtime_startup_preserves_metadata_and_save_boundary() -> void:
	var runtime_view := SubViewport.new()
	runtime_view.own_world_3d = true
	runtime_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child_autofree(runtime_view)

	var document: Node3D = LevelRootScript.new()
	document.name = "GeneratedRuntimeLevel"
	document.level_name = "Generated Runtime Smoke"
	document.set_meta("mission_id", "generated_runtime_smoke")
	document.set_meta("document_runtime_session", true)
	runtime_view.add_child(document)

	var player_spawn: LevelSpawnPoint = SpawnPointScript.new()
	player_spawn.name = "PlayerSpawn"
	player_spawn.spawn_type = LevelSpawnPoint.SpawnType.PLAYER
	document.add_child(player_spawn)
	player_spawn.owner = document

	var enemy_record := {"id": "enemy_0", "enemy_id": "grunt_basic", "tier": 1}
	var enemy: EnemySpawnerActor = EnemySpawnerActorScript.new()
	enemy.name = "EnemySpawner_0"
	enemy.actor_id = "enemy_0"
	enemy.enemy_id = "grunt_basic"
	enemy.auto_spawn = true
	enemy.set_meta("generation", enemy_record.duplicate(true))
	document.add_child(enemy)
	enemy.owner = document

	var pickup_record := {"id": "item_0", "type": "health", "item_id": "health_potion"}
	var pickup: PickupSpawnerActor = PickupSpawnerActorScript.new()
	pickup.name = "PickupSpawner_0"
	pickup.actor_id = "item_0"
	pickup.pickup_category = PickupSpawnerActor.PickupCategory.HEALTH
	pickup.item_id = "health_potion"
	pickup.auto_spawn = true
	pickup.set_meta("generation", pickup_record.duplicate(true))
	document.add_child(pickup)
	pickup.owner = document

	var key_record := {"color": "RED", "position": Vector3(2, 0, 0)}
	var key: KeyPickupActor = KeyPickupActorScript.new()
	key.name = "KeyPickup_0"
	key.actor_id = key.name
	key.key_id = "key_red"
	key.set_meta("generation", key_record.duplicate(true))
	key.set_meta(
		"mission_objective",
		{"description": "Collect generated red key", "order": 0}
	)
	document.add_child(key)
	key.owner = document

	var door_record := {"color": "RED", "position": Vector3(4, 0, 0)}
	var door: DoorActor = DoorActorScript.new()
	door.name = "LockedDoor_0"
	door.actor_id = door.name
	door.locked = true
	door.required_key = "key_red"
	door.set_meta("generation", door_record.duplicate(true))
	door.set_meta(
		"mission_objective",
		{
			"description": "Open generated red door",
			"requires": ["KeyPickup_0"],
			"order": 1
		}
	)
	document.add_child(door)
	door.owner = document

	await get_tree().process_frame
	assert_true(_mission.start_document_mission(document))
	var key_identity: String = document.get_actor_identity(key)
	var door_identity: String = document.get_actor_identity(door)
	assert_eq(_mission.active_mission_data.objectives.size(), 2)
	assert_eq(_mission.active_mission_data.objectives[0].id, key_identity)
	assert_eq(_mission.active_mission_data.objectives[1].id, door_identity)
	assert_eq(_mission.active_mission_data.objectives[1].requires, [key_identity])
	assert_eq(_mission.objective_state.get(key_identity, -1), 0)
	assert_eq(_mission.objective_state.get(door_identity, -1), 0)

	enemy.start_runtime()
	pickup.start_runtime()
	key.start_runtime()
	door.start_runtime()
	await get_tree().process_frame

	assert_true(enemy.get("_runtime_started"), "Enemy spawner must enter runtime")
	assert_true(pickup.get("_runtime_started"), "Pickup spawner must enter runtime")
	assert_true(key.get("_actor_runtime_started"), "Key actor must enter runtime")
	assert_true(door.get("_actor_runtime_started"), "Door actor must enter runtime")
	assert_eq(enemy.get_meta("generation"), enemy_record)
	assert_eq(pickup.get_meta("generation"), pickup_record)
	assert_eq(key.get_meta("generation"), key_record)
	assert_eq(door.get_meta("generation"), door_record)
	assert_eq(key.activation_count, 0, "Smoke must not collect the generated key")
	assert_eq(door.activation_count, 0, "Smoke must not open the generated door")

	var spawned_enemy: Node = document.get_node_or_null("EncounterEnemy_0")
	var spawned_pickup: Node = pickup.get("_current_pickup") as Node
	assert_not_null(spawned_enemy, "Enemy runtime startup should create its encounter child")
	assert_not_null(spawned_pickup, "Pickup runtime startup should create its pickup child")
	if spawned_enemy:
		assert_true(spawned_enemy.get_meta("editor_runtime_only", false))
	if spawned_pickup:
		assert_true(spawned_pickup.get_meta("editor_runtime_only", false))

	document.prepare_for_save()
	if spawned_enemy:
		assert_eq(spawned_enemy.owner, null, "Runtime enemy must not be scene-owned")
	if spawned_pickup:
		assert_eq(spawned_pickup.owner, null, "Runtime pickup must not be scene-owned")
	var packed := PackedScene.new()
	assert_eq(packed.pack(document), OK)
	var saved_document: Node3D = packed.instantiate() as Node3D
	assert_not_null(saved_document)
	if saved_document:
		saved_document.authoring_mode = true
		runtime_view.add_child(saved_document)
		assert_null(
			saved_document.get_node_or_null("EncounterEnemy_0"),
			"Runtime enemy must be excluded from the authored scene"
		)
		if spawned_pickup:
			assert_null(
				saved_document.get_node_or_null(NodePath(spawned_pickup.name)),
				"Runtime pickup must be excluded from the authored scene"
			)

func test_generated_health_spawner_collects_catalog_effect_and_completes() -> void:
	var player := PlayerScene.instantiate() as Player
	assert_not_null(player, "Generated pickup completion needs the production player contract")
	if not player:
		return
	player.name = "GeneratedHealthCollector"
	player.isolated_session = true
	_world.add_child(player)
	await get_tree().process_frame
	var health := player.get_node_or_null("HealthComponent") as HealthComponent
	assert_not_null(health, "Production player must expose HealthComponent")
	if not health:
		return
	health.set_health(25.0)

	_level.set_meta("document_runtime_session", true)
	_level.runtime_player = player
	var spawner: PickupSpawnerActor = PickupSpawnerActorScript.new()
	spawner.name = "GeneratedHealthSpawner"
	spawner.actor_id = "generated_health"
	spawner.pickup_category = PickupSpawnerActor.PickupCategory.HEALTH
	spawner.item_id = "health_potion"
	spawner.auto_spawn = true
	spawner.one_shot = true
	spawner.position = Vector3(1, 0, 0)
	_level.add_child(spawner)
	await get_tree().process_frame
	spawner.start_runtime()
	await get_tree().process_frame

	var pickup := spawner.get("_current_pickup") as PickupBase
	assert_not_null(pickup, "Generated health spawner must create a real PickupBase")
	if not pickup:
		return
	assert_true(pickup is HealthPickup)
	assert_eq((pickup as HealthPickup).tier, HealthPickup.HealthTier.LARGE)
	player.global_position = pickup.global_position
	assert_true(health.current_health < health.max_health)
	assert_true(
		pickup.collect_for_player(player, player.get_multiplayer_authority()),
		"Collection must use PickupBase's authoritative public API"
	)
	assert_eq(health.current_health, 75.0, "Catalog health potion must restore its advertised 50 HP")
	assert_true(pickup.collected)
	assert_false(
		pickup.collect_for_player(player, player.get_multiplayer_authority()),
		"Collected pickup must reject duplicate application"
	)
	assert_eq(spawner.capture_runtime_state().pickup_phase, "collected")
	assert_eq(spawner.activation_count, 1)


func test_generated_enemy_damage_marks_health_dead_and_clears_encounter() -> void:
	_level.set_meta("document_runtime_session", true)
	var encounter: EnemySpawnerActor = EnemySpawnerActorScript.new()
	encounter.name = "GeneratedEnemySpawner"
	encounter.actor_id = "generated_enemy"
	encounter.enemy_id = "grunt_basic"
	encounter.auto_spawn = true
	encounter.spawn_count = 1
	encounter.spawn_interval = 0.0
	_level.add_child(encounter)
	await get_tree().process_frame
	encounter.start_runtime()
	await get_tree().process_frame

	var enemy := _level.get_node_or_null("EncounterEnemy_0") as Enemy
	assert_not_null(enemy, "Generated enemy spawner must create its encounter child")
	if not enemy:
		return
	var health := enemy.get_node_or_null("HealthComponent") as HealthComponent
	assert_not_null(health, "EnemyBuilder output must include HealthComponent")
	if not health:
		return
	var damage := DamageInfo.create(
		health.current_health, DamageInfo.DamageType.BULLET
	)
	enemy.take_damage(damage)
	assert_true(health.is_dead, "Lethal DamageInfo must close the enemy health lifecycle")
	assert_true(enemy.is_dead)
	await get_tree().process_frame

	var state := encounter.capture_runtime_state()
	assert_true(state.encounter_cleared, "Enemy spawner must complete after its generated enemy dies")
	assert_eq(state.enemies.size(), 1)
	assert_false(state.enemies[0].alive)
	assert_eq(encounter.activation_count, 1)



func test_nested_authored_enemy_spawns_without_legacy_arena_enemies() -> void:
	var floor_body := StaticBody3D.new()
	floor_body.position.y = -0.5
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(30, 1, 30)
	shape.shape = box
	floor_body.add_child(shape)
	_level.add_child(floor_body)
	var marker: LevelSpawnPoint = SpawnPointScript.new()
	marker.spawn_type = LevelSpawnPoint.SpawnType.ENEMY
	marker.enemy_id = "grunt_basic"
	marker.position = Vector3(0, 0.5, 0)
	marker.rotation.y = 0.4
	_markers.add_child(marker)
	await get_tree().physics_frame

	_manager.spawn_enemies()

	var enemies: Array[Node] = []
	for child: Node in _world.get_children():
		if child is Enemy:
			enemies.append(child)
	assert_eq(enemies.size(), 1, "Only the authored enemy should exist, not legacy arena spawns")
	assert_eq(_stats.enemies_spawned, 1)
	if enemies.size() == 1:
		var enemy: Node3D = enemies[0]
		assert_eq(enemy.enemy_id, "grunt_basic")
		assert_true(enemy.global_position.is_equal_approx(marker.global_position))
		assert_true(enemy.global_basis.is_equal_approx(Basis.from_euler(marker.global_rotation)))


func test_authored_catalog_item_keeps_world_transform_and_heals_on_pickup() -> void:
	var marker := _item_marker("health_potion", Vector3(1, 2, 0))
	_manager.spawn_enemies()
	var pickups := _pickups()
	assert_eq(pickups.size(), 1)
	assert_eq(
		_stats.enemies_spawned, 0, "An item-only authored level must not spawn legacy enemies"
	)
	if pickups.size() != 1:
		return
	var pickup: Node3D = pickups[0]
	assert_true(pickup.global_position.is_equal_approx(marker.global_position))
	assert_true(pickup.global_basis.is_equal_approx(Basis.from_euler(marker.global_rotation)))
	var recipient := PickupRecipient.new()
	_world.add_child(recipient)
	recipient.global_position = pickup.global_position
	pickup._request_pickup(recipient.get_path())
	assert_eq(recipient.health, 75, "The catalog potion must apply its real 50 HP effect")
	assert_true(pickup.collected)


func test_authored_material_enters_inventory_with_its_catalog_type() -> void:
	_item_marker("scrap_metal", Vector3(0, 2, 0))
	_manager.spawn_enemies()
	var pickups := _pickups()
	assert_eq(pickups.size(), 1)
	if pickups.size() != 1:
		return
	var recipient := PickupRecipient.new()
	recipient.inventory = Inventory.new()
	_world.add_child(recipient)
	recipient.global_position = pickups[0].global_position
	pickups[0]._request_pickup(recipient.get_path())
	var item: InventoryItem = recipient.inventory.get_item_at(0)
	assert_not_null(item)
	if item:
		assert_eq(item.id, "scrap_metal")
		assert_eq(item.item_type, InventoryItem.ItemType.MATERIAL)
		assert_eq(item.current_stack, 1)


func test_authored_health_tier_and_weapon_scene_keep_their_pickup_effects() -> void:
	_item_marker("health_mega", Vector3(0, 2, 0))
	_item_marker("shotgun_pickup", Vector3(4, 2, 0))
	_manager.spawn_enemies()
	var pickups := _pickups()
	assert_eq(pickups.size(), 2)
	var recipient := PickupRecipient.new()
	_world.add_child(recipient)
	for pickup: Node3D in pickups:
		recipient.global_position = pickup.global_position
		pickup._request_pickup(recipient.get_path())
	assert_eq(recipient.health, 125, "Megahealth must retain its overhealing tier")
	assert_eq(recipient.ammo_by_weapon.get(WeaponPickup.WeaponType.SHOTGUN, 0), 12)
	assert_false(recipient.ammo_by_weapon.has(WeaponPickup.WeaponType.PISTOL))


func test_authored_item_respawns_at_its_marker_after_collection() -> void:
	var marker := _item_marker("shield_booster", Vector3(0, 2, 0), 0.01)
	_manager.spawn_enemies()
	var pickups := _pickups()
	assert_eq(pickups.size(), 1)
	if pickups.size() != 1:
		return
	var original_id: int = pickups[0].get_instance_id()
	var recipient := PickupRecipient.new()
	_world.add_child(recipient)
	recipient.global_position = pickups[0].global_position
	pickups[0]._request_pickup(recipient.get_path())
	assert_eq(recipient.armor, 25)
	await get_tree().create_timer(0.1).timeout
	pickups = _pickups()
	assert_eq(pickups.size(), 1, "Exactly one replacement pickup should be spawned")
	if pickups.size() == 1:
		assert_ne(pickups[0].get_instance_id(), original_id)
		# Rigid-body pickups can fall between respawn and this observation.
		assert_almost_eq(pickups[0].global_position.x, marker.global_position.x, 0.001)
		assert_almost_eq(pickups[0].global_position.z, marker.global_position.z, 0.001)
		recipient.global_position = pickups[0].global_position
		pickups[0]._request_pickup(recipient.get_path())
		assert_eq(recipient.armor, 50, "The replacement retains the authored item's effect")


func test_player_spawns_at_authored_marker_instead_of_origin() -> void:
	var world := SpawnWorld.new()
	add_child(world)
	var level: Node3D = LevelRootScript.new()
	level.position = Vector3(50, 0, 60)
	level.rotation.y = 0.7
	world.add_child(level)
	var marker: LevelSpawnPoint = SpawnPointScript.new()
	marker.position = Vector3(3, 2, 4)
	marker.rotation.y = 0.2
	level.add_child(marker)
	var player_service: PlayerSvc = PlayerSvc.get_instance()
	var player_data: Dictionary = (
		player_service._player_data.duplicate(true) if player_service else {}
	)
	var tokens: Dictionary = player_service._active_tokens.duplicate() if player_service else {}
	var mouse_mode: Input.MouseMode = Input.mouse_mode
	var gameplay := GameManager.get_core_system("gameplay") as GameplaySvc
	var scores: Dictionary = (
		gameplay.match_service.player_scores.duplicate(true)
		if gameplay and gameplay.match_service
		else {}
	)

	world.spawn_player_node(1, "editor")

	var player: Node3D = world.get_node("1")
	assert_true(player.global_position.is_equal_approx(marker.global_position))
	assert_true(player.global_basis.is_equal_approx(Basis.from_euler(marker.global_rotation)))
	world.free()
	Input.mouse_mode = mouse_mode
	if player_service:
		player_service._player_data = player_data
		player_service._active_tokens = tokens
	if gameplay and gameplay.match_service:
		gameplay.match_service.player_scores = scores
