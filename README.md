<!-- markdownlint-disable MD013 -->
# ProStateKit

ProStateKit is a starter kit for reliable endpoint state with DSC v3. It provides reusable runner templates, evidence schemas, sample DSC configuration documents, validation tooling, and management-plane wrappers for Intune and ConfigMgr. It is a starter kit teams can fork and standardize, not a finished product.

> Built and validated against `dsc.exe` version: TBD (to be pinned before MMSMOA 2026).

This repository was created from Frank Lesniak's Copilot repository template and then tailored for ProStateKit.

## What ProStateKit Is

ProStateKit is a preview starter kit for endpoint engineers who need a repeatable contract around DSC v3 runs. The kit separates the management plane from the desired-state payload, preserves raw DSC output, normalizes wrapper-owned evidence, and fails closed when proof is missing.

## What ProStateKit Is Not

ProStateKit is not a replacement for Intune, ConfigMgr, Azure Machine Configuration, Jamf, Apple MDM/DDM, or patch-management platforms. It is not production-ready, does not ship a pinned DSC runtime yet, and must not be treated as a finished management agent.

## Native-First Decision Rule

Use native CSPs, Settings Catalog, ConfigMgr Compliance Baselines, or another platform-native feature when they fully meet the requirement. Reach for ProStateKit when the requirement needs exact drift control, ordered convergence, portability across execution planes, code review, or durable evidence.

## Execution Plane Vs. DSC V3 Payload

The execution plane owns delivery, scheduling, identity, retry behavior, reporting, and reboot orchestration. DSC v3 owns desired state, test, set, and structured result output. ProStateKit's Runner is the contract boundary between those responsibilities.

## Execution Template Overview

The public entry point is [src/Invoke-ProStateKit.ps1](src/Invoke-ProStateKit.ps1), backed by the common Runner at [src/runner/Runner.ps1](src/runner/Runner.ps1). Detect mode maps to `dsc config test`. Remediate mode maps to `dsc config set`, followed by a verification `dsc config test`. The Runner currently implements path validation, runtime-mode resolution, DSC invocation when a runtime is present, raw output preservation, normalization, evidence writing, current-result updates, and fail-closed exit codes.

## Supported Management Planes

- Intune Remediations: [planes/intune/Detect-ProStateKit.ps1](planes/intune/Detect-ProStateKit.ps1) and [planes/intune/Remediate-ProStateKit.ps1](planes/intune/Remediate-ProStateKit.ps1).
- ConfigMgr Configuration Items: [planes/configmgr/Discover-ProStateKit.ps1](planes/configmgr/Discover-ProStateKit.ps1) and [planes/configmgr/Remediate-ProStateKit.ps1](planes/configmgr/Remediate-ProStateKit.ps1).
- Local preflight: [planes/local/Invoke-LocalPreflight.ps1](planes/local/Invoke-LocalPreflight.ps1).
- CI/lab runner: PowerShell tests, schema linting, data validation, and fixture compatibility checks.

## Bundle Layout

The source scaffold uses `src/`, `planes/`, `configs/`, `runtime/`, `resources/`, `schemas/`, `docs/`, and `evidence/sample/`. The release bundle layout is documented in [docs/packaging.md](docs/packaging.md). Packaging fails closed until a reviewed DSC runtime exists under `runtime/dsc/`.

## Evidence Model

Every run MUST preserve raw DSC output before normalization. The stable automation contract is `wrapper.result.json`, described by [schemas/wrapper-result.schema.json](schemas/wrapper-result.schema.json) and [docs/evidence-schema.md](docs/evidence-schema.md). Synthetic examples live under [evidence/sample](evidence/sample).

## Exit-Code Model

Detect exits `0` for compliant, `1` for non-compliant, `2` for runtime failure, and `3` for parse failure or proof missing. Remediate exits `0` only after verification proves compliance. Details are in [docs/exit-codes.md](docs/exit-codes.md).

## Reboot Model

The execution plane owns reboot orchestration. The Runner writes `reboot.marker.json` when normalized proof reports `rebootRequired`; lab-validated cleanup and platform-specific reboot orchestration remain documented in [docs/reboots.md](docs/reboots.md).

## Secrets Rule

Do not put secrets in configuration documents, examples, logs, transcripts, stdout, normalized evidence, or raw evidence. Runtime retrieval patterns are documented in [docs/secrets.md](docs/secrets.md), and [src/tools/SecretHelper.ps1](src/tools/SecretHelper.ps1) fails closed until implemented.

## Validation And CI

Run these checks before committing:

```bash
npm run validate
npm run lint:md
pre-commit run --all-files
```

Run PowerShell tests with:

```powershell
Invoke-Pester -Path tests/ -Output Detailed
pwsh -File src/tools/Invoke-SchemaLint.ps1
```

The repository keeps markdown, JSON, YAML, GitHub Actions, and PowerShell validation. Removed language-template support is intentionally not part of this starter kit.

## Releases

The chosen release posture is source plus a release bundle ZIP plus `bundle.manifest.json` plus a SHA-256 checksum file. Release publishing automation is not enabled yet because packaging intentionally fails closed until the pinned runtime is present.

Run the readiness gate after runtime placement and lab evidence collection:

```powershell
pwsh -File tools/Test-ReleaseReadiness.ps1
```

Expected preview result: non-zero exit with a report of missing runtime, dry release, rehearsal, lab, public-flip, deck, and final DSC recheck evidence.

## Getting Started

1. Install Node.js 20 or newer.
2. Run `npm install`.
3. Install `pre-commit` with your normal global or isolated tooling.
4. Run `pre-commit run --all-files`.
5. Review [docs/contract.md](docs/contract.md), [docs/packaging.md](docs/packaging.md), and [docs/runbooks/demo-runbook.md](docs/runbooks/demo-runbook.md).

## Support

Use GitHub issues for bugs, feature requests, and documentation problems. Do not paste secrets, tenant identifiers, customer data, private logs, unredacted transcripts, or full evidence bundles into issues.

## Security

Read [SECURITY.md](SECURITY.md) before reporting vulnerabilities or sharing evidence. Security reports must not be filed as public issues.

## Contributing

Read [CONTRIBUTING.md](CONTRIBUTING.md). Runner behavior changes require tests, and schema changes must update schemas, examples, tests, and docs together.

## License

MIT License. Copyright (c) 2026 Frank Lesniak and Blake Cherry.
