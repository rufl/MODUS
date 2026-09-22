extends Control
class_name EmbeddedLevelEditor

signal editor_closed
signal level_saved(path: String)
signal level_loaded(path: String)

const EditorState = preload("res://shared/editor_core/core/editor_state.gd")
const AssetRegistry = preload("res://shared/editor_core/core/asset_registry.gd")
const GridSystemScript = preload("res://shared/editor_core/core/grid_system.gd")
const SelectionManagerScript = preload("res://shared/editor_core/core/selection_manager.gd")
const EditorFeaturesScript = preload("res://shared/editor_core/core/editor_features.gd")
const AssetPaletteDock = preload("res://shared/editor_core/ui/asset_palette_dock.tscn")
const ToolbarDock = preload("res://shared/editor_core/ui/toolbar_dock.tscn")
const LevelRootScript = preload("res://shared/editor_core/nodes/level_root.gd")
const ModuleAssemblyScript = preload("res://shared/editor_core/core/module_assembly.gd")
const ModulePanelScript = preload("res://shared/editor_core/ui/module_authoring_panel.gd")
const MapPrefabSystemScript = preload("res://game/scripts/map_generator/prefab_system.gd")
const GenerationConfigScript = preload("res://game/scripts/map_generator/generation_config.gd")

var editor_state: Node
var asset_registry: Node
var grid_system: Node
var selection_manager: Node
var editor_features: Node  ## Unified features controller
var generator_prefab_system: RefCounted
var _map_generator: Node
var _replacement_capabilities: Array[String] = ["walk"]
var _replacement_capabilities_configured := false
var palette_panel: Control
var toolbar_panel: Control
var hotbar: Control
var viewport_container: SubViewportContainer
var sub_viewport: SubViewport
var editor_camera: Camera3D
var level_root: Node3D
var _environment_panel: PanelContainer
var _env_interface: Control
var module_panel: VBoxContainer
var _author_surface: Control
var _hotbar_container: HBoxContainer
var _play_overlay: Control
var _play_session: Node3D
var _play_starting: bool = false
var _document_error: String = ""
var _replacement_previews: Array[PlacementPreview] = []
var _socket_highlights: Array[CSGSphere3D] = []

var _is_active: bool = false


func _ready() -> void:
	name = "EmbeddedLevelEditor"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_setup_layout()
	_init_systems()
	_init_ui()
	_init_viewport()
	_finish_ui()
	EditorGlobals.get_undo_redo().version_changed.connect(_on_history_changed)

	# Start hidden until activated
	visible = false
	editor_features.process_mode = Node.PROCESS_MODE_DISABLED
	_author_surface.process_mode = Node.PROCESS_MODE_DISABLED


func _setup_layout() -> void:
	_author_surface = Control.new()
	_author_surface.set_anchors_preset(Control.PRESET_FULL_RECT)
	_author_surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_author_surface)
	# Main horizontal container
	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	_author_surface.add_child(hbox)

	# Left: Palette panel
	palette_panel = PanelContainer.new()
	palette_panel.custom_minimum_size.x = 300
	hbox.add_child(palette_panel)

	# Center: Viewport + Toolbar stack
	var center_vbox: VBoxContainer = VBoxContainer.new()
	center_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(center_vbox)

	# Right: Environment panel
	_environment_panel = PanelContainer.new()
	_environment_panel.name = "EnvironmentPanel"
	_environment_panel.custom_minimum_size.x = 320
	_environment_panel.visible = false
	hbox.add_child(_environment_panel)

	# Environment Interface
	var env_interface_script: GDScript = preload(
		"res://game/editor/environment_effect_config_interface.gd"
	)
	if env_interface_script:
		_env_interface = Control.new()
		_env_interface.set_script(env_interface_script)
		_env_interface.name = "EnvironmentInterface"
		_environment_panel.add_child(_env_interface)

	var toolbar_scroll := ScrollContainer.new()
	toolbar_scroll.custom_minimum_size.y = 64
	toolbar_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	center_vbox.add_child(toolbar_scroll)
	toolbar_panel = HBoxContainer.new()
	toolbar_panel.custom_minimum_size.y = 48
	toolbar_scroll.add_child(toolbar_panel)

	# 3D Viewport
	viewport_container = SubViewportContainer.new()
	viewport_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	viewport_container.stretch = true
	viewport_container.gui_input.connect(_on_viewport_gui_input)
	center_vbox.add_child(viewport_container)

	# Hotbar at bottom
	_hotbar_container = HBoxContainer.new()
	_hotbar_container.custom_minimum_size.y = 64
	_hotbar_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_vbox.add_child(_hotbar_container)


func _init_systems() -> void:
	# Editor State (tools, selection, brush size)
	editor_state = EditorState.new()
	editor_state.name = "EditorState"
	add_child(editor_state)

	# Asset Registry (scans available assets)
	asset_registry = AssetRegistry.new()
	asset_registry.name = "AssetRegistry"
	add_child(asset_registry)

	# Grid System (snapping)
	grid_system = GridSystemScript.new()
	grid_system.name = "GridSystem"
	add_child(grid_system)

	# Selection Manager (multi-select, clipboard)
	selection_manager = SelectionManagerScript.new()
	selection_manager.name = "SelectionManager"
	add_child(selection_manager)

	# Editor Features (hotbar, console, preview, actors)
	generator_prefab_system = MapPrefabSystemScript.new()
	generator_prefab_system.load_all_prefabs()
	_map_generator = get_node_or_null("/root/MapGenerator")
	if _map_generator and _map_generator.has_signal("generation_completed"):
		if not _map_generator.generation_completed.is_connected(_on_generation_completed):
			_map_generator.generation_completed.connect(_on_generation_completed)
	editor_features = EditorFeaturesScript.new()
	editor_features.name = "EditorFeatures"
	add_child(editor_features)


func _init_ui() -> void:
	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	palette_panel.add_child(tabs)
	var module_scroll := ScrollContainer.new()
	module_scroll.name = "Modules"
	module_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(module_scroll)
	module_panel = ModulePanelScript.new()
	module_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	module_scroll.add_child(module_panel)
	var assets := VBoxContainer.new()
	assets.name = "Assets"
	tabs.add_child(assets)
	# Asset Palette
	if ResourceLoader.exists(AssetPaletteDock.resource_path):
		var palette: Control = AssetPaletteDock.instantiate()
		assets.add_child(palette)
		if palette.has_method("setup"):
			palette.setup(asset_registry, editor_state)

	# Toolbar
	if ResourceLoader.exists(ToolbarDock.resource_path):
		var toolbar: Control = ToolbarDock.instantiate()
		toolbar_panel.add_child(toolbar)
		if toolbar.has_method("setup"):
			toolbar.setup(editor_state)

		# Connect Toolbar Actions to Features
		if editor_features:
			if toolbar.has_signal("package_requested"):
				toolbar.package_requested.connect(editor_features.package_current_level)
			if toolbar.has_signal("workshop_requested"):
				toolbar.workshop_requested.connect(editor_features.toggle_workshop)
			if toolbar.has_signal("environment_toggled"):
				toolbar.environment_toggled.connect(_on_environment_toggled)

	var play_button := Button.new()
	play_button.text = "Playtest (F5)"
	play_button.custom_minimum_size = Vector2(140, 48)
	play_button.pressed.connect(begin_playtest)
	toolbar_panel.add_child(play_button)

	var generate_button := Button.new()
	generate_button.text = "Generate Candidates"
	generate_button.custom_minimum_size = Vector2(180, 48)
	generate_button.pressed.connect(_on_generate_candidates_pressed)
	toolbar_panel.add_child(generate_button)


func _finish_ui() -> void:
	hotbar = editor_features.get_hotbar()
	if hotbar:
		hotbar.reparent(_hotbar_container)
		hotbar.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		hotbar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for panel: Control in [
		editor_features.command_console,
		editor_features.connection_properties,
		editor_features.workshop_browser
	]:
		if panel:
			panel.reparent(_author_surface)
			panel.hide()
	module_panel.setup(self)


func _init_viewport() -> void:
	# SubViewport for 3D editing
	sub_viewport = SubViewport.new()
	sub_viewport.own_world_3d = true
	sub_viewport.process_mode = Node.PROCESS_MODE_ALWAYS
	sub_viewport.handle_input_locally = true
	sub_viewport.physics_object_picking = true
	sub_viewport.size = Vector2i(1280, 720)
	viewport_container.add_child(sub_viewport)

	# Editor Camera
	editor_camera = Camera3D.new()
	editor_camera.position = Vector3(0, 5, 10)
	editor_camera.current = true
	sub_viewport.add_child(editor_camera)
	editor_camera.look_at(Vector3.ZERO)

	# Lighting
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 45, 0)
	sun.shadow_enabled = true
	sub_viewport.add_child(sun)

	# Level Root (where placed objects go)
	level_root = LevelRootScript.new()
	level_root.name = "LevelRoot"
	level_root.authoring_mode = true
	sub_viewport.add_child(level_root)
	EditorGlobals.set_runtime_root(level_root)
	EditorGlobals.set_runtime_camera(editor_camera)

	# Setup EditorFeatures with all references
	if editor_features:
		editor_features.setup(editor_state, asset_registry, grid_system, level_root, editor_camera)
	if _env_interface:
		_env_interface.set_level_root(level_root)


func get_generator_replacement_entries() -> Array:
	var entries: Array = []
	if generator_prefab_system == null:
		return entries
	for theme: int in GenerationConfig.ThemeType.values():
		for category: String in generator_prefab_system.get_categories(theme):
			entries.append_array(generator_prefab_system.get_prefabs(theme, category))
	return entries


func get_generator_replacement_metadata() -> Array:
	if not _generator_replacement_metadata.is_empty():
		return _generator_replacement_metadata.duplicate(true)
	var metadata: Array = []
	for entry in get_generator_replacement_entries():
		if entry and entry.metadata:
			metadata.append(entry.metadata.to_dict())
	return metadata


func set_generator_replacement_metadata(entries: Array) -> void:
	_generator_replacement_metadata = entries.duplicate(true)
	if module_panel:
		module_panel.refresh_document()


func _on_generation_completed(_map_scene: PackedScene, metadata: Dictionary) -> void:
	if not _replacement_capabilities_configured:
		var replacement_capabilities: Variant = metadata.get("replacement_capabilities", [])
		if replacement_capabilities is Array:
			_replacement_capabilities = replacement_capabilities.duplicate()
	var replacement_catalog: Variant = metadata.get("replacement_catalog", [])
	if replacement_catalog is Array:
		set_generator_replacement_metadata(replacement_catalog)


func get_replacement_capabilities() -> Array[String]:
	if (
		not _replacement_capabilities_configured
		and _map_generator
		and _map_generator.has_method("get_runtime_capabilities")
	):
		return _map_generator.get_runtime_capabilities()
	return _replacement_capabilities.duplicate()


func set_replacement_capabilities(capabilities: Array[String]) -> void:
	_replacement_capabilities = capabilities.duplicate()
	_replacement_capabilities_configured = true
	if module_panel:
		module_panel.refresh_document()


func show_module_preview(
	definition: PrefabMetadata, transform: Transform3D, valid: bool = true
) -> void:
	if editor_features == null or definition == null:
		return
	editor_features.start_placement({"type": "scene", "scene_path": definition.scene_path})
	var preview := editor_features.get_placement_preview()
	if preview and preview.has_method("set_preview_transform"):
		preview.set_preview_transform(transform, valid)


func show_module_previews(
	definitions: Array[PrefabMetadata], transforms: Array[Transform3D]
) -> void:
	clear_module_preview()
	for index in range(mini(definitions.size(), transforms.size())):
		var preview := PlacementPreview.new()
		sub_viewport.add_child(preview)
		preview.start_preview(load(definitions[index].scene_path) as PackedScene)
		preview.set_preview_transform(transforms[index], true)
		_replacement_previews.append(preview)


func clear_module_preview() -> void:
	for preview: PlacementPreview in _replacement_previews:
		preview.queue_free()
	_replacement_previews.clear()
	if editor_features:
		editor_features.clear_placement()


func show_socket_highlight(instance_id: String, socket_id: String) -> void:
	show_socket_highlights([instance_id], [socket_id], true)


func show_socket_highlights(
	instance_ids: Array[String], socket_ids: Array[String], valid: bool = true
) -> void:
	clear_socket_highlight()
	for index in range(mini(instance_ids.size(), socket_ids.size())):
		for instance: ModuleInstance in ModuleAssemblyScript.get_instances(level_root):
			if instance.instance_id != instance_ids[index]:
				continue
			var socket := instance.get_socket(socket_ids[index])
			if socket.is_empty():
				break
			var highlight := CSGSphere3D.new()
			highlight.name = "SocketHighlight"
			highlight.radius = 0.22
			highlight.height = 0.44
			var material := StandardMaterial3D.new()
			material.albedo_color = (
				Color(0.2, 0.9, 0.3, 0.9) if valid else Color(0.95, 0.15, 0.1, 0.9)
			)
			material.emission_enabled = true
			material.emission = Color(0.05, 0.7, 0.1) if valid else Color(0.8, 0.05, 0.02)
			material.emission_energy_multiplier = 2.0
			highlight.material = material
			sub_viewport.add_child(highlight)
			highlight.global_transform = instance.global_transform * socket.local_transform
			_socket_highlights.append(highlight)
			break


func clear_socket_highlight() -> void:
	for highlight: CSGSphere3D in _socket_highlights:
		highlight.queue_free()
	_socket_highlights.clear()


func _process(_delta: float) -> void:
	if not _is_active or is_instance_valid(_play_session) or _play_starting:
		return

	_handle_camera_movement(_delta)


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventMouse:
		_handle_editor_input(event)


func _on_viewport_gui_input(event: InputEvent) -> void:
	if event is InputEventMouse and _is_active and not is_playtesting():
		_handle_editor_input(event)
		viewport_container.accept_event()


func _handle_editor_input(event: InputEvent) -> void:
	if is_instance_valid(_play_session) or _play_starting:
		return
	if not _is_active:
		return
	if event is InputEventMouseMotion and module_panel and module_panel.is_module_preview_active():
		var ray_origin := editor_camera.global_position
		var ray_direction := editor_camera.project_ray_normal(event.position)
		module_panel.update_preview_target_from_ray(ray_origin, ray_direction)
		return
	if event is InputEventKey and event.pressed and module_panel:
		if module_panel.is_module_preview_active():
			if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
				module_panel.confirm_module_preview()
				return
			if event.keycode == KEY_ESCAPE:
				module_panel.cancel_module_preview()
				return
	# Forward to editor features first (for custom tools like Visual Connection)
	if editor_features and editor_features.has_method("handle_3d_input"):
		if editor_features.handle_3d_input(editor_camera, event):
			return

	# Forward to editor state for standard tools
	if editor_state:
		editor_state.handle_3d_input(editor_camera, event, grid_system)

	# Camera rotation (RMB drag)
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		editor_camera.rotation.y -= event.relative.x * 0.005
		editor_camera.rotation.x -= event.relative.y * 0.005
		editor_camera.rotation.x = clamp(editor_camera.rotation.x, -PI / 2, PI / 2)


func _handle_camera_movement(delta: float) -> void:
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		return

	var speed: float = 20.0
	if Input.is_key_pressed(KEY_SHIFT):
		speed *= 2.5

	var velocity: Vector3 = Vector3.ZERO
	if Input.is_key_pressed(KEY_W):
		velocity -= editor_camera.global_transform.basis.z
	if Input.is_key_pressed(KEY_S):
		velocity += editor_camera.global_transform.basis.z
	if Input.is_key_pressed(KEY_A):
		velocity -= editor_camera.global_transform.basis.x
	if Input.is_key_pressed(KEY_D):
		velocity += editor_camera.global_transform.basis.x
	if Input.is_key_pressed(KEY_E):
		velocity += Vector3.UP
	if Input.is_key_pressed(KEY_Q):
		velocity -= Vector3.UP

	editor_camera.global_position += velocity.normalized() * speed * delta


## Open the embedded editor


func open() -> void:
	_is_active = true
	visible = true
	_author_surface.process_mode = Node.PROCESS_MODE_INHERIT
	editor_features.process_mode = Node.PROCESS_MODE_INHERIT
	editor_state.set_editing_mode(true)
	EditorGlobals.set_runtime_root(level_root)
	EditorGlobals.set_runtime_camera(editor_camera)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# Notify network if in multiplayer
	var ns := GameManager.get_core_system("network") as NetworkSvc
	if ns and ns.network_editor:
		ns.network_editor.is_edit_mode = true


## Close the embedded editor


func close() -> void:
	end_playtest()
	clear_module_preview()
	clear_socket_highlight()
	visible = false
	_author_surface.process_mode = Node.PROCESS_MODE_DISABLED
	editor_features.process_mode = Node.PROCESS_MODE_DISABLED
	editor_state.set_editing_mode(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	var ns := GameManager.get_core_system("network") as NetworkSvc
	if ns and ns.network_editor:
		ns.network_editor.is_edit_mode = false

	editor_closed.emit()


## Toggle editor visibility


func toggle() -> void:
	if _is_active:
		close()
	else:
		open()


## Save current level


func save_level(path: String) -> bool:
	if not is_instance_valid(level_root) or is_instance_valid(_play_session) or _play_starting:
		return _fail_document("Cannot save without an editable document.")
	if level_root.has_method("prepare_for_save"):
		level_root.prepare_for_save()
	else:
		LevelRootScript.prepare_ownership(level_root, level_root)
	var packed := PackedScene.new()
	var pack_error := packed.pack(level_root)
	if pack_error != OK:
		return _fail_document("Failed to pack level: %s" % pack_error)
	var save_error := ResourceSaver.save(packed, path)
	if save_error != OK:
		return _fail_document("Failed to save '%s': %s" % [path, save_error])
	_document_error = ""
	level_saved.emit(path)
	return true


## Load a level


func load_level(path: String) -> bool:
	if is_instance_valid(_play_session) or _play_starting:
		return _fail_document("Return to editing before opening a level.")
	if not ResourceLoader.exists(path):
		return _fail_document("Level does not exist: %s" % path)
	# Bypass cached resources: opening after Save As must read the actual file.
	var resource := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if not resource is PackedScene or not resource.can_instantiate():
		return _fail_document("Not an instantiable level scene: %s" % path)
	var candidate: Node = resource.instantiate()
	if not candidate is Node3D:
		candidate.free()
		return _fail_document("Level root must be a Node3D.")
	if candidate.get_script() == null:
		candidate.set_script(LevelRootScript)
	if not candidate.has_method("get_channel_system"):
		candidate.free()
		return _fail_document("Level root must implement the document channel contract.")
	var validation := ModuleAssemblyScript.validate_level(candidate)
	if not validation.valid:
		candidate.free()
		return _fail_document("\n".join(validation.errors))
	var channel_errors: Array[String] = candidate.get_channel_system().validate_data(
		candidate.channel_data
	)
	if not channel_errors.is_empty():
		candidate.free()
		return _fail_document("\n".join(channel_errors))
	# Staging is complete before touching selection, history, globals or the old root.
	_replace_document(candidate)
	_document_error = ""
	level_loaded.emit(path)
	return true


func new_level() -> bool:
	if is_instance_valid(_play_session) or _play_starting:
		return _fail_document("Return to editing before creating a level.")
	var candidate := LevelRootScript.new()
	candidate.name = "LevelRoot"
	_replace_document(candidate)
	_document_error = ""
	return true


func _replace_document(candidate: Node3D) -> void:
	selection_manager.clear_selection()
	selection_manager.clipboard.clear()
	selection_manager.clipboard_changed.emit()
	selection_manager.is_box_selecting = false
	editor_state.clear_selection()
	editor_features.clear_placement()
	if editor_features.visual_connection_tool:
		editor_features.visual_connection_tool.cancel_connection()
	EditorGlobals.get_undo_redo().clear_history()
	var previous := level_root
	if is_instance_valid(previous) and previous.get_parent():
		previous.get_parent().remove_child(previous)
	level_root = candidate
	level_root.authoring_mode = true
	sub_viewport.add_child(level_root)
	EditorGlobals.set_runtime_root(level_root)
	EditorGlobals.set_runtime_camera(editor_camera)
	editor_features.set_level_root(level_root)
	editor_features.set_camera(editor_camera)
	if _env_interface:
		_env_interface.set_level_root(level_root)
	if is_instance_valid(previous):
		previous.free()
	_on_history_changed()


func _on_history_changed() -> void:
	if is_instance_valid(level_root) and level_root.has_method("freeze_authoring"):
		level_root.freeze_authoring()
	if editor_features and is_instance_valid(editor_features.connection_renderer):
		editor_features.connection_renderer.refresh_all()
	if is_instance_valid(module_panel) and is_instance_valid(level_root):
		module_panel.refresh_document()
	if _env_interface:
		_env_interface.set_level_root(level_root)


func _fail_document(message: String) -> bool:
	_document_error = message
	push_warning("EmbeddedLevelEditor: " + message)
	if is_inside_tree() and visible:
		var dialog := AcceptDialog.new()
		dialog.title = "Level Operation Failed"
		dialog.dialog_text = message
		dialog.confirmed.connect(dialog.queue_free)
		add_child(dialog)
		dialog.popup_centered()
	return false


func get_document_error() -> String:
	return _document_error


func is_playtesting() -> bool:
	return _play_starting or is_instance_valid(_play_session)


func generate_replacement_candidates(seed: String = "editor-preview") -> bool:
	if _map_generator == null or not _map_generator.has_method("generate_map"):
		return false
	if _map_generator.get("is_generating"):
		return false
	var config := GenerationConfigScript.new()
	config.map_seed = seed
	_map_generator.generate_map(seed, config)
	return true


func _on_generate_candidates_pressed() -> void:
	generate_replacement_candidates()


func begin_playtest() -> bool:
	if is_instance_valid(_play_session) or _play_starting or not is_instance_valid(level_root):
		return false
	_play_starting = true
	editor_state.set_editing_mode(false)
	editor_features.process_mode = Node.PROCESS_MODE_DISABLED
	_author_surface.process_mode = Node.PROCESS_MODE_DISABLED
	_author_surface.hide()
	_play_overlay = Control.new()
	_play_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_play_overlay)
	var play_container := SubViewportContainer.new()
	play_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	play_container.stretch = true
	play_container.offset_top = 64
	play_container.focus_mode = Control.FOCUS_ALL
	_play_overlay.add_child(play_container)
	var play_viewport := SubViewport.new()
	play_viewport.own_world_3d = true
	play_viewport.handle_input_locally = false
	play_viewport.size = Vector2i(size)
	play_container.add_child(play_viewport)
	var session_script: GDScript = load("res://game/levels/level_play_session.gd")
	_play_session = session_script.new()
	play_viewport.add_child(_play_session)
	_play_session.session_finished.connect(end_playtest, CONNECT_DEFERRED)
	var return_button := Button.new()
	return_button.text = "Return to Editor (Esc)"
	return_button.position = Vector2(16, 16)
	return_button.custom_minimum_size = Vector2(220, 48)
	return_button.disabled = true
	return_button.pressed.connect(end_playtest)
	_play_overlay.add_child(return_button)
	var started: bool = await _play_session.start_document(level_root)
	_play_starting = false
	if is_instance_valid(return_button):
		return_button.disabled = false
	if not started:
		end_playtest()
		return _fail_document("Playtest could not initialize this document.")
	play_container.grab_focus()
	return true


func end_playtest() -> void:
	if is_instance_valid(_play_session):
		_play_session.stop()
		_play_session.queue_free()
	_play_session = null
	if is_instance_valid(_play_overlay):
		_play_overlay.queue_free()
	_play_overlay = null
	if not is_instance_valid(_author_surface):
		return
	_author_surface.show()
	editor_features.process_mode = (
		Node.PROCESS_MODE_INHERIT if _is_active else Node.PROCESS_MODE_DISABLED
	)
	_author_surface.process_mode = (
		Node.PROCESS_MODE_INHERIT if _is_active else Node.PROCESS_MODE_DISABLED
	)
	editor_state.set_editing_mode(_is_active)
	EditorGlobals.set_runtime_root(level_root)
	EditorGlobals.set_runtime_camera(editor_camera)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _input(event: InputEvent) -> void:
	if not _is_active or not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_ESCAPE and is_instance_valid(_play_session) and not _play_starting:
		get_viewport().set_input_as_handled()
		end_playtest()
	elif event.keycode == KEY_F5 and not is_playtesting():
		get_viewport().set_input_as_handled()
		begin_playtest()


func _exit_tree() -> void:
	var history := EditorGlobals.get_undo_redo()
	if history.version_changed.is_connected(_on_history_changed):
		history.version_changed.disconnect(_on_history_changed)
	if is_instance_valid(_play_session):
		_play_session.stop()
	if EditorGlobals.get_edited_scene_root() == level_root:
		history.clear_history()
		EditorGlobals.set_runtime_root(null)
		EditorGlobals.set_runtime_camera(null)


func _on_environment_toggled(active: bool) -> void:
	if _environment_panel:
		_environment_panel.visible = active
		if active and _env_interface and _env_interface.has_method("refresh_zone_list"):
			_env_interface.refresh_zone_list()
