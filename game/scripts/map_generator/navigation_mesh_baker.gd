class_name NavigationMeshBaker
extends RefCounted

## Synchronous baking of a prepared, tree-attached generated geometry subtree.
## The caller owns geometry attachment, CSG updates and the returned region.

const AGENT_RADIUS := 0.5
const AGENT_HEIGHT := 2.0
const CELL_SIZE := 0.25
const CELL_HEIGHT := 0.25
const AGENT_MAX_CLIMB := 0.5
const AGENT_MAX_SLOPE := 45.0

var _context: GenerationContext
var _navigation_region: NavigationRegion3D
var _navigation_mesh: NavigationMesh


func initialize(context: GenerationContext) -> void:
	# A parented region has been handed off to its generated scene. Only reclaim
	# an unowned region left by an earlier generation attempt.
	if is_instance_valid(_navigation_region) and _navigation_region.get_parent() == null:
		if _context != null and _context.navigation_region == _navigation_region:
			_context.navigation_region = null
		_navigation_region.free()
	_context = context
	_navigation_region = null
	_navigation_mesh = null
	if context == null:
		return
	if is_instance_valid(context.navigation_region):
		if context.navigation_region.get_parent() == null:
			context.navigation_region.free()
	_navigation_region = NavigationRegion3D.new()
	_navigation_region.name = "NavigationRegion"
	_navigation_mesh = NavigationMesh.new()
	_configure_navigation_mesh()
	_navigation_region.navigation_mesh = _navigation_mesh
	context.navigation_region = _navigation_region


func _configure_navigation_mesh() -> void:
	_navigation_mesh.agent_radius = AGENT_RADIUS
	_navigation_mesh.agent_height = AGENT_HEIGHT
	_navigation_mesh.agent_max_climb = AGENT_MAX_CLIMB
	_navigation_mesh.agent_max_slope = AGENT_MAX_SLOPE
	_navigation_mesh.cell_size = CELL_SIZE
	_navigation_mesh.cell_height = CELL_HEIGHT
	_navigation_mesh.region_min_size = 8.0
	_navigation_mesh.region_merge_size = 20.0
	_navigation_mesh.edge_max_length = 12.0
	_navigation_mesh.edge_max_error = 1.3
	_navigation_mesh.detail_sample_distance = 6.0
	_navigation_mesh.detail_sample_max_error = 1.0
	_navigation_mesh.filter_low_hanging_obstacles = true
	_navigation_mesh.filter_ledge_spans = true
	_navigation_mesh.filter_walkable_low_height_spans = true
	_navigation_mesh.geometry_source_geometry_mode = (
		NavigationMesh.SOURCE_GEOMETRY_ROOT_NODE_CHILDREN
	)
	_navigation_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS


## Never changes agent geometry or retries with relaxed coverage requirements.
func bake_navigation_mesh(geometry_root: Node3D = null) -> bool:
	if _context == null or not is_instance_valid(_navigation_region) or _navigation_mesh == null:
		push_error("NavigationMeshBaker: Not initialized")
		return false
	_navigation_mesh.clear()
	var source_root: Node3D = geometry_root if geometry_root else _context.csg_root
	if not is_instance_valid(source_root) or not source_root.is_inside_tree():
		push_error("NavigationMeshBaker: Prepared collision geometry must be inside the scene tree")
		return false
	var source_geometry := NavigationMeshSourceGeometryData3D.new()
	_collect_collision_geometry(
		source_root, source_geometry, source_root.global_transform.affine_inverse()
	)
	if not source_geometry.has_data():
		push_error("NavigationMeshBaker: Source geometry is empty")
		return false
	NavigationServer3D.bake_from_source_geometry_data(_navigation_mesh, source_geometry)
	if _navigation_mesh.get_polygon_count() == 0:
		push_error("NavigationMeshBaker: No walkable navigation polygons generated")
		return false
	# Parsed vertices are source-local; the returned region is the source's sibling.
	_navigation_region.transform = source_root.transform
	return true


## CSG exposes CPU collision faces; its stock nav parser instead reads GPU meshes.
## Non-CSG prefab collision uses the engine's shape parsers, in the same local space.
func _collect_collision_geometry(
	node: Node, source: NavigationMeshSourceGeometryData3D, root_inverse: Transform3D
) -> void:
	# Moving doors retain physical collision, but must not permanently cut the baked floor.
	if node is AnimatableBody3D:
		return
	if node is CSGShape3D and node.is_root_shape() and node.use_collision:
		var collision: ConcavePolygonShape3D = node.bake_collision_shape()
		if collision:
			var faces := collision.get_faces()
			if not faces.is_empty():
				source.add_faces(faces, root_inverse * node.global_transform)
	if node is StaticBody3D:
		var parsed := NavigationMeshSourceGeometryData3D.new()
		NavigationServer3D.parse_source_geometry_data(_navigation_mesh, parsed, node)
		var vertices := parsed.get_vertices()
		var transform: Transform3D = root_inverse * node.global_transform
		for index in range(0, vertices.size(), 3):
			var point := (
				transform * Vector3(vertices[index], vertices[index + 1], vertices[index + 2])
			)
			vertices[index] = point.x
			vertices[index + 1] = point.y
			vertices[index + 2] = point.z
		source.append_arrays(vertices, parsed.get_indices())
		return
	for child: Node in node.get_children():
		_collect_collision_geometry(child, source, root_inverse)


func get_navigation_region() -> NavigationRegion3D:
	return _navigation_region


func get_navigation_mesh() -> NavigationMesh:
	return _navigation_mesh


## Query only this baked mesh, including when its region is detached.
func is_position_on_navmesh(position: Vector3) -> bool:
	if (
		not position.is_finite()
		or _navigation_mesh == null
		or _navigation_mesh.get_polygon_count() == 0
	):
		return false
	var map_rid := NavigationServer3D.map_create()
	var region_rid := NavigationServer3D.region_create()
	NavigationServer3D.map_set_use_async_iterations(map_rid, false)
	NavigationServer3D.region_set_use_async_iterations(region_rid, false)
	NavigationServer3D.map_set_cell_size(map_rid, _navigation_mesh.cell_size)
	NavigationServer3D.map_set_cell_height(map_rid, _navigation_mesh.cell_height)
	NavigationServer3D.region_set_navigation_mesh(region_rid, _navigation_mesh)
	var region_transform := _navigation_region.transform
	if _navigation_region.is_inside_tree():
		region_transform = _navigation_region.global_transform
	NavigationServer3D.region_set_transform(region_rid, region_transform)
	NavigationServer3D.region_set_map(region_rid, map_rid)
	NavigationServer3D.map_force_update(map_rid)
	var on_mesh := NavigationServer3D.map_get_closest_point_owner(map_rid, position).is_valid()
	if on_mesh:
		on_mesh = (
			position.distance_to(NavigationServer3D.map_get_closest_point(map_rid, position)) < 1.0
		)
	NavigationServer3D.free_rid(region_rid)
	NavigationServer3D.free_rid(map_rid)
	return on_mesh
