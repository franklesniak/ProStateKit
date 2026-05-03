<!-- markdownlint-disable MD013 -->
# Demo Runbook

## Metadata

- **Status:** Draft
- **Owner:** Repository Maintainers
- **Last Updated:** 2026-05-03
- **Scope:** Reproducible demo path for ProStateKit. Commands are preview-stage and fail closed until pinned DSC runtime integration is completed.
- **Related:** [Contract](../contract.md), [Troubleshooting](../troubleshooting.md), [Packaging](../packaging.md)

## Lab Prerequisites

- Windows lab endpoint with permission to test DSC v3 resources.
- ProStateKit checkout or built bundle.
- Node.js 20 or later for `ValidateBundle` / `Preflight` YAML parsing in the preview toolchain.
- Pinned `dsc.exe` version: TBD.
- Pinned resource modules: TBD.

## Bundle Build

```powershell
pwsh -File .\tools\Build-Bundle.ps1
```

Expected preview result without a pinned runtime: non-zero failure stating that the pinned DSC runtime is required, with no partial release artifact.

## Local Install Or Extraction

After `Build-Bundle.ps1` produces `dist\ProStateKit-0.1.0.zip`, extract it to the lab bundle path:

```powershell
New-Item -Path C:\ProgramData\ProStateKit\Bundle -ItemType Directory -Force
Expand-Archive -Path .\dist\ProStateKit-0.1.0.zip -DestinationPath C:\ProgramData\ProStateKit\Bundle -Force
```

Expected preview result before runtime pinning: there is no ZIP to extract because bundle build fails closed.

## Local Preflight

```powershell
pwsh -File .\planes\local\Invoke-LocalPreflight.ps1 -BundleRoot . -RuntimeMode PinnedBundle
```

Expected preview result on a clean checkout without `bundle.manifest.json` and `runtime/dsc/dsc.exe`: exit `1` with a report under `C:\ProgramData\ProStateKit\Evidence\Preflight\<OperationId>\preflight.report.json`.

## Known-Good Detect

```powershell
pwsh -File .\src\Invoke-ProStateKit.ps1 -Mode Detect -Plane Local -ConfigPath .\configs\baseline.dsc.yaml -RuntimeMode PinnedBundle -BundleRoot .
```

Expected preview result on a clean checkout without `runtime/dsc/dsc.exe`: public entry-point exit `1`; `wrapper.result.json` records Runner exit decision `2` with runtime-failure evidence under the selected evidence root.

## Evidence To Open On Stage

Use synthetic fallback evidence until real lab evidence exists:

- `evidence/sample/compliant-detect/summary.txt`
- `evidence/sample/noncompliant-detect/wrapper.result.json`
- `evidence/sample/successful-remediate/wrapper.result.json`
- `evidence/sample/partial-failure/wrapper.result.json`
- `evidence/sample/parse-failure/summary.txt`

## Deterministic Drift

```powershell
pwsh -File .\src\tools\New-DemoDrift.ps1
```

Expected preview result: removes the demo marker file. Registry and local-group drift steps remain lab debt until the exact DSC resource versions are pinned.

## Detect After Drift

```powershell
pwsh -File .\src\Invoke-ProStateKit.ps1 -Mode Detect -Plane Local -ConfigPath .\configs\baseline.dsc.yaml -RuntimeMode PinnedBundle -BundleRoot .
```

Expected preview result without runtime: exit `1` and runtime-failure evidence. Expected lab result after runtime pinning: exit `1` with noncompliant resource proof.

## Remediate

```powershell
pwsh -File .\src\Invoke-ProStateKit.ps1 -Mode Remediate -Plane Local -ConfigPath .\configs\baseline.dsc.yaml -RuntimeMode PinnedBundle -BundleRoot .
```

Expected preview result without runtime: exit `1` and runtime-failure evidence. Expected lab result after runtime pinning: exit `0` only after post-set verification proves compliance.

## Final Detect

Use the same command as Known-Good Detect. Expected lab result after runtime pinning and remediation: exit `0` with `classification` set to `Compliant`.

## Reset

Use [reset-lab.md](reset-lab.md) or:

```powershell
pwsh -File .\src\tools\Reset-DemoDrift.ps1
```

## Fallback Paths

Use checked-in synthetic evidence if runtime, parser, resource, reboot, or evidence write behavior is not ready for stage rehearsal. Do not present synthetic output as live endpoint proof.

Fallback captures to prepare before the talk:

- Screenshot of `evidence/sample/compliant-detect/wrapper.result.json`.
- Screenshot of `evidence/sample/noncompliant-detect/summary.txt`.
- Screenshot of `evidence/sample/successful-remediate/wrapper.result.json`.
- Screenshot of `evidence/sample/partial-failure/wrapper.result.json`.
- Screenshot of `evidence/sample/parse-failure/summary.txt`.

## Timing Budget

| Step | Target |
| --- | ---: |
| Explain operating model | 2 minutes |
| Run known-good Detect | 1 minute |
| Create deterministic drift | 1 minute |
| Run Detect after drift | 1 minute |
| Run Remediate | 2 minutes |
| Open evidence and explain false-green prevention | 3 minutes |

TODO: replace targets with measured timings after two clean rehearsals.

## Release Readiness Gate

After runtime placement, dry release, two clean rehearsals, Intune validation, ConfigMgr validation, public-flip tasks, deck reconciliation, and the final DSC release recheck are complete, run:

```powershell
pwsh -File .\tools\Test-ReleaseReadiness.ps1
```

Expected preview result before those external actions are complete: exit `1` with a fail-closed readiness report.
