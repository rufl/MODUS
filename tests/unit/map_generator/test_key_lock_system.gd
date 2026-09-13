extends ModusGutTestBase

## Unit tests for KeyLockSystem
## Tests Requirements 12.1, 12.2, 12.3, 12.4, 12.5, 12.6

const KeyLockSystem = preload("res://game/scripts/map_generator/key_lock_system.gd")
const GenerationContext = preload("res://game/scripts/map_generator/generation_context.gd")
const GenerationConfig = preload("res://game/scripts/map_generator/generation_config.gd")
const Cell = preload("res://game/scripts/map_generator/cell.gd")
const Room = preload("res://game/scripts/map_generator/room.gd")

var key_lock_system: KeyLockSystem
var context: GenerationContext


func before_each() -> void:
	key_lock_system = KeyLockSystem.new()
	context = GenerationContext.new()
	context.config = GenerationConfig.new()
	context.config.enable_key_locks = true
	context.grid_size = Vector2i(128, 128)

	# Initialize grid
	context.grid = []
	for y in range(context.grid_size.y):
		var row: Array[Cell] = []
		row.resize(context.grid_size.x)
		for x in range(context.grid_size.x):
			row[x] = Cell.new(Cell.Type.EMPTY)
		context.grid.append(row)

	# Seed RNG for deterministic tests
	context.rng.seed = 54321


func after_each() -> void:
	key_lock_system = null
	context = null


## Test that all locked doors are reachable after key acquisition
## Requirement 12.5
func test_locked_doors_reachable_after_key_acquisition() -> void:
	# Create a chain of connected rooms
	_create_room_chain(context, 6)

	# Generate key-lock system
	var result: Dictionary = key_lock_system.generate_key_lock_system(context)

	var keys: Array = result.get("keys", [])
	var locked_doors: Array = result.get("locked_doors", [])

	# Validate progression
	var is_valid: bool = key_lock_system.validate_key_lock_progression(context, keys, locked_doors)

	assert_true(is_valid, "Key-lock progression should be valid")


## Test that no keys are generated when disabled
func test_no_keys_when_disabled() -> void:
	context.config.enable_key_locks = false

	# Create a chain of connected rooms
	_create_room_chain(context, 5)

	# Generate key-lock system
	var result: Dictionary = key_lock_system.generate_key_lock_system(context)

	var keys: Array = result.get("keys", [])
	var locked_doors: Array = result.get("locked_doors", [])

	assert_eq(keys.size(), 0, "Should not generate keys when disabled")
	assert_eq(locked_doors.size(), 0, "Should not generate locked doors when disabled")


## Helper function to create a chain of connected rooms
func _create_room_chain(ctx: GenerationContext, room_count: int) -> void:
	var spacing := 15

	for i in range(room_count):
		var center := Vector2i(10 + i * spacing, 10)
		var room := Room.new(i, center, Room.RoomType.MEDIUM)

		# Create room cells
		for dy in range(-3, 4):
			for dx in range(-3, 4):
				var pos := center + Vector2i(dx, dy)
				if (
					pos.x >= 0
					and pos.x < ctx.grid_size.x
					and pos.y >= 0
					and pos.y < ctx.grid_size.y
				):
					ctx.grid[pos.y][pos.x].type = Cell.Type.ROOM
					ctx.grid[pos.y][pos.x].room_id = room.id
					room.cells.append(pos)

		# Add entrance point
		room.entrance_points.append(center + Vector2i(3, 0))

		# Connect to previous room
		if i > 0:
			room.connections.append(i - 1)
			ctx.rooms[i - 1].connections.append(i)

		ctx.rooms.append(room)

	ctx.player_start_position = ctx.rooms[0].center
	HallwayGenerator.new().generate_hallways(ctx.rooms, ctx.grid)
