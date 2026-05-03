<!-- markdownlint-disable MD013 -->
# Agent Instructions For OpenAI Codex CLI

**Version:** 2.0.20260503.0

## Metadata

- **Status:** Active
- **Owner:** Repository Maintainers
- **Last Updated:** 2026-05-03
- **Scope:** Minimal entry point for Codex and compatible AI coding agents operating in ProStateKit.
- **Related:** [Repository Instructions](.github/copilot-instructions.md), [PowerShell Instructions](.github/instructions/powershell.instructions.md), [Documentation Instructions](.github/instructions/docs.instructions.md)

Read [.github/copilot-instructions.md](.github/copilot-instructions.md) before making changes. It is the authoritative repository constitution.

## Essential Rules

- No secrets in configs, examples, logs, transcripts, stdout, prompts, normalized evidence, or raw evidence.
- No live downloads in endpoint runtime paths.
- Runtime dependencies must be pinned and bundled when packaging.
- Fail closed when proof is missing.
- Detect maps to `dsc config test`.
- Remediate maps to `dsc config set`, then verifies with `dsc config test`.
- Preserve raw DSC output before normalization.
- Consumers read `wrapper.result.json`, not raw DSC fields.
- Reboots are durable, re-entrant, and owned by the execution plane.
- PowerShell uses `$ErrorActionPreference = 'Stop'` and `Set-StrictMode -Version Latest`.
- Unimplemented paths must be marked `TODO:` and return non-zero or throw.

## Validation

Use the repository validation commands:

```bash
npm run lint:md
pre-commit run --all-files
```

```powershell
Invoke-Pester -Path tests/ -Output Detailed
```
