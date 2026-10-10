extends GutTest

const BACKPACK_SCENE := preload("res://game/scenes/items/backpack.tscn")


func test_restore_inventory_merges_slots_and_equipment() -> void:
	var source := Inventory.new()
	var bandage := _make_item("bandage", 2, 5)
	assert_true(source.add_item(bandage))
	var rifle := _make_item("rifle")
	rifle.equip_slot = "weapon_primary"
	source.equip_item(rifle, "weapon_primary")

	var backpack: Node = BACKPACK_SCENE.instantiate()
	add_child_autofree(backpack)
	backpack.set("inventory_data", source.to_dict())
	var target := Inventory.new()
	var existing := _make_item("scrap")
	assert_true(target.add_item(existing))

	assert_true(backpack.call("_restore_inventory", target))
	assert_eq(target.count_item("scrap"), 1)
	assert_eq(target.count_item("bandage"), 2)
	assert_eq(target.get_equipped("weapon_primary").id, "rifle")


func test_restore_inventory_is_atomic_when_target_is_full() -> void:
	var target := Inventory.new()
	for index in Inventory.MAX_SLOTS:
		var item := _make_item("occupied_%d" % index)
		assert_true(target.add_item(item))

	var source := Inventory.new()
	assert_true(source.add_item(_make_item("backpack_item")))
	var backpack: Node = BACKPACK_SCENE.instantiate()
	add_child_autofree(backpack)
	backpack.set("inventory_data", source.to_dict())

	assert_false(backpack.call("_restore_inventory", target))
	assert_eq(target.count_item("backpack_item"), 0)
	assert_eq(target.count_item("occupied_0"), 1)


func _make_item(item_id: String, stack: int = 1, max_stack: int = 1) -> InventoryItem:
	var item := InventoryItem.new()
	item.id = item_id
	item.display_name = item_id
	item.current_stack = stack
	item.max_stack = max_stack
	return item
