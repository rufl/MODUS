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


static func is_randomized_override(overrides: Dictionary, event_name: String) -> bool:
	return overrides.get(event_name) is Array


static func load_stream(overrides: Dictionary, event_name: String) -> AudioStream:
	if not overrides.has(event_name):
		return null

	var candidates: Array[String] = []
	var configured: Variant = overrides[event_name]
	if configured is Array:
		for value: Variant in configured:
			candidates.append(str(value).strip_edges())
	else:
		candidates.append(str(configured).strip_edges())

	candidates = candidates.filter(func(path: String) -> bool: return not path.is_empty())
	if candidates.is_empty():
		return null
	candidates.shuffle()

	for relative_path: String in candidates:
		if (
			relative_path.begins_with("/")
			or relative_path.begins_with("res://")
			or relative_path.contains("..")
			or relative_path.contains("\\")
			or relative_path.contains(":")
		):
			push_warning("[AudioOverrideCatalog] Rejected unsafe override path for %s" % event_name)
			continue
		var stream_path := AUDIO_ROOT + relative_path
		if not ResourceLoader.exists(stream_path):
			push_warning(
				"[AudioOverrideCatalog] Missing override for %s: %s" % [event_name, stream_path]
			)
			continue
		var stream := (
			ResourceLoader.load(stream_path, "AudioStream", ResourceLoader.CACHE_MODE_REUSE)
			as AudioStream
		)
		if stream:
			return stream
		push_warning(
			"[AudioOverrideCatalog] Failed to load override for %s: %s" % [event_name, stream_path]
		)
	return null
