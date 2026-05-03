<!-- markdownlint-disable MD013 -->
# Security Policy

## Metadata

- **Status:** Active
- **Owner:** Repository Maintainers
- **Last Updated:** 2026-05-03
- **Scope:** Security reporting and handling guidance for the private-staging ProStateKit repository.
- **Related:** [Secrets Guidance](docs/secrets.md), [Evidence Schema](docs/evidence-schema.md), [Packaging](docs/packaging.md)

## Supported Versions

| Version | Support Status |
| --- | --- |
| `0.1.0` | Preview staging; security fixes are handled before public release. |

## Reporting A Vulnerability

Do not report security vulnerabilities through public GitHub issues.

During private staging, security reports are handled through maintainer-only repository access. Before public release, this repository will enable GitHub Private Vulnerability Reporting and update this document with the advisory submission link.

## What To Include

Include a clear description, reproduction steps, affected files or scripts, expected impact, and any suggested mitigation. Redact evidence before sharing it.

Do not include secrets, tenant identifiers, customer data, private logs, unredacted transcripts, full raw evidence bundles, or sensitive endpoint inventory.

## Sensitive Areas

- Runner execution context, especially when invoked under SYSTEM by the Intune Management Extension.
- SYSTEM context behavior and file-system access boundaries.
- Scheduled-task fallback used as a reboot continuation strategy.
- Runtime retrieval and secret-helper behavior.
- Evidence redaction for raw DSC output, transcripts, summaries, and normalized results.
- Bundle integrity, manifest validation, and SHA-256 checksums.
- Supply-chain pinning for DSC, PowerShell, resources, modules, and scripts.

## Disclosure

The maintainers will coordinate privately while the repository remains private. Public disclosure workflow will be documented after the public flip and Private Vulnerability Reporting setup are complete.
