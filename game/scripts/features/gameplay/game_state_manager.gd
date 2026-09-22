extends Node

signal save_completed(slot: String)
signal load_completed(slot: String)
signal save_failed(error: String)
signal load_failed(error: String)

const SAVE_VERSION: String = "1.0"
const SAVE_DIR: String = "user://saves/"
const QUICKSAVE_SLOT: String = "quicksave"
const MAX_SAVED_ENEMIES: int = 128

var save_slots: Array[String] = [QUICKSAVE_SLOT, "slot1", "slot2", "slot3"]

# Session time tracking
var _session_start_time: float = 0.0
var _total_session_time: float = 0.0


func _ready() -> void:
	# Ensure save directory exists
	DirAccess.make_dir_recursive_absolute(SAVE_DIR.replace("user://", OS.get_user_data_dir() + "/"))

	# Start session timer
	_session_start_time = Time.get_ticks_msec() / 1000.0


## Get current session play time in seconds
func get_session_time() -> float:
	var current_time: float = Time.get_ticks_msec() / 1000.0
	return _total_session_time + (current_time - _session_start_time)


## Reset session timer (call when starting new game)
func reset_session_time() -> void:
	_session_start_time = Time.get_ticks_msec() / 1000.0
	_total_session_time = 0.0


## Pause session timer (call when pausing)
func pause_session_time() -> void:
	var current_time: float = Time.get_ticks_msec() / 1000.0
	_total_session_time += (current_time - _session_start_time)


## Resume session timer (call when unpausing)
func resume_session_time() -> void:
	_session_start_time = Time.get_ticks_msec() / 1000.0


## Save game to slot (Server only)


func save_game(slot: String = QUICKSAVE_SLOT) -> bool:
	# In single-player (no peer), we ARE the server
	var is_server_or_sp: bool = not multiplayer.has_multiplayer_peer() or multiplayer.is_server()
	if not is_server_or_sp:
		push_warning("Only server can save game")
		return false
	var session := _get_level_session()
	if session and session.is_travel_pending():
		save_failed.emit("Travel is pending")
		return false

	var save_svc: Node = GameManager.get_core_system("save")
	if not save_svc:
		push_error("[GameStateManager] SaveService not found!")
		save_failed.emit("SaveService missing")
		return false

	var save_data: Dictionary = serialize_world()
	if session and not _validate_world_data(save_data):
		save_failed.emit("Invalid campaign state")
		return false
	save_data["version"] = SAVE_VERSION
	save_data["timestamp"] = Time.get_datetime_string_from_system(true)
	save_data["slot"] = slot

	var metadata: Dictionary = {
		"version": SAVE_VERSION,
		"player_count":
		(
			save_data.level_campaign.players.size()
			if save_data.has("level_campaign")
			else save_data.get("players", []).size()
		),
		"time_played": get_session_time()
	}

	if save_svc.save_data(slot, save_data, metadata):
		GameManager.get_core_system("logger").info(
			"[GameStateManager] Saved to slot: " + " " + str(slot), "Core"
		)
		save_completed.emit(slot)
		return true
	save_failed.emit("Write failed")
	return false


## Load game from slot (Server only, syncs to clients)


func load_game(slot: String = QUICKSAVE_SLOT) -> bool:
	# In single-player (no peer), we ARE the server
	var is_server_or_sp: bool = not multiplayer.has_multiplayer_peer() or multiplayer.is_server()
	if not is_server_or_sp:
		push_warning("Only server can load game")
		return false
	var session := _get_level_session()
	if session and session.is_travel_pending():
		load_failed.emit("Travel is pending")
		return false

	var save_svc: Node = GameManager.get_core_system("save")
	if not save_svc:
		push_error("[GameStateManager] SaveService not found!")
		load_failed.emit("SaveService missing")
		return false

	var save_data: Dictionary = save_svc.load_data(slot)
	if save_data.is_empty():
		load_failed.emit("Load failed or empty data")
		return false

	# Validate every destructive section before changing live nodes.
	if not _validate_world_data(save_data):
		load_failed.emit("Invalid save data")
		return false

	if not await deserialize_world(save_data):
		load_failed.emit("World restoration failed")
		return false

	# Sync to all clients only after the authoritative world was restored.
	if multiplayer.has_multiplayer_peer() and not save_data.has("level_campaign"):
		_sync_load_to_clients.rpc(save_data)

	GameManager.get_core_system("logger").info(
		"[GameStateManager] Loaded from slot: " + " " + str(slot), "Core"
	)
	load_completed.emit(slot)
	return true


@rpc("authority", "call_remote", "reliable")
func _sync_load_to_clients(save_data: Dictionary) -> void:
	# Clients receive world state from server
	if save_data.has("level_campaign"):
		return
	if not _validate_world_data(save_data):
		load_failed.emit("Invalid synchronized save data")
		return
	if not await deserialize_world(save_data):
		load_failed.emit("Synchronized world restoration failed")
		return
	load_completed.emit(save_data.get("slot", "unknown"))


func _validate_world_data(data: Dictionary) -> bool:
	var session := _get_level_session()
	if session:
		var campaign: Variant = data.get("level_campaign")
		return (
			not session.is_travel_pending()
			and campaign is Dictionary
			and validate_session_players(campaign.get("players"))
			and session.validate_campaign_state(campaign)
		)
	if data.has("level_campaign") or data.has("level_runtime"):
		return false
	if data.has("enemies") and not _validate_enemy_records(data["enemies"]):
		push_warning("[GameStateManager] Save validation failed: enemies")
		return false
	if data.has("items") and not _validate_item_records(data["items"]):
		push_warning("[GameStateManager] Save validation failed: items")
		return false
	if data.has("environment") and not _validate_environment_records(data["environment"]):
		push_warning("[GameStateManager] Save validation failed: environment")
		return false
	if data.has("players") and not _validate_player_records(data["players"]):
		push_warning("[GameStateManager] Save validation failed: players")
		return false
	return true


func _validate_player_records(data: Variant) -> bool:
	if not data is Array:
		return false
	var seen_peers: Dictionary = {}
	for record: Variant in data:
		if not record is Dictionary:
			return false
		if (
			not _is_integer_value(record.get("peer_id"))
			or record.peer_id <= 0
			or record.peer_id > 2147483647
			or seen_peers.has(int(record.peer_id))
		):
			return false
		seen_peers[int(record.peer_id)] = true
		if record.has("position") and not _is_valid_vec3_array(record.position):
			return false
		if record.has("rotation") and not _is_valid_vec3_array(record.rotation):
			return false
		if record.has("keys"):
			if not record["keys"] is Array:
				return false
			var seen_keys: Dictionary = {}
			for key: Variant in record["keys"]:
				if not key is String or key.is_empty() or seen_keys.has(key):
					return false
				seen_keys[key] = true
	return true


## Session records are complete, JSON-safe snapshots; world saves retain their
## historical optional fields.
func validate_session_players(records: Variant) -> bool:
	if not _validate_player_records(records):
		return false
	for record: Dictionary in records:
		for field: String in ["position", "rotation"]:
			if not _is_valid_vec3_array(record.get(field)):
				return false
		for field: String in ["health", "armor"]:
			var value: Variant = record.get(field)
			if not (value is int or value is float) or not is_finite(value) or value < 0:
				return false
		if (
			not _is_integer_value(record.get("lifecycle"))
			or not int(record.lifecycle) in Enums.PlayerState.values()
		):
			return false
		if record.lifecycle == Enums.PlayerState.ALIVE and record.health <= 0:
			return false
		if not record.get("keys") is Array:
			return false
		var ammo: Variant = record.get("weapon_ammo")
		if not ammo is Dictionary:
			return false
		for weapon: Variant in ammo:
			if not weapon is String or weapon.is_empty():
				return false
			var counts: Variant = ammo[weapon]
			if not counts is Array or counts.size() != 2:
				return false
			for count: Variant in counts:
				if not _is_integer_value(count) or count < 0 or count > 2147483647:
					return false
		var index: Variant = record.get("current_weapon_index")
		if not _is_integer_value(index) or index < 0 or index >= maxi(1, ammo.size()):
			return false
		if not _validate_inventory(record.get("inventory"), int(record.peer_id)):
			return false
	return true


func _validate_inventory(data: Variant, peer_id: int) -> bool:
	if not data is Dictionary or not _is_integer_value(data.get("owner_peer_id")):
		return false
	if int(data.owner_peer_id) != peer_id:
		return false
	if not data.get("slots") is Array or data.slots.size() != Inventory.MAX_SLOTS:
		return false
	if (
		not data.get("equipment") is Dictionary
		or data.equipment.size() != Inventory.EQUIPMENT_SLOTS.size()
	):
		return false
	for item: Variant in data.slots:
		if item != null and not _validate_inventory_item(item):
			return false
	for slot: String in Inventory.EQUIPMENT_SLOTS:
		if not data.equipment.has(slot):
			return false
		var item: Variant = data.equipment[slot]
		if item != null:
			if not _validate_inventory_item(item):
				return false
			if not item.equip_slot.is_empty() and item.equip_slot != slot:
				return false
	return true


func _validate_inventory_item(item: Variant) -> bool:
	if not item is Dictionary:
		return false
	for field: String in [
		"id",
		"display_name",
		"description",
		"icon_path",
		"equip_slot",
		"weapon_scene",
		"effect_type"
	]:
		if not item.get(field) is String:
			return false
	if (
		item.id.is_empty()
		or (not item.equip_slot.is_empty() and not item.equip_slot in Inventory.EQUIPMENT_SLOTS)
	):
		return false
	for field: String in ["item_type", "rarity", "max_stack", "current_stack", "value"]:
		if not _is_integer_value(item.get(field)) or item[field] < 0 or item[field] > 2147483647:
			return false
	if (
		not int(item.item_type) in InventoryItem.ItemType.values()
		or not int(item.rarity) in ItemRarity.Tier.values()
	):
		return false
	if item.current_stack < 1 or item.max_stack < 1 or item.current_stack > item.max_stack:
		return false
	return (
		(item.get("effect_value") is int or item.get("effect_value") is float)
		and is_finite(item.effect_value)
	)


func _validate_enemy_records(data: Variant) -> bool:
	if not data is Array:
		return false
	var world: Node = get_tree().current_scene
	if (
		not world
		or not world.has_method("prepare_enemy_for_restore")
		or not world.has_method("commit_enemy_restore")
	):
		return false
	var config: Node = GameManager.get_core_system("config")
	var configured_max: Variant = config.get_value("enemies.max_count", null) if config else null
	var max_enemies: int = MAX_SAVED_ENEMIES
	if configured_max is int or configured_max is float:
		var candidate_max: int = int(configured_max)
		if candidate_max > 0:
			max_enemies = candidate_max
	if data.size() > max_enemies:
		return false
	var data_service: Node = GameManager.get_core_system("data")
	if not data_service or not data_service.has_method("get_enemy_data"):
		return false
	for record: Variant in data:
		if not record is Dictionary:
			return false
		var enemy_id: Variant = record.get("id", "")
		if not enemy_id is String or enemy_id.strip_edges().is_empty():
			return false
		if not _is_valid_vec3_array(record.get("position", null)):
			return false
		if not _is_valid_vec3_array(record.get("rotation", null)):
			return false
		var health: Variant = record.get("health", 100.0)
		if (
			(health is bool)
			or not (health is int or health is float)
			or not is_finite(float(health))
		):
			return false
		if float(health) < 0.0:
			return false
		if data_service.get_enemy_data(enemy_id).is_empty():
			return false
	return true


func _validate_item_records(data: Variant) -> bool:
	if not data is Array:
		return false
	for record: Variant in data:
		if not record is Dictionary:
			return false
		var scene_path: Variant = record.get("scene_path", "")
		if not scene_path is String or scene_path.is_empty():
			return false
		if not ResourceLoader.exists(scene_path, "PackedScene"):
			return false
		if not _is_valid_vec3_array(record.get("position", null)):
			return false
		if not _is_valid_vec3_array(record.get("rotation", null)):
			return false
		if record.has("name") and not record.name is String:
			return false
		if record.has("item_data") and not record.item_data is Dictionary:
			return false
		if record.has("owner_peer_id") and not _is_integer_value(record.owner_peer_id):
			return false
		if record.has("rarity_tier") and not _is_integer_value(record.rarity_tier):
			return false
	return true


func _is_integer_value(value: Variant) -> bool:
	if value is int:
		return true
	if value is float:
		return is_finite(value) and value == floor(value)
	return false


func _validate_environment_records(data: Variant) -> bool:
	if not data is Dictionary:
		return false
	for key: String in ["doors", "destructibles"]:
		if data.has(key) and not data[key] is Array:
			return false
		for record: Variant in data.get(key, []):
			if not record is Dictionary:
				return false
			var path: Variant = record.get("path", "")
			if not path is String or path.is_empty():
				return false
			var actor: Node = get_node_or_null(path)
			if not actor:
				return false
			if key == "doors":
				if not actor.has_method("restore_state"):
					return false
				if record.has("is_open") and not record.is_open is bool:
					return false
				if record.has("is_locked") and not record.is_locked is bool:
					return false
			else:
				if not actor.has_method("restore_state"):
					return false
				if record.has("is_broken") and not record.is_broken is bool:
					return false
	return true


func _is_valid_vec3_array(value: Variant) -> bool:
	if not value is Array or value.size() != 3:
		return false
	for component: Variant in value:
		if component is bool or not (component is int or component is float):
			return false
		if not is_finite(float(component)):
			return false
	return true


## Serialize entire world state


func serialize_world() -> Dictionary:
	var data: Dictionary = {}
	var session := _get_level_session()
	if session:
		return {"level_campaign": session.capture_campaign_state()}

	# Match state
	data["match"] = _serialize_match()

	# Players
	data["players"] = _serialize_players()

	# Enemies
	data["enemies"] = _serialize_enemies()

	# Items/Pickups
	data["items"] = _serialize_items()

	# Environment (doors, destructibles)
	data["environment"] = _serialize_environment()

	return data


## Deserialize and restore world state


func deserialize_world(data: Dictionary) -> bool:
	if not _validate_world_data(data):
		return false
	if data.has("level_campaign"):
		var session := _get_level_session()
		if (
			not session
			or (session.multiplayer.has_multiplayer_peer() and not session.multiplayer.is_server())
		):
			return false
		return await session.restore_campaign_state(data.level_campaign)

	# Match state and players are non-destructive; enemy/item restoration is
	# staged before their existing nodes are removed.
	if data.has("match"):
		if not data.match is Dictionary:
			return false
		_deserialize_match(data["match"])

	if data.has("players"):
		_deserialize_players(data["players"])

	if data.has("enemies") and not await _deserialize_enemies(data["enemies"]):
		return false

	if data.has("items") and not await _deserialize_items(data["items"]):
		return false

	if data.has("environment") and not _deserialize_environment(data["environment"]):
		return false
	return true


# -------------------------------------------------------------------------
# Serialization Helpers
# -------------------------------------------------------------------------


func _serialize_match() -> Dictionary:
	var match_data: Dictionary = {}

	# Get from MatchService if available
	var gs := GameManager.get_core_system("gameplay") as GameplaySvc
	if gs and gs.match_service:
		var t_left: float = gs.match_service.time_left
		match_data["time_left"] = t_left if is_finite(t_left) else 0.0
		match_data["state"] = gs.match_service.current_match_state
		match_data["scores"] = gs.match_service.player_scores.duplicate()

	return match_data


func _deserialize_match(data: Dictionary) -> void:
	var gs := GameManager.get_core_system("gameplay") as GameplaySvc
	if gs and gs.match_service:
		gs.match_service.time_left = data.get("time_left", 0.0)
		gs.match_service.current_match_state = data.get("state", 0)
		if data.has("scores"):
			gs.match_service.player_scores = _normalize_player_scores(data["scores"])


func _normalize_player_scores(scores: Dictionary) -> Dictionary:
	var normalized: Dictionary = {}
	for raw_peer_id: Variant in scores:
		var peer_id: int
		if raw_peer_id is int:
			peer_id = raw_peer_id
		elif str(raw_peer_id).is_valid_int():
			peer_id = int(raw_peer_id)
		else:
			continue
		normalized[peer_id] = scores[raw_peer_id]
	return normalized


func capture_session_players(session: Node) -> Array:
	return _serialize_players(session) if is_instance_valid(session) else []


func restore_session_players(records: Array, session: Node) -> void:
	if is_instance_valid(session) and validate_session_players(records):
		_deserialize_players(records, session)


func _get_level_session() -> Node:
	for session: Node in get_tree().get_nodes_in_group("level_play_session"):
		if session.multiplayer == multiplayer:
			return session
	return null


func _player_nodes(scope: Node = null) -> Array:
	if scope:
		return scope.get_session_players()
	var players: Array = []
	for node: Node in get_tree().get_nodes_in_group("player"):
		if node.multiplayer == multiplayer and node is CharacterBody3D:
			players.append(node)
	return players


func _serialize_players(scope: Node = null) -> Array:
	var players_data: Array = []
	for node: Node in _player_nodes(scope):
		if node is CharacterBody3D:
			# Access properties via components (Player uses health_component and weapon_manager)
			var health_val: float = 100.0
			var armor_val: float = 0.0
			var weapon_idx: int = 0
			var ammo_data: Dictionary = {}

			if "health_component" in node and node.health_component:
				health_val = node.health_component.current_health
				armor_val = node.health_component.current_armor

			if "weapon_manager" in node and node.weapon_manager:
				weapon_idx = node.weapon_manager.current_weapon_index
				ammo_data = node.weapon_manager.get_ammo_data()

			var player_data: Dictionary = {
				"peer_id": node.get_multiplayer_authority(),
				"position": _vec3_to_array(node.global_position),
				"rotation": _vec3_to_array(node.global_rotation),
				"health": health_val,
				"armor": armor_val,
				"current_weapon_index": weapon_idx,
				"weapon_ammo": ammo_data
			}
			if "interaction_component" in node and node.interaction_component:
				player_data["keys"] = node.interaction_component.get_collected_keys()
			if "inventory" in node and node.inventory:
				player_data["inventory"] = node.inventory.to_dict()
			if "state_manager" in node and node.state_manager:
				player_data["lifecycle"] = node.state_manager.current_state

			players_data.append(player_data)

	return players_data


func _deserialize_players(data: Array, scope: Node = null) -> void:
	for player_data: Dictionary in data:
		var peer_id: int = player_data.get("peer_id", 0)

		# Find player node by authority
		for node: Node in _player_nodes(scope):
			if node.get_multiplayer_authority() == peer_id:
				if not scope:
					node.global_position = _array_to_vec3(player_data.get("position", [0, 0, 0]))
					node.global_rotation = _array_to_vec3(player_data.get("rotation", [0, 0, 0]))
					if node is CharacterBody3D:
						node.velocity = Vector3.ZERO
				if "interaction_component" in node and node.interaction_component:
					var keys: Array = player_data.get("keys", [])
					if (
						not scope
						or not LevelRuntimeState._same_json_value(
							keys, node.interaction_component.get_collected_keys()
						)
					):
						node.interaction_component.restore_collected_keys(keys)
				if player_data.has("inventory") and "inventory" in node and node.inventory:
					if (
						not scope
						or not LevelRuntimeState._same_json_value(
							player_data.inventory, node.inventory.to_dict()
						)
					):
						node.inventory.from_dict(player_data.inventory)
				# The server restores lifecycle and health once, then replicates both.
				if (
					not scope
					and (
						not node.multiplayer.has_multiplayer_peer() or node.multiplayer.is_server()
					)
				):
					var hp: float = player_data.get("health", 100)
					var armor: float = player_data.get("armor", 0)
					if "state_manager" in node and node.state_manager:
						node.state_manager.restore_health(hp, armor)
					elif "health_component" in node and node.health_component:
						node.health_component.set_health(hp, armor)

				# Restore weapon state via weapon_manager
				if "weapon_manager" in node and node.weapon_manager:
					var saved_idx: int = int(player_data.get("current_weapon_index", 0))
					if not scope or saved_idx != node.weapon_manager.current_weapon_index:
						if scope and node.weapon_manager.inventory:
							node.weapon_manager.inventory.switch_to_weapon(saved_idx)
						else:
							node.weapon_manager.switch_to_weapon(saved_idx)
					if player_data.get("weapon_ammo") is Dictionary:
						if (
							not scope
							or not LevelRuntimeState._same_json_value(
								player_data.weapon_ammo, node.weapon_manager.get_ammo_data()
							)
						):
							node.weapon_manager.apply_ammo_data(player_data.weapon_ammo)
					elif (
						player_data.get("weapon_ammo") is Array and node.weapon_manager.ammo_system
					):
						var current_ammo: Array = node.weapon_manager.ammo_system.weapon_ammo
						var limit: int = mini(player_data.weapon_ammo.size(), current_ammo.size())
						for i in range(limit):
							current_ammo[i] = player_data.weapon_ammo[i]
						node.weapon_manager.ammo_system.emit_ammo_update()
				if scope:
					_restore_session_lifecycle(node, player_data)
				break


func _restore_session_lifecycle(node: Node, record: Dictionary) -> void:
	var state: Node = node.state_manager if "state_manager" in node else null
	var health: HealthComponent = node.health_component if "health_component" in node else null
	if not state or not health:
		return
	# Campaign snapshots are authenticated by the travel coordinator and apply
	# locally on every peer; ordinary setters would duplicate network updates.
	var lifecycle: int = int(record.lifecycle)
	var lifecycle_changed: bool = state.current_state != lifecycle
	if lifecycle_changed:
		state._restore_alive()
	if health.current_health != record.health or health.current_armor != record.armor:
		health._apply_health_state(float(record.health), float(record.armor))
	health.set("_is_dead", record.health <= 0)
	if not lifecycle_changed:
		return
	if lifecycle == Enums.PlayerState.DOWNED:
		if state.current_state != lifecycle:
			state.current_state = lifecycle
			state.state_changed.emit(lifecycle)
		if node.downed_handler and not node.downed_handler.is_downed:
			node.downed_handler.enter_downed()
		state._sync_downed_visuals(true)
	elif lifecycle == Enums.PlayerState.DEAD or lifecycle == Enums.PlayerState.SPECTATING:
		state._cancel_pending_respawn()
		if node.downed_handler:
			node.downed_handler.exit_downed()
		state._sync_downed_visuals(false)
		state._sync_death_visuals(true)
		if state.current_state != lifecycle:
			state.current_state = lifecycle
			state.state_changed.emit(lifecycle)
		if node.is_multiplayer_authority() and not is_instance_valid(state._spectator_instance):
			state._start_spectating()
	elif state.current_state != lifecycle:
		state.current_state = lifecycle
		state.state_changed.emit(lifecycle)


func _serialize_enemies() -> Array:
	var enemies_data: Array = []

	for node in get_tree().get_nodes_in_group("enemies"):
		if node is CharacterBody3D:
			var enemy_data: Dictionary = {
				"id": node.enemy_id if "enemy_id" in node else "",
				"name": node.name,
				"position": _vec3_to_array(node.global_position),
				"rotation": _vec3_to_array(node.global_rotation),
				"health": node.health if "health" in node else 100
			}
			enemies_data.append(enemy_data)

	return enemies_data


func _deserialize_enemies(data: Array) -> bool:
	var world: Node = get_tree().current_scene
	if (
		not world
		or not world.has_method("prepare_enemy_for_restore")
		or not world.has_method("commit_enemy_restore")
	):
		return false

	# Instantiate every replacement off-tree first. A failed record therefore
	# cannot erase the currently active enemies.
	var staged: Array[Dictionary] = []
	for enemy_data: Dictionary in data:
		var enemy: Node = world.prepare_enemy_for_restore(
			_array_to_vec3(enemy_data.position), enemy_data.id, _array_to_vec3(enemy_data.rotation)
		)
		if not enemy:
			for entry: Dictionary in staged:
				entry.enemy.free()
			return false
		staged.append({"enemy": enemy, "health": float(enemy_data.get("health", 100.0))})

	for node in get_tree().get_nodes_in_group("enemies"):
		node.queue_free()
	await get_tree().process_frame

	for entry: Dictionary in staged:
		var enemy: Node = entry.enemy
		if not world.commit_enemy_restore(enemy):
			for rollback_entry: Dictionary in staged:
				var rollback_enemy: Node = rollback_entry.enemy
				if is_instance_valid(rollback_enemy):
					rollback_enemy.queue_free()
			return false
		if "health" in enemy:
			enemy.health = entry.health

	if multiplayer.is_server():
		await get_tree().process_frame
		var ps: Node = GameManager.get_core_system("performance")
		if ps and ps.has_method("optimize_ai_pathfinding"):
			ps.optimize_ai_pathfinding()
	return true


func _serialize_items() -> Array:
	var items_data: Array = []

	for node in get_tree().get_nodes_in_group("items"):
		# Only save if not collected
		var is_collected: bool = node.collected if "collected" in node else false
		if not is_collected:
			var item_data: Dictionary = {
				"scene_path": node.scene_file_path,
				"name": node.pickup_name if "pickup_name" in node else node.name,
				"position": _vec3_to_array(node.global_position),
				"rotation": _vec3_to_array(node.global_rotation)
			}
			if node is PickupBase:
				item_data["item_data"] = node.item_data.duplicate(true)
				item_data["owner_peer_id"] = node.owner_peer_id
				item_data["rarity_tier"] = node.rarity_tier
			# Only save if it has a scene file (instantiable)
			if not item_data["scene_path"].is_empty():
				items_data.append(item_data)

	return items_data


func _deserialize_items(data: Array) -> bool:
	var world: Node = get_tree().current_scene
	if not world:
		return false

	# Fully instantiate and configure replacements before deleting live items.
	var staged: Array[Node3D] = []
	var items_per_batch: int = 5
	for index: int in range(data.size()):
		var item_data: Dictionary = data[index]
		var scene: PackedScene = load(item_data.scene_path) as PackedScene
		if not scene:
			for staged_item: Node3D in staged:
				staged_item.free()
			return false
		var item: Node = scene.instantiate()
		if not item or not item is Node3D:
			if item:
				item.free()
			for staged_item: Node3D in staged:
				staged_item.free()
			return false

		var item_3d: Node3D = item as Node3D
		var world_transform := Transform3D(
			Basis.from_euler(_array_to_vec3(item_data.rotation)), _array_to_vec3(item_data.position)
		)
		item_3d.transform = (
			(world as Node3D).global_transform.affine_inverse() * world_transform
			if world is Node3D
			else world_transform
		)
		if "pickup_name" in item and item_data.has("name"):
			item.pickup_name = item_data.name
		if item is PickupBase:
			item.item_data = item_data.get("item_data", {}).duplicate(true)
			item.owner_peer_id = int(item_data.get("owner_peer_id", 0))
			item.rarity_tier = int(item_data.get("rarity_tier", -1))
		staged.append(item_3d)

		# Keep batching without exposing a partially restored world.
		if (index + 1) % items_per_batch == 0:
			await get_tree().process_frame

	for node in get_tree().get_nodes_in_group("items"):
		node.queue_free()
	await get_tree().process_frame

	for item: Node3D in staged:
		world.add_child(item, true)
		var loot := LootSvc.get_instance()
		if loot and item is PickupBase:
			loot._track_pickup(item, item.owner_peer_id, item.rarity_tier)
	return true


func _serialize_environment() -> Dictionary:
	var env_data: Dictionary = {"doors": [], "destructibles": []}

	for door in get_tree().get_nodes_in_group("doors"):
		env_data["doors"].append(
			{
				"path": door.get_path(),
				"is_open": door.is_open if "is_open" in door else false,
				"is_locked": door.is_locked if "is_locked" in door else false
			}
		)

	# DestructibleObject uses the singular group; keep compatibility with
	# scenes that use the plural group and avoid duplicate records.
	var destructibles: Array[Node] = []
	for group_name: String in ["destructible", "destructibles", "breakables"]:
		for destr: Node in get_tree().get_nodes_in_group(group_name):
			if destr not in destructibles:
				destructibles.append(destr)
	for destr: Node in destructibles:
		env_data["destructibles"].append(
			{
				"path": destr.get_path(),
				"is_broken": destr.is_broken if "is_broken" in destr else false
			}
		)
	return env_data


func _deserialize_environment(data: Dictionary) -> bool:
	for door_data: Dictionary in data.get("doors", []):
		var door: Node = get_node_or_null(door_data.path)
		if not door or not door.has_method("restore_state"):
			return false
		if not door.restore_state(
			bool(door_data.get("is_locked", false)), bool(door_data.get("is_open", false))
		):
			return false

	for destr_data: Dictionary in data.get("destructibles", []):
		var destr: Node = get_node_or_null(destr_data.path)
		if not destr or not destr.has_method("restore_state"):
			return false
		if not destr.restore_state(bool(destr_data.get("is_broken", false))):
			return false
	return true


# -------------------------------------------------------------------------
# Utility Functions
# -------------------------------------------------------------------------


func _vec3_to_array(vec: Vector3) -> Array:
	if not vec.is_finite():
		push_warning("[GameStateManager] NaN/Inf detected in vector serialization: ", vec)
		return [0.0, 0.0, 0.0]
	return [vec.x, vec.y, vec.z]


func _array_to_vec3(arr: Array) -> Vector3:
	if arr.size() >= 3:
		return Vector3(arr[0], arr[1], arr[2])
	return Vector3.ZERO


## Get list of existing saves


func get_save_list() -> Array[Dictionary]:
	var save_svc: Node = GameManager.get_core_system("save")
	if save_svc and save_svc.has_method("get_all_saves"):
		return save_svc.get_all_saves()
	return []


## Delete a save


func delete_save(slot: String) -> void:
	var save_svc: Node = GameManager.get_core_system("save")
	if save_svc and save_svc.has_method("delete_save"):
		save_svc.delete_save(slot)
	GameManager.get_core_system("logger").info(
		"[GameStateManager] Deleted save: " + " " + str(slot), "Core"
	)


## Check if save exists


func save_exists(slot: String) -> bool:
	var save_svc: Node = GameManager.get_core_system("save")
	return save_svc and save_svc.has_method("save_exists") and save_svc.save_exists(slot)
