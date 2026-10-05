class_name ModPackageValidator
extends RefCounted

## Validates mod package manifests before they reach ModLoader.
## Errors are structural or dependency/override failures; disabled mods are warnings.

const REQUIRED_FIELDS: Array[String] = ["id", "name", "version"]
const CURRENT_MOD_API_VERSION: int = 1
const CURRENT_SAVE_VERSION: String = "1.0"
const IDENTIFIER_PATTERN: String = "^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$"
const VERSION_PATTERN: String = "^[0-9A-Za-z][0-9A-Za-z._+-]{0,63}$"
const REQUIRED_COMPATIBILITY_FIELDS: Array[String] = ["mod_api", "save_version"]
const OVERRIDE_SECTIONS: Array[String] = ["systems", "weapons", "enemies", "loot", "loot_tables"]


func _matches(pattern: String, value: String) -> bool:
	var regex := RegEx.new()
	regex.compile(pattern)
	return regex.search(value) != null


func validate_manifest(manifest: Dictionary, source: String = "<memory>") -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	for field in REQUIRED_FIELDS:
		if not manifest.has(field):
			errors.append("%s: missing required field '%s'" % [source, field])
			continue
		var value: Variant = manifest[field]
		if not value is String or value.strip_edges().is_empty():
			errors.append("%s: field '%s' must be a non-empty string" % [source, field])
	if (
		manifest.has("id")
		and manifest.id is String
		and not _matches(IDENTIFIER_PATTERN, manifest.id)
	):
		errors.append("%s: id must match %s" % [source, IDENTIFIER_PATTERN])
	if (
		manifest.has("version")
		and manifest.version is String
		and not _matches(VERSION_PATTERN, manifest.version)
	):
		errors.append("%s: version must be a simple release identifier" % source)

	if not manifest.has("compatibility") or not manifest.compatibility is Dictionary:
		errors.append("%s: compatibility must be an object" % source)
	else:
		var compatibility: Dictionary = manifest.compatibility
		for field in REQUIRED_COMPATIBILITY_FIELDS:
			if not compatibility.has(field):
				errors.append("%s: compatibility is missing '%s'" % [source, field])
		if (
			compatibility.has("mod_api")
			and (
				not (compatibility.mod_api is int or compatibility.mod_api is float)
				or float(compatibility.mod_api) != CURRENT_MOD_API_VERSION
			)
		):
			errors.append(
				"%s: compatibility.mod_api must be %d" % [source, CURRENT_MOD_API_VERSION]
			)
		if (
			compatibility.has("save_version")
			and (
				not compatibility.save_version is String
				or compatibility.save_version != CURRENT_SAVE_VERSION
			)
		):
			errors.append(
				"%s: compatibility.save_version must be '%s'" % [source, CURRENT_SAVE_VERSION]
			)

	if manifest.has("dependencies") and not manifest.dependencies is Array:
		errors.append("%s: dependencies must be an array" % source)
	elif manifest.has("dependencies"):
		for dependency in manifest.dependencies:
			if (
				not dependency is String
				or dependency.strip_edges().is_empty()
				or not _matches(IDENTIFIER_PATTERN, dependency)
			):
				errors.append("%s: dependencies must contain valid package ids" % source)
	if manifest.has("config_overrides") and not manifest.config_overrides is Dictionary:
		errors.append("%s: config_overrides must be an object" % source)
	if manifest.has("enabled") and not manifest.enabled is bool:
		errors.append("%s: enabled must be a boolean" % source)
	elif not manifest.get("enabled", false):
		warnings.append("%s: mod is disabled" % source)
	for field in ["scripts"]:
		if manifest.has(field) and not manifest[field] is Array:
			errors.append("%s: %s must be an array" % [source, field])
	for field in ["assets", "features", "components", "entities"]:
		if manifest.has(field) and not manifest[field] is Dictionary:
			errors.append("%s: %s must be an object" % [source, field])

	return {
		"source": source,
		"id": str(manifest.get("id", "")),
		"valid": errors.is_empty(),
		"errors": errors,
		"warnings": warnings
	}


func validate_packages(manifests: Array[Dictionary]) -> Dictionary:
	var results: Array[Dictionary] = []
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var package_ids: Dictionary = {}
	var overrides: Dictionary = {}

	for manifest in manifests:
		var source := str(manifest.get("id", "<unknown>"))
		var result := validate_manifest(manifest, source)
		results.append(result)
		errors.append_array(result.errors)
		warnings.append_array(result.warnings)
		if result.id != "":
			if package_ids.has(result.id):
				errors.append("duplicate package id '%s'" % result.id)
			else:
				package_ids[result.id] = true

	for manifest in manifests:
		var mod_id := str(manifest.get("id", "<unknown>"))
		var dependencies: Variant = manifest.get("dependencies", [])
		if dependencies is Array:
			for dependency in dependencies:
				if str(dependency) == mod_id:
					errors.append("%s: package cannot depend on itself" % mod_id)
				elif not package_ids.has(str(dependency)):
					errors.append("%s: missing dependency '%s'" % [mod_id, str(dependency)])
		if manifest.get("enabled", false) != true:
			continue
		var config_overrides: Dictionary = manifest.get("config_overrides", {})
		if not config_overrides is Dictionary:
			continue
		for section in OVERRIDE_SECTIONS:
			var section_data: Variant = config_overrides.get(section, {})
			if not section_data is Dictionary:
				continue
			for target in section_data.keys():
				var key := "%s.%s" % [section, str(target)]
				if overrides.has(key):
					errors.append(
						"override conflict on %s between %s and %s" % [key, overrides[key], mod_id]
					)
				else:
					overrides[key] = mod_id

	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"warnings": warnings,
		"packages": results,
		"override_owners": overrides
	}
