class_name EnemyBulletDecals
extends Node

## Manages bullet hit decals on enemy bodies
## Uses pooling for performance optimization
## Uses Sprite3D for GLES3 compatibility

const BULLET_HIT_TEXTURE = preload("res://game/art/textures/decals/bullet_hit.png")
const MAX_DECALS_PER_ENEMY: int = 10

const FADE_TOKEN_META: StringName = &"modus_enemy_decal_fade_token"
const FADE_TWEEN_META: StringName = &"modus_enemy_decal_fade_tween"
var _next_fade_token: int = 0

var _enemy: Node3D
var _visuals: SkeletalCharacterVisuals
var _active_decals: Array[Sprite3D] = []
var _decal_pool: Array[Sprite3D] = []


func setup(enemy: Node3D, visuals: SkeletalCharacterVisuals) -> void:
	_enemy = enemy
	_visuals = visuals

	# Pre-warm decal pool
	_prewarm_pool(5)


func _prewarm_pool(count: int) -> void:
	for i in range(count):
		var decal := _create_decal()
		decal.visible = false
		_decal_pool.append(decal)


func _create_decal() -> Sprite3D:
	var decal := Sprite3D.new()
	decal.name = "BulletHitDecal"

	# Configure as decal-like sprite for GLES3 compatibility
	decal.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	decal.shaded = false
	decal.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	decal.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	decal.no_depth_test = false
	decal.layers = 0xFFFFF

	decal.texture = BULLET_HIT_TEXTURE

	# Decal settings
	decal.pixel_size = 0.15 / 64.0  # Small bullet hole
	decal.modulate = Color(1, 1, 1, 1)

	# Add to enemy so it moves with the body
	if _visuals and _visuals.mannequin_root:
		_visuals.mannequin_root.add_child(decal)
	elif _enemy:
		_enemy.add_child(decal)

	return decal


func spawn_bullet_decal(hit_position: Vector3, hit_normal: Vector3) -> void:
	# Get decal from pool or create new.
	var decal: Sprite3D
	if _decal_pool.size() > 0:
		decal = _decal_pool.pop_back()
	else:
		decal = _create_decal()

	var local_pos: Vector3
	if _visuals and _visuals.mannequin_root:
		local_pos = _visuals.mannequin_root.to_local(hit_position)
	else:
		local_pos = _enemy.to_local(hit_position)

	decal.position = local_pos + hit_normal * 0.01

	if hit_normal != Vector3.ZERO:
		var up := Vector3.UP
		if abs(hit_normal.dot(up)) > 0.99:
			up = Vector3.RIGHT
		decal.look_at(decal.global_position + hit_normal, up)

	decal.rotate_object_local(Vector3.FORWARD, randf() * TAU)
	decal.visible = true
	decal.modulate.a = 1.0
	_active_decals.append(decal)

	if _active_decals.size() > MAX_DECALS_PER_ENEMY:
		var oldest: Sprite3D = _active_decals.pop_front()
		_return_decal(oldest)

	_schedule_fade_out(decal, 30.0)


func _schedule_fade_out(decal: Sprite3D, delay: float) -> void:
	_next_fade_token += 1
	var fade_token := _next_fade_token
	decal.set_meta(FADE_TOKEN_META, fade_token)

	await get_tree().create_timer(delay).timeout

	if (
		not is_instance_valid(decal)
		or not is_instance_valid(self)
		or int(decal.get_meta(FADE_TOKEN_META, -1)) != fade_token
	):
		return

	var tween := create_tween()
	decal.set_meta(FADE_TWEEN_META, tween)
	tween.tween_property(decal, "modulate:a", 0.0, 2.0)
	tween.tween_callback(_finish_fade_out.bind(decal, fade_token))


func _finish_fade_out(decal: Sprite3D, fade_token: int) -> void:
	if (
		not is_instance_valid(decal)
		or int(decal.get_meta(FADE_TOKEN_META, -1)) != fade_token
	):
		return
	_return_decal(decal)


func _return_decal(decal: Sprite3D) -> void:
	if not is_instance_valid(decal):
		return

	decal.set_meta(FADE_TOKEN_META, -1)
	if decal.has_meta(FADE_TWEEN_META):
		var fade_tween := decal.get_meta(FADE_TWEEN_META) as Tween
		if fade_tween:
			fade_tween.kill()
		decal.remove_meta(FADE_TWEEN_META)

	var idx := _active_decals.find(decal)
	if idx != -1:
		_active_decals.remove_at(idx)
	elif _decal_pool.has(decal):
		return

	decal.visible = false
	decal.modulate.a = 1.0
	_decal_pool.append(decal)


func clear_all_decals() -> void:
	## Remove all decals (called on death/despawn).
	for decal in _active_decals.duplicate():
		if is_instance_valid(decal):
			decal.queue_free()

	for decal in _decal_pool:
		if is_instance_valid(decal):
			decal.queue_free()

	_active_decals.clear()
	_decal_pool.clear()


func _exit_tree() -> void:
	clear_all_decals()
