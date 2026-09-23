extends ModusGutTestBase

const ModuleLayoutSolver = preload("res://game/scripts/map_generator/module_layout_solver.gd")
const PrefabMetadata = preload("res://game/scripts/map_generator/prefab_metadata.gd")

var solver: ModuleLayoutSolver


func before_each() -> void:
	solver = ModuleLayoutSolver.new()


func test_linear_graph_pairs_typed_sockets_deterministically() -> void:
	var plan := _tree_plan(
		[0, 1, 2],
		[
			{"from_room_id": 0, "to_room_id": 1},
			{"from_room_id": 1, "to_room_id": 0},
			{"from_room_id": 1, "to_room_id": 2},
			{"from_room_id": 2, "to_room_id": 1}
		]
	)
	var result := solver.solve(plan, [_module("hall", ["in", "out"])])
	assert_true(bool(result.get("is_valid", false)))
	assert_eq(result.get("placements", []).size(), 3)
	assert_eq(result.get("connections", []).size(), 2)
	assert_eq(result.get("placements", [])[0].get("module_id", ""), "hall")
	assert_true(int(result.get("attempts", 0)) > 0)


func test_branch_graph_requires_enough_socket_capacity() -> void:
	var plan := _tree_plan(
		[0, 1, 2],
		[
			{"from_room_id": 0, "to_room_id": 1},
			{"from_room_id": 1, "to_room_id": 0},
			{"from_room_id": 0, "to_room_id": 2},
			{"from_room_id": 2, "to_room_id": 0}
		]
	)
	var result := solver.solve(plan, [_module("leaf", ["only"]), _module("hub", ["a", "b"])])
	assert_true(bool(result.get("is_valid", false)))
	assert_eq(result.get("connections", []).size(), 2)
	assert_eq(result.get("placements", [])[0].get("module_id", ""), "hub")


func test_cycle_is_rejected_before_candidate_search() -> void:
	var plan := _tree_plan(
		[0, 1, 2],
		[
			{"from_room_id": 0, "to_room_id": 1},
			{"from_room_id": 1, "to_room_id": 0},
			{"from_room_id": 1, "to_room_id": 2},
			{"from_room_id": 2, "to_room_id": 1},
			{"from_room_id": 2, "to_room_id": 0},
			{"from_room_id": 0, "to_room_id": 2}
		]
	)
	var result := solver.solve(plan, [_module("hall", ["a", "b", "c"])])
	assert_false(bool(result.get("is_valid", false)))
	assert_true("tree-shaped" in str(result.get("error_message", "")))
	assert_eq(result.get("attempts", 0), 0)


func test_incompatible_socket_kind_fails_with_bounded_attempts() -> void:
	var plan := _tree_plan(
		[0, 1], [{"from_room_id": 0, "to_room_id": 1}, {"from_room_id": 1, "to_room_id": 0}]
	)
	plan["required_socket_kind"] = "walk"
	var result := solver.solve(plan, [_module("combat", ["combat"], "combat")], 3)
	assert_false(bool(result.get("is_valid", false)))
	assert_true(str(result.get("error_message", "")).contains("compatible"))
	assert_lte(int(result.get("attempts", 0)), 3)


func _tree_plan(room_ids: Array, edges: Array) -> Dictionary:
	return {
		"is_valid": true, "room_ids": room_ids, "room_edges": edges, "start_room_id": room_ids[0]
	}


func _module(module_id: String, socket_ids: Array, kind: String = "walk") -> PrefabMetadata:
	var metadata := PrefabMetadata.new()
	metadata.module_id = module_id
	metadata.scene_path = "res://%s.tscn" % module_id
	metadata.dimensions = Vector3(2, 2, 2)
	for index in range(socket_ids.size()):
		var z := -1.0 if index % 2 == 0 else 1.0
		metadata.sockets.append(
			{
				"id": socket_ids[index],
				"kind": kind,
				"local_transform": Transform3D(Basis.IDENTITY, Vector3(0, 0, z)),
				"opening": Vector2(1, 2),
				"clearance": AABB(Vector3(-0.5, 0, z - 0.5), Vector3(1, 2, 1))
			}
		)
	return metadata
