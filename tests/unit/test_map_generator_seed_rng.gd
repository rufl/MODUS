extends ModusGutTestBase

const TEST_SEED := 424242


func _make_context(size: int = 128) -> GenerationContext:
	var context := GenerationContext.new()
	context.grid_size = Vector2i(size, size)
	context.seed_hash = TEST_SEED
	context.rng.seed = TEST_SEED
	context.config = GenerationConfig.new()
	context.config.enable_key_locks = true
	context.config.enable_secrets = true
	context.config.secret_room_count = 2
	for y in range(size):
		var row: Array = []
		for x in range(size):
			row.append(Cell.new())
		context.grid.append(row)
	return context


func _add_progression_rooms(context: GenerationContext, with_doors: bool = true) -> void:
	for i in range(4):
		var room := Room.new(i, Vector2i(12 + i * 12, 20))
		for y in range(room.center.y - 1, room.center.y + 2):
			for x in range(room.center.x - 1, room.center.x + 2):
				var pos := Vector2i(x, y)
				room.cells.append(pos)
				context.grid[y][x].type = Cell.Type.ROOM
				context.grid[y][x].room_id = room.id
				context.grid[y][x].height = 1.25
		if with_doors:
			room.entrance_points.append(room.cells[0])
		if i > 0:
			room.connections.append(i - 1)
		if i < 3:
			room.connections.append(i + 1)
		context.rooms.append(room)
	context.player_start_position = context.rooms[0].center


func _disturb_global_rng(global_seed: int) -> void:
	seed(global_seed)
	for i in range(37):
		randf()
		randi()
		var unrelated := [0, 1, 2, 3, 4]
		unrelated.shuffle()


func _generate_gameplay_records(context: GenerationContext) -> Dictionary:
	var pairs := KeyLockSystem.new().generate_key_lock_system(context)
	var secrets := SecretRoomGenerator.new()
	context.secret_rooms = secrets.generate_secret_rooms(context)
	secrets.place_secret_items(context)
	return {"pairs": pairs, "secrets": context.secret_rooms, "items": context.item_spawns}


func test_keys_and_secrets_ignore_unrelated_global_random_activity() -> void:
	var first := _make_context()
	_add_progression_rooms(first)
	_disturb_global_rng(111)
	var first_records := _generate_gameplay_records(first)
	var second := _make_context()
	_add_progression_rooms(second)
	_disturb_global_rng(999)
	var second_records := _generate_gameplay_records(second)

	assert_eq(first_records.pairs["keys"].size(), 1, "Fixture must produce a paired key")
	assert_eq(first_records.secrets.size(), 2, "Fixture must produce multiple secret identities")
	assert_true(
		first_records == second_records,
		"Placements and item records must depend only on the map seed"
	)


func test_failed_door_does_not_commit_a_key() -> void:
	var context := _make_context()
	_add_progression_rooms(context, false)
	var result := KeyLockSystem.new().generate_key_lock_system(context)
	assert_eq(result, {"keys": [], "locked_doors": []})
	assert_true(context.key_placements.is_empty(), "Failed pairs cannot leave retained keys")
	for room: Room in context.rooms:
		for pos: Vector2i in room.cells:
			assert_false(context.grid[pos.y][pos.x].metadata.get("has_key", false))
			assert_false(context.grid[pos.y][pos.x].metadata.get("has_locked_door", false))


func test_secret_records_reserve_unique_cells_and_a_walkable_entrance() -> void:
	var context := _make_context()
	_add_progression_rooms(context)
	var original_rooms := {}
	for room: Room in context.rooms:
		for pos: Vector2i in room.cells:
			original_rooms[pos] = room.id
	var generator := SecretRoomGenerator.new()
	var secrets := generator.generate_secret_rooms(context)
	assert_eq(secrets.size(), 2)
	assert_true(context.secret_rooms.is_empty(), "Caller retains the returned array exactly once")
	context.secret_rooms = secrets
	var ids := {}
	var occupied := original_rooms.duplicate()
	for secret: Dictionary in secrets:
		assert_false(ids.has(secret.id), "Secret IDs must be unique")
		ids[secret.id] = true
		var wall: Vector2i = secret.fake_wall_position
		var entrance: Vector2i = secret.entrance_position
		assert_eq(entrance, wall + secret.direction)
		assert_true(
			original_rooms.has(wall - secret.direction), "Fake wall must adjoin the source room"
		)
		assert_has(secret.cells, entrance)
		assert_false(occupied.has(wall), "Fake walls cannot overwrite any room or another secret")
		occupied[wall] = secret.id
		assert_eq(context.grid[wall.y][wall.x].type, Cell.Type.SECRET)
		assert_true(context.grid[wall.y][wall.x].metadata.get("passable", false))
		for pos: Vector2i in secret.cells:
			assert_false(
				occupied.has(pos), "Secret cells cannot overlap rooms, walls, or other secrets"
			)
			occupied[pos] = secret.id
			assert_eq(context.grid[pos.y][pos.x].metadata.secret_room_id, secret.id)
	for pos: Vector2i in original_rooms:
		assert_eq(context.grid[pos.y][pos.x].type, Cell.Type.ROOM)
		assert_eq(context.grid[pos.y][pos.x].room_id, original_rooms[pos])

	generator.place_secret_items(context)
	for item: Dictionary in context.item_spawns:
		var pos := Vector2i(floori(item.position.x / 2.0), floori(item.position.z / 2.0))
		assert_has(
			secrets[item.secret_room_id].cells, pos, "Secret rewards must be on real room cells"
		)
		assert_eq(
			item.position,
			Vector3(pos.x * 2.0 + 1.0, context.grid[pos.y][pos.x].height, pos.y * 2.0 + 1.0)
		)


func _room_records(rooms: Array[Room]) -> Array:
	var records := []
	for room: Room in rooms:
		records.append(
			{
				"type": room.type,
				"center": room.center,
				"cells": room.cells,
				"entrances": room.entrance_points,
				"metadata": room.metadata
			}
		)
	return records


func _layout_records(global_seed: int) -> Dictionary:
	_disturb_global_rng(global_seed)
	var context := _make_context()
	context.config.enable_boss_arena = true
	var rooms := ShapeGrammarEngine.new().generate_rooms(6, context)
	var arenas := BossArenaGenerator.new().generate_boss_arenas(context)

	# Long boundaries force transition selection to choose a subset of candidates.
	var transitions := _make_context(32)
	var region := Rect2i(4, 4, 20, 2)
	for x in range(4, 24):
		transitions.grid[3][x].type = Cell.Type.ROOM
		transitions.grid[4][x].type = Cell.Type.OUTDOOR
		transitions.grid[5][x].type = Cell.Type.CAVE
		transitions.grid[6][x].type = Cell.Type.HALLWAY
	OutdoorParkGenerator.new()._create_outdoor_transitions(region, transitions)
	CaveSystemGenerator.new()._create_cave_connections(region, transitions)
	var outdoor := []
	var caves := []
	for x in range(4, 24):
		if transitions.grid[4][x].metadata.get("is_outdoor_transition", false):
			outdoor.append(Vector2i(x, 4))
		if transitions.grid[5][x].metadata.get("is_cave_entrance", false):
			caves.append(Vector2i(x, 5))
	return {
		"rooms": _room_records(rooms),
		"arenas": _room_records(arenas),
		"outdoor": outdoor,
		"caves": caves
	}


func test_room_layouts_and_boundary_connections_ignore_global_random_activity() -> void:
	var first := _layout_records(111)
	var second := _layout_records(999)
	assert_eq(first.rooms.size(), 6)
	assert_eq(first.arenas.size(), 1)
	assert_eq(first.outdoor.size(), 2)
	assert_eq(first.caves.size(), 2)
	assert_true(
		first == second,
		"Room choices, boss entrances and outdoor/cave connections must be seed-isolated"
	)


func _group_colors(context: GenerationContext, count: int) -> Array:
	var placements := []
	for i in range(count):
		var node := Node3D.new()
		add_child_autofree(node)
		placements.append({"node": node, "entry": {"file_path": "res://color_fixture.tscn"}})
	var groups := MultiMeshManager.new().group_prefab_instances(
		placements, context.create_cosmetic_rng()
	)
	var colors := []
	for instance in groups["res://color_fixture.tscn"]:
		colors.append(instance.color)
	return colors


func test_cosmetic_colors_are_seeded_without_changing_gameplay_placements() -> void:
	var first := _make_context()
	_add_progression_rooms(first)
	_disturb_global_rng(111)
	var first_colors := _group_colors(first, 24)
	var first_records := _generate_gameplay_records(first)
	var second := _make_context()
	_add_progression_rooms(second)
	_disturb_global_rng(999)
	var second_colors := _group_colors(second, 24)
	_group_colors(second, 71)
	var second_records := _generate_gameplay_records(second)
	assert_eq(first_colors, second_colors, "Rendered instance colors must ignore global randomness")
	assert_true(
		first_records == second_records, "Extra cosmetic work must not move keys or secrets"
	)


func test_key_and_door_positions_use_cell_centers_and_floor_height() -> void:
	var context := _make_context()
	_add_progression_rooms(context)
	var result := KeyLockSystem.new().generate_key_lock_system(context)
	assert_eq(result["keys"].size(), 1)
	for key: Dictionary in result["keys"]:
		var pos: Vector2i = key.grid_position
		assert_eq(key.position, Vector3(pos.x * 2.0 + 1.0, 1.75, pos.y * 2.0 + 1.0))
	for door: Dictionary in result.locked_doors:
		var pos: Vector2i = door.grid_position
		assert_eq(door.position, Vector3(pos.x * 2.0 + 1.0, 1.25, pos.y * 2.0 + 1.0))
