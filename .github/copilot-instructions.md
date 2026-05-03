<!-- markdownlint-disable MD013 -->
# Repository Copilot Instructions

**Version:** 2.0.20260503.0

## Metadata

- **Status:** Active
- **Owner:** Repository Maintainers
- **Last Updated:** 2026-05-03
- **Scope:** Repo-wide constitution for ProStateKit contributors and AI coding agents.
- **Related:** [PowerShell Instructions](instructions/powershell.instructions.md), [Documentation Instructions](instructions/docs.instructions.md), [JSON Instructions](instructions/json.instructions.md), [YAML Instructions](instructions/yaml.instructions.md)

These instructions are authoritative for all changes in this repository.

## ProStateKit Contract Rules

- No secrets in configuration documents, examples, logs, transcripts, stdout, prompts, normalized evidence, or raw evidence committed to the repository.
- No live downloads in endpoint runtime paths.
- DSC binary, PowerShell, resources, modules, wrapper scripts, and configurations must be pinned and bundled when packaging.
- The wrapper must fail closed when proof is missing.
- Unknown DSC result shape, parse failure, missing evidence, partial convergence, or resource failure must not produce green status.
- Preserve raw DSC output before normalization.
- Normalize evidence into the stable wrapper-owned schema.
- Consumers should read wrapper-owned normalized fields, not raw DSC fields directly.
- The execution plane owns targeting, scheduling, identity, delivery, retries, reporting, and reboots.
- DSC v3 payload owns desired state, test, set, and structured result output.
- Detect maps to `dsc config test`.
- Remediate maps to `dsc config set`, then verifies with `dsc config test`.
- Reboots must be re-entrant and durable.
- PowerShell code must use strict error handling and be covered by tests where behavior changes.
- Markdown docs must stay practitioner-first, concrete, sponsor-safe, and stage-safe.

## Safety Rules

- Treat all external input as untrusted.
- Reject path traversal and symlink escapes in runtime paths.
- Do not add telemetry or external logging services without explicit approval.
- Do not weaken security constraints to make a test pass.
- Do not invent a pinned DSC version, hash, source commit, timestamp, tenant value, account name, or machine name.
- Mark unimplemented behavior with `TODO:` and make the execution path fail non-zero.

## Validation

Run applicable checks before committing:

```bash
npm run lint:md
pre-commit run --all-files
```

Run PowerShell tests with:

```powershell
Invoke-Pester -Path tests/ -Output Detailed
```

Pre-commit auto-fixes must be included with the related change. Do not create separate formatting-only or lint-only commits.

## Modular Instructions

Read the relevant file before changing matching files:

| Scope | Instruction File |
| --- | --- |
| Markdown | `instructions/docs.instructions.md` |
| PowerShell | `instructions/powershell.instructions.md` |
| JSON | `instructions/json.instructions.md` |
| YAML | `instructions/yaml.instructions.md` |
| Git attributes | `instructions/gitattributes.instructions.md` |

## Definition Of Done

A change is not done until tests and validation gates that cover the changed behavior pass, docs are updated for user-facing behavior, schemas and examples remain synchronized, and no committed artifact contains sensitive data.
