<!-- markdownlint-disable MD013 -->
# Exit Codes

## Metadata

- **Status:** Draft
- **Owner:** Repository Maintainers
- **Last Updated:** 2026-05-03
- **Scope:** Defines Runner exit semantics for local, Intune, ConfigMgr, and CI-facing wrappers.
- **Related:** [Contract](contract.md), [Troubleshooting](troubleshooting.md), [Evidence Schema](evidence-schema.md)

## Detect

| Code | Meaning | Evidence Requirement |
| ---: | --- | --- |
| 0 | Compliant | Parsed proof shows every resource succeeded and is compliant. |
| 1 | Non-compliant | Parsed proof is valid and shows drift. |
| 2 | Runtime failure | Runtime selection, process launch, or DSC invocation failed. |
| 3 | Parse failure or proof missing | Raw output exists but cannot prove compliance. |

## Remediate

| Code | Meaning | Evidence Requirement |
| ---: | --- | --- |
| 0 | Success after verification | Set completed and verification test proves compliance. |
| 1 | Partial or failed convergence | At least one resource failed or verification still shows drift. |
| 2 | Runtime failure | Runtime selection, process launch, or DSC invocation failed. |
| 3 | Parse failure or proof missing | Set or verification output cannot be parsed into proof. |

## Intune Remediations

Intune Remediations detection exit `1` triggers remediation. Platform output is limited to roughly 2,048 characters, so the wrapper MUST keep full evidence on disk and return only a concise status bit plus short summary.

[src/Invoke-ProStateKit.ps1](../src/Invoke-ProStateKit.ps1) maps Runner runtime or parser failure codes to plane-facing exit `1` while preserving the detailed Runner decision in `wrapper.result.json`.

## ConfigMgr Configuration Items

ConfigMgr compliance handling depends on discovery script output type, compliance rule configuration, and remediation behavior. The ConfigMgr wrapper remains fail-closed until those semantics are lab-validated.

## Proof-Missing Handling

Any parse failure, missing raw output, missing normalized field, unknown shape, or partial convergence MUST produce a non-green status. The wrapper MUST NOT treat the DSC process exit code alone as compliance proof.
