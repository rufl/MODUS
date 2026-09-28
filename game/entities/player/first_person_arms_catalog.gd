class_name FirstPersonArmsCatalog
extends RefCounted

## Canonical WRAD ARMS selections for first-person player presentation.
## The model ships with the pale skin; the catalog keeps both supplied skin
## variants available for a future runtime skin selector.

const MODEL_PATH := "res://game/art/models/first_person/wrad_arms/arms.glb"
const SKIN_TEXTURE_PATHS: Dictionary = {
	"pale": "res://game/art/models/first_person/wrad_arms/arm_albedo_pale.png",
	"dark": "res://game/art/models/first_person/wrad_arms/arm_albedo_dark.png",
}
const ASSET_ROSTER: Array[Dictionary] = [
	{
		"id": "wrad_arms_model",
		"asset_type": "model",
		"path": MODEL_PATH,
		"role": "first_person_arms",
	},
	{
		"id": "wrad_arms_skin_pale",
		"asset_type": "texture",
		"path": SKIN_TEXTURE_PATHS["pale"],
		"role": "first_person_arms_skin",
		"variant": "pale",
	},
	{
		"id": "wrad_arms_skin_dark",
		"asset_type": "texture",
		"path": SKIN_TEXTURE_PATHS["dark"],
		"role": "first_person_arms_skin",
		"variant": "dark",
	},
]


static func get_asset_roster() -> Array[Dictionary]:
	return ASSET_ROSTER.duplicate(true)


static func load_model() -> PackedScene:
	return (
		ResourceLoader.load(MODEL_PATH, "PackedScene", ResourceLoader.CACHE_MODE_REUSE)
		as PackedScene
	)


static func load_skin(variant: String) -> Texture2D:
	var path := str(SKIN_TEXTURE_PATHS.get(variant, ""))
	if path.is_empty():
		return null
	return ResourceLoader.load(path, "Texture2D", ResourceLoader.CACHE_MODE_REUSE) as Texture2D


static func is_ready() -> bool:
	if load_model() == null:
		return false
	for path: String in SKIN_TEXTURE_PATHS.values():
		if ResourceLoader.load(path, "Texture2D", ResourceLoader.CACHE_MODE_REUSE) == null:
			return false
	return true
