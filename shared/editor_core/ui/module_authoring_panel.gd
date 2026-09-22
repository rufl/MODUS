@tool
class_name ModuleAuthoringPanel
extends VBoxContainer

var _editor: Control
var _catalog: Array[PrefabMetadata] = []
var _module: OptionButton
var _target: OptionButton
var _target_socket: OptionButton
var _source_socket: OptionButton
var _rotation: OptionButton
var _status: Label
var _mode: OptionButton
var _rooms: VBoxContainer
var _gameplay: VBoxContainer
var _source_actor: OptionButton
var _target_actor: OptionButton
var _source_port: OptionButton
var _target_port: OptionButton
var _channel: LineEdit
var _enabled: CheckBox
var _inverted: CheckBox
var _delay: SpinBox
var _color: ColorPickerButton
var _actors: Dictionary = {}
var _preview_target_key := ""
var _preview_active := false
var _regeneration_preview := false
var _pending_regeneration_plans: Array[Dictionary] = []
var _pending_placement: Dictionary = {}
var _preview_document_state: Dictionary = {}
var _generator_replacement_catalog: Array[PrefabMetadata] = []
var _built := false


func setup(editor: Control) -> void:
	_editor = editor
	if not _built:
		_build()
		_built = true
	refresh_document()


func set_external_status(message: String) -> void:
	if _status:
		_status.text = message


func _build() -> void:
	add_theme_constant_override("separation", 8)
	_mode = _option(self, "Authoring mode")
	_mode.add_item("Modules")
	_mode.add_item("Gameplay")
	_mode.item_selected.connect(
		func(index: int) -> void:
			clear_module_preview()
			_rooms.visible = index == 0
			_gameplay.visible = index == 1
	)
	_rooms = VBoxContainer.new()
	_rooms.add_theme_constant_override("separation", 8)
	add_child(_rooms)
	_module = _option(_rooms, "Module definition")
	_target = _option(_rooms, "Attach to module")
	_target_socket = _option(_rooms, "Target socket (free only)")
	_source_socket = _option(_rooms, "New module socket")
	_rotation = _option(_rooms, "Quarter turn (first room; attached sockets must align)")
	for turn in 4:
		_rotation.add_item(str(turn * 90) + " degrees")
	_button(_rooms, "Regenerate unpinned modules", _regenerate_unpinned)
	_button(_rooms, "Regenerate with selected definition", _regenerate_with_selected)
	_button(_rooms, "Check selected replacement", _check_selected_replacement)
	_button(_rooms, "Preview selected replacement", _preview_selected_replacement)
	_button(_rooms, "Place module", _place)
	_button(_rooms, "Preview socket placement", _preview)
	_button(_rooms, "Toggle pin on selected module", _toggle_pin)
	_button(_rooms, "Validate layout", _validate_document)
	_module.item_selected.connect(
		func(_index: int) -> void:
			_refresh_source_sockets()
			_on_placement_option_changed()
	)
	_target.item_selected.connect(
		func(_index: int) -> void:
			_refresh_target_sockets()
			_on_placement_option_changed()
	)
	for option in [_target_socket, _source_socket, _rotation]:
		option.item_selected.connect(func(_index: int) -> void: _on_placement_option_changed())
	_gameplay = VBoxContainer.new()
	_gameplay.add_theme_constant_override("separation", 8)
	_gameplay.visible = false
	add_child(_gameplay)
	_source_actor = _option(_gameplay, "Source actor ID")
	_source_port = _option(_gameplay, "Output port")
	_source_port.add_item("output_channel (activation / deactivation)")
	_target_actor = _option(_gameplay, "Target actor ID")
	_target_port = _option(_gameplay, "Input port")
	_target_actor.item_selected.connect(func(_index: int) -> void: _refresh_input_port())
	_label(_gameplay, "Channel name (new or existing)")
	_channel = LineEdit.new()
	_channel.placeholder_text = "e.g. pump_power"
	_control(_gameplay, _channel)
	_enabled = CheckBox.new()
	_enabled.text = "Channel enabled"
	_enabled.button_pressed = true
	_control(_gameplay, _enabled)
	_inverted = CheckBox.new()
	_inverted.text = "Invert channel value"
	_control(_gameplay, _inverted)
	_label(_gameplay, "Delay (seconds)")
	_delay = SpinBox.new()
	_delay.min_value = 0
	_delay.max_value = 3600
	_delay.step = 0.1
	_control(_gameplay, _delay)
	_label(_gameplay, "Wire color")
	_color = ColorPickerButton.new()
	_color.color = Color(0.2, 0.5, 0.9)
	_control(_gameplay, _color)
	_button(_gameplay, "Connect gameplay actors", _connect_gameplay)
	_button(_gameplay, "Disconnect selected actors", _disconnect_gameplay)
	_button(self, "Undo last edit", _undo)
	_button(self, "Redo last edit", _redo)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_font_size_override("font_size", 16)
	add_child(_status)


func refresh_document() -> void:
	if not _built:
		return
	var selected_module := _selected(_module)
	var selected_target := _selected(_target)
	var selected_source_socket := _selected(_source_socket)
	var selected_target_socket := _selected(_target_socket)
	var selected_source_actor := _selected(_source_actor)
	var selected_target_actor := _selected(_target_actor)
	clear_module_preview()
	_catalog = ModuleAssembly.get_catalog()
	_generator_replacement_catalog.clear()
	if _editor and _editor.has_method("get_generator_replacement_metadata"):
		_generator_replacement_catalog = ModuleAssembly.catalog_from_metadata_dicts(
			_editor.get_generator_replacement_metadata()
		)
		for generated in _generator_replacement_catalog:
			var duplicate := false
			for existing in _catalog:
				if existing.module_id == generated.module_id:
					duplicate = true
					break
			if not duplicate:
				_catalog.append(generated)
	_module.clear()
	for definition in _catalog:
		_module.add_item(definition.module_id.replace("_", " ").capitalize())
		_module.set_item_metadata(_module.item_count - 1, definition.module_id)
	_select_metadata(_module, selected_module)
	_target.clear()
	_actors.clear()
	_source_actor.clear()
	_target_actor.clear()
	var root := _root()
	if root:
		var instances := ModuleAssembly.get_instances(root)
		if instances.is_empty():
			_target.add_item("Origin — first module")
			_target.set_item_metadata(0, "")
		for instance in instances:
			var label := instance.instance_id + (" [pinned]" if instance.pinned else "")
			_target.add_item(label)
			_target.set_item_metadata(_target.item_count - 1, instance.instance_id)
		_collect_actors(root, "")
		for actor_id: String in _actors:
			var actor: Node = _actors[actor_id]
			if not is_instance_valid(actor):
				continue
			if "output_channel" in actor:
				_source_actor.add_item(actor_id)
				_source_actor.set_item_metadata(_source_actor.item_count - 1, actor_id)
			if actor.has_method("on_channel_triggered") or actor.has_method("trigger"):
				_target_actor.add_item(actor_id)
				_target_actor.set_item_metadata(_target_actor.item_count - 1, actor_id)
	_select_metadata(_target, selected_target)
	_select_metadata(_source_actor, selected_source_actor)
	_select_metadata(_target_actor, selected_target_actor)
	_refresh_source_sockets()
	_refresh_target_sockets()
	_select_metadata(_source_socket, selected_source_socket)
	_select_metadata(_target_socket, selected_target_socket)
	_refresh_input_port()
	_status.text = "Select a module and matching free sockets, or wire real actors in Gameplay mode."


func _root() -> Node3D:
	return EditorGlobals.get_edited_scene_root() as Node3D


func _refresh_source_sockets() -> void:
	_source_socket.clear()
	if _module.selected >= 0 and _module.selected < _catalog.size():
		for socket in _catalog[_module.selected].sockets:
			_source_socket.add_item(str(socket.id) + " — " + str(socket.get("kind", "walk")))
			_source_socket.set_item_metadata(_source_socket.item_count - 1, str(socket.id))


func _refresh_target_sockets() -> void:
	_target_socket.clear()
	var root := _root()
	if root == null or not "module_connections" in root:
		return
	var target_id := _selected(_target)
	for instance in ModuleAssembly.get_instances(root):
		if instance.instance_id != target_id:
			continue
		for socket in instance.definition.sockets:
			var used := false
			for edge: Dictionary in root.module_connections:
				if (
					(
						edge.get("from_instance") == target_id
						and edge.get("from_socket") == socket.id
					)
					or (edge.get("to_instance") == target_id and edge.get("to_socket") == socket.id)
				):
					used = true
			if not used:
				_target_socket.add_item(str(socket.id) + " — " + str(socket.get("kind", "walk")))
				_target_socket.set_item_metadata(_target_socket.item_count - 1, str(socket.id))


func _regenerate_unpinned() -> void:
	clear_module_preview()
	var root := _root()
	var captured := ModuleAssembly.build_regeneration_plans(root)
	if not captured.success:
		_status.text = "Regeneration plan failed: " + str(captured.error)
		return
	var result := ModuleAssembly.regenerate_unpinned(root, captured.plans)
	if result.success:
		refresh_document()
		_status.text = (
			"Regenerated "
			+ str(captured.plans.size())
			+ " unpinned module(s). Undo restores the prior layout."
		)
	else:
		_status.text = "Regeneration failed: " + str(result.error)


func _preview_selected_replacement() -> void:
	clear_module_preview()
	_preview_active = true
	_regeneration_preview = true
	if _module.selected < 0 or _module.selected >= _catalog.size():
		_status.text = "Select a replacement module definition first."
		return
	var captured := ModuleAssembly.build_regeneration_plans(
		_root(), [_catalog[_module.selected]], _replacement_capabilities()
	)
	if not captured.success or captured.plans.is_empty():
		_status.text = (
			"Replacement preview failed: "
			+ str(captured.error if not captured.success else "No unpinned modules.")
		)
		return
	var staged := ModuleAssembly.preview_regeneration(_root(), captured.plans)
	if not staged.success:
		if _editor and _editor.has_method("show_socket_highlights"):
			var target_ids: Array[String] = []
			var target_sockets: Array[String] = []
			for plan: Dictionary in captured.plans:
				var target_id := str(plan.get("target_instance_id", ""))
				if target_id.is_empty():
					continue
				target_ids.append(target_id)
				target_sockets.append(str(plan.get("target_socket_id", "")))
			_editor.show_socket_highlights(target_ids, target_sockets, false)
		_status.text = "Replacement preview failed: " + str(staged.error)
		return
	_pending_regeneration_plans = captured.plans.duplicate(true)
	_preview_document_state = _document_state()
	var definitions: Array[PrefabMetadata] = []
	for plan: Dictionary in captured.plans:
		definitions.append(plan.definition)
	if _editor and _editor.has_method("show_module_previews"):
		_editor.show_module_previews(definitions, staged.transforms)
	var first_plan: Dictionary = captured.plans[0]
	_preview_target_key = (
		str(first_plan.get("target_instance_id", ""))
		+ ":"
		+ str(first_plan.get("target_socket_id", ""))
	)
	var target_ids: Array[String] = []
	var target_sockets: Array[String] = []
	for plan: Dictionary in captured.plans:
		var target_id := str(plan.get("target_instance_id", ""))
		if target_id.is_empty():
			continue
		target_ids.append(target_id)
		target_sockets.append(str(plan.get("target_socket_id", "")))
	if _editor and _editor.has_method("show_socket_highlights"):
		_editor.show_socket_highlights(target_ids, target_sockets)
	_status.text = (
		"Previewing "
		+ str(definitions.size())
		+ " compatible replacements. Enter commits; Esc cancels."
	)


func _check_selected_replacement() -> void:
	if _module.selected < 0 or _module.selected >= _catalog.size():
		_status.text = "Select a replacement module definition first."
		return
	var captured := ModuleAssembly.build_regeneration_plans(
		_root(), [_catalog[_module.selected]], _replacement_capabilities()
	)
	var diagnostics := ModuleAssembly.get_replacement_diagnostics(
		_root(), _generator_replacement_catalog, _replacement_capabilities()
	)
	if captured.success:
		var rejection_detail := ""
		if not diagnostics.rejected.is_empty():
			var rejection: Dictionary = diagnostics.rejected[0]
			rejection_detail = (
				" First rejection: "
				+ str(rejection.module_id)
				+ " for "
				+ str(rejection.target_instance_ids)
				+ " (requires "
				+ str(rejection.required_capabilities)
				+ ") — "
				+ str(rejection.error)
				+ "."
			)
		_status.text = (
			"Replacement is valid for "
			+ str(captured.plans.size())
			+ " unpinned module(s); "
			+ str(diagnostics.compatible.size())
			+ " compatible, "
			+ str(diagnostics.rejected.size())
			+ " rejected catalog candidate(s)."
			+ rejection_detail
		)
	else:
		_status.text = "Replacement is invalid: " + str(captured.error)


func _regenerate_with_selected() -> void:
	clear_module_preview()
	if _module.selected < 0 or _module.selected >= _catalog.size():
		_status.text = "Select a replacement module definition first."
		return
	var captured := ModuleAssembly.build_regeneration_plans(
		_root(), [_catalog[_module.selected]], _replacement_capabilities()
	)
	if not captured.success:
		_status.text = "Replacement planning failed: " + str(captured.error)
		return
	var result := ModuleAssembly.regenerate_unpinned(_root(), captured.plans)
	if result.success:
		refresh_document()
		_status.text = (
			"Replaced "
			+ str(captured.plans.size())
			+ " unpinned module(s) with "
			+ _catalog[_module.selected].module_id
			+ "."
		)
	else:
		_status.text = "Replacement failed: " + str(result.error)


func _place() -> void:
	if _preview_active:
		confirm_module_preview()
		return
	if _module.selected < 0 or _module.selected >= _catalog.size():
		_status.text = "No valid module definition is available."
		return
	var result := ModuleAssembly.place_module(
		_root(),
		_catalog[_module.selected],
		_selected(_target),
		_selected(_target_socket),
		_selected(_source_socket),
		_rotation.selected
	)
	if result.success:
		refresh_document()
		_status.text = (
			"Placed " + result.instance.instance_id + ". Undo restores the previous layout."
		)
	else:
		_status.text = "Not placed: " + str(result.error)


func _preview() -> void:
	clear_module_preview()
	_preview_active = true
	if _module.selected < 0 or _module.selected >= _catalog.size():
		_status.text = "Invalid preview: no valid module definition is available. Esc cancels."
		return
	var definition := _catalog[_module.selected]
	var target_id := _selected(_target)
	var target_socket_id := _selected(_target_socket)
	var source_socket_id := _selected(_source_socket)
	var result := ModuleAssembly.preview_module(
		_root(), definition, target_id, target_socket_id, source_socket_id, _rotation.selected
	)
	_preview_target_key = target_id + ":" + target_socket_id
	if _editor and _editor.has_method("show_socket_highlights"):
		var target_ids: Array[String] = [target_id]
		var target_sockets: Array[String] = [target_socket_id]
		_editor.show_socket_highlights(target_ids, target_sockets, result.success)
	if not result.success:
		_status.text = "Invalid socket placement: " + str(result.error) + " Esc cancels."
		return
	_pending_placement = {
		"definition": definition,
		"definition_state": _definition_state(definition),
		"target_instance_id": target_id,
		"target_socket_id": target_socket_id,
		"source_socket_id": source_socket_id,
		"quarter_turns": _rotation.selected,
		"transform": result.transform,
	}
	_preview_document_state = _document_state()
	if _editor and _editor.has_method("show_module_preview"):
		_editor.show_module_preview(definition, _root().global_transform * result.transform, true)
	_status.text = "Valid socket placement. Enter or Place module commits; Esc cancels."


func _on_placement_option_changed() -> void:
	if not _preview_active:
		return
	if _regeneration_preview:
		cancel_module_preview()
		_status.text = "Replacement options changed. Preview the replacement again before committing."
	else:
		_preview()


func rotate_module_preview() -> void:
	if _regeneration_preview:
		_status.text = "Replacement poses are preserved. Esc cancels; Enter commits."
		return
	_rotation.select(posmod(_rotation.selected + 1, 4))
	_on_placement_option_changed()


func is_module_preview_active() -> bool:
	return _preview_active


func confirm_module_preview() -> void:
	if not _preview_active:
		return
	if _pending_placement.is_empty() and _pending_regeneration_plans.is_empty():
		_status.text = "Cannot commit an invalid preview. Select a valid free socket or press Esc."
		return
	if _preview_document_state != _document_state():
		clear_module_preview()
		_status.text = "Preview is stale: the document changed. Preview again before committing."
		return
	if not _pending_regeneration_plans.is_empty():
		var plans := _pending_regeneration_plans.duplicate(true)
		clear_module_preview()
		var result := ModuleAssembly.regenerate_unpinned(_root(), plans)
		if result.success:
			refresh_document()
			_status.text = "Committed all previewed module replacements."
		else:
			_status.text = "Replacement commit failed: " + str(result.error)
		return
	if _pending_placement.definition_state != _definition_state(_pending_placement.definition):
		clear_module_preview()
		_status.text = "Preview definition changed. Preview again before committing."
		return
	var plan := _pending_placement.duplicate()
	var checked := ModuleAssembly.preview_module(
		_root(),
		plan.definition,
		plan.target_instance_id,
		plan.target_socket_id,
		plan.source_socket_id,
		plan.quarter_turns
	)
	clear_module_preview()
	if not checked.success:
		_status.text = "Preview is no longer valid: " + str(checked.error)
		return
	if not (checked.transform as Transform3D).is_equal_approx(plan.transform):
		_status.text = "Preview pose changed. Preview again before committing."
		return
	var result := ModuleAssembly.place_module(
		_root(),
		plan.definition,
		plan.target_instance_id,
		plan.target_socket_id,
		plan.source_socket_id,
		plan.quarter_turns
	)
	if result.success:
		refresh_document()
		_status.text = (
			"Placed " + result.instance.instance_id + ". Undo restores the previous layout."
		)
	else:
		_status.text = "Not placed: " + str(result.error)


func clear_module_preview() -> void:
	_preview_active = false
	_regeneration_preview = false
	_preview_target_key = ""
	_pending_placement.clear()
	_pending_regeneration_plans.clear()
	_preview_document_state.clear()
	if _editor and _editor.has_method("clear_module_preview"):
		_editor.clear_module_preview()
	if _editor and _editor.has_method("clear_socket_highlight"):
		_editor.clear_socket_highlight()


func cancel_module_preview() -> void:
	clear_module_preview()
	_status.text = "Module preview cancelled. The document is unchanged."


func _document_state() -> Dictionary:
	var root := _root()
	if not is_instance_valid(root) or not "module_connections" in root:
		return {}
	var instances: Array[Dictionary] = []
	for instance in ModuleAssembly.get_instances(root):
		(
			instances
			. append(
				{
					"node": instance.get_instance_id(),
					"id": instance.instance_id,
					"transform": instance.transform,
					"pinned": instance.pinned,
					"definition": _definition_state(instance.definition),
				}
			)
		)
	var replacements: Array[Dictionary] = []
	for plan in _pending_regeneration_plans:
		replacements.append(_definition_state(plan.get("definition")))
	return {
		"root": root.get_instance_id(),
		"transform": root.global_transform,
		"version": _history().get_version(),
		"instances": instances,
		"connections": root.module_connections.duplicate(true),
		"replacements": replacements,
	}


func _definition_state(definition: PrefabMetadata) -> Dictionary:
	if definition == null:
		return {}
	return {
		"id": definition.module_id,
		"scene": definition.scene_path,
		"revision": definition.content_revision,
		"dimensions": definition.dimensions,
		"sockets": definition.sockets.duplicate(true),
		"capabilities": definition.required_capabilities.duplicate(),
	}


func update_preview_target_from_ray(ray_origin: Vector3, ray_direction: Vector3) -> void:
	if not _preview_active or _regeneration_preview:
		return
	var root := _root()
	if not is_instance_valid(root):
		clear_module_preview()
		return
	# The empty document's origin placement does not require a socket under the pointer.
	if ModuleAssembly.get_instances(root).is_empty():
		return
	var match := ModuleAssembly.find_free_socket_on_ray(root, ray_origin, ray_direction)
	if match.is_empty():
		clear_module_preview()
		_preview_active = true
		_status.text = "No free socket under the pointer. Aim at a free socket; Esc cancels."
		return
	var target_id := str(match.target_instance_id)
	var socket_id := str(match.target_socket_id)
	var key := target_id + ":" + socket_id
	if key == _preview_target_key:
		return
	_select_metadata(_target, target_id)
	_refresh_target_sockets()
	_select_metadata(_target_socket, socket_id)
	_preview()


func _toggle_pin() -> void:
	var root := _root()
	var instance_id := _selected(_target)
	if root == null or instance_id.is_empty():
		_status.text = "Select an existing module before changing its pin."
		return
	var selected: ModuleInstance = null
	for instance in ModuleAssembly.get_instances(root):
		if instance.instance_id == instance_id:
			selected = instance
			break
	if selected == null:
		_status.text = "Selected module is no longer in the document."
		return
	var result := ModuleAssembly.set_pinned(root, instance_id, not selected.pinned)
	if result.success:
		refresh_document()
		_status.text = (
			("Pinned " if result.pinned else "Unpinned ")
			+ instance_id
			+ (
				". Regeneration will preserve this module."
				if result.pinned
				else ". This module can now be regenerated."
			)
		)
	else:
		_status.text = "Pin change failed: " + str(result.error)


func _validate_document() -> void:
	var result := ModuleAssembly.validate_level(_root())
	_status.text = (
		"Layout is valid." if result.valid else "Layout errors:\n" + "\n".join(result.errors)
	)


func _collect_actors(node: Node, module_id: String) -> void:
	if node is ModuleInstance:
		module_id = node.instance_id
	if "actor_id" in node and not str(node.actor_id).is_empty():
		var actor_id := (
			str(node.actor_id) if module_id.is_empty() else module_id + "/" + str(node.actor_id)
		)
		# Ambiguous IDs are not offered as bindable ports.
		if _actors.has(actor_id):
			_actors[actor_id] = null
		else:
			_actors[actor_id] = node
	for child in node.get_children():
		_collect_actors(child, module_id)


func _refresh_input_port() -> void:
	_target_port.clear()
	var actor: Node = _actors.get(_selected(_target_actor))
	if actor:
		_target_port.add_item(
			"on_channel_triggered" if actor.has_method("on_channel_triggered") else "trigger"
		)


func _connect_gameplay() -> void:
	_edit_gameplay(false)


func _disconnect_gameplay() -> void:
	_edit_gameplay(true)


func _edit_gameplay(disconnect: bool) -> void:
	var root := _root()
	if (
		root == null
		or not root.has_method("get_channel_system")
		or not root.has_method("prepare_for_save")
		or not root.has_method("restore_runtime_bindings")
	):
		_status.text = "Gameplay authoring requires a LevelRoot with persistent channels."
		return
	var source_id := _selected(_source_actor)
	var target_id := _selected(_target_actor)
	var source: Node = _actors.get(source_id)
	var target: Node = _actors.get(target_id)
	var channel_name := _channel.text.strip_edges()
	if source == null or target == null or source == target or channel_name.is_empty():
		_status.text = "Select distinct actors with real output/input ports and enter a channel name."
		return
	var system: Node = root.get_channel_system()
	if system == null:
		_status.text = "The document has no ChannelSystem."
		return
	root.prepare_for_save()
	var before: Dictionary = root.channel_data.duplicate(true)
	var after := before.duplicate(true)
	if disconnect:
		if (
			not after.has(channel_name)
			or source_id not in after[channel_name].sources
			or target_id not in after[channel_name].targets
		):
			_status.text = "These actors are not connected on that channel."
			return
		# Channels broadcast: removing one endpoint is only unambiguous for a single source.
		if after[channel_name].sources.size() != 1:
			_status.text = "This is a broadcast channel with multiple sources; pair-only disconnection is not representable."
			return
		after[channel_name].targets.erase(target_id)
		if after[channel_name].targets.is_empty():
			after.erase(channel_name)
	else:
		for existing: String in before:
			if existing != channel_name and source_id in before[existing].sources:
				_status.text = (
					"This actor has one output_channel port and already emits on " + existing + "."
				)
				return
		if not after.has(channel_name):
			after[channel_name] = {
				"sources": [],
				"targets": [],
				"enabled": _enabled.button_pressed,
				"delay": _delay.value,
				"inverted": _inverted.button_pressed,
				"color": _color.color.to_html()
			}
		if source_id in after[channel_name].sources and target_id in after[channel_name].targets:
			_status.text = "These actors are already connected on that channel."
			return
		if source_id not in after[channel_name].sources:
			after[channel_name].sources.append(source_id)
		if target_id not in after[channel_name].targets:
			after[channel_name].targets.append(target_id)
	var undo := EditorGlobals.get_undo_redo()
	undo.create_action("Disconnect gameplay actors" if disconnect else "Connect gameplay actors")
	undo.add_do_method(_apply_channels.bind(root, after))
	undo.add_undo_method(_apply_channels.bind(root, before))
	undo.commit_action()
	_status.text = (
		"Gameplay channel saved in document: "
		+ channel_name
		+ ". Undo restores all channel settings."
	)


static func _apply_channels(root: Node3D, data: Dictionary) -> void:
	root.channel_data = data.duplicate(true)
	root.restore_runtime_bindings()


func _undo() -> void:
	var history := _history()
	if history == null or not history.has_undo():
		_status.text = "Nothing to undo."
		return
	history.undo()
	refresh_document()
	_status.text = "Undid the last edit."


func _redo() -> void:
	var history := _history()
	if history == null or not history.has_redo():
		_status.text = "Nothing to redo."
		return
	history.redo()
	refresh_document()
	_status.text = "Redid the last edit."


func _history() -> UndoRedo:
	var manager := EditorGlobals.get_undo_redo()
	if manager is UndoRedo:
		return manager
	return manager.get_history_undo_redo(manager.get_object_history_id(_root()))


func _selected(option: OptionButton) -> String:
	if option.selected < 0:
		return ""
	var value: Variant = option.get_item_metadata(option.selected)
	return "" if value == null else str(value)


func _select_metadata(option: OptionButton, value: String) -> void:
	for index in option.item_count:
		if str(option.get_item_metadata(index)) == value:
			option.select(index)
			return


func _replacement_capabilities() -> Array[String]:
	if _editor and _editor.has_method("get_replacement_capabilities"):
		return _editor.get_replacement_capabilities()
	return ["walk"]


func _label(parent: Control, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 16)
	parent.add_child(label)


func _control(parent: Control, control: Control) -> void:
	control.custom_minimum_size.y = 48
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control.add_theme_font_size_override("font_size", 16)
	parent.add_child(control)


func _option(parent: Control, label: String) -> OptionButton:
	_label(parent, label)
	var option := OptionButton.new()
	option.fit_to_longest_item = false
	_control(parent, option)
	return option


func _button(parent: Control, text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	_control(parent, button)
