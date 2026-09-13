@tool
extends EditorNode3DGizmoPlugin


func _init() -> void:
	create_material("channel_wire", Color.WHITE)


func _get_gizmo_name() -> String:
	return "ConnectionWire"


func _has_gizmo(node: Node3D) -> bool:
	# Show on nodes that have channel connections
	return _has_channel_data(node)


func _has_channel_data(node: Node3D) -> bool:
	return not _get_connections(node).is_empty()


func _redraw(gizmo: EditorNode3DGizmo) -> void:
	gizmo.clear()

	var node := gizmo.get_node_3d()
	if not node:
		return

	# Get channel connections
	var connections := _get_connections(node)
	if connections.is_empty():
		return

	for connection in connections:
		_draw_connection(gizmo, node, connection)


func _get_connections(node: Node3D) -> Array:
	var current: Node = node.get_parent()
	while current:
		if current.has_method("get_channel_system"):
			var result: Array[Dictionary] = []
			for connection: Dictionary in current.get_channel_system().get_node_connections(node):
				if connection.role == "source":
					result.append(connection)
			return result
		current = current.get_parent()
	return []


func _draw_connection(gizmo: EditorNode3DGizmo, source: Node3D, connection: Dictionary) -> void:
	var target := connection.get("other") as Node3D
	if not is_instance_valid(target):
		return

	var lines := PackedVector3Array()
	var start := Vector3.ZERO  # Local to source
	var end := source.to_local(target.global_position)

	# Draw curved wire
	_draw_wire(lines, start, end)

	gizmo.add_lines(
		lines, get_material("channel_wire", gizmo), false, connection.get("color", Color.WHITE)
	)


func _draw_wire(lines: PackedVector3Array, start: Vector3, end: Vector3) -> void:
	# Draw a bezier curve wire
	var mid_y := maxf(start.y, end.y) + 1.0
	var control1 := Vector3(start.x, mid_y, start.z)
	var control2 := Vector3(end.x, mid_y, end.z)

	var segments := 20
	for i in range(segments):
		var t1 := float(i) / segments
		var t2 := float(i + 1) / segments

		var p1 := _bezier(start, control1, control2, end, t1)
		var p2 := _bezier(start, control1, control2, end, t2)

		lines.append(p1)
		lines.append(p2)

	# Draw arrow at end
	var arrow_size := 0.2
	var dir := (end - _bezier(start, control1, control2, end, 0.95)).normalized()
	var right := dir.cross(Vector3.UP).normalized() * arrow_size

	lines.append(end)
	lines.append(end - dir * arrow_size + right)
	lines.append(end)
	lines.append(end - dir * arrow_size - right)


func _bezier(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var q0 := p0.lerp(p1, t)
	var q1 := p1.lerp(p2, t)
	var q2 := p2.lerp(p3, t)
	var r0 := q0.lerp(q1, t)
	var r1 := q1.lerp(q2, t)
	return r0.lerp(r1, t)
