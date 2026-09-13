class_name HallwayGenerator
extends RefCounted

## Generates hallways connecting rooms using A* pathfinding
## Implements dead-end removal and junction detection
## Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6

# Global classes Cell, Room, and Hallway are already defined via class_name


## Find a path between two points using A* pathfinding with Manhattan distance heuristic
## Returns array of Vector2i positions forming the path, or empty array if no path found
## Requirement 3.2: Use A* pathfinding to determine hallway routes between rooms
func find_hallway_path(start: Vector2i, goal: Vector2i, grid: Array[Array]) -> Array[Vector2i]:
	var open_set: Array[Vector2i] = [start]
	var came_from: Dictionary = {}
	var g_score: Dictionary = {start: 0}
	var f_score: Dictionary = {start: _heuristic(start, goal)}

	while not open_set.is_empty():
		var current := _get_lowest_f_score(open_set, f_score)

		if current == goal:
			return _reconstruct_path(came_from, current)

		open_set.erase(current)

		for neighbor in _get_neighbors(current, grid, start, goal):
			var tentative_g_score: int = g_score[current] + 1

			if tentative_g_score < g_score.get(neighbor, INF):
				came_from[neighbor] = current
				g_score[neighbor] = tentative_g_score
				f_score[neighbor] = tentative_g_score + _heuristic(neighbor, goal)

				if neighbor not in open_set:
					open_set.append(neighbor)

	return []  # No path found


## Manhattan distance heuristic for A* pathfinding
func _heuristic(a: Vector2i, b: Vector2i) -> float:
	return abs(a.x - b.x) + abs(a.y - b.y)


## Get the node with the lowest f_score from the open set
func _get_lowest_f_score(open_set: Array[Vector2i], f_score: Dictionary) -> Vector2i:
	var lowest := open_set[0]
	var lowest_score: float = f_score.get(lowest, INF)

	for node in open_set:
		var score: float = f_score.get(node, INF)
		if score < lowest_score:
			lowest = node
			lowest_score = score

	return lowest


## Reconstruct the path from the came_from dictionary
func _reconstruct_path(came_from: Dictionary, current: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = [current]

	while came_from.has(current):
		current = came_from[current]
		path.push_front(current)

	return path


## Get valid neighbors for pathfinding (4-directional)
## A neighbor is valid if it's within bounds and not a solid obstacle
func _get_neighbors(
	pos: Vector2i, grid: Array[Array], start: Vector2i, goal: Vector2i
) -> Array[Vector2i]:
	var neighbors: Array[Vector2i] = []
	# North, South, East, West
	var directions := [Vector2i(0, -1), Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0)]

	for dir: Vector2i in directions:
		var neighbor_pos: Vector2i = pos + dir

		# Check bounds
		if neighbor_pos.y < 0 or neighbor_pos.y >= grid.size():
			continue
		if neighbor_pos.x < 0 or neighbor_pos.x >= grid[0].size():
			continue

		var cell: Cell = grid[neighbor_pos.y][neighbor_pos.x]

		# Allow pathfinding through empty cells and existing hallways
		# Also allow pathfinding to room cells (for connection points)
		var is_walkable := (
			cell.type == Cell.Type.EMPTY
			or cell.type == Cell.Type.HALLWAY
			or (
				cell.type in [Cell.Type.ROOM, Cell.Type.BOSS_ARENA]
				and (neighbor_pos == start or neighbor_pos == goal)
			)
		)
		if is_walkable:
			neighbors.append(neighbor_pos)

	return neighbors


## Generate hallways connecting adjacent rooms
## Requirement 3.1: Generate hallways connecting adjacent rooms
## Requirement 3.4: Ensure hallway width is at least 2 cells
## Requirement 3.5: Create junction cells at hallway intersections
## Requirement 3.6: Hallways connect exactly two rooms or one room and a junction
func generate_hallways(rooms: Array[Room], grid: Array[Array]) -> Array[Hallway]:
	var hallways: Array[Hallway] = []
	var components: Dictionary = {}
	var edges: Array[Dictionary] = []
	for room in rooms:
		components[room.id] = room.id
		room.connections.clear()
		room.entrance_points.clear()

	for i in range(rooms.size()):
		for j in range(i + 1, rooms.size()):
			var points := _find_best_connection_points(rooms[i], rooms[j])
			if not points.is_empty():
				edges.append(
					{
						"a": rooms[i],
						"b": rooms[j],
						"points": points,
						"distance": _manhattan_distance(points[0], points[1])
					}
				)
	edges.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			if a["distance"] != b["distance"]:
				return a["distance"] < b["distance"]
			if a["a"].id != b["a"].id:
				return a["a"].id < b["a"].id
			return a["b"].id < b["b"].id
	)

	# Connect components, not merely rooms with no edges. Two connected pairs
	# still need a bridge, including when their distance exceeds 64 cells.
	for edge in edges:
		var room_a: Room = edge["a"]
		var room_b: Room = edge["b"]
		if components[room_a.id] == components[room_b.id]:
			continue
		var points: Array[Vector2i] = edge["points"]
		var path := find_hallway_path(points[0], points[1], grid)
		if path.is_empty():
			continue
		var hallway := Hallway.new(hallways.size(), room_a.id, room_b.id)
		hallway.path = path
		hallway.width = 2
		_apply_hallway_to_grid(hallway, grid)
		room_a.connections.append(room_b.id)
		room_b.connections.append(room_a.id)
		room_a.entrance_points.append(points[0])
		room_b.entrance_points.append(points[1])
		hallways.append(hallway)

		var old_component: int = components[room_b.id]
		var merged_component: int = components[room_a.id]
		for room_id: int in components:
			if components[room_id] == old_component:
				components[room_id] = merged_component
		if hallways.size() == rooms.size() - 1:
			break

	_detect_and_mark_junctions(hallways, grid)
	return hallways


## Keep a connected organic footprint and join it to existing playable geometry.
## Disconnected CA noise is removed before rooms, spawns or secrets refer to it.
func connect_generated_area(
	context: GenerationContext, region: Rect2i, cell_type: Cell.Type
) -> void:
	var grid := context.grid
	var remaining: Dictionary = {}
	for y in range(region.position.y, region.end.y):
		for x in range(region.position.x, region.end.x):
			if _is_valid_grid_pos(Vector2i(x, y), grid) and grid[y][x].type == cell_type:
				remaining[Vector2i(x, y)] = true
	var components: Array[Array] = []
	var largest: Array[Vector2i] = []
	const DIRECTIONS := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
	while not remaining.is_empty():
		var component: Array[Vector2i] = [remaining.keys()[0]]
		remaining.erase(component[0])
		var index := 0
		while index < component.size():
			var point := component[index]
			index += 1
			for direction: Vector2i in DIRECTIONS:
				var next := point + direction
				if remaining.has(next):
					remaining.erase(next)
					component.append(next)
		components.append(component)
		if component.size() > largest.size():
			largest = component
	for component in components:
		if component != largest:
			for point: Vector2i in component:
				grid[point.y][point.x].type = Cell.Type.EMPTY

	# Multi-source BFS finds the shortest bridge without an all-cell pair scan.
	var pending: Array[Vector2i] = largest.duplicate()
	var visited: Dictionary = {}
	var came_from: Dictionary = {}
	for point in largest:
		visited[point] = true
	var index := 0
	while index < pending.size():
		var point := pending[index]
		index += 1
		for direction: Vector2i in DIRECTIONS:
			var next := point + direction
			if not _is_valid_grid_pos(next, grid) or visited.has(next):
				continue
			visited[next] = true
			came_from[next] = point
			if grid[next.y][next.x].type != Cell.Type.EMPTY:
				var hallway := Hallway.new(
					context.hallways.size(), -1, grid[next.y][next.x].room_id
				)
				hallway.path = _reconstruct_path(came_from, next)
				hallway.width = 2
				_apply_hallway_to_grid(hallway, grid)
				context.hallways.append(hallway)
				return
			pending.append(next)


## Find the best connection points between two rooms
## Returns array with [start_pos, end_pos] or empty array if no valid connection
func _find_best_connection_points(room_a: Room, room_b: Room) -> Array[Vector2i]:
	var best_distance := INF
	var best_start := Vector2i.ZERO
	var best_end := Vector2i.ZERO

	# Find closest cells between the two rooms
	for cell_a in room_a.cells:
		for cell_b in room_b.cells:
			var dist := _manhattan_distance(cell_a, cell_b)
			if dist < best_distance:
				best_distance = dist
				best_start = cell_a
				best_end = cell_b

	if best_distance == INF:
		return []

	var result: Array[Vector2i] = [best_start, best_end]
	return result


## Apply hallway to grid with specified width
## Requirement 3.4: Ensure hallway width is at least 2 cells
func _apply_hallway_to_grid(hallway: Hallway, grid: Array[Array]) -> void:
	for pos in hallway.path:
		# Set center cell
		if _is_valid_grid_pos(pos, grid):
			var cell: Cell = grid[pos.y][pos.x]
			if cell.type == Cell.Type.EMPTY:
				cell.type = Cell.Type.HALLWAY

		# Add width by setting adjacent cells (perpendicular to path direction)
		if hallway.width >= 2:
			# Determine path direction at this point
			var idx := hallway.path.find(pos)
			var direction := Vector2i.ZERO

			if idx > 0:
				direction = pos - hallway.path[idx - 1]
			elif idx < hallway.path.size() - 1:
				direction = hallway.path[idx + 1] - pos

			# Get perpendicular directions
			var perpendicular := Vector2i(-direction.y, direction.x)

			# Apply width
			for w in range(1, hallway.width):
				var offset_pos := pos + perpendicular * w
				if _is_valid_grid_pos(offset_pos, grid):
					var cell: Cell = grid[offset_pos.y][offset_pos.x]
					if cell.type == Cell.Type.EMPTY:
						cell.type = Cell.Type.HALLWAY


## Detect hallway intersections and mark junction cells
## Requirement 3.5: Create junction cells at hallway intersections
func _detect_and_mark_junctions(hallways: Array[Hallway], grid: Array[Array]) -> void:
	# Build a map of positions to hallway IDs
	var position_map: Dictionary = {}  # Vector2i -> Array[int] (hallway IDs)

	for hallway in hallways:
		for pos in hallway.path:
			if not position_map.has(pos):
				position_map[pos] = []
			position_map[pos].append(hallway.id)

	# Find intersections (positions used by multiple hallways)
	for pos: Vector2i in position_map.keys():
		var hallway_ids: Array = position_map[pos]
		if hallway_ids.size() > 1:
			# This is a junction - mark it in the grid
			if _is_valid_grid_pos(pos, grid):
				var _cell: Cell = grid[pos.y][pos.x]
				# Mark as junction (we can use metadata or a special flag)
				# For now, we keep it as HALLWAY type but could add junction metadata


## Check if a grid position is valid
func _is_valid_grid_pos(pos: Vector2i, grid: Array[Array]) -> bool:
	return pos.y >= 0 and pos.y < grid.size() and pos.x >= 0 and pos.x < grid[0].size()


## Calculate Manhattan distance between two points
func _manhattan_distance(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)


## Remove dead-end hallway segments
## Requirement 3.3: Detect and remove dead-end segments
## A dead-end is a hallway cell with only one open neighbor
## Iteratively removes dead-ends until none remain
func remove_dead_ends(grid: Array[Array]) -> void:
	var changed := true
	var iteration := 0
	var max_iterations := 100  # Safety limit to prevent infinite loops

	while changed and iteration < max_iterations:
		changed = false
		iteration += 1

		# Scan grid for dead-end hallway cells
		for y in range(1, grid.size() - 1):
			for x in range(1, grid[y].size() - 1):
				var cell: Cell = grid[y][x]

				# Only process hallway cells
				if cell.type != Cell.Type.HALLWAY:
					continue

				# Count open neighbors (walkable cells)
				var open_neighbors := _count_open_neighbors(Vector2i(x, y), grid)

				# If only one open neighbor, this is a dead end
				if open_neighbors == 1:
					cell.type = Cell.Type.EMPTY
					changed = true


## Count open (walkable) neighbors for a position
## Used for dead-end detection
func _count_open_neighbors(pos: Vector2i, grid: Array[Array]) -> int:
	var count := 0
	# North, South, East, West
	var directions := [Vector2i(0, -1), Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0)]

	for dir: Vector2i in directions:
		var neighbor_pos: Vector2i = pos + dir

		if not _is_valid_grid_pos(neighbor_pos, grid):
			continue

		var neighbor_cell: Cell = grid[neighbor_pos.y][neighbor_pos.x]

		# Count as open if it's a walkable cell type
		if _is_walkable_cell(neighbor_cell):
			count += 1

	return count


## Check if a cell is walkable
func _is_walkable_cell(cell: Cell) -> bool:
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
