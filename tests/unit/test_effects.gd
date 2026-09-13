extends ModusGutTestBase


func before_each() -> void:
	await modus_setup()


func after_each() -> void:
	modus_teardown()


func test_deleted_decal_cancels_remaining_blood_drips() -> void:
	var spray: Node = (
		load("res://game/scripts/features/effects/effects/directional_blood_spray.gd").new()
	)
	add_child_autofree(spray)
	var decal := Sprite3D.new()
	add_child(decal)
	var emitted: Array[Node] = []
	var record_drip := func(node: Node) -> void:
		if node is GPUParticles3D:
			emitted.append(node)
			autofree(node)
	get_tree().node_added.connect(record_drip)
	spray._spawn_drip_trail(decal, 1.1)
	await wait_seconds(0.1)
	assert_eq(emitted.size(), 1, "A live decal emits its first drip")
	decal.free()
	await wait_seconds(1.05)
	get_tree().node_added.disconnect(record_drip)
	assert_eq(emitted.size(), 1, "Deleted decals produce no delayed blood particles")
