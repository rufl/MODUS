extends SceneTree

const GenerationConfigScript = preload("res://game/scripts/map_generator/generation_config.gd")
const MAP_SIZE := Vector2i(128, 128)
const CANCELLATION_CYCLES := 2
const TIMEOUT_MS := 120000

var _generator: Node
var _pending: Dictionary = {}
var _failures: Array[String] = []
var _baseline_static_memory := 0
var _baseline_objects := 0
var _peak_static_memory := 0
var _peak_objects := 0
var _completed_count := 0
var _cancelled_count := 0
var _replacement_count := 0


func _init() -> void:
	call_deferred("_run_soak")


func _run_soak() -> void:
	await process_frame
	var generator_script := load("res://game/scripts/map_generator/map_generator.gd") as GDScript
	if not generator_script:
		_failures.append("MapGenerator script failed to load")
		_finish()
		return

	_generator = generator_script.new()
	root.add_child(_generator)
	_generator.generation_completed.connect(_on_generation_completed)
	_generator.generation_failed.connect(_on_generation_failed)
	_generator.generation_cancelled.connect(_on_generation_cancelled)
	await process_frame

	_sample_metrics()
	_baseline_static_memory = _current_static_memory()
	_baseline_objects = _current_objects()

	var warmup := await _generate_success("large-world-warmup")
	if not warmup:
		_finish()
		return
	await _flush_frames(8)
	_sample_metrics()
	_baseline_static_memory = _current_static_memory()
	_baseline_objects = _current_objects()

	for cycle in range(CANCELLATION_CYCLES):
		var cancelled_seed := "large-world-cancel-%d" % cycle
		_pending = {"seed": cancelled_seed, "completed": false, "failed": false, "cancelled": false}
		_generator.generate_map(cancelled_seed, _build_config())
		await process_frame
		if not _generator.is_generating:
			_failures.append("%s did not enter the generating state" % cancelled_seed)
		else:
			_generator.cancel_generation()
		await _wait_until_idle(cancelled_seed)
		if not bool(_pending.get("cancelled", false)):
			_failures.append("%s did not emit generation_cancelled" % cancelled_seed)
		if bool(_pending.get("completed", false)):
			_failures.append("%s completed after cancellation" % cancelled_seed)
		await _flush_frames(8)
		_sample_metrics()
		if _current_objects() > _baseline_objects + 100:
			_failures.append(
				"%s retained too many objects after cancellation: %d > %d"
				% [cancelled_seed, _current_objects(), _baseline_objects + 100]
			)
		var replacement_seed := "large-world-replacement-%d" % cycle
		if await _generate_success(replacement_seed):
			_replacement_count += 1

	if await _generate_success("large-world-final"):
		await _flush_frames(8)
		_sample_metrics()

	_generator.cancel_generation()
	_generator.queue_free()
	await _flush_frames(8)
	_sample_metrics()

	var final_static_memory := _current_static_memory()
	var final_objects := _current_objects()
	var final_delta_mb := float(final_static_memory - _baseline_static_memory) / 1048576.0
	var object_delta := final_objects - _baseline_objects
	if _cancelled_count != CANCELLATION_CYCLES:
		_failures.append(
			"Expected %d cancellation signals, observed %d"
			% [CANCELLATION_CYCLES, _cancelled_count]
		)
	if _replacement_count != CANCELLATION_CYCLES:
		_failures.append(
			"Expected %d replacement completions, observed %d"
			% [CANCELLATION_CYCLES, _replacement_count]
		)
	print(
		(
			"LARGE_WORLD_SOAK map=%dx%d warmup=1 cancellations=%d "
			+ "observed_cancellations=%d replacements=%d completed=%d "
			+ "peak_static_mb=%.2f final_delta_mb=%.2f peak_objects=%d "
			+ "final_object_delta=%d failures=%d"
		)
		% [
			MAP_SIZE.x,
			MAP_SIZE.y,
			CANCELLATION_CYCLES,
			_cancelled_count,
			_replacement_count,
			_completed_count,
			float(_peak_static_memory) / 1048576.0,
			final_delta_mb,
			_peak_objects,
			object_delta,
			_failures.size()
		]
	)
	for failure in _failures:
		push_error("LARGE_WORLD_SOAK failure: %s" % failure)
	_finish()


func _build_config() -> Resource:
	var config: Resource = GenerationConfigScript.new()
	config.map_size = MAP_SIZE
	config.outdoor_bias = 0.0
	config.cave_bias = 0.0
	config.prefab_detail_level = 0.0
	config.prop_density = 0.0
	config.decorative_density = 0.0
	config.enable_lod = false
	config.enable_occlusion_culling = false
	config.use_multimesh = false
	config.monster_density = 0.0
	config.minimum_monsters = 0
	config.item_density = 0.0
	config.enable_secrets = false
	config.enable_key_locks = true
	config.enable_boss_arena = true
	return config


func _generate_success(seed: String) -> bool:
	_pending = {"seed": seed, "completed": false, "failed": false, "cancelled": false}
	_generator.generate_map(seed, _build_config())
	await _wait_until_idle(seed)
	if bool(_pending.get("completed", false)):
		_completed_count += 1
		return true
	if not bool(_pending.get("failed", false)):
		_failures.append("%s did not emit completion or failure" % seed)
	return false


func _wait_until_idle(seed: String) -> void:
	var deadline := Time.get_ticks_msec() + TIMEOUT_MS
	while _generator.is_generating and Time.get_ticks_msec() < deadline:
		await process_frame
	if _generator.is_generating:
		_failures.append("%s exceeded %d ms timeout" % [seed, TIMEOUT_MS])
		_generator.cancel_generation()
	while _generator.is_generating:
		await process_frame
	if _generator.get("_generation_thread") != null:
		_failures.append("%s left a generation thread after becoming idle" % seed)


func _on_generation_completed(_scene: PackedScene, metadata: Dictionary) -> void:
	if _pending.is_empty():
		_failures.append("completion signal arrived without a pending generation")
		return
	var seed := str(metadata.get("seed", ""))
	if seed != str(_pending.get("seed", "")):
		_failures.append("completion seed mismatch: %s != %s" % [seed, _pending.get("seed", "")])
	_pending["completed"] = true


func _on_generation_failed(error: String) -> void:
	if _pending.is_empty():
		_failures.append("failure signal arrived without a pending generation: %s" % error)
		return
	_pending["failed"] = true
	_failures.append("%s failed: %s" % [_pending.get("seed", ""), error])


func _on_generation_cancelled() -> void:
	if _pending.is_empty():
		_failures.append("cancellation signal arrived without a pending generation")
		return
	_pending["cancelled"] = true
	_cancelled_count += 1


func _flush_frames(count: int) -> void:
	for _index in range(count):
		await process_frame


func _sample_metrics() -> void:
	_peak_static_memory = max(_peak_static_memory, _current_static_memory())
	_peak_objects = max(_peak_objects, _current_objects())


func _current_static_memory() -> int:
	return int(Performance.get_monitor(Performance.MEMORY_STATIC))


func _current_objects() -> int:
	return int(Performance.get_monitor(Performance.OBJECT_COUNT))


func _finish() -> void:
	if _generator and is_instance_valid(_generator):
		_generator.cancel_generation()
		_generator.queue_free()
	quit(1 if not _failures.is_empty() else 0)
