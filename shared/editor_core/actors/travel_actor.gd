@tool
class_name TravelActor
extends "res://shared/editor_core/actors/switch_actor.gd"

@export var destination_id: String = ""
@export var destination_spawn_id: String = ""


func _init() -> void:
	actor_name = "Travel"
	actor_description = "Travel with the current party; preserve this destination for a revisit"


func _on_actor_ready() -> void:
	super._on_actor_ready()
	var label := Label3D.new()
	label.name = "TravelLabel"
	label.set_meta("editor_runtime_only", true)
	label.text = actor_name
	label.position.y = 0.65
	label.font_size = 32
	label.pixel_size = 0.008
	add_child(label)


func interact(participant: Node = null) -> bool:
	if not is_enabled or is_authoring() or not _can_mutate_runtime():
		return false
	var level := get_level_document()
	var session: Node = null
	if level and level.has_meta("travel_session"):
		session = level.get_meta("travel_session")
	if not session or session.is_travel_pending() or not participant is Player:
		return false
	if (
		participant.get_parent() != session
		or participant.global_position.distance_to(global_position) > 4.0
	):
		return false
	if not session.destinations.has(destination_id):
		return false
	# The actor is discarded by the commit; the persistent session owns the coroutine.
	session.call_deferred("travel_to", destination_id, destination_spawn_id)
	return true
