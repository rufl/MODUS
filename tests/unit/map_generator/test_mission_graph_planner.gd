extends ModusGutTestBase

const MissionGraphPlanner = preload("res://game/scripts/map_generator/mission_graph_planner.gd")
const GenerationContext = preload("res://game/scripts/map_generator/generation_context.gd")
const GenerationConfig = preload("res://game/scripts/map_generator/generation_config.gd")
const Cell = preload("res://game/scripts/map_generator/cell.gd")
const Room = preload("res://game/scripts/map_generator/room.gd")

var planner: MissionGraphPlanner
var context: GenerationContext


func before_each() -> void:
	planner = MissionGraphPlanner.new()
	context = GenerationContext.new()
	context.config = GenerationConfig.new()
	context.grid_size = Vector2i(64, 64)
	context.grid = []
	for y in range(context.grid_size.y):
		var row: Array[Cell] = []
		row.resize(context.grid_size.x)
		for x in range(context.grid_size.x):
			row[x] = Cell.new(Cell.Type.EMPTY)
		context.grid.append(row)


func test_linear_graph_produces_recovery_route() -> void:
	_create_chain(4)
	var plan := planner.plan(context)
	assert_true(bool(plan.get("is_valid", false)))
	assert_eq(plan.get("graph_profile", ""), "linear")
	assert_eq(plan.get("recovery_route", []), [0, 1, 2, 3])
	assert_eq(plan.get("branch_room_ids", []), [])


func test_explicit_extraction_selects_shortest_route_and_branch_metadata() -> void:
	_create_chain(4)
	context.rooms[0].connections = [1, 2]
	context.rooms[1].connections = [0, 3]
	context.rooms[2].connections = [0, 3]
	context.rooms[3].connections = [1, 2]
	context.exit_position = context.rooms[3].center
	var plan := planner.plan(context)
	assert_true(bool(plan.get("is_valid", false)))
	assert_eq(plan.get("recovery_route", []), [0, 1, 3])
	assert_eq(plan.get("branch_room_ids", []), [2])
	assert_eq(plan.get("graph_profile", ""), "branching")


func test_graph_profile_marks_cycles_without_off_route_rooms() -> void:
	_create_chain(4)
	context.rooms[0].connections = [1, 3]
	context.rooms[1].connections = [0, 2]
	context.rooms[2].connections = [1, 3]
	context.rooms[3].connections = [2, 0]
	context.exit_position = context.rooms[2].center
	var plan := planner.plan(context)
	assert_true(bool(plan.get("is_valid", false)))
	assert_eq(plan.get("branch_room_ids", []), [3])
	assert_eq(plan.get("graph_profile", ""), "branching")


func test_unknown_edge_is_rejected() -> void:
	_create_chain(3)
	context.rooms[1].connections.append(99)
	var plan := planner.plan(context)
	assert_false(bool(plan.get("is_valid", false)))
	assert_true("unknown room" in str(plan.get("error_message", "")))


func test_disconnected_graph_is_rejected() -> void:
	_create_chain(3)
	context.rooms[1].connections = [0]
	context.rooms[2].connections = []
	var plan := planner.plan(context)
	assert_false(bool(plan.get("is_valid", false)))
	assert_true("disconnected" in str(plan.get("error_message", "")))


func _create_chain(count: int) -> void:
	for index in range(count):
		var room := Room.new(index, Vector2i(4 + index * 10, 4), Room.RoomType.MEDIUM)
		room.center = Vector2i(4 + index * 10, 4)
		room.connections = []
		if index > 0:
			room.connections.append(index - 1)
		if index < count - 1:
			room.connections.append(index + 1)
		context.rooms.append(room)
		context.grid[4][4 + index * 10].room_id = index
