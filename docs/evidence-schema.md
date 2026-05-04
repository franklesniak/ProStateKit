<!-- markdownlint-disable MD013 -->
# Evidence Schema

## Metadata

- **Status:** Draft
- **Owner:** Repository Maintainers
- **Last Updated:** 2026-05-04
- **Scope:** Documents raw DSC evidence preservation and the normalized `wrapper.result.json` schema.
- **Related:** [Wrapper Result Schema](../schemas/wrapper-result.schema.json), [Contract](contract.md), [Troubleshooting](troubleshooting.md)

## Why Raw Output Is Preserved

Raw DSC output is required for forensic review, parser drift analysis, and compatibility checks across DSC versions. The Runner MUST write raw output before normalization so parser failures do not erase the original proof source.

## Normalized Fields

`wrapper.result.json` MUST match [schemas/wrapper-result.schema.json](../schemas/wrapper-result.schema.json). Required fields are:

| Field | Meaning |
| --- | --- |
| `schemaVersion` | Normalized evidence schema version. |
| `operationId` / `runId` | Stable run identifier. |
| `mode` | `Detect` or `Remediate`. |
| `plane` | `Local`, `Intune`, `ConfigMgr`, or `CI`. |
| `runtime` | Runtime mode, path, version, expected hash, and observed hash. |
| `config` | Configuration path and observed hash. |
| `startedAt` / `endedAt` / `durationMs` | RFC 3339 timestamps and duration for the wrapper operation. |
| `startedUtc` / `endedUtc` | RFC 3339 timestamps for the wrapper operation. |
| `dscVersion` | Observed DSC runtime version, or `TBD` in samples before pinning. |
| `compliant` / `classification` | Stable top-level state for automation. |
| `overall.succeeded` | Wrapper decision that runtime and parser work succeeded. |
| `overall.compliant` | Compliance state proven by normalized resource results. |
| `overall.rebootRequired` | Durable reboot signal summary. |
| `resources[]` | Per-resource normalized proof. |
| `exitDecision` | Runner exit code and reason before plane-specific translation. |
| `evidencePath` | Path to the run evidence directory. |

Each resource result requires `name`, `type`, `succeeded`, `changed`, `error`, and `rebootRequired`.

## Schema Versioning

The schema is additive. Consumers SHOULD read wrapper-owned normalized fields and MUST NOT depend directly on raw DSC fields. Breaking changes require a new schema version, fixture updates, docs updates, and tests.

## Resource Normalization

Success requires per-resource success. The preview parser accepts resource collections from top-level `resources`, `results`, `result`, or `actualState`; if those are absent, it accepts a single root object only when that object has resource identity fields. Resource name resolves from `name`, `resourceName`, then `instanceName`. Resource type resolves from `type`, `resourceType`, then `fullyQualifiedTypeName`. Success resolves from `succeeded`, `success`, `inDesiredState`, then `compliant` on the resource object, or from the same fields under a nested DSC `result` object. A textual `result` value of `Success`, `Succeeded`, `Compliant`, or `InDesiredState` is also treated as success, while `Fail`, `Error`, `NonCompliant`, or `NotInDesiredState` is treated as failure. Change state resolves from `changed`, `wasChanged`, then `rebootRequired` on the resource object or nested DSC `result`, and Detect mode forces `changed` to `false`.

## Fail-Closed Strategy

Unknown DSC result shape, invalid JSON, missing required fields, failed resources, and partial convergence all produce non-green normalized evidence. Parse failure uses exit `3` and preserves raw output as `dsc.raw.txt` or `dsc.raw.json` depending on what was captured.

## Sample

```json
{
  "schemaVersion": "1.0.0",
  "operationId": "20260512-093501-0a1b",
  "runId": "20260512-093501-0a1b",
  "mode": "Remediate",
  "plane": "Local",
  "bundle": {
    "name": "ProStateKit",
    "version": "0.1.0",
    "sourceCommit": "unknown",
    "manifestHash": "TBD"
  },
  "runtime": {
    "mode": "PinnedBundle",
    "path": "runtime/dsc/dsc.exe",
    "version": "TBD",
    "expectedHash": "TBD",
    "observedHash": "TBD"
  },
  "config": {
    "path": "configs/baseline.dsc.yaml",
    "hash": "TBD"
  },
  "startedAt": "2026-05-12T14:35:01Z",
  "endedAt": "2026-05-12T14:35:09Z",
  "durationMs": 8000,
  "startedUtc": "2026-05-12T14:35:01Z",
  "endedUtc": "2026-05-12T14:35:09Z",
  "dscVersion": "TBD",
  "compliant": true,
  "classification": "Compliant",
  "overall": {
    "succeeded": true,
    "compliant": true,
    "rebootRequired": false
  },
  "resources": [
    {
      "name": "LLMNR disabled",
      "type": "Microsoft.Windows/Registry",
      "succeeded": true,
      "changed": false,
      "error": null,
      "rebootRequired": false
    }
  ],
  "exitDecision": {
    "exitCode": 0,
    "reason": "VerifiedCompliant"
  },
  "reboot": {
    "required": false,
    "signals": []
  },
  "evidencePath": "evidence/sample/successful-remediate",
  "errors": [],
  "warnings": []
}
```
