<!-- markdownlint-disable MD013 -->
# Troubleshooting

## Metadata

- **Status:** Draft
- **Owner:** Repository Maintainers
- **Last Updated:** 2026-05-03
- **Scope:** Evidence-first troubleshooting workflow for ProStateKit runs.
- **Related:** [Contract](contract.md), [Exit Codes](exit-codes.md), [Evidence Schema](evidence-schema.md)

## Start With Evidence

Open the run folder under `<LogRoot>\Runs\<RunId>\`. Review `summary.txt` first, then `wrapper.result.json`, then raw DSC output.

## Compliant Detect

Expected exit is `0`. `overall.succeeded` and `overall.compliant` should both be `true`.

## Non-Compliant Detect

Expected exit is `1`. The result should be parseable and should identify drift without claiming runtime failure.

## Successful Remediate

Expected exit is `0` only after set and verification test both complete and the verification test proves compliance.

## Partial Convergence

Expected exit is `1`. Review `resources[]` for named failures. Partial convergence is not green even if some resources changed successfully.

## Runtime Failure

Expected Runner exit is `2`; the public entry point maps this to plane-facing exit `1` for local, Intune, and ConfigMgr. Check runtime path, version, hash validation, and process launch details. The current preview Runner resolves pinned bundle runtime under `runtime/dsc/` with a compatibility fallback to `Runtime/dsc/`.

## Parse Failure

Expected exit is `3`. Raw output should be preserved, and `wrapper.result.json` should explain that proof was missing or unparseable.

## Reboot Marker Present

Treat `<LogRoot>\Current\reboot.marker.json` as a durable handoff to the execution plane. Confirm the plane re-runs the Runner after reboot. The Runner clears the current marker only after verified compliance with no reboot requirement; run-level marker files remain historical evidence.
