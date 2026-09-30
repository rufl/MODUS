# MODUS Ship-Readiness Estimate

> **Documentation status: maintained reference.** This is a dated evidence-completeness estimate, not release approval. Published status is consolidated in [Current Status](CURRENT_STATUS.md); regenerate local gate reports using the [truth contract](DOCUMENTATION_TRUTH.md#regenerating-local-reports).

**Languages:** [English](SHIP_READINESS_ESTIMATE.md) · [Português (Brasil)](pt-BR/SHIP_READINESS_ESTIMATE.md)
**Estimated:** 2026-09-30
**Target:** a distributable MODUS release with green automated gates, reviewed runtime evidence, signed artifacts, and bounded public claims.

## Current gateboard

This snapshot reports evidence state, not lines of code or feature volume. It deliberately does not publish a weighted percentage: external gates are not interchangeable with source coverage, and the previous August estimate is superseded. Raw logs and generated reports remain local-only; curated screenshots/video remain published.

| Gate | Status | Evidence / remaining proof |
| --- | --- | --- |
| Documentation truth | **PASS** | Documentation, project truth, runner-manifest and provenance checks pass locally |
| Hosted CI | **PASS** | Source-validation pipeline `36588760158` and quality `36588760149` pass on commit `701ead4758c6e23f67a31e22587a7ef38166faff`; documentation-only commits run through the same GitHub Actions workflows |
| Automated Godot aggregate | **PASS / bounded** | September 29 strict aggregate: 1,671/1,671 tests, 22,982 assertions, 149 scripts in 1,103.095 seconds; two GUI-required files skipped |
| Focused release engineering | **PASS** | Archive validation, staging, package lifecycle, ZTASH preparation, fleet forwarding and toolchain-lock contracts pass |
| Authenticated dogfood transfer | **PASS** | DDJARIN Windows (`24a29d3eed0510d7993c99d9a97c7ff52358165485fac7f871b8874d50948d9b`) and CHOPPER Linux (`63171873e1b7ed3cc7cd190694064e35724a03f75a38830fb121626907618f64`) reconcile to immutable metadata for build `1f6d4faf4a80f4426f85f3a6f731689d756806ef` |
| Manual gameplay evidence | **BLOCKED / TOOLING READY** | Recorder and strict validator exist; reviewed CSV count is 0 and validated hours are 0.00 |
| Performance evidence | **BOUNDED** | One warmed 69.90-second/66-sample Showcase capture; display-synchronized target, low-end, multiplayer and long-session evidence remain open |
| Release version | **BLOCKED** | Project remains `0.9.5-beta`, not `1.0.0` |
| Signing/public distribution | **BLOCKED** | Artifacts remain unsigned; no installer, signed publication, or public release exists |
| Native/external runtime | **OPEN** | Native Windows renderer/input/content/save/network, independent WAN, two-account Steam, Workshop and graphical editor acceptance remain unproven |
| Provenance | **PASS / bounded** | Current tracked asset ledger is cleared; package notices and distribution policy remain separate checks |

## Critical path

The remaining work is primarily evidence and external prerequisites, not another local framework abstraction:

1. Collect and review human gameplay evidence.
2. Execute the finite native-Windows acceptance bundle on an approved machine.
3. Execute independent WAN ENet and, if supported, two-account Steam relay/P2P evidence.
4. Obtain signing material, define installer/public-release policy, and publish signed client/server/editor artifacts.
5. Close bundled native-runtime/dependency, Workshop, exported-editor graphical, and audiovisual/first-play review gates.
6. Promote the version only after the current automated, manual, native, distribution, and rights gates agree.

## Approval rule

Do not call MODUS shipped, production-ready, or approved while any required row has an open limitation. Unsigned authenticated dogfood is validation of transfer and package compatibility, not release approval.

## Verification

```bash
bash tools/check_documentation_truth.sh
bash tools/check_project_truth.sh
bash tools/check_headless_runner_manifest.sh
tools/generate_provenance_ledger.py --check
tools/validate_release_readiness.sh --strict
tools/validate_production_readiness.sh --run-godot-tests --strict
```
