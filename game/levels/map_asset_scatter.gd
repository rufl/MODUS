class_name LevelMapAssetScatter
extends Node3D

## World dressing contract for authored map-wide asset placement.
##
## These representatives sit beside authored modules and never replace their
## gameplay geometry. Imported model collisions are disabled recursively.

const CONTRACT_VERSION := 1

@export_enum("breakwater", "showcase") var placement_profile: String = "breakwater"

const BREAKWATER_ASSETS: Array[Dictionary] = [
	{
		"id": "dock_fence",
		"family": "fences",
		"path": "res://game/art/models/fences/metal_fence/metalfence_both_sides_topbar.glb",
		"position": Vector3(10.5, 0.0, 0.0),
		"rotation_degrees": Vector3(0.0, 90.0, 0.0),
		"scale": Vector3(1.2, 1.2, 1.2),
	},
	{
		"id": "dock_street_barrel",
		"family": "kkryy_street_furniture",
		"path": "res://game/art/models/third_party/kkryy_street_furniture/Barrel.fbx",
		"position": Vector3(-10.5, 0.0, 4.5),
		"rotation_degrees": Vector3(0.0, 25.0, 0.0),
		"scale": Vector3(1.2, 1.2, 1.2),
	},
	{
		"id": "dock_trash_debris",
		"family": "mcsteeg_trash_and_debris",
		"path": "res://game/art/models/third_party/mcsteeg_trash_and_debris/TrashAndDebris.glb",
		"position": Vector3(10.5, 0.0, 4.5),
		"rotation_degrees": Vector3(0.0, -35.0, 0.0),
		"scale": Vector3(0.45, 0.45, 0.45),
	},
	{
		"id": "hub_survival_camp",
		"family": "mcsteeg_survival",
		"path": "res://game/art/models/third_party/mcsteeg_survival/Survival.dae",
		"position": Vector3(-15.5, 0.0, -18.0),
		"rotation_degrees": Vector3(0.0, 180.0, 0.0),
		"scale": Vector3(0.04, 0.04, 0.04),
	},
	{
		"id": "hub_office_desk",
		"family": "office",
		"path": "res://game/art/models/office/desks/desk1.glb",
		"position": Vector3(15.5, 0.0, -18.0),
		"rotation_degrees": Vector3(0.0, 180.0, 0.0),
		"scale": Vector3(1.2, 1.2, 1.2),
	},
	{
		"id": "pump_retro_generator",
		"family": "chilly_durango_retro_machinery",
		"path":
		"res://game/art/models/third_party/chilly_durango_retro_machinery/models/retro_generator.glb",
		"position": Vector3(16.5, 0.0, -40.0),
		"rotation_degrees": Vector3(0.0, 20.0, 0.0),
		"scale": Vector3(1.5, 1.5, 1.5),
	},
	{
		"id": "pump_pipe_set",
		"family": "loafbrr_pipes",
		"path": "res://game/art/models/third_party/loafbrr_pipes/Scenes/pipeSet/pipe_set_1.tscn",
		"position": Vector3(-16.5, 0.0, -40.0),
		"rotation_degrees": Vector3(0.0, 180.0, 0.0),
		"scale": Vector3(0.8, 0.8, 0.8),
	},
	{
		"id": "intake_retro_pump",
		"family": "chilly_durango_retro_machinery",
		"path":
		"res://game/art/models/third_party/chilly_durango_retro_machinery/models/retro_pump.glb",
		"position": Vector3(16.5, 0.0, -64.0),
		"rotation_degrees": Vector3(0.0, -20.0, 0.0),
		"scale": Vector3(1.5, 1.5, 1.5),
	},
	{
		"id": "intake_pipe_box",
		"family": "loafbrr_pipes",
		"path": "res://game/art/models/third_party/loafbrr_pipes/Scenes/Boxes/pipes_box_aa.tscn",
		"position": Vector3(-16.5, 0.0, -64.0),
		"rotation_degrees": Vector3(0.0, -15.0, 0.0),
		"scale": Vector3(0.8, 0.8, 0.8),
	},
	{
		"id": "cavern_mine_props",
		"family": "elbolilloduro_mine",
		"path": "res://game/art/models/third_party/elbolilloduro_mine/mine_props.dae",
		"position": Vector3(39.5, 0.0, -74.0),
		"rotation_degrees": Vector3(0.0, 180.0, 0.0),
		"scale": Vector3(0.04, 0.04, 0.04),
	},
	{
		"id": "turbine_wind_landmark",
		"family": "3dexter_looming_landmarks",
		"path": "res://game/art/models/third_party/3dexter_looming_landmarks/WindTurbine.glb",
		"position": Vector3(16.5, 0.0, -90.0),
		"rotation_degrees": Vector3(0.0, 180.0, 0.0),
		"scale": Vector3(0.06, 0.06, 0.06),
	},
	{
		"id": "relay_industrial_exterior",
		"family": "godgoldfear_industrial",
		"path":
		"res://game/art/models/third_party/godgoldfear_industrial/IndustrialHorror_PS_like.fbx",
		"position": Vector3(-16.5, 0.0, -116.0),
		"rotation_degrees": Vector3(0.0, 180.0, 0.0),
		"scale": Vector3(0.05, 0.05, 0.05),
	},
	{
		"id": "return_psx_models",
		"family": "elbolilloduro_psx_models",
		"path": "res://game/art/models/third_party/elbolilloduro_psx_models/models.dae",
		"position": Vector3(35.5, 0.0, -114.0),
		"rotation_degrees": Vector3(0.0, 180.0, 0.0),
		"scale": Vector3(0.06, 0.06, 0.06),
	},
	{
		"id": "return_prildarill_shelf",
		"family": "prildarill_low_poly_assets",
		"path": "res://game/art/models/third_party/prildarill_low_poly_assets/Shelf.fbx",
		"position": Vector3(48.0, 0.0, -114.0),
		"rotation_degrees": Vector3(0.0, 180.0, 0.0),
		"scale": Vector3(0.75, 0.75, 0.75),
	},
	{
		"id": "return_psx_skeleton",
		"family": "vinrax_psx_skeleton",
		"path": "res://game/art/models/third_party/vinrax_psx_skeleton/skeleton.glb",
		"position": Vector3(42.0, 0.0, -106.0),
		"rotation_degrees": Vector3(0.0, 180.0, 0.0),
		"scale": Vector3.ONE,
	},
	{
		"id": "return_water_duck",
		"family": "binbun_water",
		"path": "res://game/art/models/third_party/binbun_water/duck.glb",
		"position": Vector3(49.0, 0.0, -106.0),
		"rotation_degrees": Vector3(0.0, 25.0, 0.0),
		"scale": Vector3(1.5, 1.5, 1.5),
	},
	{
		"id": "return_pipe_valve",
		"family": "loafbrr_pipes",
		"path": "res://game/art/models/third_party/loafbrr_pipes/Scenes/Valves/valve_a_grp.tscn",
		"position": Vector3(34.0, 4.0, -65.0),
		"rotation_degrees": Vector3(0.0, 15.0, 0.0),
		"scale": Vector3(0.55, 0.55, 0.55),
	},
	{
		"id": "dock_wooden_fence",
		"family": "fences",
		"path": "res://game/art/models/fences/low_wooden_fence/wooden_fence_closed.glb",
		"position": Vector3(-10.5, 0.0, -4.5),
		"rotation_degrees": Vector3(0.0, -90.0, 0.0),
		"scale": Vector3(1.2, 1.2, 1.2),
	},
	{
		"id": "hub_water_cooler",
		"family": "office",
		"path": "res://game/art/models/office/extras/water_cooler.glb",
		"position": Vector3(15.5, 0.0, -22.5),
		"rotation_degrees": Vector3.ZERO,
		"scale": Vector3(1.2, 1.2, 1.2),
	},
	{
		"id": "pump_pipe_valve",
		"family": "loafbrr_pipes",
		"path": "res://game/art/models/third_party/loafbrr_pipes/Scenes/Valves/valve_a_grp.tscn",
		"position": Vector3(-16.5, 0.0, -44.5),
		"rotation_degrees": Vector3(0.0, 15.0, 0.0),
		"scale": Vector3(0.55, 0.55, 0.55),
	},
	{
		"id": "intake_industrial_exterior",
		"family": "godgoldfear_industrial",
		"path":
		"res://game/art/models/third_party/godgoldfear_industrial/IndustrialHorror_PS_like.fbx",
		"position": Vector3(16.5, 0.0, -68.5),
		"rotation_degrees": Vector3(0.0, 180.0, 0.0),
		"scale": Vector3(0.05, 0.05, 0.05),
	},
	{
		"id": "cavern_prildarill_shelf",
		"family": "prildarill_low_poly_assets",
		"path": "res://game/art/models/third_party/prildarill_low_poly_assets/Shelf.fbx",
		"position": Vector3(39.5, 0.0, -78.5),
		"rotation_degrees": Vector3(0.0, 180.0, 0.0),
		"scale": Vector3(0.75, 0.75, 0.75),
	},
	{
		"id": "turbine_street_barrel",
		"family": "kkryy_street_furniture",
		"path": "res://game/art/models/third_party/kkryy_street_furniture/Barrel.fbx",
		"position": Vector3(-16.5, 0.0, -94.5),
		"rotation_degrees": Vector3(0.0, -25.0, 0.0),
		"scale": Vector3(1.2, 1.2, 1.2),
	},
	{
		"id": "relay_office_bookcase",
		"family": "office",
		"path": "res://game/art/models/office/book_things/book_case_small.glb",
		"position": Vector3(-16.5, 0.0, -120.5),
		"rotation_degrees": Vector3.ZERO,
		"scale": Vector3(1.2, 1.2, 1.2),
	},
	{
		"id": "return_wooden_fence",
		"family": "fences",
		"path": "res://game/art/models/fences/low_wooden_fence/wooden_fence_closed.glb",
		"position": Vector3(48.0, 0.0, -119.5),
		"rotation_degrees": Vector3(0.0, -90.0, 0.0),
		"scale": Vector3(1.2, 1.2, 1.2),
	},
	{
		"id": "dock_classic64_guard_rail",
		"family": "classic64_breakwater",
		"path": "res://game/art/models/third_party/classic64_breakwater/classic64_guard_rail.glb",
		"position": Vector3(-15.5, 0.0, 0.0),
		"rotation_degrees": Vector3(0.0, 180.0, 0.0),
		"scale": Vector3(0.62, 0.62, 0.62),
	},
	{
		"id": "hub_classic64_generator",
		"family": "classic64_breakwater",
		"path": "res://game/art/models/third_party/classic64_breakwater/classic64_generator.glb",
		"position": Vector3(-15.5, 0.0, -22.0),
		"rotation_degrees": Vector3(0.0, -14.0, 0.0),
		"scale": Vector3(1.55, 1.55, 1.55),
	},
	{
		"id": "pump_retro_transformer",
		"family": "chilly_durango_retro_machinery",
		"path":
		"res://game/art/models/third_party/chilly_durango_retro_machinery/models/retro_transformer.glb",
		"position": Vector3(16.5, 0.0, -44.5),
		"rotation_degrees": Vector3(0.0, -12.0, 0.0),
		"scale": Vector3(1.45, 1.45, 1.45),
	},
	{
		"id": "intake_retro_turbine",
		"family": "chilly_durango_retro_machinery",
		"path":
		"res://game/art/models/third_party/chilly_durango_retro_machinery/models/retro_turbine.glb",
		"position": Vector3(-16.5, 0.0, -68.5),
		"rotation_degrees": Vector3(0.0, -16.0, 0.0),
		"scale": Vector3(1.2, 1.2, 1.2),
	},
	{
		"id": "cavern_mine_modular",
		"family": "elbolilloduro_mine",
		"path": "res://game/art/models/third_party/elbolilloduro_mine/mine_modular.dae",
		"position": Vector3(39.5, 0.0, -68.5),
		"rotation_degrees": Vector3(0.0, 180.0, 0.0),
		"scale": Vector3(0.15, 0.15, 0.15),
	},
	{
		"id": "turbine_retro_pipe_valve",
		"family": "chilly_durango_retro_machinery",
		"path":
		"res://game/art/models/third_party/chilly_durango_retro_machinery/models/retro_pipe_valve.glb",
		"position": Vector3(-16.5, 0.0, -88.5),
		"rotation_degrees": Vector3(0.0, -14.0, 0.0),
		"scale": Vector3(1.55, 1.55, 1.55),
	},
	{
		"id": "relay_classic64_panel",
		"family": "classic64_breakwater",
		"path":
		"res://game/art/models/third_party/classic64_breakwater/classic64_panel_electrical_closed.glb",
		"position": Vector3(16.5, 0.0, -120.0),
		"rotation_degrees": Vector3(0.0, 12.0, 0.0),
		"scale": Vector3(4.6, 4.6, 4.6),
	},
	{
		"id": "return_classic64_junctionbox",
		"family": "classic64_breakwater",
		"path":
		"res://game/art/models/third_party/classic64_breakwater/classic64_electrical_junctionbox_small.glb",
		"position": Vector3(35.5, 0.8, -119.0),
		"rotation_degrees": Vector3(0.0, -18.0, 0.0),
		"scale": Vector3(8.0, 8.0, 8.0),
	},
	{
		"id": "dock_retro_wires",
		"family": "chilly_durango_retro_machinery",
		"path":
		"res://game/art/models/third_party/chilly_durango_retro_machinery/models/retro_wires.glb",
		"position": Vector3(10.5, 0.0, -8.5),
		"rotation_degrees": Vector3(0.0, 25.0, 0.0),
		"scale": Vector3(1.2, 1.2, 1.2),
	},
	{
		"id": "hub_retro_circuit_breaker",
		"family": "chilly_durango_retro_machinery",
		"path":
		"res://game/art/models/third_party/chilly_durango_retro_machinery/models/retro_circuit_breaker.glb",
		"position": Vector3(-15.5, 0.0, -30.0),
		"rotation_degrees": Vector3(0.0, -14.0, 0.0),
		"scale": Vector3(1.4, 1.4, 1.4),
	},
	{
		"id": "pump_retro_pipes",
		"family": "chilly_durango_retro_machinery",
		"path":
		"res://game/art/models/third_party/chilly_durango_retro_machinery/models/retro_pipes.glb",
		"position": Vector3(-16.5, 0.0, -52.5),
		"rotation_degrees": Vector3(0.0, -15.0, 0.0),
		"scale": Vector3(1.0, 1.0, 1.0),
	},
	{
		"id": "cavern_prildarill_locker",
		"family": "prildarill_low_poly_assets",
		"path": "res://game/art/models/third_party/prildarill_low_poly_assets/locker.fbx",
		"position": Vector3(39.5, 0.0, -94.0),
		"rotation_degrees": Vector3(0.0, 180.0, 0.0),
		"scale": Vector3(0.8, 0.8, 0.8),
	},
	{
		"id": "turbine_street_trashcan",
		"family": "kkryy_street_furniture",
		"path": "res://game/art/models/third_party/kkryy_street_furniture/TrashCan.fbx",
		"position": Vector3(16.5, 0.0, -101.0),
		"rotation_degrees": Vector3(0.0, 25.0, 0.0),
		"scale": Vector3(1.2, 1.2, 1.2),
	},
	{
		"id": "relay_office_file_cabinet",
		"family": "office",
		"path": "res://game/art/models/office/file_cabinets/file_cabinet_small.glb",
		"position": Vector3(16.5, 0.0, -110.0),
		"rotation_degrees": Vector3(0.0, 180.0, 0.0),
		"scale": Vector3(1.2, 1.2, 1.2),
	},
	{
		"id": "return_pipe_valve_b",
		"family": "loafbrr_pipes",
		"path": "res://game/art/models/third_party/loafbrr_pipes/Scenes/Valves/valve_b_grp.tscn",
		"position": Vector3(34.0, 4.0, -56.0),
		"rotation_degrees": Vector3(0.0, -20.0, 0.0),
		"scale": Vector3(0.55, 0.55, 0.55),
	},
	{
		"id": "return_drystone_column",
		"family": "fences",
		"path": "res://game/art/models/fences/drystone_wall/drystone_column.glb",
		"position": Vector3(28.0, 0.0, -108.0),
		"rotation_degrees": Vector3(0.0, 90.0, 0.0),
		"scale": Vector3(1.0, 1.0, 1.0),
	},
	{
		"id": "dock_prildarill_double_doors",
		"family": "prildarill_low_poly_assets",
		"path": "res://game/art/models/third_party/prildarill_low_poly_assets/doors_double.fbx",
		"position": Vector3(-10.5, 0.0, -10.0),
		"rotation_degrees": Vector3(0.0, 90.0, 0.0),
		"scale": Vector3(0.8, 0.8, 0.8),
	},
	{
		"id": "hub_street_box",
		"family": "kkryy_street_furniture",
		"path": "res://game/art/models/third_party/kkryy_street_furniture/Box.fbx",
		"position": Vector3(15.5, 0.0, -30.0),
		"rotation_degrees": Vector3(0.0, -14.0, 0.0),
		"scale": Vector3(1.2, 1.2, 1.2),
	},
	{
		"id": "pump_office_chair",
		"family": "office",
		"path": "res://game/art/models/office/chairs/office_chair_black.glb",
		"position": Vector3(16.5, 0.0, -52.5),
		"rotation_degrees": Vector3(0.0, 25.0, 0.0),
		"scale": Vector3(1.2, 1.2, 1.2),
	},
	{
		"id": "intake_office_couch",
		"family": "office",
		"path": "res://game/art/models/office/couches/couch_blue.glb",
		"position": Vector3(-16.5, 0.0, -78.5),
		"rotation_degrees": Vector3(0.0, 180.0, 0.0),
		"scale": Vector3(1.0, 1.0, 1.0),
	},
	{
		"id": "cavern_street_bottles",
		"family": "kkryy_street_furniture",
		"path": "res://game/art/models/third_party/kkryy_street_furniture/Bottles.fbx",
		"position": Vector3(39.5, 0.0, -88.5),
		"rotation_degrees": Vector3(0.0, -20.0, 0.0),
		"scale": Vector3(1.2, 1.2, 1.2),
	},
	{
		"id": "turbine_office_keyboard",
		"family": "office",
		"path": "res://game/art/models/office/computers/computer_keyboard.glb",
		"position": Vector3(16.5, 1.0, -94.5),
		"rotation_degrees": Vector3(0.0, 15.0, 0.0),
		"scale": Vector3(1.2, 1.2, 1.2),
	},
	{
		"id": "relay_prildarill_talllocker",
		"family": "prildarill_low_poly_assets",
		"path": "res://game/art/models/third_party/prildarill_low_poly_assets/Talllocker.fbx",
		"position": Vector3(16.5, 0.0, -116.0),
		"rotation_degrees": Vector3(0.0, 180.0, 0.0),
		"scale": Vector3(0.8, 0.8, 0.8),
	},
	{
		"id": "return_pipe_box_ab",
		"family": "loafbrr_pipes",
		"path": "res://game/art/models/third_party/loafbrr_pipes/Scenes/Boxes/pipes_box_ab.tscn",
		"position": Vector3(28.0, 0.0, -98.0),
		"rotation_degrees": Vector3(0.0, 12.0, 0.0),
		"scale": Vector3(0.8, 0.8, 0.8),
	},
	{
		"id": "dock_street_gasmask",
		"family": "kkryy_street_furniture",
		"path": "res://game/art/models/third_party/kkryy_street_furniture/GasMask.fbx",
		"position": Vector3(-10.5, 1.0, -12.0),
		"rotation_degrees": Vector3(0.0, 25.0, 0.0),
		"scale": Vector3(0.9, 0.9, 0.9),
	},
	{
		"id": "hub_street_hammer",
		"family": "kkryy_street_furniture",
		"path": "res://game/art/models/third_party/kkryy_street_furniture/Hammer.fbx",
		"position": Vector3(15.5, 1.0, -34.0),
		"rotation_degrees": Vector3(0.0, -14.0, 0.0),
		"scale": Vector3(0.9, 0.9, 0.9),
	},
	{
		"id": "pump_street_flashlight",
		"family": "kkryy_street_furniture",
		"path": "res://game/art/models/third_party/kkryy_street_furniture/Flashlight.fbx",
		"position": Vector3(-16.5, 1.0, -58.0),
		"rotation_degrees": Vector3(0.0, -15.0, 0.0),
		"scale": Vector3(0.9, 0.9, 0.9),
	},
	{
		"id": "intake_office_computer_mouse",
		"family": "office",
		"path": "res://game/art/models/office/computers/computer_mouse.glb",
		"position": Vector3(16.5, 1.0, -82.0),
		"rotation_degrees": Vector3(0.0, 15.0, 0.0),
		"scale": Vector3(1.2, 1.2, 1.2),
	},
	{
		"id": "cavern_office_computer_tower",
		"family": "office",
		"path": "res://game/art/models/office/computers/computer_tower.glb",
		"position": Vector3(39.5, 0.0, -100.0),
		"rotation_degrees": Vector3(0.0, 180.0, 0.0),
		"scale": Vector3(1.2, 1.2, 1.2),
	},
	{
		"id": "turbine_office_tv",
		"family": "office",
		"path": "res://game/art/models/office/computers/TV.glb",
		"position": Vector3(-16.5, 1.0, -104.0),
		"rotation_degrees": Vector3(0.0, -20.0, 0.0),
		"scale": Vector3(1.2, 1.2, 1.2),
	},
	{
		"id": "relay_office_conference_chair",
		"family": "office",
		"path": "res://game/art/models/office/chairs/conference_chair.glb",
		"position": Vector3(-16.5, 0.0, -108.0),
		"rotation_degrees": Vector3(0.0, 180.0, 0.0),
		"scale": Vector3(1.0, 1.0, 1.0),
	},
	{
		"id": "return_pipe_box_ac",
		"family": "loafbrr_pipes",
		"path": "res://game/art/models/third_party/loafbrr_pipes/Scenes/Boxes/pipes_box_ac.tscn",
		"position": Vector3(28.0, 0.0, -90.0),
		"rotation_degrees": Vector3(0.0, 12.0, 0.0),
		"scale": Vector3(0.8, 0.8, 0.8),
	},
]

const SHOWCASE_ASSETS: Array[Dictionary] = [
	{
		"id": "movement_lab_fence",
		"family": "fences",
		"path": "res://game/art/models/fences/brick_fence/brick_wall_gate.glb",
		"position": Vector3(-65.0, 0.0, -50.0),
		"rotation_degrees": Vector3(0.0, 90.0, 0.0),
		"scale": Vector3(1.5, 1.5, 1.5),
	},
	{
		"id": "movement_lab_office",
		"family": "office",
		"path": "res://game/art/models/office/extras/water_cooler.glb",
		"position": Vector3(-35.0, 0.0, -50.0),
		"rotation_degrees": Vector3.ZERO,
		"scale": Vector3(1.4, 1.4, 1.4),
	},
	{
		"id": "hazards_retro_generator",
		"family": "chilly_durango_retro_machinery",
		"path":
		"res://game/art/models/third_party/chilly_durango_retro_machinery/models/retro_generator.glb",
		"position": Vector3(65.0, 0.0, -50.0),
		"rotation_degrees": Vector3(0.0, 20.0, 0.0),
		"scale": Vector3(1.5, 1.5, 1.5),
	},
	{
		"id": "hazards_industrial",
		"family": "godgoldfear_industrial",
		"path":
		"res://game/art/models/third_party/godgoldfear_industrial/IndustrialHorror_PS_like.fbx",
		"position": Vector3(35.0, 0.0, -50.0),
		"rotation_degrees": Vector3(0.0, 180.0, 0.0),
		"scale": Vector3(0.05, 0.05, 0.05),
	},
	{
		"id": "interactables_prildarill",
		"family": "prildarill_low_poly_assets",
		"path": "res://game/art/models/third_party/prildarill_low_poly_assets/doors_single.fbx",
		"position": Vector3(-65.0, 0.0, 0.0),
		"rotation_degrees": Vector3(0.0, 90.0, 0.0),
		"scale": Vector3(0.8, 0.8, 0.8),
	},
	{
		"id": "interactables_mine_props",
		"family": "elbolilloduro_mine",
		"path": "res://game/art/models/third_party/elbolilloduro_mine/mine_props.dae",
		"position": Vector3(-35.0, 0.0, 0.0),
		"rotation_degrees": Vector3(0.0, 180.0, 0.0),
		"scale": Vector3(0.04, 0.04, 0.04),
	},
	{
		"id": "enemy_zoo_skeleton",
		"family": "vinrax_psx_skeleton",
		"path": "res://game/art/models/third_party/vinrax_psx_skeleton/skeleton.glb",
		"position": Vector3(65.0, 0.0, 0.0),
		"rotation_degrees": Vector3(0.0, 180.0, 0.0),
		"scale": Vector3.ONE,
	},
	{
		"id": "enemy_zoo_wind_turbine",
		"family": "3dexter_looming_landmarks",
		"path": "res://game/art/models/third_party/3dexter_looming_landmarks/WindTurbine.glb",
		"position": Vector3(35.0, 0.0, 0.0),
		"rotation_degrees": Vector3(0.0, 180.0, 0.0),
		"scale": Vector3(0.06, 0.06, 0.06),
	},
	{
		"id": "projectile_trash_debris",
		"family": "mcsteeg_trash_and_debris",
		"path": "res://game/art/models/third_party/mcsteeg_trash_and_debris/TrashAndDebris.glb",
		"position": Vector3(-65.0, 0.0, 50.0),
		"rotation_degrees": Vector3(0.0, 35.0, 0.0),
		"scale": Vector3(0.45, 0.45, 0.45),
	},
	{
		"id": "projectile_street_barrel",
		"family": "kkryy_street_furniture",
		"path": "res://game/art/models/third_party/kkryy_street_furniture/Barrel.fbx",
		"position": Vector3(-35.0, 0.0, 50.0),
		"rotation_degrees": Vector3(0.0, -25.0, 0.0),
		"scale": Vector3(1.2, 1.2, 1.2),
	},
	{
		"id": "traversal_pipe_set",
		"family": "loafbrr_pipes",
		"path": "res://game/art/models/third_party/loafbrr_pipes/Scenes/pipeSet/pipe_set_1.tscn",
		"position": Vector3(-12.0, 0.0, -72.0),
		"rotation_degrees": Vector3(0.0, 180.0, 0.0),
		"scale": Vector3(0.8, 0.8, 0.8),
	},
	{
		"id": "traversal_pipe_valve",
		"family": "loafbrr_pipes",
		"path": "res://game/art/models/third_party/loafbrr_pipes/Scenes/Valves/valve_a_grp.tscn",
		"position": Vector3(12.0, 0.0, -72.0),
		"rotation_degrees": Vector3(0.0, 15.0, 0.0),
		"scale": Vector3(0.55, 0.55, 0.55),
	},
	{
		"id": "visual_survival_camp",
		"family": "mcsteeg_survival",
		"path": "res://game/art/models/third_party/mcsteeg_survival/Survival.dae",
		"position": Vector3(-12.0, 0.0, 72.0),
		"rotation_degrees": Vector3(0.0, 180.0, 0.0),
		"scale": Vector3(0.04, 0.04, 0.04),
	},
	{
		"id": "visual_water_duck",
		"family": "binbun_water",
		"path": "res://game/art/models/third_party/binbun_water/duck.glb",
		"position": Vector3(12.0, 0.0, 72.0),
		"rotation_degrees": Vector3(0.0, 25.0, 0.0),
		"scale": Vector3(1.5, 1.5, 1.5),
	},
	{
		"id": "movement_lab_security_fence",
		"family": "fences",
		"path": "res://game/art/models/fences/metal_fence/metalfence_both_sides_topbar.glb",
		"position": Vector3(-58.0, 0.0, -56.0),
		"rotation_degrees": Vector3(0.0, 90.0, 0.0),
		"scale": Vector3(1.2, 1.2, 1.2),
	},
	{
		"id": "movement_lab_office_desk",
		"family": "office",
		"path": "res://game/art/models/office/desks/desk1.glb",
		"position": Vector3(-42.0, 0.0, -56.0),
		"rotation_degrees": Vector3(0.0, 180.0, 0.0),
		"scale": Vector3(1.2, 1.2, 1.2),
	},
	{
		"id": "hazards_pipe_valve",
		"family": "loafbrr_pipes",
		"path": "res://game/art/models/third_party/loafbrr_pipes/Scenes/Valves/valve_a_grp.tscn",
		"position": Vector3(58.0, 0.0, -56.0),
		"rotation_degrees": Vector3(0.0, 15.0, 0.0),
		"scale": Vector3(0.55, 0.55, 0.55),
	},
	{
		"id": "hazards_street_barrel",
		"family": "kkryy_street_furniture",
		"path": "res://game/art/models/third_party/kkryy_street_furniture/Barrel.fbx",
		"position": Vector3(42.0, 0.0, -56.0),
		"rotation_degrees": Vector3(0.0, -25.0, 0.0),
		"scale": Vector3(1.2, 1.2, 1.2),
	},
	{
		"id": "interactables_water_cooler",
		"family": "office",
		"path": "res://game/art/models/office/extras/water_cooler.glb",
		"position": Vector3(-58.0, 0.0, 6.0),
		"rotation_degrees": Vector3.ZERO,
		"scale": Vector3(1.2, 1.2, 1.2),
	},
	{
		"id": "enemy_zoo_water_duck",
		"family": "binbun_water",
		"path": "res://game/art/models/third_party/binbun_water/duck.glb",
		"position": Vector3(42.0, 0.0, 6.0),
		"rotation_degrees": Vector3(0.0, 25.0, 0.0),
		"scale": Vector3(1.5, 1.5, 1.5),
	},
	{
		"id": "projectile_pipe_box",
		"family": "loafbrr_pipes",
		"path": "res://game/art/models/third_party/loafbrr_pipes/Scenes/Boxes/pipes_box_aa.tscn",
		"position": Vector3(-58.0, 0.0, 56.0),
		"rotation_degrees": Vector3(0.0, -15.0, 0.0),
		"scale": Vector3(0.8, 0.8, 0.8),
	},
	{
		"id": "traversal_wooden_fence",
		"family": "fences",
		"path": "res://game/art/models/fences/low_wooden_fence/wooden_fence_closed.glb",
		"position": Vector3(20.0, 0.0, -66.0),
		"rotation_degrees": Vector3(0.0, -90.0, 0.0),
		"scale": Vector3(1.2, 1.2, 1.2),
	},
	{
		"id": "visual_lab_psx_skeleton",
		"family": "vinrax_psx_skeleton",
		"path": "res://game/art/models/third_party/vinrax_psx_skeleton/skeleton.glb",
		"position": Vector3(0.0, 0.0, 72.0),
		"rotation_degrees": Vector3(0.0, 180.0, 0.0),
		"scale": Vector3.ONE,
	},
	{
		"id": "visual_lab_prildarill_shelf",
		"family": "prildarill_low_poly_assets",
		"path": "res://game/art/models/third_party/prildarill_low_poly_assets/Shelf.fbx",
		"position": Vector3(20.0, 0.0, 72.0),
		"rotation_degrees": Vector3(0.0, 180.0, 0.0),
		"scale": Vector3(0.75, 0.75, 0.75),
	},
	{
		"id": "movement_lab_classic64_guard_rail",
		"family": "classic64_breakwater",
		"path": "res://game/art/models/third_party/classic64_breakwater/classic64_guard_rail.glb",
		"position": Vector3(-70.0, 0.0, -50.0),
		"rotation_degrees": Vector3(0.0, 180.0, 0.0),
		"scale": Vector3(0.62, 0.62, 0.62),
	},
	{
		"id": "hazards_retro_transformer",
		"family": "chilly_durango_retro_machinery",
		"path":
		"res://game/art/models/third_party/chilly_durango_retro_machinery/models/retro_transformer.glb",
		"position": Vector3(55.0, 0.0, -50.0),
		"rotation_degrees": Vector3(0.0, -12.0, 0.0),
		"scale": Vector3(1.45, 1.45, 1.45),
	},
	{
		"id": "interactables_mine_modular",
		"family": "elbolilloduro_mine",
		"path": "res://game/art/models/third_party/elbolilloduro_mine/mine_modular.dae",
		"position": Vector3(-35.0, 0.0, 6.0),
		"rotation_degrees": Vector3(0.0, 180.0, 0.0),
		"scale": Vector3(0.15, 0.15, 0.15),
	},
	{
		"id": "interactables_office_computer_monitor",
		"family": "office",
		"path": "res://game/art/models/office/computers/computer_monitor.glb",
		"position": Vector3(-58.0, 1.0, 6.0),
		"rotation_degrees": Vector3(0.0, 180.0, 0.0),
		"scale": Vector3(1.4, 1.4, 1.4),
	},
	{
		"id": "enemy_zoo_retro_turbine",
		"family": "chilly_durango_retro_machinery",
		"path":
		"res://game/art/models/third_party/chilly_durango_retro_machinery/models/retro_turbine.glb",
		"position": Vector3(55.0, 0.0, 6.0),
		"rotation_degrees": Vector3(0.0, -16.0, 0.0),
		"scale": Vector3(1.2, 1.2, 1.2),
	},
	{
		"id": "projectile_classic64_pump_station",
		"family": "classic64_breakwater",
		"path": "res://game/art/models/third_party/classic64_breakwater/classic64_pump_station.glb",
		"position": Vector3(-65.0, 0.0, 56.0),
		"rotation_degrees": Vector3(0.0, 18.0, 0.0),
		"scale": Vector3(1.25, 1.25, 1.25),
	},
	{
		"id": "traversal_retro_switches",
		"family": "chilly_durango_retro_machinery",
		"path":
		"res://game/art/models/third_party/chilly_durango_retro_machinery/models/retro_switches.glb",
		"position": Vector3(20.0, 0.1, -72.0),
		"rotation_degrees": Vector3(0.0, 18.0, 0.0),
		"scale": Vector3(1.9, 1.9, 1.9),
	},
	{
		"id": "visual_lab_classic64_sign",
		"family": "classic64_breakwater",
		"path":
		"res://game/art/models/third_party/classic64_breakwater/classic64_sign_confined_space.glb",
		"position": Vector3(35.0, 1.25, 72.0),
		"rotation_degrees": Vector3(90.0, 0.0, 18.0),
		"scale": Vector3(7.0, 7.0, 7.0),
	},
	{
		"id": "movement_lab_retro_wires",
		"family": "chilly_durango_retro_machinery",
		"path":
		"res://game/art/models/third_party/chilly_durango_retro_machinery/models/retro_wires.glb",
		"position": Vector3(-50.0, 0.0, -50.0),
		"rotation_degrees": Vector3(0.0, 15.0, 0.0),
		"scale": Vector3(1.2, 1.2, 1.2),
	},
	{
		"id": "hazards_retro_circuit_breaker",
		"family": "chilly_durango_retro_machinery",
		"path":
		"res://game/art/models/third_party/chilly_durango_retro_machinery/models/retro_circuit_breaker.glb",
		"position": Vector3(50.0, 0.0, -50.0),
		"rotation_degrees": Vector3(0.0, -14.0, 0.0),
		"scale": Vector3(1.4, 1.4, 1.4),
	},
	{
		"id": "interactables_prildarill_locker",
		"family": "prildarill_low_poly_assets",
		"path": "res://game/art/models/third_party/prildarill_low_poly_assets/locker.fbx",
		"position": Vector3(-50.0, 0.0, 0.0),
		"rotation_degrees": Vector3(0.0, 180.0, 0.0),
		"scale": Vector3(0.8, 0.8, 0.8),
	},
	{
		"id": "interactables_office_file_cabinet",
		"family": "office",
		"path": "res://game/art/models/office/file_cabinets/file_cabinet_small.glb",
		"position": Vector3(-48.0, 0.0, 6.0),
		"rotation_degrees": Vector3(0.0, 180.0, 0.0),
		"scale": Vector3(1.2, 1.2, 1.2),
	},
	{
		"id": "enemy_zoo_street_trashcan",
		"family": "kkryy_street_furniture",
		"path": "res://game/art/models/third_party/kkryy_street_furniture/TrashCan.fbx",
		"position": Vector3(50.0, 0.0, 0.0),
		"rotation_degrees": Vector3(0.0, 25.0, 0.0),
		"scale": Vector3(1.2, 1.2, 1.2),
	},
	{
		"id": "projectile_retro_pipes",
		"family": "chilly_durango_retro_machinery",
		"path":
		"res://game/art/models/third_party/chilly_durango_retro_machinery/models/retro_pipes.glb",
		"position": Vector3(-50.0, 0.0, 56.0),
		"rotation_degrees": Vector3(0.0, -15.0, 0.0),
		"scale": Vector3(1.0, 1.0, 1.0),
	},
	{
		"id": "traversal_pipe_set",
		"family": "loafbrr_pipes",
		"path": "res://game/art/models/third_party/loafbrr_pipes/Scenes/pipeSet/pipe_set_2.tscn",
		"position": Vector3(35.0, 0.0, -72.0),
		"rotation_degrees": Vector3(0.0, 12.0, 0.0),
		"scale": Vector3(0.8, 0.8, 0.8),
	},
	{
		"id": "visual_lab_drystone_column",
		"family": "fences",
		"path": "res://game/art/models/fences/drystone_wall/drystone_column.glb",
		"position": Vector3(35.0, 0.0, 62.0),
		"rotation_degrees": Vector3(0.0, 90.0, 0.0),
		"scale": Vector3(1.0, 1.0, 1.0),
	},
	{
		"id": "movement_lab_prildarill_double_doors",
		"family": "prildarill_low_poly_assets",
		"path": "res://game/art/models/third_party/prildarill_low_poly_assets/doors_double.fbx",
		"position": Vector3(-50.0, 0.0, -56.0),
		"rotation_degrees": Vector3(0.0, 90.0, 0.0),
		"scale": Vector3(0.8, 0.8, 0.8),
	},
	{
		"id": "hazards_prildarill_talllocker",
		"family": "prildarill_low_poly_assets",
		"path": "res://game/art/models/third_party/prildarill_low_poly_assets/Talllocker.fbx",
		"position": Vector3(50.0, 0.0, -56.0),
		"rotation_degrees": Vector3(0.0, 180.0, 0.0),
		"scale": Vector3(0.8, 0.8, 0.8),
	},
	{
		"id": "interactables_street_box",
		"family": "kkryy_street_furniture",
		"path": "res://game/art/models/third_party/kkryy_street_furniture/Box.fbx",
		"position": Vector3(-50.0, 0.0, 12.0),
		"rotation_degrees": Vector3(0.0, -14.0, 0.0),
		"scale": Vector3(1.2, 1.2, 1.2),
	},
	{
		"id": "interactables_office_chair",
		"family": "office",
		"path": "res://game/art/models/office/chairs/office_chair_black.glb",
		"position": Vector3(-62.0, 0.0, 6.0),
		"rotation_degrees": Vector3(0.0, 25.0, 0.0),
		"scale": Vector3(1.2, 1.2, 1.2),
	},
	{
		"id": "enemy_zoo_street_bottles",
		"family": "kkryy_street_furniture",
		"path": "res://game/art/models/third_party/kkryy_street_furniture/Bottles.fbx",
		"position": Vector3(50.0, 0.0, 6.0),
		"rotation_degrees": Vector3(0.0, -20.0, 0.0),
		"scale": Vector3(1.2, 1.2, 1.2),
	},
	{
		"id": "projectile_office_couch",
		"family": "office",
		"path": "res://game/art/models/office/couches/couch_blue.glb",
		"position": Vector3(-50.0, 0.0, 56.0),
		"rotation_degrees": Vector3(0.0, 180.0, 0.0),
		"scale": Vector3(1.0, 1.0, 1.0),
	},
	{
		"id": "traversal_office_keyboard",
		"family": "office",
		"path": "res://game/art/models/office/computers/computer_keyboard.glb",
		"position": Vector3(35.0, 1.0, -66.0),
		"rotation_degrees": Vector3(0.0, 15.0, 0.0),
		"scale": Vector3(1.2, 1.2, 1.2),
	},
	{
		"id": "visual_lab_pipe_box_ab",
		"family": "loafbrr_pipes",
		"path": "res://game/art/models/third_party/loafbrr_pipes/Scenes/Boxes/pipes_box_ab.tscn",
		"position": Vector3(35.0, 0.0, 64.0),
		"rotation_degrees": Vector3(0.0, 12.0, 0.0),
		"scale": Vector3(0.8, 0.8, 0.8),
	},
	{
		"id": "movement_lab_street_gasmask",
		"family": "kkryy_street_furniture",
		"path": "res://game/art/models/third_party/kkryy_street_furniture/GasMask.fbx",
		"position": Vector3(-50.0, 1.0, -62.0),
		"rotation_degrees": Vector3(0.0, 25.0, 0.0),
		"scale": Vector3(0.9, 0.9, 0.9),
	},
	{
		"id": "hazards_street_hammer",
		"family": "kkryy_street_furniture",
		"path": "res://game/art/models/third_party/kkryy_street_furniture/Hammer.fbx",
		"position": Vector3(50.0, 1.0, -62.0),
		"rotation_degrees": Vector3(0.0, -14.0, 0.0),
		"scale": Vector3(0.9, 0.9, 0.9),
	},
	{
		"id": "interactables_street_flashlight",
		"family": "kkryy_street_furniture",
		"path": "res://game/art/models/third_party/kkryy_street_furniture/Flashlight.fbx",
		"position": Vector3(-50.0, 1.0, 18.0),
		"rotation_degrees": Vector3(0.0, -15.0, 0.0),
		"scale": Vector3(0.9, 0.9, 0.9),
	},
	{
		"id": "interactables_office_computer_mouse",
		"family": "office",
		"path": "res://game/art/models/office/computers/computer_mouse.glb",
		"position": Vector3(-62.0, 1.0, 18.0),
		"rotation_degrees": Vector3(0.0, 15.0, 0.0),
		"scale": Vector3(1.2, 1.2, 1.2),
	},
	{
		"id": "enemy_zoo_office_computer_tower",
		"family": "office",
		"path": "res://game/art/models/office/computers/computer_tower.glb",
		"position": Vector3(50.0, 0.0, 18.0),
		"rotation_degrees": Vector3(0.0, 180.0, 0.0),
		"scale": Vector3(1.2, 1.2, 1.2),
	},
	{
		"id": "projectile_office_tv",
		"family": "office",
		"path": "res://game/art/models/office/computers/TV.glb",
		"position": Vector3(-50.0, 1.0, 64.0),
		"rotation_degrees": Vector3(0.0, -20.0, 0.0),
		"scale": Vector3(1.2, 1.2, 1.2),
	},
	{
		"id": "traversal_office_conference_chair",
		"family": "office",
		"path": "res://game/art/models/office/chairs/conference_chair.glb",
		"position": Vector3(35.0, 0.0, -60.0),
		"rotation_degrees": Vector3(0.0, 180.0, 0.0),
		"scale": Vector3(1.0, 1.0, 1.0),
	},
	{
		"id": "visual_lab_pipe_box_ac",
		"family": "loafbrr_pipes",
		"path": "res://game/art/models/third_party/loafbrr_pipes/Scenes/Boxes/pipes_box_ac.tscn",
		"position": Vector3(35.0, 0.0, 58.0),
		"rotation_degrees": Vector3(0.0, 12.0, 0.0),
		"scale": Vector3(0.8, 0.8, 0.8),
	},
]

var load_errors: Array[String] = []
var spawned_model_count := 0
var _built := false


func _ready() -> void:
	call_deferred("_build")


func _build() -> void:
	if _built:
		return
	_built = true
	for entry: Dictionary in _entries_for_profile():
		_spawn_model(entry)
	set_meta("map_asset_scatter_contract", get_asset_usage_contract())


func _entries_for_profile() -> Array[Dictionary]:
	if placement_profile == "showcase":
		return SHOWCASE_ASSETS
	return BREAKWATER_ASSETS


func get_asset_usage_contract() -> Dictionary:
	var entries: Array[Dictionary] = _entries_for_profile()
	return {
		"version": CONTRACT_VERSION,
		"valid": _built and load_errors.is_empty(),
		"profile": placement_profile,
		"model_assets": _asset_ids(entries),
		"source_families": _source_families(entries),
		"spawned_models": spawned_model_count,
		"errors": load_errors.duplicate(),
	}


func _asset_ids(entries: Array[Dictionary]) -> Array[String]:
	var ids: Array[String] = []
	for entry: Dictionary in entries:
		ids.append(str(entry.get("id", "")))
	return ids


func _source_families(entries: Array[Dictionary]) -> Array[String]:
	var families: Array[String] = []
	for entry: Dictionary in entries:
		var family := str(entry.get("family", ""))
		if not families.has(family):
			families.append(family)
	return families


func _spawn_model(entry: Dictionary) -> void:
	var path := str(entry.get("path", ""))
	var packed := ResourceLoader.load(path) as PackedScene
	if packed == null:
		load_errors.append("Model %s failed to load: %s" % [entry.get("id", ""), path])
		return
	var instance := packed.instantiate() as Node3D
	if instance == null:
		load_errors.append(
			"Model %s did not instantiate as Node3D: %s" % [entry.get("id", ""), path]
		)
		return
	instance.name = "Scatter_%s" % entry.get("id", "model")
	instance.set_meta("asset_id", entry.get("id", ""))
	instance.set_meta("asset_path", path)
	instance.set_meta("asset_family", "model")
	instance.set_meta("asset_source_family", entry.get("family", ""))
	instance.position = entry.get("position", Vector3.ZERO)
	instance.rotation_degrees = entry.get("rotation_degrees", Vector3.ZERO)
	instance.scale = entry.get("scale", Vector3.ONE)
	add_child(instance)
	_disable_collision(instance)
	instance.add_to_group("level_asset_scatter_model")
	spawned_model_count += 1


func _disable_collision(node: Node) -> void:
	if node is CollisionShape3D:
		(node as CollisionShape3D).disabled = true
	elif node is CollisionPolygon3D:
		(node as CollisionPolygon3D).disabled = true
	elif node is PhysicsBody3D:
		var body := node as PhysicsBody3D
		body.collision_layer = 0
		body.collision_mask = 0
	for child: Node in node.get_children():
		_disable_collision(child)
