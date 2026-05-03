<!-- markdownlint-disable MD013 -->
# Secrets

## Metadata

- **Status:** Draft
- **Owner:** Repository Maintainers
- **Last Updated:** 2026-05-03
- **Scope:** Secret handling rules for ProStateKit configs, runtime retrieval, evidence, prompts, and issues.
- **Related:** [Security Policy](../SECURITY.md), [Contract](contract.md), [Evidence Schema](evidence-schema.md)

## Configuration Rule

Do not place secrets in configs. This includes plaintext, Base64, encrypted values whose key is in the repository, tokens, passwords, connection strings, certificates with private key material, and tenant-specific private values.

## Runtime Retrieval

Runtime retrieval should use `Microsoft.PowerShell.SecretManagement` with an approved vault extension. Azure Key Vault is the canonical production pattern to evaluate after execution context and resource behavior are validated.

## Helper Rules

[src/tools/SecretHelper.ps1](../src/tools/SecretHelper.ps1) is a fail-closed scaffold. When implemented, it MUST redact values from surfaced errors, MUST NOT emit values to transcript, stdout, normalized result, raw evidence, or summaries, and MUST record only fact-of-retrieval metadata such as vault name and item name.

## Failure Behavior

Any secret resolution failure MUST exit non-zero and MUST NOT apply partial configuration. TODO: assign a distinct code or normalized classification before secret-backed resources are implemented.

## Issue Hygiene

Do not paste secrets, tenant identifiers, customer data, private logs, unredacted transcripts, full raw evidence bundles, or sensitive endpoint inventory into issues, prompts, or review comments.
