extends GutTest


func test_wait_with_invalid_tree_completes_deferred() -> void:
	assert_true(
		Engine.get_main_loop() is SceneTree, "The test should run with a SceneTree main loop"
	)
	var state: Dictionary = {"completed": false}

	var completion: Signal = TimerUtils.wait(null, 0.0)
	assert_false(completion.is_null(), "Invalid-tree fallback should return a live timer signal")
	completion.connect(func() -> void: state["completed"] = true)

	await completion
	assert_true(state["completed"], "Invalid-tree waits should complete using the active SceneTree")
