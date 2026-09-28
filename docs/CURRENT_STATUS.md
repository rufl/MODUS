# MODUS Current Status

> **Documentation status: maintained reference.** This is the consolidated published snapshot; fresh verification records are dated below. Generated reports and raw logs are local-only; each report describes its own invocation.

**Updated:** September 28, 2026 <!-- craft-ignore: status sheet uses deliberate labels -->
**Version:** `0.9.5-beta`  
**Engine:** Godot 4.7+  
**Project status:** Alpha-quality codebase with a pre-alpha evidence boundary  
**Production readiness:** **NOT READY**

## Summary

MODUS contains broad FPS framework code plus focused and golden-demo runtime proof, but reviewed manual gameplay evidence is absent and the release-version gate is blocked. The September 25 strict headless aggregate passes 1,665/1,665 tests with 22,767 assertions across 149 scripts; two GUI-required files remain skipped. Focused runtime, package, multiplayer, editor, generator and bounded performance evidence are retained by named lanes. Platform executable exports, signed release packaging, manual gameplay, target-Windows runtime and external-service proof remain open.

The canonical publication rules are in [Documentation Truth](DOCUMENTATION_TRUTH.md).

Publication cleanup preserves old local evidence without refreshing it. Fresh clones retain this summary, maintained guides, licenses, and curated media—not raw `logs/`, historical session/archive files, or generated reports. See [local report regeneration](DOCUMENTATION_TRUTH.md#regenerating-local-reports) for commands and prerequisites. Missing local inputs must remain missing evidence; earlier PASS results below are dated observations, not checkout guarantees.

### September 22 Release Engineering

Portable schema-v1 manifests now cover all client/server/editor executable/PCK pairs with root-relative paths, SHA-256 hashes and optional commit/runtime identity. Verification rejects corrupted, missing, duplicated or escaping payloads. Candidate staging requires identity, verifies before and after copying, and refuses existing destinations. Detached-signature metadata is an integrity record, not signature authentication. OVERZEER and ZTASH release inventories now also record the SHA-256 digest of the checked-in toolchain lock used for assembly.

The Linux helper now validates archive ownership/bytes/modes before extraction and replacement, supports rollback, and preserves unowned files and XDG data. The former upgrade path's deletion of an unowned file was reproduced. Three focused regression runners pass manifest relocation/tampering, staging failure isolation, malicious archives, failed-upgrade rollback and save preservation. A retained September 13 client executable passes package/install/verify/headless-launch/upgrade/verify/uninstall under a Unicode/space prefix; it was not rebuilt in this batch.

CI builds Linux client and editor alongside its existing targets and assembles versioned Linux and OVERZEER candidates. The checked-in `tools/toolchain.lock.json` pins Godot/GUT/GDScript Toolkit/SCons versions, the patched Godot source revision and downloaded archive hashes; the validator, GUT installer and CI download steps reject drift or corrupted archives. Native runtime/dependency bundling, signing/authentication, release publication, Windows runtime and manual acceptance remain open.

The Windows acceptance harness now records actual W movement, Space jump and E interaction outcomes, reliable application-level ENet probes, reconnect/soak and controlled host-loss evidence, renderer/viewport/window/GPU/API/OS metadata, plus same-build manifest/commit/hash metadata, the copied toolchain lock and its SHA-256 digest, and retained logs. Linux boundary regressions pass; no native Windows execution, independent WAN session, or authenticated Steam session is claimed.

The OVERZEER package contract emits `README.md`; fresh Godot 4.7.2 client/server/editor exports were packaged for Linux and Windows, strict four-format inventory validation passed, and the extracted Linux `--package-smoke` path exited cleanly. The source/package-smoke regression now covers user-argument dispatch without script errors; CI export manifests will record the toolchain-lock digest and native acceptance verifies that binding. Authenticated receiver publication, signing, and native target smoke remain open.

September 28 current artifact proof: commit `16cc7f4f1b5316eb2df609f0c8790b7efa8e3acb` produced fresh Godot 4.7.2 Linux client/server/editor and Windows client/editor exports. All four OVERZEER formats and lean ZTASH archives passed strict inventory/hash validation; source and extracted Linux `--package-smoke`, Linux client/server export smoke, package reproducibility, and ZTASH preparation regressions passed; and ZTASH preview passed against the registered DDJARIN/CHOPPER endpoints. Direct authenticated CHOPPER deployment completed for the Linux archive (`65efea85656e2be588f4b348d206e86d96099da320cd2ba854897d5b247156f0`); the combined DDJARIN/CHOPPER apply stopped safely at DDJARIN `RemoteDeploymentPollingExceeded`, so no Windows publication or native acceptance claim is made. Windows runtime was not executed on Linux; packages are unsigned and native target, manual, Steam/Workshop/WAN and 1.0 release gates remain open.

September 28 capability and artifact refresh: commit `b1cca0b418db8968dbbd036932f8b9a8b2ae409a` now publishes a versioned runtime capability manifest, detects native CSG/MultiMesh/occlusion classes through `ClassDB`, derives omitted `ModuleAssembly` capability policy from the runtime, and skips unavailable optional generation passes. Fresh Godot 4.7.2 exports passed strict four-format inventory/hash validation, source/extracted Linux `--package-smoke`, Linux client/server export smoke and ZTASH preparation. CHOPPER deployed the lean Linux archive (`2074c2cfa312e728a5f694d19b9fa4c9b4fe369cb4d0d57d2fd13b4e5f90c69b`, 83562624 bytes); DDJARIN returned `AccessDenied` while validating/smoke-testing the Windows candidate and did not change its active deployment. Signing, bundled native dependencies, Windows execution and manual acceptance remain open.

September 28 packaged capability artifact refresh: commit `255d01b79a3efa5600baea1b2445084014fb47e1` produced fresh Godot 4.7.2 Linux client/server/editor and Windows client/editor exports. Four-format OVERZEER inventory/hash validation, lean ZTASH preparation, source/extracted Linux `--package-smoke` and `--capability-report`, Linux client/server export smoke and registered-endpoint preview passed. A private Wine Windows package attempt did not terminate and is not counted as proof. CHOPPER deployed lean Linux `f864849f76e2b774ecb31a4a99ceeef630cb45d17efe5c946af49f11e492cb53` (83564226 bytes); DDJARIN returned `AccessDenied` during Windows validation/smoke and did not change its active deployment. Packages remain unsigned; native Windows, Steam/Workshop/WAN, signing and manual acceptance remain open.

September 28 dependency-diagnostic artifact refresh: commit `5dd75fdf2cb942a0f1306293a74c722273d3513d` produced fresh Godot 4.7.2 Linux client/server/editor and Windows client/editor exports. Four-format OVERZEER validation, lean ZTASH preparation, extracted Linux `--package-smoke` and `--capability-report`, Linux client/server export smoke and registered-endpoint preview passed. CHOPPER deployed lean Linux `2479fd14873be1fe825cc96b1c21429940225edb370154ec6e8e0cd34c8b7bc9` (83566924 bytes); DDJARIN returned `AccessDenied` during Windows validation/smoke and did not change its active deployment. Packages remain unsigned; native Windows, Steam/Workshop/WAN, signing and manual acceptance remain open.

### September 22 Persistent Hub Travel

Authored sessions preserve the host transport and player nodes across staged, validated destination commits. Revisit records retain actor/objective state and consumed rewards; encrypted campaign checkpoints restore into a fresh session. Late joiners validate content before receiving the current destination and party, with replication gated on acknowledgement.

The completed delivery passes 40 focused tests/263 assertions and actual hub → mission → hub console interaction headlessly. This batch rechecked the three hub tests (**3/3, 45 assertions**) and the separate-process ENet scenario: content refusal, revisits, living/cleared encounters, late join and disconnect during preparation all pass. This is not host migration, cross-build save compatibility or graphical acceptance.

### September 22 Authoring and Network Cadence

Persistent pins, socket-following visual-only ghosts and bounded partial regeneration now work through the shared standalone/embedded editor. Regeneration retains module IDs/poses, pinned objects, complete loop/boundary connections and valid channel/objective references. Planning and previews stage detached content; failure preserves live objects/history, and commit is one undoable transaction. Mode/document/history transitions invalidate pending ghosts.

**73/73 focused tests, 483 assertions** pass across prefab assembly, module authoring, authored missions, network manager, weapon validation and weapon synchronization. Twenty actual standalone-editor checks pass headlessly, including pin/save/reopen, regeneration/undo/redo, ghost cancellation and single Enter placement. The isolated graphical attempt deferred on the occupied display lock; no rendered or exported-app evidence is refreshed.

The movement limiter now uses a monotonic microsecond token bucket instead of minimum packet spacing. Movement retains a sustained 60-command/s limit with at most eight coalesced catch-up commands; other RPC policies retain one-call burst capacity. Deterministic tests cover ten seconds of jittered input, floods, per-peer isolation and bounded idle credit. Whitelist, sender and payload validation remain in force.

Real host/client CLI join/disconnect completed without engine/script errors; two movement burst-limit rejections remain in that run. The cap was retained rather than increased until warnings disappeared.

### September 23 Capability and Generated Progression Contract

Generated and authored content now carries a versioned capability manifest with runtime identity, required capabilities and explicit fallback diagnostics. Destination staging and network admission reject malformed, mismatched or unavailable capabilities before instantiation or peer spawn; common walk/CSG content remains available without Voxel Tools. Key/lock generation publishes deterministic key, lock, objective, recovery-route, room-ID and room-edge metadata transactionally; recovery routes begin at the configured player room, choose a real deterministic path to extraction or the true farthest reachable room, disconnected graphs, forged edges and locks without actual room adjacency are rejected before publication, and MissionMgr accepts valid branching edges outside the recovery route, rejects disconnected declared graphs and preserves legacy manifests without room IDs. `MissionGraphPlanner` now owns topology validation, deterministic route selection and linear/branching/cyclic profile metadata before lock placement. `ModuleLayoutSolver` realizes tree-shaped mission graphs and cyclic graph spanning trees with deterministic least-used catalog selection, bounded breadth/depth spanning-tree alternatives, socket transforms, bounded loop-socket closure search, clearance checks and rejection diagnostics; valid plans attach authored `ModuleInstance` scenes and graph connections to generated `LevelRoot` documents, while unsupported cyclic geometry remains non-destructive with explicit metadata errors. Spatial attachment now rejects duplicate room identities, malformed transforms and empty plans before mutating the document. Generated actor realization publishes packed record/count diagnostics for enemy, pickup, key, door and extraction actors; generated gameplay retains a bounded encounter manifest with proportional weapon/ammo/health floors, per-room resource counts and impossible-composition refusal; health balancing preserves the floors. Every authored catalog definition passes single-room solve/attach coverage.

The focused capability/prefab/mission selection passes **43/43 tests with 299 assertions**; the deterministic generator selection passes **6/6 with 191 assertions**. Planner/key-lock graph regressions pass **14/14 tests with 48 assertions**, generator actor/composition realization and impossible-resource refusal passes **22/22 tests with 544 assertions**, standalone package overwrite protection passes **6/6 with 17 assertions**, authored mission validation passes **10/10 with 96 assertions**, and spatial solver/catalog/attachment selection passes **10/10 with 100 assertions**. The generated 32×32 LevelRoot smoke requires a valid spatial plan, preserved attached connection metadata, catalog usage diagnostics, exact actor realization diagnostics and a valid encounter manifest. This proves source and headless contracts; manual balance and rendered audiovisual review remain open.
Encounter placement now refuses shared actor/resource grid cells and retains early/mid/late progression bands plus collision diagnostics in packed gameplay metadata. The focused placer proof remains **13/13 tests with 75 assertions**; current tuning and authored pickup behavior are covered by the dedicated encounter suite. The resource contract is automated; human balance acceptance remains open.
September 28 capability-contract refresh: `FeatureAvailability` now detects CSG, MultiMesh and occlusion classes through `ClassDB`, includes the detected runtime capabilities in its snapshot/report, and uses canonical aliases for admission. `ModuleAssembly` resolves omitted capability sets from the detected runtime, and map generation skips unavailable optional batching/culling passes. The focused prefab capability lane passes **34/34 tests with 252 assertions**; this advances source-level rejection of unsupported runtime content but does not close bundled native dependencies, voxel artifacts, Windows execution or external-service gates.

The packaged entrypoint now exposes `--capability-report` and makes `--package-smoke` validate the common walk/CSG runtime contract before resource checks. The focused package runner covers both modes; prefab capability proof is **35/35 tests with 260 assertions**. This improves target-side observability and fail-closed behavior but does not bundle GodotSteam/Voxel Tools or establish native Windows execution.

Steam transport now consumes the same native dependency report as packaged capability diagnostics and exposes explicit ENet fallback state. Focused Steam integration proof passes **12/12 tests with 66 assertions**; the ENet fallback lane passes **6/6 tests with 38 assertions**. This is local contract proof, not authenticated Steam, two-account, WAN or native target evidence.

The latest local release candidate is commit `b1ffb5d5bb0c56e70388501b57d37e6bc494c532`. All five Godot 4.7.2 exports rebuilt; four-format OVERZEER validation, lean ZTASH preparation, extracted Linux package smoke/capability report, Linux client/server export smoke and ZEER preview passed. DDJARIN and direct CHOPPER apply attempts returned HTTP 403 `MissingRequestGuard`; no new remote activation is claimed. Lean hashes: Linux `b0eb3b867766a6f3fad1508c1d3024eff1a790e0fa3161a2f7c938500f26d7c2` (83567536 bytes), Windows `4aa0bb83b6c0da038d3e1c6da510d589fe5d64280105b1b405029ffaa2eed078` (93341198 bytes).

The packaged capability report now distinguishes stock Godot classes from optional GodotSteam, `SteamMultiplayerPeer` and Voxel Tools inputs, and records ENet/CSG fallbacks when those native integrations are absent. Focused prefab capability proof is **36/36 tests with 269 assertions**. This improves release diagnostics and fail-closed behavior; it does not bundle native binaries or establish native Windows, Steam or Workshop acceptance.

Generated mission graphs now retain deterministic room-depth records, key-lock manifests export them, and gameplay metadata preserves the graph for authored/editable inspection. Encounter placement uses playable route depth before editor-space distance for weapon, ammo, health and enemy quality pacing, with the prior fallback retained for legacy contexts. Focused planner/key-lock/placer/generator/export proof passes **49/49 tests with 697 assertions**; full encounter tuning, composed Breakwater review and manual balance remain open.

Generated key, door and switch actors now expose state-aware interaction prompts through the shared actor contract. The player HUD resolves collision children back to their actor parent, and the native `InteractionPrompt` renders a high-contrast key/action panel with fade/scale feedback. Focused prompt proof passes **3/3 tests with 11 assertions**; the existing full HUD fixture still has a pre-existing player-lifecycle failure.
Generated door collision leaves now carry both world-blocking and interactable layers; key and switch bodies are interactable-only with zero collision masks. Focused actor proof passes **8/8 tests with 60 assertions**; the native prompt is now wired into `PlayerHUDBridge`.

Interact-triggered secret walls now use world plus interactable collision layers while channel, proximity and shootable walls retain world/debris blocking. Travel actors expose destination-aware prompts through the same contract. The isolated rendered prompt smoke is present, but execution is blocked by an already-running serialized display job; no manual feel claim is made.

### September 13 Generator Correctness and World-Building Plan

The [release and world-building plan](RELEASE_AND_WORLD_BUILDING_PLAN.md) separates implemented generator/module/editor contracts from release acceptance. The eleven-module **Breakwater Black Start** mission is authored with 12 route edges, all rooms reachable from `dock`, and a return edge that closes the hub loop; the authored cyclic mission proof passes as part of **10/10 mission tests with 96 assertions**. Power-driven presentation, zoned ambience, finite-supply tuning, persistent hub visits and controlled unpinned regeneration are implemented and headlessly exercised. Human audiovisual/balance acceptance, signed/published installers, bundled native integrations and external-service proof remain open.

The initial disposable Godot 4.7.2 probe reproduced key/secret nondeterminism at context seed `424242` under global seeds `111`/`999`. Generator revision **2** now isolates random choices, fixes double-offset room polygons and overwritten entrances, connects room components and organic areas, retains gameplay output, and bakes collision-backed navigation before packing. The nine-script focused selection passes **55/55 tests, 1,319 assertions**. Separate 64×64 and default 128×128 source-generation smokes pass; the latter produces 1,405 navigation polygons, 27 rooms, 28 hallways and one secret. Saved-scene tests exercise reachable room/key/monster destinations, player-floor collision, repeatable gameplay/navigation and cancellation/restart; no visual/manual gameplay or full matrix was run.

The owner selected a **bundled full-feature runtime**; no Steamworks app exists yet. Live rule execution now passes **9/9 tests**, and Voxel Tools detection only advertises the native `VoxelTerrain` path when that class is instantiable; the current runtime explicitly uses the CSG fallback. Signed release packaging, target-platform runtime, manual acceptance and external-service proof remain open.

The earlier embedded editor experiment reproduced **4 saved nodes becoming 1 after load/resave**. Transactional document replacement now preserves root names/metadata, nested ownership, transforms and collision; the unresolved `sync_cursor` dependency is repaired, and actors use one document-owned channel service. Editor/history regressions pass **36/36 with 204 assertions**; module/navigation regressions pass **25/25 with 105 assertions**, including moving doors not permanently severing navigation. Both focused runs report no GUT orphans; stock-engine ObjectDB exit warnings remain.

Source and exported Linux standalone editors place/wire three real modules, play the key/switch/blocking-door/objective loop, return to unchanged author data, save/reopen/resave and export/extract `.mdsl`. The exported Linux game completes that package, including pre-gate/completed checkpoint restoration and navigation through every room and the upper walkway. The document retains 23 meshes with 24,764 vertices, three architectural collision shapes, four actors and one player spawn. [Editor Round-Trip Proof](EDITOR_ROUNDTRIP_PROOF.md) records artifact evidence and the pressure-blocked graphical boundary; these headless observations are not reviewed manual play.

September 13 production proof: the exported Linux client completes the `.mdsl` mission in **100 automated checks**, using real pistol fire, normal damage, finite ammunition and default movement; enemies are defeated by weapon hitscan rather than scripted damage. The return lift stops above obstructing characters, resumes when clear, carries the player through a mid-ride encrypted checkpoint, and reaches the powered hub; completed-state reload passes. Separate native playback exercises void respawn, loading before its pending timer, the cavern dry route, real hitscan/physical access to both caches and their restored discovery state. **85 native presentation checks** cover fourteen actual 1280×720 views across all eleven rooms, power restoration without progression replay, unclipped spatial audio, SFX/Master mute, reduced motion, low/zero-particle settings and stopped out-of-zone sources. Rendering used an isolated llvmpipe/Mesa 26.2.2 display, not the developer's desktop. Focused regressions pass **33/33 tests, 197 assertions**, plus death/load and deleted-decal lifecycle regressions **2/2, 22 assertions**; this is not a refreshed aggregate. Evidence, native client and package are retained locally under `logs/breakwater_production/`; the previous source-only tranche remains under `logs/breakwater_mission/`. Human-operated completion, listening/visual approval, target-hardware performance and the 15–20 minute first-play hypothesis remain unproven; follow the [human checklist](../tests/docs/MANUAL_TEST_TIMING.md#black-start-production-acceptance).

## Readiness Snapshot

| Evidence | Current result | Boundary |
| --- | --- | --- |
| Documentation truth | **PASS** | Source/docs consistency only |
| Craft / Slopometer | **PASS** | Craft penalty 0; MODUS 0.0/10 with recorded aggregate proof and no reclaimable caches |
| Main player-path smoke | **PASS** | Fresh August 2 main-menu startup only |
| Showcase scene launch smoke | **PASS** | Fresh August 2 world-scene load/initialization only |
| Golden demo runtime smoke | **PASS** | August 4: all 8 controlled framework-loop steps; automated scope, not manual feel |
| September engineering repairs | **PASS** | 67 focused tests/612 assertions; eleven-step real-player smoke; native four-prop/ten-icon render; explicit patched Godot required for the MP3 fix |
| Retained complete Godot/GUT suite | **PASS** | September 10 refreshed headless aggregate: 1,568/1,568 passing, 21,718 assertions across 135 scripts; 10 warnings and 31 deprecations; two GUI-required files skipped |
| Latest strict aggregate attempt | **PASS/complete** | September 10: `run_all_tests_headless.sh` completed in 1,169.121 seconds with the patched Godot 4.7.2 binary; Godot emitted the known engine-exit ObjectDB diagnostics |
| Latest batched Unit lane | **PASS** | September 10: 1,166/1,166 passing |
| Latest batched Integration lane | **PASS** | September 10: 227/227 passing; 2 GUI-required files skipped |
| Latest batched Property lane | **PASS** | September 10: 175/175 passing, 2,804 assertions |
| Manual evidence | **BLOCKED / RECORDER READY** | Responsive 20-item F8 workflow and strict CSV validation pass; 0 reviewed CSV files and 0.00 validated hours |
| Performance evidence | **PASS** | 2026-09-27 warmed bounded headless Showcase capture: 69.90 seconds/66 samples, 7.00 FPS minimum and 7.58ms maximum frame time; measured evidence shape only, not a production FPS claim |
| Release-version evidence | **BLOCKED** | Project remains `0.9.5-beta` |
| Production readiness | **NOT READY** | 3 validator-tracked blockers: filtered full suite, manual evidence and release version; provenance clearance is outside that count |
| Release evidence bundle | **INDEX COMPLETE / RELEASE BLOCKED** | Hashed menu/welcome/mod/golden-demo captures, short automated video, bounded benchmark table, native Windows acceptance harness, known-limits matrix, provenance ledger, fresh three-preset notice checks, local Linux desktop export smoke, executable exports, local ENet/reconnect/host-loss/rate-limit proof, and authenticated Steam API initialization are retained; manual marketing review, installer, two-account Steam/Workshop, target-Windows runtime, independent WAN and rights clearance remain open |

## Current Focused Automated Proof

These results are narrower than the aggregate suite and must not be summed into a replacement “overall pass rate.”

| Contract | Result |
| --- | --- |
| Server rewind / combat / adjacent weapons | September 9: 119/119, 255 assertions; eight runtime checks pass after six baseline failures; controlled latency and real physics, not WAN/manual proof |
| Save service | 8/8; current encrypted slot existence/list/delete contract and score-key restoration |
| Network manager | 15/15; trusted Steam-authenticated peers remain subject to whitelist, rate limits, movement validation, semantic status/chat/kill/ticket/revive/interaction validation, authority-only damage, weapon visual effects, player-state synchronization, bounded lifecycle, grenade, prop-damage, chest, backpack, treasure-chest, button, lever, EnemyLab, door, barrel, world-spawn, ProjectileLab, downed-state, player-state, interaction-pickup, inventory, and editor requests |
| Reconnect | 2/2; focused token preservation and reconnect cancellation proof |
| Combat latency | 10/10; controlled 100 ms rewind/reconciliation proof; representative WAN sessions remain open |
| Network rate validation | 13/13 focused network-manager proof; real abusive-client soak remains open |
| ENet host/join | PASS; separate Godot server/client processes now prove readiness, reliable application delivery, reconnect/1-second soak and controlled host-loss observation; independent WAN and Steam transport remain external |
| Package notices | 6/6 required notices match for Windows Desktop, Dedicated Server (Linux), and Standalone Editor resource exports; Windows client, Windows editor, and Linux server executables export successfully with installed Godot 4.7.2 templates |
| Linux desktop export | PASS; `Linux Desktop` preset builds and the bounded exported artifact smoke launches cleanly on the current Linux/Godot 4.7.2 environment; this is not a published release or target-Windows proof |
| RPC whitelist | 9/9 |
| Network editor RPC boundary | 5/5 focused integration proof; server-only handlers, finite/bounded payloads, safe relative paths, resource checks, and entity/transform rate limits |
| Mod-loading integration | 12/12 |
| Enemy AI | 13/13 |
| Enemy AI system | 126/126 |
| AI LOD update rate | 13/13 |
| Splitscreen configuration | 3/3 |
| Splitscreen manager | 28/28 |
| Splitscreen assignment UI | 15/15, 21 assertions |
| Splitscreen multiplayer compatibility | 16/16 |
| Splitscreen feature integration | 10/10 |
| Splitscreen gameplay | 34/34 |
| Splitscreen stress | 20/20 |
| Splitscreen property/layout/error recovery | 83/83, 334 assertions; includes all 30 properties and equal-area five-player layout |
| Feature integration | 10/10 |
| Configuration manager | 22/22 |
| Configuration caching | 5/5 |
| Configuration fallback | 8/8 |
| Configuration validation | 6/6 |
| Configuration loading correctness | 4/4 |
| Feature toggles | 9/9 |
| GameManager state transitions | 6/6 |
| Feature dependency validation | 7/7, 407 assertions |
| Mod loading properties | 4/4 |
| Mod conflict detection | 6/6 |
| Mod dependency resolution | 4/4 |
| Weapon synchronization | 6/6, 750 assertions |
| Event bus | 3/3, 9 assertions |
| Component lifecycle/signal hygiene | 30/30, 66 assertions; generic dynamic signals and GUT-owned fixture cleanup |
| Feature lifecycle/toggles | 36/36, 75 assertions; no-dependency validation, explicit loaded-state checks, GUT-owned fixtures |
| Individual weapons | 58/58, 76 assertions; hitscan defaults and name-based async switching/reload contracts |
| Combat feature | 20/20, 30 assertions; injected configuration preserves critical and knockback modifiers |
| Audio/performance logging | 23/23, 67 assertions; maintained music navigation API and mutable signal observations |
| Grid pathfinding/HUD boundaries | 30/30, 70 assertions; walkable-only A* and deterministic ten-update state |
| UI/UX | 26/26, 109 assertions on August 3; supplied hero artwork, player-visible Showcase route, contextual action help, responsive containment, 48-pixel logical controls, visible version, explicit focus loop, responsive shared forms, localized welcome panel, responsive mod workflow, and complete skill-tree compatibility scene; fresh menu, welcome, mod, and golden-demo captures are retained |
| Manual evidence recorder | 2/2, 21 assertions on August 4; safe CSV output, required metadata, explicit Skip accounting, compact 800×600 layout, 48-pixel targets, and focus order |
| ENet fallback Unit contract | 11/11, 28 assertions; expected engine errors consumed and config fixture owned |
| Configuration validation | 14/14, 104 assertions; canonical nested paths and GUT-owned managers |
| GameManager lifecycle | 28/28, 102 assertions |
| Memory usage property | 4/4 |
| Lazy loading property | 4/4; deferred construction is verified without a wall-clock microbenchmark |
| Frame-time property | 5/5 at default counts in 331.79s; stability uses the middle 90% to exclude host descheduling, while absolute spikes stay in the performance lane |
| Visual configuration/reload | Editor, lazy-loading, graphics, and map focus passes 52/52 with 443 assertions; graphics preset coverage is 27/27; all ConfigurationManager reload subscribers accept the emitted path |
| Map-generator correctness | September 13: 55/55 focused tests, 1,319 assertions across nine scripts; not a refreshed full-suite count |
| Map-generator saved-scene routes | 64×64 `generator-correctness`: export/reload, real navigation paths and player-floor collision; cancellation/replacement succeeds |
| Map-generator export history | Historical 10/10, 34 assertions; current roundtrip proof is included in the focused correctness selection above |
| Map-generator seed/RNG | Revision 2: global `111`/`999` cannot change tested gameplay records or baked navigation vertices; old unconditional determinism claim superseded |
| Map playability | 15/15, 40 assertions |
| Showcase structure | 17/17, 46 assertions |
| Reference integrity | 22/22, 119 assertions; shared blood-pool shader/controller parse and load |
| MatchService | 8/8 |
| Breakable props | 17/17; RPC validation uses the whitelisted method name and test peers close before port reuse |
| Migration compatibility | 13/13, 21 assertions |
| Sample mod SDK | 2/2 |
| Mod package validator | 4/4; repository scan 9 packages, 0 errors, 8 disabled-mod warnings |
| Editor save/export/reload | 1/1, 15 assertions |
| Local Workshop simulation | 1/1, 13 assertions |
| Source shape/resource/editor registry | 37/37, 172 assertions, zero GUT orphans; canonical paths and built-in actor instantiation only |


The September 10 refreshed aggregate is current-tree automated evidence: 1,568/1,568 selected tests passed with 21,718 assertions across 135 scripts. It does not certify the two GUI-required files, benchmark performance, manual gameplay feel, packaging, rights, or external service proof.
## Source-Backed Implementation Boundary

- `project.godot` registers two autoloads: `GameManager` and `MapGenerator`.
- GameManager creates logging, events, data, audio, UI, performance, localization, entities, saves, mods, chat, networking, assets, and UI-input services.
- Runtime feature code covers player, combat, loot, match, effects, missions, difficulty, movement, world systems, and supporting components.
- `game/data/` owns content registries; `game/config/` owns runtime feature/system configuration.
- Network source includes ENet, dedicated-server paths, server-side validation, RPC whitelist/rate limits, prediction, and conditional Steam structures.
- Shared editor source includes serialization, packaging, local Workshop simulation, UI panels, prefabs, and embedded/standalone entry points; every registered built-in actor resolves and instantiates its native script base.
- Map-generator source includes a multi-phase pipeline, profiling, validation, export, and batch-oriented support.

This source inventory is not equivalent to complete runtime or user-experience proof.

## Player-Visible and External Boundaries

### Multiplayer

- `multiplayer_demo` profile launch: **PASS** for profile/service startup.
- Local separate-process ENet host/join smoke: **PASS**; the client connected to the server over localhost and the harness terminated the server after client success. Focused reconnect token/cancellation, 100 ms rewind, and network/rate suites pass; exported Linux dedicated server and Windows client/editor executables now build with installed Godot 4.7.2 templates.
- Real Steam/GodotSteam: **FOCUSED PASS** on September 10. GodotSteam 4.22.1's Godot 4.7.2 Linux runtime initialized through the authenticated Steam client and logged in as Steam ID `76561199814411086`; the Steam integration suite passes 8/8. This is one authenticated local account/API initialization, not two-account lobby, Workshop, relay, or production server proof.
- Server rewind and combat integration: **FOCUSED PASS** on September 9. One CombatSvc-owned system captures player/enemy history, uses bounded server-measured RTT/2, rejects invalid/out-of-window requests, and restores query state. Temporary static query bodies handle Jolt's deferred kinematic transforms without changing live body modes or velocities. Feature and multi-pellet weapon flows share the service; projectile/melee and nonplayer validation remain current-state.
- High-latency combat quality: **UNPROVEN**. Client-view/interpolation calibration and representative end-to-end latency sessions remain outside the focused physics/weapon proof.

### Editor and Workshop

- Save/export/reload serialization contract: **PASS**.
- Local Workshop filesystem simulation: **PASS**.
- August main-menu/showcase/mod-manager/skill-tree presentation: **FOCUSED PASS** through 26/26 structural/accessibility tests plus dated wide/narrow captures in `docs/media/release/`. The menu captures predate artwork removal and are not current rendered proof.
- Standalone block, erase, paint, transform, selection, paste, and duplicate history: **FOCUSED PASS**; runtime-safe fallback, centroid-preserving paste, offset duplication, and live node-tree/material/transform round trips are covered. Full editor UI and manual authoring workflow remain open.
- Live complete editor UI workflow: **UNPROVEN**.
- Standalone custom undo/redo commands, advanced brush operations, and concrete implementation-debt fixes: **FOCUSED PASS** for block, erase, paint, transform, selection, paste, duplicate, `EditorState` block/entity/spawn placement, runtime-safe level-save boundaries, runtime-safe visual-script selection, tool-cycle signaling, Escape cancellation signaling, positive brush-size shortcuts, embedded editor save/load round trips, toolbar/hotbar runtime construction, workshop browser construction, optional environment preset apply/load/delete/parameter handling, zone selection safety, preset-list refresh safety, detached zone creation/deletion, stale preset-selection safety, standalone Undo/Redo plus `.mdsl` export menu dispatch, staircase/arch/torus/capsule geometry, density-aware fill, detached clear/remove safety, editor-console keep occupancy checks, configurable package authors, visual action sound/variable/teleport execution, collapsable-floor audio, armor reduction formulas, per-file rule hot reload, SteamID profile mapping, milestone popups, threat-aware AI retaliation, and configurable minimum monster counts; native exported-app and full graphical editor workflow remain unproven.
- Real Steam Workshop transfer: **BLOCKED** without a configured app-owned Workshop item, two-account authorization, and service upload/download evidence.

### Showcase and Performance

- Showcase structure: **PASS** with 4 player spawns, 2 enemy spawns, 1 navigation region, lighting, environment, collision, and 539 nodes.
- Automated golden-demo route: **PASS** for all 8 controlled framework-loop steps.
- Human-operated golden-demo feel and failure recovery: **UNPROVEN**; the F8 recorder workflow is ready but contains no human observations yet.
- Bounded performance CSV: **PASS** for evidence shape/duration.
- Display-synchronized gameplay, splitscreen, multiplayer, low-end hardware, and long-session performance: **UNPROVEN**.
- The historical capture's 108.55 ms maximum frame time remains an active concern; extreme enemy positions now trigger bounded recovery, but long-session behavior is unproven.

## Current Validator-Tracked Blockers

1. No reviewed ManualTestTimer CSV evidence has been imported; the recorder and validator are ready, but recorded manual gameplay remains 0.00 validated hours.
2. The project is still explicitly `0.9.5-beta`, so the 1.0 release-version gate is blocked.

The two-count is the scope of `tools/validate_production_readiness.sh`, not exhaustive release or legal clearance. The current 1104-row provenance ledger clears all 1104 tracked assets; the twelve private Suno tracks were removed rather than distributed, the Quaternius Universal Animation Library plus derived Godot resources are cleared under CC0, the author-confirmed liquid, skybox, resource, model, editor-icon, shader, effect-texture, weapon-icon, and retro prototype assets are classified MIT, the imported Binbun3D RetroUrban maps/materials are cleared under CC BY 4.0 with local attribution, and the imported valsekamerplant fence/wall models and textures plus office models and embedded textures and Brackeys VFX textures are cleared under CC0/Public Domain. The generated map overview remains a project capture artifact.

Additional open proof: representative WAN latency, hostile-client soak, dedicated-client sessions, two-account Steam, real Workshop publication, live complete editor UI, display-synchronized performance, signed/published installer and target-Windows runtime. Local real-ENet behavior, authenticated local Steam initialization, the refreshed full aggregate, the Linux portable lifecycle, and all four formerly missing props have focused proof; stock Godot still requires the explicit audio patch described in [Known Limits](KNOWN_LIMITS_MATRIX.md).

## Project Inventory

| Metric | Current retained inventory |
| --- | ---: |
| Project autoloads | 2 |
| Unit test files | 71 |
| Integration test files | 18 |
| Property test files | 29 |
| GUI-required manifest entries | 2 |
| Manual evidence files | 0 |
| Recorded manual hours | 0.00 |
| Performance evidence files | 1 |
| Performance evidence duration/samples | 66.4 seconds / 130 samples |

## Verification Commands

```bash
bash tools/check_documentation_truth.sh
bash tools/check_project_truth.sh
bash tools/check_headless_runner_manifest.sh
tools/generate_provenance_ledger.py --check
./tests/runners/run_all_tests_headless.sh
./tests/runners/run_tests_by_category.sh --report docs/AUTOMATED_TEST_LANES_REPORT.md
tools/run_showcase_golden_demo_smoke.sh --strict
tools/run_manual_showcase_session.sh --tester NAME --input DEVICES
tests/runners/test_manual_evidence_validator.sh
tools/run_main_player_path_smoke.sh --strict
tools/validate_manual_evidence.sh --strict
tools/validate_performance_evidence.sh --strict
tools/validate_release_readiness.sh --strict
tools/validate_production_readiness.sh --run-godot-tests --strict
```

## Related Current Sources

- [Report Regeneration and Evidence Prerequisites](DOCUMENTATION_TRUTH.md#regenerating-local-reports)
- [Known-Limits Matrix](KNOWN_LIMITS_MATRIX.md)
- [Release Evidence Bundle](RELEASE_EVIDENCE_BUNDLE.md)
- [Active Backlog](../BACKLOG.md)
