<!-- markdownlint-disable MD013 -->
# Agent Instructions For Gemini Code Assist

**Version:** 2.0.20260503.0

## Metadata

- **Status:** Active
- **Owner:** Repository Maintainers
- **Last Updated:** 2026-05-03
- **Scope:** Minimal entry point for Gemini Code Assist and compatible AI coding agents operating in ProStateKit.
- **Related:** [Repository Instructions](.github/copilot-instructions.md), [Documentation Instructions](.github/instructions/docs.instructions.md)

Read [.github/copilot-instructions.md](.github/copilot-instructions.md) before making changes. It is the authoritative repository constitution.

## Essential Rules

- No secrets in configs, examples, logs, transcripts, stdout, prompts, normalized evidence, or raw evidence.
- Runtime paths do not perform live downloads.
- Detect maps to `dsc config test`; Remediate maps to `dsc config set` plus verification `dsc config test`.
- Raw DSC output is preserved before normalized evidence is derived.
- Missing proof, unknown result shape, parser failure, resource failure, or partial convergence fails closed.
- PowerShell changes require strict error handling and Pester coverage where behavior changes.
- Documentation must be practitioner-first, direct, concrete, sponsor-safe, and stage-safe.
