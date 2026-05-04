<!-- markdownlint-disable MD013 -->
# Reset Lab

## Metadata

- **Status:** Draft
- **Owner:** Repository Maintainers
- **Last Updated:** 2026-05-03
- **Scope:** Lab reset guidance for ProStateKit demos.
- **Related:** [Demo Runbook](demo-runbook.md), [Troubleshooting](../troubleshooting.md)

## Current Status

Preview reset automation restores the LLMNR demo registry value through [Reset-DemoDrift.ps1](../../src/tools/Reset-DemoDrift.ps1). Local group and marker-file reset remain lab debt until adapter behavior is pinned and rehearsed on the Windows lab endpoint.

## Required Future Coverage

- Restore `HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient\EnableMulticast` to `0`.
- Remove or restore the controlled local group `Baseline-ControlledLocal` if testing the deferred adapter path.
- Remove or restore `C:\ProgramData\ProStateKit\Baseline\baseline-applied.txt` if testing the deferred adapter path.
- Clear generated runtime evidence outside committed synthetic samples.
- Confirm no reboot marker remains unless intentionally testing reboot behavior.
