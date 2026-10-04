# MODUS Mod and Save Compatibility Policy

> **Documentation status: maintained reference.** Current policy for the public beta format. This page does not certify native-platform acceptance, multiplayer compatibility, or production release readiness.

**Effective:** 2026-10-04
**Game version:** `0.9.5-beta`
**Mod API:** `1`
**Save schema:** `1.0`

## Mod package contract

Every `mod.json` accepted by the repository validator and runtime loader MUST contain:

- `id`: 1–64 characters matching `^[A-Za-z0-9][A-Za-z0-9._-]*$`;
- `name`: a non-empty string;
- `version`: a non-empty release identifier;
- `compatibility.mod_api`: integer `1`;
- `compatibility.save_version`: string `"1.0"`.

Optional fields have these shapes:

- `dependencies`: an array of package IDs. Every dependency MUST be present; self-dependencies are rejected.
- `config_overrides`: an object. Enabled packages cannot claim the same supported override target.
- `scripts`: an array of script paths.
- `assets`, `features`, `components`, and `entities`: objects.

Unknown manifest fields are ignored by the current loader. A package with an invalid required field, compatibility value, dependency, or field shape is rejected before loading. Disabled repository examples remain visible to validation as warnings, not active content.

The package `version` is descriptive metadata. Dependency ranges and automatic package migration are not supported. A mod API or save-schema change requires a new compatible package and an explicit validator/test/doc update; there is no silent downgrade or migration path.

Discovery and load failures are observable: `ModLoader` emits `mod_rejected`
with the package path and normalized errors, and `get_rejected_mods()` returns
the same diagnostics for the current discovery/load pass. Rejected packages
never enter the installed-mod list or enabled load set.

## Save contract

`GameStateManager` writes `version: "1.0"` into every saved world envelope. Loading, network synchronization, and direct world restoration reject a missing or different save version before destructive restoration starts. `SaveService` metadata uses the project version from `project.godot` (`0.9.5-beta`).

Save-schema migrations are not implemented. A future incompatible save format MUST either add a tested migration before changing the accepted version or be rejected with an explicit compatibility error. Existing saves are not silently rewritten.

## Trust and distribution boundaries

Mod scripts are trusted GDScript and are not sandboxed. Asset replacement paths are resolved under the package directory, but the package itself is not a security boundary. PCK/ZIP mounting and unmounting, Workshop delivery, multiplayer synchronization, and public hosting compatibility remain separate release work.

This policy covers repository validation and local runtime acceptance. It does not claim signed artifacts, native Windows/macOS acceptance, Steam/Workshop support, WAN behavior, or balance quality.

## Verification

Focused checks:

```bash
godot --headless --path . --script res://tools/validate_mod_packages.gd
```

The validator behavior is covered by `tests/unit/test_mod_package_validator.gd`; save-version rejection is covered by `tests/unit/test_autoload_consolidation.gd`.
Runtime rejection diagnostics are covered by `tests/unit/test_mod_reload.gd`.
