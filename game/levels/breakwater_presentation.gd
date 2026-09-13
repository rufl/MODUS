extends Node3D
## Document-local presentation: no gameplay triggers, global weather mutation or save state.

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
			_sources.append(child)
			_gains.append(0.0)
			child.bus = &"SFX"
		elif child is CPUParticles3D:
			_rain.append(child)
	call_deferred("_bind_power")


func _bind_power() -> void:
	for stage: String in ["aux", "coolant", "relay"]:
		var identity: String = {
			"aux": "pump/aux_lights",
			"coolant": "turbine/cooling_lights",
			"relay": "hub/station_power"
		}[stage]
		var actor := _document.call("find_actor", identity) as StationPowerActor
		if actor:
			actor.power_applied.connect(_on_power_applied.bind(stage))
			_power[stage] = actor.is_active
		var group := "breakwater_%s_machinery" % stage
		_rotors[stage] = _document_group(group)
		var fixture_group := (
			"breakwater_relay_fixtures" if stage == "relay" else "breakwater_%s_emissive" % stage
		)
		_fixtures[stage] = []
		for node: Node in _document_group(fixture_group):
			if node is MeshInstance3D:
				_fixtures[stage].append(node)
	for node: Node in _document_group("breakwater_relay_status"):
		if node is Label3D:
			node.set_meta("unpowered_text", node.text)
			_labels.append(node)
	_bound = true
	_update_settings()
	for stage: String in _power:
		_apply_power_presentation(stage)


func _document_group(group: String) -> Array[Node]:
	var result: Array[Node] = []
	for node: Node in get_tree().get_nodes_in_group(group):
		if _document.is_ancestor_of(node):
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
