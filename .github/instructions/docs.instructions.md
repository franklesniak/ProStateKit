---
applyTo: "**/*.md"
description: "Documentation standards for ProStateKit Markdown."
---

<!-- markdownlint-disable MD013 -->
# Documentation Writing Style

**Version:** 2.0.20260503.0

## Metadata

- **Status:** Active
- **Owner:** Repository Maintainers
- **Last Updated:** 2026-05-03
- **Scope:** Markdown standards for ProStateKit docs, runbooks, schemas, issue guidance, and agent instructions.
- **Related:** [Repository Instructions](../copilot-instructions.md)

## Core Requirements

- Write practitioner-first, direct, concrete, sponsor-safe documentation.
- Keep wording stage-safe: ProStateKit is a preview starter kit, not a finished product.
- Do not overclaim production readiness, platform validation, DSC version support, or security guarantees.
- Use `TODO:` for unimplemented behavior instead of describing it as complete.
- Keep execution semantics consistent with the Runner contract: Detect maps to `dsc config test`; Remediate maps to `dsc config set` plus verification.
- Never instruct users to paste secrets, tenant identifiers, customer data, private logs, unredacted transcripts, or full evidence bundles.
- Prefer relative links for repository files.
- Include `<!-- markdownlint-disable MD013 -->` at the top of Markdown files for portability.

## Durable Docs

Documents longer than about 30 lines or intended as durable references SHOULD include a metadata block with `Status`, `Owner`, `Last Updated`, `Scope`, and `Related`.

When behavior changes, update the relevant contract docs in the same change:

- Exit semantics: `docs/exit-codes.md`
- Evidence shape: `docs/evidence-schema.md`
- Reboot behavior: `docs/reboots.md`
- Secret handling: `docs/secrets.md`
- Packaging or runtime distribution: `docs/packaging.md`

## Examples And Runbooks

Commands in runbooks MUST be copy/paste safe and must not destroy data without an explicit warning. If a command is expected to fail because the implementation is a scaffold, state the expected non-zero outcome.
