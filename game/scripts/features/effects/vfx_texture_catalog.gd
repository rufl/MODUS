class_name VFXTextureCatalog
extends RefCounted

## Canonical texture selections for runtime weapon and impact effects.
## Textures load lazily so existing procedural fallbacks remain valid if assets are absent.

const MUZZLE_FLASH_PATHS = [
	"res://game/art/textures/vfx/brackeys/particles/alpha/muzzle_01_a.png",
	"res://game/art/textures/vfx/brackeys/particles/alpha/muzzle_02_a.png",
	"res://game/art/textures/vfx/brackeys/particles/alpha/muzzle_03_a.png",
	"res://game/art/textures/vfx/brackeys/particles/alpha/muzzle_04_a.png",
	"res://game/art/textures/vfx/brackeys/particles/alpha/muzzle_05_a.png",
]

const MUZZLE_SMOKE_PATHS = [
	"res://game/art/textures/vfx/brackeys/particles/alpha/smoke_01_a.png",
	"res://game/art/textures/vfx/brackeys/particles/alpha/smoke_02_a.png",
	"res://game/art/textures/vfx/brackeys/particles/alpha/smoke_03_a.png",
	"res://game/art/textures/vfx/brackeys/particles/alpha/smoke_04_a.png",
	"res://game/art/textures/vfx/brackeys/particles/alpha/smoke_05_a.png",
]

const IMPACT_PATHS = [
	"res://game/art/textures/vfx/brackeys/particles/alpha/scorch_01_a.png",
	"res://game/art/textures/vfx/brackeys/particles/alpha/scorch_02_a.png",
	"res://game/art/textures/vfx/brackeys/particles/alpha/scorch_03_a.png",
]

static var _cache: Dictionary = {}


static func pick_muzzle_flash() -> Texture2D:
	return _load_first("muzzle_flash", MUZZLE_FLASH_PATHS)


static func pick_muzzle_smoke() -> Texture2D:
	return _load_first("muzzle_smoke", MUZZLE_SMOKE_PATHS)


static func pick_impact() -> Texture2D:
	return _load_first("impact", IMPACT_PATHS)


static func _load_first(cache_key: String, paths: Array) -> Texture2D:
	if _cache.has(cache_key):
		return _cache[cache_key] as Texture2D

	for path in paths:
		if not ResourceLoader.exists(path):
			continue
		var texture := (
			ResourceLoader.load(path, "Texture2D", ResourceLoader.CACHE_MODE_REUSE) as Texture2D
		)
		if texture:
			_cache[cache_key] = texture
			return texture
	return null
