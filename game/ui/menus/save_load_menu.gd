extends PanelContainer

signal back_pressed
signal play_requested(slot_name: String)

@onready var slot_list: ItemList = %SlotList

const DEFAULT_SLOT_NAMES: Array[String] = ["slot1", "slot2", "slot3"]


func _ready() -> void:
	hide()
	_populate_slots()


func show_menu() -> void:
	_populate_slots()
	show()


func hide_menu() -> void:
	hide()
	back_pressed.emit()


func _populate_slots() -> void:
	if not slot_list:
		return

	slot_list.clear()

	for slot_name: String in _get_slot_names():
		var item_index: int = slot_list.add_item(_format_slot_label(slot_name))
		slot_list.set_item_metadata(item_index, slot_name)


func _get_slot_names() -> Array[String]:
	var slot_names: Array[String] = DEFAULT_SLOT_NAMES.duplicate()
	var save_service: Node = _get_save_service()

	if save_service and save_service.has_method("get_all_saves"):
		for save_metadata: Dictionary in save_service.get_all_saves():
			var slot_name: String = str(save_metadata.get("slot_name", ""))
			if not slot_name.is_empty() and not slot_names.has(slot_name):
				slot_names.append(slot_name)

	for slot_name: String in PlayerProgression.get_save_slots():
		if not slot_name.is_empty() and not slot_names.has(slot_name):
			slot_names.append(slot_name)

	return slot_names


func _get_save_service() -> Node:
	var game_manager: Node = get_node_or_null("/root/GameManager")
	if game_manager and game_manager.has_method("get_core_system"):
		return game_manager.get_core_system("save")
	return null


func _format_slot_label(slot_name: String) -> String:
	var display_name: String = slot_name.replace("_", " ").capitalize()
	var save_service: Node = _get_save_service()
	if not save_service or not save_service.has_method("save_exists"):
		return display_name
	if not save_service.save_exists(slot_name):
		return "%s — Empty" % display_name

	var metadata: Dictionary = (
		save_service.get_slot_metadata(slot_name)
		if save_service.has_method("get_slot_metadata")
		else {}
	)
	var date_string: String = str(metadata.get("date_string", "")).strip_edges()
	return (
		"%s — Saved (%s)" % [display_name, date_string]
		if not date_string.is_empty()
		else "%s — Saved" % display_name
	)


func _on_load_pressed() -> void:
	var selected: Array[int] = slot_list.get_selected_items()
	if selected.size() > 0:
		var slot_name: String = str(slot_list.get_item_metadata(selected[0]))
		if slot_name.is_empty():
			slot_name = slot_list.get_item_text(selected[0]).to_lower().replace(" ", "_")
		play_requested.emit(slot_name)


func _on_back_pressed() -> void:
	hide_menu()


func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event.is_action_pressed("ui_cancel"):
		hide_menu()
		get_viewport().set_input_as_handled()
