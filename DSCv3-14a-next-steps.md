<!-- markdownlint-disable MD013 -->
# DSCv3 14a Next Steps

## Metadata

- **Status:** Active
- **Owner:** Repository Maintainers
- **Last Updated:** 2026-05-03
- **Scope:** Tracks ProStateKit and deck work that remains after the preview repository scaffold. This file keeps unresolved questions explicit until they are resolved, lab-validated, or moved into a public issue.
- **Related:** [ProStateKit Technical Specification](ProStateKit.md), [Deck Specification](DSCv3-14-deck-spec.md), [Completion Audit](docs/completion-audit.md), [Post-Public-Flip TODO](_TODO.md), [Demo Runbook](docs/runbooks/demo-runbook.md)

## Current Position

The repository now has a preview Runner, validation command, bundle tooling, schemas, evidence samples, management-plane shims, and runbooks. It intentionally does not ship a pinned DSC runtime or claim production readiness. Release packaging, lab proof, public repository settings, and final deck screenshots remain blocked until the external actions below are completed.

The current prompt-to-artifact and `_init-instructions.md` Step 1 through Step 27 mapping is tracked in [docs/completion-audit.md](docs/completion-audit.md). Keep that audit synchronized when blockers are closed or the objective scope changes.

Use `tools/Test-ReleaseReadiness.ps1` for a fail-closed readiness report after runtime placement, dry release, lab validation, public flip, deck reconciliation, and final DSC release recheck evidence exists. On the preview scaffold it is expected to return non-zero.

## Blocking Actions

| ID | Owner | Blocking Item | Required Evidence Before Closure |
| --- | --- | --- | --- |
| NEXT-001 | Build owner | Select the pinned DSC release and place the reviewed executable under `runtime/dsc/`. | Version, source URL, source hash, observed bundle hash, and reviewer sign-off recorded in docs and manifest. |
| NEXT-002 | Build owner | Run a dry release through `tools/New-Package.ps1`. | `ProStateKit-<version>.zip`, `bundle.manifest.json`, and `.sha256` produced in a disposable output directory and verified by `Test-Bundle.ps1`. |
| NEXT-003 | Repository owner | Complete public flip tasks in [_TODO.md](_TODO.md). | Public visibility, Private Vulnerability Reporting, branch protection, final security URL, final Code of Conduct contact, and Discussions link verified. |
| NEXT-004 | Demo owner | Rehearse the local runbook twice from a clean reset. | Two timestamped evidence directories with known-good Detect, drift Detect, Remediate, final Detect, and reset notes. |
| NEXT-005 | Intune owner | Validate final pinned bundle through Intune Remediations. | Detection exit/output, remediation exit/output, evidence path, and portal screenshots sanitized and archived. |
| NEXT-006 | ConfigMgr owner | Validate final pinned bundle through ConfigMgr compliance settings. | Discovery output type, remediation behavior, unknown/failure handling, evidence path, and console screenshots sanitized and archived. |
| NEXT-007 | Content owner | Reconcile [DSCv3-14-deck-spec.md](DSCv3-14-deck-spec.md) with real repo commands and evidence. | Slide notes updated with actual file names, commands, screenshots, evidence fields, and any caveats that remain. |
| NEXT-008 | Security reviewer | Decide whether any real secret-flow sample belongs in the repository. | Written decision. Current default remains no real secrets in demo configs, logs, prompts, raw evidence, normalized evidence, or samples. |
| NEXT-009 | Content owner | Recheck latest DSC release one week before deck freeze. | Keep v3.2.0 or select a later stable release only after lab validation and docs updates. |

## Release Watch

- 2026-05-03: Microsoft announced DSC v3.2.0 as GA on 2026-04-29, and `gh release view --repo PowerShell/DSC` reports latest non-prerelease tag `v3.2.0` published at `2026-04-29T18:29:17Z`. This is a watch note only; it does not select, download, hash, or lab-validate the pinned runtime.

## Pinned Runtime Candidate Evidence

This section records candidate evidence for NEXT-001. It does not close NEXT-001 and does not select the pinned runtime until reviewer sign-off and lab validation are complete.

- Candidate release: `PowerShell/DSC` tag `v3.2.0`, published `2026-04-29T18:29:17Z`, non-prerelease.
- Candidate release page: <https://github.com/PowerShell/DSC/releases/tag/v3.2.0>.
- Candidate Windows x64 asset: `DSC-3.2.0-x86_64-pc-windows-msvc.zip`.
- Candidate asset URL: <https://github.com/PowerShell/DSC/releases/download/v3.2.0/DSC-3.2.0-x86_64-pc-windows-msvc.zip>.
- Observed candidate ZIP SHA-256: `638f5e93197ebe64d6d15de743773728e0f0ed22407bd4decc69581e42d43194`.
- Observed extracted `dsc.exe` SHA-256: `6ee88bd4c93c4a94539a0af0667ace8ffba48f5b8732930e1421721621ca19de`.
- Candidate ZIP inspection: 55 files, including `dsc.exe`, `registry.exe`, `dscecho.exe`, `dsc-bicep-ext.exe`, adapter scripts, resource manifests, `NOTICE.txt`, and sample Windows DSC YAML files.
- Current repository action: candidate artifact was downloaded only to `/tmp/prostatekit-dsc-candidate` for inspection and then removed. It was not copied into `runtime/dsc/`, not committed, and not treated as reviewed.
- Candidate helper: [.github/scripts/Save-DscRuntimeCandidate.ps1](.github/scripts/Save-DscRuntimeCandidate.ps1) can re-download the selected asset into a disposable temp directory, verify `ExpectedSourceSha256`, extract the archive, and report the extracted runtime hash before reviewer placement.
- Candidate helper verification: 2026-05-03, `Save-DscRuntimeCandidate.ps1` verified the candidate source hash and extracted `dsc.exe` hash above from its default current-user temp working root, extracted 55 files, and reported the next step as full-payload review before copying anything into `runtime/dsc/`. This verification is not reviewer sign-off and does not close NEXT-001.

### NEXT-001 Reviewer Sign-Off Checklist

- [ ] Confirm `v3.2.0` remains the intended pinned release, or replace this candidate before placement.
- [ ] Re-download the selected release asset from the official release URL in a disposable temp review directory, optionally with `.github/scripts/Save-DscRuntimeCandidate.ps1`.
- [ ] Recompute and compare the source artifact SHA-256 before extraction.
- [ ] Inspect the archive contents and keep the full reviewed archive payload with `dsc.exe` under `runtime/dsc/`.
- [ ] Recompute the extracted `runtime/dsc/dsc.exe` SHA-256 after placement.
- [ ] Run `runtime/dsc/dsc.exe --version` on the Windows lab endpoint and record the observed version.
- [ ] Run `tools/New-Package.ps1` with a disposable output path and verify `tools/Test-Bundle.ps1` passes for the staged bundle.
- [ ] Record reviewer name or handle, review date, selected version, release URL, source artifact hash, extracted runtime hash, and observed bundle manifest hash before closing NEXT-001.

## Open Questions

1. Is the LLMNR registry example stable and visible enough for the live demo, or should the demo use a replacement registry-backed or file-backed control?
2. What exact ConfigMgr compliance discovery output and remediation behavior should ProStateKit document after lab validation?
3. Should first public release artifacts require Authenticode signatures in addition to SHA-256 hashes?
4. Should reboot marker cleanup be implemented as a Runner behavior, a plane-owned cleanup behavior, or a runbook-only lab step for the first public version?
5. Should YAML parsing remain Node-backed for preview validation, or should the project adopt a reviewed PowerShell-native YAML parser before release packaging?

## Deck Reconciliation Checklist

- Replace all [REPO] placeholders with actual paths from this repository.
- Replace all [LAB] placeholders with sanitized evidence from the final pinned bundle.
- Replace all [REHEARSAL] placeholders with screenshots and timing from two clean rehearsals.
- Keep slides about Intune and ConfigMgr cautious until the matching lab validation artifacts exist.
- Keep the release/version slide tied to the selected pinned DSC runtime and manifest hashes.
- Do not present synthetic checked-in evidence as live endpoint proof.
