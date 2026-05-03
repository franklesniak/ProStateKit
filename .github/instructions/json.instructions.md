---
applyTo: "**/*.json,**/*.jsonc"
description: "JSON standards for ProStateKit schemas, fixtures, manifests, and tooling."
---

<!-- markdownlint-disable MD013 -->
# JSON Writing Style

**Version:** 2.0.20260503.0

## Metadata

- **Status:** Active
- **Owner:** Repository Maintainers
- **Last Updated:** 2026-05-03
- **Scope:** JSON and JSONC authoring standards for ProStateKit.
- **Related:** [Repository Instructions](../copilot-instructions.md), [Schemas](../../schemas/README.md)

## Requirements

- `.json` files MUST be strict JSON: no comments, trailing commas, single quotes, or unquoted keys.
- Use 2-space indentation and double-quoted keys and string values.
- Preserve intentional ordering in schemas, fixtures, `package.json`, and generated manifests.
- Do not commit secrets or real endpoint, tenant, user, customer, or credential data.
- Bundle manifest examples MUST keep literal `TBD` values until real version, timestamp, commit, and hash values exist.
- Schema-backed examples MUST stay synchronized with their schemas and tests.
- Additional properties are allowed in ProStateKit normalized evidence and manifest schemas unless a future contract explicitly closes a sub-object.

## Validation

Run:

```bash
pre-commit run check-json --all-files
pre-commit run check-jsonschema --all-files
pre-commit run check-metaschema --all-files
```
