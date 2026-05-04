<!-- markdownlint-disable MD013 -->
# Packaging

## Metadata

- **Status:** Draft
- **Owner:** Repository Maintainers
- **Last Updated:** 2026-05-04
- **Scope:** Bundle layout, manifest, checksum, and release posture for ProStateKit.
- **Related:** [Bundle Manifest Schema](../schemas/bundle-manifest.schema.json), [Contract](contract.md), [Runtime Distribution](runtime-distribution.md)

## Pinned Runtime Principle

Pin everything used by endpoint runtime paths: DSC executable, optional PowerShell, resources, modules, wrapper scripts, and configuration documents. Production endpoint runs MUST NOT perform live downloads.

## Supply-Chain Artifacts

The release artifact set is source plus bundle ZIP plus `bundle.manifest.json` plus a SHA-256 checksum file. [tools/Build-Bundle.ps1](../tools/Build-Bundle.ps1) and [tools/New-Package.ps1](../tools/New-Package.ps1) generate those artifacts only after the pinned runtime exists. [tools/New-Package.ps1](../tools/New-Package.ps1) runs bundle validation before returning success. They fail closed rather than creating fake or partial bundles.

[tools/Test-ReleaseReadiness.ps1](../tools/Test-ReleaseReadiness.ps1) reports whether the external release evidence is present. It fails closed on the preview scaffold until the reviewed runtime, dry release output, local rehearsal evidence, Intune and ConfigMgr lab evidence, public flip, deck reconciliation, and final DSC release recheck are complete.

## Bundle Layout

```text
BaselineBundle/
  runtime/dsc/          (pinned dsc executable + shared libs)
  resources/            (pinned resource modules)
  configs/              (baseline.dsc.yaml, generated/baseline.dsc.json)
  src/                  (Invoke-ProStateKit.ps1, modules, Runner, tools)
  planes/               (Intune, ConfigMgr, local shims)
  tests/                (Pester tests and DSC output fixtures)
  evidence/sample/      (synthetic fallback evidence)
  schemas/examples/     (valid and invalid schema fixtures)
  package.json          (Node.js validation tool metadata)
  package-lock.json     (locked Node.js dependency metadata)
  node_modules/         (selected parser runtime dependencies only)
  .github/scripts/      (selected Markdown validation helpers only)
  .github/linting/      (PSScriptAnalyzer settings)
  bundle.manifest.json
```

Maintainer-only review helpers such as `.github/scripts/Save-DscRuntimeCandidate.ps1` stay source-only and are not included in endpoint bundles.

## Delivery Channels

Supported delivery patterns to validate include Intune Win32 app, ConfigMgr application or package, Arc/server extension, and golden image bake-in.

## Offline Determinism

The Runner MUST fail closed if an expected binary, resource module, config, or manifest entry is missing under `BundleRoot`. Runtime, configuration, and manifest paths must resolve inside `BundleRoot` and must not include symlink or reparse-point components.

`Test-Bundle.ps1` validates manifest schema, safe bundle-relative paths, required files, duplicate manifest paths, untracked bundle files, hashes, runtime version, and packaged config parseability. The preview YAML parser uses Node.js 20 or later plus the packaged `js-yaml` dependency. `Build-Bundle.ps1` copies only the selected parser runtime dependencies from the repository's `node_modules/`; it fails closed if `npm install` has not populated them before bundle creation.

## Future Release Workflow

Do not add a tag-triggered release workflow until packaging produces real artifacts. The intended future flow is: tag `v*.*.*`, run `tools/New-Package.ps1`, generate bundle ZIP, generate `bundle.manifest.json`, generate SHA-256 checksum, validate the staged bundle with `tools/Test-Bundle.ps1`, publish a draft GitHub Release, and fail closed if any expected artifact is missing.
