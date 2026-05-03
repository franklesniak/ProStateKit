<!-- markdownlint-disable MD013 -->
# Agent Instructions For Claude Code

**Version:** 2.0.20260503.0

## Metadata

- **Status:** Active
- **Owner:** Repository Maintainers
- **Last Updated:** 2026-05-03
- **Scope:** Minimal entry point for Claude Code and compatible AI coding agents operating in ProStateKit.
- **Related:** [Repository Instructions](.github/copilot-instructions.md), [PowerShell Instructions](.github/instructions/powershell.instructions.md)

Read [.github/copilot-instructions.md](.github/copilot-instructions.md) before making changes. It is the authoritative repository constitution.

## Essential Rules

- No secrets in configs, examples, logs, transcripts, stdout, prompts, normalized evidence, or raw evidence.
- Endpoint runtime paths must not perform live downloads.
- Package runtime dependencies only when they are pinned, bundled, and recorded in the manifest.
- Detect maps to `dsc config test`; Remediate maps to `dsc config set` plus verification `dsc config test`.
- Preserve raw DSC output before deriving `wrapper.result.json`.
- Missing proof, parser failure, unknown DSC shape, resource failure, or partial convergence fails closed.
- Reboots are execution-plane owned, durable, and re-entrant.
- Use Pester tests for PowerShell behavior changes.
- Keep docs accurate to preview status; do not claim production readiness.
