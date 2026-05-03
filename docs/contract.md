<!-- markdownlint-disable MD013 -->
# Execution Contract

## Metadata

- **Status:** Draft
- **Owner:** Repository Maintainers
- **Last Updated:** 2026-05-03
- **Scope:** Defines the ProStateKit Runner contract, inputs, evidence outputs, and exit semantics for the current preview implementation.
- **Related:** [README](../README.md), [Exit Codes](exit-codes.md), [Evidence Schema](evidence-schema.md), [Packaging](packaging.md)

## Definition

The Runner is a reusable wrapper template, not a Microsoft product. It standardizes how execution planes call DSC v3, capture raw output, normalize evidence, and translate the result into a plane-specific status.

## Inputs

[src/runner/Runner.ps1](../src/runner/Runner.ps1) exposes this parameter contract:

| Parameter | Requirement |
| --- | --- |
| `Mode` | Mandatory. `Detect` or `Remediate`. |
| `ConfigPath` | Mandatory path to the DSC configuration document. |
| `BundleRoot` | Mandatory bundle root used to resolve the pinned runtime and resources. |
| `Plane` | Optional. `Local`, `Intune`, `ConfigMgr`, or `CI`; defaults to `Local`. |
| `RuntimeMode` | Optional. `PinnedBundle`, `InstalledPath`, or `LabLatest`; defaults to `PinnedBundle`. |
| `RuntimePath` | Optional explicit runtime path for managed-prerequisite testing. |
| `RuntimeExpectedHash` | Optional expected SHA-256 for `InstalledPath`; required with `RuntimeExpectedVersion` in production planes. |
| `RuntimeExpectedVersion` | Optional expected runtime version for `InstalledPath`; required with `RuntimeExpectedHash` in production planes. |
| `LogRoot` | Optional. Defaults to `C:\ProgramData\ProStateKit\Baseline`. |
| `RunId` | Optional. Defaults to `yyyyMMdd-HHmmss-<guid>`. |
| `AllowLabLatest` | Optional switch. Required before `LabLatest` can run in local or CI contexts. |
| `Strict` | Optional boolean. Defaults to `$true`; enables `Set-StrictMode -Version Latest`. |

[src/Invoke-ProStateKit.ps1](../src/Invoke-ProStateKit.ps1) is the public command-contract entry point. It adds `ValidateBundle` and `Preflight` modes and maps Runner-specific failure codes to plane-facing exit codes.

The public entry point supports `Detect`, `Remediate`, `ValidateBundle`, and `Preflight`. `ValidateBundle` runs [src/tools/Test-Bundle.ps1](../src/tools/Test-Bundle.ps1) against the selected bundle root. `Preflight` runs bundle validation, prerequisite checks, known-good Detect, deterministic drift, Remediate, and final Detect.

## Execution Semantics

Detect MUST map to `dsc config test --file <config> --output-format json`.

Remediate MUST map to `dsc config set --file <config> --output-format json`, then MUST verify with `dsc config test --file <config> --output-format json`. Remediate MUST NOT return success unless verification proves compliance.

## Evidence Outputs

Every run MUST write evidence under `<LogRoot>\Runs\<RunId>\`:

| File | Purpose |
| --- | --- |
| `transcript.log` | Wrapper transcript with sensitive values redacted or excluded. |
| `dsc.raw.json` | Raw DSC output preserved before interpretation. |
| `dsc.test.stdout.raw.json` | Raw DSC test output when DSC is invoked. |
| `dsc.set.stdout.raw.json` | Raw DSC set output for remediation runs when DSC is invoked. |
| `runtime.json` | Runtime mode, path, version, source, and hash metadata. |
| `manifest.snapshot.json` | Bundle manifest copy or missing-manifest marker. |
| `wrapper.result.json` | Normalized wrapper-owned result. |
| `summary.txt` | Short human-readable summary for platform output and troubleshooting. |
| `reboot.marker.json` | Optional durable reboot signal when required. |

The Runner also atomically updates `<LogRoot>\Current\last-result.json`.

When normalized proof reports `rebootRequired`, the Runner writes both run-level `reboot.marker.json` and `<LogRoot>\Current\reboot.marker.json`. A later verified compliant run with no reboot requirement clears only the current marker; historical run evidence remains immutable.

## Exit Codes

| Mode | Code | Meaning |
| --- | ---: | --- |
| Detect | 0 | Compliant. |
| Detect | 1 | Non-compliant. |
| Detect | 2 | Runtime failure. |
| Detect | 3 | Parse failure or proof missing. |
| Remediate | 0 | Success after verification. |
| Remediate | 1 | Partial or failed convergence. |
| Remediate | 2 | Runtime failure. |
| Remediate | 3 | Parse failure or proof missing. |

## False-Green Prevention

Success requires parsing the DSC result payload and confirming every normalized resource result succeeded. Unknown result shapes, parse failures, missing evidence, resource failures, and partial convergence MUST fail closed.

## Strictness

`-Strict:$true` is the default. PowerShell code MUST set `$ErrorActionPreference = 'Stop'` and use strict mode for wrapper behavior unless a specific compatibility exception is documented and tested.

## Secrets

Configuration documents MUST NOT contain secrets. Runtime retrieval MAY use `Microsoft.PowerShell.SecretManagement` after the secret helper is implemented, but secret values MUST NOT be emitted to transcripts, stdout, logs, raw evidence, normalized evidence, or summaries.

## Current Status

The current Runner is a preview implementation. It validates local paths, rejects symlink escape paths, requires `bundle.manifest.json` before executing `PinnedBundle` runtime mode, validates the bundle manifest schema, rejects duplicate manifest file paths, enforces bundle manifest hashes, requires the selected `ConfigPath` to be covered by manifest hashes, supports the `InstalledPath` and guarded `LabLatest` runtime-mode surfaces, invokes DSC when a validated runtime is present, preserves raw output, writes normalized evidence, writes a sanitized wrapper transcript summary, and fails closed when runtime or parser proof is missing. The checked-in DSC fixture tests now cover multiple resource-output shapes, but they remain compatibility samples until the pinned runtime is selected and lab replayed. Packaging still fails closed until a real pinned DSC runtime and release manifest hashes are supplied. TODO: add lab-validated reboot orchestration behavior.
