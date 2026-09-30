# Security Policy

> **Documentation status: maintained reference.** This policy defines the supported beta line and private reporting boundary.

MODUS is pre-release software. Only the current `0.9.x` beta line receives security fixes.

## Report a vulnerability

Use a [private GitHub security advisory](https://github.com/rufl/MODUS/security/advisories/new). Do not publish credentials, exploit details, private data, or an undisclosed vulnerability in an issue or discussion.

Include:

- the affected version, commit, or release asset;
- a minimal reproduction;
- expected impact and affected configurations;
- relevant logs with credentials and personal data removed;
- whether the issue is already public or actively exploited.

The maintainer may ask for clarification and coordinate disclosure after a fix is available. The project currently makes no response-time, embargo, bounty, or compatibility commitment.

## Release boundary

Public beta binaries are unsigned. Verify assets with the published `SHA256SUMS` file before use. Source-level authority checks, validation code, and passing tests are not a security certification.
