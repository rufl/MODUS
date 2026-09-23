@tool
class_name ModuleAssembly
extends RefCounted

const CATALOG := [
	"res://game/levels/modules/breakwater/airlock.tres",
	"res://game/levels/modules/breakwater/pump_hall.tres",
	"res://game/levels/modules/breakwater/control_room.tres",
	"res://game/levels/modules/breakwater/mission/dock.tres",
	"res://game/levels/modules/breakwater/mission/hub.tres",
	"res://game/levels/modules/breakwater/mission/pump.tres",
	"res://game/levels/modules/breakwater/mission/intake.tres",
	"res://game/levels/modules/breakwater/mission/cavern.tres",
	"res://game/levels/modules/breakwater/mission/turbine.tres",
	"res://game/levels/modules/breakwater/mission/relay.tres",
	"res://game/levels/modules/breakwater/mission/return_landing.tres",
	"res://game/levels/modules/breakwater/mission/return.tres",
	"res://game/levels/modules/breakwater/mission/return_gallery.tres",
	"res://game/levels/modules/breakwater/mission/return_elbow.tres",
]
const EPSILON := 0.01
const LevelRootScript := preload("res://shared/editor_core/nodes/level_root.gd")
const SUPPORTED_CAPABILITIES: Array[String] = ["walk"]


static func _unsupported_capabilities(
	definition: PrefabMetadata, supported_capabilities: Array[String] = SUPPORTED_CAPABILITIES
) -> Array[String]:
	var unsupported: Array[String] = []
	for capability: String in definition.required_capabilities:
		if not supported_capabilities.has(capability):
			unsupported.append(capability)
	return unsupported


static func get_catalog() -> Array[PrefabMetadata]:
	var result: Array[PrefabMetadata] = []
	for path: String in CATALOG:
		var definition := load(path) as PrefabMetadata
		if definition and definition.is_valid():
			result.append(definition)
	return result


static func catalog_from_prefab_entries(entries: Array) -> Array[PrefabMetadata]:
	var catalog: Array[PrefabMetadata] = []
	for entry in entries:
		if entry == null or not "metadata" in entry:
			continue
		var definition := entry.metadata as PrefabMetadata
		if definition and definition.is_valid():
			catalog.append(definition)
	return catalog


static func get_replacement_diagnostics_from_entries(root: Node3D, entries: Array) -> Dictionary:
	return get_replacement_diagnostics(root, catalog_from_prefab_entries(entries))


static func catalog_from_metadata_dicts(entries: Array) -> Array[PrefabMetadata]:
	var catalog: Array[PrefabMetadata] = []
	for entry: Variant in entries:
		if not entry is Dictionary:
			continue
		var definition := PrefabMetadata.from_dict(entry)
		if definition and definition.is_valid():
			catalog.append(definition)
	return catalog


static func get_replacement_diagnostics_from_metadata(root: Node3D, entries: Array) -> Dictionary:
	return get_replacement_diagnostics(root, catalog_from_metadata_dicts(entries))


static func get_compatible_replacement_catalog(
	root: Node3D, catalog: Array[PrefabMetadata] = []
) -> Array[PrefabMetadata]:
	return get_replacement_diagnostics(root, catalog).compatible


static func get_replacement_diagnostics(
	root: Node3D,
	catalog: Array[PrefabMetadata] = [],
	supported_capabilities: Array[String] = SUPPORTED_CAPABILITIES
) -> Dictionary:
	var candidates := catalog if not catalog.is_empty() else get_catalog()
	var compatible: Array[PrefabMetadata] = []
	var rejected: Array[Dictionary] = []
	var target_instance_ids: Array[String] = []
	for instance: ModuleInstance in get_instances(root):
		if not instance.pinned:
			target_instance_ids.append(instance.instance_id)
	for definition in candidates:
		var result := build_regeneration_plans(root, [definition], supported_capabilities)
		if result.success:
			compatible.append(definition)
		else:
			rejected.append(
				{
					"module_id": definition.module_id,
					"error": result.error,
					"required_capabilities": Array(definition.required_capabilities),
					"unsupported_capabilities":
					_unsupported_capabilities(definition, supported_capabilities),
					"target_instance_ids": target_instance_ids.duplicate()
				}
			)
	compatible.sort_custom(_definition_precedes)
	return {"compatible": compatible, "rejected": rejected}


static func _definition_precedes(left: PrefabMetadata, right: PrefabMetadata) -> bool:
	if left.module_id != right.module_id:
		return left.module_id < right.module_id
	if left.scene_path != right.scene_path:
		return left.scene_path < right.scene_path
	return JSON.stringify(left.to_dict()) < JSON.stringify(right.to_dict())


static func get_instances(root: Node) -> Array[ModuleInstance]:
	var result: Array[ModuleInstance] = []
	for child in root.get_children():
		if child is ModuleInstance:
			result.append(child)
	return result


static func place_module(
	root: Node3D,
	definition: PrefabMetadata,
	target_instance_id: String = "",
	target_socket_id: String = "",
	source_socket_id: String = "",
	quarter_turns: int = 0,
	record_history: bool = true,
	validate_existing: bool = true
) -> Dictionary:
	if root == null or not "module_connections" in root:
		return _failure("Open a LevelRoot document before placing modules.")
	if definition == null or definition.module_id.is_empty() or not definition.is_valid():
		return _failure("The module definition is invalid.")
	if validate_existing:
		var previous := validate_level(root)
		if not previous.valid:
			return _failure("Repair the existing layout first: " + "; ".join(previous.errors))
	var instances := get_instances(root)
	var candidate := ModuleInstance.new()
	candidate.definition = definition
	candidate.instance_id = _next_id(definition.module_id, instances)
	candidate.name = candidate.instance_id.to_pascal_case()
	candidate.transform = Transform3D(
		Basis(Vector3.UP, posmod(quarter_turns, 4) * PI / 2.0), Vector3.ZERO
	)
	var graph: Array[Dictionary] = root.module_connections.duplicate(true)
	if instances.is_empty():
		if not target_instance_id.is_empty() or not target_socket_id.is_empty():
			candidate.free()
			return _failure("The first module is placed at the origin without a target.")
	else:
		var target: ModuleInstance = null
		for instance in instances:
			if instance.instance_id == target_instance_id:
				target = instance
		if target == null:
			candidate.free()
			return _failure("Select an existing target module and free socket.")
		var target_socket := target.get_socket(target_socket_id)
		var source_socket := candidate.get_socket(source_socket_id)
		if target_socket.is_empty() or source_socket.is_empty():
			candidate.free()
			return _failure("Both selected sockets must exist.")
		var target_pose: Transform3D = target.transform * target_socket.local_transform
		var opposite := Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO)
		candidate.transform = (
			target_pose * opposite * source_socket.local_transform.affine_inverse()
		)
		# Connected orientation is solved from sockets. A requested extra turn must still match.
		candidate.basis = Basis(Vector3.UP, posmod(quarter_turns, 4) * PI / 2.0) * candidate.basis
		candidate.position = (
			target_pose.origin - candidate.basis * source_socket.local_transform.origin
		)
		graph.append(
			{
				"from_instance": target.instance_id,
				"from_socket": target_socket_id,
				"to_instance": candidate.instance_id,
				"to_socket": source_socket_id
			}
		)
	var scene := load(definition.scene_path) as PackedScene
	if scene == null:
		candidate.free()
		return _failure("The module scene could not be loaded.")
	var content_node := scene.instantiate()
	var content := content_node as Node3D
	if content == null:
		content_node.free()
		candidate.free()
		return _failure("Module scenes must have a Node3D root.")
	if not content.transform.is_equal_approx(Transform3D.IDENTITY):
		content.free()
		candidate.free()
		return _failure("Module scene roots must have an identity transform.")
	if content is ModuleInstance:
		var template_id: String = content.instance_id
		if not template_id.is_empty():
			candidate.instance_id = _next_id(template_id, instances)
			if not instances.is_empty():
				graph[-1].to_instance = candidate.instance_id
			_remap_local_objectives(content, template_id, candidate.instance_id)
		content.definition = definition
		content.instance_id = candidate.instance_id
		content.transform = candidate.transform
		candidate.free()
		candidate = content
	else:
		candidate.name = content.name
		candidate.add_child(content)
	instances.append(candidate)
	var errors := _validate(instances, graph)
	if not errors.is_empty():
		candidate.free()
		return _failure("; ".join(errors))
	if not record_history:
		_attach(root, candidate, graph)
		return {"success": true, "error": "", "instance": candidate}
	var undo := EditorGlobals.get_undo_redo()
	undo.create_action("Place module: " + definition.module_id)
	undo.add_do_method(_attach.bind(root, candidate, graph))
	undo.add_undo_method(_detach.bind(root, candidate, root.module_connections.duplicate(true)))
	undo.add_do_reference(candidate)
	undo.commit_action()
	return {"success": true, "error": "", "instance": candidate}


static func attach_spatial_plan(
	root: Node3D, spatial_plan: Dictionary, catalog: Array[PrefabMetadata] = []
) -> Dictionary:
	if root == null or not "module_connections" in root:
		return _failure("Open a LevelRoot document before attaching a spatial plan.")
	if not bool(spatial_plan.get("is_valid", false)):
		return _failure("Cannot attach an invalid spatial plan.")
	var definitions := {}
	var candidates := catalog if not catalog.is_empty() else get_catalog()
	for definition: PrefabMetadata in candidates:
		definitions[definition.module_id] = definition
		definitions[definition.scene_path] = definition
	var instances: Array[ModuleInstance] = []
	var room_instances := {}
	for placement: Variant in spatial_plan.get("placements", []):
		if not placement is Dictionary:
			_free_instances(instances)
			return _failure("Spatial plan contains an invalid placement record.")
		var definition: PrefabMetadata = definitions.get(
			str(placement.get("module_id", "")),
			definitions.get(str(placement.get("scene_path", "")))
		)
		if definition == null:
			_free_instances(instances)
			return _failure("Spatial plan references an unknown module definition.")
		var room_id := int(placement.get("room_id", -1))
		var instance_id := "generated_room_%d" % room_id
		var instance := _instantiate_spatial_instance(
			definition, placement.get("transform", Transform3D.IDENTITY), instance_id
		)
		if instance == null:
			_free_instances(instances)
			return _failure(
				"Spatial plan module could not be instantiated: " + definition.module_id
			)
		instances.append(instance)
		room_instances[room_id] = instance_id
	var graph: Array[Dictionary] = []
	for connection: Variant in spatial_plan.get("connections", []):
		if not connection is Dictionary:
			_free_instances(instances)
			return _failure("Spatial plan contains an invalid connection record.")
		var from_room_id := int(connection.get("from_room_id", -1))
		var to_room_id := int(connection.get("to_room_id", -1))
		if not room_instances.has(from_room_id) or not room_instances.has(to_room_id):
			_free_instances(instances)
			return _failure("Spatial plan connection references an unplaced room.")
		graph.append(
			{
				"from_instance": room_instances[from_room_id],
				"from_socket": str(connection.get("from_socket_id", "")),
				"to_instance": room_instances[to_room_id],
				"to_socket": str(connection.get("to_socket_id", ""))
			}
		)
	var errors := _validate(instances, graph)
	if not errors.is_empty():
		_free_instances(instances)
		return _failure("; ".join(errors))
	for instance: ModuleInstance in instances:
		root.add_child(instance)
		instance.owner = root
		LevelRootScript.prepare_ownership(instance, root)
	root.module_connections = graph
	if root.has_method("restore_runtime_bindings"):
		root.restore_runtime_bindings()
	return {"success": true, "error": "", "instances": instances}


static func _instantiate_spatial_instance(
	definition: PrefabMetadata, transform: Transform3D, instance_id: String
) -> ModuleInstance:
	var scene := load(definition.scene_path) as PackedScene
	if scene == null:
		return null
	var content_node := scene.instantiate()
	var content := content_node as Node3D
	if content == null or not content.transform.is_equal_approx(Transform3D.IDENTITY):
		content_node.free()
		return null
	var instance: ModuleInstance
	if content is ModuleInstance:
		instance = content
		var template_id := instance.instance_id
		if not template_id.is_empty() and template_id != instance_id:
			_remap_local_objectives(instance, template_id, instance_id)
	else:
		instance = ModuleInstance.new()
		instance.add_child(content)
	instance.name = instance_id.to_pascal_case()
	instance.instance_id = instance_id
	instance.definition = definition
	instance.transform = transform
	return instance


static func _free_instances(instances: Array[ModuleInstance]) -> void:
	for instance: ModuleInstance in instances:
		if is_instance_valid(instance):
			instance.free()


static func build_regeneration_plans(
	root: Node3D,
	replacement_catalog: Array[PrefabMetadata] = [],
	supported_capabilities: Array[String] = SUPPORTED_CAPABILITIES,
	max_attempts: int = 128
) -> Dictionary:
	if root == null or not "module_connections" in root:
		return _regeneration_failure(
			"Open a LevelRoot document before capturing regeneration plans."
		)
	if max_attempts <= 0:
		return _regeneration_failure("Regeneration attempt limit must be positive.")
	var previous := validate_level(root)
	if not previous.valid:
		return _regeneration_failure(
			"Repair the existing layout first: " + "; ".join(previous.errors)
		)
	var instances := get_instances(root)
	instances.sort_custom(
		func(left: ModuleInstance, right: ModuleInstance) -> bool:
			return left.instance_id < right.instance_id
	)
	var catalog: Array[PrefabMetadata] = replacement_catalog.duplicate()
	for definition in catalog:
		if definition == null or definition.module_id.is_empty() or not definition.is_valid():
			return _regeneration_failure("Replacement catalog contains an invalid definition.")
	catalog.sort_custom(_definition_precedes)
	var layout := _capture_layout(root)
	var plans: Array[Dictionary] = []
	var choices: Array = []
	for instance in instances:
		if instance.pinned:
			continue
		var plan := {
			"definition": instance.definition,
			"instance_id": instance.instance_id,
			"transform": instance.transform,
			"_layout": layout
		}
		for edge: Dictionary in root.module_connections:
			if edge.from_instance == instance.instance_id:
				plan.merge(
					{
						"target_instance_id": edge.to_instance,
						"target_socket_id": edge.to_socket,
						"source_socket_id": edge.from_socket
					}
				)
				break
			if edge.to_instance == instance.instance_id:
				plan.merge(
					{
						"target_instance_id": edge.from_instance,
						"target_socket_id": edge.from_socket,
						"source_socket_id": edge.to_socket
					}
				)
				break
		plans.append(plan)
		choices.append(catalog if not catalog.is_empty() else [instance.definition])
	var search := {"attempts": 0, "error": "", "exhausted": false}
	if _search_regeneration(root, plans, choices, 0, supported_capabilities, max_attempts, search):
		return {"success": true, "error": "", "plans": plans, "attempts": search.attempts}
	var reason := (
		"Regeneration attempt limit exhausted"
		if search.exhausted
		else "No compatible replacement layout"
	)
	return _regeneration_failure(reason + ": " + str(search.error), search.attempts)


static func _regeneration_failure(message: String, attempts: int = 0) -> Dictionary:
	return {"success": false, "error": message, "plans": [], "transforms": [], "attempts": attempts}


static func _capture_layout(root: Node3D) -> Dictionary:
	var modules: Dictionary = {}
	for instance in get_instances(root):
		modules[instance.instance_id] = {
			"object_id": instance.get_instance_id(),
			"transform": instance.transform,
			"pinned": instance.pinned,
			"definition": instance.definition.to_dict().duplicate(true)
		}
	return {"modules": modules, "graph": root.module_connections.duplicate(true)}


static func _retained_socket_error(
	instance: ModuleInstance, definition: PrefabMetadata, graph: Array[Dictionary]
) -> String:
	for edge in graph:
		var socket_id := ""
		if edge.from_instance == instance.instance_id:
			socket_id = edge.from_socket
		elif edge.to_instance == instance.instance_id:
			socket_id = edge.to_socket
		else:
			continue
		var retained := instance.get_socket(socket_id)
		var replacement: Dictionary = {}
		for socket in definition.sockets:
			if socket.id == socket_id:
				replacement = socket
				break
		if (
			replacement.is_empty()
			or replacement.get("kind", "walk") != retained.get("kind", "walk")
			or not replacement.opening.is_equal_approx(retained.opening)
			or not replacement.local_transform.is_equal_approx(retained.local_transform)
		):
			return (
				"%s: replacement %s violates retained socket %s."
				% [instance.instance_id, definition.module_id, socket_id]
			)
	return ""


static func _search_regeneration(
	root: Node3D,
	plans: Array[Dictionary],
	choices: Array,
	depth: int,
	supported_capabilities: Array[String],
	max_attempts: int,
	search: Dictionary
) -> bool:
	if depth == plans.size():
		var staged := _stage_regeneration(root, plans, supported_capabilities)
		if not staged.success:
			search.error = staged.error
			return false
		staged.document.free()
		return true
	var original: ModuleInstance
	for instance in get_instances(root):
		if instance.instance_id == plans[depth].instance_id:
			original = instance
			break
	for definition: PrefabMetadata in choices[depth]:
		if search.attempts >= max_attempts:
			search.exhausted = true
			return false
		search.attempts += 1
		var unsupported := _unsupported_capabilities(definition, supported_capabilities)
		if not unsupported.is_empty():
			search.error = (
				"%s: replacement %s requires unsupported capabilities: %s."
				% [original.instance_id, definition.module_id, ", ".join(unsupported)]
			)
			continue
		var socket_error := _retained_socket_error(original, definition, root.module_connections)
		if not socket_error.is_empty():
			search.error = socket_error
			continue
		plans[depth].definition = definition
		if _search_regeneration(
			root, plans, choices, depth + 1, supported_capabilities, max_attempts, search
		):
			return true
		if search.exhausted:
			return false
	return false


static func preview_regeneration(root: Node3D, plans: Array[Dictionary]) -> Dictionary:
	var staged := _stage_regeneration(root, plans)
	if not staged.success:
		return staged
	var transforms: Array[Transform3D] = []
	for instance: ModuleInstance in staged.instances:
		transforms.append(instance.transform)
	staged.document.free()
	return {"success": true, "error": "", "transforms": transforms}


static func _instantiate_replacement(
	original: ModuleInstance, definition: PrefabMetadata
) -> Dictionary:
	var scene := load(definition.scene_path) as PackedScene
	if scene == null:
		return _regeneration_failure("Module scene could not be loaded: " + definition.module_id)
	var content := scene.instantiate()
	if not content is Node3D or not content.transform.is_equal_approx(Transform3D.IDENTITY):
		content.free()
		return _regeneration_failure(
			"Module scene roots must be Node3D with an identity transform."
		)
	var candidate: ModuleInstance
	if content is ModuleInstance:
		candidate = content
		_remap_local_objectives(candidate, candidate.instance_id, original.instance_id)
	else:
		candidate = ModuleInstance.new()
		candidate.add_child(content)
	candidate.name = original.name
	candidate.instance_id = original.instance_id
	candidate.definition = definition
	candidate.transform = original.transform
	candidate.pinned = false
	return {"success": true, "instance": candidate}


static func _stage_regeneration(
	root: Node3D,
	plans: Array[Dictionary],
	supported_capabilities: Array[String] = SUPPORTED_CAPABILITIES
) -> Dictionary:
	if root == null or not "module_connections" in root:
		return _regeneration_failure("Open a LevelRoot document before regenerating modules.")
	var previous := validate_level(root)
	if not previous.valid:
		return _regeneration_failure(
			"Repair the existing layout first: " + "; ".join(previous.errors)
		)
	var layout := _capture_layout(root)
	var by_id: Dictionary = {}
	for plan in plans:
		var id := str(plan.get("instance_id", ""))
		var definition := plan.get("definition") as PrefabMetadata
		if not layout.modules.has(id) or by_id.has(id):
			return _regeneration_failure("Invalid or duplicate regeneration instance: " + id)
		if plan.get("_layout") != layout:
			return _regeneration_failure("Stale regeneration layout: " + id)
		if layout.modules[id].pinned:
			return _regeneration_failure("Cannot regenerate pinned module: " + id)
		if (
			not plan.get("transform") is Transform3D
			or plan.transform != layout.modules[id].transform
		):
			return _regeneration_failure("Regeneration must preserve the original pose: " + id)
		if definition == null or definition.module_id.is_empty() or not definition.is_valid():
			return _regeneration_failure("Invalid replacement definition: " + id)
		var unsupported := _unsupported_capabilities(definition, supported_capabilities)
		if not unsupported.is_empty():
			return _regeneration_failure(
				id + ": unsupported capabilities: " + ", ".join(unsupported)
			)
		var connected := false
		var matches_target := false
		for edge: Dictionary in root.module_connections:
			if edge.from_instance == id:
				connected = true
				matches_target = (
					matches_target
					or (
						plan.get("source_socket_id") == edge.from_socket
						and plan.get("target_instance_id") == edge.to_instance
						and plan.get("target_socket_id") == edge.to_socket
					)
				)
			elif edge.to_instance == id:
				connected = true
				matches_target = (
					matches_target
					or (
						plan.get("source_socket_id") == edge.to_socket
						and plan.get("target_instance_id") == edge.from_instance
						and plan.get("target_socket_id") == edge.from_socket
					)
				)
		if connected and not matches_target:
			return _regeneration_failure("Invalid retained connection in plan: " + id)
		by_id[id] = plan
	for instance in get_instances(root):
		if not instance.pinned and not by_id.has(instance.instance_id):
			return _regeneration_failure("Missing regeneration plan: " + instance.instance_id)
		if by_id.has(instance.instance_id):
			var error := _retained_socket_error(
				instance, by_id[instance.instance_id].definition, root.module_connections
			)
			if not error.is_empty():
				return _regeneration_failure(error)
	# All validation occurs in a detached document. Never remove, reparent or assign owners
	# on live nodes while planning, previewing, or rejecting a transaction.
	var document: Node3D = LevelRootScript.new()
	document.name = root.name
	document.module_connections = root.module_connections.duplicate(true)
	document.channel_data = root.channel_data.duplicate(true)
	for child in root.get_children():
		if not child.get_meta("editor_runtime_only", false):
			document.add_child(
				child.duplicate(
					(
						Node.DUPLICATE_GROUPS
						| Node.DUPLICATE_SCRIPTS
						| Node.DUPLICATE_USE_INSTANTIATION
					)
				)
			)
	# Include unsaved editor channel changes without assigning IDs on the live tree.
	if root.has_method("get_channel_system"):
		for channel_name: String in root.get_channel_system().channels:
			var channel: Dictionary = root.get_channel_system().channels[channel_name]
			var saved := {
				"color": channel.color.to_html(),
				"enabled": channel.enabled,
				"delay": channel.delay,
				"inverted": channel.inverted
			}
			for role: String in ["sources", "targets"]:
				var identities: Array[String] = []
				for node: Node in channel[role]:
					if is_instance_valid(node) and root.is_ancestor_of(node):
						var copy := document.get_node_or_null(root.get_path_to(node))
						if copy:
							identities.append(document.get_actor_identity(copy))
				saved[role] = identities
			document.channel_data[channel_name] = saved
	var old_channel_data: Dictionary = document.channel_data.duplicate(true)
	var replacements: Dictionary = {}
	for original in get_instances(root):
		if not by_id.has(original.instance_id):
			continue
		var result := _instantiate_replacement(original, by_id[original.instance_id].definition)
		if not result.success:
			document.free()
			return result
		var copy := document.get_node(NodePath(str(original.name)))
		var index := copy.get_index()
		document.remove_child(copy)
		copy.free()
		document.add_child(result.instance)
		document.move_child(result.instance, index)
		replacements[original.instance_id] = result.instance
	var errors := _validate(
		get_instances(document), document.module_connections, supported_capabilities
	)
	errors.append_array(document.get_channel_system().validate_data(document.channel_data))
	var mission := MissionMgr.new()
	var mission_state := mission.build_document_state(document)
	mission.free()
	if not mission_state.success:
		errors.append(mission_state.error)
	if not errors.is_empty():
		document.free()
		return _regeneration_failure("Regenerated layout is invalid: " + "; ".join(errors))
	# Preserve saved channel contracts and include channels authored by replacement scenes.
	document._bind_actors(document, document.get_channel_system())
	var new_channel_data: Dictionary = document.get_channel_system().serialize()
	for channel_name: String in old_channel_data:
		var saved: Dictionary = old_channel_data[channel_name].duplicate(true)
		if new_channel_data.has(channel_name):
			for role: String in ["sources", "targets"]:
				for identity: String in new_channel_data[channel_name][role]:
					if not saved.get(role, []).has(identity):
						if not saved.has(role):
							saved[role] = []
						saved[role].append(identity)
		new_channel_data[channel_name] = saved
	var instances: Array[ModuleInstance] = []
	for plan in plans:
		instances.append(replacements[plan.instance_id])
	return {
		"success": true,
		"error": "",
		"document": document,
		"instances": instances,
		"old_channel_data": old_channel_data,
		"channel_data": new_channel_data
	}


static func regenerate_unpinned(root: Node3D, plans: Array[Dictionary]) -> Dictionary:
	var staged := _stage_regeneration(root, plans)
	if not staged.success:
		return staged
	var new_nodes: Array[ModuleInstance] = staged.instances
	var old_nodes: Array[ModuleInstance] = []
	var indices: Array[int] = []
	for plan in plans:
		for instance in get_instances(root):
			if instance.instance_id == plan.instance_id:
				old_nodes.append(instance)
				indices.append(instance.get_index())
				break
	for instance in new_nodes:
		staged.document.remove_child(instance)
	staged.document.free()
	if new_nodes.is_empty():
		return {"success": true, "error": "", "instances": new_nodes}
	var graph: Array[Dictionary] = root.module_connections.duplicate(true)
	var undo := EditorGlobals.get_undo_redo()
	undo.create_action("Regenerate unpinned modules")
	undo.add_do_method(
		_swap_layout.bind(
			root, old_nodes, new_nodes, indices, graph, staged.channel_data, staged.channel_data
		)
	)
	undo.add_undo_method(
		_swap_layout.bind(
			root,
			new_nodes,
			old_nodes,
			indices,
			graph,
			root.channel_data.duplicate(true),
			staged.old_channel_data
		)
	)
	for instance in old_nodes:
		undo.add_undo_reference(instance)
	for instance in new_nodes:
		undo.add_do_reference(instance)
	undo.commit_action()
	return {"success": true, "error": "", "instances": new_nodes}


static func _swap_layout(
	root: Node3D,
	remove_nodes: Array[ModuleInstance],
	add_nodes: Array[ModuleInstance],
	indices: Array[int],
	graph: Array[Dictionary],
	channel_data: Dictionary,
	bindings: Dictionary
) -> void:
	for instance in remove_nodes:
		root.remove_child(instance)
	for instance in add_nodes:
		root.add_child(instance)
		instance.owner = root
		LevelRootScript.prepare_ownership(instance, root)
	# Restore positions in ascending order even though plans are ordered by stable ID.
	var order: Array[int] = []
	for index in indices.size():
		order.append(index)
	order.sort_custom(func(a: int, b: int) -> bool: return indices[a] < indices[b])
	for index in order:
		root.move_child(add_nodes[index], indices[index])
	root.module_connections = graph.duplicate(true)
	root.channel_data = channel_data.duplicate(true)
	root.get_channel_system().deserialize(bindings, root)
	root._bind_actors(root, root.get_channel_system())
	if root.authoring_mode:
		for instance in add_nodes:
			root._freeze_node(instance)


static func _remap_local_objectives(
	content: Node, previous_id: String, instance_id: String
) -> void:
	if previous_id == instance_id:
		return
	var prefix := previous_id + "/"
	for actor: Node in content.find_children("*", "", true, false):
		if not actor.has_meta("mission_objective"):
			continue
		var authored: Variant = actor.get_meta("mission_objective")
		if not authored is Dictionary or not authored.get("requires") is Array:
			continue
		var updated: Dictionary = authored.duplicate(true)
		for index: int in updated.requires.size():
			var prerequisite: Variant = updated.requires[index]
			if prerequisite is String and prerequisite.begins_with(prefix):
				updated.requires[index] = instance_id + "/" + prerequisite.trim_prefix(prefix)
		actor.set_meta("mission_objective", updated)


static func find_free_socket_on_ray(
	root: Node3D, ray_origin: Vector3, ray_direction: Vector3, max_distance: float = 1.5
) -> Dictionary:
	if root == null or not "module_connections" in root:
		return {}
	var direction := ray_direction.normalized()
	if direction.is_zero_approx():
		return {}
	var best_distance := max_distance
	var best := {}
	for instance: ModuleInstance in get_instances(root):
		for socket: Dictionary in instance.definition.sockets:
			var socket_id := str(socket.get("id", ""))
			var used := false
			for edge: Dictionary in root.module_connections:
				if (
					(
						edge.get("from_instance") == instance.instance_id
						and edge.get("from_socket") == socket_id
					)
					or (
						edge.get("to_instance") == instance.instance_id
						and edge.get("to_socket") == socket_id
					)
				):
					used = true
					break
			if used:
				continue
			var socket_position: Vector3 = (
				(instance.global_transform * socket.local_transform).origin
			)
			var distance_along_ray := maxf(0.0, direction.dot(socket_position - ray_origin))
			var ray_point := ray_origin + direction * distance_along_ray
			var distance_from_ray := ray_point.distance_to(socket_position)
			if distance_from_ray <= best_distance:
				best_distance = distance_from_ray
				best = {
					"target_instance_id": instance.instance_id,
					"target_socket_id": socket_id,
					"position": socket_position,
					"distance": distance_from_ray
				}
	return best


static func preview_module(
	root: Node3D,
	definition: PrefabMetadata,
	target_instance_id: String = "",
	target_socket_id: String = "",
	source_socket_id: String = "",
	quarter_turns: int = 0
) -> Dictionary:
	if root == null or not "module_connections" in root:
		return _failure("Open a LevelRoot document before previewing modules.")
	if definition == null or definition.module_id.is_empty() or not definition.is_valid():
		return _failure("The module definition is invalid.")
	var previous := validate_level(root)
	if not previous.valid:
		return _failure("Repair the existing layout first: " + "; ".join(previous.errors))

	var instances := get_instances(root)
	var candidate := ModuleInstance.new()
	candidate.definition = definition
	candidate.instance_id = _next_id(definition.module_id, instances)
	if instances.is_empty():
		if not target_instance_id.is_empty() or not target_socket_id.is_empty():
			candidate.free()
			return _failure("The first module is placed at the origin without a target.")
		candidate.transform = Transform3D(
			Basis(Vector3.UP, posmod(quarter_turns, 4) * PI / 2.0), Vector3.ZERO
		)
	else:
		var target: ModuleInstance = null
		for instance in instances:
			if instance.instance_id == target_instance_id:
				target = instance
		if target == null:
			candidate.free()
			return _failure("Select an existing target module and free socket.")
		var target_socket := target.get_socket(target_socket_id)
		var source_socket := candidate.get_socket(source_socket_id)
		if target_socket.is_empty() or source_socket.is_empty():
			candidate.free()
			return _failure("Both selected sockets must exist.")
		var target_pose: Transform3D = target.transform * target_socket.local_transform
		var opposite := Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO)
		candidate.transform = (
			target_pose * opposite * source_socket.local_transform.affine_inverse()
		)
		candidate.basis = Basis(Vector3.UP, posmod(quarter_turns, 4) * PI / 2.0) * candidate.basis
		candidate.position = (
			target_pose.origin - candidate.basis * source_socket.local_transform.origin
		)
	var candidate_transform := candidate.transform
	instances.append(candidate)
	var graph: Array[Dictionary] = root.module_connections.duplicate(true)
	if instances.size() > 1:
		graph.append(
			{
				"from_instance": target_instance_id,
				"from_socket": target_socket_id,
				"to_instance": candidate.instance_id,
				"to_socket": source_socket_id
			}
		)
	var errors := _validate(instances, graph)
	candidate.free()
	if not errors.is_empty():
		return {"success": false, "error": "; ".join(errors), "errors": errors}
	return {"success": true, "error": "", "transform": candidate_transform}


static func set_pinned(root: Node3D, instance_id: String, pinned: bool) -> Dictionary:
	if root == null or not "module_connections" in root:
		return _failure("Open a LevelRoot document before changing module pins.")
	var instance: ModuleInstance = null
	for candidate in get_instances(root):
		if candidate.instance_id == instance_id:
			instance = candidate
			break
	if instance == null:
		return _failure("Select an existing module before changing its pin.")
	if instance.pinned == pinned:
		return {"success": true, "error": "", "pinned": pinned}

	var undo := EditorGlobals.get_undo_redo()
	undo.create_action(("Pin" if pinned else "Unpin") + " module: " + instance_id)
	undo.add_do_property(instance, "pinned", pinned)
	undo.add_undo_property(instance, "pinned", instance.pinned)
	undo.add_do_reference(instance)
	undo.commit_action()
	return {"success": true, "error": "", "pinned": pinned}


static func validate_level(root: Node3D) -> Dictionary:
	if root == null or not "module_connections" in root:
		return {"valid": false, "errors": ["Document must be a LevelRoot."]}
	var errors := _validate(get_instances(root), root.module_connections)
	return {"valid": errors.is_empty(), "errors": errors}


static func _validate(
	instances: Array[ModuleInstance],
	graph: Array[Dictionary],
	supported_capabilities: Array[String] = SUPPORTED_CAPABILITIES
) -> Array[String]:
	var errors: Array[String] = []
	var ids := {}
	for instance in instances:
		if (
			instance.instance_id.is_empty()
			or "/" in instance.instance_id
			or ids.has(instance.instance_id)
		):
			errors.append("Module instance IDs must be nonempty, unique and contain no slash.")
		ids[instance.instance_id] = instance
		if (
			instance.definition == null
			or instance.definition.module_id.is_empty()
			or not instance.definition.is_valid()
		):
			errors.append("Invalid definition on " + instance.instance_id)
			continue
		for capability: String in instance.definition.required_capabilities:
			if capability not in supported_capabilities:
				errors.append(
					instance.instance_id + ": unsupported runtime capability " + capability
				)
		if not _orthogonal(instance.transform):
			errors.append(
				instance.instance_id + ": only orthogonal yaw and unit scale are supported."
			)
		for socket in instance.definition.sockets:
			var pose: Transform3D = socket.local_transform
			if not _orthogonal(pose):
				errors.append(
					(
						instance.instance_id
						+ ": socket must have orthogonal outward yaw and unit scale."
					)
				)
			var bounds := instance.get_local_bounds()
			var outward: Vector3 = -pose.basis.z
			var boundary := bounds.end.z if outward.z > 0.5 else bounds.position.z
			var coordinate := pose.origin.z
			if absf(outward.x) > 0.5:
				boundary = bounds.end.x if outward.x > 0 else bounds.position.x
				coordinate = pose.origin.x
			if (
				not bounds.grow(EPSILON).has_point(pose.origin)
				or absf(coordinate - boundary) > EPSILON
			):
				errors.append(instance.instance_id + ": socket is not on its outward boundary.")
			if not socket.clearance.grow(EPSILON).has_point(pose.origin + Vector3.UP * EPSILON):
				errors.append(
					instance.instance_id + ": socket clearance must reserve its floor approach."
				)
			var opening: Vector2 = socket.opening
			var left: Vector3 = pose.origin - pose.basis.x * opening.x * 0.5
			var right: Vector3 = (
				pose.origin + pose.basis.x * opening.x * 0.5 + Vector3.UP * opening.y
			)
			if (
				not bounds.grow(EPSILON).has_point(left)
				or not bounds.grow(EPSILON).has_point(right)
			):
				errors.append(
					instance.instance_id + ": socket opening extends outside module bounds."
				)
			if (
				not socket.clearance.grow(EPSILON).has_point(left)
				or not socket.clearance.grow(EPSILON).has_point(right)
			):
				errors.append(
					instance.instance_id + ": clearance must contain the full socket opening."
				)
	if not errors.is_empty():
		return errors
	var used := {}
	var neighbors := {}
	for connection in graph:
		var from_id: String = str(connection.get("from_instance", ""))
		var to_id: String = str(connection.get("to_instance", ""))
		if not ids.has(from_id) or not ids.has(to_id) or from_id == to_id:
			errors.append("Connection refers to missing modules or connects a module to itself.")
			continue
		var source: ModuleInstance = ids[from_id]
		var target: ModuleInstance = ids[to_id]
		var source_socket := source.get_socket(str(connection.get("from_socket", "")))
		var target_socket := target.get_socket(str(connection.get("to_socket", "")))
		if source_socket.is_empty() or target_socket.is_empty():
			errors.append("Connection refers to a missing socket.")
			continue
		var a := from_id + "/" + str(source_socket.id)
		var b := to_id + "/" + str(target_socket.id)
		if used.has(a) or used.has(b):
			errors.append("A socket cannot be connected more than once.")
		used[a] = true
		used[b] = true
		neighbors[a] = to_id
		neighbors[b] = from_id
		if (
			source_socket.get("kind", "walk") != target_socket.get("kind", "walk")
			or not source_socket.opening.is_equal_approx(target_socket.opening)
		):
			errors.append("Connected socket kinds and opening sizes must match.")
		var source_pose: Transform3D = source.transform * source_socket.local_transform
		var target_pose: Transform3D = target.transform * target_socket.local_transform
		if (
			source_pose.origin.distance_to(target_pose.origin) > EPSILON
			or not source_pose.basis.is_equal_approx(target_pose.basis * Basis(Vector3.UP, PI))
		):
			errors.append("Connected sockets must coincide and face in opposite directions.")
	for i in instances.size():
		var instance := instances[i]
		var bounds: AABB = instance.transform * instance.get_local_bounds()
		_validate_geometry_bounds(instance, instance, Transform3D.IDENTITY, errors)
		for j in range(i + 1, instances.size()):
			var other := instances[j]
			if _overlaps(bounds, other.transform * other.get_local_bounds()):
				errors.append(
					"Module occupancy overlaps: " + instance.instance_id + " / " + other.instance_id
				)
		for socket in instance.definition.sockets:
			var reserved: AABB = instance.transform * socket.clearance
			var key := instance.instance_id + "/" + str(socket.id)
			for other in instances:
				if other == instance or neighbors.get(key, "") == other.instance_id:
					continue
				if _overlaps(reserved, other.transform * other.get_local_bounds()):
					errors.append("Reserved socket approach is blocked: " + key)
			_validate_approach(instance, instance, Transform3D.IDENTITY, socket.clearance, errors)
	if instances.size() > 1:
		var reached := {instances[0].instance_id: true}
		for _pass in instances.size():
			for edge in graph:
				if reached.has(edge.get("from_instance", "")):
					reached[edge.get("to_instance", "")] = true
				if reached.has(edge.get("to_instance", "")):
					reached[edge.get("from_instance", "")] = true
		if reached.size() != instances.size():
			errors.append("Every module must belong to the connected layout.")
	return errors


static func _validate_approach(
	instance: ModuleInstance, node: Node, pose: Transform3D, clearance: AABB, errors: Array[String]
) -> void:
	# Actors (including a moving door) intentionally occupy openings, unlike static room geometry.
	if node is ActorBase:
		return
	if node != instance and node is Node3D:
		pose = pose * node.transform
	var solid := AABB()
	if (
		node is CSGBox3D
		and node.use_collision
		and not node.operation == CSGShape3D.OPERATION_SUBTRACTION
	):
		solid = AABB(-node.size * 0.5, node.size)
	elif node is CollisionShape3D and not node.disabled and node.shape is BoxShape3D:
		solid = AABB(-node.shape.size * 0.5, node.shape.size)
	elif node is CollisionShape3D and not node.disabled and node.shape is ConcavePolygonShape3D:
		var faces: PackedVector3Array = node.shape.get_faces()
		var interior := clearance.grow(-EPSILON)
		for index in range(0, faces.size(), 3):
			var a: Vector3 = pose * faces[index]
			var b: Vector3 = pose * faces[index + 1]
			var c: Vector3 = pose * faces[index + 2]
			var triangle_bounds := AABB(a, Vector3.ZERO).expand(b).expand(c)
			if not triangle_bounds.intersects(interior):
				continue
			var polygon := PackedVector3Array([a, b, c])
			for axis in 3:
				var normal := Vector3.ZERO
				normal[axis] = 1
				polygon = Geometry3D.clip_polygon(polygon, Plane(normal, interior.end[axis]))
				if polygon.is_empty():
					break
				polygon = Geometry3D.clip_polygon(polygon, Plane(-normal, -interior.position[axis]))
				if polygon.is_empty():
					break
			if not polygon.is_empty():
				errors.append(
					(
						instance.instance_id
						+ ": static triangles block a reserved socket approach ("
						+ str(node.name)
						+ ")."
					)
				)
				break
	if solid.has_volume() and _overlaps(pose * solid, clearance):
		errors.append(
			(
				instance.instance_id
				+ ": static geometry blocks a reserved socket approach ("
				+ str(node.name)
				+ ")."
			)
		)
	for child in node.get_children():
		_validate_approach(instance, child, pose, clearance, errors)


static func _validate_geometry_bounds(
	instance: ModuleInstance, node: Node, pose: Transform3D, errors: Array[String]
) -> void:
	if node is ActorBase:
		return
	if node != instance and node is Node3D:
		pose = pose * node.transform
	# Dimensions measure the room above the walking plane; the kit's structural slab is 30cm below it.
	var allowed := instance.get_local_bounds()
	allowed.position.y -= 0.3
	allowed.size.y += 0.3
	allowed = allowed.grow(EPSILON)
	var solid := AABB()
	if node is CSGBox3D and node.use_collision:
		solid = pose * AABB(-node.size * 0.5, node.size)
	elif node is CollisionShape3D and not node.disabled:
		if node.shape is BoxShape3D:
			solid = pose * AABB(-node.shape.size * 0.5, node.shape.size)
		elif node.shape is ConcavePolygonShape3D:
			for vertex: Vector3 in node.shape.get_faces():
				if not allowed.has_point(pose * vertex):
					errors.append(
						instance.instance_id + ": collision extends outside declared module bounds."
					)
					break
		elif node.shape != null:
			errors.append(
				(
					instance.instance_id
					+ ": static module collision must use boxes or baked triangle meshes."
				)
			)
	elif node is CSGShape3D and node.use_collision:
		errors.append(
			(
				instance.instance_id
				+ ": non-box CSG must be baked to triangle collision before placement."
			)
		)
	if solid.has_volume() and not allowed.encloses(solid):
		errors.append(instance.instance_id + ": collision extends outside declared module bounds.")
	for child in node.get_children():
		_validate_geometry_bounds(instance, child, pose, errors)


static func _orthogonal(pose: Transform3D) -> bool:
	if not pose.is_finite():
		return false
	for turn in 4:
		if pose.basis.is_equal_approx(Basis(Vector3.UP, turn * PI / 2.0)):
			return true
	return false


static func _overlaps(a: AABB, b: AABB) -> bool:
	return a.grow(-EPSILON).intersects(b.grow(-EPSILON))


static func _next_id(module_id: String, instances: Array[ModuleInstance]) -> String:
	var base := module_id
	var used := {}
	for instance in instances:
		used[instance.instance_id] = true
	var candidate := base
	var suffix := 2
	while used.has(candidate):
		candidate = base + "_" + str(suffix)
		suffix += 1
	return candidate


static func _attach(root: Node3D, instance: ModuleInstance, graph: Array[Dictionary]) -> void:
	root.add_child(instance)
	instance.owner = root
	LevelRootScript.prepare_ownership(instance, root)
	root.module_connections = graph.duplicate(true)
	if root.has_method("restore_runtime_bindings"):
		root.restore_runtime_bindings()


static func _detach(root: Node3D, instance: ModuleInstance, graph: Array[Dictionary]) -> void:
	root.remove_child(instance)
	root.module_connections = graph.duplicate(true)
	if root.has_method("restore_runtime_bindings"):
		root.restore_runtime_bindings()


static func _failure(message: String) -> Dictionary:
	return {"success": false, "error": message, "instance": null}
