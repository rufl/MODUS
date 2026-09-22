class_name LevelDestination
extends RefCounted

const Assembly := preload("res://shared/editor_core/core/module_assembly.gd")

var viewport: SubViewport
var document: Node3D
var navigation: NavigationRegion3D
var descriptor: Dictionary
var runtime: Dictionary
var baseline: Dictionary
var spawn_id: String
var spawn_transform: Transform3D
var error: String = ""


func prepare(
	session: Node, packed: PackedScene, identity: Dictionary, arrival: String, saved: Dictionary
) -> bool:
	descriptor = identity.duplicate(true)
	spawn_id = arrival
	document = packed.instantiate() as Node3D
	if not document or not document.has_method("prepare_for_save"):
		return _fail("Destination must contain a LevelRoot document.")
	document.scene_file_path = identity.path
	document.authoring_mode = false
	document.set_meta("document_runtime_session", true)
	document.process_mode = Node.PROCESS_MODE_DISABLED
	viewport = SubViewport.new()
	viewport.name = "StagedDestination"
	viewport.own_world_3d = true
	viewport.disable_3d = false
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	viewport.gui_disable_input = true
	viewport.process_mode = Node.PROCESS_MODE_DISABLED
	session.add_child(viewport)
	viewport.add_child(document)
	document.restore_runtime_bindings()
	var channels: Array[String] = document.get_channel_system().validate_data(document.channel_data)
	if not channels.is_empty():
		return _fail("\n".join(channels))
	var validation: Dictionary = Assembly.validate_level(document)
	if not validation.valid:
		return _fail("\n".join(PackedStringArray(validation.errors)))
	var points: Array[Node3D] = document.get_spawn_points("player")
	var spawn: Node3D
	for point: Node3D in points:
		var identity_id: String = str(point.get_meta("spawn_id", document.get_path_to(point)))
		if arrival.is_empty() or identity_id == arrival:
			spawn = point
			spawn_id = identity_id
			break
	if not spawn:
		return _fail("Destination player spawn is unavailable: " + arrival)
	spawn_transform = spawn.global_transform
	var preview: Dictionary = MissionMgr.get_instance().build_document_state(document)
	if not preview.success:
		return _fail(preview.error)
	baseline = preview.state
	var signature := LevelRuntimeState.signature(document)
	if not str(identity.get("signature", "")).is_empty() and identity.signature != signature:
		return _fail("Destination content differs from the authoritative manifest.")
	descriptor.signature = signature
	var required: Array[String] = []
	for module: Node3D in Assembly.get_instances(document):
		for capability: String in module.definition.required_capabilities:
			if capability not in required:
				required.append(capability)
	required.sort()
	if identity.has("required_capabilities") and identity.required_capabilities != required:
		return _fail("Destination capability manifest differs from local content.")
	descriptor.required_capabilities = required
	runtime = saved.duplicate(true) if not saved.is_empty() else LevelRuntimeState.capture(document, signature, baseline)
	if not LevelRuntimeState.validate(document, signature, baseline, runtime):
		return _fail("Destination runtime checkpoint is incompatible with its content.")
	var context := GenerationContext.new()
	var baker := NavigationMeshBaker.new()
	baker.initialize(context)
	if not baker.bake_navigation_mesh(document):
		baker.initialize(null)
		return _fail("Destination collision produced no walkable navigation mesh.")
	navigation = baker.get_navigation_region()
	viewport.add_child(navigation)
	navigation.enabled = false
	# Restore while isolated: failure cannot destroy the committed world.
	if not saved.is_empty():
		document.set_meta("applying_authoritative_state", true)
		var restored := LevelRuntimeState.restore_actors(document, runtime)
		document.remove_meta("applying_authoritative_state")
		if not restored:
			return _fail("Destination actor restoration failed.")
	return true


func _fail(message: String) -> bool:
	error = message
	discard()
	return false


func discard() -> void:
	if is_instance_valid(viewport):
		viewport.free()
	elif is_instance_valid(document) and not document.is_inside_tree():
		document.free()
	viewport = null
	document = null
	navigation = null
