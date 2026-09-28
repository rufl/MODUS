# CC0 Asset Search List

> **Documentation status: maintained reference.** This is the acquisition checklist for CC0 material that can finish the test-map presentation without replacing working gameplay systems.

## Purpose and scope

This list separates **missing presentation assets** from systems that already work with procedural or primitive visuals. “Missing” means that a reusable authored asset is not currently available in the canonical content path, or that the current map uses a flat/procedural placeholder where final review needs a readable surface, prop, decal, or sound. It does **not** mean the map is unplayable.

The scope is:

- the [Comprehensive Showcase](../game/world/maps/comprehensive_showcase.tscn) and its six test zones;
- the generated showcase path in `game/world/maps/generate_showcase_level_v2.gd` and `game/world/maps/map.tscn`;
- the authored Breakwater mission and its eleven rooms;
- `game/world/maps/dm_arena_01.tscn` only if it remains in the final test-map set.

The search target is **CC0 / public-domain dedication with source evidence**, not merely “free,” “royalty-free,” or “commercial use allowed.”

## Current 3D prop style gate

New prop candidates must match the MODUS stylized industrial language: PSX/PS2/HL2-era low-poly forms, readable silhouettes, restrained geometry, and low-resolution authored textures. Earlier high-poly/high-resolution recommendations are rejected for this target and must not be imported as-is.

Default acceptance targets:

- Repeated dressing props: roughly 500–2,500 triangles each with a 128–512 px texture or atlas.
- Hero/interactable props: roughly 2,500–8,000 triangles, normally using 512 px textures; allow 1024 px only when silhouette or label readability requires it.
- Reject 2K/4K texture packs, photoreal scans, dense subdivision, baked microdetail, expensive material stacks, and proprietary/ripped HL2 or PS2 assets.
- Use `PSX`, `PS2 low poly`, `Half-Life 2-era low poly`, `retro industrial`, and `Source-style low-poly` as visual search terms only. Import only candidates with clear CC0/public-domain rights.

## Already covered — do not search for duplicates

| Area | Already present | Search decision |
| --- | --- | --- |
| RetroUrban surface library | 240 source texture maps and 40 derived materials under `game/art/textures/retro_urban/` and `game/art/materials/retro_urban/` | Do not replace it. It is CC BY 4.0, not CC0; preserve attribution. It supplies useful pavement/concrete variants but does not cover every industrial or coastal surface. |
| PSX walls and fences | Canonical GLB set under `game/art/models/fences/` | Do not search for another fence/wall pack unless a missing shape is demonstrated. |
| PSX office props | Canonical GLB set under `game/art/models/office/` | Do not search for another office pack. The current gap is industrial/coastal machinery and controls. |
| Brackeys VFX | Particle textures and flipbooks under `game/art/textures/vfx/brackeys/` | Do not search for generic fire/smoke/spark sheets first. Search only for uncovered water spray, steam, electrical arc, dust, and impact variants. |
| First-person arms | `game/art/models/first_person/wrad_arms/arms.glb` and supplied skins | Do not search for another arms model. |
| Breakwater architecture and ambience | Native Breakwater module geometry/materials and six original synthesized ambience streams under `game/levels/modules/breakwater/` and `game/art/audio/breakwater/` | Do not replace the authored room kit or six base loops. Search for modular detail props, surface variation, control visuals, and optional layered one-shots. |
| Loafbrr Pipes Asset Pack | `game/art/models/third_party/loafbrr_pipes/` supplies 50 modular pipe-set scenes, valves, utility boxes, pipe stickers, and source materials under CC0. | Do not search for another modular pipe/valve/utility-box pack. The remaining I-01 gap is a cohesive panel/console kit with push buttons, keypad/card reader, gauges, status lamps/screens, junction boxes, conduit, and cable bundles. |
| Liquid shader logic | Project-owned `retro_water`, `retro_lava`, `retro_poison`, and `retro_blood` shaders/materials, plus the optional CC0 Binbun Water shader/material review under `game/art/shaders/third_party/binbun_water/`, `game/art/materials/liquids/binbun_water*.tres`, and `game/world/test_scenes/binbun_water_demo.tscn` | Do not replace the project-owned liquid shaders. The Binbun source is an optional comparison/integration candidate; continue searching for compatible texture inputs and supporting foam, caustic, splash, and shoreline assets. |
| Sky shader source | `game/art/shaders/third_party/binbun_skies/`, `game/art/materials/sky/third_party/binbun_skies/`, and `game/world/test_scenes/binbun_skies_demo.tscn` | Binbun's CC0 Godot Skies source shader and procedural noise resources are retained as an optional review/demo path; they do not replace the project-owned sky resources or establish golden-route visual/performance proof. |

License paths and current provenance are maintained in [Licensing and Provenance Inventory](ATTRIBUTION.md) and [Retained Third-Party License Records](licenses/README.md).

## Priority 0 — shared assets with the highest map coverage

These should be searched before one-off room props. One good modular kit can improve every test map and the Breakwater route.

| ID | Search target | What to find | Search phrases | Used by | Preferred deliverable |
| --- | --- | --- | --- | --- | --- |
| W-01 | Water surface texture kit | Seamless water colour/albedo, tiling normal, grayscale distortion/noise, foam/shoreline mask, and optional caustic/ripple sheet. The current `retro_water` material exposes distortion and foam inputs but has no imported texture set; Breakwater coastal water uses a generated noise normal and flat coast-rock colour. | `CC0 seamless stylized water PBR normal foam mask`, `CC0 low poly ocean caustics`, `CC0 shoreline foam texture`, `CC0 water ripple flipbook` | `map.tscn`, generated showcase liquids, Breakwater dock/cavern/return | PNG/TGA maps at 128–512 px, tileable; OpenGL normal orientation identified; no baked sky, horizon, or camera. A small Godot material example is useful but optional. |
| W-02 | Water effect support | Edge foam, shore wetness, underwater caustics, splash rings, droplets, spray, and a small looping surface ripple/foam flipbook. | `CC0 water splash sprite sheet`, `CC0 foam particle texture`, `CC0 underwater caustic tile`, `CC0 stylized water spray` | Coastline, basin, hazards arena, liquid test surfaces | Transparent PNG/TGA sheets with frame layout documented; separate masks preferred over a single baked composite. |
| M-01 | Industrial surface material kit | Tileable concrete, wet concrete, painted enamel, dark metal, galvanized metal, rust/oxidation, grating, brass/copper, black rubber, glass, ceramic/tile, and dirty/wet variants. Current Breakwater role materials are intentionally small and mostly colour/roughness driven; Showcase floors and ramps still use flat/prototype assignments. | `CC0 low poly industrial PBR texture`, `CC0 stylized wet concrete tile`, `CC0 painted metal rust trim sheet`, `CC0 sci fi grating material`, `CC0 galvanized metal texture` | Every Showcase zone; dock, pump, intake, turbine, relay, and return rooms | Tileable albedo plus normal/roughness/metallic/AO where available; 128–512 px; one consistent stylized/PSX scale rather than photoreal 4K scans. |
| D-01 | Trim and decal atlas | Yellow/black hazard stripes, red/white emergency stripes, arrows, floor lanes, room IDs, maintenance labels, caution symbols, numbered range markers, waterline stains, leak streaks, grime, edge wear, and small panel labels. | `CC0 industrial hazard decal atlas`, `CC0 sci fi warning decals`, `CC0 low poly maintenance labels`, `CC0 hazard stripe trim sheet` | Showcase navigation/readability; Breakwater intake, pump, turbine, relay, dock | Transparent PNG/TGA atlas with non-baked text variants; source files or a clear license record; avoid real company logos. |
| I-01 | Reusable interaction hardware kit | Panel/console body, toggle switch, momentary push button, hold button, emergency-stop button, breaker/lever, key switch, keypad/card reader, valve wheel, gauge, status lamps, small screen, junction box, conduit, and cable bundles. Chilly Durango's retro machinery pack covers switches, breaker/fuse, valve, pipes, wires, and machinery; loafbrr's Pipes Asset Pack now adds 50 modular pipe sets, valves, utility boxes, and stickers. The remaining gap is a cohesive panel/console, push-button, keypad/card-reader, gauge/status/screen, junction/conduit, and cable-bundle kit. | Interactables Demo; generated showcase switches/buttons/doors; Breakwater pump, intake, relay, return | Modular GLB or Godot scene set, metre scale, separate pieces for controls and indicator lamps, sensible pivots, 500–2,500 triangles for repeated pieces, no gameplay collision by default. |
| I-02 | Door, lift, and platform presentation kit | Industrial door face, frame trim, lock/light module, lift gate, handrails, platform edge, elevator call panel, and mechanical travel details. Existing door/platform mechanics can receive visual children; do not replace their collision or scripts. | `CC0 PSX low poly sci fi door`, `CC0 PS2 low poly elevator gate`, `CC0 Half-Life 2-era maintenance lift`, `CC0 retro industrial door frame` | Interactables Demo, Traversal Course, Breakwater airlock/return route | GLB parts with open/closed-compatible pivots or static dressing variants; 500–2,500 triangles for repeated parts, 2,500–8,000 for a hero assembly, 128–512 px texture/atlas, no baked collision. |
| A-01 | Shared audio one-shots | Switch/button/lever click, breaker clunk, emergency-stop thunk, key/card reader beep, denied/locked beep, door servo open/close, platform/elevator start/stop, pickup/key, UI confirm/error, timer beep, teleport in/out, jump-pad launch, and slipgate hum. | `CC0 industrial switch click`, `CC0 sci fi panel button beep`, `CC0 hydraulic door servo`, `CC0 elevator motor one shot`, `CC0 teleport whoosh`, `CC0 jump pad sound`, `CC0 machinery clunk` | All test maps and interaction demos | Luka Aleksic's imported CC0 pack now covers pickup, door open/close, and switch overrides; continue searching for the remaining short one-shots. WAV or OGG; mono for 3D events; 44.1/48 kHz; supply loop points for hums. |
| A-02 | Shared environmental audio | Ocean/waves, rain, wind, sheltered wind, cavern drips, pump/machinery hum, turbine/rotor loop, electrical buzz/arc, warning alarm, water splash, steam hiss, metal impact, and grating/concrete footsteps. | `CC0 coastal storm ambience loop`, `CC0 industrial pump loop`, `CC0 turbine machinery loop`, `CC0 electrical arc sound`, `CC0 cavern drip ambience`, `CC0 metal grating footsteps` | Showcase weather zones; Breakwater dock/cavern/pump/turbine/relay; movement and traversal tests | Loopable WAV/OGG with clean endpoints and source duration; provide mono/stereo intent and loudness notes. |
The supplied cooler11 Very Simple Waves Pack now covers two Breakwater coastal sources with four imported WAV variants. It is a restricted game-use exception documented at `docs/licenses/VERY_SIMPLE_WAVES_PACK_GAME_USE.txt`, not CC0/public-domain material; do not redistribute it as a standalone or asset pack, and continue the CC0 search for unrestricted environmental loops.

### Audio files that are specifically absent today

The runtime now has committed one-shot assets under `game/art/audio/sfx/luka_aleksic/`; its safe overrides cover pickup, door open/close, and switch events. The remaining direct-load gaps are:

- `game/art/audio/sfx/jump_pad.wav` — required by `shared/editor_core/actors/jump_pad_actor.gd`;
- `game/art/audio/sfx/teleport.wav` — required by `shared/editor_core/actors/teleporter_actor.gd`.

The event catalogue in `game/config/gameplay/audio_overrides.json5` still leaves the remaining world/interaction and movement events open for file overrides. The procedural audio fallback keeps those events functional, so these are **presentation-completion searches**, not a reason to change the audio API.

There is no committed music track in `game/art/audio/music/`. Add music only after the map ambience and interaction sounds are covered; it is optional for test-map completion.

## Priority 1 — map-specific search targets

### Comprehensive Showcase

| Map/zone | Missing or weak presentation | Search phrases | Minimum useful result |
| --- | --- | --- | --- |
| HubFloor / shared platform | A single clean pavement material and labels do not provide enough surface variation, wayfinding, or vertical interest. | `CC0 modular sci fi corridor trim`, `CC0 industrial floor tile`, `CC0 low poly maintenance sign`, `CC0 modular column pipe kit` | One compatible floor/wall/trim family, modular columns or pipe racks, and a small sign/decal atlas. |
| Movement Lab | Ramp and course geometry are primitive/flat; movement boundaries and route direction need stronger visual language. | `CC0 movement course arrows decals`, `CC0 industrial ramp hazard stripes`, `CC0 low poly training obstacle` | Floor lane/arrows, edge strips, ramp material, and a few reusable obstacle markers. |
| Hazards Arena | Hazard volumes and props use readable debug colours but need authored hazard surfaces, barriers, warning stripes, and liquid/steam/impact feedback. | `CC0 hazard floor tile`, `CC0 sci fi warning barrier`, `CC0 acid pool edge`, `CC0 steam vent low poly`, `CC0 hazard stripe decal` | Hazard floor/edge material, barrier/vent prop, warning decals, and one liquid/splash or steam effect. |
| Interactables Demo | Button stand, lever, door, platform, and trigger visuals are primitive or untextured. | `CC0 industrial button stand`, `CC0 lever switch panel GLB`, `CC0 sci fi door frame`, `CC0 cable junction box` | One interaction hardware kit from I-01 plus a door/panel visual and cables/conduit. |
| Projectile Range | Range floor, walls, weapon rack, targets, backstop, and distance markers need authored shooting-gallery dressing. | `CC0 low poly shooting range target`, `CC0 sci fi target panel`, `CC0 industrial backstop`, `CC0 weapon rack GLB`, `CC0 range marker decals` | Target panels with replaceable bullseyes, backstop, range markings, and one rack/fixture. |
| Traversal Course | Ladders, ropes, slipgates, jump pad, teleporter, moving platform, and elevator are mostly generated/primitive presentation. | `CC0 industrial ladder GLB`, `CC0 rope cable bridge`, `CC0 sci fi teleporter pad`, `CC0 jump pad platform`, `CC0 elevator lift hardware` | One traversal hardware family, strong emissive/status treatment, and A-01 sounds for jump/teleport/platform. |
| Visual Tweaking Lab | Reload button, sample walls/floors, labels, and target fixtures are debug-style; the lab needs material comparison panels and a usable console. | `CC0 material sample panel`, `CC0 sci fi monitor console`, `CC0 industrial reload button`, `CC0 LED status panel` | Console/button visual, 3–6 swappable surface sample panels, and small emissive indicators. |

### Generated showcase and legacy map

| Area | Missing or weak presentation | Search target |
| --- | --- | --- |
| `map.tscn` liquid tests | Water/lava/poison/blood materials already exist procedurally; the gap is authored texture support, edge treatment, caustics, splashes, and readable hazard boundaries. | W-01, W-02, D-01; do not replace the four project-owned liquid shaders. |
| Generated switches/buttons/doors | The generator places six switch/button interactions and door/secret-wall tests, but their visuals are generated primitives. | I-01, I-02, D-01, A-01. |
| Weather zones | Clear/windy/storm/rain/snow zones need weather-specific audio and contact/particle textures rather than more generic fire/smoke sprites. | A-02 plus CC0 rain splash, snow impact, wind-blown debris, and storm electrical textures. |
| `dm_arena_01.tscn` if retained | CSG floor/walls/platform/ramp have no authored material assignment. | M-01, D-01, plus a small cover/rail/barrier kit. Lower priority than the Showcase and Breakwater route. |

### Breakwater authored mission

The Breakwater route already has authored geometry, role materials, collision, lighting stages, and six synthesized ambience streams. Search for **detail dressing and material variation**, not another architecture pack.

| Rooms | Search target | Useful asset families |
| --- | --- | --- |
| Dock, hub, return landing, return, return gallery, return elbow | Coastal arrival and service-area detail | Wet deck/concrete, seawall/rock, bollards, ropes, mooring hardware, crates, barrels, pallets, containers, lamps, handrails, warning signs, cables, puddles, shoreline foam. |
| Pump | Machinery silhouette and readable controls | Pump housing, valves, pipe elbows, pressure gauges, flanges, maintenance ladders, cable trays, breaker/control panel, warning decals, leak/steam effects. |
| Intake | Hazard teaching and timed crossing | Grates, conductors/insulators, arc barrier hardware, pipe runs, warning panels, emergency lights, wet concrete, splash/steam/electrical arc effects. |
| Cavern | Coastal cavern readability and water edge | Tiled/wet rock, rock rubble, stalactite/stalagmite variants, water basin/shoreline foam, drips, algae/seaweed, cave lamps, cable/rail detail. |
| Turbine | Large-machine focal point | Turbine housing, rotor/fan, pipe manifolds, vents, gauges, catwalk rails, cable bundles, hazard stripes, rotating machinery loop, sparks/steam. |
| Relay / crown | Mission endpoint silhouette and power-state readability | Relay cabinet, transmitter console, antenna detail, display/screen, status lamps, insulators, conduit, warning plaques, beacon/emissive lens, electrical hum/arc. |
| Return route | Changed-place proof after power restoration | Lift/bridge hardware, railings, maintenance platforms, powered lamps, cable trays, open/closed gate dressing, replacement status panels. |

## Priority 2 — polish after the shared kit works

Search these only after W-01, M-01, I-01, and A-01/A-02 have candidates:

- grime, rust, salt streaks, wetness, oil leaks, edge wear, chipped paint, moss/algae, and puddle decals;
- crates, barrels, tools, buckets, pallets, spare parts, cable coils, hoses, pipe sections, fans, vents, lamps, emergency beacons, and maintenance clutter;
- water spray, steam, dust, rain splash, sparks, electrical arcs, ricochet/impact marks, and low-cost flipbooks not already covered by Brackeys VFX;
- optional CC0 music or low-volume tension loops for Showcase and Breakwater, after environmental loops are mixed and approved.

## Acquisition constraints

### Licensing and provenance

- Accept only CC0 / public-domain material with a source page and license text that can be retained in `docs/licenses/`.
- Direct user-supplied runtime material may be imported only when the retained terms explicitly grant game use; record it as a non-CC0 dependency, preserve every redistribution restriction in `docs/licenses/`, and never present it as an unrestricted acquisition candidate.
- Record the author, source URL, exact asset/archive name, download date, archive hash, and any attribution/credit requirement even when the source says CC0.
- “Free,” “open,” “royalty-free,” “free for commercial use,” or “no attribution required” is not sufficient without the actual license terms.
- Do not import logos, recognizable commercial signage, scraped game assets, or packs with mixed/unclear licenses.
- Every accepted asset must be added to the provenance ledger and pass the repository’s provenance check before it is treated as cleared. See [Licensing and Provenance Inventory](ATTRIBUTION.md).

### Models

- Prefer GLB/glTF as the canonical runtime format; OBJ is acceptable only as a source that will be deliberately converted. Do not make FBX/BLEND the runtime dependency.
- Require metre-scale dimensions, sensible origin/pivot, readable silhouette at gameplay distance, and no hidden external dependencies.
- Prefer modular pieces and variants over a single hero mesh. Keep repeated dressing within the style-gate triangle budget; supply LODs only when they preserve the low-poly silhouette rather than adding hidden density.
- Imported dressing must not add gameplay collision unless a separate collision asset is explicitly needed and reviewed.
- Match the existing stylized/low-poly industrial language; reject photoreal scans, dense subdivision, and high-resolution hero assets that make the prototype surfaces inconsistent.

### Textures and materials

- Prefer tileable PNG/TGA maps at 128, 256, or 512 px. Allow 1024 only for a singular hero/interactable when readability requires it; reject 2K/4K maps for routine props.
- Albedo/emissive maps use sRGB intent; normal, roughness, metallic, AO, height, and masks use linear intent.
- Identify normal-map Y orientation. Prefer OpenGL/+Y normals or include conversion instructions.
- Keep text, logos, and room-specific labels out of reusable texture atlases; use separate decals or Godot labels.
- For water, prefer separate colour, normal/distortion, foam/shoreline, and caustic inputs. Do not provide a baked ocean horizon or camera-specific composite.

### Audio

- WAV or OGG; 44.1 or 48 kHz; clean starts/ends; loop points documented for ambient/machinery files.
- Mono for positional one-shots and local machinery where possible; stereo only when the spatial source is intentionally environmental.
- Supply short variants or pitch-safe one-shots for repeated switches, footsteps, impacts, and alerts.
- Avoid clips with speech, music beds, or distinctive third-party samples unless their license explicitly covers redistribution and editing.

## Candidate worksheet

Fill one row per candidate before importing it:

| ID | Source URL and asset name | License proof retained | File format / size | Target map(s) | Import notes | Accepted / rejected |
| --- | --- | --- | --- | --- | --- | --- |
|  |  |  |  |  |  |  |
|  |  |  |  |  |  |  |
|  |  |  |  |  |  |  |
|  |  |  |  |  |  |  |
|  |  |  |  |  |  |  |

## Completion definition

A search item is complete only when the candidate is imported into the intended map or canonical asset folder, the visual/audio result is reviewed in the actual map, the source/license record is retained, and the asset is either registered for reuse or intentionally rejected. A download without provenance and map-level review is not completion.

For current proof boundaries and open audiovisual review, see [Known-Limits Matrix](KNOWN_LIMITS_MATRIX.md), [Current Status](CURRENT_STATUS.md), and [Release and World-Building Plan](RELEASE_AND_WORLD_BUILDING_PLAN.md).
