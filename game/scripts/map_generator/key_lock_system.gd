class_name KeyLockSystem
extends RefCounted

## Implements key-lock mechanics for gated progression
## Requirements: 12.1, 12.2, 12.3, 12.4, 12.5, 12.6

const Cell = preload("res://game/scripts/map_generator/cell.gd")
const Room = preload("res://game/scripts/map_generator/room.gd")

enum KeyColor { RED, BLUE, YELLOW }


## Generate key-lock pairs for the map.
## The returned pair records remain backwards-compatible; a successful result
## also contains the canonical progression manifest. Placement and manifest
## publication are transactional: a failed pair leaves no generated lock state.
func generate_key_lock_system(context: GenerationContext) -> Dictionary:
	context.progression_manifest.clear()
	context.metadata.erase("mission_progression")
	if not context.config.enable_key_locks:
		return {"keys": [], "locked_doors": []}

	var key_count := _calculate_key_count(context)
	var progression_order := _analyze_room_progression(context)
	if progression_order.size() < 2:
		push_warning("Not enough rooms for key-lock system")
		return {"keys": [], "locked_doors": []}
	if progression_order.size() <= 4:
		key_count = 1

	var keys: Array = []
	var locked_doors: Array = []
	for i in range(key_count):
		var key_lock_pair := _place_key_lock_pair(context, progression_order, i as KeyColor, i)
		if key_lock_pair.is_empty():
			_rollback_generated_progression(context, keys, locked_doors)
			return {"keys": [], "locked_doors": []}
		keys.append(key_lock_pair.key)
		locked_doors.append(key_lock_pair.door)

	var manifest := build_progression_manifest(context, progression_order, keys, locked_doors)
	var validation := validate_progression_manifest(context, manifest, false)
	if not validation.is_valid:
		_rollback_generated_progression(context, keys, locked_doors)
		push_warning("Mission progression rejected: " + validation.error_message)
		return {"keys": [], "locked_doors": []}
	context.progression_manifest = manifest
	context.metadata["mission_progression"] = manifest.duplicate(true)
	return {
		"keys": keys, "locked_doors": locked_doors, "progression_manifest": manifest.duplicate(true)
	}


## Build the retained, deterministic mission progression contract.
func build_progression_manifest(
	context: GenerationContext, progression: Array[Room], keys: Array, locked_doors: Array
) -> Dictionary:
	var room_order: Array[int] = []
	for room: Room in progression:
		room_order.append(room.id)

	var manifest_keys: Array[Dictionary] = []
	var manifest_doors: Array[Dictionary] = []
	var objectives: Array[Dictionary] = []
	for index in range(keys.size()):
		var key: Dictionary = keys[index]
		var key_id := "KeyPickup_%d" % index
		manifest_keys.append(
			{
				"id": key_id,
				"color": str(key.get("color", "")),
				"room_id": int(key.get("room_id", -1)),
				"grid_position": key.get("grid_position", Vector2i(-1, -1))
			}
		)
		objectives.append(
			{
				"id": key_id,
				"type": "collect_key",
				"order": index * 2,
				"room_id": int(key.get("room_id", -1)),
				"requires": []
			}
		)
		if index >= locked_doors.size():
			continue
		var door: Dictionary = locked_doors[index]
		var door_id := "LockedDoor_%d" % index
		manifest_doors.append(
			{
				"id": door_id,
				"color": str(door.get("color", "")),
				"room_id": int(door.get("room_id", -1)),
				"grid_position": door.get("grid_position", Vector2i(-1, -1)),
				"key_id": key_id,
				"from_room_id": int(key.get("room_id", -1)),
				"to_room_id": int(door.get("room_id", -1))
			}
		)
		objectives.append(
			{
				"id": door_id,
				"type": "open_lock",
				"order": index * 2 + 1,
				"room_id": int(door.get("room_id", -1)),
				"requires": [key_id]
			}
		)

	var goal_room_id := -1
	if (
		context.exit_position.x >= 0
		and context.exit_position.y >= 0
		and context.exit_position.y < context.grid.size()
		and context.exit_position.x < context.grid[context.exit_position.y].size()
	):
		goal_room_id = context.grid[context.exit_position.y][context.exit_position.x].room_id
	if goal_room_id < 0 and not room_order.is_empty():
		goal_room_id = room_order[-1]
	return {
		"version": 1,
		"seed_hash": context.seed_hash,
		"start_room_id": room_order[0] if not room_order.is_empty() else -1,
		"goal_room_id": goal_room_id,
		"objectives": objectives,
		"keys": manifest_keys,
		"locked_transitions": manifest_doors,
		"recovery_route": room_order
	}


## Validate the manifest independently of publication.
func validate_progression_manifest(
	context: GenerationContext, manifest: Dictionary, check_reachability: bool = true
) -> Dictionary:
	for field: String in [
		"version",
		"seed_hash",
		"start_room_id",
		"goal_room_id",
		"objectives",
		"keys",
		"locked_transitions",
		"recovery_route"
	]:
		if not manifest.has(field):
			return {"is_valid": false, "error_message": "Mission progression missing '%s'" % field}
	for field: String in ["objectives", "keys", "locked_transitions", "recovery_route"]:
		if not manifest.get(field) is Array:
			return {
				"is_valid": false,
				"error_message": "Mission progression field '%s' must be an array" % field
			}
	var keys: Array = manifest.keys
	var doors: Array = manifest.locked_transitions
	var route: Array = manifest.recovery_route
	if route.is_empty() or manifest.start_room_id != route[0]:
		return {"is_valid": false, "error_message": "Mission progression has no valid start route"}
	var colors: Dictionary = {}
	var positions: Dictionary = {}
	var key_ids: Dictionary = {}
	for key: Dictionary in keys:
		var key_id := str(key.get("id", ""))
		var color := str(key.get("color", ""))
		var pos: Variant = key.get("grid_position")
		if (
			key_id.is_empty()
			or color.is_empty()
			or not pos is Vector2i
			or positions.has(pos)
			or key_ids.has(key_id)
		):
			return {
				"is_valid": false, "error_message": "Mission progression contains duplicate keys"
			}
		if colors.has(color):
			return {
				"is_valid": false,
				"error_message": "Mission progression repeats key color '%s'" % color
			}
		key_ids[key_id] = true
		colors[color] = true
		positions[pos] = true
	var door_positions: Dictionary = {}
	var door_ids: Dictionary = {}
	var objective_ids: Dictionary = {}
	for objective: Dictionary in manifest.objectives:
		var objective_id := str(objective.get("id", ""))
		if objective_id.is_empty() or objective_ids.has(objective_id):
			return {
				"is_valid": false,
				"error_message": "Mission progression contains duplicate objectives"
			}
		objective_ids[objective_id] = true
	for index in range(doors.size()):
		var door: Dictionary = doors[index]
		var pos: Variant = door.get("grid_position")
		var color := str(door.get("color", ""))
		var door_id := str(door.get("id", ""))
		if (
			door_id.is_empty()
			or color.is_empty()
			or not pos is Vector2i
			or door_positions.has(pos)
			or door_ids.has(door_id)
		):
			return {
				"is_valid": false, "error_message": "Mission progression contains duplicate doors"
			}
		if not colors.has(color):
			return {"is_valid": false, "error_message": "Locked door '%s' has no key" % color}
		door_positions[pos] = true
		door_ids[door_id] = true
		if (
			str(door.get("key_id", "")) != "KeyPickup_%d" % index
			or not key_ids.has(door.get("key_id", ""))
		):
			return {
				"is_valid": false, "error_message": "Locked transition has no deterministic key"
			}
		if not objective_ids.has(door_id):
			return {"is_valid": false, "error_message": "Locked transition has no objective"}
		if (
			int(door.get("from_room_id", -1)) not in route
			or int(door.get("to_room_id", -1)) not in route
		):
			return {
				"is_valid": false, "error_message": "Locked transition leaves the recovery route"
			}
		if route.find(int(door.from_room_id)) >= route.find(int(door.to_room_id)):
			return {
				"is_valid": false,
				"error_message": "Locked transition is encountered before its key"
			}
	if check_reachability:
		var lock_result := validate_key_lock_progression(context, keys, doors)
		if not lock_result:
			return {
				"is_valid": false,
				"error_message": "Mission progression is unreachable after lock acquisition"
			}
	return {"is_valid": true, "error_message": ""}


func _rollback_generated_progression(
	context: GenerationContext, keys: Array, locked_doors: Array
) -> void:
	for key: Dictionary in keys:
		var pos: Variant = key.get("grid_position")
		if pos is Vector2i and _is_in_bounds(context, pos):
			var cell: Cell = context.grid[pos.y][pos.x]
			cell.metadata.erase("has_key")
			cell.metadata.erase("key_color")
	for door: Dictionary in locked_doors:
		var pos: Variant = door.get("grid_position")
		if pos is Vector2i and _is_in_bounds(context, pos):
			var cell: Cell = context.grid[pos.y][pos.x]
			cell.metadata.erase("has_locked_door")
			cell.metadata.erase("door_color")
			cell.metadata.erase("blocks_progression")
	context.key_placements.clear()
	context.progression_manifest.clear()
	context.metadata.erase("mission_progression")


## Calculate number of key types based on map complexity
## Small maps: 1 key, Medium: 2 keys, Large: 3 keys
func _calculate_key_count(context: GenerationContext) -> int:
	var map_area: int = context.grid_size.x * context.grid_size.y
	var room_count: int = context.rooms.size()

	# Base on map size and room count
	if map_area >= 256 * 256 or room_count >= 20:
		return 3
	if map_area >= 128 * 128 or room_count >= 10:
		return 2
	return 1


## Analyze room progression from player start
## Returns array of rooms in order of distance from start
func _analyze_room_progression(context: GenerationContext) -> Array[Room]:
	if context.rooms.is_empty():
		return []

	# Find player start room (typically first room or room closest to center)
	var start_room: Room = _find_start_room(context)

	# Build progression order using breadth-first search
	var progression: Array[Room] = []
	var visited: Dictionary = {}
	var queue: Array[Room] = [start_room]
	visited[start_room.id] = true

	while not queue.is_empty():
		var current: Room = queue.pop_front()
		progression.append(current)

		# Add connected rooms to queue
		for connected_id: int in current.connections:
			if not visited.has(connected_id):
				var connected_room := _find_room_by_id(context, connected_id)
				if connected_room:
					queue.append(connected_room)
					visited[connected_id] = true

	if progression.size() < 2:
		for room: Room in context.rooms:
			if room not in progression and not room.cells.is_empty():
				progression.append(room)

	return progression


## Find the starting room (first room or closest to center)
func _find_start_room(context: GenerationContext) -> Room:
	if context.rooms.is_empty():
		return null

	# Use first room as start (typically placed near center)
	return context.rooms[0]


## Find room by ID
func _find_room_by_id(context: GenerationContext, room_id: int) -> Room:
	for room: Room in context.rooms:
		if room.id == room_id:
			return room
	return null


## Place a key-lock pair in progression order
func _place_key_lock_pair(
	context: GenerationContext, progression: Array[Room], key_color: KeyColor, pair_index: int
) -> Dictionary:
	if progression.size() < 2:
		return {}

	# Keep the key before its door, including on maps with only two or three
	# reachable rooms.
	var key_room_idx := mini(pair_index, progression.size() - 2)
	var door_room_idx := mini(key_room_idx + 1, progression.size() - 1)
	var key_room: Room = progression[key_room_idx]
	var door_room: Room = progression[door_room_idx]

	if key_room.cells.is_empty() or door_room.cells.is_empty():
		return {}

	# Commit the key only after its paired door has a valid placement.
	var door_data := _place_locked_door(context, door_room, key_color)
	if door_data.is_empty():
		return {}
	var key_data := _place_key(context, key_room, key_color)

	return {"key": key_data, "door": door_data}


## Place a key in a room
func _place_key(context: GenerationContext, room: Room, key_color: KeyColor) -> Dictionary:
	# Find a good position in the room (not at entrance)
	var key_pos := _find_key_position(room, context.rng)
	var cell: Cell = context.grid[key_pos.y][key_pos.x]

	var key_data := {
		"id": context.key_placements.size(),
		"color": KeyColor.keys()[key_color],
		"position": Vector3(key_pos.x * 2.0 + 1.0, cell.height + 0.5, key_pos.y * 2.0 + 1.0),
		"room_id": room.id,
		"grid_position": key_pos
	}

	# Mark in metadata
	context.key_placements.append(key_data)

	# Mark cell metadata
	cell.metadata["has_key"] = true
	cell.metadata["key_color"] = KeyColor.keys()[key_color]

	return key_data


## Find a suitable position for a key in a room
func _find_key_position(room: Room, rng: RandomNumberGenerator) -> Vector2i:
	if room.cells.is_empty():
		return Vector2i.ZERO

	# Prefer positions away from entrance points
	var candidates: Array[Vector2i] = []

	for cell_pos: Vector2i in room.cells:
		# Skip entrance points
		if cell_pos in room.entrance_points:
			continue
		candidates.append(cell_pos)

	# If no candidates, use any cell
	if candidates.is_empty():
		candidates = room.cells.duplicate()

	# Return random candidate
	return candidates[rng.randi_range(0, candidates.size() - 1)]


## Place a locked door at a room entrance
func _place_locked_door(context: GenerationContext, room: Room, key_color: KeyColor) -> Dictionary:
	# Find a connection point to place the door
	var door_pos := _find_door_position(context, room)

	if door_pos == Vector2i(-1, -1):
		push_warning("Could not find valid door position for room %d" % room.id)
		return {}

	var cell: Cell = context.grid[door_pos.y][door_pos.x]

	var door_data := {
		"id": context.key_placements.size(),
		"color": KeyColor.keys()[key_color],
		"position": Vector3(door_pos.x * 2.0 + 1.0, cell.height, door_pos.y * 2.0 + 1.0),
		"room_id": room.id,
		"grid_position": door_pos,
		"blocks_progression": true
	}

	# Mark cell metadata
	cell.metadata["has_locked_door"] = true
	cell.metadata["door_color"] = KeyColor.keys()[key_color]
	cell.metadata["blocks_progression"] = true

	return door_data


## Find a suitable position for a locked door (at room entrance)
func _find_door_position(context: GenerationContext, room: Room) -> Vector2i:
	# Use entrance points if available
	for entrance: Vector2i in room.entrance_points:
		if not _is_in_bounds(context, entrance):
			continue
		var cell: Cell = context.grid[entrance.y][entrance.x]
		if cell.type != Cell.Type.EMPTY and not cell.metadata.get("has_locked_door", false):
			return entrance

	# Otherwise find a hallway connection
	for cell_pos: Vector2i in room.cells:
		if not _is_in_bounds(context, cell_pos):
			continue
		var cell: Cell = context.grid[cell_pos.y][cell_pos.x]
		if cell.type == Cell.Type.EMPTY or cell.metadata.get("has_locked_door", false):
			continue
		# Check if adjacent to hallway
		var neighbors := [Vector2i(0, -1), Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0)]

		for dir: Vector2i in neighbors:
			var neighbor_pos: Vector2i = cell_pos + dir
			if _is_in_bounds(context, neighbor_pos):
				var neighbor_cell: Cell = context.grid[neighbor_pos.y][neighbor_pos.x]
				if neighbor_cell.type == Cell.Type.HALLWAY:
					return cell_pos

	return Vector2i(-1, -1)


## Check if position is within grid bounds
func _is_in_bounds(context: GenerationContext, pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < context.grid_size.x and pos.y >= 0 and pos.y < context.grid_size.y


## Validate that all locked doors are reachable after key acquisition
func validate_key_lock_progression(
	context: GenerationContext, keys: Array, locked_doors: Array
) -> bool:
	var validation_context := GenerationContext.new()
	validation_context.grid = context.grid
	validation_context.grid_size = context.grid_size
	validation_context.rooms = context.rooms
	validation_context.player_start_position = context.player_start_position
	validation_context.key_placements = keys
	validation_context.metadata["locked_doors"] = locked_doors
	return ValidationSystem.new().validate_key_lock_progression(validation_context).is_valid
