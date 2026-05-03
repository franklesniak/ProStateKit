---
applyTo: "**/*.ps1,**/*.psm1,**/*.psd1"
description: "PowerShell standards for ProStateKit runner, wrappers, tools, and tests."
---

<!-- markdownlint-disable MD013 -->
# PowerShell Writing Style

**Version:** 3.0.20260503.0

## Metadata

- **Status:** Active
- **Owner:** Repository Maintainers
- **Last Updated:** 2026-05-03
- **Scope:** PowerShell coding standards for ProStateKit scripts, modules, data files, and Pester tests.
- **Related:** [Repository Instructions](../copilot-instructions.md), [Execution Contract](../../docs/contract.md)

## Required Defaults

- Scripts MUST set `$ErrorActionPreference = 'Stop'`.
- Runtime scripts MUST use `Set-StrictMode -Version Latest` unless a documented compatibility exception is tested.
- PowerShell behavior changes MUST include Pester tests.
- Public runtime behavior MUST have an explicit exit-code contract.
- Unimplemented runtime paths MUST fail closed with a non-zero exit or thrown terminating error.

## Security And Evidence

- Treat all parameters, paths, config files, and process output as untrusted.
- Use safe path handling and reject path traversal or symlink escapes before runtime use.
- Use `-LiteralPath` for concrete variable-derived paths when cmdlets support it.
- Do not write secrets or sensitive values to stdout, transcripts, logs, raw evidence, normalized evidence, or summaries.
- Preserve raw DSC output before parsing or normalizing it.
- Parser failures, unknown result shapes, missing evidence, resource failures, and partial convergence MUST fail closed.

## Style

- Use 4 spaces for indentation and OTBS braces.
- Use approved verbs for functions.
- Avoid aliases.
- Prefer named parameters in script logic.
- Use concise comments for non-obvious behavior and TODO comments for incomplete implementation.
- Avoid new dependencies unless the need is documented.

## Tests

Pester tests live under `tests/PowerShell/` and use Pester 5 syntax. Tests should cover parameter contracts, fail-closed behavior, schema fixtures, redaction checks, and path consistency as implementation lands.
