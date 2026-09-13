extends ModusGutTestBase

const EditorGlobalsScript := preload("res://shared/editor_core/core/editor_globals.gd")
const PaintBrushScript := preload("res://shared/editor_core/tools/paint_brush.gd")
const TransformInspectorScript := preload(
	"res://shared/editor_core/gizmos/entity_transform_inspector.gd"
)

const SelectionManagerScript := preload("res://shared/editor_core/core/selection_manager.gd")
const EditorStateScript := preload("res://shared/editor_core/core/editor_state.gd")
const LevelSaveSystemScript := preload("res://shared/editor_core/data/level_save_system.gd")
const VisualScriptEditorScript := preload(
	"res://shared/editor_core/scripting/visual_script_editor.gd"
)
const EmbeddedLevelEditorScript := preload("res://game/editor/embedded_level_editor.gd")
const ToolbarDockScript := preload("res://shared/editor_core/ui/toolbar_dock.gd")
const HotbarScript := preload("res://shared/editor_core/ui/hotbar.gd")
const EditorFeaturesScript := preload("res://shared/editor_core/core/editor_features.gd")
const EnvironmentZoneEditorScript := preload("res://game/editor/ui/environment_zone_editor.gd")
const StandaloneEditorScript := preload("res://standalone/editor/standalone_main.gd")
const AdvancedBrushScript := preload("res://game/editor/advanced_brush_tool.gd")
const DamageCalculatorScript := preload("res://game/scripts/features/combat/damage_calculator.gd")
const DamageInfoScript := preload("res://game/scripts/features/combat/damage_info.gd")
const GenerationConfigScript := preload("res://game/scripts/map_generator/generation_config.gd")
const GenerationContextScript := preload("res://game/scripts/map_generator/generation_context.gd")
const GameplayElementPlacerScript := preload(
	"res://game/scripts/map_generator/gameplay_element_placer.gd"
)

const ActorBaseScript := preload("res://shared/editor_core/actors/actor_base.gd")
const LevelRootScript := preload("res://shared/editor_core/nodes/level_root.gd")


func before_each() -> void:
	await modus_setup()
	EditorGlobalsScript._runtime_undo_redo = null


func after_each() -> void:
	if is_instance_valid(EditorGlobalsScript._runtime_undo_redo):
		EditorGlobalsScript._runtime_undo_redo.clear_history()
	EditorGlobalsScript._runtime_undo_redo = null
	modus_teardown()


func test_standalone_block_placement_supports_undo_and_redo() -> void:
	var level_root := Node3D.new()
	add_child_autofree(level_root)
	var brush: BlockBrush = BlockBrush.new()

	var block: CSGShape3D = brush.place_block(Vector3.ZERO, level_root)
	assert_not_null(block, "Standalone placement should create a block")
	assert_eq(level_root.get_child_count(), 1, "Placement should add one live block")

	var undo: UndoRedo = EditorGlobalsScript.get_undo_redo()
	assert_true(undo.has_undo(), "Standalone placement should create an undo action")
	undo.undo()
	assert_eq(level_root.get_child_count(), 0, "Undo should remove the placed block")
	assert_true(undo.has_redo(), "Undo should expose redo")
	undo.redo()
	assert_eq(level_root.get_child_count(), 1, "Redo should restore the placed block")

	brush = null


func test_standalone_erase_supports_undo() -> void:
	var level_root := Node3D.new()
	add_child_autofree(level_root)
	var target := Node3D.new()
	level_root.add_child(target)
	var eraser: EraserBrush = EraserBrush.new()

	eraser._erase_node(target)
	assert_eq(level_root.get_child_count(), 0, "Erase should remove the target")

	var undo: UndoRedo = EditorGlobalsScript.get_undo_redo()
	assert_true(undo.has_undo(), "Standalone erase should create an undo action")
	undo.undo()
	assert_eq(level_root.get_child_count(), 1, "Undo should restore the erased target")


func test_standalone_paint_supports_undo_and_redo() -> void:
	var target := CSGBox3D.new()
	add_child_autofree(target)
	var brush: PaintBrush = PaintBrush.new()
	brush.set_material(StandardMaterial3D.new())

	brush._apply_material(target, Vector3.UP)
	assert_not_null(target.material, "Paint should apply a material")

	var undo: UndoRedo = EditorGlobalsScript.get_undo_redo()
	assert_true(undo.has_undo(), "Standalone paint should create an undo action")
	undo.undo()
	assert_null(target.material, "Undo should restore the original material")
	undo.redo()
	assert_not_null(target.material, "Redo should restore the painted material")


func test_standalone_transform_preset_supports_undo_and_redo() -> void:
	var target := Node3D.new()
	add_child_autofree(target)
	TransformInspectorScript._on_rotation_preset(target, 90)
	assert_eq(target.rotation_degrees.y, 90.0, "Transform preset should apply rotation")
	var undo: UndoRedo = EditorGlobalsScript.get_undo_redo()
	assert_true(undo.has_undo(), "Transform preset should create an undo action")
	undo.undo()
	assert_eq(target.rotation_degrees, Vector3.ZERO, "Undo should restore the original rotation")
	undo.redo()
	assert_eq(target.rotation_degrees.y, 90.0, "Redo should restore the preset rotation")


func test_standalone_scale_flip_and_reset_support_history() -> void:
	var target := Node3D.new()
	add_child_autofree(target)

	TransformInspectorScript._on_scale_preset(target, 2.0)
	assert_eq(target.scale, Vector3.ONE * 2.0)
	var undo: UndoRedo = EditorGlobalsScript.get_undo_redo()
	undo.undo()
	assert_eq(target.scale, Vector3.ONE)
	undo.redo()
	assert_eq(target.scale, Vector3.ONE * 2.0)

	TransformInspectorScript._on_flip(target, Vector3(-1, 1, 1))
	assert_eq(target.scale, Vector3(-2, 2, 2))
	undo.undo()
	assert_eq(target.scale, Vector3.ONE * 2.0)

	target.rotation_degrees = Vector3(10, 20, 30)
	TransformInspectorScript._on_reset_transform(target)
	assert_eq(target.rotation_degrees, Vector3.ZERO)
	assert_eq(target.scale, Vector3.ONE)
	undo.undo()
	assert_true(
		target.rotation_degrees.is_equal_approx(Vector3(10, 20, 30)),
		"Undo should restore the prior rotation"
	)
	assert_eq(target.scale, Vector3.ONE * 2.0)


func test_standalone_selection_move_and_delete_support_history() -> void:
	var level_root := Node3D.new()
	add_child_autofree(level_root)
	var target := Node3D.new()
	level_root.add_child(target)
	var manager: Node = SelectionManagerScript.new()
	add_child_autofree(manager)

	manager.select(target)
	manager.move_selection(Vector3(2, 0, 0))
	assert_eq(target.position, Vector3(2, 0, 0))

	var undo: UndoRedo = EditorGlobalsScript.get_undo_redo()
	undo.undo()
	assert_eq(target.position, Vector3.ZERO, "Undo should restore the selected node position")
	undo.redo()
	assert_eq(target.position, Vector3(2, 0, 0), "Redo should restore the move")

	manager.delete_selected()
	assert_eq(level_root.get_child_count(), 0, "Delete should remove the selected node")
	await get_tree().process_frame
	undo.undo()
	assert_eq(level_root.get_child_count(), 1, "Undo should restore the deleted node")


func test_standalone_paste_uses_clipboard_centroid_and_history() -> void:
	var source_root := Node3D.new()
	add_child_autofree(source_root)
	var first := CSGBox3D.new()
	first.position = Vector3(10, 0, 0)
	source_root.add_child(first)
	var second := CSGBox3D.new()
	second.position = Vector3(20, 0, 0)
	source_root.add_child(second)
	var manager: Node = SelectionManagerScript.new()
	add_child_autofree(manager)

	var selected: Array[Node3D] = [first, second]
	manager.select_multiple(selected)
	manager.copy()
	var pasted: Array[Node3D] = manager.paste(Vector3(100, 0, 0), source_root)
	await get_tree().process_frame
	assert_true(pasted[0].global_position.is_equal_approx(Vector3(95, 0, 0)))
	assert_true(pasted[1].global_position.is_equal_approx(Vector3(105, 0, 0)))

	var undo: UndoRedo = EditorGlobalsScript.get_undo_redo()
	assert_true(undo.has_undo(), "Paste should create an undo action")
	undo.undo()
	assert_eq(source_root.get_child_count(), 2, "Undo should remove all pasted nodes")
	manager.clear_selection()
	await get_tree().process_frame
	undo.redo()
	assert_true(pasted[0].global_position.is_equal_approx(Vector3(95, 0, 0)))
	assert_true(pasted[1].global_position.is_equal_approx(Vector3(105, 0, 0)))


func test_standalone_duplicate_uses_offset_and_history() -> void:
	var source_root := Node3D.new()
	add_child_autofree(source_root)
	var first := CSGBox3D.new()
	first.position = Vector3(10, 0, 0)
	source_root.add_child(first)
	var second := CSGBox3D.new()
	second.position = Vector3(20, 0, 0)
	source_root.add_child(second)
	var manager: Node = SelectionManagerScript.new()
	add_child_autofree(manager)
	var selected: Array[Node3D] = [first, second]
	manager.select_multiple(selected)

	var duplicated: Array[Node3D] = manager.duplicate_selection(Vector3(1, 0, 1))
	await get_tree().process_frame
	assert_eq(duplicated.size(), 2, "Duplicate should create both selected nodes")
	assert_true(duplicated[0].global_position.is_equal_approx(Vector3(11, 0, 1)))
	assert_true(duplicated[1].global_position.is_equal_approx(Vector3(21, 0, 1)))
	assert_eq(source_root.get_child_count(), 4)

	var undo: UndoRedo = EditorGlobalsScript.get_undo_redo()
	undo.undo()
	manager.clear_selection()
	await get_tree().process_frame
	assert_eq(source_root.get_child_count(), 2, "Undo should remove duplicated nodes")


func test_editor_state_block_placement_uses_runtime_history() -> void:
	var scene_root := Node3D.new()
	add_child_autofree(scene_root)
	EditorGlobalsScript.set_runtime_root(scene_root)
	var state: Node = EditorStateScript.new()
	add_child_autofree(state)
	state.selected_asset = {"id": "block"}
	state.hover_position = Vector3(3, 0, 0)

	assert_eq(state._apply_block_brush(), 1)
	await get_tree().process_frame
	assert_eq(scene_root.get_child_count(), 1, "EditorState should place one block")

	var undo: UndoRedo = EditorGlobalsScript.get_undo_redo()
	undo.undo()
	assert_eq(scene_root.get_child_count(), 0, "Undo should remove the EditorState block")
	await get_tree().process_frame
	undo.redo()
	assert_eq(scene_root.get_child_count(), 1, "Redo after a frame must restore a live block")
	EditorGlobalsScript.set_runtime_root(null)


func test_level_save_load_requires_editor_interface_in_runtime() -> void:
	var scene_root := Node3D.new()
	add_child_autofree(scene_root)
	var save_system: RefCounted = LevelSaveSystemScript.new()
	save_system.setup(scene_root)
	assert_true(save_system.save_level(LevelSaveSystemScript.QUICKSAVE_PATH, false))
	assert_false(save_system.quick_load(), "Runtime mode must not call EditorInterface")
	assert_false(save_system.load_level(LevelSaveSystemScript.QUICKSAVE_PATH))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(LevelSaveSystemScript.QUICKSAVE_PATH))


func test_visual_script_selection_is_runtime_safe() -> void:
	var editor: Control = VisualScriptEditorScript.new()
	add_child_autofree(editor)
	await get_tree().process_frame
	var source := Node.new()
	add_child_autofree(source)
	editor.connection_list.add_item("runtime")
	editor.connection_list.set_item_metadata(0, {"source": source, "channel": "test"})

	var selected: Array[Dictionary] = []
	editor.connection_selected.connect(func(meta: Dictionary) -> void: selected.append(meta))
	editor._on_connection_selected(0)

	assert_eq(selected.size(), 1)
	assert_eq(selected[0].source, source)


func test_editor_state_entity_placement_uses_history() -> void:
	var scene_root := Node3D.new()
	add_child_autofree(scene_root)
	EditorGlobalsScript.set_runtime_root(scene_root)
	var template := Node3D.new()
	var packed := PackedScene.new()
	assert_eq(packed.pack(template), OK)
	template.free()

	var state: Node = EditorStateScript.new()
	add_child_autofree(state)
	state.selected_asset = {"id": "crate", "scene": packed}
	state.hover_position = Vector3(4, 0, 0)
	state._preview_rotation = PI / 2.0

	assert_eq(state._apply_entity_placer(), 1)
	await get_tree().process_frame
	assert_eq(scene_root.get_child_count(), 1)
	assert_true(scene_root.get_child(0).get_meta("level_editor_placed"))
	assert_true(scene_root.get_child(0).position.is_equal_approx(Vector3(4, 0, 0)))
	EditorGlobalsScript.get_undo_redo().undo()
	assert_eq(scene_root.get_child_count(), 0)
	EditorGlobalsScript.set_runtime_root(null)


func test_editor_state_spawn_point_history_and_invalid_type() -> void:
	var scene_root := Node3D.new()
	add_child_autofree(scene_root)
	EditorGlobalsScript.set_runtime_root(scene_root)
	var state: Node = EditorStateScript.new()
	add_child_autofree(state)
	state.selected_asset = {"spawn_type": "player"}
	state._apply_spawn_point()
	await get_tree().process_frame
	assert_eq(scene_root.get_child_count(), 1)
	assert_eq(scene_root.get_child(0).name, "PlayerSpawn")
	EditorGlobalsScript.get_undo_redo().undo()
	assert_eq(scene_root.get_child_count(), 0)

	state.selected_asset = {"spawn_type": "unknown"}
	assert_eq(state._apply_spawn_point(), 0)
	assert_eq(scene_root.get_child_count(), 0)
	EditorGlobalsScript.set_runtime_root(null)


func test_editor_state_tool_navigation_emits_changes() -> void:
	var state: Node = EditorStateScript.new()
	add_child_autofree(state)
	var emitted: Array[int] = []
	state.tool_changed.connect(
		func(tool_type: EditorStateScript.ToolType) -> void: emitted.append(tool_type)
	)

	state.select_tool(EditorStateScript.ToolType.BLOCK_BRUSH)
	state.next_tool()
	state.previous_tool()

	assert_eq(
		emitted,
		[
			EditorStateScript.ToolType.BLOCK_BRUSH,
			EditorStateScript.ToolType.PAINT_BRUSH,
			EditorStateScript.ToolType.BLOCK_BRUSH
		]
	)


func test_editor_state_brush_size_shortcut_stays_positive() -> void:
	var state: Node = EditorStateScript.new()
	add_child_autofree(state)
	state.select_tool(EditorStateScript.ToolType.BLOCK_BRUSH)
	state.set_editing_mode(true)

	var decrease := InputEventKey.new()
	decrease.pressed = true
	decrease.keycode = KEY_BRACKETLEFT
	state.handle_3d_input(null, decrease, null)
	assert_eq(state.brush_size, Vector3i.ONE)

	var increase := InputEventKey.new()
	increase.pressed = true
	increase.keycode = KEY_BRACKETRIGHT
	state.handle_3d_input(null, increase, null)
	assert_eq(state.brush_size, Vector3i(2, 2, 2))


func test_editor_state_escape_clears_tool_and_emits_change() -> void:
	var state: Node = EditorStateScript.new()
	add_child_autofree(state)
	var emitted: Array[int] = []
	state.tool_changed.connect(
		func(tool_type: EditorStateScript.ToolType) -> void: emitted.append(tool_type)
	)
	state.select_tool(EditorStateScript.ToolType.BLOCK_BRUSH)
	state.set_editing_mode(true)

	var escape := InputEventKey.new()
	escape.pressed = true
	escape.keycode = KEY_ESCAPE
	state.handle_3d_input(null, escape, null)

	assert_eq(state.current_tool, EditorStateScript.ToolType.NONE)
	assert_eq(emitted.back(), EditorStateScript.ToolType.NONE)


func test_embedded_editor_two_roundtrips_preserve_document_and_nested_collision() -> void:
	var editor: Control = EmbeddedLevelEditorScript.new()
	add_child_autofree(editor)
	var document: Node3D = editor.level_root
	document.level_name = "Persistent Root"
	document.name = "PersistentDocument"
	document.level_author = "Test Author"
	document.position = Vector3(3, 2, 1)
	document.set_meta("custom_document", {"revision": 7})
	var nested := Node3D.new()
	nested.name = "Nested"
	nested.transform = Transform3D(Basis(Vector3.UP, PI / 2), Vector3(2, 0, -5))
	document.add_child(nested)
	var body := StaticBody3D.new()
	body.name = "Body"
	body.position = Vector3(1, 2, 3)
	nested.add_child(body)
	var collision := CollisionShape3D.new()
	collision.name = "Collision"
	collision.shape = BoxShape3D.new()
	collision.shape.size = Vector3(4, 1, 2)
	body.add_child(collision)
	var source := ActorBaseScript.new()
	source.name = "Source"
	source.actor_id = "switch"
	document.add_child(source)
	var target := ActorBaseScript.new()
	target.name = "Target"
	target.actor_id = "door"
	nested.add_child(target)
	var channel: ChannelSystem = document.get_channel_system()
	channel.create_connection(source, target, "gate")
	channel.set_channel_color("gate", Color.CORNFLOWER_BLUE)
	channel.set_channel_delay("gate", 0.25)
	channel.set_channel_inverted("gate", true)
	channel.set_channel_enabled("gate", false)
	var path := "user://embedded_editor_lifecycle_test.tscn"
	var expected_transform := nested.transform
	for _roundtrip: int in range(2):
		assert_true(editor.save_level(path))
		assert_true(editor.load_level(path))
		document = editor.level_root
		assert_eq(document.name, "PersistentDocument")
		assert_eq(document.level_name, "Persistent Root")
		assert_eq(document.level_author, "Test Author")
		assert_eq(document.position, Vector3(3, 2, 1))
		assert_eq(document.get_meta("custom_document"), {"revision": 7})
		assert_true(document.get_node("Nested").transform.is_equal_approx(expected_transform))
		assert_eq(document.get_node("Nested/Body").position, Vector3(1, 2, 3))
		assert_eq(document.get_node("Nested/Body/Collision").shape.size, Vector3(4, 1, 2))
		assert_eq(document.channel_data.gate.sources, ["switch"])
		assert_eq(document.channel_data.gate.targets, ["door"])
		assert_eq(document.channel_data.gate.delay, 0.25)
		assert_true(document.channel_data.gate.inverted)
		assert_false(document.channel_data.gate.enabled)
		assert_eq(document.channel_data.gate.color, Color.CORNFLOWER_BLUE.to_html())
		channel = document.get_channel_system()
		channel.set_channel_enabled("gate", true)
		channel.set_channel_delay("gate", 0.0)
		channel.set_channel_inverted("gate", false)
		document.authoring_mode = false
		channel.emit("gate")
		assert_eq(document.find_actor("door").activation_count, 1)
		document.authoring_mode = true
		channel.set_channel_enabled("gate", false)
		channel.set_channel_delay("gate", 0.25)
		channel.set_channel_inverted("gate", true)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_failed_open_preserves_document_selection_and_history() -> void:
	var editor: Control = EmbeddedLevelEditorScript.new()
	add_child_autofree(editor)
	var document: Node3D = editor.level_root
	var target := Node3D.new()
	document.add_child(target)
	editor.selection_manager.select(target)
	editor.selection_manager.move_selection(Vector3.RIGHT)
	var invalid_root := Control.new()
	var invalid_scene := PackedScene.new()
	assert_eq(invalid_scene.pack(invalid_root), OK)
	invalid_root.free()
	var path := "user://embedded_editor_invalid_root.tscn"
	assert_eq(ResourceSaver.save(invalid_scene, path), OK)
	assert_false(editor.load_level(path))
	assert_same(editor.level_root, document)
	assert_same(editor.selection_manager.selected_nodes[0], target)
	EditorGlobalsScript.get_undo_redo().undo()
	assert_eq(target.position, Vector3.ZERO)
	assert_true(editor.new_level())
	assert_false(EditorGlobalsScript.get_undo_redo().has_undo())
	assert_false(EditorGlobalsScript.get_undo_redo().has_redo())
	assert_true(editor.selection_manager.selected_nodes.is_empty())
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_editor_toolbar_and_hotbar_build_runtime_controls() -> void:
	var toolbar: HBoxContainer = ToolbarDockScript.new()
	toolbar._create_toolbar()
	assert_eq(toolbar.tool_buttons.size(), 7)
	assert_not_null(toolbar.get_node_or_null("GridSizeLabel"))
	toolbar.free()

	var hotbar: HBoxContainer = HotbarScript.new()
	hotbar._init_slots()
	hotbar._create_ui()
	assert_eq(hotbar.primary_buttons.size(), HotbarScript.MAX_SLOTS)
	assert_eq(hotbar.secondary_buttons.size(), HotbarScript.MAX_SLOTS)
	assert_eq(hotbar.primary_buttons[0].name, "Button")
	hotbar.free()


func test_editor_workshop_browser_uses_panel_container_base() -> void:
	var features: Node = EditorFeaturesScript.new()
	add_child_autofree(features)
	features._init_workshop_system()
	assert_true(features.workshop_browser is PanelContainer)
	assert_eq(features.workshop_browser.name, "WorkshopBrowserPanel")


func test_environment_editor_ignores_preset_actions_without_optional_panel() -> void:
	var editor: Node = EnvironmentZoneEditorScript.new()
	editor.show_preset_manager = false
	editor._on_apply_preset_pressed()
	editor._on_delete_preset_pressed()
	editor.free()


func test_environment_editor_ignores_incomplete_parameter_panel() -> void:
	var editor: Node = EnvironmentZoneEditorScript.new()
	var zone := EnvironmentVolume.new()
	editor._selected_zone = zone
	editor._parameter_panel = PanelContainer.new()
	editor._update_parameter_ui()
	editor._parameter_panel.free()
	zone.free()
	editor.free()


func test_environment_editor_ignores_zone_selection_without_zone_list() -> void:
	var editor: Node = EnvironmentZoneEditorScript.new()
	editor._on_zone_selected()
	editor.free()


func test_environment_editor_ignores_preset_refresh_without_preset_list() -> void:
	var editor: Node = EnvironmentZoneEditorScript.new()
	var preset_manager := PanelContainer.new()
	editor._preset_manager = preset_manager
	editor._update_preset_list()
	preset_manager.free()
	editor.free()


func test_environment_editor_creates_zone_without_optional_zone_list() -> void:
	var editor: Node = EnvironmentZoneEditorScript.new()
	var zone: EnvironmentVolume = editor.create_zone()
	assert_not_null(zone)
	if zone:
		zone.free()
	editor.free()


func test_environment_editor_deletes_zone_without_optional_zone_list() -> void:
	var editor: Node = EnvironmentZoneEditorScript.new()
	var zone := EnvironmentVolume.new()
	assert_true(editor.delete_zone(zone))
	zone.free()
	editor.free()


func test_standalone_editor_uses_runtime_undo_and_redo_menu_actions() -> void:
	var main: Node = StandaloneEditorScript.new()
	var target := Node3D.new()
	var undo: UndoRedo = EditorGlobalsScript.get_undo_redo()
	undo.clear_history()
	undo.create_action("Standalone test")
	undo.add_do_property(target, "position", Vector3.ONE)
	undo.add_undo_property(target, "position", Vector3.ZERO)
	undo.commit_action()
	main._on_edit_menu_pressed(0)
	assert_eq(target.position, Vector3.ZERO)
	main._on_edit_menu_pressed(1)
	assert_eq(target.position, Vector3.ONE)
	target.free()
	main.free()
	undo.clear_history()


func test_standalone_editor_exports_current_level_package() -> void:
	var main: Node = StandaloneEditorScript.new()
	var embedded: Node = EmbeddedLevelEditorScript.new()
	embedded.level_root = LevelRootScript.new()
	embedded.level_root.name = "StandaloneExport"
	embedded.level_root.level_name = "StandaloneExport"
	main._editor = embedded
	var output_dir := "user://standalone_editor_export/"
	var package_path := output_dir + "standalone_export.mdsl"
	DirAccess.make_dir_recursive_absolute(output_dir)
	assert_true(main._export_mod_to_directory(output_dir))
	assert_true(FileAccess.file_exists(package_path))
	DirAccess.remove_absolute(package_path)
	DirAccess.remove_absolute(output_dir)
	embedded.level_root.free()
	embedded.free()
	main.free()


func test_advanced_brush_generates_specialized_meshes() -> void:
	var brush: Node = AdvancedBrushScript.new()
	for brush_type in [
		AdvancedBrushScript.BrushType.STAIRCASE,
		AdvancedBrushScript.BrushType.ARCH,
		AdvancedBrushScript.BrushType.CAPSULE,
	]:
		var shape: Node3D = brush._create_brush_shape(brush_type)
		var mesh: ArrayMesh = shape.mesh
		assert_not_null(mesh)
		assert_gt(mesh.get_surface_count(), 0)
		shape.free()

	var torus: Node3D = brush._create_brush_shape(AdvancedBrushScript.BrushType.TORUS)
	assert_true(torus is CSGTorus3D)
	assert_gt((torus as CSGTorus3D).outer_radius, (torus as CSGTorus3D).inner_radius)
	torus.free()
	brush.free()


func test_advanced_brush_fill_uses_density_and_detached_clear_is_safe() -> void:
	var brush: Node = AdvancedBrushScript.new()
	brush.brush_size = Vector3(2, 2, 2)
	brush.grid_size = 1.0
	brush.brush_density = 1.0
	assert_true(brush._fill_area_with_brush(Vector3.ZERO))
	assert_eq(brush.get_child_count(), 27)
	assert_false(brush._clear_area(Vector3.ZERO))
	assert_false(brush._remove_brush_object(Vector3.ZERO))
	for child: Node in brush.get_children():
		child.free()
	brush.free()


func test_damage_calculator_applies_armor_formula_and_penetration() -> void:
	var calculator: Node = DamageCalculatorScript.new(
		{"bullet": {"armor_penetration": 0.0}},
		{"armor": {"enabled": true, "damage_reduction_formula": "linear", "max_reduction": 0.75}}
	)
	var info: Resource = DamageInfoScript.create(100.0, DamageInfoScript.DamageType.BULLET)
	info.target_armor = 100.0
	assert_almost_eq(calculator.calculate(info), 50.0, 0.01)
	info.armor_penetration = 1.0
	assert_almost_eq(calculator.calculate(info), 100.0, 0.01)
	calculator.free()


func test_generation_config_controls_small_map_monster_floor() -> void:
	var config: Resource = GenerationConfigScript.new()
	assert_eq(config.minimum_monsters, 0)
	config.minimum_monsters = 3
	var context = GenerationContextScript.new()
	context.config = config
	context.grid_size = Vector2i(1, 1)
	var placer = GameplayElementPlacerScript.new()
	assert_eq(placer._calculate_monster_count(context), 3)
