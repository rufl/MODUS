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
	if not _room_graph_is_connected(context):
		push_warning("Mission progression rejected: room graph is disconnected")
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

	var room_ids: Array[int] = []
	var room_edges: Array[Dictionary] = []
	for room: Room in context.rooms:
		room_ids.append(room.id)
		for connected_id: int in room.connections:
			room_edges.append({"from_room_id": room.id, "to_room_id": connected_id})
	room_ids.sort()
	room_edges.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			if a.from_room_id == b.from_room_id:
				return a.to_room_id < b.to_room_id
			return a.from_room_id < b.from_room_id
	)

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
		"room_ids": room_ids,
		"objectives": objectives,
		"keys": manifest_keys,
		"locked_transitions": manifest_doors,
		"recovery_route": room_order,
		"room_edges": room_edges
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
	var room_ids: Dictionary = {}
	var actual_edges: Dictionary = {}
	for room: Room in context.rooms:
		if room_ids.has(room.id):
			return {"is_valid": false, "error_message": "Mission progression has duplicate rooms"}
		room_ids[room.id] = true
	for room: Room in context.rooms:
		for connected_id: Variant in room.connections:
			if not connected_id is int or not room_ids.has(connected_id):
				return {
					"is_valid": false,
					"error_message": "Mission progression references an unknown room edge"
				}
			actual_edges["%d:%d" % [room.id, connected_id]] = true
	if manifest.has("room_ids"):
		if not manifest.room_ids is Array:
			return {
				"is_valid": false,
				"error_message": "Mission progression field 'room_ids' must be an array"
			}
		var declared_room_ids: Dictionary = {}
		for room_id: Variant in manifest.room_ids:
			if not room_id is int or declared_room_ids.has(room_id) or not room_ids.has(room_id):
				return {
					"is_valid": false,
					"error_message": "Mission progression contains an invalid room ID"
				}
			declared_room_ids[room_id] = true
		if declared_room_ids.size() != room_ids.size():
			return {
				"is_valid": false,
				"error_message": "Mission progression room IDs do not match the generated graph"
			}
	var declared_edges := actual_edges
	if manifest.has("room_edges"):
		if not manifest.room_edges is Array:
			return {
				"is_valid": false,
				"error_message": "Mission progression field 'room_edges' must be an array"
			}
		declared_edges = {}
		for edge: Variant in manifest.room_edges:
			if (
				not edge is Dictionary
				or not edge.get("from_room_id") is int
				or not edge.get("to_room_id") is int
			):
				return {
					"is_valid": false,
					"error_message": "Mission progression contains a malformed room edge"
				}
			var edge_key := "%d:%d" % [edge.from_room_id, edge.to_room_id]
			if (
				not room_ids.has(edge.from_room_id)
				or not room_ids.has(edge.to_room_id)
				or declared_edges.has(edge_key)
			):
				return {
					"is_valid": false,
					"error_message": "Mission progression contains an invalid room edge"
				}
			declared_edges[edge_key] = true
		if declared_edges != actual_edges:
			return {
				"is_valid": false,
				"error_message": "Mission progression room edges do not match the generated graph"
			}
	var route: Array = manifest.recovery_route
	if route.is_empty() or manifest.start_room_id != route[0]:
		return {"is_valid": false, "error_message": "Mission progression has no valid start route"}
	var seen_route: Dictionary = {}
	for room_id: Variant in route:
		if not room_id is int or not room_ids.has(room_id) or seen_route.has(room_id):
			return {
				"is_valid": false, "error_message": "Mission progression recovery route is invalid"
			}
		seen_route[room_id] = true
	if manifest.goal_room_id not in seen_route:
		return {
			"is_valid": false,
			"error_message": "Mission progression goal is outside the recovery route"
		}
	for index in range(route.size() - 1):
		if not actual_edges.has("%d:%d" % [route[index], route[index + 1]]):
			return {
				"is_valid": false,
				"error_message": "Mission progression recovery route leaves the room graph"
			}
	var colors: Dictionary = {}
	var positions: Dictionary = {}
	var key_ids: Dictionary = {}
	for key: Variant in manifest.keys:
		if not key is Dictionary:
			return {
				"is_valid": false, "error_message": "Mission progression contains a malformed key"
			}
		var key_id := str(key.get("id", ""))
		var color := str(key.get("color", ""))
		var pos: Variant = key.get("grid_position")
		var key_room_id: Variant = key.get("room_id")
		if (
			key_id.is_empty()
			or color.is_empty()
			or not pos is Vector2i
			or not key_room_id is int
			or not seen_route.has(key_room_id)
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
	for objective: Variant in manifest.objectives:
		if not objective is Dictionary:
			return {
				"is_valid": false,
				"error_message": "Mission progression contains a malformed objective"
			}
		var objective_id := str(objective.get("id", ""))
		if objective_id.is_empty() or objective_ids.has(objective_id):
			return {
				"is_valid": false,
				"error_message": "Mission progression contains duplicate objectives"
			}
		objective_ids[objective_id] = true
	for index in range(manifest.locked_transitions.size()):
		var door: Variant = manifest.locked_transitions[index]
		if not door is Dictionary:
			return {
				"is_valid": false, "error_message": "Mission progression contains a malformed lock"
			}
		var pos: Variant = door.get("grid_position")
		var color := str(door.get("color", ""))
		var door_id := str(door.get("id", ""))
		var from_room_id: Variant = door.get("from_room_id")
		var to_room_id: Variant = door.get("to_room_id")
		if (
			door_id.is_empty()
			or color.is_empty()
			or not pos is Vector2i
			or not from_room_id is int
			or not to_room_id is int
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
			or int(door.get("room_id", -1)) != to_room_id
			or not seen_route.has(from_room_id)
			or not seen_route.has(to_room_id)
			or not actual_edges.has("%d:%d" % [from_room_id, to_room_id])
		):
			return {
				"is_valid": false, "error_message": "Locked transition is not a valid room edge"
			}
		if not objective_ids.has(door_id):
			return {"is_valid": false, "error_message": "Locked transition has no objective"}
		if route.find(from_room_id) >= route.find(to_room_id):
			return {
				"is_valid": false,
				"error_message": "Locked transition is encountered before its key"
			}
	if check_reachability:
		var lock_result := validate_key_lock_progression(
			context, manifest.keys, manifest.locked_transitions
		)
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


## Analyze a deterministic, connected recovery route from the start room.
## Prefer the room containing the configured extraction, otherwise use the
## farthest reachable room. Every returned consecutive pair is a real edge.
func _analyze_room_progression(context: GenerationContext) -> Array[Room]:
	if context.rooms.is_empty():
		return []

	var start_room: Room = _find_start_room(context)
	if not start_room:
		return []
	var goal_room := _find_goal_room(context)
	if goal_room and goal_room.id != start_room.id:
		var goal_path := _find_room_path(context, start_room.id, goal_room.id)
		if not goal_path.is_empty():
			return goal_path
	return _find_room_path(context, start_room.id, -1)


## Find the room containing the configured extraction position.
func _find_goal_room(context: GenerationContext) -> Room:
	var exit := context.exit_position
	if (
		exit.x < 0
		or exit.y < 0
		or exit.y >= context.grid.size()
		or exit.x >= context.grid[exit.y].size()
	):
		return null
	var room_id: int = context.grid[exit.y][exit.x].room_id
	return _find_room_by_id(context, room_id) if room_id >= 0 else null


## Find a shortest deterministic room path, or the farthest path when target=-1.
func _find_room_path(
	context: GenerationContext, start_room_id: int, target_room_id: int
) -> Array[Room]:
	var parents: Dictionary = {start_room_id: -1}
	var distances: Dictionary = {start_room_id: 0}
	var queue: Array[int] = [start_room_id]
	var farthest_room_id := start_room_id
	while not queue.is_empty():
		var room_id: int = queue.pop_front()
		var room_distance: int = int(distances[room_id])
		if (
			room_distance > int(distances[farthest_room_id])
			or (room_distance == int(distances[farthest_room_id]) and room_id < farthest_room_id)
		):
			farthest_room_id = room_id
		if room_id == target_room_id:
			break
		var room := _find_room_by_id(context, room_id)
		if not room:
			continue
		var neighbors: Array = room.connections.duplicate()
		neighbors.sort()
		for connected_id: Variant in neighbors:
			if not connected_id is int or parents.has(connected_id):
				continue
			parents[connected_id] = room_id
			distances[connected_id] = room_distance + 1
			queue.append(connected_id)

	if target_room_id >= 0:
		if not parents.has(target_room_id):
			return []
		farthest_room_id = target_room_id
	var room_path: Array[Room] = []
	var path_ids: Array[int] = []
	var current_id := farthest_room_id
	while current_id >= 0:
		path_ids.push_front(current_id)
		current_id = int(parents.get(current_id, -1))
	for room_id: int in path_ids:
		var room := _find_room_by_id(context, room_id)
		if not room:
			return []
		room_path.append(room)
	return room_path


## Find the starting room from the configured player start cell.
func _find_start_room(context: GenerationContext) -> Room:
	if context.rooms.is_empty():
		return null
	var start := context.player_start_position
	if (
		start.x >= 0
		and start.y >= 0
		and start.y < context.grid.size()
		and start.x < context.grid[start.y].size()
	):
		var room_id: int = context.grid[start.y][start.x].room_id
		var room := _find_room_by_id(context, room_id)
		if room:
			return room
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


func _room_graph_is_connected(context: GenerationContext) -> bool:
	if context.rooms.is_empty():
		return false
	var rooms_by_id: Dictionary = {}
	for room: Room in context.rooms:
		if rooms_by_id.has(room.id):
			return false
		rooms_by_id[room.id] = room
	for room: Room in context.rooms:
		for connected_id: Variant in room.connections:
			if not connected_id is int or not rooms_by_id.has(connected_id):
				return false
	var visited: Dictionary = {}
	var queue: Array[int] = [context.rooms[0].id]
	while not queue.is_empty():
		var room_id: int = queue.pop_front()
		if visited.has(room_id):
			continue
		visited[room_id] = true
		var room: Room = rooms_by_id[room_id]
		for connected_id: int in room.connections:
			if not visited.has(connected_id):
				queue.append(connected_id)
	return visited.size() == rooms_by_id.size()


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
