extends ModusGutTestBase

const InteractionPromptScript := preload("res://game/ui/hud/interaction_prompt.gd")


func test_prompt_renders_action_and_key_hint() -> void:
	var prompt: InteractionPrompt = InteractionPromptScript.new()
	add_child_autofree(prompt)
	await get_tree().process_frame

	prompt.show_prompt("Open Secret Wall", "E")
	assert_true(prompt.visible, "Prompt should become visible for an actionable target")
	assert_eq(prompt.get_prompt_text(), "Open Secret Wall")
	assert_eq(prompt.get_key_text(), "E")
	assert_gt(prompt.custom_minimum_size.x, 300.0)
	assert_gt(prompt.custom_minimum_size.y, 48.0)


func test_prompt_hides_when_target_is_lost() -> void:
	var prompt: InteractionPrompt = InteractionPromptScript.new()
	add_child_autofree(prompt)
	await get_tree().process_frame

	prompt.show_prompt("Travel to mission_hub")
	prompt.hide_prompt()
	assert_false(prompt.visible, "Prompt should disappear when no target is reachable")
	assert_eq(prompt.get_prompt_text(), "")


func test_prompt_ignores_mouse_input_and_uses_high_contrast_panel() -> void:
	var prompt: InteractionPrompt = InteractionPromptScript.new()
	add_child_autofree(prompt)
	await get_tree().process_frame

	assert_eq(prompt.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	var panel := prompt.get_theme_stylebox("panel") as StyleBoxFlat
	assert_not_null(panel)
	assert_gt(panel.border_width_left, 0)
	assert_gt(panel.bg_color.get_luminance(), 0.0)
