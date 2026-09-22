@tool
class_name PlacementPreview
extends Node3D

signal placement_confirmed(position: Vector3, rotation: float, scale: Vector3)
signal placement_cancelled

const VALID_COLOR := Color(0.2, 0.8, 0.3, 0.5)  # Green, semi-transparent
const INVALID_COLOR := Color(0.9, 0.2, 0.2, 0.5)  # Red, semi-transparent
const NEUTRAL_COLOR := Color(0.5, 0.5, 0.5, 0.5)  # Gray, semi-transparent

var is_active: bool = false
var preview_node: Node3D = null
var preview_material: StandardMaterial3D
var preview_position: Vector3 = Vector3.ZERO
var preview_rotation: float = 0.0
var preview_scale: Vector3 = Vector3.ONE
var is_valid_placement: bool = true
var surface_offset: float = 0.0
var grid_system: Node = null
var snap_to_grid: bool = true


func _ready() -> void:
	_create_preview_material()


func _create_preview_material() -> void:
	preview_material = StandardMaterial3D.new()
	preview_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	preview_material.albedo_color = VALID_COLOR
	preview_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	preview_material.no_depth_test = true
	preview_material.render_priority = 10


## Setup with grid system reference


func setup(grid: Node = null) -> void:
	grid_system = grid


## Start preview with a mesh/scene


func start_preview(template: Variant) -> void:
	clear_preview()

	if template is PackedScene:
		preview_node = _create_scene_visuals(template.get_state())
	elif template is Mesh:
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.mesh = template
		preview_node = mesh_instance
	elif template is Node3D:
		preview_node = _copy_node_visuals(template)
	elif template is Dictionary:
		# Asset dictionary - create appropriate preview
		preview_node = _create_preview_from_asset(template)
	else:
		push_warning("[PlacementPreview] Unknown template type: %s" % typeof(template))
		return

	if preview_material == null:
		_create_preview_material()
	if preview_node:
		# Visual-only nodes have no owners, scripts, groups, signals or physics.
		_apply_preview_material_recursive(preview_node)
		add_child(preview_node)
		is_active = true
		_update_preview_transform()


## Create preview from asset dictionary


func _create_preview_from_asset(asset: Dictionary) -> Node3D:
	var asset_type: String = asset.get("type", "")

	match asset_type:
		"block", "csg":
			# Create CSG box preview
			var box := CSGBox3D.new()
			box.size = asset.get("size", Vector3.ONE)
			return box

		"spawn_point":
			# Create a simple marker
			var marker := Node3D.new()

			# Cylinder body
			var body := CSGCylinder3D.new()
			body.radius = 0.3
			body.height = 1.8
			marker.add_child(body)

			# Arrow indicator
			var arrow := CSGBox3D.new()
			arrow.size = Vector3(0.1, 0.1, 0.5)
			arrow.position = Vector3(0, 0.9, 0.3)
			marker.add_child(arrow)

			return marker

		"scene":
			# Load and instantiate scene
			var scene_path: String = asset.get("scene_path", "")
			if ResourceLoader.exists(scene_path):
				var scene: PackedScene = load(scene_path)
				if scene:
					return _create_scene_visuals(scene.get_state())

		_:
			# Default: simple cube
			var default_box := CSGBox3D.new()
			default_box.size = Vector3.ONE
			return default_box

	return null


## Read serialized visuals without instantiate(): even a script's _init must not run.
func _create_scene_visuals(state: SceneState) -> Node3D:
	var root: Node3D = null
	var base := state.get_base_scene_state()
	if base:
		root = _create_scene_visuals(base)
	for index in state.get_node_count():
		var path := state.get_node_path(index)
		var node: Node3D = root.get_node_or_null(path) as Node3D if root else null
		if node == null:
			var scene := state.get_node_instance(index)
			node = (
				_create_scene_visuals(scene.get_state())
				if scene else _create_visual_node(state.get_node_type(index))
			)
			node.name = state.get_node_name(index)
			if root == null:
				root = node
			else:
				var parent := root.get_node_or_null(state.get_node_path(index, true))
				if parent == null:
					node.free()
					continue
				parent.add_child(node)
		for property_index in state.get_node_property_count(index):
			_set_visual_property(
				node, state.get_node_property_name(index, property_index),
				state.get_node_property_value(index, property_index)
			)
	return root


func _create_visual_node(native_type: StringName) -> Node3D:
	if (
		native_type in [&"MeshInstance3D", &"MultiMeshInstance3D", &"Path3D"]
		or ClassDB.is_parent_class(native_type, &"CSGShape3D")
	):
		if ClassDB.can_instantiate(native_type):
			return ClassDB.instantiate(native_type) as Node3D
	return Node3D.new()


func _copy_node_visuals(source: Node) -> Node3D:
	var visual := _create_visual_node(source.get_class())
	visual.name = source.name
	for property in ClassDB.class_get_property_list(source.get_class()):
		var property_name: StringName = property.name
		if _is_visual_property(visual, property_name):
			visual.set(property_name, source.get(property_name))
	for child in source.get_children():
		visual.add_child(_copy_node_visuals(child))
	return visual


func _set_visual_property(node: Node3D, property: StringName, value: Variant) -> void:
	if _is_visual_property(node, property):
		node.set(property, value)


func _is_visual_property(node: Node3D, property: StringName) -> bool:
	if property in [
		&"transform", &"position", &"rotation", &"rotation_degrees", &"scale", &"visible"
	]:
		return true
	if node is MeshInstance3D:
		return property == &"mesh"
	if node is MultiMeshInstance3D:
		return property == &"multimesh"
	if node is Path3D:
		return property == &"curve"
	if node is CSGShape3D:
		# Geometry only: deliberately exclude use_collision and collision layers.
		return property in [
			&"operation", &"snap", &"calculate_tangents", &"flip_faces", &"mesh",
			&"size", &"radius", &"height", &"sides", &"cone", &"smooth_faces",
			&"inner_radius", &"outer_radius", &"ring_sides", &"polygon", &"mode",
			&"depth", &"spin_degrees", &"spin_sides", &"path_node", &"path_interval",
			&"path_simplify_angle", &"path_rotation", &"path_local", &"path_continuous_u",
			&"path_u_distance", &"path_joined",
		]
	return false


## Apply transparent material to all meshes


func _apply_preview_material_recursive(node: Node) -> void:
	node.process_mode = Node.PROCESS_MODE_DISABLED
	if node is GeometryInstance3D:
		node.material_override = preview_material
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if node is CSGShape3D:
		node.use_collision = false

	for child: Node in node.get_children():
		_apply_preview_material_recursive(child)


## Update preview position from world coordinates


func update_position(world_pos: Vector3) -> void:
	if not is_active:
		return

	# Apply grid snapping
	if snap_to_grid and grid_system:
		preview_position = grid_system.snap_to_grid(world_pos)
	else:
		preview_position = world_pos

	# Apply surface offset
	preview_position.y += surface_offset

	_update_preview_transform()


## Update preview from raycast result


func update_from_raycast(from: Vector3, direction: Vector3, _camera: Camera3D) -> void:
	if not is_active:
		return

	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	if not space_state:
		return

	var ray_length: float = 100.0
	var query := PhysicsRayQueryParameters3D.create(from, from + direction * ray_length)
	query.collision_mask = 0xFFFFFFFF  # All layers
	query.exclude = _get_preview_bodies()

	var result: Dictionary = space_state.intersect_ray(query)

	if result:
		var hit_pos: Vector3 = result.position
		var hit_normal: Vector3 = result.normal

		# Offset along normal for surface placement
		var offset_pos: Vector3 = hit_pos + hit_normal * surface_offset

		update_position(offset_pos)

		# Check for collisions at placement position
		is_valid_placement = _check_placement_valid()
	else:
		# No hit - place at default distance
		var default_distance: float = 5.0
		update_position(from + direction * default_distance)
		is_valid_placement = true


## Get physics bodies in preview (to exclude from raycast)


func _get_preview_bodies() -> Array[RID]:
	var bodies: Array[RID] = []
	if preview_node:
		_collect_bodies_recursive(preview_node, bodies)
	return bodies


func _collect_bodies_recursive(node: Node, bodies: Array[RID]) -> void:
	if node is CollisionObject3D:
		bodies.append(node.get_rid())
	for child: Node in node.get_children():
		_collect_bodies_recursive(child, bodies)


## Check if current placement position is valid


func _check_placement_valid() -> bool:
	if not preview_node:
		return true

	# Get AABB of preview
	var aabb: AABB = _get_preview_aabb()
	if aabb.size == Vector3.ZERO:
		return true

	# Simple overlap check using shape query
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	if not space_state:
		return true

	# Create box shape for overlap test
	var shape := BoxShape3D.new()
	shape.size = aabb.size * 0.9  # Slightly smaller to avoid edge cases

	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = shape
	var offset: Vector3 = aabb.position + aabb.size * 0.5
	params.transform = Transform3D(Basis.IDENTITY, preview_position + offset)
	params.collision_mask = 0xFFFFFFFF
	params.exclude = _get_preview_bodies()

	var results: Array[Dictionary] = space_state.intersect_shape(params, 1)

	return results.is_empty()


## Get AABB of preview node


func _get_preview_aabb() -> AABB:
	if not preview_node:
		return AABB()
	return _collect_aabb_recursive(preview_node)


func _collect_aabb_recursive(node: Node) -> AABB:
	var combined := AABB()
	var has_bounds := false
	if node is VisualInstance3D:
		combined = (node as VisualInstance3D).get_aabb()
		has_bounds = combined.size != Vector3.ZERO
	for child: Node in node.get_children():
		var child_bounds := _collect_aabb_recursive(child)
		if child_bounds.size == Vector3.ZERO:
			continue
		child_bounds = child.transform * child_bounds
		combined = child_bounds if not has_bounds else combined.merge(child_bounds)
		has_bounds = true
	return combined


## Rotate preview


func rotate_preview(degrees: float = 90.0) -> void:
	preview_rotation = wrapf(preview_rotation + deg_to_rad(degrees), 0, TAU)
	_update_preview_transform()


## Fine rotate preview (smaller increments)


func fine_rotate_preview(degrees: float = 15.0) -> void:
	rotate_preview(degrees)


## Scale preview


func scale_preview(factor: Vector3) -> void:
	preview_scale *= factor
	preview_scale = preview_scale.clampf(0.1, 10.0)
	_update_preview_transform()


## Reset scale


func reset_scale() -> void:
	preview_scale = Vector3.ONE
	_update_preview_transform()


## Update visual transform


## Apply an externally solved placement transform, such as a module socket pose.
func set_preview_transform(transform: Transform3D, valid: bool = true) -> void:
	if not is_active or not preview_node:
		return
	preview_position = transform.origin
	preview_rotation = transform.basis.get_euler().y
	preview_scale = transform.basis.get_scale()
	preview_node.global_transform = transform
	is_valid_placement = valid
	_update_preview_color()


func _update_preview_transform() -> void:
	if not preview_node:
		return

	preview_node.position = preview_position
	preview_node.rotation.y = preview_rotation
	preview_node.scale = preview_scale


## Update preview color based on validity


func _update_preview_color() -> void:
	if not preview_material:
		return

	preview_material.albedo_color = VALID_COLOR if is_valid_placement else INVALID_COLOR


## Confirm placement


func confirm_placement() -> Dictionary:
	if not is_active or not is_valid_placement:
		return {}

	var result := {
		"position": preview_position,
		"rotation": preview_rotation,
		"scale": preview_scale,
		"valid": is_valid_placement
	}

	placement_confirmed.emit(preview_position, preview_rotation, preview_scale)

	return result


## Cancel and clear preview


func cancel_preview() -> void:
	clear_preview()
	placement_cancelled.emit()


## Clear preview node


func clear_preview() -> void:
	if preview_node:
		preview_node.hide()
		remove_child(preview_node)
		preview_node.queue_free()
		preview_node = null

	is_active = false
	preview_position = Vector3.ZERO
	preview_rotation = 0.0
	preview_scale = Vector3.ONE
	is_valid_placement = true


## Set surface offset


func set_surface_offset(offset: float) -> void:
	surface_offset = offset


## Toggle grid snapping


func set_snap_to_grid(enabled: bool) -> void:
	snap_to_grid = enabled


## Get current preview data


func get_preview_data() -> Dictionary:
	return {
		"is_active": is_active,
		"position": preview_position,
		"rotation": preview_rotation,
		"scale": preview_scale,
		"is_valid": is_valid_placement
	}
