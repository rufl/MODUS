extends ModusGutTestBase

## Unit tests for ShapeGrammarEngine

const ShapeGrammarEngine = preload("res://game/scripts/map_generator/shape_grammar_engine.gd")
const GenerationContext = preload("res://game/scripts/map_generator/generation_context.gd")
const GenerationConfig = preload("res://game/scripts/map_generator/generation_config.gd")
const Cell = preload("res://game/scripts/map_generator/cell.gd")
const Room = preload("res://game/scripts/map_generator/room.gd")

var engine: ShapeGrammarEngine
var rng: RandomNumberGenerator
var context: GenerationContext


func before_each() -> void:
	engine = ShapeGrammarEngine.new()
	rng = RandomNumberGenerator.new()
	rng.seed = 12345  # Fixed seed for deterministic tests

	# Create minimal context
	context = GenerationContext.new()
	context.grid_size = Vector2i(128, 128)
	context.rng = rng
	context.config = GenerationConfig.new()
	context.config.enable_boss_arena = true

	# Initialize grid
	context.grid = []
	for y in range(context.grid_size.y):
		var row: Array[Cell] = []
		for x in range(context.grid_size.x):
			row.append(Cell.new())
		context.grid.append(row)


func test_room_shape_uses_world_cell_coordinates() -> void:
	var first_center := Vector2i(20, 24)
	var second_center := Vector2i(60, 70)
	rng.seed = 42
	var first := engine.generate_room_shape(first_center, 12, Room.RoomType.MEDIUM, rng)
	rng.seed = 42
	var second := engine.generate_room_shape(second_center, 12, Room.RoomType.MEDIUM, rng)
	var expected_offset := Vector2(second_center - first_center) * 2.0
	assert_eq(first.size(), second.size())
	for i in range(first.size()):
		assert_almost_eq(second[i], first[i] + expected_offset, Vector2(0.001, 0.001))


func test_polygon_to_grid_cells_samples_centers_and_clips_bounds() -> void:
	# Only the center of cell (0, 0) is inside; its corner lies outside.
	var points := PackedVector2Array(
		[Vector2(-0.5, 0.5), Vector2(1.5, 0.5), Vector2(1.5, 1.5), Vector2(-0.5, 1.5)]
	)
	assert_eq(engine.polygon_to_grid_cells(points, context.grid_size), [Vector2i.ZERO])


func test_generated_room_center_and_entrances_are_in_its_connected_footprint() -> void:
	for center: Vector2i in [Vector2i(64, 64), Vector2i(0, 0), Vector2i(127, 127)]:
		var room := engine.generate_room(center, Room.RoomType.MEDIUM, 0, context)
		assert_has(room.cells, room.center, "Logical centers must be usable hallway/spawn cells")
		for entrance: Vector2i in room.entrance_points:
			assert_has(room.cells, entrance)
		var remaining := {}
		for cell: Vector2i in room.cells:
			assert_true(Rect2i(Vector2i.ZERO, context.grid_size).has_point(cell))
			remaining[cell] = true
		var queue: Array[Vector2i] = [room.center]
		while not queue.is_empty():
			var cell: Vector2i = queue.pop_back()
			if not remaining.erase(cell):
				continue
			for direction: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				if remaining.has(cell + direction):
					queue.append(cell + direction)
		assert_true(
			remaining.is_empty(), "Minimum-size growth must not create disconnected room islands"
		)


func test_room_meets_minimum_size_requirements() -> void:
	var center := Vector2i(64, 64)

	# Test small room
	var small_room: Room = engine.generate_room(center, Room.RoomType.SMALL, 0, context)
	assert_true(small_room.cells.size() >= 4, "Small room should have at least 4 cells")

	# Test medium room
	var medium_room: Room = engine.generate_room(
		center + Vector2i(20, 0), Room.RoomType.MEDIUM, 1, context
	)
	assert_true(medium_room.cells.size() >= 9, "Medium room should have at least 9 cells")

	# Test large room
	var large_room: Room = engine.generate_room(
		center + Vector2i(40, 0), Room.RoomType.LARGE, 2, context
	)
	assert_true(large_room.cells.size() >= 17, "Large room should have at least 17 cells")


func test_validate_no_narrow_passages_valid() -> void:
	# Create a 2x2 block of cells (no narrow passages)
	var cells: Array[Vector2i] = [
		Vector2i(64, 64), Vector2i(65, 64), Vector2i(64, 65), Vector2i(65, 65)
	]

	var is_valid: bool = engine.validate_no_narrow_passages(cells)
	assert_true(is_valid, "2x2 block should have no narrow passages")


func test_deterministic_generation_with_same_seed() -> void:
	var center := Vector2i(64, 64)
	var room_type: Room.RoomType = Room.RoomType.MEDIUM

	# Generate with first RNG
	var rng1 := RandomNumberGenerator.new()
	rng1.seed = 42
	var points1: PackedVector2Array = engine.generate_room_shape(center, 12, room_type, rng1, null)

	# Generate with second RNG (same seed)
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 42
	var points2: PackedVector2Array = engine.generate_room_shape(center, 12, room_type, rng2, null)

	assert_eq(points1.size(), points2.size(), "Should generate same number of points")

	# Check if points are identical
	for i in range(points1.size()):
		assert_almost_eq(points1[i].x, points2[i].x, 0.01, "Point X should match")
		assert_almost_eq(points1[i].y, points2[i].y, 0.01, "Point Y should match")


func test_generate_rooms_do_not_overlap() -> void:
	var rooms := engine.generate_rooms(5, context)
	assert_eq(rooms.size(), 5)
	var occupied := {}
	for room: Room in rooms:
		for cell: Vector2i in room.cells:
			assert_false(occupied.has(cell), "Generated rooms cannot claim the same cell")
			occupied[cell] = true
