extends RefCounted
class_name FeatureAvailability

## Canonical runtime capability negotiation for generated and authored content.
## This object is the only local source of truth for optional runtime features.
const CAPABILITY_CONTRACT_VERSION := 1
const RUNTIME_ID := "modus"
const RUNTIME_VERSION := 1
const NATIVE_CAPABILITY_CLASSES := {
	"csg": "CSGShape3D",
	"multimesh": "MultiMesh",
	"occlusion_culling": "OccluderInstance3D",
	"voxel": "VoxelTerrain"
}
## Capabilities guaranteed by the stock offline path. Optional native features
## are added only when the current runtime exposes their native classes.
const COMMON_CAPABILITIES: Array[String] = ["walk", "csg"]
## FeatureAvailability
## Detects and manages graceful degradation for optional runtime features.
## Provides fallback mechanisms when optional dependencies are unavailable.

## Feature availability flags
var voxel_tools_available: bool = false
var advanced_geometry_available: bool = true
var multimesh_available: bool = true
var occlusion_culling_available: bool = true


func _init() -> void:
	_detect_native_features()
	_detect_voxel_tools()


## Initialize and detect all optional features.
func initialize(emit_log: bool = true) -> void:
	_detect_native_features()
	_detect_voxel_tools()
	if emit_log:
		_log_feature_availability()


func _detect_native_features() -> void:
	# These classes are built into stock Godot, but stripped/custom runtimes
	# must not be advertised as supporting them until ClassDB confirms them.
	advanced_geometry_available = ClassDB.class_exists("CSGShape3D")
	multimesh_available = ClassDB.class_exists("MultiMesh")
	occlusion_culling_available = ClassDB.class_exists("OccluderInstance3D")


func _detect_voxel_tools() -> void:
	# A script file alone cannot provide the native VoxelTerrain API. Only
	# advertise voxel support when the runtime can instantiate the class.
	voxel_tools_available = ClassDB.class_exists("VoxelTerrain")


## Log feature availability status
func _log_feature_availability() -> void:
	print("MapGenerator Feature Availability:")
	print(
		(
			"  - Voxel Tools: %s"
			% ("Available" if voxel_tools_available else "Not Available (using CSG fallback)")
		)
	)
	print(
		(
			"  - Advanced Geometry (CSG): %s"
			% ("Available" if advanced_geometry_available else "Unavailable")
		)
	)
	print("  - MultiMesh Batching: %s" % ("Available" if multimesh_available else "Unavailable"))
	print(
		(
			"  - Occlusion Culling: %s"
			% ("Available" if occlusion_culling_available else "Unavailable")
		)
	)


## Get cave generation method based on availability
func get_cave_generation_method() -> String:
	if voxel_tools_available:
		return "voxel"
	if advanced_geometry_available:
		return "csg"
	return "unavailable"


## Check if a feature or canonical capability is available
func is_feature_available(feature_name: String) -> bool:
	match feature_name:
		"voxel_tools", "voxel":
			return voxel_tools_available
		"advanced_geometry", "csg":
			return advanced_geometry_available
		"multimesh":
			return multimesh_available
		"occlusion_culling":
			return occlusion_culling_available
		"walk":
			return true
		_:
			push_warning("Unknown feature: %s" % feature_name)
			return false


## Return the detected runtime feature and capability state.
func get_capability_snapshot() -> Dictionary:
	return {
		"contract_version": CAPABILITY_CONTRACT_VERSION,
		"runtime": {"id": RUNTIME_ID, "version": RUNTIME_VERSION},
		"voxel_tools": voxel_tools_available,
		"advanced_geometry": advanced_geometry_available,
		"multimesh": multimesh_available,
		"occlusion_culling": occlusion_culling_available,
		"native_classes": get_native_capability_classes(),
		"available_capabilities": get_available_capabilities()
	}


## Return the immutable runtime identity and native class contract.
func get_runtime_contract() -> Dictionary:
	return {
		"contract_version": CAPABILITY_CONTRACT_VERSION,
		"runtime": {"id": RUNTIME_ID, "version": RUNTIME_VERSION},
		"native_classes": get_native_capability_classes(),
		"capabilities": get_available_capabilities()
	}


func get_native_capability_classes() -> Dictionary:
	var classes: Dictionary = {}
	for capability: String in NATIVE_CAPABILITY_CLASSES:
		classes[capability] = NATIVE_CAPABILITY_CLASSES[capability]
	return classes


func get_available_capabilities() -> Array[String]:
	var capabilities: Array[String] = ["walk"]
	if advanced_geometry_available:
		capabilities.append("csg")
	if multimesh_available:
		capabilities.append("multimesh")
	if occlusion_culling_available:
		capabilities.append("occlusion_culling")
	if voxel_tools_available:
		capabilities.append("voxel")
	capabilities.sort()
	return capabilities


## Build the versioned manifest embedded in generated/authored content.
func create_capability_manifest(
	required_capabilities: Variant = [], fallback_policy: Variant = {}
) -> Dictionary:
	var required := _normalize_capabilities(required_capabilities)
	var policy: Dictionary = {}
	if fallback_policy is Dictionary:
		for capability: Variant in fallback_policy:
			if capability is String and fallback_policy[capability] is String:
				policy[capability] = fallback_policy[capability]
	return {
		"contract_version": CAPABILITY_CONTRACT_VERSION,
		"runtime": {"id": RUNTIME_ID, "version": RUNTIME_VERSION},
		"runtime_id": RUNTIME_ID,
		"runtime_version": RUNTIME_VERSION,
		"required_capabilities": required,
		"available_capabilities": get_available_capabilities(),
		"fallback_policy": policy
	}


func get_capability_manifest(
	required_capabilities: Variant = [], fallback_policy: Variant = {}
) -> Dictionary:
	return create_capability_manifest(required_capabilities, fallback_policy)


## Validate content or peer capabilities without mutating or partially loading it.
## The result shape is stable for UI, session admission, and diagnostics.
func validate_capability_manifest(manifest: Variant) -> Dictionary:
	var result := {"success": false, "error": "", "missing": [], "fallback": []}
	if not manifest is Dictionary:
		result.error = "Capability manifest is malformed: expected an object."
		return result
	if manifest.get("contract_version") != CAPABILITY_CONTRACT_VERSION:
		result.error = "Capability manifest is malformed: unsupported contract version."
		return result
	var runtime: Variant = manifest.get("runtime")
	if (
		not runtime is Dictionary
		or not runtime.get("id") is String
		or not _is_integer_number(runtime.get("version"))
	):
		result.error = "Capability manifest is malformed: runtime identity is required."
		return result
	if (
		manifest.get("runtime_id", RUNTIME_ID) != RUNTIME_ID
		or manifest.get("runtime_version", RUNTIME_VERSION) != RUNTIME_VERSION
		or runtime.id != RUNTIME_ID
		or runtime.version != RUNTIME_VERSION
	):
		result.error = (
			"Runtime capability mismatch: expected %s@%d, received %s@%s."
			% [
				RUNTIME_ID,
				RUNTIME_VERSION,
				str(manifest.get("runtime_id", runtime.get("id", ""))),
				str(manifest.get("runtime_version", runtime.get("version", "")))
			]
		)
		return result
	var required: Variant = manifest.get("required_capabilities")
	if not (required is Array or required is PackedStringArray):
		result.error = "Capability manifest is malformed: required_capabilities must be an array."
		return result
	var normalized := _normalize_capabilities(required)
	if normalized.size() != required.size():
		result.error = "Capability manifest is malformed: capabilities must be non-empty strings."
		return result
	var policy: Variant = manifest.get("fallback_policy", {})
	if not policy is Dictionary:
		result.error = "Capability manifest is malformed: fallback_policy must be an object."
		return result
	for capability: Variant in policy:
		if not capability is String or not policy[capability] is String:
			result.error = "Capability manifest is malformed: fallback policy entries must be strings."
			return result
	var available := get_available_capabilities()
	var missing: Array[String] = []
	for capability: String in normalized:
		if capability not in available and capability not in missing:
			missing.append(capability)
	missing.sort()
	var fallback: Array[String] = []
	for capability: String in missing:
		# A voxel requirement is never downgraded to CSG. Keep the suggestion
		# explicit so callers can explain the bounded alternative to users.
		if capability == "voxel":
			fallback.append("csg")
		elif policy.has(capability) and str(policy[capability]) != "reject":
			fallback.append(str(policy[capability]))
	result.missing = missing
	result.fallback = fallback
	if not missing.is_empty():
		result.error = (
			"Missing required capabilities: %s. Suggested fallback: %s."
			% [", ".join(missing), ", ".join(fallback) if not fallback.is_empty() else "none"]
		)
		return result
	result.success = true
	return result


func validate_manifest(manifest: Variant) -> Dictionary:
	return validate_capability_manifest(manifest)


## Negotiate a required set against this runtime and return its full manifest.
func negotiate_capabilities(
	required_capabilities: Variant, fallback_policy: Variant = {}
) -> Dictionary:
	var manifest := create_capability_manifest(required_capabilities, fallback_policy)
	var result := validate_capability_manifest(manifest)
	result["manifest"] = manifest
	return result


func _is_integer_number(value: Variant) -> bool:
	return value is int or (value is float and is_finite(value) and value == floor(value))


func _normalize_capabilities(value: Variant) -> Array[String]:
	var normalized: Array[String] = []
	if not (value is Array or value is PackedStringArray):
		return normalized
	for capability: Variant in value:
		if not capability is String or capability.is_empty() or capability in normalized:
			continue
		normalized.append(capability)
	normalized.sort()
	return normalized


## Get fallback method for a feature
func get_fallback_method(feature_name: String) -> String:
	match feature_name:
		"voxel_tools":
			return "csg_geometry"
		"advanced_geometry":
			return "basic_geometry"
		"multimesh":
			return "individual_instances"
		"occlusion_culling":
			return "no_culling"
		_:
			return "none"


## Handle missing prefab gracefully
func handle_missing_prefab(prefab_path: String, context: RefCounted) -> bool:
	push_warning("MapGenerator: Prefab not found: %s (skipping)" % prefab_path)

	# Track skipped prefabs in context
	if context and context.has("skipped_prefabs"):
		context.skipped_prefabs.append(
			{"path": prefab_path, "reason": "File not found", "timestamp": Time.get_ticks_msec()}
		)

	return false  # Prefab cannot be loaded


## Handle invalid prefab metadata gracefully
func handle_invalid_prefab_metadata(
	prefab_path: String, error: String, context: RefCounted
) -> bool:
	push_warning(
		"MapGenerator: Invalid prefab metadata for '%s': %s (skipping)" % [prefab_path, error]
	)

	# Track skipped prefabs in context
	if context and context.has("skipped_prefabs"):
		context.skipped_prefabs.append(
			{
				"path": prefab_path,
				"reason": "Invalid metadata: %s" % error,
				"timestamp": Time.get_ticks_msec()
			}
		)

	return false  # Prefab cannot be used


## Handle missing theme gracefully
func handle_missing_theme(theme_name: String, context: RefCounted) -> String:
	push_warning("MapGenerator: Theme '%s' not found, using default 'tech' theme" % theme_name)

	# Track theme fallback in context
	if context and context.has("metadata"):
		if not context.metadata.has("fallbacks"):
			context.metadata["fallbacks"] = []
		context.metadata["fallbacks"].append(
			{
				"type": "theme",
				"requested": theme_name,
				"fallback": "tech",
				"timestamp": Time.get_ticks_msec()
			}
		)

	return "tech"  # Default fallback theme


## Handle navigation mesh baking failure gracefully
func handle_navmesh_baking_failure(error: String, context: RefCounted) -> bool:
	push_error("MapGenerator: Navigation mesh baking failed: %s" % error)

	# Track failure in context
	if context and context.has("metadata"):
		if not context.metadata.has("warnings"):
			context.metadata["warnings"] = []
		context.metadata["warnings"].append(
			{"type": "navmesh_baking_failed", "error": error, "timestamp": Time.get_ticks_msec()}
		)

	# Navigation mesh is critical - return false to indicate failure
	return false


## Handle CSG baking failure gracefully
func handle_csg_baking_failure(error: String, context: RefCounted) -> bool:
	push_warning("MapGenerator: CSG baking failed: %s (using unbaked CSG)" % error)

	# Track warning in context
	if context and context.has("metadata"):
		if not context.metadata.has("warnings"):
			context.metadata["warnings"] = []
		context.metadata["warnings"].append(
			{
				"type": "csg_baking_failed",
				"error": error,
				"fallback": "unbaked_csg",
				"timestamp": Time.get_ticks_msec()
			}
		)

	# CSG baking is optional - can continue with unbaked CSG
	return true


## Handle LOD generation failure gracefully
func handle_lod_generation_failure(error: String, context: RefCounted) -> bool:
	push_warning("MapGenerator: LOD generation failed: %s (disabling LOD)" % error)

	# Track warning in context
	if context and context.has("metadata"):
		if not context.metadata.has("warnings"):
			context.metadata["warnings"] = []
		context.metadata["warnings"].append(
			{
				"type": "lod_generation_failed",
				"error": error,
				"fallback": "no_lod",
				"timestamp": Time.get_ticks_msec()
			}
		)

	# LOD is optional - can continue without it
	return true


## Handle MultiMesh batching failure gracefully
func handle_multimesh_failure(error: String, context: RefCounted) -> bool:
	push_warning("MapGenerator: MultiMesh batching failed: %s (using individual instances)" % error)

	# Track warning in context
	if context and context.has("metadata"):
		if not context.metadata.has("warnings"):
			context.metadata["warnings"] = []
		context.metadata["warnings"].append(
			{
				"type": "multimesh_failed",
				"error": error,
				"fallback": "individual_instances",
				"timestamp": Time.get_ticks_msec()
			}
		)

	# MultiMesh is optional - can continue with individual instances
	return true


## Handle occlusion culling failure gracefully
func handle_occlusion_culling_failure(error: String, context: RefCounted) -> bool:
	push_warning("MapGenerator: Occlusion culling failed: %s (disabling occlusion)" % error)

	# Track warning in context
	if context and context.has("metadata"):
		if not context.metadata.has("warnings"):
			context.metadata["warnings"] = []
		context.metadata["warnings"].append(
			{
				"type": "occlusion_culling_failed",
				"error": error,
				"fallback": "no_occlusion",
				"timestamp": Time.get_ticks_msec()
			}
		)

	# Occlusion culling is optional - can continue without it
	return true


## Create feature availability report
func create_availability_report() -> Dictionary:
	return {
		"contract_version": CAPABILITY_CONTRACT_VERSION,
		"runtime": {"id": RUNTIME_ID, "version": RUNTIME_VERSION},
		"capabilities": get_available_capabilities(),
		"native_classes": get_native_capability_classes(),
		"voxel_tools":
		{
			"available": voxel_tools_available,
			"fallback":
			(
				("csg_geometry" if advanced_geometry_available else "unavailable")
				if not voxel_tools_available
				else "none"
			)
		},
		"advanced_geometry":
		{
			"available": advanced_geometry_available,
			"fallback": "unavailable" if not advanced_geometry_available else "none"
		},
		"multimesh":
		{
			"available": multimesh_available,
			"fallback": "individual_instances" if not multimesh_available else "none"
		},
		"occlusion_culling":
		{
			"available": occlusion_culling_available,
			"fallback": "no_occlusion" if not occlusion_culling_available else "none"
		}
	}


## Get recommended configuration based on feature availability
func get_recommended_config() -> Dictionary:
	var config := {}

	# Recommend disabling features that aren't available.
	if not voxel_tools_available:
		config["cave_bias"] = 0.0
		config["cave_generation_note"] = "Using CSG fallback (Voxel Tools not available)"
	if not multimesh_available:
		config["use_multimesh"] = false
	if not occlusion_culling_available:
		config["enable_occlusion_culling"] = false
	if not advanced_geometry_available:
		config["geometry_generation_note"] = "CSG runtime capability is unavailable"

	return config
