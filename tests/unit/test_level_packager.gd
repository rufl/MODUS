extends ModusGutTestBase

const LevelPackagerScript = preload("res://shared/editor_core/data/level_packager.gd")


func test_package_rejects_manifest_paths_outside_package() -> void:
	var level := Node3D.new()
	add_child_autofree(level)

	var traversal_manifest := LevelPackagerScript.LevelManifest.new()
	traversal_manifest.id = "path_traversal"
	traversal_manifest.name = "Path Traversal"
	traversal_manifest.level_file = "../outside/level.tscn"
	traversal_manifest.thumbnail = "thumbnail.png"
	var traversal_result := LevelPackagerScript.package_level(
		level, "user://level_packager_regressions/", traversal_manifest
	)
	assert_false(traversal_result.success, "Traversal paths must not be packaged")

	var absolute_manifest := LevelPackagerScript.LevelManifest.new()
	absolute_manifest.id = "absolute_path"
	absolute_manifest.name = "Absolute Path"
	absolute_manifest.level_file = "/tmp/outside/level.tscn"
	absolute_manifest.thumbnail = "thumbnail.png"
	var absolute_result := LevelPackagerScript.package_level(
		level, "user://level_packager_regressions/", absolute_manifest
	)
	assert_false(absolute_result.success, "Absolute paths must not be packaged")


func test_package_rejects_manifest_file_collision() -> void:
	var level := Node3D.new()
	add_child_autofree(level)
	var manifest := LevelPackagerScript.LevelManifest.new()
	manifest.id = "manifest_collision"
	manifest.name = "Manifest Collision"
	manifest.level_file = "manifest.json"
	manifest.thumbnail = "thumbnail.png"

	var result := LevelPackagerScript.package_level(
		level, "user://level_packager_regressions/", manifest
	)

	assert_false(result.success, "A level must not replace the package manifest")


func test_package_rejects_level_and_thumbnail_collision() -> void:
	var level := Node3D.new()
	add_child_autofree(level)
	var manifest := LevelPackagerScript.LevelManifest.new()
	manifest.id = "level_thumbnail_collision"
	manifest.name = "Level Thumbnail Collision"
	manifest.level_file = "content/shared.bin"
	manifest.thumbnail = "content/shared.bin"

	var result := LevelPackagerScript.package_level(
		level, "user://level_packager_regressions/", manifest
	)

	assert_false(result.success, "Level and thumbnail must occupy distinct package files")


func test_manifest_parser_rejects_malformed_field_types() -> void:
	var malformed := (
		LevelPackagerScript
		. LevelManifest
		. from_dict(
			{
				"level_file": 42,
				"thumbnail": "thumbnail.png",
			}
		)
	)
	assert_null(malformed, "Manifest fields with unexpected types must be rejected")

	var malformed_tags := (
		LevelPackagerScript
		. LevelManifest
		. from_dict(
			{
				"tags": ["valid", 7],
			}
		)
	)
	assert_null(malformed_tags, "Manifest arrays must contain only strings")


func test_archive_entry_validation_rejects_empty_and_ambiguous_paths() -> void:
	assert_false(
		LevelPackagerScript._is_valid_archive_entry(""), "Empty archive entries must fail closed"
	)
	assert_false(
		LevelPackagerScript._is_valid_archive_entry("assets//texture.png"),
		"Archive entries with empty path components must fail closed"
	)
	assert_false(
		LevelPackagerScript._is_valid_archive_entry("assets/./texture.png"),
		"Archive entries with dot components must fail closed"
	)
	assert_true(
		LevelPackagerScript._is_valid_archive_entry("assets/texture.png"),
		"Valid archive entries must remain supported"
	)


func test_package_preserves_existing_output_and_exports_fresh_package() -> void:
	var output_dir := "user://level_packager_overwrite_regression/"
	var output_path := output_dir.path_join("overwrite_guard.mdsl")
	if FileAccess.file_exists(output_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(output_path))
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(output_dir)):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(output_dir))
	assert_eq(
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir)),
		OK,
		"Regression output directory should be creatable"
	)

	var sentinel := FileAccess.open(output_path, FileAccess.WRITE)
	assert_not_null(sentinel, "Regression sentinel should be writable")
	if not sentinel:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(output_dir))
		return
	sentinel.store_buffer(PackedByteArray([0x53, 0x45, 0x4E, 0x54, 0x49, 0x4E, 0x45, 0x4C]))
	sentinel.close()
	var sentinel_bytes := FileAccess.get_file_as_bytes(output_path)

	var level := Node3D.new()
	add_child_autofree(level)
	var manifest := LevelPackagerScript.LevelManifest.new()
	manifest.id = "overwrite_guard"
	manifest.name = "Overwrite Guard"

	var refused := LevelPackagerScript.package_level(level, output_dir, manifest)
	assert_false(refused.success, "Packaging must refuse an existing output package")
	assert_true(
		"already exists" in refused.error_msg, "Refusal should explain the existing package"
	)
	assert_eq(
		FileAccess.get_file_as_bytes(output_path),
		sentinel_bytes,
		"Refused packaging must preserve the existing package bytes"
	)

	DirAccess.remove_absolute(ProjectSettings.globalize_path(output_path))
	var fresh := LevelPackagerScript.package_level(level, output_dir, manifest)
	assert_true(fresh.success, "Packaging should still succeed for a fresh output")
	assert_eq(fresh.output_path, output_path)

	DirAccess.remove_absolute(ProjectSettings.globalize_path(output_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(output_dir))
