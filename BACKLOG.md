# MODUS Backlog

> **Documentation status: maintained reference.** Priorities updated 2026-09-30 and ordered by release risk. Completed history belongs in the changelog; implemented code is not marked complete until its acceptance boundary is named.

## Stable beta blockers

- [ ] Sign Windows and Linux artifacts through a documented release identity.
- [ ] Sign and notarize the macOS universal application.
- [ ] Complete native Windows and macOS install, launch, input, save, and uninstall acceptance.
- [ ] Run representative ENet sessions across latency, jitter, packet loss, reconnects, and late joins.
- [ ] Exercise authority validation with malformed and hostile client traffic.
- [ ] Establish low-end CPU/GPU budgets and a repeatable long-session soak.
- [x] Publish and enforce a compatibility policy for mod packages, schemas, and save data. Native-platform, distribution, and migration evidence remain separate open work.

## Gameplay and world building

- [ ] Tune movement, weapon feedback, enemy readability, and encounter pacing through observed play sessions.
- [ ] Expand authored encounters without hiding procedural-system failures behind scripted paths.
- [ ] Sample larger procedural seed sets and record generation failures with seeds.
- [ ] Validate large-world memory cleanup and worker cancellation during repeated transitions.
- [ ] Add a representative campaign loop only after save and content-versioning contracts are stable.

## Multiplayer

- [ ] Validate dedicated-server startup and client acceptance on the supported release platforms.
- [ ] Record server-authoritative inventory, damage, respawn, and map-transition behavior in multi-peer sessions.
- [ ] Measure bandwidth and correction behavior under representative latency and loss.
- [ ] Define public hosting, port, compatibility, and moderation guidance.
- [ ] Prove Steam two-account, relay/P2P, and Workshop behavior before presenting those paths as supported.

## Creation and modding

- [ ] Complete exported embedded-editor and standalone-editor graphical acceptance.
- [ ] Validate `.mdsl` round trips across more authored map structures.
- [ ] Define mod dependency, conflict, versioning, and failure-reporting behavior.
- [ ] Document safe content boundaries and the absence or presence of sandbox guarantees.
- [ ] Add public package examples only when their licenses and upgrade paths are clear.

## Accessibility and usability

- [ ] Audit menus and editor flows against WCAG 2.2 keyboard, focus, contrast, and text-resize principles.
- [ ] Verify complete keyboard-only and controller-only navigation.
- [ ] Add remapping and non-color-only feedback where current gameplay relies on defaults.
- [ ] Establish localization extraction and layout-expansion workflows.
- [ ] Test common 16:10, ultrawide, low-resolution, and scaled-desktop configurations.

## Contributor experience

- [ ] Keep setup and verification commands runnable from a clean clone.
- [ ] Add focused starter issues only when each has an owner, acceptance boundary, and no hidden dependency.
- [ ] Reduce broad ownership surfaces in `GameManager` when concrete feature work exposes a stable boundary.
- [ ] Review dependencies, asset provenance, and public claims before each release candidate.

## Done criteria

An item leaves this backlog only when:

1. the user-visible or contributor-visible result exists;
2. the smallest representative verification has been observed;
3. relevant limitations and platform boundaries are documented;
4. no credential, proprietary asset, or private infrastructure detail is required to reproduce it.
