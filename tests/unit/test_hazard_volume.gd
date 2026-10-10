extends GutTest

const HAZARD_SCENE: PackedScene = preload(
	"res://game/scenes/environment/hazards/hazard_volume.tscn"
)


func test_hazard_entry_audio_is_optional_and_spawned_when_configured() -> void:
	var hazard: Area3D = HAZARD_SCENE.instantiate()
	add_child_autofree(hazard)
	await get_tree().process_frame

	var body := CharacterBody3D.new()
	add_child_autofree(body)

	hazard.call("_on_body_entered", body)
	assert_null(_find_audio_player(hazard), "Unconfigured hazards should not spawn an audio player")

	hazard.set("enter_sound", AudioStreamGenerator.new())
	hazard.call("_on_body_entered", body)

	var audio_player: AudioStreamPlayer3D = _find_audio_player(hazard)
	assert_not_null(audio_player, "Configured hazards should spawn an audio player")
	assert_eq(audio_player.stream, hazard.get("enter_sound"))


func _find_audio_player(hazard: Area3D) -> AudioStreamPlayer3D:
	for child: Node in hazard.get_children():
		if child is AudioStreamPlayer3D:
			return child
	return null
