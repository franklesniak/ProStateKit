<!-- markdownlint-disable MD013 -->
# Schemas

## Metadata

- **Status:** Active
- **Owner:** Repository Maintainers
- **Last Updated:** 2026-05-03
- **Scope:** JSON Schema contracts and fixtures for ProStateKit evidence and bundle manifests.
- **Related:** [JSON Writing Style](../.github/instructions/json.instructions.md), [YAML Writing Style](../.github/instructions/yaml.instructions.md), [Evidence Schema](../docs/evidence-schema.md), [Packaging](../docs/packaging.md)

## Contracts

| Schema | Purpose | Valid Fixture | Invalid Fixture |
| --- | --- | --- | --- |
| [wrapper-result.schema.json](wrapper-result.schema.json) | Normalized `wrapper.result.json` evidence. | [wrapper-result.valid.json](examples/wrapper-result.valid.json) | [wrapper-result.invalid.json](examples/wrapper-result.invalid.json) |
| [bundle-manifest.schema.json](bundle-manifest.schema.json) | Bundle manifest provenance and validation metadata. | [bundle-manifest.valid.json](examples/bundle-manifest.valid.json) | [bundle-manifest.invalid.json](examples/bundle-manifest.invalid.json) |
| [release-readiness.schema.json](release-readiness.schema.json) | Release readiness report emitted by `Test-ReleaseReadiness.ps1`. | [release-readiness.valid.json](examples/release-readiness.valid.json) | [release-readiness.invalid.json](examples/release-readiness.invalid.json) |

## Validation

Pre-commit and data CI validate the valid fixtures against their schemas and self-validate the schema files. Invalid fixtures are tested by Pester so the repository proves the schemas reject missing required fields.

Run:

```bash
pre-commit run check-jsonschema --all-files
pre-commit run check-metaschema --all-files
```

Run PowerShell schema tests with:

```powershell
Invoke-Pester -Path tests/PowerShell -Output Detailed
```

## Fixture Rules

Examples must be synthetic, sanitized, and free of real endpoint, tenant, user, customer, or credential data. Bundle manifest examples keep literal `TBD` values until the pinned DSC version, build timestamp, source commit, and hashes are real.

Current fixtures use `schemaVersion` `1.0.0` and the expanded ProStateKit evidence contract documented in [ProStateKit.md](../docs/spec/ProStateKit.md) and [docs/evidence-schema.md](../docs/evidence-schema.md). The smaller bootstrap field lists are treated as lower bounds, not separate supported schemas.
