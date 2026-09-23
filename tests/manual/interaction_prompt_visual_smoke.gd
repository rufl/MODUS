extends SceneTree

const PromptScript := preload("res://game/ui/hud/interaction_prompt.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var root := Control.new()
	root.size = Vector2(1280, 720)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_root().add_child(root)
	var prompt = PromptScript.new()
	root.add_child(prompt)
	await process_frame
	prompt.show_prompt("Restore auxiliary power", "E")
	await process_frame
	await process_frame
	var texture := get_root().get_viewport().get_texture()
	if texture == null:
		quit(3)
		return
	var image := texture.get_image()
	var output := "/tmp/modus-interaction-prompt.png"
	var saved := image.save_png(output)
	if saved != OK or not prompt.visible or prompt.get_prompt_text() != "Restore auxiliary power":
		quit(2)
		return
	print("HUD render smoke saved: %s" % output)
	quit(0)
