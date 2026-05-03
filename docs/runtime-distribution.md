<!-- markdownlint-disable MD013 -->
# Runtime Distribution

## Metadata

- **Status:** Draft
- **Owner:** Repository Maintainers
- **Last Updated:** 2026-05-03
- **Scope:** Runtime mode rules for DSC and related execution dependencies.
- **Related:** [Packaging](packaging.md), [Contract](contract.md)

## Modes

| Mode | Purpose | Status |
| --- | --- | --- |
| `PinnedBundle` | Production default using the runtime included in the bundle. | Implemented surface; requires `bundle.manifest.json` plus reviewed runtime path, version, and hash. |
| `InstalledPath` | Managed prerequisite validated by path, version, and hash. | Implemented surface; production planes require expected hash and version parameters. |
| `LabLatest` | Compatibility test mode for local and CI labs. | Implemented surface; requires `-AllowLabLatest` and is blocked in Intune and ConfigMgr shims. |

## Rules

Endpoint runtime paths MUST NOT download DSC, PowerShell, resources, modules, or schemas. Production bundle mode MUST verify expected path, version, and hash before invoking DSC.

The current preview records observed runtime hash in evidence and requires `bundle.manifest.json` before executing `PinnedBundle` runtime mode. `InstalledPath` remains available for managed-prerequisite testing when explicit version and hash policy are supplied. A real pinned runtime is still required before release bundle creation can succeed.

## Review And Placement Workflow

The build owner must treat any DSC release as a candidate until review is complete. A candidate becomes the pinned runtime only after the reviewer records the selected version, release URL, source artifact hash, extracted runtime hash, and sign-off in [DSCv3-14a-next-steps.md](../DSCv3-14a-next-steps.md).

For the Windows demo bundle, review the official Windows x64 release archive, compute the archive SHA-256, extract the full archive into `runtime/dsc/`, and compute the hash of `runtime/dsc/dsc.exe`. Keep the supporting executables, resource manifests, adapter scripts, and notices from the archive with `dsc.exe`; do not copy only the executable. Maintainers may use [.github/scripts/Save-DscRuntimeCandidate.ps1](../.github/scripts/Save-DscRuntimeCandidate.ps1) in a disposable temp review directory to download a candidate asset, verify the source hash, extract the archive, and report the extracted runtime hash before any runtime files are copied into the repository. This helper is for maintainer review only and is not part of the endpoint runtime bundle.

After placement, run `tools/New-Package.ps1` with a disposable output path and then run `tools/Test-Bundle.ps1` against the staged bundle. Commit only the reviewed runtime files and source changes that are intended to ship. Do not commit generated ZIP files, `.sha256` files, root `bundle.manifest.json`, or lab evidence generated during review.
