extends ModusGutTestBase

const EmbeddedEditorScript := preload("res://game/editor/embedded_level_editor.gd")
const GlobalsScript := preload("res://shared/editor_core/core/editor_globals.gd")
const PreviewScript := preload("res://shared/editor_core/tools/placement_preview.gd")


func before_each() -> void:
	await modus_setup()
	GlobalsScript._runtime_undo_redo = null


func after_each() -> void:
	if is_instance_valid(GlobalsScript._runtime_undo_redo):
		GlobalsScript._runtime_undo_redo.clear_history()
	GlobalsScript.set_runtime_root(null)
	GlobalsScript.set_runtime_camera(null)
	GlobalsScript._runtime_undo_redo = null
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	modus_teardown()


func test_preview_escape_is_read_only_and_enter_repeat_commits_once() -> void:
	var editor := _editor()
	var panel: ModuleAuthoringPanel = editor.module_panel
	var history: UndoRedo = GlobalsScript.get_undo_redo()
	var version := history.get_version()
	var before := PackedScene.new()
	assert_eq(before.pack(editor.level_root), OK)
	_press(panel, "Preview socket placement")
	var during := PackedScene.new()
	assert_eq(during.pack(editor.level_root), OK)
	assert_eq(during.get_state().get_node_count(), before.get_state().get_node_count())
	assert_eq(history.get_version(), version)
	_key(editor, KEY_ESCAPE)
	assert_false(panel.is_module_preview_active())
	assert_eq(ModuleAssembly.get_instances(editor.level_root).size(), 0)
	assert_eq(history.get_version(), version, "Cancel must not write history")
	assert_true(editor._replacement_previews.is_empty())

	_press(panel, "Preview socket placement")
	_key(editor, KEY_ENTER, true, false, false)
	_key(editor, KEY_ENTER, true, true)
	_key(editor, KEY_ENTER, false, false)
	assert_eq(ModuleAssembly.get_instances(editor.level_root).size(), 1)
	assert_false(panel.is_module_preview_active())
	assert_true(editor._replacement_previews.is_empty())
	history.undo()
	assert_eq(ModuleAssembly.get_instances(editor.level_root).size(), 0)
	assert_false(history.has_undo(), "Exactly one placement transaction is recorded")
	history.redo()
	assert_eq(ModuleAssembly.get_instances(editor.level_root).size(), 1)


func test_lost_socket_and_stale_pose_cannot_commit() -> void:
	var editor := _editor()
	var panel: ModuleAuthoringPanel = editor.module_panel
	_press(panel, "Place module")
	var original := ModuleAssembly.get_instances(editor.level_root)[0]
	var history: UndoRedo = GlobalsScript.get_undo_redo()
	var version := history.get_version()
	_press(panel, "Preview socket placement")
	panel.update_preview_target_from_ray(Vector3(1000, 1000, 1000), Vector3.UP)
	panel.confirm_module_preview()
	assert_eq(ModuleAssembly.get_instances(editor.level_root).size(), 1)
	assert_eq(history.get_version(), version)
	assert_true(editor._replacement_previews.is_empty())

	var socket_position: Vector3 = (
		(original.global_transform * original.get_socket("out").local_transform).origin
	)
	panel.update_preview_target_from_ray(socket_position + Vector3.UP * 10, Vector3.DOWN)
	assert_false(editor._replacement_previews.is_empty(), "A valid socket restores the ghost")
	original.position.x += 1.0
	panel.confirm_module_preview()
	assert_eq(
		ModuleAssembly.get_instances(editor.level_root).size(),
		1,
		"A changed target cannot place at an unseen pose"
	)
	assert_eq(history.get_version(), version)
	assert_false(panel.is_module_preview_active())
	assert_true(editor._replacement_previews.is_empty())


func test_pin_selection_and_replacement_preview_survive_mouse_motion_not_history() -> void:
	var editor := _editor()
	var panel: ModuleAuthoringPanel = editor.module_panel
	_press(panel, "Place module")
	_press(panel, "Place module")
	var rooms := ModuleAssembly.get_instances(editor.level_root)
	assert_eq(rooms.size(), 2)
	if rooms.size() != 2:
		return
	var selected := rooms[1]
	_select(panel._target, selected.instance_id)
	_press(panel, "Toggle pin on selected module")
	assert_true(selected.pinned)
	assert_eq(panel._target.get_item_metadata(panel._target.selected), selected.instance_id)
	_press(panel, "Toggle pin on selected module")
	assert_false(selected.pinned, "A repeated toggle must address the same selected room")
	assert_eq(panel._target.get_item_metadata(panel._target.selected), selected.instance_id)
	_press(panel, "Toggle pin on selected module")

	var old_unpinned := rooms[0]
	var graph: Array = editor.level_root.module_connections.duplicate(true)
	var pose := old_unpinned.transform
	_press(panel, "Preview selected replacement")
	assert_true(panel.is_module_preview_active())
	var ghosts: Array = editor._replacement_previews.duplicate()
	panel.update_preview_target_from_ray(Vector3(0, 10, -8), Vector3.DOWN)
	assert_eq(
		editor._replacement_previews, ghosts, "Mouse targeting must not replace regeneration ghosts"
	)
	_key(editor, KEY_ENTER)
	rooms = ModuleAssembly.get_instances(editor.level_root)
	assert_eq(rooms.size(), 2)
	assert_same(
		_room(editor.level_root, selected.instance_id),
		selected,
		"Pinned room identity must survive UI confirmation"
	)
	assert_ne(_room(editor.level_root, old_unpinned.instance_id), old_unpinned)
	assert_eq(_room(editor.level_root, old_unpinned.instance_id).transform, pose)
	assert_eq(editor.level_root.module_connections, graph)
	var history: UndoRedo = GlobalsScript.get_undo_redo()
	history.undo()
	assert_same(_room(editor.level_root, old_unpinned.instance_id), old_unpinned)
	history.redo()
	assert_ne(_room(editor.level_root, old_unpinned.instance_id), old_unpinned)
	_press(panel, "Preview selected replacement")
	history.undo()
	assert_false(panel.is_module_preview_active())
	assert_true(editor._replacement_previews.is_empty())
	assert_true(editor._socket_highlights.is_empty())


func test_rotation_mode_document_and_close_clear_or_refresh_preview() -> void:
	var editor := _editor()
	var panel: ModuleAuthoringPanel = editor.module_panel
	_press(panel, "Preview socket placement")
	var before: Transform3D = editor._replacement_previews[0].preview_node.global_transform
	_select_index(panel._rotation, 1)
	var after: Transform3D = editor._replacement_previews[0].preview_node.global_transform
	assert_false(before.is_equal_approx(after), "Changing rotation must refresh the visible pose")
	_select_index(panel._mode, 1)
	assert_false(panel.is_module_preview_active())
	assert_true(editor._replacement_previews.is_empty())
	_select_index(panel._mode, 0)
	_press(panel, "Preview socket placement")
	assert_true(editor.new_level())
	panel.confirm_module_preview()
	assert_eq(ModuleAssembly.get_instances(editor.level_root).size(), 0)
	assert_false(GlobalsScript.get_undo_redo().has_undo())
	_press(panel, "Preview socket placement")
	editor.close()
	assert_false(panel.is_module_preview_active())
	assert_true(editor._replacement_previews.is_empty())
	assert_true(editor._socket_highlights.is_empty())


func test_scene_ghost_never_runs_actor_initialization_or_enters_physics() -> void:
	var actor_script := GDScript.new()
	actor_script.source_code = 'extends Node3D\nfunc _init():\n\tEngine.set_meta("ghost_actor_calls", int(Engine.get_meta("ghost_actor_calls", 0)) + 1)\nfunc _ready():\n\tEngine.set_meta("ghost_actor_calls", int(Engine.get_meta("ghost_actor_calls", 0)) + 1)\n'
	assert_eq(actor_script.reload(), OK)
	var source := Node3D.new()
	source.name = "Actor"
	source.set_script(actor_script)
	source.add_to_group("ghost_gameplay_actors")
	var body := StaticBody3D.new()
	body.name = "Body"
	source.add_child(body)
	body.owner = source
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	body.add_child(shape)
	shape.owner = source
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	body.add_child(mesh)
	mesh.owner = source
	var csg := CSGBox3D.new()
	csg.use_collision = true
	csg.position.x = 3
	source.add_child(csg)
	csg.owner = source
	var scene := PackedScene.new()
	assert_eq(scene.pack(source), OK)
	var calls: int = Engine.get_meta("ghost_actor_calls", 0)
	source.free()
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	add_child_autofree(viewport)
	var preview := PreviewScript.new()
	viewport.add_child(preview)
	preview.start_preview(scene)
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_eq(
		Engine.get_meta("ghost_actor_calls", 0),
		calls,
		"Neither _init nor _ready may execute in a ghost"
	)
	assert_true(get_tree().get_nodes_in_group("ghost_gameplay_actors").is_empty())
	var space := viewport.find_world_3d().direct_space_state
	for x in [0.0, 3.0]:
		var query := PhysicsRayQueryParameters3D.create(Vector3(x, 5, 0), Vector3(x, -5, 0))
		query.collide_with_areas = true
		assert_true(
			space.intersect_ray(query).is_empty(),
			"Neither body nor CSG collision may enter the preview world"
		)
	preview.clear_preview()
	assert_false(preview.is_active)
	Engine.remove_meta("ghost_actor_calls")


func _editor() -> EmbeddedLevelEditor:
	var editor: EmbeddedLevelEditor = EmbeddedEditorScript.new()
	add_child_autofree(editor)
	editor.open()
	_select(editor.module_panel._module, "airlock")
	return editor


func _press(panel: Control, text: String) -> void:
	for button in panel.find_children("*", "Button", true, false):
		if button.text == text:
			button.pressed.emit()
			return
	fail_test("Missing module authoring button: " + text)


func _select(option: OptionButton, value: String) -> void:
	for index in option.item_count:
		if option.get_item_metadata(index) == value:
			_select_index(option, index)
			return
	fail_test("Missing module authoring option: " + value)


func _room(document: Node3D, instance_id: String) -> ModuleInstance:
	for instance in ModuleAssembly.get_instances(document):
		if instance.instance_id == instance_id:
			return instance
	return null


func _select_index(option: OptionButton, index: int) -> void:
	option.select(index)
	option.item_selected.emit(index)


func _key(
	editor: EmbeddedLevelEditor,
	code: Key,
	pressed: bool = true,
	echo: bool = false,
	release_after: bool = true
) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = pressed
	event.echo = echo
	editor._input(event)
	if pressed and not echo and release_after:
		var release := InputEventKey.new()
		release.keycode = code
		editor._input(release)
