extends RefCounted
class_name ValidationSystem

## ValidationSystem
## Provides validation methods for each generation phase
## Validates connectivity, navigation mesh coverage, spawn points, and progression order

const Cell = preload("res://game/scripts/map_generator/cell.gd")
const Room = preload("res://game/scripts/map_generator/room.gd")


## Validation result structure
class ValidationResult:
	var is_valid: bool = false
	var error_message: String = ""
	var warnings: Array[String] = []

	func _init(valid: bool = false, error: String = "") -> void:
		is_valid = valid
		error_message = error


## Validate grid layout phase output
func validate_grid_layout(context: RefCounted) -> ValidationResult:
	var result := ValidationResult.new()

	if not context.grid or context.grid.is_empty():
		result.error_message = "Grid is empty or null"
		return result

	# Check grid dimensions match configuration
	var expected_height: int = context.config.map_size.y
	var expected_width: int = context.config.map_size.x

	if context.grid.size() != expected_height:
		result.error_message = (
			"Grid height mismatch: expected %d, got %d" % [expected_height, context.grid.size()]
		)
		return result

	for row_data: Variant in context.grid:
		var row: Array = row_data as Array
		if not row:
			result.error_message = "Grid contains invalid row"
			return result

		if row.size() != expected_width:
			result.error_message = (
				"Grid width mismatch: expected %d, got %d" % [expected_width, row.size()]
			)
			return result

	result.is_valid = true
	return result


## Validate room generation phase output
func validate_room_generation(context: RefCounted) -> ValidationResult:
	var result := ValidationResult.new()

	if not context.rooms or context.rooms.is_empty():
		result.error_message = "No rooms generated"
		return result

	# Validate each room
	for room_variant: Variant in context.rooms:
		var typed_room: Room = room_variant as Room
		if not typed_room:
			continue

		if typed_room.cells.is_empty():
			result.error_message = "Room %d has no cells" % typed_room.id
			return result

		if typed_room.entrance_points.is_empty():
			result.warnings.append("Room %d has no entrance points" % typed_room.id)

	result.is_valid = true
	return result


## Every non-secret walkable cell and every room entrance must be reachable.
func validate_connectivity(context: RefCounted) -> ValidationResult:
	var start := _find_player_start_position(context)
	if not _is_valid_grid_position(context.grid, start):
		return ValidationResult.new(false, "No valid player start position found")
	var reachable := _flood_fill_cells(context.grid, start)
	for y in range(context.grid.size()):
		for x in range(context.grid[y].size()):
			var cell: Cell = context.grid[y][x]
			if _is_walkable_cell(cell) and cell.type != Cell.Type.SECRET:
				if not reachable.has(Vector2i(x, y)):
					return ValidationResult.new(
						false, "Disconnected walkable cell at %s" % Vector2i(x, y)
					)
	for room: Room in context.rooms:
		if room.cells.is_empty():
			return ValidationResult.new(false, "Room %d has no cells" % room.id)
		for pos: Vector2i in room.cells + room.entrance_points:
			if not reachable.has(pos):
				return ValidationResult.new(false, "Room %d is disconnected at %s" % [room.id, pos])
	return ValidationResult.new(true)


## Prove paths on this mesh only; never query a scene's default navigation map.
func validate_navigation_mesh(context: RefCounted) -> ValidationResult:
	var points: Array[Vector3] = []
	var error := _collect_navigation_points(context, points)
	if not error.is_empty():
		return ValidationResult.new(false, error)
	return _validate_navigation_points(context, points)


func validate_monster_spawns(context: RefCounted) -> ValidationResult:
	if context.monster_spawns.is_empty():
		return ValidationResult.new(true)
	var points: Array[Vector3] = []
	for spawn: Variant in context.monster_spawns:
		var error := _append_spawn_point(context, spawn, points)
		if not error.is_empty():
			return ValidationResult.new(false, error)
	return _validate_navigation_points(context, points)


func _grid_world_position(context: RefCounted, pos: Vector2i) -> Vector3:
	var cell: Cell = context.grid[pos.y][pos.x]
	return Vector3(pos.x * 2.0 + 1.0, cell.height, pos.y * 2.0 + 1.0)


func _append_spawn_point(context: RefCounted, spawn: Variant, points: Array[Vector3]) -> String:
	if not spawn is Dictionary:
		return "Malformed monster spawn"
	var position: Variant = spawn.get("position")
	if position is Vector2i:
		if not _is_valid_grid_position(context.grid, position):
			return "Monster spawn is outside walkable grid"
		points.append(_grid_world_position(context, position))
		# Grid and world coordinates are both part of the placer contract.
		if spawn.has("world_position"):
			var world_position: Variant = spawn["world_position"]
			if not world_position is Vector3 or not world_position.is_finite():
				return "Malformed monster world position"
			points.append(world_position)
	elif position is Vector3 and position.is_finite():
		points.append(position)
	else:
		return "Monster spawn requires a valid position"
	return ""


func _collect_navigation_points(context: RefCounted, points: Array[Vector3]) -> String:
	for room: Room in context.rooms:
		if room.cells.is_empty():
			return "Room %d has no cells" % room.id
		# Organic room centers can be holes. Use the nearest actual room cell.
		var representative := Vector2i(-1, -1)
		var distance := INF
		for pos: Vector2i in room.cells:
			if _is_valid_grid_position(context.grid, pos):
				var candidate_distance := Vector2(pos).distance_squared_to(Vector2(room.center))
				if candidate_distance < distance:
					distance = candidate_distance
					representative = pos
		if representative == Vector2i(-1, -1):
			return "Room %d has no walkable cells" % room.id
		points.append(_grid_world_position(context, representative))
		for entrance: Vector2i in room.entrance_points:
			if not _is_valid_grid_position(context.grid, entrance):
				return "Room %d has an invalid entrance" % room.id
			points.append(_grid_world_position(context, entrance))
	var progression := _collect_progression(context)
	if not progression.error.is_empty():
		return progression.error
	for key: Dictionary in progression.keys:
		points.append(_grid_world_position(context, key.grid_position))
	for door_pos: Vector2i in progression.doors:
		points.append(_grid_world_position(context, door_pos))
	for records: Array in [context.key_placements, context.metadata.get("locked_doors", [])]:
		for record: Dictionary in records:
			if record.has("position"):
				var position: Variant = record.position
				if not position is Vector3 or not position.is_finite():
					return "Malformed key or door world position"
				points.append(position)
	for spawn: Variant in context.monster_spawns:
		var error := _append_spawn_point(context, spawn, points)
		if not error.is_empty():
			return error
	return ""


func _validate_navigation_points(context: RefCounted, points: Array[Vector3]) -> ValidationResult:
	if not is_instance_valid(context.navigation_region):
		return ValidationResult.new(false, "Navigation region is null")
	var region: NavigationRegion3D = context.navigation_region
	var mesh := region.navigation_mesh
	if mesh == null or mesh.get_polygon_count() == 0:
		return ValidationResult.new(false, "Navigation mesh has no polygons")
	var start := _find_player_start_position(context)
	if not _is_valid_grid_position(context.grid, start):
		return ValidationResult.new(false, "No valid player start position found")
	var map_rid := NavigationServer3D.map_create()
	var region_rid := NavigationServer3D.region_create()
	# force_update is synchronous only when both private objects disable async work.
	NavigationServer3D.map_set_use_async_iterations(map_rid, false)
	NavigationServer3D.region_set_use_async_iterations(region_rid, false)
	NavigationServer3D.map_set_cell_size(map_rid, mesh.cell_size)
	NavigationServer3D.map_set_cell_height(map_rid, mesh.cell_height)
	NavigationServer3D.map_set_use_edge_connections(map_rid, false)
	NavigationServer3D.region_set_navigation_mesh(region_rid, mesh)
	var region_transform := region.transform
	if region.is_inside_tree():
		region_transform = region.global_transform
	NavigationServer3D.region_set_transform(region_rid, region_transform)
	NavigationServer3D.region_set_map(region_rid, map_rid)
	NavigationServer3D.map_force_update(map_rid)
	var result := _query_required_paths(map_rid, mesh, _grid_world_position(context, start), points)
	NavigationServer3D.free_rid(region_rid)
	NavigationServer3D.free_rid(map_rid)
	return result


func _query_required_paths(
	map_rid: RID, mesh: NavigationMesh, start: Vector3, points: Array[Vector3]
) -> ValidationResult:
	# Voxelization lifts the surface slightly; pickups may sit 0.5m above it.
	# Horizontal proximity is tighter so projecting across a wall cannot pass.
	var horizontal_tolerance := maxf(mesh.cell_size * 2.0, mesh.agent_radius)
	var vertical_tolerance := maxf(mesh.cell_height * 2.0, 0.75)
	var projected_start := NavigationServer3D.map_get_closest_point(map_rid, start)
	if not _point_on_surface(
		map_rid, start, projected_start, horizontal_tolerance, vertical_tolerance
	):
		return ValidationResult.new(false, "Player start is outside the navigation mesh")
	for target: Vector3 in points:
		var projected := NavigationServer3D.map_get_closest_point(map_rid, target)
		if not _point_on_surface(
			map_rid, target, projected, horizontal_tolerance, vertical_tolerance
		):
			return ValidationResult.new(
				false, "Required position %s is outside the navigation mesh" % target
			)
		var path := NavigationServer3D.map_get_path(map_rid, projected_start, projected, true)
		if (
			path.is_empty()
			or path[0].distance_to(projected_start) > 0.01
			or path[-1].distance_to(projected) > 0.01
		):
			return ValidationResult.new(false, "No complete navigation path to %s" % target)
	return ValidationResult.new(true)


func _point_on_surface(
	map_rid: RID, point: Vector3, projected: Vector3, horizontal: float, vertical: float
) -> bool:
	return (
		point.is_finite()
		and NavigationServer3D.map_get_closest_point_owner(map_rid, point).is_valid()
		and Vector2(point.x, point.z).distance_to(Vector2(projected.x, projected.z)) <= horizontal
		and absf(point.y - projected.y) <= vertical
	)


## Solve all locks together; a key never opens its own gate speculatively.
func validate_key_lock_progression(context: RefCounted) -> ValidationResult:
	var progression := _collect_progression(context)
	if not progression.error.is_empty():
		return ValidationResult.new(false, progression.error)
	var keys: Array = progression.keys
	var doors: Dictionary = progression.doors
	if keys.is_empty() and doors.is_empty():
		return ValidationResult.new(true)
	var colors: Dictionary = {}
	for key: Dictionary in keys:
		colors[key.color] = true
	for color: String in doors.values():
		if not colors.has(color):
			return ValidationResult.new(false, "Locked door '%s' has no corresponding key" % color)
	var start := _find_player_start_position(context)
	if not _is_valid_grid_position(context.grid, start):
		return ValidationResult.new(false, "Cannot validate progression without a player start")
	var acquired: Dictionary = {}
	var reachable: Dictionary = {}
	while true:
		var blocked: Dictionary = {}
		for pos: Vector2i in doors:
			if not acquired.has(doors[pos]):
				blocked[pos] = true
		reachable = _flood_fill_cells(context.grid, start, blocked)
		var changed := false
		for key: Dictionary in keys:
			if reachable.has(key.grid_position) and not acquired.has(key.color):
				acquired[key.color] = true
				changed = true
		if not changed:
			break
	for key: Dictionary in keys:
		if not reachable.has(key.grid_position):
			return ValidationResult.new(
				false, "Key '%s' is unreachable in locked progression" % key.color
			)
	for pos: Vector2i in doors:
		if not reachable.has(pos):
			return ValidationResult.new(
				false, "Locked door '%s' is unreachable after key acquisition" % doors[pos]
			)
	return ValidationResult.new(true)


## Merge explicit and grid records, rejecting malformed or conflicting locks.
func _collect_progression(context: RefCounted) -> Dictionary:
	var data := {"keys": [], "key_colors": {}, "doors": {}, "error": ""}
	for record: Variant in context.key_placements:
		data.error = _add_progression_record(context.grid, record, false, data)
		if not data.error.is_empty():
			return data
	var explicit_doors: Variant = context.metadata.get("locked_doors", [])
	if not explicit_doors is Array:
		data.error = "Locked door records must be an array"
		return data
	for record: Variant in explicit_doors:
		data.error = _add_progression_record(context.grid, record, true, data)
		if not data.error.is_empty():
			return data
	for y in range(context.grid.size()):
		for x in range(context.grid[y].size()):
			var cell: Cell = context.grid[y][x]
			var pos := Vector2i(x, y)
			if cell.metadata.get("has_key", false):
				if (
					not data.key_colors.has(pos)
					or data.key_colors[pos] != cell.metadata.get("key_color")
				):
					data.error = "Grid key marker has no matching retained key at %s" % pos
					return data
			if cell.metadata.get("has_locked_door", false):
				var record := {"color": cell.metadata.get("door_color"), "grid_position": pos}
				data.error = _add_progression_record(context.grid, record, true, data)
				if not data.error.is_empty():
					return data
	return data


func _add_progression_record(
	grid: Array, record: Variant, is_door: bool, data: Dictionary
) -> String:
	if not record is Dictionary:
		return "Malformed key or locked door record"
	var color: Variant = record.get("color")
	var pos: Variant = record.get("grid_position")
	if not color is String or color.strip_edges().is_empty() or not pos is Vector2i:
		return "Key or locked door requires a color and grid position"
	if not _is_valid_grid_position(grid, pos):
		return "Key or locked door is outside the walkable grid"
	if (
		record.has("position")
		and (not record.position is Vector3 or not record.position.is_finite())
	):
		return "Malformed key or door world position"
	if is_door or record.get("is_door", false):
		if data.doors.has(pos) and data.doors[pos] != color:
			return "Conflicting locked door colors at %s" % pos
		data.doors[pos] = color
	else:
		if data.key_colors.has(pos) and data.key_colors[pos] != color:
			return "Conflicting key colors at %s" % pos
		data.key_colors[pos] = color
		data.keys.append({"color": color, "grid_position": pos})
	return ""


## Validate player start position is accessible
func validate_player_start(context: RefCounted) -> ValidationResult:
	var result := ValidationResult.new()

	var player_start := _find_player_start_position(context)
	if player_start == Vector2i(-1, -1):
		result.error_message = "No valid player start position found"
		return result

	# Check if player start is on a walkable cell
	if player_start.y < 0 or player_start.y >= context.grid.size():
		result.error_message = "Player start position out of bounds (Y)"
		return result

	if player_start.x < 0 or player_start.x >= context.grid[0].size():
		result.error_message = "Player start position out of bounds (X)"
		return result

	var cell: Cell = context.grid[player_start.y][player_start.x]
	if not _is_walkable_cell(cell):
		result.error_message = "Player start position is not on a walkable cell"
		return result

	result.is_valid = true
	return result


## Find player start position in the grid
func _find_player_start_position(context: RefCounted) -> Vector2i:
	# Look for player start marker in context
	if context.has("player_start_position") and context.player_start_position != Vector2i(-1, -1):
		return context.player_start_position

	# Fallback: find first room's center
	if context.rooms and not context.rooms.is_empty():
		var first_room: Room = context.rooms[0]
		if (
			first_room.center.y >= 0
			and first_room.center.y < context.grid.size()
			and first_room.center.x >= 0
			and first_room.center.x < context.grid[first_room.center.y].size()
			and _is_walkable_cell(context.grid[first_room.center.y][first_room.center.x])
		):
			return first_room.center
		for room_cell: Vector2i in first_room.cells:
			if (
				room_cell.y >= 0
				and room_cell.y < context.grid.size()
				and room_cell.x >= 0
				and room_cell.x < context.grid[room_cell.y].size()
				and _is_walkable_cell(context.grid[room_cell.y][room_cell.x])
			):
				return room_cell

	# Last resort: find first walkable cell
	for y in range(context.grid.size()):
		for x in range(context.grid[y].size()):
			var cell: Cell = context.grid[y][x]
			if _is_walkable_cell(cell):
				return Vector2i(x, y)

	return Vector2i(-1, -1)


## Count walkable cells in grid
func _count_walkable_cells(grid: Array) -> int:
	var count := 0
	for row_data: Variant in grid:
		var row: Array = row_data as Array
		if not row:
			continue
		for cell_data: Variant in row:
			var cell: Cell = cell_data as Cell
			if cell and _is_walkable_cell(cell):
				count += 1
	return count


## Check if cell is walkable
func _is_walkable_cell(cell: Cell) -> bool:
	if cell == null:
		return false
	return (
		cell.type
		in [
			Cell.Type.ROOM,
			Cell.Type.HALLWAY,
			Cell.Type.OUTDOOR,
			Cell.Type.CAVE,
			Cell.Type.BOSS_ARENA,
			Cell.Type.SECRET
		]
	)


## Check whether a grid position exists and is walkable.
func _is_valid_grid_position(grid: Array, position: Vector2i) -> bool:
	if position.y < 0 or position.y >= grid.size():
		return false
	var row: Array = grid[position.y] as Array
	if not row or position.x < 0 or position.x >= row.size():
		return false
	return _is_walkable_cell(row[position.x] as Cell)


## Flood fill while treating selected cells as progression blockers.
func _flood_fill_reaches(
	grid: Array, start: Vector2i, target: Vector2i, blocked: Dictionary = {}
) -> bool:
	return _flood_fill_cells(grid, start, blocked).has(target)


func _flood_fill_count(grid: Array, start: Vector2i) -> int:
	return _flood_fill_cells(grid, start).size()


func _flood_fill_cells(grid: Array, start: Vector2i, blocked: Dictionary = {}) -> Dictionary:
	var visited: Dictionary = {}
	if blocked.has(start) or not _is_valid_grid_position(grid, start):
		return visited
	var queue: Array[Vector2i] = [start]
	visited[start] = true
	var index := 0
	while index < queue.size():
		var current := queue[index]
		index += 1
		for offset: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
			var neighbor := current + offset
			if visited.has(neighbor) or blocked.has(neighbor):
				continue
			if _is_valid_grid_position(grid, neighbor):
				visited[neighbor] = true
				queue.append(neighbor)
	return visited
