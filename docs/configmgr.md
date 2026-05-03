<!-- markdownlint-disable MD013 -->
# ConfigMgr

## Metadata

- **Status:** Draft
- **Owner:** Repository Maintainers
- **Last Updated:** 2026-05-03
- **Scope:** Configuration Manager wrapper expectations for ProStateKit.
- **Related:** [Contract](contract.md), [Exit Codes](exit-codes.md), [Packaging](packaging.md)

## Pattern

The intended playbook uses an Application or Package to distribute the bundle and Configuration Items to discover and remediate state. DSC configs and parser logic stay common; ConfigMgr-specific code handles compliance output and remediation semantics. Preview shims live under [planes/configmgr](../planes/configmgr/) and call [src/Invoke-ProStateKit.ps1](../src/Invoke-ProStateKit.ps1).

## Current Status

[src/runner/ConfigMgr/Runner.ps1](../src/runner/ConfigMgr/Runner.ps1) and the `planes/configmgr` scripts are fail-closed preview shims. ConfigMgr behavior with the final pinned bundle is explicitly unproven until compliance-setting output type and remediation behavior are lab-validated; keep the docs non-prescriptive until that evidence exists.
