extends ModusGutTestBase
const DIRECTIONAL_BLOOD_SPRAY = preload(
	"res://game/scripts/features/effects/effects/directional_blood_spray.gd"
)
const DECAL_SPAWNER = preload("res://game/scripts/features/effects/decal_spawner.gd")


func before_each() -> void:
	await modus_setup()


func after_each() -> void:
	modus_teardown()


func test_deleted_decal_cancels_remaining_blood_drips() -> void:
	var spray: Node = DIRECTIONAL_BLOOD_SPRAY.new()
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


func test_blood_decal_follows_moving_hit_surface() -> void:
	var spray: Node = DIRECTIONAL_BLOOD_SPRAY.new()
	add_child_autofree(spray)
	var carrier := Node3D.new()
	add_child_autofree(carrier)

	spray._spawn_blood_decal_on_surface(Vector3.ZERO, Vector3.FORWARD, carrier)
	assert_eq(carrier.get_child_count(), 1, "Surface decal is parented to its hit body")
	var decal := carrier.get_child(0) as Sprite3D
	var initial_position := decal.global_position
	carrier.global_position = Vector3(3, 0, 0)

	assert_true(
		decal.global_position.is_equal_approx(initial_position + Vector3(3, 0, 0)),
		"Surface decal follows a moving hit body instead of floating in world space"
	)


func test_pooled_decal_follows_moving_collision_body() -> void:
	var spawner: Node = DECAL_SPAWNER.new()
	add_child_autofree(spawner)
	var carrier := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3.ONE * 2.0
	collision.shape = shape
	carrier.add_child(collision)
	add_child_autofree(carrier)
	await wait_physics_frames(1)

	var decal: Sprite3D = spawner.spawn_decal(null, Vector3(0, 1, 0), Vector3.UP, Vector3.ONE, 30.0)
	assert_eq(decal.get_parent(), carrier, "Pooled decal is attached to the hit body")
	var initial_position: Vector3 = decal.global_position
	carrier.global_position = Vector3(3, 0, 0)

	assert_true(
		decal.global_position.is_equal_approx(initial_position + Vector3(3, 0, 0)),
		"Pooled decal follows a moving collision body instead of floating in world space"
	)
