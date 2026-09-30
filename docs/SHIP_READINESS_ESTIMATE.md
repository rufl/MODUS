# MODUS Ship-Readiness Estimate

> **Documentation status: maintained reference.** This is a dated evidence-completeness estimate, not release approval. Published status is consolidated in [Current Status](CURRENT_STATUS.md); regenerate local gate reports using the [truth contract](DOCUMENTATION_TRUTH.md#regenerating-local-reports).

**Languages:** [English](SHIP_READINESS_ESTIMATE.md) · [Português (Brasil)](pt-BR/SHIP_READINESS_ESTIMATE.md)
**Estimated:** 2026-09-30
**Target:** a distributable MODUS release with green automated gates, reviewed runtime evidence, signed artifacts, and bounded public claims.

## Current gateboard

This snapshot reports evidence state, not lines of code or feature volume. It deliberately does not publish a weighted percentage: external gates are not interchangeable with source coverage, and the previous August estimate is superseded. Raw logs and generated reports remain local-only; curated screenshots/video remain published.

| Gate | Status | Evidence / remaining proof |
| --- | --- | --- |
| Documentation truth | **PASS** | Documentation, project truth, runner-manifest, and provenance checks passed for the public-beta source baseline |
| Hosted CI | **PASS** | Source-validation pipeline `36779150278` and quality run `36779150276` passed on release-source commit `1367b270d651b1a2588044774a15f1dbeb2b8b51`; later documentation commits run through the same workflows |
| Automated Godot aggregate | **PASS / bounded** | September 29 strict aggregate: 1,671/1,671 tests, 22,982 assertions, 149 scripts in 1,103.095 seconds; two GUI-required files skipped |
| Focused release engineering | **PASS** | Artifact validation, staging, reproducible archives, checksum verification, package lifecycle, and toolchain-lock contracts passed |
| Public beta publication | **PASS / unsigned** | Linux x86-64, Windows x86-64, and macOS universal archives plus `SHA256SUMS` are published as `v0.9.5-beta` |
| Manual gameplay evidence | **BLOCKED / TOOLING READY** | Recorder and strict validator exist; reviewed CSV count is 0 and validated hours are 0.00 |
| Performance evidence | **BOUNDED** | One warmed 69.90-second/66-sample Showcase capture; display-synchronized target, low-end, multiplayer, and long-session evidence remain open |
| Release version | **BETA** | Project remains `0.9.5-beta`, not `1.0.0` |
| Signing/installers | **BLOCKED** | Public archives are unsigned; macOS is not notarized and polished installers are absent |
| Native/external runtime | **OPEN** | Native Windows/macOS renderer, input, content, save, and network acceptance; representative WAN; two-account Steam; Workshop; and graphical editor acceptance remain unproven |
| Provenance | **PASS / bounded** | Current tracked asset ledger is cleared; package notices and distribution policy remain separate checks |

## Critical path

The remaining work is primarily evidence and external prerequisites, not another local framework abstraction:

1. Collect and review human gameplay evidence.
2. Execute native Windows and macOS acceptance on representative systems.
3. Execute representative WAN ENet and, if supported, two-account Steam relay/P2P evidence.
4. Obtain signing material, define installer policy, and publish signed client/server/editor artifacts.
5. Close bundled native-runtime/dependency, Workshop, exported-editor graphical, and audiovisual/first-play review gates.
6. Promote the version only after the current automated, manual, native, distribution, and rights gates agree.

## Approval rule

Do not call MODUS shipped, production-ready, or approved while any required row has an open limitation. The public beta proves a bounded build and publication path, not stable-release approval.

## Verification

```bash
bash tools/check_documentation_truth.sh
bash tools/check_project_truth.sh
bash tools/check_headless_runner_manifest.sh
tools/generate_provenance_ledger.py --check
tools/validate_release_readiness.sh --strict
tools/validate_production_readiness.sh --run-godot-tests --strict
```
