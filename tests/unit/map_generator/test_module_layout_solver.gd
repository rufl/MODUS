extends ModusGutTestBase

const ModuleAssembly = preload("res://shared/editor_core/core/module_assembly.gd")
const LevelRootScript = preload("res://shared/editor_core/nodes/level_root.gd")
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
	assert_eq(result.get("graph_profile", ""), "cyclic", str(result))
	assert_eq(result.get("graph_profile", ""), "cyclic")
	assert_eq(result.get("room_count", 0), 3)
	assert_eq(result.get("edge_count", 0), 3)
	assert_eq(result.get("attempts", 0), 0)


func test_valid_spatial_plan_attaches_authored_modules() -> void:
	var definitions := ModuleAssembly.get_catalog()
	assert_false(definitions.is_empty(), "Authored module catalog must be available")
	if definitions.is_empty():
		return
	var definition: PrefabMetadata = definitions[0]
	var plan := _tree_plan(
		[0, 1], [{"from_room_id": 0, "to_room_id": 1}, {"from_room_id": 1, "to_room_id": 0}]
	)
	var solved := solver.solve(plan, [definition])
	assert_true(bool(solved.get("is_valid", false)), str(solved.get("error_message", "")))
	if not bool(solved.get("is_valid", false)):
		return
	var root := LevelRootScript.new()
	root.name = "SpatialPlanRoot"
	add_child_autofree(root)
	var attached := ModuleAssembly.attach_spatial_plan(root, solved, [definition])
	assert_true(bool(attached.get("success", false)), str(attached.get("error", "")))
	assert_eq(ModuleAssembly.get_instances(root).size(), 2)
	assert_eq(root.module_connections.size(), 1)
	assert_eq(ModuleAssembly.get_instances(root)[0].instance_id, "generated_room_0")


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
