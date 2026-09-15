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
const SUPPORTED_CAPABILITIES := ["walk"]


static func get_catalog() -> Array[PrefabMetadata]:
	var result: Array[PrefabMetadata] = []
	for path: String in CATALOG:
		var definition := load(path) as PrefabMetadata
		if definition and definition.is_valid():
			result.append(definition)
	return result


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


static func build_regeneration_plans(root: Node3D) -> Dictionary:
	if root == null or not "module_connections" in root:
		return _failure("Open a LevelRoot document before capturing regeneration plans.")
	var pending: Array[ModuleInstance] = []
	var placed_ids: Dictionary = {}
	for instance: ModuleInstance in get_instances(root):
		if instance.pinned:
			placed_ids[instance.instance_id] = true
		else:
			pending.append(instance)
	var plans: Array[Dictionary] = []
	var seeded := false
	while not pending.is_empty():
		var progressed := false
		for index in range(pending.size() - 1, -1, -1):
			var instance := pending[index]
			var plan := _build_plan_for_instance(root, instance, placed_ids)
			if plan.is_empty():
				if not seeded and placed_ids.is_empty():
					plan = {"definition": instance.definition}
					seeded = true
				else:
					continue
			plans.append(plan)
			placed_ids[instance.instance_id] = true
			pending.remove_at(index)
			progressed = true
		if not progressed:
			return _failure("Unable to derive a connected regeneration order.")
	return {"success": true, "error": "", "plans": plans}


static func _build_plan_for_instance(
	root: Node3D, instance: ModuleInstance, placed_ids: Dictionary
) -> Dictionary:
	for edge: Dictionary in root.module_connections:
		var from_id := str(edge.get("from_instance", ""))
		var to_id := str(edge.get("to_instance", ""))
		if to_id == instance.instance_id and placed_ids.has(from_id):
			return {
				"definition": instance.definition,
				"target_instance_id": from_id,
				"target_socket_id": str(edge.get("from_socket", "")),
				"source_socket_id": str(edge.get("to_socket", ""))
			}
		if from_id == instance.instance_id and placed_ids.has(to_id):
			return {
				"definition": instance.definition,
				"target_instance_id": to_id,
				"target_socket_id": str(edge.get("to_socket", "")),
				"source_socket_id": str(edge.get("from_socket", ""))
			}
	return {}


static func regenerate_unpinned(root: Node3D, plans: Array[Dictionary]) -> Dictionary:
	if root == null or not "module_connections" in root:
		return _failure("Open a LevelRoot document before regenerating modules.")
	var old_graph: Array[Dictionary] = root.module_connections.duplicate(true)
	var old_nodes: Array[ModuleInstance] = []
	var pinned_ids: Dictionary = {}
	for instance: ModuleInstance in get_instances(root):
		if instance.pinned:
			pinned_ids[instance.instance_id] = true
		else:
			old_nodes.append(instance)
	for instance: ModuleInstance in old_nodes:
		root.remove_child(instance)
	root.module_connections = _filter_graph(old_graph, pinned_ids)
	var new_nodes: Array[ModuleInstance] = []
	for plan: Dictionary in plans:
		var definition := plan.get("definition") as PrefabMetadata
		if definition == null:
			_rollback_regeneration(root, old_nodes, new_nodes, old_graph)
			return _failure("Every regeneration plan needs a valid module definition.")
		var result := place_module(
			root,
			definition,
			str(plan.get("target_instance_id", "")),
			str(plan.get("target_socket_id", "")),
			str(plan.get("source_socket_id", "")),
			int(plan.get("quarter_turns", 0)),
			false,
			false
		)
		if not result.success:
			_rollback_regeneration(root, old_nodes, new_nodes, old_graph)
			return result
		new_nodes.append(result.instance as ModuleInstance)
	var final_validation := validate_level(root)
	if not final_validation.valid:
		_rollback_regeneration(root, old_nodes, new_nodes, old_graph)
		return _failure("Regenerated layout is invalid: " + "; ".join(final_validation.errors))
	var new_graph: Array[Dictionary] = root.module_connections.duplicate(true)
	var undo := EditorGlobals.get_undo_redo()
	undo.create_action("Regenerate unpinned modules")
	undo.add_do_method(_swap_layout.bind(root, old_nodes, new_nodes, new_graph))
	undo.add_undo_method(_swap_layout.bind(root, new_nodes, old_nodes, old_graph))
	for instance: ModuleInstance in old_nodes:
		undo.add_do_reference(instance)
	for instance: ModuleInstance in new_nodes:
		undo.add_do_reference(instance)
	undo.commit_action()
	return {"success": true, "error": "", "instances": new_nodes}


static func _filter_graph(graph: Array[Dictionary], instance_ids: Dictionary) -> Array[Dictionary]:
	var filtered: Array[Dictionary] = []
	for edge: Dictionary in graph:
		if (
			instance_ids.has(edge.get("from_instance", ""))
			and instance_ids.has(edge.get("to_instance", ""))
		):
			filtered.append(edge.duplicate(true))
	return filtered


static func _rollback_regeneration(
	root: Node3D,
	old_nodes: Array[ModuleInstance],
	new_nodes: Array[ModuleInstance],
	old_graph: Array[Dictionary]
) -> void:
	for instance: ModuleInstance in new_nodes:
		if instance.get_parent() == root:
			root.remove_child(instance)
		instance.free()
	for instance: ModuleInstance in old_nodes:
		root.add_child(instance)
		instance.owner = root
		LevelRootScript.prepare_ownership(instance, root)
	root.module_connections = old_graph.duplicate(true)


static func _swap_layout(
	root: Node3D,
	remove_nodes: Array[ModuleInstance],
	add_nodes: Array[ModuleInstance],
	graph: Array[Dictionary]
) -> void:
	for instance: ModuleInstance in remove_nodes:
		if instance.get_parent() == root:
			root.remove_child(instance)
	for instance: ModuleInstance in add_nodes:
		if instance.get_parent() == null:
			root.add_child(instance)
			instance.owner = root
			LevelRootScript.prepare_ownership(instance, root)
	root.module_connections = graph.duplicate(true)


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


static func _validate(instances: Array[ModuleInstance], graph: Array[Dictionary]) -> Array[String]:
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
			if capability not in SUPPORTED_CAPABILITIES:
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
