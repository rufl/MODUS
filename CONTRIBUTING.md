# Contributing to MODUS

> **Documentation status: maintained reference.** This guide defines the current contribution workflow and review boundary.

Thanks for helping improve MODUS. The project is an experimental Godot 4 FPS mechanics lab, so focused changes with reproducible evidence are more useful than broad rewrites.

## Before you start

- Search existing issues and pull requests.
- Open an issue before a large feature, architectural change, or asset import.
- Keep a pull request to one concern.
- Do not include credentials, personal data, proprietary assets, or generated build output.
- Confirm that every asset and dependency can be redistributed under its stated license.

## Local setup

Requirements:

- Godot 4.7.2
- Python 3 for repository validation tools
- Bash for the maintained runner scripts

```bash
git clone https://github.com/rufl/MODUS.git
cd MODUS
godot --editor --path .
```

Run the narrowest check that exercises your change. Useful entry points:

```bash
bash tools/check_project_truth.sh
bash tools/check_documentation_truth.sh
bash tests/runners/test_release_archive_package.sh
```

Tests that need a display must use an isolated disposable display environment. Never run automation against an active desktop session.

## Pull requests

A useful pull request explains:

1. the problem and user-visible result;
2. the smallest relevant verification command;
3. known limits or unverified behavior;
4. screenshots or short captures for visual changes;
5. license and provenance for new assets.

Update documentation when behavior, commands, support boundaries, or public claims change. Distinguish implemented code from observed evidence and future plans.

## Code and content

- Follow nearby GDScript style and existing ownership boundaries.
- Prefer explicit data contracts over new global state.
- Keep multiplayer authority on the server-facing side of the boundary.
- Preserve deterministic seeds in procedural systems and tests.
- Add permanent tests only for observable behavior or a plausible regression.
- Use inclusive language and design controls that remain usable with keyboard-only input.

By participating, you agree to follow the [Code of Conduct](CODE_OF_CONDUCT.md).
