extends GutTest

## Unit tests for MapPrefabSystem and PrefabMetadata

const PrefabMetadata = preload("res://game/scripts/map_generator/prefab_metadata.gd")
const MapPrefabSystem = preload("res://game/scripts/map_generator/prefab_system.gd")
const LevelRootScript = preload("res://shared/editor_core/nodes/level_root.gd")

var prefab_system: MapPrefabSystem


func before_each() -> void:
	prefab_system = MapPrefabSystem.new()


func after_each() -> void:
	prefab_system = null


## Test PrefabMetadata parsing from dictionary
func test_prefab_metadata_from_dict_valid() -> void:
	var data := {
		"dimensions": [2.0, 3.0, 2.0],
		"anchor_points": [[0.0, 0.0, 0.0], [1.0, 0.0, 0.0]],
		"required_theme": "tech",
		"density_weight": 1.5,
		"tags": ["prop", "cover"],
		"collision_radius": 0.75,
		"placement_rules": {"min_distance_from_walls": 0.5}
	}

	var metadata := PrefabMetadata.from_dict(data)

	assert_not_null(metadata, "Metadata should be parsed successfully")
	assert_eq(metadata.dimensions, Vector3(2.0, 3.0, 2.0), "Dimensions should match")
	assert_eq(metadata.anchor_points.size(), 2, "Should have 2 anchor points")
	assert_eq(metadata.required_theme, GenerationConfig.ThemeType.TECH, "MapTheme should be TECH")
	assert_eq(metadata.density_weight, 1.5, "Density weight should match")
	assert_eq(metadata.tags.size(), 2, "Should have 2 tags")
	assert_eq(metadata.collision_radius, 0.75, "Collision radius should match")
	assert_true(
		metadata.placement_rules.has("min_distance_from_walls"), "Should have placement rule"
	)


## Test PrefabMetadata parsing with missing required fields
func test_prefab_metadata_from_dict_missing_dimensions() -> void:
	var data := {"anchor_points": [[0.0, 0.0, 0.0]], "required_theme": "tech"}

	var metadata := PrefabMetadata.from_dict(data)

	assert_null(metadata, "Metadata should be null when dimensions are missing")
	assert_push_error_count(1)


## Test PrefabMetadata parsing with invalid theme
func test_prefab_metadata_from_dict_invalid_theme() -> void:
	var data := {
		"dimensions": [2.0, 3.0, 2.0],
		"anchor_points": [[0.0, 0.0, 0.0]],
		"required_theme": "invalid_theme"
	}

	var metadata := PrefabMetadata.from_dict(data)

	assert_null(metadata, "Metadata should be null when theme is invalid")
	assert_push_error_count(1)


## Test PrefabMetadata to_dict conversion
func test_prefab_metadata_to_dict() -> void:
	var metadata := PrefabMetadata.new()
	metadata.dimensions = Vector3(2.0, 3.0, 2.0)
	metadata.anchor_points = [Vector3(0.0, 0.0, 0.0), Vector3(1.0, 0.0, 0.0)]
	metadata.required_theme = GenerationConfig.ThemeType.URBAN
	metadata.density_weight = 1.2
	metadata.tags = ["furniture", "decorative"]
	metadata.collision_radius = 0.6
	metadata.placement_rules = {"requires_floor": true}

	var data := metadata.to_dict()

	assert_eq(data["dimensions"], [2.0, 3.0, 2.0], "Dimensions should match")
	assert_eq(data["anchor_points"].size(), 2, "Should have 2 anchor points")
	assert_eq(data["required_theme"], "urban", "MapTheme should be 'urban'")
	assert_eq(data["density_weight"], 1.2, "Density weight should match")
	assert_eq(data["tags"].size(), 2, "Should have 2 tags")
	assert_eq(data["collision_radius"], 0.6, "Collision radius should match")
	assert_true(data["placement_rules"].has("requires_floor"), "Should have placement rule")


## Test PrefabMetadata round-trip (parse -> export -> parse)
func test_prefab_metadata_round_trip() -> void:
	var original_data := {
		"dimensions": [3.0, 2.5, 1.5],
		"anchor_points": [[0.0, 0.0, 0.0]],
		"required_theme": "cave",
		"density_weight": 0.8,
		"tags": ["gameplay"],
		"collision_radius": 1.0,
		"placement_rules": {"max_per_room": 2}
	}

	var metadata := PrefabMetadata.from_dict(original_data)
	assert_not_null(metadata, "First parse should succeed")

	var exported_data := metadata.to_dict()
	var metadata2 := PrefabMetadata.from_dict(exported_data)
	assert_not_null(metadata2, "Second parse should succeed")

	# Verify all fields match
	assert_eq(metadata2.dimensions, metadata.dimensions, "Dimensions should match")
	assert_eq(
		metadata2.anchor_points.size(),
		metadata.anchor_points.size(),
		"Anchor points count should match"
	)
	assert_eq(metadata2.required_theme, metadata.required_theme, "MapTheme should match")
	assert_eq(metadata2.density_weight, metadata.density_weight, "Density weight should match")
	assert_eq(metadata2.tags.size(), metadata.tags.size(), "Tags count should match")
	assert_eq(
		metadata2.collision_radius, metadata.collision_radius, "Collision radius should match"
	)


## Test PrefabMetadata validation
func test_prefab_metadata_is_valid() -> void:
	var metadata := PrefabMetadata.new()

	# Invalid: zero dimensions
	metadata.dimensions = Vector3.ZERO
	assert_false(metadata.is_valid(), "Should be invalid with zero dimensions")

	# Valid: non-zero dimensions
	metadata.dimensions = Vector3(1.0, 1.0, 1.0)
	assert_true(metadata.is_valid(), "Should be valid with non-zero dimensions")


## Test MapPrefabSystem cache initialization
func test_prefab_system_cache_initialization() -> void:
	assert_not_null(prefab_system, "MapPrefabSystem should be created")

	# Check that cache is initialized for all themes
	for theme: int in GenerationConfig.ThemeType.values():
		var count := prefab_system.get_prefab_count(theme)
		assert_eq(count, 0, "Initial prefab count should be 0 for theme %d" % theme)


## Test MapPrefabSystem get_categories
func test_prefab_system_get_categories() -> void:
	var categories := prefab_system.get_categories(GenerationConfig.ThemeType.TECH)

	assert_not_null(categories, "Categories should not be null")
	assert_eq(categories.size(), 0, "Initial categories should be empty")


## Test MapPrefabSystem has_prefabs_for_theme
func test_prefab_system_has_prefabs_for_theme() -> void:
	var has_prefabs := prefab_system.has_prefabs_for_theme(GenerationConfig.ThemeType.TECH)

	assert_false(has_prefabs, "Should not have prefabs initially")


## Test MapPrefabSystem statistics
func test_prefab_system_statistics() -> void:
	var stats := prefab_system.get_statistics()

	assert_not_null(stats, "Statistics should not be null")
	assert_true(stats.has("total_prefabs"), "Should have total_prefabs")
	assert_true(stats.has("by_theme"), "Should have by_theme")
	assert_true(stats.has("by_category"), "Should have by_category")
	assert_eq(stats["total_prefabs"], 0, "Initial total should be 0")


func test_module_json_roundtrip_retains_attachable_socket_geometry() -> void:
	var original := PrefabMetadata.new()
	original.module_id = "rotated_room"
	original.scene_path = "res://room.tscn"
	original.content_revision = 3
	original.dimensions = Vector3(12, 6, 16)
	original.required_capabilities = PackedStringArray(["walk"])
	var pose := Transform3D(Basis(Vector3.UP, PI / 2), Vector3(-6, 0, 0))
	original.sockets = [
		{
			"id": "west",
			"kind": "walk",
			"local_transform": pose,
			"opening": Vector2(4, 3),
			"clearance": AABB(Vector3(-7, 0, -2), Vector3(3, 3, 4))
		}
	]
	var decoded := PrefabMetadata.from_dict(JSON.parse_string(original.to_json_string()))
	assert_not_null(decoded)
	if decoded == null:
		return
	var restored_pose: Transform3D = decoded.sockets[0].local_transform
	assert_true(
		restored_pose.is_equal_approx(pose),
		"JSON must preserve outward orientation and socket floor position"
	)
	assert_true(
		decoded.sockets[0].clearance.has_point(Vector3(-6, 1, 0)),
		"The reserved walk approach survives JSON"
	)
	assert_eq(
		decoded.to_dict(),
		original.to_dict(),
		"Content identity and all authored metadata survive serialization"
	)
	assert_true(
		decoded.anchor_points.is_empty(), "Room sockets must not become decorative prop anchors"
	)
	var duplicate := decoded.to_dict()
	duplicate.sockets.append(duplicate.sockets[0].duplicate(true))
	assert_null(PrefabMetadata.from_dict(duplicate), "Ambiguous socket IDs cannot be authored")
	var malformed := decoded.to_dict()
	malformed.sockets[0].local_transform.basis[0] = ["not a number", 0, 0]
	assert_null(
		PrefabMetadata.from_dict(malformed), "Malformed socket geometry cannot enter the catalog"
	)


func test_editor_library_retains_canonical_module_definition_through_json() -> void:
	var definition := PrefabMetadata.new()
	definition.module_id = "room"
	definition.scene_path = "res://room.tscn"
	definition.dimensions = Vector3(12, 6, 16)
	var info := PrefabSystem.PrefabInfo.new()
	info.definition = definition
	info.bounds = AABB(Vector3(-6, 0, -8), definition.dimensions)
	var restored := PrefabSystem.PrefabInfo.from_dict(
		JSON.parse_string(JSON.stringify(info.to_dict()))
	)
	assert_eq(restored.bounds, info.bounds, "Library bounds must remain usable after loading JSON")
	assert_not_null(restored.definition)
	assert_eq(
		restored.definition.to_dict(),
		definition.to_dict(),
		"The editor library must use canonical metadata"
	)


func test_module_rotation_undo_and_pack_preserve_geometry_and_graph() -> void:
	var saved_history := EditorGlobals._runtime_undo_redo
	EditorGlobals._runtime_undo_redo = UndoRedo.new()
	var root: Node3D = LevelRootScript.new()
	root.authoring_mode = true
	add_child(root)
	var catalog := ModuleAssembly.get_catalog()
	var first := ModuleAssembly.place_module(root, catalog[0], "", "", "", 1)
	var second := ModuleAssembly.place_module(root, catalog[1], "airlock", "out", "in")
	assert_true(first.success)
	assert_true(second.success)
	if second.success:
		var instance: ModuleInstance = second.instance
		var pose := instance.transform
		var graph: Array[Dictionary] = root.module_connections.duplicate(true)
		assert_true(ModuleAssembly.validate_level(root).valid)
		EditorGlobals.get_undo_redo().undo()
		assert_eq(ModuleAssembly.get_instances(root).size(), 1)
		assert_true(root.module_connections.is_empty())
		EditorGlobals.get_undo_redo().redo()
		assert_eq(instance.instance_id, "pump")
		assert_true(
			instance.transform.is_equal_approx(pose),
			"Redo restores rotated placement, not source-scene geometry"
		)
		assert_eq(root.module_connections, graph)
		root.prepare_for_save()
		var packed := PackedScene.new()
		assert_eq(packed.pack(root), OK)
		var reopened := packed.instantiate() as Node3D
		assert_true(
			ModuleAssembly.validate_level(reopened).valid,
			"Packed modules keep their socket geometry and graph"
		)
		assert_eq(reopened.module_connections, graph)
		reopened.free()
	EditorGlobals._runtime_undo_redo.clear_history()
	EditorGlobals._runtime_undo_redo = saved_history
	root.free()


func test_module_pin_is_transactional_and_survives_pack_roundtrip() -> void:
	var saved_history := EditorGlobals._runtime_undo_redo
	EditorGlobals._runtime_undo_redo = UndoRedo.new()
	var root: Node3D = LevelRootScript.new()
	root.authoring_mode = true
	add_child(root)
	var catalog := ModuleAssembly.get_catalog()
	var placed := ModuleAssembly.place_module(root, catalog[0])
	assert_true(placed.success)
	if placed.success:
		var instance: ModuleInstance = placed.instance
		var result := ModuleAssembly.set_pinned(root, instance.instance_id, true)
		assert_true(result.success)
		assert_true(instance.pinned, "Pinning must update the selected module")
		EditorGlobals.get_undo_redo().undo()
		assert_false(instance.pinned, "Undo must restore the prior pin state")
		EditorGlobals.get_undo_redo().redo()
		assert_true(instance.pinned, "Redo must restore the pin state")
		root.prepare_for_save()
		var packed := PackedScene.new()
		assert_eq(packed.pack(root), OK)
		var reopened := packed.instantiate() as Node3D
		assert_true(
			(reopened.get_node("Airlock") as ModuleInstance).pinned,
			"Packed documents must preserve module pins"
		)
		reopened.free()
	EditorGlobals._runtime_undo_redo.clear_history()
	EditorGlobals._runtime_undo_redo = saved_history
	root.free()


func test_socket_preview_is_non_mutating_and_matches_committed_pose() -> void:
	var saved_history := EditorGlobals._runtime_undo_redo
	EditorGlobals._runtime_undo_redo = UndoRedo.new()
	var root: Node3D = LevelRootScript.new()
	root.authoring_mode = true
	add_child(root)
	var catalog := ModuleAssembly.get_catalog()
	assert_true(ModuleAssembly.place_module(root, catalog[0]).success)
	var preview := ModuleAssembly.preview_module(root, catalog[1], "airlock", "out", "in")
	assert_true(preview.success, "Compatible sockets must produce a valid preview")
	assert_eq(ModuleAssembly.get_instances(root).size(), 1)
	assert_true(root.module_connections.is_empty(), "Preview must not mutate the document graph")
	var placed := ModuleAssembly.place_module(root, catalog[1], "airlock", "out", "in")
	assert_true(placed.success)
	if placed.success and preview.success:
		assert_true(
			(placed.instance as ModuleInstance).transform.is_equal_approx(preview.transform),
			"Commit must use the previewed socket pose"
		)
	EditorGlobals._runtime_undo_redo.clear_history()
	EditorGlobals._runtime_undo_redo = saved_history
	root.free()


func test_module_ghost_preview_tracks_external_transform_and_clears() -> void:
	var preview := PlacementPreview.new()
	add_child(preview)
	preview.start_preview(BoxMesh.new())
	assert_true(preview.is_active)
	var pose := Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3(4, 2, -3))
	preview.set_preview_transform(pose, false)
	assert_true(preview.preview_node.global_transform.is_equal_approx(pose))
	assert_false(preview.is_valid_placement)
	preview.clear_preview()
	assert_false(preview.is_active)
	assert_null(preview.preview_node)
	preview.free()


func test_free_socket_ray_query_selects_nearest_open_socket() -> void:
	var root: Node3D = LevelRootScript.new()
	root.authoring_mode = true
	add_child(root)
	var catalog := ModuleAssembly.get_catalog()
	assert_true(ModuleAssembly.place_module(root, catalog[0]).success)
	var instance := ModuleAssembly.get_instances(root)[0]
	var socket := instance.get_socket("out")
	var socket_position: Vector3 = (instance.global_transform * socket.local_transform).origin
	var origin := socket_position + Vector3(0, 0, 5)
	var result := ModuleAssembly.find_free_socket_on_ray(
		root, origin, (socket_position - origin).normalized(), 0.01
	)
	assert_eq(result.target_instance_id, instance.instance_id)
	assert_eq(result.target_socket_id, "out")
	root.free()


func test_regenerate_unpinned_preserves_pins_and_is_undoable() -> void:
	var saved_history := EditorGlobals._runtime_undo_redo
	EditorGlobals._runtime_undo_redo = UndoRedo.new()
	var root: Node3D = LevelRootScript.new()
	root.authoring_mode = true
	add_child(root)
	var catalog := ModuleAssembly.get_catalog()
	assert_true(ModuleAssembly.place_module(root, catalog[0]).success)
	var pinned := ModuleAssembly.get_instances(root)[0]
	var pin_result := ModuleAssembly.set_pinned(root, pinned.instance_id, true)
	assert_true(pin_result.success)
	var initial := ModuleAssembly.place_module(root, catalog[1], "airlock", "out", "in")
	assert_true(initial.success)
	var original_unpinned: ModuleInstance = initial.instance
	var captured := ModuleAssembly.build_regeneration_plans(root)
	assert_true(captured.success, "Connected layouts must produce regeneration plans")
	assert_eq(captured.plans.size(), 1)
	var selected := ModuleAssembly.build_regeneration_plans(root, [catalog[1]])
	assert_true(selected.success, "Compatible selected definitions must produce plans")
	assert_eq(selected.plans[0].definition.module_id, catalog[1].module_id)
	var incompatible := catalog[1].duplicate(true) as PrefabMetadata
	for socket in incompatible.sockets:
		socket.kind = "vent"
	var rejected := ModuleAssembly.build_regeneration_plans(root, [incompatible])
	assert_false(rejected.success, "Incompatible replacement definitions must be rejected")
	var regenerated := ModuleAssembly.regenerate_unpinned(root, captured.plans)
	assert_true(regenerated.success, "A valid replacement plan must commit")
	assert_true(pinned.pinned, "Pinned modules must survive regeneration")
	assert_eq(ModuleAssembly.get_instances(root).size(), 2)
	assert_ne(ModuleAssembly.get_instances(root)[1], original_unpinned)
	EditorGlobals.get_undo_redo().undo()
	assert_eq(ModuleAssembly.get_instances(root).size(), 2)
	assert_eq(ModuleAssembly.get_instances(root)[1], original_unpinned)
	EditorGlobals.get_undo_redo().redo()
	assert_eq(ModuleAssembly.get_instances(root).size(), 2)
	assert_ne(ModuleAssembly.get_instances(root)[1], original_unpinned)
	EditorGlobals._runtime_undo_redo.clear_history()
	EditorGlobals._runtime_undo_redo = saved_history
	root.free()


func test_rejected_module_placement_does_not_mutate_document() -> void:
	var saved_history := EditorGlobals._runtime_undo_redo
	EditorGlobals._runtime_undo_redo = UndoRedo.new()
	var root: Node3D = LevelRootScript.new()
	root.authoring_mode = true
	add_child(root)
	var catalog := ModuleAssembly.get_catalog()
	assert_true(ModuleAssembly.place_module(root, catalog[0]).success)
	var wrong_kind := catalog[1].duplicate(true) as PrefabMetadata
	wrong_kind.sockets[0]["kind"] = "vent"
	assert_false(ModuleAssembly.place_module(root, wrong_kind, "airlock", "out", "in").success)
	assert_eq(ModuleAssembly.get_instances(root).size(), 1)
	assert_true(root.module_connections.is_empty())
	var wrong_opening := catalog[1].duplicate(true) as PrefabMetadata
	wrong_opening.sockets[0]["opening"] = Vector2(3, 3)
	assert_false(ModuleAssembly.place_module(root, wrong_opening, "airlock", "out", "in").success)
	assert_eq(ModuleAssembly.get_instances(root).size(), 1)
	assert_true(root.module_connections.is_empty())
	assert_true(ModuleAssembly.place_module(root, catalog[1], "airlock", "out", "in").success)
	var before: Array[Dictionary] = root.module_connections.duplicate(true)
	assert_false(
		ModuleAssembly.place_module(root, catalog[2], "airlock", "out", "in").success,
		"An occupied socket cannot be reused"
	)
	assert_eq(ModuleAssembly.get_instances(root).size(), 2)
	assert_eq(root.module_connections, before, "Failed attachment must preserve existing graph")
	EditorGlobals._runtime_undo_redo.clear_history()
	EditorGlobals._runtime_undo_redo = saved_history
	root.free()


func test_elevated_mission_sockets_connect_and_reject_vertical_seam_gaps() -> void:
	var document: Node3D = load("res://game/levels/breakwater_mission.tscn").instantiate()
	document.authoring_mode = true
	add_child_autofree(document)
	assert_true(
		ModuleAssembly.validate_level(document).valid,
		"The mission's lateral and elevated walk sockets must share their actual landing geometry"
	)
	var gallery := document.get_node("Return_Gallery") as ModuleInstance
	gallery.position.y += 0.5
	assert_false(
		ModuleAssembly.validate_level(document).valid,
		"An elevated seam cannot accept a half-metre vertical gap"
	)


func test_elevated_socket_opening_cannot_extend_through_the_ceiling() -> void:
	var document: Node3D = LevelRootScript.new()
	var module := ModuleInstance.new()
	module.instance_id = "landing"
	module.definition = PrefabMetadata.new()
	module.definition.scene_path = "res://game/levels/modules/breakwater/mission/return.tscn"
	module.definition.module_id = "landing"
	module.definition.dimensions = Vector3(10, 8, 10)
	module.definition.sockets = [
		{
			"id": "upper",
			"kind": "walk",
			"local_transform": Transform3D(Basis.IDENTITY, Vector3(0, 4, -5)),
			"opening": Vector2(4, 3),
			"clearance": AABB(Vector3(-2, 4, -6), Vector3(4, 3, 2))
		}
	]
	document.add_child(module)
	add_child_autofree(document)
	assert_true(ModuleAssembly.validate_level(document).valid)
	module.definition.sockets[0].local_transform.origin.y = 6
	module.definition.sockets[0].clearance.position.y = 6
	assert_false(
		ModuleAssembly.validate_level(document).valid,
		"Valid floor position is insufficient when the full opening exceeds the module ceiling"
	)


func test_duplicated_mission_module_keeps_its_own_objective_prerequisites() -> void:
	var saved_history := EditorGlobals._runtime_undo_redo
	EditorGlobals._runtime_undo_redo = UndoRedo.new()
	var document: Node3D = LevelRootScript.new()
	document.authoring_mode = true
	add_child(document)
	var definition := (
		load("res://game/levels/modules/breakwater/mission/pump.tres") as PrefabMetadata
	)
	var first := ModuleAssembly.place_module(document, definition)
	var second := ModuleAssembly.place_module(document, definition, "pump", "out", "in")
	assert_true(first.success)
	assert_true(second.success)
	var mission := MissionMgr.get_instance()
	var previous := mission.capture_runtime_state()
	var previous_level := mission.mission_level
	assert_true(mission.start_document_mission(document))
	var checkpoint := mission.capture_runtime_state()
	checkpoint.state["pump/maintenance_key"] = 1
	checkpoint.state["pump/encounter_clear"] = 1
	assert_true(mission.restore_runtime_state(checkpoint, document))
	assert_true(mission.can_activate_actor(document.find_actor("pump/power_switch")))
	assert_false(
		mission.can_activate_actor(document.find_actor("pump_2/power_switch")),
		"Saved progress in the first room cannot unlock the duplicated room's objectives"
	)
	mission.restore_runtime_state(previous, previous_level)
	EditorGlobals._runtime_undo_redo.clear_history()
	EditorGlobals._runtime_undo_redo = saved_history
	document.free()
