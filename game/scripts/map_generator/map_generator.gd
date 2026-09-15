extends Node

## MapGenerator Autoload Singleton
## Orchestrates procedural map generation using shape grammars,
## cellular automata, and prefab composition
##
## Performance Optimization Strategy:
## - Independent phases (grid layout, shape grammar, hallway, cave) run on worker thread
## - CSG geometry and navigation baking require main thread (use call_deferred)
## - Phase profiling tracks time per phase and logs warnings when targets exceeded
## - Performance targets: 128×128 maps <15s, 256×256 maps with caves <30s
## - Threading prevents UI blocking during generation

# Preload required classes (renamed to avoid conflicts with global class names)
const GenConfig = preload("res://game/scripts/map_generator/generation_config.gd")
const GenContext = preload("res://game/scripts/map_generator/generation_context.gd")
const ValidationSystem = preload("res://game/scripts/map_generator/validation_system.gd")
const ErrorHandler = preload("res://game/scripts/map_generator/error_handler.gd")
const DebugSystem = preload("res://game/scripts/map_generator/debug_system.gd")
const FeatureAvailability = preload("res://game/scripts/map_generator/feature_availability.gd")
const MapExporter = preload("res://game/scripts/map_generator/map_exporter.gd")
const BatchGenerator = preload("res://game/scripts/map_generator/batch_generator.gd")
const LevelRootScript = preload("res://shared/editor_core/nodes/level_root.gd")
const LevelSpawnPointScript = preload("res://shared/editor_core/nodes/spawn_point.gd")
const EnemySpawnerActorScript = preload("res://shared/editor_core/actors/enemy_spawner_actor.gd")
const PickupSpawnerActorScript = preload("res://shared/editor_core/actors/pickup_spawner_actor.gd")
const KeyPickupActorScript = preload("res://shared/editor_core/actors/key_pickup_actor.gd")
const DoorActorScript = preload("res://shared/editor_core/actors/door_actor.gd")
const SwitchActorScript = preload("res://shared/editor_core/actors/switch_actor.gd")
const GENERATED_SECRET_REWARD_CATEGORY := PickupSpawnerActor.PickupCategory.POWERUP
const GENERATED_SECRET_REWARD_ITEM_ID := "damage_powerup"
const GENERATED_SECRET_REWARD_RARITY_TIER := 2  # ItemRarity.Tier.RARE

# Signals
signal generation_started
@warning_ignore("unused_signal")
signal generation_progress(phase: String, progress: float)
@warning_ignore("unused_signal")
signal generation_completed(map_scene: PackedScene, metadata: Dictionary)
@warning_ignore("unused_signal")
signal generation_failed(error: String)
signal generation_cancelled

# Configuration
var config: GenConfig = null
var rng: RandomNumberGenerator = null

# Component managers
var grid_manager: GridLayoutManager = null
var shape_grammar: ShapeGrammarEngine = null
var hallway_generator: HallwayGenerator = null
var cellular_automata: CellularAutomataEngine = null
var outdoor_park_generator: OutdoorParkGenerator = null
var cave_system_generator: CaveSystemGenerator = null
var boss_arena_generator: BossArenaGenerator = null
var csg_builder: CSGGeometryBuilder = null
var prefab_system: MapPrefabSystem = null
var theme_manager: ThemeManager = null
var navmesh_baker: NavigationMeshBaker = null
var gameplay_element_placer: GameplayElementPlacer = null
var secret_room_generator: SecretRoomGenerator = null
var key_lock_system: KeyLockSystem = null
var advanced_geometry_builder: AdvancedGeometryBuilder = null
var lod_manager: MapLODManager = null
var multimesh_manager: MultiMeshManager = null
var occlusion_culling_manager: OcclusionCullingManager = null
var rule_module_loader: RuleModuleLoader = null
var rule_execution_pipeline: RuleExecutionPipeline = null
var batch_generator: RefCounted = null  # BatchGenerator

# Error handling and validation
var validation_system: ValidationSystem = null
var error_handler: ErrorHandler = null
var error_contexts: Array[ErrorHandler.ErrorContext] = []

# Debug system
var debug_system: DebugSystem = null

# Feature availability and graceful degradation
var feature_availability: FeatureAvailability = null

# State
var is_generating: bool = false
var current_phase: String = ""
var generation_context: GenContext
var _generation_viewport: SubViewport

# Seed-to-layout output changed when global RNG and coordinate leaks were removed.
const GENERATOR_REVISION := 2

# Threading
var _generation_thread: Thread = null
var _thread_should_cancel: bool = false

# Phase profiling
var _generation_start_time: int = 0


func _deferred_warning(message: String) -> void:
	push_warning(message)


func _deferred_error(message: String) -> void:
	push_error(message)


# Performance targets (in milliseconds)
const PHASE_TIME_TARGETS: Dictionary = {
	"grid_layout": 500,
	"shape_grammar": 2000,
	"hallway_generation": 1500,
	"outdoor_generation": 1000,
	"cave_generation": 3000,
	"boss_arena": 500,
	"csg_geometry": 5000,
	"prefab_placement": 3000,
	"gameplay_placement": 1000,
	"navigation_baking": 5000,
	"validation": 500,
	"export": 1000
}

# Map size time targets (in milliseconds)
const MAP_SIZE_TARGETS: Dictionary = {
	Vector2i(128, 128): 15000,  # 15 seconds
	Vector2i(256, 256): 30000,  # 30 seconds
}


func _ready() -> void:
	# Initialize RNG
	rng = RandomNumberGenerator.new()

	# Initialize validation and error handling systems
	validation_system = ValidationSystem.new()
	error_handler = ErrorHandler.new()
	debug_system = DebugSystem.new()

	# Initialize feature availability detection
	feature_availability = FeatureAvailability.new()
	feature_availability.initialize()

	# Initialize component managers
	_initialize_component_managers()

	# Initialize batch generator
	batch_generator = BatchGenerator.new()
	batch_generator.initialize(self)

	# Log initialization
	if GameManager.has_method("log_info"):
		GameManager.log_info("MapGenerator", "Map generator initialized with all components")


func _exit_tree() -> void:
	# Never let a worker thread or its deferred callbacks outlive the owner.
	_thread_should_cancel = true
	_join_generation_thread()
	_release_generated_nodes()
	is_generating = false


func _join_generation_thread() -> void:
	if not _generation_thread:
		return
	_generation_thread.wait_to_finish()
	_generation_thread = null


## Initialize all component managers
func _initialize_component_managers() -> void:
	# Core layout and generation
	grid_manager = GridLayoutManager.new()
	shape_grammar = ShapeGrammarEngine.new()
	hallway_generator = HallwayGenerator.new()
	cellular_automata = CellularAutomataEngine.new()

	# Specialized generators
	outdoor_park_generator = OutdoorParkGenerator.new()
	cave_system_generator = CaveSystemGenerator.new()
	boss_arena_generator = BossArenaGenerator.new()

	# Geometry and visuals
	csg_builder = CSGGeometryBuilder.new()
	advanced_geometry_builder = AdvancedGeometryBuilder.new()

	# Prefabs and theme
	prefab_system = MapPrefabSystem.new()
	theme_manager = ThemeManager.new()

	# Gameplay elements
	gameplay_element_placer = GameplayElementPlacer.new()
	secret_room_generator = SecretRoomGenerator.new()
	key_lock_system = KeyLockSystem.new()

	# Navigation
	navmesh_baker = NavigationMeshBaker.new()

	# Performance optimization
	lod_manager = MapLODManager.new()
	multimesh_manager = MultiMeshManager.new()
	occlusion_culling_manager = OcclusionCullingManager.new()

	# Rule modules are loaded once and executed by the live generation phases.
	rule_module_loader = RuleModuleLoader.new()
	rule_module_loader.load_rules()
	rule_execution_pipeline = RuleExecutionPipeline.new(rule_module_loader)


## Generate a single map with the given seed and configuration
func generate_map(seed_str: String, gen_config: GenConfig) -> void:
	if is_generating:
		push_warning("MapGenerator: Generation already in progress")
		return
	if not gen_config:
		push_error("MapGenerator: Generation config is required")
		return
	if not grid_manager:
		_initialize_component_managers()
	if not validation_system:
		validation_system = ValidationSystem.new()
	if not error_handler:
		error_handler = ErrorHandler.new()
	if not debug_system:
		debug_system = DebugSystem.new()
	if not rng:
		rng = RandomNumberGenerator.new()

	is_generating = true
	config = gen_config.duplicate(true)
	_thread_should_cancel = false
	error_contexts.clear()  # Clear previous error contexts

	# Initialize context
	generation_context = GenContext.new()
	generation_context.config = config
	generation_context.generation_start_time = Time.get_ticks_msec()
	_generation_start_time = generation_context.generation_start_time

	# Hash seed for deterministic generation (use current time if empty)
	var effective_seed := seed_str if seed_str != "" else str(Time.get_ticks_msec())
	var seed_hash := hash_seed(effective_seed)
	generation_context.seed_hash = seed_hash
	config.map_seed = effective_seed

	# Initialize RNG with hashed seed for deterministic generation
	generation_context.rng.seed = seed_hash
	rng.seed = seed_hash  # Also initialize MapGenerator's RNG for consistency
	rule_execution_pipeline.reset()
	generation_context.rule_modules_used.clear()
	theme_manager.set_theme(config.theme, generation_context.create_cosmetic_rng())
	generation_context.theme = theme_manager.get_current_theme()

	# Initialize debug system if enabled
	var debug_enabled: bool = config.has("debug_mode") and config.debug_mode
	debug_system.initialize(debug_enabled, effective_seed)

	generation_started.emit()

	# Start threaded generation
	_start_threaded_generation()


## Cancel ongoing generation
func cancel_generation() -> void:
	if not is_generating:
		return

	_thread_should_cancel = true

	# Join both live and already-finished threads before clearing ownership.
	_join_generation_thread()
	_release_generated_nodes()

	is_generating = false
	generation_cancelled.emit()


## Generate multiple maps in sequence for an episode
func generate_episode(base_seed: String, episode_length: int, gen_config: GenConfig) -> void:
	if not batch_generator:
		push_error("MapGenerator: BatchGenerator not initialized")
		return

	# Ensure output directory exists
	var output_dir := gen_config.output_directory
	if not DirAccess.dir_exists_absolute(output_dir):
		DirAccess.make_dir_recursive_absolute(output_dir)

	# Start batch generation
	var generated_maps: Array[String] = await batch_generator.generate_episode(
		base_seed, episode_length, gen_config, output_dir
	)

	print("MapGenerator: Generated %d/%d maps in episode" % [generated_maps.size(), episode_length])


## Export generated map to file
## Returns true if export succeeded, false otherwise
func export_map(
	map_scene: PackedScene, output_path: String, format: GenConfig.ExportFormat
) -> bool:
	if not map_scene:
		push_warning("MapGenerator: Cannot export null map scene")
		return false

	# Ensure output directory exists
	var output_dir := output_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(output_dir):
		var err := DirAccess.make_dir_recursive_absolute(output_dir)
		if err != OK:
			push_error("MapGenerator: Failed to create output directory: %s" % output_dir)
			return false

	# Export based on format
	var success := false
	match format:
		GenConfig.ExportFormat.PACKED_SCENE:
			success = _export_packed_scene(map_scene, output_path)
		GenConfig.ExportFormat.GLTF:
			success = _export_gltf(map_scene, output_path)
		_:
			push_error("MapGenerator: Unknown export format: %d" % format)
			return false

	if not success:
		return false

	# Save metadata JSON
	var metadata_path := output_path.get_basename() + ".json"
	var total_time := Time.get_ticks_msec() - _generation_start_time
	var metadata := _build_metadata(total_time)

	if not _save_metadata_json(metadata, metadata_path):
		push_warning("MapGenerator: Failed to save metadata JSON, but map export succeeded")
		# Don't fail the export if metadata save fails

	# Validate exported file is loadable
	if not _validate_exported_file(output_path, format):
		push_error("MapGenerator: Exported file validation failed: %s" % output_path)
		return false

	return true


## Export map as PackedScene (.tscn)
func _export_packed_scene(map_scene: PackedScene, output_path: String) -> bool:
	# Ensure path has .tscn extension
	var scene_path := output_path
	if not scene_path.ends_with(".tscn"):
		scene_path += ".tscn"

	# Save PackedScene to file
	var err := ResourceSaver.save(map_scene, scene_path)
	if err != OK:
		push_error("MapGenerator: Failed to save PackedScene to %s (error: %d)" % [scene_path, err])
		return false

	return true


## Export map as GLTF (optional)
func _export_gltf(map_scene: PackedScene, output_path: String) -> bool:
	# Ensure path has .gltf extension
	var gltf_path := output_path
	if not gltf_path.ends_with(".gltf") and not gltf_path.ends_with(".glb"):
		gltf_path += ".gltf"

	# Instantiate the scene to export
	var scene_root := map_scene.instantiate()
	if not scene_root:
		push_error("MapGenerator: Failed to instantiate scene for GLTF export")
		return false

	# Create GLTF document
	var gltf_document := GLTFDocument.new()
	var gltf_state := GLTFState.new()

	# Append scene to GLTF state
	var err := gltf_document.append_from_scene(scene_root, gltf_state)
	if err != OK:
		push_error("MapGenerator: Failed to append scene to GLTF state (error: %d)" % err)
		scene_root.free()
		return false

	# Embed metadata in GLTF extras
	var total_time := Time.get_ticks_msec() - _generation_start_time
	var metadata := _build_metadata(total_time)
	gltf_state.json["extras"] = metadata

	# Write GLTF to file
	err = gltf_document.write_to_filesystem(gltf_state, gltf_path)
	if err != OK:
		push_error("MapGenerator: Failed to write GLTF to %s (error: %d)" % [gltf_path, err])
		scene_root.free()
		return false

	# The export instance is detached, so deferred queue_free() would never run.
	scene_root.free()

	return true


## Save metadata to JSON file
func _save_metadata_json(metadata: Dictionary, json_path: String) -> bool:
	var json_string := JSON.stringify(metadata, "\t")

	var file := FileAccess.open(json_path, FileAccess.WRITE)
	if not file:
		push_error("MapGenerator: Failed to open metadata file for writing: %s" % json_path)
		return false

	file.store_string(json_string)
	file.close()

	return true


## Validate exported file is loadable
func _validate_exported_file(file_path: String, format: GenConfig.ExportFormat) -> bool:
	match format:
		GenConfig.ExportFormat.PACKED_SCENE:
			return _validate_packed_scene(file_path)
		GenConfig.ExportFormat.GLTF:
			return _validate_gltf(file_path)
		_:
			return false


## Validate PackedScene file is loadable
func _validate_packed_scene(scene_path: String) -> bool:
	# Ensure path has .tscn extension
	var path := scene_path
	if not path.ends_with(".tscn"):
		path += ".tscn"

	# Check if file exists
	if not FileAccess.file_exists(path):
		push_error("MapGenerator: Exported scene file does not exist: %s" % path)
		return false

	# Try to load the scene
	var loaded_scene := ResourceLoader.load(path, "PackedScene")
	if not loaded_scene:
		push_error("MapGenerator: Failed to load exported scene: %s" % path)
		return false

	# Try to instantiate the scene
	var instance: Node = loaded_scene.instantiate()
	if not instance:
		push_error("MapGenerator: Failed to instantiate exported scene: %s" % path)
		return false

	# Validation instances are detached from the SceneTree.
	instance.free()

	return true


## Validate GLTF file is loadable
func _validate_gltf(gltf_path: String) -> bool:
	# Ensure path has .gltf or .glb extension
	var path := gltf_path
	if not path.ends_with(".gltf") and not path.ends_with(".glb"):
		path += ".gltf"

	# Check if file exists
	if not FileAccess.file_exists(path):
		push_error("MapGenerator: Exported GLTF file does not exist: %s" % path)
		return false

	# Try to load the GLTF
	var gltf_document := GLTFDocument.new()
	var gltf_state := GLTFState.new()

	var err := gltf_document.append_from_file(path, gltf_state)
	if err != OK:
		push_error("MapGenerator: Failed to load GLTF file: %s (error: %d)" % [path, err])
		return false

	# Try to generate scene from GLTF
	var scene := gltf_document.generate_scene(gltf_state)
	if not scene:
		push_error("MapGenerator: Failed to generate scene from GLTF: %s" % path)
		return false

	# Generated validation scenes are detached from the SceneTree.
	scene.free()

	return true


## Hash seed string to 64-bit integer using SHA-256
## This method is public to allow testing of deterministic behavior
func hash_seed(seed_str: String) -> int:
	var hash_context := HashingContext.new()
	hash_context.start(HashingContext.HASH_SHA256)
	hash_context.update(seed_str.to_utf8_buffer())
	var hash_bytes := hash_context.finish()

	# Convert first 8 bytes to 64-bit integer
	var seed_int: int = 0
	for i in range(min(8, hash_bytes.size())):
		seed_int = (seed_int << 8) | hash_bytes[i]

	return seed_int


## Start threaded generation pipeline
func _start_threaded_generation() -> void:
	# Create and start worker thread
	_generation_thread = Thread.new()
	_generation_thread.start(_generation_worker_thread)

	# Monitor thread progress on main thread
	_monitor_generation_thread()


## Monitor generation thread and handle completion
func _monitor_generation_thread() -> void:
	# Wait for thread to complete
	while _generation_thread and _generation_thread.is_alive():
		await get_tree().process_frame

	# Get result from thread
	if _generation_thread:
		var result: Dictionary = _generation_thread.wait_to_finish()
		_generation_thread = null

		# Handle result on main thread
		_finalize_generation(result)


## Worker thread for independent generation phases
func _generation_worker_thread() -> Dictionary:
	var result := {"success": false, "error": "", "context": generation_context}

	# Check for cancellation
	if _thread_should_cancel:
		result["error"] = "Generation cancelled"
		return result

	# Phase 1: Initialize seed and RNG (already done in generate_map)
	# Phase 2: Grid layout allocation
	if not _run_phase_threaded("grid_layout"):
		result["error"] = "Grid layout phase failed"
		return result

	# Phase 3: Shape grammar room generation
	if not _run_phase_threaded("shape_grammar"):
		result["error"] = "Shape grammar phase failed"
		return result

	# Phase 4: Hallway generation and dead-end removal
	if not _run_phase_threaded("hallway_generation"):
		result["error"] = "Hallway generation phase failed"
		return result

	# Phase 5: Outdoor/cave generation
	if not _run_phase_threaded("outdoor_generation"):
		result["error"] = "Outdoor generation phase failed"
		return result

	if not _run_phase_threaded("cave_generation"):
		result["error"] = "Cave generation phase failed"
		return result

	# Phase 6: Boss arena placement
	if not _run_phase_threaded("boss_arena"):
		result["error"] = "Boss arena phase failed"
		return result

	# Phases 7-12 require main thread (CSG, scene tree operations)
	# Signal that we need to continue on main thread
	result["success"] = true
	result["continue_on_main_thread"] = true
	return result


## Run a generation phase with profiling (thread-safe version)
func _run_phase_threaded(phase_name: String) -> bool:
	if _thread_should_cancel:
		return false

	# Start phase profiling
	var phase_start := Time.get_ticks_msec()
	current_phase = phase_name

	# Emit progress signal (thread-safe via call_deferred)
	call_deferred("emit_signal", "generation_progress", phase_name, 0.0)

	# Phases mutate the grid and RNG; replaying a partial phase is not a retry.
	var success: bool = _execute_phase(phase_name)

	# If phase succeeded, validate output
	if success:
		success = _validate_phase_output(phase_name)

		# Save debug state after successful phase
		if success and debug_system:
			call_deferred("_save_debug_state", phase_name)

	# End phase profiling
	var phase_end := Time.get_ticks_msec()
	var phase_time := phase_end - phase_start

	# Store phase time in context
	if generation_context:
		generation_context.phase_times[phase_name] = phase_time

	# Check against target time and log warning if exceeded
	if PHASE_TIME_TARGETS.has(phase_name):
		var target_time: int = PHASE_TIME_TARGETS[phase_name]
		if phase_time > target_time:
			var warning_msg := (
				"Phase '%s' exceeded target time: %d ms (target: %d ms)"
				% [phase_name, phase_time, target_time]
			)
			call_deferred("_deferred_warning", warning_msg)

	# Emit completion progress
	call_deferred("emit_signal", "generation_progress", phase_name, 1.0)

	return success


func _execute_phase(phase_name: String) -> bool:
	if rule_execution_pipeline and generation_context:
		var phase_rules := rule_module_loader.get_rules_for_phase(phase_name)
		if not phase_rules.is_empty():
			if not rule_execution_pipeline.execute_phase(phase_name, generation_context):
				return false
			generation_context.rule_modules_used = rule_execution_pipeline.get_applied_rules()

	match phase_name:
		"grid_layout":
			return _execute_grid_layout_phase()
		"shape_grammar":
			return _execute_shape_grammar_phase()
		"hallway_generation":
			return _execute_hallway_generation_phase()
		"outdoor_generation":
			return _execute_outdoor_generation_phase()
		"cave_generation":
			return _execute_cave_generation_phase()
		"boss_arena":
			return _execute_boss_arena_phase()
		"csg_geometry":
			return _execute_csg_geometry_phase()
		"prefab_placement":
			return _execute_prefab_placement_phase()
		"gameplay_placement":
			return _execute_gameplay_placement_phase()
		"navigation_baking":
			return _execute_navigation_baking_phase()
		"validation":
			return _execute_validation_phase()
		"export":
			return _execute_export_phase()
		_:
			push_warning("Unknown phase: %s" % phase_name)
			return true  # Don't fail on unknown phases


## Validate phase output
func _validate_phase_output(phase_name: String) -> bool:
	if not validation_system:
		return true  # Skip validation if system not initialized

	var result: ValidationSystem.ValidationResult = null

	match phase_name:
		"grid_layout":
			result = validation_system.validate_grid_layout(generation_context)
		"shape_grammar":
			result = validation_system.validate_room_generation(generation_context)
		"hallway_generation":
			result = validation_system.validate_connectivity(generation_context)
		"navigation_baking":
			result = validation_system.validate_navigation_mesh(generation_context)
		_:
			return true  # No validation for this phase

	if not result:
		return true

	# Log warnings
	for warning in result.warnings:
		call_deferred("_deferred_warning", "MapGenerator: %s" % warning)

	# Check if validation passed
	if not result.is_valid:
		var error_ctx := ErrorHandler.ErrorContext.new(
			phase_name, 1, "Validation failed: %s" % result.error_message
		)
		error_contexts.append(error_ctx)
		call_deferred(
			"_deferred_error",
			"MapGenerator: Phase '%s' validation failed: %s" % [phase_name, result.error_message]
		)
		return false

	return true


## Execute grid layout phase
func _execute_grid_layout_phase() -> bool:
	if not grid_manager or not generation_context:
		push_error("Grid manager or context not initialized")
		return false
	if not config:
		push_error("Generation config not initialized")
		return false

	# Rule modules may provide the initial grid; preserve their output and
	# fall back to the built-in initializer when no rule applies.
	if generation_context.grid.is_empty():
		grid_manager.initialize_grid(config.map_size)
		generation_context.grid = grid_manager.grid
		generation_context.grid_size = config.map_size
	else:
		grid_manager.grid = generation_context.grid
		grid_manager.grid_size = generation_context.grid_size

	return true


## Execute shape grammar phase
func _execute_shape_grammar_phase() -> bool:
	if not shape_grammar or not generation_context:
		push_error("Shape grammar or context not initialized")
		return false

	# Load theme for shape grammar rules
	var theme: MapTheme = null
	if theme_manager:
		theme = theme_manager.get_theme(config.theme)

	# Generate rooms using shape grammar
	var room_count := _calculate_room_count(config.map_size)
	generation_context.rooms.clear()

	for i in range(room_count):
		if _thread_should_cancel:
			return false

		# Determine room type based on index
		var room_type: Room.RoomType
		if i == room_count - 1 and config.enable_boss_arena:
			room_type = Room.RoomType.BOSS_ARENA
		elif i < room_count * 0.3:
			room_type = Room.RoomType.SMALL
		elif i < room_count * 0.7:
			room_type = Room.RoomType.MEDIUM
		else:
			room_type = Room.RoomType.LARGE

		# Find a suitable center position for the room
		var center := _find_room_placement(generation_context.grid, room_type)
		if center == Vector2i(-1, -1):
			continue  # Skip if no suitable position found

		# Generate room shape
		var target_size := _get_room_target_size(room_type)
		var room_shape := shape_grammar.generate_room_shape(
			center, target_size, room_type, generation_context.rng, theme
		)

		# Create room and place it on grid
		var room := Room.new()
		room.id = i
		room.center = center
		room.type = room_type
		room.poly_points = room_shape

		# Convert polygon to grid cells
		room.cells = shape_grammar.polygon_to_grid_cells(room_shape, config.map_size)
		if room.cells.is_empty():
			continue
		room.entrance_points = shape_grammar.find_entrance_points(room.cells)
		if room.entrance_points.is_empty():
			continue
		var overlaps := false
		for cell_pos: Vector2i in room.cells:
			if generation_context.grid[cell_pos.y][cell_pos.x].type != Cell.Type.EMPTY:
				overlaps = true
				break
		if overlaps:
			continue
		# Concave polygons need a representative cell on the actual floor.
		if room.center not in room.cells:
			var closest := room.cells[0]
			for cell_pos: Vector2i in room.cells:
				if cell_pos.distance_squared_to(center) < closest.distance_squared_to(center):
					closest = cell_pos
			room.center = closest

		# Mark cells on grid
		for cell_pos: Vector2i in room.cells:
			var cell := grid_manager.get_cell_at(cell_pos)
			if cell:
				var cell_type := (
					Cell.Type.BOSS_ARENA
					if room_type == Room.RoomType.BOSS_ARENA
					else Cell.Type.ROOM
				)
				cell.type = cell_type
				cell.room_id = room.id

		generation_context.rooms.append(room)
	if not generation_context.rooms.is_empty():
		generation_context.player_start_position = generation_context.rooms[0].center
		generation_context.exit_position = _find_exit_position()

	return generation_context.rooms.size() > 0


func _find_exit_position() -> Vector2i:
	if not generation_context or generation_context.rooms.is_empty():
		return Vector2i(-1, -1)
	var start := generation_context.player_start_position
	var selected := Vector2i(-1, -1)
	var selected_distance := -1
	var found_boss := false
	for room: Room in generation_context.rooms:
		if room.cells.is_empty():
			continue
		var is_boss := room.type == Room.RoomType.BOSS_ARENA
		if found_boss and not is_boss:
			continue
		var distance := room.center.distance_squared_to(start)
		if is_boss and not found_boss:
			selected = Vector2i(-1, -1)
			selected_distance = -1
			found_boss = true
		if distance > selected_distance:
			selected = room.center
			selected_distance = distance
	return selected


## Execute hallway generation phase
func _execute_hallway_generation_phase() -> bool:
	if not hallway_generator or not generation_context:
		push_error("Hallway generator or context not initialized")
		return false

	# Generate hallways connecting rooms
	generation_context.hallways = hallway_generator.generate_hallways(
		generation_context.rooms, generation_context.grid
	)

	# Remove dead ends
	hallway_generator.remove_dead_ends(generation_context.grid)

	return generation_context.hallways.size() > 0


## Execute outdoor generation phase
func _execute_outdoor_generation_phase() -> bool:
	if config.outdoor_bias <= 0.0:
		return true  # Skip if outdoor bias is 0

	if not outdoor_park_generator or not generation_context:
		push_error("Outdoor park generator or context not initialized")
		return false

	# Generate outdoor areas
	generation_context.outdoor_areas = outdoor_park_generator.generate_outdoor_areas(
		generation_context
	)

	return true


## Execute cave generation phase
func _execute_cave_generation_phase() -> bool:
	if config.cave_bias <= 0.0:
		return true  # Skip if cave bias is 0

	if not cave_system_generator or not generation_context:
		push_error("Cave system generator or context not initialized")
		return false

	# Generate cave areas
	generation_context.cave_areas = cave_system_generator.generate_cave_areas(generation_context)

	return true


## Execute boss arena phase
func _execute_boss_arena_phase() -> bool:
	if not config.enable_boss_arena:
		return true  # Skip if boss arenas disabled

	if not boss_arena_generator or not generation_context:
		push_error("Boss arena generator or context not initialized")
		return false

	# Populate existing boss arena rooms and materialize their gameplay records.
	# The generator exposes both the spawn-marker and arena-element operations;
	# the shape phase may legitimately produce no boss room.
	var boss_rooms := generation_context.rooms.filter(
		func(r: Room) -> bool: return r.type == Room.RoomType.BOSS_ARENA
	)

	for boss_room: Room in boss_rooms:
		# The shape phase creates the room; this phase owns its gameplay record.
		# Keep the operation idempotent so a retried phase cannot duplicate a boss.
		if not boss_room.metadata.has("boss_spawn"):
			boss_arena_generator.place_boss_spawn_marker(boss_room, generation_context)
		boss_arena_generator.add_arena_elements(boss_room, generation_context)
	return true


## Execute CSG geometry phase
func _execute_csg_geometry_phase() -> bool:
	if not csg_builder or not generation_context:
		push_error("CSG builder or context not initialized")
		return false

	# Initialize CSG builder with context
	csg_builder.initialize(generation_context)

	# Build CSG geometry
	generation_context.csg_root = csg_builder.build_geometry()

	if generation_context.csg_root:
		# Updating CSG requires a SceneTree, not the player's world or navigation map.
		_generation_viewport = SubViewport.new()
		_generation_viewport.own_world_3d = true
		_generation_viewport.size = Vector2i.ONE
		_generation_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		_generation_viewport.gui_disable_input = true
		add_child(_generation_viewport)
		_generation_viewport.add_child(generation_context.csg_root)
	return generation_context.csg_root != null


## Execute prefab placement phase
func _execute_prefab_placement_phase() -> bool:
	if not prefab_system or not generation_context:
		push_error("Prefab system or context not initialized")
		return false

	# Load theme for prefab filtering
	var theme: MapTheme = null
	if theme_manager:
		theme = theme_manager.get_theme(config.theme)

	# Place prefabs through the current room/context API and retain only the
	# instantiated nodes required by downstream batching and export.
	var placement_results: Array = prefab_system.place_prefabs_in_rooms(
		generation_context.rooms, generation_context, generation_context.csg_root
	)
	generation_context.prefab_instances.clear()
	for placement_result: Variant in placement_results:
		if placement_result and placement_result.node:
			generation_context.prefab_instances.append(placement_result.node)

	# Apply MultiMesh optimization if enabled
	if config.use_multimesh and multimesh_manager and generation_context.csg_root.is_inside_tree():
		multimesh_manager.apply_multimesh_batching(
			placement_results, generation_context.csg_root, generation_context
		)

	return true


## Execute gameplay placement phase
func _execute_gameplay_placement_phase() -> bool:
	if not gameplay_element_placer or not generation_context:
		push_error("Gameplay element placer or context not initialized")
		return false

	# Secret cells and their entrances must exist before CSG and navigation baking.
	if config.enable_secrets and secret_room_generator:
		generation_context.secret_rooms = secret_room_generator.generate_secret_rooms(
			generation_context
		)
		secret_room_generator.place_secret_items(generation_context)

	if config.enable_key_locks and key_lock_system:
		var locks: Dictionary = key_lock_system.generate_key_lock_system(generation_context)
		generation_context.key_placements.assign(locks["keys"])
		generation_context.metadata["locked_doors"] = locks["locked_doors"]

	gameplay_element_placer.place_monster_spawns(generation_context)
	gameplay_element_placer.place_boss_monsters(generation_context)
	gameplay_element_placer.place_weapons_and_ammo(generation_context)
	gameplay_element_placer.place_health_pickups(generation_context)

	return true


## Execute navigation baking phase
func _execute_navigation_baking_phase() -> bool:
	if not navmesh_baker or not generation_context:
		push_error("Navigation mesh baker or context not initialized")
		return false
	if not generation_context.csg_root or not generation_context.csg_root.is_inside_tree():
		push_error("Navigation baking requires the prepared generated geometry tree")
		return false

	# Initialize navigation mesh baker with context
	navmesh_baker.initialize(generation_context)

	# Bake navigation mesh
	var success: bool = navmesh_baker.bake_navigation_mesh()

	# Get the navigation region from the baker
	if success:
		generation_context.navigation_region = navmesh_baker.get_navigation_region()

	return success


## Execute validation phase
func _execute_validation_phase() -> bool:
	if not validation_system or not generation_context:
		push_error("Validation system or context not initialized")
		return false

	var validations: Array[ValidationSystem.ValidationResult] = [
		validation_system.validate_player_start(generation_context),
		validation_system.validate_key_lock_progression(generation_context),
		validation_system.validate_connectivity(generation_context),
		validation_system.validate_monster_spawns(generation_context)
	]

	# Check if all validations passed
	for result: ValidationSystem.ValidationResult in validations:
		if not result.is_valid:
			push_error("Validation failed: %s" % result.error_message)
			return false

		# Log warnings
		for warning in result.warnings:
			push_warning("Validation warning: %s" % warning)

	return true


## Execute export phase (optimization passes)
func _execute_export_phase() -> bool:
	if not generation_context:
		push_error("Context not initialized")
		return false

	# Apply LOD if enabled
	if config.enable_lod and lod_manager and generation_context.csg_root.is_inside_tree():
		lod_manager.initialize(generation_context)
		lod_manager.apply_lod_to_scene(generation_context.csg_root)

	# Apply occlusion culling if enabled
	if (
		config.enable_occlusion_culling
		and occlusion_culling_manager
		and generation_context.csg_root.is_inside_tree()
	):
		occlusion_culling_manager.initialize(generation_context)
		var occluders_root: Node3D = occlusion_culling_manager.generate_occluders()
		if occluders_root and generation_context.csg_root:
			generation_context.csg_root.add_child(occluders_root)

	return true


## Finalize generation on main thread
func _finalize_generation(result: Dictionary) -> void:
	if not result["success"]:
		_release_generated_nodes()
		is_generating = false
		generation_failed.emit(result["error"])
		return

	var context := generation_context
	# If we need to continue on main thread, run remaining phases
	if result.get("continue_on_main_thread", false):
		await _run_main_thread_phases()

	# Check if generation was cancelled or failed during main thread phases
	if not is_generating or generation_context != context:
		return

	# Calculate total generation time
	var total_time := Time.get_ticks_msec() - _generation_start_time

	# Check against map size target
	if config and config.map_size:
		var map_size := config.map_size
		if MAP_SIZE_TARGETS.has(map_size):
			var target_time: int = MAP_SIZE_TARGETS[map_size]
			if total_time > target_time:
				push_warning(
					(
						"Map generation exceeded target time for size %dx%d: %d ms (target: %d ms)"
						% [map_size.x, map_size.y, total_time, target_time]
					)
				)

	# Log profiling information
	_log_profiling_info(total_time)

	# Save generation summary if debug mode enabled
	_save_generation_summary()

	# Build final map scene
	var metadata := _build_metadata(total_time)
	var map_scene := _build_map_scene(metadata)
	if not map_scene:
		abort_generation("Generated scene could not be packed")
		return

	is_generating = false
	generation_completed.emit(map_scene, metadata)


## Run phases that require main thread (CSG, scene tree operations)
func _run_main_thread_phases() -> void:
	var context := generation_context
	# Layout-changing gameplay precedes geometry; optimization precedes its bake.
	for phase_name: String in [
		"gameplay_placement",
		"csg_geometry",
		"prefab_placement",
		"export",
		"navigation_baking",
		"validation"
	]:
		if not await _run_phase_main_thread(phase_name):
			if is_generating and generation_context == context:
				abort_generation("%s phase failed" % phase_name)
			return


## Run a phase on the main thread with profiling
func _run_phase_main_thread(phase_name: String) -> bool:
	if _thread_should_cancel or not is_generating:
		return false
	var context := generation_context

	if phase_name == "navigation_baking":
		# Let deferred CSG/collision changes finish in the private world first.
		await get_tree().physics_frame
		await get_tree().process_frame
		if not is_generating or generation_context != context:
			return false

	# Start phase profiling
	var phase_start := Time.get_ticks_msec()
	current_phase = phase_name

	# Emit progress signal
	generation_progress.emit(phase_name, 0.0)

	var success: bool = _execute_phase(phase_name)

	# If phase succeeded, validate output
	if success:
		success = _validate_phase_output(phase_name)

		# Save debug state after successful phase
		if success and debug_system:
			_save_debug_state(phase_name)

	# End phase profiling
	var phase_end := Time.get_ticks_msec()
	var phase_time := phase_end - phase_start

	# Store phase time in context
	if generation_context:
		generation_context.phase_times[phase_name] = phase_time

	# Check against target time and log warning if exceeded
	if PHASE_TIME_TARGETS.has(phase_name):
		var target_time: int = PHASE_TIME_TARGETS[phase_name]
		if phase_time > target_time:
			push_warning(
				(
					"Phase '%s' exceeded target time: %d ms (target: %d ms)"
					% [phase_name, phase_time, target_time]
				)
			)

	# Emit completion progress
	generation_progress.emit(phase_name, 1.0)
	return success and is_generating and generation_context == context


## Build metadata dictionary for export
func _build_metadata(total_time: int) -> Dictionary:
	var metadata := {
		"seed": config.map_seed if config else "",
		"seed_hash": generation_context.seed_hash if generation_context else 0,
		"generator_revision": GENERATOR_REVISION,
		"generation_time": float(total_time) / 1000.0,
		"map_size": [config.map_size.x, config.map_size.y] if config else [0, 0],
		"theme": _get_theme_name(config.theme) if config else "unknown",
		"config": _build_config_metadata(),
		"statistics": _build_statistics_metadata(),
		"rule_modules_used": _get_rule_modules_used(),
		"replacement_catalog": get_replacement_catalog_metadata(),
		"gameplay": _build_gameplay_metadata(),
		"phase_times": _build_phase_times_metadata()
	}
	return metadata


func get_replacement_catalog_metadata() -> Array:
	if prefab_system == null:
		return []
	return prefab_system.get_replacement_metadata()


## Variant records are retained in the PackedScene, not only transient signals.
func _build_gameplay_metadata() -> Dictionary:
	if not generation_context:
		return {}
	var gameplay := {
		"player_start": generation_context.player_start_position,
		"exit_position": generation_context.exit_position,
		"monsters": generation_context.monster_spawns.duplicate(true),
		"items": generation_context.item_spawns.duplicate(true),
		"keys": generation_context.key_placements.duplicate(true),
		"locked_doors": generation_context.metadata.get("locked_doors", []).duplicate(true),
		"secrets": generation_context.secret_rooms.duplicate(true)
	}
	var extraction := _generated_extraction_record()
	if not extraction.is_empty():
		gameplay["extraction"] = extraction
	return gameplay


## Build configuration metadata
func _build_config_metadata() -> Dictionary:
	if not config:
		return {}

	return {
		"outdoor_bias": config.outdoor_bias,
		"cave_bias": config.cave_bias,
		"prefab_detail_level": config.prefab_detail_level,
		"prop_density": config.prop_density,
		"decorative_density": config.decorative_density,
		"monster_density": config.monster_density,
		"minimum_monsters": config.minimum_monsters,
		"difficulty_scaling": _get_difficulty_name(config.difficulty_scaling),
		"item_density": config.item_density,
		"secret_room_count": config.secret_room_count,
		"enable_key_locks": config.enable_key_locks,
		"enable_boss_arena": config.enable_boss_arena,
		"enable_secrets": config.enable_secrets,
		"enable_lod": config.enable_lod,
		"enable_occlusion_culling": config.enable_occlusion_culling,
		"use_multimesh": config.use_multimesh
	}


## Build statistics metadata
func _build_statistics_metadata() -> Dictionary:
	if not generation_context:
		return {}

	var stats := {
		"room_count": generation_context.rooms.size(),
		"hallway_count": generation_context.hallways.size(),
		"secret_count": generation_context.secret_rooms.size(),
		"monster_spawn_count": generation_context.monster_spawns.size(),
		"item_spawn_count": generation_context.item_spawns.size(),
		"outdoor_area_count": generation_context.outdoor_areas.size(),
		"cave_area_count": generation_context.cave_areas.size()
	}

	return stats


## Get list of rule modules used during generation
func _get_rule_modules_used() -> Array[String]:
	var modules: Array[String] = []

	if rule_execution_pipeline:
		modules = rule_execution_pipeline.get_applied_rules()

	return modules


## Build phase times metadata (convert to seconds)
func _build_phase_times_metadata() -> Dictionary:
	var phase_times := {}

	if generation_context:
		for phase_name: String in generation_context.phase_times:
			var time_ms: int = generation_context.phase_times[phase_name]
			phase_times[phase_name] = float(time_ms) / 1000.0  # Convert to seconds

	return phase_times


## Get theme name from enum
func _get_theme_name(theme_type: GenerationConfig.ThemeType) -> String:
	match theme_type:
		GenerationConfig.ThemeType.TECH:
			return "tech"
		GenerationConfig.ThemeType.HELL:
			return "hell"
		GenerationConfig.ThemeType.URBAN:
			return "urban"
		GenerationConfig.ThemeType.CAVE:
			return "cave"
		GenerationConfig.ThemeType.JUMBLED:
			return "jumbled"
		_:
			return "unknown"


## Get difficulty name from enum
func _get_difficulty_name(difficulty: GenerationConfig.DifficultyLevel) -> String:
	match difficulty:
		GenerationConfig.DifficultyLevel.EASY:
			return "easy"
		GenerationConfig.DifficultyLevel.NORMAL:
			return "normal"
		GenerationConfig.DifficultyLevel.HARD:
			return "hard"
		GenerationConfig.DifficultyLevel.NIGHTMARE:
			return "nightmare"
		_:
			return "normal"


## Log profiling information
func _log_profiling_info(total_time: int) -> void:
	if not generation_context:
		return

	var profiling_output := "Map generation profiling:\n"
	profiling_output += "  Total time: %d ms\n" % total_time
	profiling_output += "  Phase times:\n"

	for phase_name: String in generation_context.phase_times:
		var phase_time: int = generation_context.phase_times[phase_name]
		var target_time: int = PHASE_TIME_TARGETS.get(phase_name, 0)
		var status := " (OK)" if target_time == 0 or phase_time <= target_time else " (EXCEEDED)"
		profiling_output += "    %s: %d ms%s\n" % [phase_name, phase_time, status]

	print(profiling_output)


## Check if generation met performance targets
func is_within_performance_target(map_size: Vector2i, total_time_ms: int) -> bool:
	if not MAP_SIZE_TARGETS.has(map_size):
		return true  # No target defined for this size

	var target_time: int = MAP_SIZE_TARGETS[map_size]
	return total_time_ms <= target_time


## Get performance target for map size
func get_performance_target(map_size: Vector2i) -> int:
	return MAP_SIZE_TARGETS.get(map_size, 0)


## Get phase time target
func get_phase_target(phase_name: String) -> int:
	return PHASE_TIME_TARGETS.get(phase_name, 0)


## Handle invalid prefab gracefully (skip with warning)
func skip_invalid_prefab(prefab_path: String, reason: String) -> void:
	push_warning("MapGenerator: Skipping invalid prefab '%s': %s" % [prefab_path, reason])

	# Track skipped prefabs in context
	if generation_context:
		if not generation_context.has("skipped_prefabs"):
			generation_context.set("skipped_prefabs", [])
		generation_context.skipped_prefabs.append(
			{"path": prefab_path, "reason": reason, "timestamp": Time.get_ticks_msec()}
		)


## Abort generation with error report
func abort_generation(reason: String) -> void:
	push_error("MapGenerator: Aborting generation - %s" % reason)

	# Create error report
	if error_handler and not error_contexts.is_empty():
		var report := error_handler.create_error_report(error_contexts)
		report["abort_reason"] = reason

		# Save error report to debug directory
		var debug_dir := "res://debug/map_generator/"
		DirAccess.make_dir_recursive_absolute(debug_dir)
		var report_path := debug_dir + "error_report_%d.json" % Time.get_ticks_msec()
		error_handler.save_error_report(report, report_path)

	# Generated scene nodes are detached until packing. Failed or cancelled
	# generations must release them explicitly because queue_free() cannot run on
	# nodes that were never attached to a SceneTree.
	_release_generated_nodes()

	# Emit failure signal
	is_generating = false
	generation_failed.emit(reason)


## Check if generation should abort (after multiple failures)
func should_abort_generation() -> bool:
	# Count consecutive failures
	var consecutive_failures := 0
	for ctx in error_contexts:
		if ctx.attempt_number >= ErrorHandler.MAX_RETRY_ATTEMPTS:
			consecutive_failures += 1

	# Abort if we have multiple phase failures
	return consecutive_failures >= 2


## Save debug state for current phase (called on main thread)
func _save_debug_state(phase_name: String) -> void:
	if debug_system and generation_context:
		debug_system.save_phase_state(phase_name, generation_context)


## Save final generation summary
func _save_generation_summary() -> void:
	if debug_system and generation_context:
		debug_system.save_generation_summary(generation_context)


## Get feature availability report
func get_feature_availability_report() -> Dictionary:
	if feature_availability:
		return feature_availability.create_availability_report()
	return {}


## Check if a specific feature is available
func is_feature_available(feature_name: String) -> bool:
	if feature_availability:
		return feature_availability.is_feature_available(feature_name)
	return false


## Get recommended configuration based on available features
func get_recommended_config() -> Dictionary:
	if feature_availability:
		return feature_availability.get_recommended_config()
	return {}


## Calculate room count based on map size
func _calculate_room_count(map_size: Vector2i) -> int:
	var area := map_size.x * map_size.y
	# Roughly 1 room per 400 cells, with min 5 and max 30
	return clampi(int(float(area) / 400.0), 5, 30)


## Find suitable placement for a room
func _find_room_placement(grid: Array[Array], _room_type: Room.RoomType) -> Vector2i:
	var attempts := 0
	var max_attempts := 100
	var min_spacing := 8  # Minimum distance between room centers

	while attempts < max_attempts:
		var x := generation_context.rng.randi_range(10, grid[0].size() - 10)
		var y := generation_context.rng.randi_range(10, grid.size() - 10)
		var pos := Vector2i(x, y)

		# Check if position is empty and far enough from other rooms
		var cell := grid_manager.get_cell_at(pos)
		if cell and cell.type == Cell.Type.EMPTY:
			var too_close := false
			for room: Room in generation_context.rooms:
				if pos.distance_to(room.center) < min_spacing:
					too_close = true
					break

			if not too_close:
				return pos

		attempts += 1

	return Vector2i(-1, -1)  # No suitable position found


## Get target size for room type
func _get_room_target_size(room_type: Room.RoomType) -> int:
	match room_type:
		Room.RoomType.SMALL:
			return 6  # 4-8 cells
		Room.RoomType.MEDIUM:
			return 12  # 9-16 cells
		Room.RoomType.LARGE:
			return 24  # 17-32 cells
		Room.RoomType.BOSS_ARENA:
			return 50  # 40+ cells
		_:
			return 12


func _generated_enemy_id(record: Dictionary) -> String:
	var enemy_id := str(record.get("enemy_id", record.get("id", "")))
	if not enemy_id.is_empty():
		return enemy_id
	return "warlord" if record.get("type", "") == "boss" else "grunt_basic"


func _generated_enemy_supported(record: Dictionary) -> bool:
	# Generated records may be retained even when their runtime realization is
	# disabled or unsupported. Only runtime-supported monster/boss records get
	# mission linkage; their records remain available in the generation manifest.
	var supported: Variant = record.get("supported", true)
	if supported is bool and not supported:
		return false
	var record_type := str(record.get("type", ""))
	return record_type in ["monster", "boss"] and not _generated_enemy_id(record).is_empty()


func _generated_enemy_enabled(record: Dictionary) -> bool:
	var disabled: Variant = record.get("disabled", false)
	if disabled is bool and disabled:
		return false
	var enabled: Variant = record.get("enabled", true)
	if enabled is bool and not enabled:
		return false
	return true


func _generated_enemy_objective(record: Dictionary, index: int) -> Dictionary:
	if record.get("type", "") == "boss":
		return {"description": "Defeat generated boss", "final": true, "order": 1000 + index}
	if record.get("type", "") != "monster" or not _generated_enemy_supported(record):
		return {}
	if not _generated_enemy_enabled(record):
		return {}
	var objective := {"description": "Defeat generated enemy", "order": 100 + index}
	if record.get("optional", false) is bool and record.get("optional", false):
		objective["optional"] = true
	return objective


func _apply_generated_enemy_objective(
	enemy_actor: EnemySpawnerActor, record: Dictionary, index: int
) -> void:
	# One actor identity maps to one objective. Do not replace an objective
	# supplied by a future generator record or authoring pass.
	if enemy_actor.has_meta("mission_objective"):
		return
	var objective := _generated_enemy_objective(record, index)
	if not objective.is_empty():
		enemy_actor.set_meta("mission_objective", objective)


func _generated_item_rarity_tier(record: Dictionary, fallback: int = -1) -> int:
	var raw_tier: Variant = record.get("rarity_tier", record.get("item_tier", fallback))
	if raw_tier is int:
		return clampi(int(raw_tier), 0, 5)
	match str(raw_tier).strip_edges().to_lower():
		"common":
			return 0
		"uncommon":
			return 1
		"rare":
			return 2
		"epic":
			return 3
		"legendary":
			return 4
		"unique":
			return 5
		_:
			return fallback


func _generated_item_config(record: Dictionary) -> Dictionary:
	var item_type := str(record.get("type", ""))
	var item_id := str(record.get("item_id", ""))
	var weapon_id := str(record.get("weapon_id", ""))
	var category := PickupSpawnerActor.PickupCategory.HEALTH
	var rarity_tier := _generated_item_rarity_tier(record)
	var supported := true

	match item_type:
		"weapon":
			category = PickupSpawnerActor.PickupCategory.WEAPON
			if weapon_id.is_empty():
				weapon_id = "shotgun"
			if item_id.is_empty():
				item_id = "weapon_" + weapon_id
		"ammo":
			category = PickupSpawnerActor.PickupCategory.AMMO
			if item_id.is_empty():
				item_id = "ammo_clip"
		"health":
			category = PickupSpawnerActor.PickupCategory.HEALTH
			if item_id.is_empty():
				item_id = "health_potion"
		"armor":
			category = PickupSpawnerActor.PickupCategory.ARMOR
			if item_id.is_empty():
				item_id = "armor_pickup"
		"powerup":
			category = PickupSpawnerActor.PickupCategory.POWERUP
			if item_id.is_empty():
				item_id = "speed_powerup"
		"high_value":
			# Secret rewards have no source catalog ID. Resolve them to the
			# deterministic, catalog-backed damage powerup instead of dropping
			# the reward or inventing a new pickup category.
			category = GENERATED_SECRET_REWARD_CATEGORY
			item_id = GENERATED_SECRET_REWARD_ITEM_ID
			rarity_tier = _generated_item_rarity_tier(record, GENERATED_SECRET_REWARD_RARITY_TIER)
		_:
			# Unknown records remain outside the PickupSpawnerActor catalog.
			supported = false

	return {
		"supported": supported,
		"category": category,
		"item_id": item_id,
		"weapon_id": weapon_id,
		"rarity_tier": rarity_tier
	}


func _generated_extraction_record() -> Dictionary:
	if not generation_context:
		return {}
	var position := generation_context.exit_position
	if (
		position.x < 0
		or position.y < 0
		or position.y >= generation_context.grid.size()
		or position.x >= generation_context.grid[position.y].size()
	):
		return {}
	var cell: Cell = generation_context.grid[position.y][position.x]
	if not cell or cell.type == Cell.Type.EMPTY:
		return {}
	var prerequisites: Array[String] = []
	for index in range(generation_context.key_placements.size()):
		prerequisites.append("KeyPickup_%d" % index)
	for index in range(generation_context.metadata.get("locked_doors", []).size()):
		prerequisites.append("LockedDoor_%d" % index)
	for record: Dictionary in generation_context.monster_spawns:
		if record.get("type", "") != "boss":
			continue
		var boss_id := str(record.get("id", ""))
		if not boss_id.is_empty():
			prerequisites.append(boss_id)

	return {
		"id": "generated_extraction",
		"actor_id": "generated_extraction",
		"grid_position": position,
		"room_id": cell.room_id,
		"position": Vector3(position.x * 2.0 + 1.0, cell.height + 0.5, position.y * 2.0 + 1.0),
		"prerequisites": prerequisites
	}


## Build final map scene from generation context
func _build_map_scene(metadata: Dictionary) -> PackedScene:
	var scene := PackedScene.new()

	# Generated maps are editable level documents, not anonymous world roots.
	var root := LevelRootScript.new()
	root.name = "GeneratedMap"
	root.set_meta("generation", metadata.duplicate(true))
	theme_manager.apply_lighting_to_scene(root)

	var player_spawn: LevelSpawnPoint = LevelSpawnPointScript.new()
	player_spawn.name = "PlayerSpawn"
	player_spawn.spawn_type = LevelSpawnPoint.SpawnType.PLAYER
	player_spawn.add_to_group("spawn_player", true)
	var start := generation_context.player_start_position
	player_spawn.position = Vector3(
		start.x * 2.0 + 1.0,
		generation_context.grid[start.y][start.x].height + 1.0,
		start.y * 2.0 + 1.0
	)
	root.add_child(player_spawn)
	for index in range(generation_context.monster_spawns.size()):
		var record: Dictionary = generation_context.monster_spawns[index]
		var world_position: Vector3 = record.get("world_position", Vector3.ZERO)

		# Keep the typed marker for authoring/validation compatibility. The
		# spawner actor is the canonical runtime source for generated encounters.
		var enemy_spawn: LevelSpawnPoint = LevelSpawnPointScript.new()
		enemy_spawn.name = "EnemySpawn_%d" % index
		enemy_spawn.spawn_type = LevelSpawnPoint.SpawnType.ENEMY
		enemy_spawn.enemy_id = str(record.get("enemy_id", record.get("id", "")))
		enemy_spawn.position = world_position + Vector3.UP
		enemy_spawn.add_to_group("spawn_enemy", true)
		enemy_spawn.set_meta("generation", record.duplicate(true))
		root.add_child(enemy_spawn)

		var enemy_actor: EnemySpawnerActor = EnemySpawnerActorScript.new()
		enemy_actor.name = "EnemySpawner_%d" % index
		enemy_actor.actor_id = str(record.get("id", enemy_actor.name))
		enemy_actor.enemy_id = _generated_enemy_id(record)
		enemy_actor.tier = int(record.get("tier", 1))
		enemy_actor.auto_spawn = true
		enemy_actor.is_enabled = _generated_enemy_enabled(record)
		enemy_actor.position = world_position + Vector3.UP
		enemy_actor.set_meta("generation", record.duplicate(true))
		_apply_generated_enemy_objective(enemy_actor, record, index)
		root.add_child(enemy_actor)

	for index in range(generation_context.item_spawns.size()):
		var record: Dictionary = generation_context.item_spawns[index]
		var world_position: Vector3 = record.get(
			"world_position", record.get("position", Vector3.ZERO)
		)
		var item_config := _generated_item_config(record)
		if not item_config["supported"]:
			push_warning(
				"[MapGenerator] Unsupported generated item type: %s" % str(record.get("type", ""))
			)
			continue
		var item_actor: PickupSpawnerActor = PickupSpawnerActorScript.new()
		item_actor.name = "PickupSpawner_%d" % index
		item_actor.actor_id = str(record.get("id", item_actor.name))
		item_actor.pickup_category = item_config["category"]
		item_actor.item_id = item_config["item_id"]
		item_actor.weapon_id = item_config["weapon_id"]
		item_actor.rarity_tier = int(item_config["rarity_tier"])
		item_actor.auto_spawn = true
		item_actor.position = world_position
		item_actor.set_meta("generation", record.duplicate(true))
		if item_config["rarity_tier"] >= 0:
			item_actor.set_meta("rarity_tier", item_config["rarity_tier"])
		if record.has("secret_room_id"):
			item_actor.set_meta(
				"mission_objective",
				{
					"description": "Discover generated secret reward",
					"secret_room_id": int(record.get("secret_room_id", -1)),
					"optional": true,
					"order": 9000 + index
				}
			)
		root.add_child(item_actor)
	for index in range(generation_context.key_placements.size()):
		var record: Dictionary = generation_context.key_placements[index]
		var color := str(record.get("color", "UNKNOWN"))
		var key_id := "key_" + color.to_lower()
		var key_actor: KeyPickupActor = KeyPickupActorScript.new()
		key_actor.name = "KeyPickup_%d" % index
		key_actor.actor_id = key_actor.name
		key_actor.key_id = key_id
		key_actor.position = record.get("position", Vector3.ZERO)
		key_actor.set_meta("generation", record.duplicate(true))
		key_actor.set_meta("color", color)
		key_actor.set_meta("key_color", color)
		key_actor.set_meta(
			"mission_objective",
			{"description": "Collect generated %s key" % color.to_lower(), "order": index * 2}
		)
		root.add_child(key_actor)

	var locked_doors: Array = generation_context.metadata.get("locked_doors", [])
	for index in range(locked_doors.size()):
		var record: Dictionary = locked_doors[index]
		var color := str(record.get("color", "UNKNOWN"))
		var key_id := "key_" + color.to_lower()
		var door_actor: DoorActor = DoorActorScript.new()
		door_actor.name = "LockedDoor_%d" % index
		door_actor.actor_id = door_actor.name
		door_actor.locked = true
		door_actor.required_key = key_id
		door_actor.position = record.get("position", Vector3.ZERO)
		door_actor.set_meta("generation", record.duplicate(true))
		door_actor.set_meta("color", color)
		door_actor.set_meta("key_color", color)
		door_actor.set_meta(
			"mission_objective",
			{
				"description": "Open generated %s door" % color.to_lower(),
				"requires": ["KeyPickup_%d" % index],
				"order": index * 2 + 1
			}
		)
		root.add_child(door_actor)

	var extraction_record := _generated_extraction_record()
	if not extraction_record.is_empty():
		var extraction_actor: SwitchActor = SwitchActorScript.new()
		extraction_actor.name = "GeneratedExtraction"
		extraction_actor.actor_id = extraction_record.id
		extraction_actor.one_shot = true
		extraction_actor.position = extraction_record.position
		extraction_actor.set_meta("generation", extraction_record.duplicate(true))
		extraction_actor.set_meta(
			"mission_objective",
			{
				"description": "Reach the generated extraction",
				"final": true,
				"requires": extraction_record.prerequisites,
				"order": 2000
			}
		)
		root.add_child(extraction_actor)

	# Add CSG geometry

	if generation_context.csg_root:
		generation_context.csg_root.get_parent().remove_child(generation_context.csg_root)
		root.add_child(generation_context.csg_root)
		generation_context.csg_root.owner = root

	# Add navigation region
	if generation_context.navigation_region:
		root.add_child(generation_context.navigation_region)
		generation_context.navigation_region.owner = root

	# LevelRoot owns the document's runtime-only ChannelSystem and canonical
	# ownership preparation. Its save preparation excludes that service from the
	# PackedScene while assigning the document root to generated descendants.
	root.prepare_for_save()
	var pack_error := scene.pack(root)

	# Packing copies the node state; it does not free the live source tree. Clear
	# context references first, then release the detached tree immediately so each
	# generation does not leak thousands of CSG, navigation, and renderer objects.
	generation_context.csg_root = null
	generation_context.navigation_region = null
	generation_context.prefab_instances.clear()
	root.free()
	if is_instance_valid(_generation_viewport):
		_generation_viewport.free()
	_generation_viewport = null

	if pack_error != OK:
		push_error("MapGenerator: Failed to pack generated scene (error: %d)" % pack_error)
		return null

	return scene


## Release generated nodes on cancellation, failure, or owner teardown.
func _release_generated_nodes() -> void:
	if generation_context:
		var geometry := generation_context.csg_root
		var navigation := generation_context.navigation_region
		generation_context.csg_root = null
		generation_context.navigation_region = null
		generation_context.prefab_instances.clear()
		if is_instance_valid(geometry):
			geometry.free()
		if is_instance_valid(navigation):
			navigation.free()
	if is_instance_valid(_generation_viewport):
		_generation_viewport.free()
	_generation_viewport = null
