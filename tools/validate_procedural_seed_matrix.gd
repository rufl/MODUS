extends SceneTree

const SEEDS: Array[String] = [
	"breakwater-01",
	"breakwater-02",
	"breakwater-03",
	"breakwater-04",
	"breakwater-05",
	"breakwater-06",
	"breakwater-07",
	"breakwater-08",
]
const PASSES_PER_SEED: int = 2
const GENERATION_TIMEOUT_MS: int = 60000


func _init() -> void:
	call_deferred("_run_matrix")


func _run_matrix() -> void:
	await process_frame
	var generator_script := load("res://game/scripts/map_generator/map_generator.gd") as GDScript
	if not generator_script:
		push_error("PROCEDURAL_SEED_MATRIX failed to load map generator")
		quit(1)
		return
	var generator: Node = generator_script.new()
	get_root().add_child(generator)
	var config: Resource = _create_bounded_config()
	if not config:
		generator.queue_free()
		quit(1)
		return
	var failures: Array[String] = []
	var signatures: Dictionary = {}
	var completed_passes := 0

	for map_seed: String in SEEDS:
		for pass_index: int in range(PASSES_PER_SEED):
			var result: Dictionary = await _generate(generator, map_seed, config)
			if not result.has("scene"):
				failures.append("%s pass %d: %s" % [map_seed, pass_index + 1, result.get("error", "no result")])
				continue
			var metadata: Dictionary = result.get("metadata", {})
			if metadata.get("seed", "") != map_seed:
				failures.append(
					"%s pass %d: metadata seed was %s" % [map_seed, pass_index + 1, metadata.get("seed", "")]
				)
				continue
			var signature: Dictionary = {
				"seed": metadata.get("seed", ""),
				"gameplay": metadata.get("gameplay", {}).duplicate(true),
			}
			if pass_index == 0:
				signatures[map_seed] = signature
			elif signatures.get(map_seed) != signature:
				failures.append("%s pass %d: deterministic signature changed" % [map_seed, pass_index + 1])
			completed_passes += 1

	generator.cancel_generation()
	generator.queue_free()
	print(
		"PROCEDURAL_SEED_MATRIX seeds=%d passes=%d completed=%d failures=%d" % [
			SEEDS.size(), PASSES_PER_SEED, completed_passes, failures.size()
		]
	)
	for failure: String in failures:
		push_error("PROCEDURAL_SEED_MATRIX failure: %s" % failure)
	quit(0 if failures.is_empty() else 1)


func _create_bounded_config() -> Resource:
	var config_script := load("res://game/scripts/map_generator/generation_config.gd") as GDScript
	if not config_script:
		push_error("PROCEDURAL_SEED_MATRIX failed to load generation config")
		return null
	var config: Resource = config_script.new()
	config.map_size = Vector2i(64, 64)
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


func _generate(generator: Node, map_seed: String, config: Resource) -> Dictionary:
	var result: Dictionary = {}
	var completed := func(_scene: PackedScene, metadata: Dictionary) -> void:
		result["metadata"] = metadata
		result["scene"] = true
	var failed := func(reason: String) -> void: result["error"] = reason
	generator.generation_completed.connect(completed)
	generator.generation_failed.connect(failed)
	generator.generate_map(map_seed, config)
	var deadline := Time.get_ticks_msec() + GENERATION_TIMEOUT_MS
	while result.is_empty() and Time.get_ticks_msec() < deadline:
		await process_frame
	if result.is_empty():
		generator.cancel_generation()
		result["error"] = "timed out after %d ms" % GENERATION_TIMEOUT_MS
	generator.generation_completed.disconnect(completed)
	generator.generation_failed.disconnect(failed)
	return result
