class_name LevelRuntimeState
extends RefCounted

const ModuleAssemblyScript := preload("res://shared/editor_core/core/module_assembly.gd")


static func signature(document: Node3D) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	var files: Dictionary = {}
	var resources: Dictionary = {}
	_hash_file(document.scene_file_path, context, files)
	var modules: Array = []
	for module: Node3D in ModuleAssemblyScript.get_instances(document):
		var definition: Resource = module.definition
		modules.append({"instance": module.instance_id, "module": definition.module_id,
			"revision": definition.content_revision, "transform": var_to_str(module.transform)})
	_hash_value([modules, document.module_connections, document.channel_data], context, files, resources)
	_hash_node(document, document, context, files, resources)
	return context.finish().hex_encode()


static func _hash_file(path: String, context: HashingContext, files: Dictionary) -> void:
	if path.is_empty() or path.contains("::") or files.has(path):
		return
	files[path] = true
	context.update(var_to_bytes(path))
	var physical_path := path
	if not FileAccess.file_exists(physical_path):
		# Exported text resources may exist only through their binary remap.
		var remap := ConfigFile.new()
		if remap.load(path + ".remap") != OK:
			remap.load(path + ".import")
		physical_path = str(remap.get_value("remap", "path", path))
	if FileAccess.file_exists(physical_path):
		context.update(FileAccess.get_sha256(physical_path).to_utf8_buffer())
	if not ResourceLoader.exists(path):
		return
	var dependencies := ResourceLoader.get_dependencies(path)
	dependencies.sort()
	for dependency: String in dependencies:
		var parts := dependency.split("::")
		var dependency_path: String = parts[parts.size() - 1]
		if dependency_path.begins_with("uid://"):
			var uid := ResourceUID.text_to_id(dependency_path)
			if ResourceUID.has_id(uid):
				dependency_path = ResourceUID.get_id_path(uid)
		_hash_file(dependency_path, context, files)


static func _hash_node(document: Node3D, node: Node, context: HashingContext,
	files: Dictionary, resources: Dictionary) -> void:
	if node.get_meta("editor_runtime_only", false):
		return
	context.update(var_to_bytes([str(document.get_path_to(node)), node.get_class(),
		node.transform if node is Node3D else Transform3D.IDENTITY]))
	for property: Dictionary in node.get_property_list():
		var usage: int = property.get("usage", 0)
		if not (usage & PROPERTY_USAGE_STORAGE):
			continue
		var value: Variant = node.get(property.name)
		if value is Resource or usage & PROPERTY_USAGE_SCRIPT_VARIABLE or str(property.name).begins_with("metadata/"):
			context.update(var_to_bytes(property.name))
			_hash_value(value, context, files, resources)
	for child: Node in node.get_children():
		_hash_node(document, child, context, files, resources)


static func _hash_value(value: Variant, context: HashingContext,
	files: Dictionary, resources: Dictionary) -> void:
	if value is Resource:
		context.update(var_to_bytes([value.get_class(), value.resource_path]))
		_hash_file(value.resource_path, context, files)
		if resources.has(value.get_instance_id()):
			return
		resources[value.get_instance_id()] = true
		if value is Script:
			context.update(value.source_code.to_utf8_buffer())
		for property: Dictionary in value.get_property_list():
			if not (int(property.get("usage", 0)) & PROPERTY_USAGE_STORAGE):
				continue
			context.update(var_to_bytes(property.name))
			_hash_value(value.get(property.name), context, files, resources)
	elif value is Dictionary:
		context.update(var_to_bytes(["dictionary", value.size()]))
		for key: Variant in value:
			_hash_value(key, context, files, resources)
			_hash_value(value[key], context, files, resources)
	elif value is Array:
		context.update(var_to_bytes(["array", value.size()]))
		for entry: Variant in value:
			_hash_value(entry, context, files, resources)
	elif not value is Object:
		context.update(var_to_bytes(value))


static func capture(document: Node3D, document_signature: String, mission_state: Dictionary) -> Dictionary:
	var actors: Dictionary = {}
	for actor: Node in document.find_children("*", "", true, false):
		if actor is ActorBase:
			actors[document.get_actor_identity(actor)] = actor.capture_runtime_state()
	return {"version": 1, "document": document_signature, "actors": actors,
		"mission": mission_state.duplicate(true)}


static func validate(document: Node3D, document_signature: String,
	baseline_mission: Dictionary, state: Variant) -> bool:
	if not state is Dictionary or state.get("version") != 1 or state.get("document") != document_signature:
		return false
	if not _validate_actors(document, state.get("actors")):
		return false
	var mission: Variant = state.get("mission")
	if not mission is Dictionary or not _same_json_value(mission.get("definition"), baseline_mission.get("definition")):
		return false
	if not mission.get("active_id") is String or not mission.get("completed_id") is String:
		return false
	var mission_id: String = str(document.get_meta("mission_id", "document_mission"))
	if not ((mission.active_id == mission_id and mission.completed_id == "")
		or (mission.active_id == "" and mission.completed_id == mission_id)):
		return false
	if not _same_json_value(mission.get("totals"), baseline_mission.get("totals")) or not mission.get("state") is Dictionary:
		return false
	if mission.state.size() != baseline_mission.state.size():
		return false
	for identity: String in baseline_mission.state:
		var count: Variant = mission.state.get(identity)
		if not _is_integer(count) or count < 0 or count > int(mission.totals[identity]):
			return false
	return true


static func _validate_actors(document: Node3D, actors: Variant) -> bool:
	if not actors is Dictionary:
		return false
	var identities: Dictionary = {}
	for actor: Node in document.find_children("*", "", true, false):
		if not actor is ActorBase:
			continue
		var identity: String = document.get_actor_identity(actor)
		if identity.is_empty() or identities.has(identity):
			return false
		identities[identity] = true
		var saved: Variant = actors.get(identity)
		if not saved is Dictionary or not actor.validate_runtime_state(saved):
			return false
		var expected: Dictionary = actor.capture_runtime_state()
		if expected.size() != saved.size():
			return false
		for field: String in expected:
			if expected[field] is int:
				if not _is_integer(saved.get(field)):
					return false
			elif expected[field] is float:
				var value: Variant = saved.get(field)
				if not (value is int or value is float) or not is_finite(value):
					return false
			elif typeof(saved.get(field)) != typeof(expected[field]):
				return false
		if saved.activation_count < 0:
			return false
	return actors.size() == identities.size()


static func restore_actors(document: Node3D, state: Dictionary) -> bool:
	# Check every record before the first actor can change.
	if not _validate_actors(document, state.get("actors")):
		return false
	for identity: String in state.actors:
		var actor: Node = document.find_actor(identity)
		var actor_state: Dictionary = state.actors[identity].duplicate(true)
		actor_state.activation_count = int(actor_state.activation_count)
		if not actor.restore_runtime_state(actor_state):
			return false
	return true


static func _is_integer(value: Variant) -> bool:
	return value is int or (value is float and is_finite(value) and value == floor(value))


static func _same_json_value(saved: Variant, expected: Variant) -> bool:
	if expected is int or expected is float:
		return (saved is int or saved is float) and is_finite(saved) and saved == expected
	if typeof(saved) != typeof(expected):
		return false
	if expected is Dictionary:
		if saved.size() != expected.size():
			return false
		for key: Variant in expected:
			if not saved.has(key) or not _same_json_value(saved[key], expected[key]):
				return false
		return true
	if expected is Array:
		if saved.size() != expected.size():
			return false
		for index in expected.size():
			if not _same_json_value(saved[index], expected[index]):
				return false
		return true
	return saved == expected
