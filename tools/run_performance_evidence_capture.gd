extends SceneTree

const PerformanceLoggerScript = preload("res://tests/manual/performance_logger.gd")
const SHOWCASE_SCENE := "res://game/world/maps/showcase.tscn"
const SESSION_NAME := "showcase_baseline_20260713"
const WARMUP_SECONDS := 10.0
const DURATION_SECONDS := 65.0
const OUTPUT_DIR := "res://logs/performance_logs"


func _init() -> void:
	call_deferred("_run_capture")


func _run_capture() -> void:
	var showcase_scene := load(SHOWCASE_SCENE) as PackedScene
	if not showcase_scene:
		push_error("PERFORMANCE_CAPTURE failed to load showcase scene")
		quit(1)
		return

	var showcase := showcase_scene.instantiate()
	get_root().add_child(showcase)
	await create_timer(WARMUP_SECONDS).timeout

	var logger := PerformanceLoggerScript.new()
	get_root().add_child(logger)
	logger.sample_interval = 1.0
	var source_path: String = logger.start_logging(SESSION_NAME)
	if source_path.is_empty():
		push_error("PERFORMANCE_CAPTURE failed to start PerformanceLogger")
		quit(1)
		return

	print(
		(
			"PERFORMANCE_CAPTURE scene=%s warmup=%.1fs duration=%.1fs renderer=gl_compatibility"
			% [SHOWCASE_SCENE, WARMUP_SECONDS, DURATION_SECONDS]
		)
	)
	await create_timer(DURATION_SECONDS).timeout
	logger.stop_logging()

	DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)
	var output_path := OUTPUT_DIR.path_join(SESSION_NAME + ".csv")
	if DirAccess.copy_absolute(source_path, output_path) != OK:
		push_error("PERFORMANCE_CAPTURE failed to copy %s to %s" % [source_path, output_path])
		quit(1)
		return

	print("PERFORMANCE_CAPTURE output=%s" % output_path)
	quit(0)
