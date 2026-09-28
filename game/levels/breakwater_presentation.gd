extends Node3D
## Document-local presentation: no gameplay triggers, global weather mutation or save state.

const POWER_STAGES := ["aux", "coolant", "relay"]
const POWER_ACTORS := {
	"aux": "pump/aux_lights", "coolant": "turbine/cooling_lights", "relay": "hub/station_power"
}
const POWER_TARGET_GROUPS := {
	"aux": "breakwater_aux_lights",
	"coolant": "breakwater_coolant_lights",
	"relay": "breakwater_relay_lights"
}
const MACHINERY_GROUPS := {
	"aux": "breakwater_aux_machinery", "coolant": "breakwater_coolant_machinery", "relay": ""
}
const FIXTURE_GROUPS := {
	"aux": "breakwater_aux_emissive",
	"coolant": "breakwater_coolant_emissive",
	"relay": "breakwater_relay_fixtures"
}
const CONTRACT_VERSION := 1

@export var emergency_lens: Material
@export var powered_lens: Material

var _document: Node3D
var _power: Dictionary = {"aux": false, "coolant": false, "relay": false}
var _sources: Array[AudioStreamPlayer3D] = []
var _gains: Array[float] = []
var _rotors: Dictionary = {}
var _fixtures: Dictionary = {}
var _labels: Array[Label3D] = []
var _rain: Array[CPUParticles3D] = []
var _reduced_motion := false
var _weather_enabled := true
var _settings_timer := 0.0
var _bound := false


func _ready() -> void:
	_document = get_parent() as Node3D
	if Engine.is_editor_hint() or not _document or _document.get("authoring_mode") == true:
		set_process(false)
		return
	for child: Node in get_children():
		if child is AudioStreamPlayer3D:
			if child.stream is AudioStreamWAV:
				var wav_stream := child.stream as AudioStreamWAV
				wav_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			_sources.append(child)
			_gains.append(0.0)
			child.bus = &"SFX"
		elif child is CPUParticles3D:
			_rain.append(child)
	call_deferred("_bind_power")


func _bind_power() -> void:
	for stage: String in POWER_STAGES:
		var identity: String = str(POWER_ACTORS[stage])
		var actor := _document.call("find_actor", identity) as StationPowerActor
		if actor:
			actor.power_applied.connect(_on_power_applied.bind(stage))
			_power[stage] = actor.is_active
		var machinery_group: String = str(MACHINERY_GROUPS[stage])
		_rotors[stage] = _document_group(machinery_group) if not machinery_group.is_empty() else []
		var fixture_group: String = str(FIXTURE_GROUPS[stage])
		_fixtures[stage] = []
		for node: Node in _document_group(fixture_group):
			if node is MeshInstance3D:
				_fixtures[stage].append(node)
	for node: Node in _document_group("breakwater_relay_status"):
		if node is Label3D:
			node.set_meta("unpowered_text", node.text)
			_labels.append(node)
	_bound = true
	var contract := get_presentation_contract()
	if not bool(contract.get("valid", false)):
		push_error(
			(
				"[BreakwaterPresentation] Invalid presentation contract: %s"
				% contract.get("errors", [])
			)
		)
	_update_settings()
	for stage: String in _power:
		_apply_power_presentation(stage)


func get_presentation_contract() -> Dictionary:
	var errors: Array[String] = []
	var document := _document if is_instance_valid(_document) else get_parent() as Node3D
	var stages: Dictionary = {}
	if not document:
		errors.append("Presentation node must be parented to a LevelRoot document.")
	else:
		for stage: String in POWER_STAGES:
			var identity: String = str(POWER_ACTORS[stage])
			var actor: Node = null
			if document.has_method("find_actor"):
				actor = document.call("find_actor", identity) as Node
			var target_group: String = str(POWER_TARGET_GROUPS[stage])
			var target_nodes := _nodes_in_document(target_group, document)
			var machinery_group: String = str(MACHINERY_GROUPS[stage])
			var machinery_nodes: Array[Node] = []
			if not machinery_group.is_empty():
				machinery_nodes = _nodes_in_document(machinery_group, document)
			var fixture_group: String = str(FIXTURE_GROUPS[stage])
			var fixture_nodes := _nodes_in_document(fixture_group, document)
			var stage_report := {
				"power_actor": identity,
				"actor_type": actor.get_class() if actor else "",
				"target_group": target_group,
				"target_count": target_nodes.size(),
				"machinery_group": machinery_group,
				"machinery_count": machinery_nodes.size(),
				"fixture_group": fixture_group,
				"fixture_count": fixture_nodes.size()
			}
			stages[stage] = stage_report
			if actor == null:
				errors.append("Missing power actor: " + identity)
			elif not actor is StationPowerActor:
				errors.append("Power actor is not a StationPowerActor: " + identity)
			else:
				if str(actor.get("target_group")) != target_group:
					errors.append(identity + " targets the wrong group.")
				var input_channels: Array = actor.get("input_channels")
				var expected_channel: String = str(
					{"aux": "aux_power", "coolant": "coolant", "relay": "relay_power"}[stage]
				)
				if not input_channels.has(expected_channel):
					errors.append(identity + " is missing input channel " + expected_channel + ".")
			if target_nodes.is_empty():
				errors.append("Power stage has no target nodes: " + target_group)

	var audio_sources: Array[Dictionary] = []
	for child: Node in get_children():
		if not child is AudioStreamPlayer3D:
			continue
		var source := child as AudioStreamPlayer3D
		var stage := str(source.get_meta("power_stage", ""))
		var zone: Variant = source.get_meta("zone_half_extents", null)
		var valid_zone: bool = zone is Vector3 and zone.x > 0.0 and zone.y > 0.0 and zone.z > 0.0
		audio_sources.append(
			{
				"name": source.name,
				"power_stage": stage,
				"has_stream": source.stream != null,
				"zone_half_extents": zone
			}
		)
		if source.stream == null:
			errors.append("Audio source has no stream: " + source.name)
		if not source.has_meta("zone_half_extents") or not valid_zone:
			errors.append("Audio source has an invalid listener zone: " + source.name)
		if not stage.is_empty() and not POWER_STAGES.has(stage):
			errors.append("Audio source references an unknown power stage: " + source.name)

	var rain_count := 0
	for child: Node in get_children():
		if child is CPUParticles3D:
			rain_count += 1
	var status_label_count := _nodes_in_document("breakwater_relay_status", document).size()
	if emergency_lens == null or powered_lens == null:
		errors.append("Power presentation requires emergency and powered materials.")
	if audio_sources.is_empty():
		errors.append("Breakwater presentation requires at least one audio source.")
	if rain_count == 0:
		errors.append("Breakwater presentation requires at least one rain emitter.")
	if status_label_count == 0:
		errors.append("Breakwater presentation requires at least one relay status label.")
	return {
		"version": CONTRACT_VERSION,
		"valid": errors.is_empty(),
		"errors": errors,
		"power_stages": stages,
		"audio_sources": audio_sources,
		"rain_emitters": rain_count,
		"status_labels": status_label_count
	}


func _document_group(group: String) -> Array[Node]:
	return _nodes_in_document(group, _document)


func _nodes_in_document(group: String, document: Node3D) -> Array[Node]:
	var result: Array[Node] = []
	if not document:
		return result
	for node: Node in get_tree().get_nodes_in_group(group):
		if document.is_ancestor_of(node):
			result.append(node)
	return result


func _on_power_applied(powered: bool, restored: bool, stage: String) -> void:
	_power[stage] = powered
	_apply_power_presentation(stage)
	# A restored state is authoritative, not an interaction: no startup sound or ramp replay.
	if restored:
		for index: int in range(_sources.size()):
			if _sources[index].get_meta("power_stage", "") == stage:
				_gains[index] = -1.0


func _apply_power_presentation(stage: String) -> void:
	var powered: bool = _power[stage]
	for fixture: MeshInstance3D in _fixtures.get(stage, []):
		fixture.material_override = powered_lens if powered else emergency_lens
	if stage == "relay":
		for label: Label3D in _labels:
			label.text = (
				str(label.get_meta("powered_text", label.text))
				if powered
				else str(label.get_meta("unpowered_text", label.text))
			)


func _process(delta: float) -> void:
	if not _bound:
		return
	_settings_timer -= delta
	if _settings_timer <= 0.0:
		_update_settings()
		_settings_timer = 0.5
	var camera := get_viewport().get_camera_3d()
	# Session staging has no listener yet; never play an entire level during load/export.
	var audible := camera != null and is_instance_valid(_document.get("runtime_player"))
	var listener := camera.global_position if audible else Vector3.ZERO
	for index: int in range(_sources.size()):
		var source := _sources[index]
		var stage: String = source.get_meta("power_stage", "")
		var enabled: bool = stage.is_empty() or bool(_power.get(stage, false))
		var target := 0.0
		if audible and enabled:
			var half: Vector3 = source.get_meta("zone_half_extents", Vector3.ONE * 8.0)
			var offset := source.to_local(listener).abs() - half
			var edge := maxf(maxf(offset.x, offset.y), offset.z)
			target = 1.0 - smoothstep(0.0, 4.0, edge)
		var gain := (
			target if _gains[index] < 0.0 else move_toward(_gains[index], target, delta * 0.7)
		)
		_gains[index] = gain
		if gain <= 0.001:
			if source.playing:
				source.stop()
			continue
		source.volume_db = float(source.get_meta("mix_db", -16.0)) + linear_to_db(gain)
		if not source.playing and source.stream:
			# Distinct offsets avoid comb filtering where reused loops meet at a doorway.
			source.play(
				fmod(Time.get_ticks_msec() * 0.001 + index * 1.73, source.stream.get_length())
			)
	if not _reduced_motion:
		for stage: String in _rotors:
			if not _power[stage]:
				continue
			for rotor: Node in _rotors[stage]:
				if rotor is Node3D:
					rotor.rotate_object_local(
						Vector3.BACK, delta * (0.55 if stage == "aux" else 0.8)
					)
	for rain: CPUParticles3D in _rain:
		rain.visible = audible and _weather_enabled and not _reduced_motion
		rain.emitting = rain.visible and listener.distance_squared_to(rain.global_position) < 1444.0


func _update_settings() -> void:
	var ui := UISystem.get_service()
	_reduced_motion = (
		ui != null and ui.theme_manager != null and ui.theme_manager.is_reduced_motion()
	)
	var config: Node = GameManager.get_core_system("config")
	if config:
		_reduced_motion = (
			_reduced_motion or bool(config.get_value("ui.accessibility.reduced_motion", false))
		)
		_weather_enabled = (
			str(config.get_value("graphics.effect_quality", "MEDIUM")).to_upper() != "LOW"
		)
		_weather_enabled = (
			_weather_enabled
			and int(config.get_value("graphics.particles.max_particles", 10000)) > 0
		)
	# All light changes are steady, with no lightning, flashing, pulsing, bloom or camera motion.


func _exit_tree() -> void:
	for source: AudioStreamPlayer3D in _sources:
		source.stop()
	for rain: CPUParticles3D in _rain:
		rain.emitting = false
