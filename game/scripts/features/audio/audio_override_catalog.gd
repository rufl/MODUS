class_name AudioOverrideCatalog
extends RefCounted

const AUDIO_ROOT := "res://game/art/audio/sfx/"
const CONFIG_PATH := "res://game/config/gameplay/audio_overrides.json5"
const JSON5_LOADER_PATH := "res://game/core/json5_loader.gd"


static func load_overrides() -> Dictionary:
	var loader := load(JSON5_LOADER_PATH) as GDScript
	if loader == null or not loader.file_exists(CONFIG_PATH):
		return {}
	var data: Variant = loader.load_file(CONFIG_PATH)
	if data is Dictionary:
		return data
	return {}


static func load_stream(overrides: Dictionary, event_name: String) -> AudioStream:
	if not overrides.has(event_name):
		return null
	var relative_path := str(overrides[event_name]).strip_edges()
	if relative_path.is_empty():
		return null
	if (
		relative_path.begins_with("/")
		or relative_path.begins_with("res://")
		or relative_path.contains("..")
		or relative_path.contains("\\")
		or relative_path.contains(":")
	):
		push_warning("[AudioOverrideCatalog] Rejected unsafe override path for %s" % event_name)
		return null
	var stream_path := AUDIO_ROOT + relative_path
	if not ResourceLoader.exists(stream_path):
		push_warning(
			"[AudioOverrideCatalog] Missing override for %s: %s" % [event_name, stream_path]
		)
		return null
	var stream := (
		ResourceLoader.load(stream_path, "AudioStream", ResourceLoader.CACHE_MODE_REUSE)
		as AudioStream
	)
	if stream == null:
		push_warning(
			"[AudioOverrideCatalog] Failed to load override for %s: %s" % [event_name, stream_path]
		)
	return stream
