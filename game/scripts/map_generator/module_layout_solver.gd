class_name ModuleLayoutSolver
extends RefCounted

## Deterministic bounded solver for mission graphs.
## It selects reusable authored modules, pairs typed sockets and rejects
## clearance collisions before a spatial plan is published. Cyclic graphs use
## a spanning-tree placement followed by bounded loop-socket closure search.

const PrefabMetadata = preload("res://game/scripts/map_generator/prefab_metadata.gd")
const EPSILON := 0.001


func solve(
	graph_plan: Dictionary, catalog: Array[PrefabMetadata], max_attempts: int = 128
) -> Dictionary:
	if not bool(graph_plan.get("is_valid", false)):
		return _invalid("Cannot solve an invalid mission graph.")
	if catalog.is_empty():
		return _invalid("Spatial solver requires at least one module definition.")
	if max_attempts <= 0:
		return _invalid("Spatial solver attempt limit must be positive.")

	var room_ids := _read_room_ids(graph_plan.get("room_ids", []))
	if room_ids.is_empty():
		return _invalid("Spatial solver requires declared room IDs.")
	var adjacency := _build_adjacency(room_ids, graph_plan.get("room_edges", []))
	if adjacency.is_empty():
		return _invalid("Spatial solver requires valid room edges.")
	var undirected_edges := _undirected_edges(adjacency)
	var edge_count := undirected_edges.size()
	var graph_profile := "cyclic" if edge_count > room_ids.size() - 1 else "linear"
	var start_room_id := int(graph_plan.get("start_room_id", room_ids[0]))
	if not adjacency.has(start_room_id):
		return _invalid("Spatial solver start room is not declared.")
	var traversal := _build_tree(adjacency, start_room_id)
	if traversal.order.size() != room_ids.size():
		return _invalid("Spatial solver requires a connected mission graph.").merged(
			{
				"graph_profile": graph_profile,
				"room_count": room_ids.size(),
				"edge_count": edge_count
			},
			true
		)
	var tree_adjacency := _build_tree_adjacency(room_ids, traversal.parents)
	var loop_edges := _build_loop_edges(undirected_edges, traversal.parents)
	var required_kind := str(graph_plan.get("required_socket_kind", ""))
	var ordered_catalog: Array[PrefabMetadata] = []
	for definition: PrefabMetadata in catalog:
		if required_kind.is_empty() or _has_socket_kind(definition, required_kind):
			ordered_catalog.append(definition)
	if ordered_catalog.is_empty():
		return _invalid("No compatible module definitions for the required socket kind.")
	ordered_catalog.sort_custom(
		func(left: PrefabMetadata, right: PrefabMetadata) -> bool:
			if left.module_id != right.module_id:
				return left.module_id < right.module_id
			return left.scene_path < right.scene_path
	)
	var state := {"attempts": 0, "exhausted": false, "error": ""}
	var placements: Dictionary = {}
	var connections: Array[Dictionary] = []
	if not _search(
		traversal.order,
		traversal.parents,
		tree_adjacency,
		loop_edges,
		ordered_catalog,
		0,
		placements,
		connections,
		state,
		max_attempts
	):
		var reason := (
			"Spatial solver attempt limit exhausted"
			if state.exhausted
			else "No compatible spatial layout"
		)
		return (
			_invalid(reason + (": " + str(state.error) if not str(state.error).is_empty() else ""))
			. merged(
				{
					"attempts": state.attempts,
					"graph_profile": graph_profile,
					"room_count": room_ids.size(),
					"edge_count": edge_count,
					"loop_edge_count": loop_edges.size(),
					"closed_loop_count": 0
				},
				true
			)
		)
	var ordered_placements: Array[Dictionary] = []
	for room_id: int in traversal.order:
		var placement: Dictionary = placements[room_id]
		ordered_placements.append(
			{
				"room_id": room_id,
				"module_id": placement.module_id,
				"scene_path": placement.scene_path,
				"transform": placement.transform,
				"used_socket_ids": placement.used_socket_ids.duplicate()
			}
		)
	connections.sort_custom(
		func(left: Dictionary, right: Dictionary) -> bool:
			if left.from_room_id == right.from_room_id:
				return left.to_room_id < right.to_room_id
			return left.from_room_id < right.from_room_id
	)
	var catalog_usage := {}
	for placement: Dictionary in ordered_placements:
		var module_id := str(placement.get("module_id", ""))
		catalog_usage[module_id] = int(catalog_usage.get(module_id, 0)) + 1
	return {
		"is_valid": true,
		"error_message": "",
		"attempts": state.attempts,
		"graph_profile": graph_profile,
		"room_count": room_ids.size(),
		"edge_count": edge_count,
		"loop_edge_count": loop_edges.size(),
		"closed_loop_count": loop_edges.size(),
		"catalog_usage": catalog_usage,
		"catalog_diversity": catalog_usage.size(),
		"placements": ordered_placements,
		"connections": connections
	}


func _has_socket_kind(definition: PrefabMetadata, required_kind: String) -> bool:
	for socket: Dictionary in definition.sockets:
		if str(socket.get("kind", "walk")) == required_kind:
			return true
	return false


func _ordered_catalog(
	catalog: Array[PrefabMetadata], placements: Dictionary
) -> Array[PrefabMetadata]:
	var ordered: Array[PrefabMetadata] = []
	ordered.assign(catalog)
	ordered.sort_custom(
		func(left: PrefabMetadata, right: PrefabMetadata) -> bool:
			var left_usage := _catalog_usage_count(left.module_id, placements)
			var right_usage := _catalog_usage_count(right.module_id, placements)
			if left_usage != right_usage:
				return left_usage < right_usage
			if left.module_id != right.module_id:
				return left.module_id < right.module_id
			return left.scene_path < right.scene_path
	)
	return ordered


func _catalog_usage_count(module_id: String, placements: Dictionary) -> int:
	var count := 0
	for placement: Variant in placements.values():
		if placement is Dictionary and str(placement.get("module_id", "")) == module_id:
			count += 1
	return count


func _search(
	order: Array[int],
	parents: Dictionary,
	adjacency: Dictionary,
	loop_edges: Array[Dictionary],
	catalog: Array[PrefabMetadata],
	depth: int,
	placements: Dictionary,
	connections: Array[Dictionary],
	state: Dictionary,
	max_attempts: int
) -> bool:
	if depth >= order.size():
		return _close_loops(loop_edges, 0, placements, connections, state, max_attempts)
	var room_id: int = order[depth]
	var parent_id: int = int(parents.get(room_id, -1))
	var required_sockets: int = adjacency[room_id].size()
	for definition: PrefabMetadata in _ordered_catalog(catalog, placements):
		if definition.sockets.size() < required_sockets:
			continue
		if state.attempts >= max_attempts:
			state.exhausted = true
			return false
		state.attempts += 1
		if parent_id < 0:
			var root_placement := _make_placement(definition, Transform3D.IDENTITY)
			if _overlaps_existing(root_placement, placements, -1):
				continue
			placements[room_id] = root_placement
			if _search(
				order,
				parents,
				adjacency,
				loop_edges,
				catalog,
				depth + 1,
				placements,
				connections,
				state,
				max_attempts
			):
				return true
			placements.erase(room_id)
			continue

		var parent_placement: Dictionary = placements.get(parent_id, {})
		if parent_placement.is_empty():
			state.error = "Parent room %d was not placed." % parent_id
			return false
		var parent_definition: PrefabMetadata = parent_placement.definition
		for parent_socket: Dictionary in parent_definition.sockets:
			if parent_placement.used_socket_ids.has(str(parent_socket.get("id", ""))):
				continue
			for child_socket: Dictionary in definition.sockets:
				if parent_socket.get("kind", "walk") != child_socket.get("kind", "walk"):
					continue
				var transform := _attach_transform(
					parent_placement.transform, parent_socket, child_socket
				)
				var placement := _make_placement(definition, transform)
				if _overlaps_existing(placement, placements, parent_id):
					continue
				parent_placement.used_socket_ids.append(str(parent_socket.get("id", "")))
				placement.used_socket_ids.append(str(child_socket.get("id", "")))
				placements[room_id] = placement
				connections.append(
					{
						"from_room_id": parent_id,
						"to_room_id": room_id,
						"from_socket_id": str(parent_socket.get("id", "")),
						"to_socket_id": str(child_socket.get("id", ""))
					}
				)
				if _search(
					order,
					parents,
					adjacency,
					loop_edges,
					catalog,
					depth + 1,
					placements,
					connections,
					state,
					max_attempts
				):
					return true
				connections.pop_back()
				placements.erase(room_id)
				parent_placement.used_socket_ids.pop_back()
		return false
	return false


func _close_loops(
	loop_edges: Array[Dictionary],
	depth: int,
	placements: Dictionary,
	connections: Array[Dictionary],
	state: Dictionary,
	max_attempts: int
) -> bool:
	if depth >= loop_edges.size():
		return true
	var edge: Dictionary = loop_edges[depth]
	var from_placement: Dictionary = placements.get(edge.from_room_id, {})
	var to_placement: Dictionary = placements.get(edge.to_room_id, {})
	if from_placement.is_empty() or to_placement.is_empty():
		state.error = "Loop closure references an unplaced room."
		return false
	var from_definition: PrefabMetadata = from_placement.definition
	var to_definition: PrefabMetadata = to_placement.definition
	for from_socket: Dictionary in from_definition.sockets:
		var from_socket_id := str(from_socket.get("id", ""))
		if from_placement.used_socket_ids.has(from_socket_id):
			continue
		for to_socket: Dictionary in to_definition.sockets:
			if state.attempts >= max_attempts:
				state.exhausted = true
				return false
			state.attempts += 1
			var to_socket_id := str(to_socket.get("id", ""))
			if to_placement.used_socket_ids.has(to_socket_id):
				continue
			if from_socket.get("kind", "walk") != to_socket.get("kind", "walk"):
				continue
			var from_pose: Transform3D = from_placement.transform * from_socket.local_transform
			var to_pose: Transform3D = to_placement.transform * to_socket.local_transform
			if (
				from_pose.origin.distance_to(to_pose.origin) > EPSILON
				or not from_pose.basis.is_equal_approx(to_pose.basis * Basis(Vector3.UP, PI))
			):
				continue
			from_placement.used_socket_ids.append(from_socket_id)
			to_placement.used_socket_ids.append(to_socket_id)
			connections.append(
				{
					"from_room_id": edge.from_room_id,
					"to_room_id": edge.to_room_id,
					"from_socket_id": from_socket_id,
					"to_socket_id": to_socket_id
				}
			)
			if _close_loops(loop_edges, depth + 1, placements, connections, state, max_attempts):
				return true
			connections.pop_back()
			from_placement.used_socket_ids.pop_back()
			to_placement.used_socket_ids.pop_back()
	state.error = (
		"No compatible loop closure for edge %d:%d." % [edge.from_room_id, edge.to_room_id]
	)
	return false


func _attach_transform(
	parent_transform: Transform3D, parent_socket: Dictionary, child_socket: Dictionary
) -> Transform3D:
	var parent_pose: Transform3D = parent_transform * parent_socket.local_transform
	var opposite := Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO)
	return parent_pose * opposite * child_socket.local_transform.affine_inverse()


func _make_placement(definition: PrefabMetadata, transform: Transform3D) -> Dictionary:
	return {
		"definition": definition,
		"module_id": definition.module_id,
		"scene_path": definition.scene_path,
		"transform": transform,
		"used_socket_ids": [],
		"bounds": _world_bounds(definition.dimensions, transform)
	}


func _world_bounds(dimensions: Vector3, transform: Transform3D) -> AABB:
	var local := AABB(-dimensions / 2.0, dimensions)
	var corners: Array[Vector3] = []
	for x in [local.position.x, local.end.x]:
		for y in [local.position.y, local.end.y]:
			for z in [local.position.z, local.end.z]:
				corners.append(transform * Vector3(x, y, z))
	var result := AABB(corners[0], Vector3.ZERO)
	for corner: Vector3 in corners:
		result = result.expand(corner)
	return result


func _overlaps_existing(
	candidate: Dictionary, placements: Dictionary, ignored_room_id: int
) -> bool:
	for room_id: Variant in placements:
		if int(room_id) == ignored_room_id:
			continue
		if candidate.bounds.grow(EPSILON).intersects(placements[room_id].bounds.grow(EPSILON)):
			return true
	return false


func _read_room_ids(values: Variant) -> Array[int]:
	if not values is Array:
		return []
	var result: Array[int] = []
	for value: Variant in values:
		if not value is int or result.has(value):
			return []
		result.append(value)
	result.sort()
	return result


func _build_adjacency(room_ids: Array[int], edges: Variant) -> Dictionary:
	if not edges is Array:
		return {}
	var adjacency: Dictionary = {}
	for room_id: int in room_ids:
		adjacency[room_id] = []
	var seen: Dictionary = {}
	for edge: Variant in edges:
		if not edge is Dictionary:
			return {}
		var from_id := int(edge.get("from_room_id", -1))
		var to_id := int(edge.get("to_room_id", -1))
		if not adjacency.has(from_id) or not adjacency.has(to_id) or from_id == to_id:
			return {}
		var key := "%d:%d" % [mini(from_id, to_id), maxi(from_id, to_id)]
		if seen.has(key):
			continue
		seen[key] = true
		adjacency[from_id].append(to_id)
		adjacency[to_id].append(from_id)
	for room_id: int in room_ids:
		adjacency[room_id].sort()
	return adjacency


func _undirected_edges(adjacency: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for from_id: int in adjacency:
		for to_id: int in adjacency[from_id]:
			var key := "%d:%d" % [mini(from_id, to_id), maxi(from_id, to_id)]
			if not result.has(key):
				result.append(key)
	result.sort()
	return result


func _build_tree(adjacency: Dictionary, start_room_id: int) -> Dictionary:
	var parents: Dictionary = {start_room_id: -1}
	var order: Array[int] = [start_room_id]
	var queue: Array[int] = [start_room_id]
	while not queue.is_empty():
		var room_id: int = queue.pop_front()
		for neighbor_id: int in adjacency[room_id]:
			if parents.has(neighbor_id):
				continue
			parents[neighbor_id] = room_id
			order.append(neighbor_id)
			queue.append(neighbor_id)
	return {"parents": parents, "order": order}


func _build_tree_adjacency(room_ids: Array[int], parents: Dictionary) -> Dictionary:
	var adjacency: Dictionary = {}
	for room_id: int in room_ids:
		adjacency[room_id] = []
	for room_id: int in room_ids:
		var parent_id := int(parents.get(room_id, -1))
		if parent_id < 0:
			continue
		adjacency[parent_id].append(room_id)
		adjacency[room_id].append(parent_id)
	for room_id: int in room_ids:
		adjacency[room_id].sort()
	return adjacency


func _build_loop_edges(edge_keys: Array[String], parents: Dictionary) -> Array[Dictionary]:
	var tree_edges: Dictionary = {}
	for child_id: Variant in parents:
		var parent_id := int(parents[child_id])
		if parent_id >= 0:
			tree_edges[_edge_key(parent_id, int(child_id))] = true
	var result: Array[Dictionary] = []
	for key: String in edge_keys:
		if tree_edges.has(key):
			continue
		var endpoints := key.split(":")
		result.append({"from_room_id": int(endpoints[0]), "to_room_id": int(endpoints[1])})
	return result


func _edge_key(left_id: int, right_id: int) -> String:
	return "%d:%d" % [mini(left_id, right_id), maxi(left_id, right_id)]


func _invalid(message: String) -> Dictionary:
	return {
		"is_valid": false,
		"error_message": message,
		"attempts": 0,
		"graph_profile": "invalid",
		"room_count": 0,
		"edge_count": 0,
		"loop_edge_count": 0,
		"closed_loop_count": 0,
		"placements": [],
		"connections": []
	}
