---
applyTo: "**/*.yml,**/*.yaml"
description: "YAML standards for ProStateKit workflows and DSC configuration samples."
---

<!-- markdownlint-disable MD013 -->
# YAML Writing Style

**Version:** 2.0.20260503.0

## Metadata

- **Status:** Active
- **Owner:** Repository Maintainers
- **Last Updated:** 2026-05-03
- **Scope:** YAML authoring standards for ProStateKit.
- **Related:** [Repository Instructions](../copilot-instructions.md), [JSON Instructions](json.instructions.md)

## Requirements

- Use 2-space indentation and block style by default.
- Quote version pins and string values that could be misparsed as booleans, numbers, nulls, dates, or YAML 1.1 truthy values.
- Use lowercase `true`, `false`, and `null`.
- Use single quotes for literal Windows paths unless escaping is required.
- Do not use anchors, aliases, merge keys, or custom tags unless the consumer requires them and the reason is documented.
- Do not commit secrets or real endpoint, tenant, user, customer, or credential data.
- GitHub Actions workflows MUST use least-privilege `permissions:`.

## Validation

Run:

```bash
pre-commit run check-yaml --all-files
pre-commit run yamllint --all-files
pre-commit run actionlint --all-files
```
