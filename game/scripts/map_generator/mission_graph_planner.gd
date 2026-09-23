class_name MissionGraphPlanner
extends RefCounted

## Plans and classifies the logical mission graph before lock placement.
## The planner is topology-only: spatial assembly and objective state remain
## separate phases.

const Room = preload("res://game/scripts/map_generator/room.gd")


func plan(context: GenerationContext) -> Dictionary:
	if context == null or context.rooms.is_empty():
		return _invalid("Mission graph requires at least one room.")

	var rooms_by_id: Dictionary = {}
	for room: Room in context.rooms:
		if room.id < 0 or rooms_by_id.has(room.id):
			return _invalid("Mission graph room IDs must be unique and non-negative.")
		rooms_by_id[room.id] = room

	var room_ids: Array[int] = []
	for room_id: Variant in rooms_by_id.keys():
		room_ids.append(int(room_id))
	room_ids.sort()

	var room_edges: Array[Dictionary] = []
	var edge_keys: Dictionary = {}
	for room: Room in context.rooms:
		var neighbors: Array = room.connections.duplicate()
		neighbors.sort()
		for connected_id: Variant in neighbors:
			if not connected_id is int or not rooms_by_id.has(connected_id):
				return _invalid("Mission graph contains an edge to an unknown room.")
			var edge_key := "%d:%d" % [room.id, connected_id]
			if edge_keys.has(edge_key):
				continue
			edge_keys[edge_key] = true
			room_edges.append({"from_room_id": room.id, "to_room_id": connected_id})
	room_edges.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			if a.from_room_id == b.from_room_id:
				return a.to_room_id < b.to_room_id
			return a.from_room_id < b.from_room_id
	)

	var start_room_id := _find_start_room_id(context, rooms_by_id)
	var traversal := _traverse(rooms_by_id, start_room_id)
	var visited: Dictionary = traversal.get("visited", {})
	if visited.size() != room_ids.size():
		return _invalid("Mission graph is disconnected from the start room.")

	var goal_room_id := _find_goal_room_id(context, rooms_by_id)
	var route_ids: Array[int] = []
	if goal_room_id != start_room_id:
		route_ids = _reconstruct_route(traversal.get("parents", {}), goal_room_id)
	if route_ids.is_empty():
		goal_room_id = int(traversal.get("farthest_room_id", start_room_id))
		route_ids = _reconstruct_route(traversal.get("parents", {}), goal_room_id)

	if route_ids.is_empty():
		return _invalid("Mission graph has no recovery route.")

	var route_set: Dictionary = {}
	for room_id: int in route_ids:
		route_set[room_id] = true
	var branch_room_ids: Array[int] = []
	for room_id: int in room_ids:
		if not route_set.has(room_id):
			branch_room_ids.append(room_id)

	var graph_profile := "linear"
	if not branch_room_ids.is_empty():
		graph_profile = "branching"
	elif room_edges.size() > maxi(0, (room_ids.size() - 1) * 2):
		graph_profile = "cyclic"

	return {
		"is_valid": true,
		"error_message": "",
		"room_ids": room_ids,
		"room_edges": room_edges,
		"start_room_id": start_room_id,
		"goal_room_id": goal_room_id,
		"recovery_route": route_ids,
		"branch_room_ids": branch_room_ids,
		"graph_profile": graph_profile
	}


func _find_start_room_id(context: GenerationContext, rooms_by_id: Dictionary) -> int:
	var start := context.player_start_position
	if (
		start.x >= 0
		and start.y >= 0
		and start.y < context.grid.size()
		and start.x < context.grid[start.y].size()
	):
		var room_id: int = context.grid[start.y][start.x].room_id
		if rooms_by_id.has(room_id):
			return room_id
	var room_ids: Array[int] = []
	for room_id: Variant in rooms_by_id.keys():
		room_ids.append(int(room_id))
	room_ids.sort()
	return room_ids[0]


func _find_goal_room_id(context: GenerationContext, rooms_by_id: Dictionary) -> int:
	var exit := context.exit_position
	if (
		exit.x >= 0
		and exit.y >= 0
		and exit.y < context.grid.size()
		and exit.x < context.grid[exit.y].size()
	):
		var room_id: int = context.grid[exit.y][exit.x].room_id
		if rooms_by_id.has(room_id):
			return room_id
	return -1


func _traverse(rooms_by_id: Dictionary, start_room_id: int) -> Dictionary:
	var parents: Dictionary = {start_room_id: -1}
	var distances: Dictionary = {start_room_id: 0}
	var queue: Array[int] = [start_room_id]
	var farthest_room_id := start_room_id
	while not queue.is_empty():
		var room_id: int = queue.pop_front()
		var room_distance: int = int(distances[room_id])
		if (
			room_distance > int(distances[farthest_room_id])
			or (room_distance == int(distances[farthest_room_id]) and room_id < farthest_room_id)
		):
			farthest_room_id = room_id
		var room: Room = rooms_by_id[room_id]
		var neighbors: Array = room.connections.duplicate()
		neighbors.sort()
		for connected_id: Variant in neighbors:
			if not connected_id is int or parents.has(connected_id):
				continue
			parents[connected_id] = room_id
			distances[connected_id] = room_distance + 1
			queue.append(connected_id)
	return {"parents": parents, "visited": parents, "farthest_room_id": farthest_room_id}


func _reconstruct_route(parents: Dictionary, target_room_id: int) -> Array[int]:
	if not parents.has(target_room_id):
		return []
	var route: Array[int] = []
	var current_id := target_room_id
	while current_id >= 0:
		route.push_front(current_id)
		current_id = int(parents.get(current_id, -1))
	return route


func _invalid(message: String) -> Dictionary:
	return {"is_valid": false, "error_message": message}
