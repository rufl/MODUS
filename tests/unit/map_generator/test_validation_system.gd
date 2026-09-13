extends ModusGutTestBase

const ValidationSystem = preload("res://game/scripts/map_generator/validation_system.gd")
const GenerationContext = preload("res://game/scripts/map_generator/generation_context.gd")
const Cell = preload("res://game/scripts/map_generator/cell.gd")
const Room = preload("res://game/scripts/map_generator/room.gd")

var context: GenerationContext
var validator: ValidationSystem


func before_each() -> void:
	context = GenerationContext.new()
	validator = ValidationSystem.new()
	context.grid_size = Vector2i(12, 3)
	for y in range(3):
		var row: Array[Cell] = []
		for x in range(12):
			row.append(Cell.new(Cell.Type.HALLWAY if y == 1 else Cell.Type.EMPTY))
		context.grid.append(row)
	context.player_start_position = Vector2i(0, 1)


func _key(color: String, x: int) -> void:
	context.key_placements.append({"color": color, "grid_position": Vector2i(x, 1)})


func _door(color: String, x: int) -> void:
	if not context.metadata.has("locked_doors"):
		context.metadata.locked_doors = []
	context.metadata.locked_doors.append({"color": color, "grid_position": Vector2i(x, 1)})


func test_own_key_behind_its_gate_fails() -> void:
	_key("RED", 4)
	_door("RED", 3)
	assert_false(validator.validate_key_lock_progression(context).is_valid)


func test_mutual_key_dependency_fails_with_all_gates_closed() -> void:
	context.player_start_position = Vector2i(3, 1)
	_key("RED", 1)
	_key("BLUE", 5)
	_door("BLUE", 2)
	_door("RED", 4)
	assert_false(validator.validate_key_lock_progression(context).is_valid)


func test_ordered_chain_unlocks_until_final_door_is_reachable() -> void:
	_key("RED", 1)
	_key("BLUE", 4)
	_door("RED", 3)
	_door("BLUE", 6)
	var result := validator.validate_key_lock_progression(context)
	assert_true(result.is_valid, result.error_message)


func test_multiple_same_color_gates_cannot_expose_their_own_key() -> void:
	_key("RED", 4)
	_door("RED", 3)
	_door("RED", 6)
	assert_false(validator.validate_key_lock_progression(context).is_valid)


func test_explicit_door_without_any_keys_fails() -> void:
	_door("RED", 3)
	assert_false(validator.validate_key_lock_progression(context).is_valid)


func test_grid_only_orphan_door_is_not_hidden_by_empty_placements() -> void:
	context.grid[1][3].metadata = {"has_locked_door": true, "door_color": "RED"}
	assert_false(validator.validate_key_lock_progression(context).is_valid)
	context.grid[1][1].metadata = {"has_key": true, "key_color": "RED"}
	assert_false(validator.validate_key_lock_progression(context).is_valid)
	_key("RED", 1)
	assert_true(validator.validate_key_lock_progression(context).is_valid)


func test_malformed_and_outside_door_records_fail() -> void:
	_key("RED", 1)
	for door: Variant in [
		{"grid_position": Vector2i(3, 1)},
		{"color": "RED"},
		{"color": "RED", "grid_position": Vector2i(12, 1)},
		{"color": "RED", "grid_position": Vector2i(3, 0)},
		{"color": "RED", "grid_position": "3,1"},
		null,
	]:
		context.metadata.locked_doors = [door]
		assert_false(
			validator.validate_key_lock_progression(context).is_valid,
			"Reject malformed door %s" % str(door)
		)


func test_malformed_key_is_not_ignored() -> void:
	context.key_placements = [{"color": "RED", "grid_position": Vector2i(-1, 1)}]
	assert_false(validator.validate_key_lock_progression(context).is_valid)


func test_conflicting_explicit_and_grid_door_colors_fail() -> void:
	_key("RED", 1)
	_key("BLUE", 2)
	_door("RED", 3)
	context.grid[1][3].metadata = {"has_locked_door": true, "door_color": "BLUE"}
	assert_false(validator.validate_key_lock_progression(context).is_valid)


func test_tiny_disconnected_mandatory_room_fails_connectivity() -> void:
	# The disconnected room is less than 10% of walkable area.
	context.grid[1][10].type = Cell.Type.EMPTY
	var room := Room.new(0, Vector2i(11, 1))
	room.cells.append(room.center)
	context.rooms.append(room)
	assert_false(validator.validate_connectivity(context).is_valid)
