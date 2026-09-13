extends "res://game/scenes/items/pickups/pickup_base.gd"
class_name AmmoPickup

@export var ammo_amount: int = 30


func _ready() -> void:
	pickup_name = "pickup_ammo_box"
	description = "+" + str(ammo_amount) + " Ammo"

	# Icon configuration
	use_icon = true
	icon_text = "🔫"
	icon_color = Color.GRAY

	super._ready()

	# Grey ray for consumables
	if vertical_ray:
		_update_ray_color(Color.GRAY, 2.0)
	if base_glow:
		base_glow.light_color = Color.GRAY
		base_glow.light_energy = 0.3


func _apply_pickup(player: CharacterBody3D) -> bool:
	if not "weapon_manager" in player or not player.weapon_manager:
		return false
	var ammo: WeaponAmmoSystem = player.weapon_manager.ammo_system
	if not ammo or ammo.add_reserve_ammo(ammo_amount) == 0:
		return false
	var blood_overlay: Control = player.blood_overlay
	if blood_overlay and blood_overlay.has_method("show_ammo_flash"):
		blood_overlay.show_ammo_flash()
	return true
