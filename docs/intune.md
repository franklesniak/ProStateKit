<!-- markdownlint-disable MD013 -->
# Intune

## Metadata

- **Status:** Draft
- **Owner:** Repository Maintainers
- **Last Updated:** 2026-05-03
- **Scope:** Intune Remediations wrapper expectations for ProStateKit.
- **Related:** [Contract](contract.md), [Exit Codes](exit-codes.md), [Packaging](packaging.md)

## Pattern

The intended pattern is a managed Win32 app or equivalent content channel that places the bundle on disk, then Intune Remediations runs [planes/intune/Detect-ProStateKit.ps1](../planes/intune/Detect-ProStateKit.ps1) and [planes/intune/Remediate-ProStateKit.ps1](../planes/intune/Remediate-ProStateKit.ps1). The legacy scaffold paths under `src/runner/Intune/` call the same Runner contract.

## Semantics

Detection exit `1` means drift and should trigger remediation. Detection exit `0` means verified compliance. Runtime or proof failures fail closed and must preserve evidence behind the short platform summary.

## Current Status

The Intune scripts are thin preview shims. They call the common Runner, return `0` only for verified compliance or verified remediation, and return `1` for drift, runtime failure, parser failure, or missing proof. Intune behavior with the final pinned bundle is explicitly unproven until lab validation is complete; do not publish prescriptive screenshots or tenant rollout steps before that evidence exists.
