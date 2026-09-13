# MODUS Standalone Editor

> **Documentation status: maintained reference.** Three-room authoring and gameplay are implemented; dated native-artifact and graphical proof is recorded in [Editor Round-Trip Proof](../../docs/EDITOR_ROUNDTRIP_PROOF.md). This is not a shipped standalone-editor release.

## Current source

- Entry scene: `standalone/editor/main.tscn`
- Entry script: `standalone/editor/standalone_main.gd`
- Embedded editor reused by the entry: `game/editor/embedded_level_editor.gd`
- Export presets: `Standalone Editor` (Windows) and `Standalone Editor Linux`
- Preset outputs: `standalone/editor/editor.exe` and `standalone/editor/modus-editor.x86_64`
- Custom feature: `standalone_editor`

## Implemented in the standalone entry

The script instantiates the embedded editor and creates File, Edit, View, and Help menus. New/open/save/save-as actions use the embedded editor; Undo/Redo uses the shared runtime history manager; Cut/Copy/Paste/Select All route through the selection manager; view toggles are stateful; documentation and shortcut entries show maintained local guidance; and Export as Mod packages the current level through `LevelPackager` into a `.mdsl` archive.

## Author and play the Breakwater gate

Launch source with `godot --path . -- --editor`, or run an exported standalone-editor binary.

1. Use **File → Open Breakwater Station** for a copy of the built-in gate, or **New Level** and the **Modules** tab to assemble the three rooms.
2. For a new layout: place Airlock at the origin; attach Pump `in` to Airlock `out`; attach Control `in` to Pump `out`. The panel reports invalid sockets/clearance without committing a partial edit.
3. In **Gameplay** mode, select source `pump/power_switch`, target `control/security_door` and a channel name, then **Connect gameplay actors**. Undo/redo restores the whole connection.
4. **F5** starts an isolated playtest. Collect the maintenance key, energize the pump-hall switch, pass the raised door and activate the control terminal. During play, **E** interacts, **F5/F9** save/load a checkpoint and **Esc** returns to unchanged author data.
5. Save As, reopen and resave the document. **File → Export as Mod** creates `.mdsl`. The game opens trusted packages through **Open level package**, or `modus.x86_64 -- --level /absolute/path/level.mdsl`.

Packages declare the required host document runtime API and scripts; meshes are serialized into native resources, with package-relative asset paths. Only open trusted packages: Godot scene/script content is executable, not sandboxed.

## Remaining proof boundaries

Focused source regressions and actual headless workflow actions cover document ownership, invalid-root rejection, history, channels, play isolation and package reconstruction. Graphical layout/input feel, every advertised legacy editor tool, cross-platform filesystem failures and real Workshop transfer require their own evidence.

## Export caution

The `standalone_editor` feature selects `standalone/editor/main.tscn`; the client enters `game/main_entry.tscn` and retains its menu plus the Breakwater/package routes. Build with matching Godot 4.7.2 templates. A Linux artifact does not establish native Windows behavior or the bundled Steam/voxel runtime profile.

## Required product proof

- Export the exact preset with Godot 4.7 templates.
- Confirm the native Windows binary starts `standalone/editor/main.tscn`.
- Exercise every visible menu item and remove/disable inert affordances.
- Review the rendered author/connect/play/save/reopen/package workflow and its pointer/keyboard behavior.
- Verify corruption, permissions, paths and overwrite behavior on supported filesystems.
- Finish proof for every legacy menu/tool claim; typed module/channel undo and `.mdsl` have focused automated evidence.
- Run Windows and any other supported OS artifact.

Until the remaining target and graphical evidence exists, this is an implemented authoring/runtime workflow, **not a supported standalone-editor release**.
