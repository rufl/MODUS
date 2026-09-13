class_name PrefabMetadata
extends Resource

## Metadata for prefab placement in generated maps
## Defines dimensions, anchor points, theme requirements, and placement rules

@export var module_id: String = ""
@export_file("*.tscn") var scene_path: String = ""
@export var content_revision: int = 1
@export var sockets: Array[Dictionary] = []
@export var required_capabilities: PackedStringArray = []

@export var dimensions: Vector3 = Vector3.ZERO  # Bounding box size
@export var anchor_points: Array[Vector3] = []  # Snap points for placement
@export var required_theme: GenerationConfig.ThemeType = GenerationConfig.ThemeType.TECH
@export var density_weight: float = 1.0  # Multiplier for density calculations
@export var tags: Array[String] = []  # Categories: "prop", "furniture", "cover", etc.
@export var collision_radius: float = 0.5  # For spatial constraint checking
@export var placement_rules: Dictionary = {}  # Custom placement constraints


## Validate that the metadata has all required fields
func is_valid() -> bool:
	if not dimensions.is_finite() or dimensions.x <= 0 or dimensions.y <= 0 or dimensions.z <= 0:
		return false
	if module_id.is_empty():
		return sockets.is_empty()
	if scene_path.is_empty() or content_revision < 1 or "/" in module_id:
		return false
	var ids := {}
	for socket in sockets:
		if not socket.get("id") is String or socket.id.is_empty() or "/" in socket.id:
			return false
		if ids.has(socket.id) or not socket.get("kind", "walk") is String:
			return false
		ids[socket.id] = true
		if socket.get("kind", "walk").is_empty():
			return false
		if not socket.get("local_transform") is Transform3D:
			return false
		if not socket.get("opening") is Vector2 or not socket.get("clearance") is AABB:
			return false
		var pose: Transform3D = socket.local_transform
		var opening: Vector2 = socket.opening
		var clearance: AABB = socket.clearance
		if not pose.is_finite() or not opening.is_finite() or opening.x <= 0 or opening.y <= 0:
			return false
		if not clearance.position.is_finite() or not clearance.size.is_finite():
			return false
		if clearance.size.x <= 0 or clearance.size.y <= 0 or clearance.size.z <= 0:
			return false
	return true


## Parse JSON metadata from a dictionary
## Returns a PrefabMetadata object or null if parsing fails
static func from_dict(data: Dictionary) -> PrefabMetadata:
	var metadata := PrefabMetadata.new()
	metadata.module_id = str(data.get("module_id", ""))
	metadata.scene_path = str(data.get("scene_path", ""))
	metadata.content_revision = int(data.get("content_revision", 1))
	var capabilities: Variant = data.get("required_capabilities", [])
	if not capabilities is Array:
		return null
	for capability: Variant in capabilities:
		if not capability is String:
			return null
		metadata.required_capabilities.append(capability)
	var socket_data: Variant = data.get("sockets", [])
	if not socket_data is Array:
		return null
	for entry: Variant in socket_data:
		if not entry is Dictionary:
			return null
		var pose: Variant = entry.get("local_transform")
		var opening: Variant = entry.get("opening")
		var clearance: Variant = entry.get("clearance")
		if not pose is Dictionary or not clearance is Dictionary:
			return null
		var axes: Variant = pose.get("basis")
		if not axes is Array or axes.size() != 3 or not _is_vector(pose.get("origin"), 3):
			return null
		for axis: Variant in axes:
			if not _is_vector(axis, 3):
				return null
		if not _is_vector(opening, 2):
			return null
		if not _is_vector(clearance.get("position"), 3) or not _is_vector(clearance.get("size"), 3):
			return null
		metadata.sockets.append(
			{
				"id": entry.get("id", ""),
				"kind": entry.get("kind", "walk"),
				"local_transform":
				Transform3D(
					Basis(_vector3(axes[0]), _vector3(axes[1]), _vector3(axes[2])),
					_vector3(pose.origin)
				),
				"opening": Vector2(opening[0], opening[1]),
				"clearance": AABB(_vector3(clearance.position), _vector3(clearance.size))
			}
		)

	# Parse dimensions (required)
	if not data.has("dimensions"):
		push_error("PrefabMetadata: Missing required field 'dimensions'")
		return null

	var dims: Variant = data["dimensions"]
	if _is_vector(dims, 3):
		metadata.dimensions = Vector3(dims[0], dims[1], dims[2])
	else:
		push_error("PrefabMetadata: Invalid 'dimensions' format, expected array of 3 numbers")
		return null

	# Legacy prop metadata still requires anchors; modules use sockets instead.
	if not data.has("anchor_points") and metadata.module_id.is_empty():
		push_error("PrefabMetadata: Missing required field 'anchor_points'")
		return null

	var anchors: Variant = data.get("anchor_points", [])
	if anchors is Array:
		for anchor: Variant in anchors:
			if _is_vector(anchor, 3):
				metadata.anchor_points.append(Vector3(anchor[0], anchor[1], anchor[2]))
			else:
				push_error(
					"PrefabMetadata: Invalid anchor point format, " + "expected array of 3 numbers"
				)
				return null
	else:
		push_error("PrefabMetadata: Invalid 'anchor_points' format, expected array")
		return null

	# Parse required_theme (required)
	if not data.has("required_theme") and metadata.module_id.is_empty():
		push_error("PrefabMetadata: Missing required field 'required_theme'")
		return null

	var theme_str: String = str(data.get("required_theme", "tech"))
	match theme_str.to_lower():
		"tech":
			metadata.required_theme = GenerationConfig.ThemeType.TECH
		"hell":
			metadata.required_theme = GenerationConfig.ThemeType.HELL
		"urban":
			metadata.required_theme = GenerationConfig.ThemeType.URBAN
		"cave":
			metadata.required_theme = GenerationConfig.ThemeType.CAVE
		"jumbled", "shared":
			metadata.required_theme = GenerationConfig.ThemeType.JUMBLED
		_:
			push_error(
				(
					"PrefabMetadata: Invalid theme '%s', expected tech/hell/urban/cave/jumbled"
					% theme_str
				)
			)
			return null

	# Parse optional fields with defaults
	metadata.density_weight = data.get("density_weight", 1.0)

	# Parse tags (optional, default to empty array)
	if data.has("tags"):
		var tags_data: Variant = data["tags"]
		if tags_data is Array:
			for tag: Variant in tags_data:
				if tag is String:
					metadata.tags.append(tag)
		else:
			push_warning("PrefabMetadata: Invalid 'tags' format, expected array of strings")

	# Parse collision_radius (optional, default to 0.5)
	metadata.collision_radius = data.get("collision_radius", 0.5)

	# Parse placement_rules (optional, default to empty dictionary)
	if data.has("placement_rules"):
		var rules: Variant = data["placement_rules"]
		if rules is Dictionary:
			metadata.placement_rules = rules
		else:
			push_warning(
				"PrefabMetadata: Invalid 'placement_rules' format, " + "expected dictionary"
			)

	if not metadata.is_valid():
		return null
	return metadata


## Parse JSON metadata from a file path
## Returns a PrefabMetadata object or null if parsing fails
static func from_file(file_path: String) -> PrefabMetadata:
	if not FileAccess.file_exists(file_path):
		push_error("PrefabMetadata: File not found: %s" % file_path)
		return null

	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_error(
			(
				"PrefabMetadata: Failed to open file: %s (Error: %d)"
				% [file_path, FileAccess.get_open_error()]
			)
		)
		return null

	var json_text := file.get_as_text()
	file.close()

	var json := JSON.new()
	var parse_result := json.parse(json_text)

	if parse_result != OK:
		push_error(
			(
				"PrefabMetadata: JSON parse error in %s at line %d: %s"
				% [file_path, json.get_error_line(), json.get_error_message()]
			)
		)
		return null

	var data: Variant = json.data
	if not data is Dictionary:
		push_error("PrefabMetadata: Expected JSON object in %s" % file_path)
		return null

	return from_dict(data)


## Convert metadata to a dictionary for JSON export
func to_dict() -> Dictionary:
	var data := {}
	data["module_id"] = module_id
	data["scene_path"] = scene_path
	data["content_revision"] = content_revision
	data["required_capabilities"] = Array(required_capabilities)
	var socket_data: Array[Dictionary] = []
	for socket in sockets:
		var pose: Transform3D = socket.local_transform
		var opening: Vector2 = socket.opening
		var clearance: AABB = socket.clearance
		socket_data.append(
			{
				"id": socket.id,
				"kind": socket.get("kind", "walk"),
				"local_transform":
				{
					"basis": [_array3(pose.basis.x), _array3(pose.basis.y), _array3(pose.basis.z)],
					"origin": _array3(pose.origin)
				},
				"opening": [opening.x, opening.y],
				"clearance":
				{"position": _array3(clearance.position), "size": _array3(clearance.size)}
			}
		)
	data["sockets"] = socket_data

	# Export dimensions
	data["dimensions"] = [dimensions.x, dimensions.y, dimensions.z]

	# Export anchor_points
	var anchors := []
	for anchor in anchor_points:
		anchors.append([anchor.x, anchor.y, anchor.z])
	data["anchor_points"] = anchors

	# Export required_theme
	match required_theme:
		GenerationConfig.ThemeType.TECH:
			data["required_theme"] = "tech"
		GenerationConfig.ThemeType.HELL:
			data["required_theme"] = "hell"
		GenerationConfig.ThemeType.URBAN:
			data["required_theme"] = "urban"
		GenerationConfig.ThemeType.CAVE:
			data["required_theme"] = "cave"
		GenerationConfig.ThemeType.JUMBLED:
			data["required_theme"] = "jumbled"

	# Export optional fields
	data["density_weight"] = density_weight
	data["tags"] = tags.duplicate()
	data["collision_radius"] = collision_radius
	data["placement_rules"] = placement_rules.duplicate()

	return data


## Pretty print metadata to JSON string
func to_json_string(indent: String = "\t") -> String:
	return JSON.stringify(to_dict(), indent)


## Save metadata to a file
func save_to_file(file_path: String) -> bool:
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		push_error(
			(
				"PrefabMetadata: Failed to open file for writing: %s (Error: %d)"
				% [file_path, FileAccess.get_open_error()]
			)
		)
		return false

	file.store_string(to_json_string())
	file.close()
	return true


static func _is_vector(value: Variant, count: int) -> bool:
	if not value is Array or value.size() != count:
		return false
	for component: Variant in value:
		if not (component is float or component is int) or not is_finite(float(component)):
			return false
	return true


static func _vector3(value: Array) -> Vector3:
	return Vector3(value[0], value[1], value[2])


static func _array3(value: Vector3) -> Array:
	return [value.x, value.y, value.z]
