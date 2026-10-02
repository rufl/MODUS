class_name DecalSpawner
extends Node

## Manages decal spawning and cleanup with optimized pooling
## Uses Sprite3D for GLES3 compatibility (Decal nodes don't work with gl_compatibility)

signal decal_spawned(decal: Sprite3D)

var current_quality: int = 1  # EffectQuality.MEDIUM

const DECAL_LIMITS: Dictionary = {
	0: 20,  # LOW
	1: 50,  # MEDIUM
	2: 100,  # HIGH
	3: 200,  # ULTRA
}

var _decal_pool: Array[Sprite3D] = []
var _active_decals: Array[Sprite3D] = []
const POOL_PREWARM_SIZE: int = 20
const MAX_POOL_SIZE: int = 50
const CLEANUP_TOKEN_META: StringName = &"modus_decal_cleanup_token"
const CLEANUP_TWEEN_META: StringName = &"modus_decal_cleanup_tween"
var _next_cleanup_token: int = 0

func _ready() -> void:
	_prewarm_pool()


func _prewarm_pool() -> void:
	## Pre-create decals for better performance
	for i in range(POOL_PREWARM_SIZE):
		var decal := _create_new_decal()
		decal.visible = false
		_decal_pool.append(decal)


func _create_new_decal() -> Sprite3D:
	## Create a new Sprite3D-based decal instance (GLES3 compatible)
	var decal := Sprite3D.new()
	decal.name = "PooledDecal"
	decal.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	decal.shaded = false
	decal.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	decal.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	decal.no_depth_test = false
	decal.fixed_size = false
	decal.layers = 0xFFFFF
	get_tree().root.add_child(decal)
	return decal


func _get_decal() -> Sprite3D:
	## Get a decal from the pool without exceeding the quality budget.
	while _active_decals.size() >= _get_active_limit():
		_return_oldest_active_decal()

	var decal: Sprite3D = null
	while not _decal_pool.is_empty():
		decal = _decal_pool.pop_back()
		if is_instance_valid(decal):
			break
		decal = null

	if not decal:
		decal = _create_new_decal()

	_active_decals.append(decal)
	return decal


func _get_active_limit() -> int:
	var quality := clampi(current_quality, 0, 3)
	return maxi(1, int(DECAL_LIMITS.get(quality, DECAL_LIMITS[1])))


func _return_oldest_active_decal() -> void:
	while not _active_decals.is_empty():
		var oldest := _active_decals[0]
		if not is_instance_valid(oldest):
			_active_decals.pop_front()
			continue
		_return_decal(oldest)
		return


func _return_decal(decal: Sprite3D) -> void:
	## Return decal to pool and invalidate any delayed cleanup for its prior use.
	if not is_instance_valid(decal):
		return

	decal.set_meta(CLEANUP_TOKEN_META, -1)
	if decal.has_meta(CLEANUP_TWEEN_META):
		var cleanup_tween := decal.get_meta(CLEANUP_TWEEN_META) as Tween
		if cleanup_tween:
			cleanup_tween.kill()
		decal.remove_meta(CLEANUP_TWEEN_META)

	var idx := _active_decals.find(decal)
	if idx != -1:
		_active_decals.remove_at(idx)

	# Pooled decals must outlive moving hit bodies and remain reusable.
	if decal.get_parent() != get_tree().root:
		decal.reparent(get_tree().root, true)

	decal.visible = false
	decal.modulate = Color(1, 1, 1, 1)
	decal.texture = null

	if _decal_pool.size() < MAX_POOL_SIZE:
		_decal_pool.append(decal)
	else:
		decal.queue_free()


func _resolve_surface(pos: Vector3, normal: Vector3) -> Node3D:
	if normal.length_squared() < 0.0001:
		return null

	var space_state := get_tree().root.get_world_3d().direct_space_state
	var surface_normal := normal.normalized()
	var query := PhysicsRayQueryParameters3D.create(
		pos + surface_normal * 0.05, pos - surface_normal * 0.2
	)
	query.collision_mask = 0xFFFFFFFF
	query.collide_with_areas = false
	var result := space_state.intersect_ray(query)
	return result.get("collider") as Node3D if result else null


func set_quality(quality: int) -> void:
	current_quality = clampi(quality, 0, 3)
	while _active_decals.size() > _get_active_limit():
		_return_oldest_active_decal()

func spawn_decal(
	texture: Texture2D,
	pos: Vector3,
	normal: Vector3,
	decal_size: Vector3 = Vector3(1, 1, 1),
	lifetime: float = 30.0
) -> Sprite3D:
	var decal := _get_decal()

	if not decal:
		return null

	var surface := _resolve_surface(pos, normal)
	if surface and surface.is_inside_tree():
		decal.reparent(surface, true)
	else:
		decal.reparent(get_tree().root, true)

	decal.texture = texture
	decal.modulate = Color(1, 1, 1, 1)
	decal.visible = true

	# Position slightly off surface to avoid z-fighting
	var surface_normal := normal.normalized()
	decal.global_position = pos + surface_normal * 0.01

	# Set size using pixel_size (Sprite3D sizing)
	# Approximate the decal_size.x as the desired world size
	var world_size: float = decal_size.x
	decal.pixel_size = world_size / 64.0  # Assuming ~64px textures

	# Orient to normal
	if normal.length_squared() > 0.0001:
		# Check if normal is parallel to up vector to avoid colinear warning
		var up := Vector3.UP
		if abs(surface_normal.dot(up)) > 0.99:
			up = Vector3.RIGHT
		decal.look_at(pos + surface_normal, up)

	# Random rotation for variety
	decal.rotate_object_local(Vector3.FORWARD, randf() * TAU)

	decal_spawned.emit(decal)

	# Auto-cleanup with fade
	_schedule_cleanup(decal, lifetime)

	return decal


func _schedule_cleanup(decal: Sprite3D, lifetime: float) -> void:
	## Schedule decal cleanup with fade-out.
	_next_cleanup_token += 1
	var cleanup_token := _next_cleanup_token
	decal.set_meta(CLEANUP_TOKEN_META, cleanup_token)

	await get_tree().create_timer(maxf(lifetime * 0.8, 0.01)).timeout

	if (
		not is_instance_valid(decal)
		or not is_instance_valid(self)
		or int(decal.get_meta(CLEANUP_TOKEN_META, -1)) != cleanup_token
	):
		return

	var fade_time := maxf(lifetime * 0.2, 0.01)
	var tween := create_tween()
	decal.set_meta(CLEANUP_TWEEN_META, tween)
	tween.tween_property(decal, "modulate:a", 0.0, fade_time)
	tween.tween_callback(_finish_cleanup.bind(decal, cleanup_token))


func _finish_cleanup(decal: Sprite3D, cleanup_token: int) -> void:
	if (
		not is_instance_valid(decal)
		or int(decal.get_meta(CLEANUP_TOKEN_META, -1)) != cleanup_token
	):
		return
	_return_decal(decal)


const BLOOD_SPLAT_TEXTURES: Array[Texture2D] = [
	preload("res://game/art/textures/decals/blood_splat.png"),
	preload("res://game/art/textures/decals/mid_blood_splat.png"),
	preload("res://game/art/textures/decals/smol_blood_splat.png")
]

const HIGH_VELOCITY_HIT_TEXTURE: Texture2D = preload(
	"res://game/art/textures/decals/hivelocity_hit.png"
)


func spawn_blood_decal(pos: Vector3, normal: Vector3, is_high_velocity: bool = false) -> Sprite3D:
	## Spawn blood decal with random texture selection.
	## Use is_high_velocity=true for railgun/sniper hits.


	var blood_texture: Texture2D

	if is_high_velocity:
		blood_texture = HIGH_VELOCITY_HIT_TEXTURE
		if not blood_texture:
			push_warning("[DecalSpawner] High velocity texture not found, using random blood splat")
			blood_texture = _load_random_blood_texture()
	else:
		blood_texture = _load_random_blood_texture()

	if not blood_texture:
		push_warning("[DecalSpawner] Blood textures not found, using procedural")
		blood_texture = ProceduralSplatGenerator.create_blood_splat_texture()

	var size: Vector3
	if is_high_velocity:
		size = Vector3(randf_range(0.8, 1.2), randf_range(0.8, 1.2), 0.2)
	else:
		size = Vector3(randf_range(0.5, 1.0), randf_range(0.5, 1.0), 0.2)

	var decal: Sprite3D = spawn_decal(blood_texture, pos, normal, size, 60.0)

	# Note: Blood drip feature was removed (not critical for gameplay)

	return decal



func _load_random_blood_texture() -> Texture2D:
	## Return a preloaded blood texture to avoid a first-hit load hitch.
	var texture_index := randi_range(0, BLOOD_SPLAT_TEXTURES.size() - 1)
	return BLOOD_SPLAT_TEXTURES[texture_index]


func spawn_bullet_hole(pos: Vector3, normal: Vector3) -> void:
	var pool_service: Node = GameManager.get_core_system("pools")
	if not pool_service:
		return

	var bullet_hole: Node3D = (
		pool_service.get_instance("bullet_hole")
		if pool_service.has_method("get_instance")
		else null
	)
	if not bullet_hole:
		return

	var session_id: int = Time.get_ticks_msec() + randi()
	bullet_hole.set_meta("session_id", session_id)

	if not bullet_hole.get_parent():
		get_tree().root.add_child(bullet_hole)

	var surface := _resolve_surface(pos, normal)
	if surface and surface.is_inside_tree():
		bullet_hole.reparent(surface, true)
	elif bullet_hole.get_parent() != get_tree().root:
		bullet_hole.reparent(get_tree().root, true)

	bullet_hole.global_position = pos + normal.normalized() * 0.01

	if normal != Vector3.ZERO:
		if abs(normal.dot(Vector3.UP)) < 0.99:
			bullet_hole.look_at(pos + normal, Vector3.UP)
		else:
			bullet_hole.rotation.x = PI / 2 if normal == Vector3.DOWN else -PI / 2

	bullet_hole.rotate_object_local(Vector3.FORWARD, randf() * TAU)

	# Cleanup after 30s
	var bh_ref: Node3D = bullet_hole
	var bh_session: int = session_id
	var captured_pool: Node = pool_service  # Capture pool_service for closure
	get_tree().create_timer(30.0).timeout.connect(
		func() -> void:
			if is_instance_valid(bh_ref) and bh_ref.get_meta("session_id", -1) == bh_session:
				if captured_pool and captured_pool.has_method("return_instance"):
					captured_pool.return_instance(bh_ref)
	)


func clear_all_decals() -> void:
	## Clear all active decals (for scene transitions).
	for decal in _active_decals.duplicate():
		if is_instance_valid(decal):
			_return_decal(decal)
	_active_decals.clear()


func get_pool_stats() -> Dictionary:
	## Get pooling statistics for debugging
	return {
		"active": _active_decals.size(),
		"pooled": _decal_pool.size(),
		"total": _active_decals.size() + _decal_pool.size()
	}


func _exit_tree() -> void:
	## Cleanup all decals on exit
	for decal in _active_decals:
		if is_instance_valid(decal):
			decal.queue_free()

	for decal in _decal_pool:
		if is_instance_valid(decal):
			decal.queue_free()

	_active_decals.clear()
	_decal_pool.clear()
