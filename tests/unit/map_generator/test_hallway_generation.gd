extends ModusGutTestBase

var grid: Array[Array]


func before_each() -> void:
	grid = []
	for y in range(32):
		var row: Array = []
		for x in range(128):
			row.append(Cell.new(Cell.Type.EMPTY))
		grid.append(row)


func test_separate_connected_pairs_receive_a_walkable_bridge() -> void:
	var rooms: Array[Room] = []
	for x in [5, 10, 90, 95]:
		rooms.append(_room(rooms.size(), Vector2i(x, 10), Cell.Type.ROOM))
	HallwayGenerator.new().generate_hallways(rooms, grid)
	var reached := _reachable(rooms[0].center)
	for room in rooms:
		assert_true(reached.has(room.center), "Every room needs a real grid route from start")


func test_boss_room_connection_has_two_cell_wide_floor() -> void:
	var rooms: Array[Room] = [
		_room(0, Vector2i(5, 10), Cell.Type.ROOM), _room(1, Vector2i(15, 10), Cell.Type.BOSS_ARENA)
	]
	HallwayGenerator.new().generate_hallways(rooms, grid)
	assert_true(_reachable(rooms[0].center).has(rooms[1].center))
	for x in range(6, 15):
		assert_ne(grid[10][x].type, Cell.Type.EMPTY, "Hallway center must be walkable")
		assert_ne(grid[11][x].type, Cell.Type.EMPTY, "Hallway width must exist in the grid")


func test_generated_cave_joins_existing_playable_floor() -> void:
	var context := GenerationContext.new()
	context.grid = grid
	context.grid_size = Vector2i(128, 32)
	var start := _room(0, Vector2i(5, 10), Cell.Type.ROOM)
	var region := Rect2i(80, 5, 10, 10)
	context.rng.seed = 12345
	CellularAutomataEngine.new().generate_area(region, grid, context.rng, Cell.Type.CAVE)
	HallwayGenerator.new().connect_generated_area(context, region, Cell.Type.CAVE)
	var reached := _reachable(start.center)
	var cave_count := 0
	for y in range(region.position.y, region.end.y):
		for x in range(region.position.x, region.end.x):
			if grid[y][x].type == Cell.Type.CAVE:
				cave_count += 1
				assert_true(reached.has(Vector2i(x, y)), "Retained cave floor needs a route")
	assert_gt(cave_count, 0, "The connection must not delete the generated area")


func _room(id: int, center: Vector2i, type: Cell.Type) -> Room:
	var room := Room.new(id, center)
	room.cells.append(center)
	grid[center.y][center.x].type = type
	grid[center.y][center.x].room_id = id
	return room


func _reachable(start: Vector2i) -> Dictionary:
	var pending: Array[Vector2i] = [start]
	var reached := {start: true}
	while not pending.is_empty():
		var point: Vector2i = pending.pop_back()
		for delta: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next := point + delta
			if next.x < 0 or next.y < 0 or next.x >= 128 or next.y >= 32 or reached.has(next):
				continue
			if grid[next.y][next.x].type != Cell.Type.EMPTY:
				reached[next] = true
				pending.append(next)
	return reached
