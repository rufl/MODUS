extends GutTest

var save_load_menu: Node
var slot_list: ItemList


func before_each() -> void:
	var scene: PackedScene = preload("res://game/ui/menus/save_load_menu.tscn")
	save_load_menu = scene.instantiate()
	add_child_autofree(save_load_menu)
	await get_tree().process_frame
	slot_list = save_load_menu.get_node("%SlotList") as ItemList


func test_slots_are_real_save_service_entries_with_canonical_metadata() -> void:
	save_load_menu.call("show_menu")

	assert_eq(slot_list.get_item_count(), 3)
	assert_eq(slot_list.get_item_metadata(0), "slot1")
	assert_eq(slot_list.get_item_metadata(1), "slot2")
	assert_eq(slot_list.get_item_metadata(2), "slot3")
