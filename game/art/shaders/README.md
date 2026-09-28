# Shaders

This directory contains the shader code (`.gdshader`) used for visual effects in the game.

## Retro Liquid Shaders

A suite of retro-styled animated liquid shaders inspired by Quake/Half-Life.

- **`retro_water.gdshader`**:
  - Features: Animated vertex waves, depth-based color absorption, edge foam, specular highlights.
  - Usage: Apply to a PlaneMesh.
  - Parameters: Wave speed, amplitude, foam threshold, deep/shallow colors.

- **`retro_lava.gdshader`**:
  - Features: Scrolling texture base, bubbling animation brightness pulsing, crust formation.
  - Usage: Apply to a PlaneMesh.
  - Parameters: Scroll speed, glow intensity, crust amount.

- **`retro_poison.gdshader`**:
  - Features: Toxic green/purple gradient, bubbling sludge animation, flow distortion.
  - Usage: Apply to a PlaneMesh for acid pools or toxic waste.
  - Parameters: Flow speed, bubble density, toxic glow.

- **`retro_blood.gdshader`**:
  - Features: Thick, viscous red liquid with coagulation patterns (darker clots).
  - Usage: Apply to a PlaneMesh for blood pools or gore effects.
  - Parameters: Flow direction, viscosity (via noise scale), blood freshness color.

## Utility Shaders

- **`liquid.gdshader`**: Generic liquid shader with vertex wobble and UV scrolling.
- **`post_process.gdshader`**: Screen-space effect for dithering and color quantization.

## Third-party water shader

- **`third_party/binbun_water/water.gdshader`** and **`water_toon.gdshader`**:
  - Binbun's CC0 Godot Water shaders with depth-aware colour, refraction, displacement, foam, and optional caustics.
  - The imported materials are `game/art/materials/liquids/binbun_water.tres` and `binbun_water_toon.tres`.
  - The isolated review scene is `game/world/test_scenes/binbun_water_demo.tscn`; the shaders remain optional and do not replace the project-owned liquid materials.

## Third-party Binbun sky shader

- **`third_party/binbun_skies/main.gdshader`**:
  - Binbun's CC0 Godot Skies shader with directional-light sun/moon tracking, day/sunset/night blending, procedural cloud layers, and stars.
  - The imported procedural noise resources and derived `Sky` preset are under `game/art/materials/sky/third_party/binbun_skies/`.
  - The isolated review scene is `game/world/test_scenes/binbun_skies_demo.tscn`; the optional third-party sky does not replace the project-owned sky resources or claim the golden route.
- MODUS defaults to the Compatibility renderer, so the demo keeps a solid-color fallback there; Forward+/Mobile visual review remains required before runtime adoption.
