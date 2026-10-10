extends GutTest

var boot_sequence: BootSequence
var completion_emitted: bool
var failure_reason: String


func _on_boot_complete() -> void:
	completion_emitted = true


func _on_boot_failed(reason: String) -> void:
	failure_reason = reason


func before_each() -> void:
	completion_emitted = false
	failure_reason = ""
	boot_sequence = BootSequence.new()
	add_child_autofree(boot_sequence)


func test_core_resource_check_loads_player_scene() -> void:
	var result: bool = await boot_sequence._check_resources()

	assert_true(result, "Boot resource check must load the maintained player scene")


func test_network_check_requires_enet_transport() -> void:
	var result: bool = await boot_sequence._check_network()

	assert_true(result, "Boot network check must instantiate ENet transport")


func test_start_sequence_emits_completion_after_checks() -> void:
	boot_sequence.boot_complete.connect(_on_boot_complete)
	boot_sequence.boot_failed.connect(_on_boot_failed)

	boot_sequence.start_sequence()
	await get_tree().create_timer(5.0).timeout

	assert_true(failure_reason.is_empty(), "Boot sequence should not fail: %s" % failure_reason)
	assert_true(completion_emitted, "Boot sequence must emit boot_complete after all checks")
