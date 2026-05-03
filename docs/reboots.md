<!-- markdownlint-disable MD013 -->
# Reboots

## Metadata

- **Status:** Draft
- **Owner:** Repository Maintainers
- **Last Updated:** 2026-05-03
- **Scope:** Reboot signaling and re-entrant execution requirements for ProStateKit.
- **Related:** [Contract](contract.md), [Exit Codes](exit-codes.md), [Packaging](packaging.md)

## Ownership

The execution plane owns reboot orchestration. DSC owns idempotent convergence. The Runner records evidence and returns a plane-appropriate signal; it MUST NOT directly reboot in Intune Remediations mode.

## Re-Entrant Pattern

1. The plane runs the Runner.
2. The Runner applies what it can and signals reboot required when needed.
3. The plane reboots according to policy.
4. The plane re-runs the Runner.
5. The Runner skips already-correct state and verifies completion.

## Signaling Contract

Two options remain under review:

| Option | Pattern | Status |
| --- | --- | --- |
| Dedicated exit code plus `reboot.marker.json` | Plane sees a reboot-specific code and durable marker. | Deferred until Intune and ConfigMgr lab validation. |
| Success/non-success plus marker file | Plane consumes marker while preserving existing exit meanings. | Preview default: Runner writes run-level and current `reboot.marker.json` when normalized proof reports `rebootRequired`. |

## Scheduled-Task Fallback

For planes without reboot orchestration, a scheduled-task continuation MAY be considered only after it is signed, self-cleans on success, has a TTL, writes audit records under `<LogRoot>\ScheduledTaskAudit\`, and is not persistence-like.

## DSC Signal Strategy

The wrapper MUST NOT rely on the removed `_rebootRequested` schema property. Reboot detection currently uses normalized resource `rebootRequired` values. Future detection should layer explicit resource opt-in properties, post-apply pending-reboot probes, and manifest declaration metadata.

## Marker Cleanup

Run-level `reboot.marker.json` remains historical evidence. `<LogRoot>\Current\reboot.marker.json` is the mutable handoff marker for the execution plane. The Runner removes the current marker only after a later run verifies compliance and reports no reboot requirement.
