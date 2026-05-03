<!-- markdownlint-disable MD013 -->
# Reset Lab

## Metadata

- **Status:** Draft
- **Owner:** Repository Maintainers
- **Last Updated:** 2026-05-03
- **Scope:** Lab reset guidance for ProStateKit demos.
- **Related:** [Demo Runbook](demo-runbook.md), [Troubleshooting](../troubleshooting.md)

## Current Status

Preview reset automation is implemented for the demo-owned marker file through [Reset-DemoDrift.ps1](../../src/tools/Reset-DemoDrift.ps1). Local group and registry reset remain lab debt until the exact DSC resource versions are pinned and rehearsed on the Windows lab endpoint.

## Required Future Coverage

- Remove or restore the controlled local group `Baseline-ControlledLocal`.
- Restore the LLMNR demo registry value to the chosen pre-demo state.
- Remove or restore `C:\ProgramData\ProStateKit\Baseline\baseline-applied.txt`.
- Clear generated runtime evidence outside committed synthetic samples.
- Confirm no reboot marker remains unless intentionally testing reboot behavior.
