# MODUS Editor Round-Trip Proof

> **Documentation status: maintained reference.** This page preserves dated, focused observations, not fresh proof. Published readiness is consolidated in [Current Status](CURRENT_STATUS.md); generated reports and raw logs remain local-only under the [truth contract](DOCUMENTATION_TRUTH.md).

## September 13: Three-Room Native Gate

**Status:** PASS for the focused source and exported Linux headless workflow; graphical acceptance remains blocked.

Godot 4.7.2 source runtime and official Linux release templates exercised the actual standalone editor and game, not copied persistence methods or a mock player.

### Exercised workflow

1. Start the standalone editor; use Modules/Gameplay controls to place airlock → pump hall → control room and connect `pump/power_switch` to `control/security_door`. Undo/redo restores the connection.
2. Save, reopen, resave and reopen the authored document. Root metadata/names, module metadata, nested ownership, actor identities and channels survive; stale history is removed only after successful replacement.
3. Play the document in a private world with the real `Player`. Its capsule is blocked by the closed door and passes when open. The interaction ray collects the maintenance key once; the switch refuses activation without it, then powers the door; the control terminal completes the actual mission.
4. Save and restore pre-gate, powered and completed checkpoints through the existing encrypted game-state service. Keys, actors and mission completion restore without replaying activation.
5. Return to the same unchanged author document, export `.mdsl`, validate/extract its manifest and load its scene without an editor asset importer.
6. Launch the exported Linux game with `-- --level <package.mdsl>` and complete the same gameplay/checkpoint/navigation checks using the editor-produced package.

The authored and packaged document retains **23 meshes, 24,764 vertices, three architectural collision shapes, four actors and one player spawn**. Runtime actor collision is additional to those architectural shapes. The exercised authored package bakes **215 navigation polygons**; queries connect all rooms and the upper pump walkway, including after the blocking door opens.

`PrefabMetadata` owns typed sockets, clearance and capability/dependency metadata. Document-owned channels preserve the original gameplay instigator. OBJ dependencies become native mesh resources; package-local resource references cannot resolve back to source through host UIDs. Packages declare runtime API version 1 and required built-in scripts. This is a trusted-content format, not a sandbox for hostile Godot resources.

Checkpoint-key probing reproduced lost F5/F9 events in the editor play viewport. The viewport now receives keyboard focus and propagates handled input to its parent, preventing a checkpoint shortcut from also triggering global debug controls. Source and rebuilt native editor probes deliver F5/F9/Esc through the root viewport: F5 saves once, F9 restores completed mission state and Esc returns to unchanged author data.

### Focused regressions

| Selection | Result |
| --- | --- |
| `test_editor_history.gd`, `test_editor_roundtrip.gd` | 36/36 tests, 204 assertions |
| `test_prefab_system.gd`, `test_navigation_mesh_baker.gd` | 25/25 tests, 105 assertions |
| `test_level_packager.gd`, `test_level_editor.gd` | 7/7 tests, 42 assertions |

These are separate focused selections, not a refreshed repository matrix. The first two report no GUT orphans; stock-engine exit diagnostics remain. The package/registry selection reports 335 ObjectDB instances, 154 resources and rendering RIDs at exit. The instrumented native editor reports one ObjectDB instance at exit; the native game workflow exits without that warning. No clean-exit claim is made for the editor or those test selections.

### Native artifact boundary

`Standalone Editor Linux` and `Linux Desktop` release exports run from separate local artifact directories under `logs/breakwater_gate/install/`, with private XDG profiles and no host display/session sockets. Their `.pck` files supply product code; raw project scripts are absent from the native resource filesystem.

The official release template ignores `--script` and rejects project-path overrides. Disposable instrumentation therefore enters through the existing trusted local mod loader in the private profile. It activates control signals, injects movement actions and viewport key events, and invokes the player's interaction handler against real physics; neither executables nor PCKs contain a test hook. This is not OS pointer input or manual play. Logs, artifact hashes, authored/resaved scenes and the `.mdsl` remain local-only evidence under `logs/breakwater_gate/`, not published release files.

### Graphical and release exclusions

The reviewed `overzeer-isolated-display` wrapper refused the final graphical attempt with exit 75: `I/O full PSI=58.88% blocked=4`, above its 8% I/O threshold. The guard was not bypassed. An Openbox attempt also found no installed Openbox executable. **No rendered screenshot, mouse-capture behavior, pointer/keyboard feel, audiovisual quality or manual playthrough is claimed.**

The larger composed mission, novice-author usability, pinning/ghost placement/controlled regeneration, automatic generated-record realization, installer, bundled native integrations, native Windows, multiplayer/WAN and Steam/Workshop remain separate acceptance lanes. See [Current Status](CURRENT_STATUS.md) and the [production plan](RELEASE_AND_WORLD_BUILDING_PLAN.md).

## July 13: Historical Serialization Contract

**Run date:** 2026-07-13
**Status:** PASS (focused authoring contract)
**Godot:** `/tmp/modus_godot_4.7/Godot_v4.7-stable_linux.x86_64`

`tests/integration/test_editor_roundtrip.gd` passes 1/1 with 15 assertions under Godot 4.7/GUT. The test creates a small `LevelRoot` with player and enemy spawn points plus a placed actor, saves it through `LevelSaveSystem`, reloads the saved scene, exports the level to a mod folder, reloads the exported `level.tscn`, and verifies the actor names, spawn types, enemy id, and actor id survive both round trips.

The proof covers editor serialization and folder export/reload. It does not claim live editor UI interaction, Steam Workshop upload, multiplayer connectivity, or a rendered/playable manual session; those remain separate evidence lanes.

The slice also repaired two live defects: root-level `LevelRoot` discovery and export-directory/save-result handling. The logger now creates its runtime logs directory recursively, which keeps isolated headless runs from failing before test startup.

## September 13: Embedded Load/Resave Defect

The July result above covers `LevelSaveSystem`, not `EmbeddedLevelEditor.load_level`. A bounded Godot 4.7.2 headless source API probe, then an independent no-autoload probe using exact copies of the embedded save/load methods, reproduced a four-node authored scene becoming a one-node saved scene after load/resave. Children appeared immediately after load, but lost packing ownership; the next save omitted their collision. Saved root metadata was not restored.

The source invocation also reported an unresolved `sync_cursor` identifier in `editor_network_adapter.gd:359`; the isolated persistence-only invocation avoided that dependency and still reproduced data loss, with detached-transform/inconsistent-owner diagnostics. Exit `0` means that investigation completed, not that authoring passed. No graphical/exported editor was exercised or repaired during that pre-fix investigation; the implementation and native evidence above supersede its defect status. See [fixture, observations and cutover](RELEASE_AND_WORLD_BUILDING_PLAN.md#editor-persistence-reproduction).
