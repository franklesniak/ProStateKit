<!-- markdownlint-disable MD013 -->
# Resource Gaps

## Metadata

- **Status:** Draft
- **Owner:** Repository Maintainers
- **Last Updated:** 2026-05-03
- **Scope:** Guidance for handling desired state when a DSC v3 resource does not directly cover the requirement.
- **Related:** [Contract](contract.md), [Packaging](packaging.md), [Secrets](secrets.md)

## Decision Tree

Use a DSC resource when a pinned, reviewed resource expresses the target state directly and emits parseable proof. Wrap script logic deliberately only when no suitable resource exists and the script can test, set, and report state deterministically. Write a custom resource when the gap is repeated, shared, or too complex for safe inline logic.

## Fail Closed In Script-Wrapping Resources

Script-wrapping resources MUST validate inputs, reject path traversal, avoid live downloads, avoid secret leakage, emit structured status, and return failure when proof is missing. They MUST NOT hide partial changes behind success output.

## Testing Requirements

Resource gaps require tests for compliant state, drift, remediation, parser failure, and unsafe input. Any helper that writes evidence must include redaction checks.
