extends ModusGutTestBase

const ActorRegistryScript := preload("res://shared/editor_core/actors/actor_registry.gd")
const AssetRegistryScript := preload("res://shared/editor_core/core/asset_registry.gd")


func before_each() -> void:
	await modus_setup()


func after_each() -> void:
	modus_teardown()


func test_actor_registry_creates_builtin_actors() -> void:
	var registry: Node = ActorRegistryScript.new()
	registry._register_builtin_actors()
	for actor_id: String in registry.get_all_actor_ids():
		var actor_instance: Node = registry.create_actor(actor_id)
		assert_not_null(actor_instance, "Built-in actor '%s' should instantiate" % actor_id)
		if actor_instance:
			actor_instance.free()
	registry.free()


func test_asset_registry_discovers_builtin_interactables_and_props() -> void:
	var registry: Node = AssetRegistryScript.new()
	registry._init_asset_categories()
	registry._scan_assets()
	for asset_id: String in ["door", "trigger_zone", "moving_platform"]:
		var asset: Dictionary = registry.get_asset_by_id(asset_id)
		assert_false(asset.is_empty(), "Built-in interactable '%s' should be registered" % asset_id)
	for scene_asset_id: String in [
		"glass_window",
		"breakable_crate",
		"breakable_barrel",
		"elevator",
		"crusher",
		"rope",
		"lever"
	]:
		var asset: Dictionary = registry.get_asset_by_id(scene_asset_id)
		assert_false(
			asset.is_empty(), "Canonical scene asset '%s' should be discovered" % scene_asset_id
		)
	registry.free()
