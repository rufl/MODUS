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


func test_manifest_retains_reachable_mandatory_order_and_unique_records() -> void:
	_create_room_chain(context, 6)
	var result: Dictionary = key_lock_system.generate_key_lock_system(context)
	var manifest: Dictionary = result.get("progression_manifest", {})
	assert_true(manifest.has("recovery_route"))
	assert_eq(manifest.objectives[0].id, "KeyPickup_0")
	assert_eq(manifest.objectives[1].id, "LockedDoor_0")
	assert_eq(manifest.objectives[1].requires, ["KeyPickup_0"])
	assert_eq(manifest.keys.size(), manifest.locked_transitions.size())
	assert_eq(manifest.keys.size(), 2)
	assert_eq(manifest.room_edges.size(), 10)
	assert_true(key_lock_system.validate_progression_manifest(context, manifest).is_valid)


func test_manifest_rejects_forged_room_edge() -> void:
	_create_room_chain(context, 6)
	var manifest: Dictionary = (
		key_lock_system.generate_key_lock_system(context).progression_manifest
	)
	manifest.room_edges[0] = {"from_room_id": 0, "to_room_id": 99}
	var validation := key_lock_system.validate_progression_manifest(context, manifest, false)
	assert_false(validation.is_valid)
	assert_true("room edge" in validation.error_message)


func test_disconnected_room_graph_is_rejected_transactionally() -> void:
	_create_room_chain(context, 4)
	var detached := Room.new(99, Vector2i(100, 100), Room.RoomType.MEDIUM)
	context.rooms.append(detached)
	var result := key_lock_system.generate_key_lock_system(context)
	assert_true(result.get("keys", []).is_empty())
	assert_true(result.get("locked_doors", []).is_empty())
	assert_true(context.progression_manifest.is_empty())


func test_manifest_is_deterministic_for_same_seed() -> void:
	var first := context
	_create_room_chain(first, 6)
	var first_manifest: Dictionary = (
		key_lock_system.generate_key_lock_system(first).progression_manifest
	)
	var second := GenerationContext.new()
	second.config = GenerationConfig.new()
	second.config.enable_key_locks = true
	second.grid_size = context.grid_size
	second.rng.seed = 54321
	second.seed_hash = context.seed_hash
	second.grid = []
	for y in range(second.grid_size.y):
		var row: Array[Cell] = []
		row.resize(second.grid_size.x)
		for x in range(second.grid_size.x):
			row[x] = Cell.new(Cell.Type.EMPTY)
		second.grid.append(row)
	_create_room_chain(second, 6)
	var second_manifest: Dictionary = (
		key_lock_system.generate_key_lock_system(second).progression_manifest
	)
	assert_eq(first_manifest, second_manifest)


func test_impossible_manifest_is_rejected_without_publication() -> void:
	_create_room_chain(context, 6)
	var result: Dictionary = key_lock_system.generate_key_lock_system(context)
	var manifest: Dictionary = result.progression_manifest.duplicate(true)
	manifest.locked_transitions[0].from_room_id = manifest.locked_transitions[0].to_room_id
	var validation := key_lock_system.validate_progression_manifest(context, manifest)
	assert_false(validation.is_valid)
	assert_true(
		context.progression_manifest != manifest,
		"Rejected graph must not replace published manifest"
	)
	assert_true(
		(
			key_lock_system
			. validate_progression_manifest(context, context.progression_manifest)
			. is_valid
		)
	)


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
