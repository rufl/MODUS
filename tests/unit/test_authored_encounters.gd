extends ModusGutTestBase

const LevelRootScript := preload("res://shared/editor_core/nodes/level_root.gd")
const EnemySpawnerScript := preload("res://shared/editor_core/actors/enemy_spawner_actor.gd")
const PickupSpawnerScript := preload("res://shared/editor_core/actors/pickup_spawner_actor.gd")


class Collector:
	extends CharacterBody3D
	var health: int = 20
	var max_health: int = 100
	var blood_overlay: Control


func test_author_document_cannot_spawn_rewards_or_start_encounters() -> void:
	var document: Node3D = LevelRootScript.new()
	document.authoring_mode = true
	var encounter := EnemySpawnerScript.new()
	var supplies := PickupSpawnerScript.new()
	document.add_child(encounter)
	document.add_child(supplies)
	add_child_autofree(document)
	encounter.start_runtime()
	supplies.start_runtime()
	encounter.trigger()
	supplies.trigger()
	await get_tree().process_frame
	assert_false(encounter.capture_runtime_state().encounter_started)
	assert_eq(supplies.capture_runtime_state().pickup_phase, "inactive")
	for child: Node in document.find_children("*", "", true, false):
		assert_false(
			child is Enemy or child is PickupBase,
			"Authoring never creates combatants or collectible rewards"
		)


func test_encounter_does_not_clear_between_wave_spawns_and_emits_once() -> void:
	var encounter := EnemySpawnerScript.new()
	encounter.auto_spawn = false
	encounter.spawn_count = 2
	add_child_autofree(encounter)
	watch_signals(encounter)
	encounter._encounter_started = true
	encounter._records = [{"alive": false}]
	encounter._finish_if_cleared()
	assert_signal_not_emitted(encounter, "activated")
	encounter._records.append({"alive": true})
	encounter._finish_if_cleared()
	assert_signal_not_emitted(encounter, "activated")
	encounter._records[1].alive = false
	encounter._finish_if_cleared()
	encounter._finish_if_cleared()
	encounter.trigger()
	assert_signal_emit_count(encounter, "activated", 1)
	assert_eq(encounter.activation_count, 1)


func test_encounter_rejects_malformed_records_before_mutating_state() -> void:
	var encounter := EnemySpawnerScript.new()
	encounter.auto_spawn = false
	add_child_autofree(encounter)
	var original := encounter.capture_runtime_state()
	var invalid := original.duplicate(true)
	invalid.encounter_started = true
	invalid.enemies = [
		{
			"index": 0,
			"enemy_id": "grunt_basic",
			"tier": 1,
			"alive": true,
			"transform": [1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, NAN],
			"velocity": [0, 0, 0],
			"health": 50,
			"max_health": 100,
			"armor": 0
		}
	]
	assert_false(encounter.restore_runtime_state(invalid))
	assert_eq(encounter.capture_runtime_state(), original)
	invalid.enemies[0].transform[11] = 0
	invalid.enemies[0].index = 0.5
	assert_false(
		encounter.restore_runtime_state(invalid), "JSON fractional spawn indices are invalid"
	)
	assert_eq(encounter.capture_runtime_state(), original)


func test_collected_supply_json_restore_never_grants_or_respawns_reward() -> void:
	var supplies := PickupSpawnerScript.new()
	supplies.auto_spawn = false
	supplies.respawn_time = 0.0
	add_child_autofree(supplies)
	watch_signals(supplies)
	var collected := supplies.capture_runtime_state()
	collected.pickup_phase = "collected"
	collected.activation_count = 1
	collected.is_active = true
	var json_state: Dictionary = JSON.parse_string(JSON.stringify(collected))
	assert_true(supplies.restore_runtime_state(json_state))
	assert_true(supplies.restore_runtime_state(json_state))
	supplies.start_runtime()
	supplies.trigger()
	supplies._process(100.0)
	assert_eq(supplies.capture_runtime_state().pickup_phase, "collected")
	assert_signal_not_emitted(supplies, "activated", "Restoration cannot re-grant a reward")
	assert_null(supplies._current_pickup)


func test_supply_rejects_impossible_respawn_without_losing_existing_state() -> void:
	var supplies := PickupSpawnerScript.new()
	supplies.auto_spawn = false
	supplies.respawn_time = 0.0
	add_child_autofree(supplies)
	var original := supplies.capture_runtime_state()
	var invalid := original.duplicate(true)
	invalid.pickup_phase = "waiting"
	invalid.activation_count = 1
	invalid.respawn_timer = 2.0
	assert_false(supplies.restore_runtime_state(invalid))
	assert_eq(supplies.capture_runtime_state(), original)


func test_actual_medkit_collection_checkpoints_synchronously_and_cannot_duplicate() -> void:
	var collector := Collector.new()
	add_child_autofree(collector)
	var supplies := PickupSpawnerScript.new()
	supplies.auto_spawn = false
	supplies.respawn_time = 0.0
	add_child_autofree(supplies)
	supplies.start_runtime()
	supplies.trigger()
	var pickup: PickupBase = supplies._current_pickup
	assert_not_null(pickup)
	if not pickup:
		return
	assert_true(pickup.collect_for_player(collector, collector.get_multiplayer_authority()))
	assert_eq(collector.health, 45, "The real medkit applies its health reward")
	var saved := supplies.capture_runtime_state()
	assert_eq(saved.pickup_phase, "collected", "Checkpoint is consumed before queue_free runs")
	assert_false(pickup.collect_for_player(collector, collector.get_multiplayer_authority()))
	assert_true(supplies.restore_runtime_state(JSON.parse_string(JSON.stringify(saved))))
	supplies.trigger()
	assert_eq(collector.health, 45, "Restoring consumed rewards is silent")
	assert_null(supplies._current_pickup)
