# ProStateKit — Coding Agent Implementation Instructions

## Project Context

You are working in the `franklesniak/ProStateKit` repository, which was created from the `franklesniak/copilot-repo-template` GitHub template. Your job is to transform the template into a project-specific starter kit and scaffold the project's content. Work iteratively; treat this document as the full specification.

**ProStateKit is a starter kit for reliable endpoint state with PowerShell Desired State Configuration (DSC) v3.** It is the public deliverable for a 2026 conference talk titled "Cure Script Fatigue: Reliable Endpoint State with DSC v3." It provides:

- A reusable PowerShell Runner that wraps DSC v3 invocations with strict error handling, structured evidence, an explicit exit-code contract, and false-green prevention.
- Management-plane wrappers for Microsoft Intune Remediations and Microsoft Configuration Manager (ConfigMgr) Configuration Items.
- Sample DSC v3 configuration documents in YAML and JSON.
- Validation tools (prereq checks, schema lint, PSScriptAnalyzer wrapper, packaging script, secret helper).
- A normalized JSON evidence schema and a bundle manifest schema.
- Documentation that mirrors the talk's operating model.

### Operating model the kit teaches

The kit separates two concerns:

- **Execution plane** — Intune, ConfigMgr, Azure Arc, Jamf, Scheduled Tasks, CI runners, SSH, etc. Owns delivery, scheduling, identity/run context, retries, reporting, and reboot orchestration.
- **Configuration runtime / payload** — DSC v3. Owns desired state, idempotent test/set convergence, and structured result output.

The Runner standardizes the contract between them so that detection, remediation, exit-code translation, evidence capture, and reboot signaling behave consistently across planes.

### Core rules the kit must enforce everywhere

1. **No secrets** in configuration documents, examples, logs, transcripts, stdout, normalized evidence, or raw evidence committed to the repository.
2. **No live downloads** in runtime paths. The DSC binary, PowerShell, resource modules, and any other runtime must be pinned and bundled.
3. **Fail closed** when proof is missing. Unknown DSC result shape, JSON parse failure, missing evidence, partial convergence, or any per-resource failure must not produce a green status.
4. **Preserve raw DSC output before normalization.** The wrapper writes `dsc.raw.json` first, then derives a stable `wrapper.result.json` from it.
5. **Detect maps to `dsc config test`. Remediate maps to `dsc config set`, then verifies with `dsc config test`.** Verification-after-set is mandatory.
6. **Reboots are durable and re-entrant**, owned by the execution plane.
7. **Strict PowerShell defaults:** `$ErrorActionPreference = 'Stop'` and `Set-StrictMode -Version Latest`.
8. **Stage-safe wording:** the repository is a starter kit teams fork and standardize, not a finished product. Do not claim production readiness anywhere.

### Repository visibility and identity

- Repository: `franklesniak/ProStateKit`.
- Visibility during your work: **Private**. The repository will be flipped to Public later. Items that depend on the public flip must go into `_TODO.md` (see Step 1) and not be done now.
- Authors and copyright holders: **Frank Lesniak** and **Blake Cherry**.
- License: **MIT**, year **2026**.
- Co-maintainer GitHub handles for CODEOWNERS: `@franklesniak` and `@blakelishly`.
- VS Code window title: `ProStateKit`.
- Initial `package.json` version: `0.1.0` (do not retain the template default of `1.0.0`; the kit is preview-state alongside a possibly-preview DSC v3.x version).
- Pinned DSC version: not yet selected. Use the literal token `TBD` wherever a version is required. Do not invent a version.

### Release posture (decided)

The kit ships **source plus a release bundle plus `bundle.manifest.json` plus a SHA-256 checksum file**. The bundle ZIP is built by `Tools/New-Package.ps1`. A tag-triggered GitHub Actions release workflow is **not** added until `New-Package.ps1` produces real artifacts; until then, document the intended release flow and keep packaging paths fail-closed.

### Things you should NOT do

- Do not enable Private Vulnerability Reporting (the repository is private; PVR requires public).
- Do not configure branch protection (workflow names and required-check identities should stabilize first).
- Do not flip the repository to public.
- Do not invent a pinned DSC version, real-looking hashes, real source commit IDs, or real build timestamps for the sample manifest.
- Do not create a release, a draft release, or any release artifacts.
- Do not paste, generate, or commit any secrets — even fake-looking ones.
- Do not claim production readiness in any document.
- Do not generate the `franklesniak/copilot-repo-template` repository or claim ProStateKit is itself a template.

---

## Conventions for this document

- **File paths** use forward slashes throughout. On disk on Windows they may render with backslashes; do not change the path format in the repository.
- **Code blocks** are illustrative content. When fields like `dscVersion` say `"TBD"`, that literal string should appear in the file you create.
- Where this document says "outline" it refers to the talk's bolstered outline; the relevant content is summarized inline so you do not need access to that file.
- Where this document says "GETTING_STARTED" or "OPTIONAL_CONFIGURATIONS," it refers to template-distributed setup docs (`GETTING_STARTED_NEW_REPO.md` and `OPTIONAL_CONFIGURATIONS.md`) that you will delete during cleanup. Their guidance has already been incorporated below.

---

## Step 1 — Create `_TODO.md` at the repository root

Create a top-level file named `_TODO.md` with the following content. This file enumerates every action that must wait until the repository is flipped from Private to Public; do **not** perform any of those actions yourself.

```markdown
# Post-Public-Flip TODO

This file tracks work that cannot be completed while the repository is private.
Delete this file as the final step after every item is complete.

- [ ] Change repository visibility from Private to Public.
- [ ] Enable Private Vulnerability Reporting (Settings → Security → Private vulnerability reporting).
- [ ] Replace private-staging security reporting text in `SECURITY.md` with PVR instructions and the advisory submission URL.
- [ ] Update `.github/ISSUE_TEMPLATE/config.yml` security URL to `https://github.com/franklesniak/ProStateKit/security/advisories/new`.
- [ ] Replace private-staging Code of Conduct reporting text in `CODE_OF_CONDUCT.md` with the final public contact method.
- [ ] Confirm the Discussions link in `.github/ISSUE_TEMPLATE/config.yml` resolves.
- [ ] Configure branch protection on `main` once workflow names and required checks have stabilized:
  - Require pull requests before merging.
  - Require status checks to pass: placeholder check, markdown lint, PowerShell CI, data/schema validation, pre-commit.
  - Require branches to be up to date before merging (optional, recommended).
  - Require CODEOWNERS review.
- [ ] Pin the DSC version in `README.md`, `docs/contract.md`, sample manifests, and any deck references.
- [ ] Run a dry release through `Tools/New-Package.ps1` after packaging is implemented and confirm `bundle.manifest.json` and SHA-256 checksum file are produced.
- [ ] Add or enable the tag-triggered release workflow once `Tools/New-Package.ps1` produces real artifacts.
- [ ] Remove this `_TODO.md` file.
```

The file name intentionally begins with an underscore so it sorts above other top-level files. Do not include any literal template placeholder strings (such as `OWNER/REPO`, `[INSERT CONTACT METHOD]`, or `[security contact email]`) anywhere in this file or anywhere else you create — the repository's `check-placeholders` workflow scans for them.

---

## Step 2 — Replace template placeholders

The template ships with intentional placeholder strings that must be replaced. Search the entire repository for each placeholder and replace as specified.

### 2.1 — `.github/ISSUE_TEMPLATE/config.yml`

Replace every occurrence of `OWNER/REPO` with `franklesniak/ProStateKit`.

Set the security contact link to the **general** Security tab during private staging:

```text
https://github.com/franklesniak/ProStateKit/security
```

The PVR-specific URL is tracked in `_TODO.md` for the public flip; do not use it now.

Uncomment and configure a Discussions link:

```yaml
- name: 💬 Questions & Discussions
  url: https://github.com/franklesniak/ProStateKit/discussions
  about: Ask questions and discuss ideas; not for bug reports.
```

Add a Support link only if the README ends up with a `## Support` section (Step 8 sets this up):

```yaml
- name: ❓ Support / FAQ
  url: https://github.com/franklesniak/ProStateKit#support
  about: Common questions, FAQs, and usage guidance.
```

### 2.2 — `.github/CODEOWNERS`

Replace every `@OWNER` with:

```text
@franklesniak @blakelishly
```

Both handles must be present on every owned path. Do not invent additional owners.

### 2.3 — `CODE_OF_CONDUCT.md`

Replace the template `[INSERT CONTACT METHOD]` placeholder with private-staging text similar to:

```markdown
To report a possible violation before public release, contact the maintainers through private repository channels. A public reporting contact will be configured before this repository is made public.
```

The final public contact replacement is tracked in `_TODO.md`. Do not leave the literal `[INSERT CONTACT METHOD]` token in the file.

### 2.4 — `CONTRIBUTING.md`

Replace every `OWNER/REPO` with `franklesniak/ProStateKit`.

### 2.5 — `LICENSE`

Confirm the license body is the standard MIT License. Set the copyright line to:

```text
Copyright (c) 2026 Frank Lesniak and Blake Cherry
```

Replace any template author string with that exact text.

### 2.6 — `SECURITY.md`

Replace the template `[security contact email]` placeholder with private-staging text similar to:

```markdown
During private staging, security reports are handled through maintainer-only repository access. Before public release, this repository will enable GitHub Private Vulnerability Reporting and update this document with the advisory submission link.
```

The final PVR wording is tracked in `_TODO.md`. Do not leave the literal `[security contact email]` token in the file.

### 2.7 — `.vscode/settings.json`

Set `window.title` to:

```text
ProStateKit
```

### 2.8 — Search-and-rewrite sweep

Sweep the entire repository for any remaining template-specific terms and remove or rewrite them so they do not appear in shipped content. The non-exhaustive list of strings to look for:

- `copilot-repo-template`
- `copilot_repo_template`
- `my-new-project`
- `your-repo-name`
- `template users`
- `OWNER/REPO`
- `@OWNER`
- `[INSERT CONTACT METHOD]`
- `[security contact email]`
- generic Python package examples
- generic Terraform examples
- "downstream template," "for template users," and similar meta-instructions

When in doubt, prefer fewer mentions of the source template; a single attribution sentence in the README (Step 8) is enough.

---

## Step 3 — Enable the `triage` label in issue templates

The repository owner is creating a `triage` label out-of-band. In each of the following files, uncomment or add the line that applies the `triage` label to new issues opened from the template:

- `.github/ISSUE_TEMPLATE/bug_report.yml`
- `.github/ISSUE_TEMPLATE/feature_request.yml`
- `.github/ISSUE_TEMPLATE/documentation_issue.yml`

If the label assignment is delivered via a top-level `labels:` list in the form, the line will look similar to `- triage`. Do not invent additional labels.

---

## Step 4 — Update `package.json` metadata

Update `package.json` so the metadata reflects ProStateKit. Set:

```json
{
  "name": "prostatekit",
  "version": "0.1.0",
  "description": "Starter kit for reliable endpoint state with DSC v3 execution templates, evidence, validation, and management-plane wrappers.",
  "private": true,
  "keywords": [
    "dsc",
    "dsc-v3",
    "powershell",
    "intune",
    "configmgr",
    "endpoint-state",
    "endpoint-management",
    "desired-state-configuration",
    "automation",
    "remediation",
    "compliance",
    "evidence"
  ],
  "author": "Frank Lesniak and Blake Cherry"
}
```

Set `version` to `0.1.0` explicitly; do not retain the template's default `1.0.0`. Leave `scripts`, `engines`, and `devDependencies` unchanged. Do not delete `package.json`; it is required because the repository keeps Node-based markdown tooling.

---

## Step 5 — Remove unused language support

The kit is PowerShell-dominant with Markdown documentation, JSON, and YAML. It does **not** ship Python or Terraform application code.

### 5.1 — Remove Python application/example support

Delete the following if present:

- The Python example package directory under `src/` (often `src/copilot_repo_template/` or similar).
- The Python example tests directory.
- `pyproject.toml`, but only if it exists solely to support the template's example application. If you are unsure, inspect the file: if it defines the example package and example test extras and nothing else, delete it; if it also configures pre-commit-relevant tooling that the kit still uses, retain only those parts.
- `.github/workflows/python-ci.yml`.
- `.github/instructions/python.instructions.md`.
- Any Python-specific files under `templates/` if present.

### 5.2 — Important: pre-commit hooks vs. application code

Some pre-commit hooks (for example `check-jsonschema`, `yamllint`, or other linters) are implemented in Python and pulled in by `.pre-commit-config.yaml`. **Those are not Python application code.** Keep any pre-commit hook the kit relies on for JSON, YAML, or Markdown validation, even though it happens to be implemented in Python. Removing them would break validation that the kit depends on.

### 5.3 — Remove Terraform/HCL support

Delete the following if present:

- Terraform example files (`*.tf`, `*.tfvars`, terraform module folders).
- Terraform-specific files under `templates/`.
- `.github/instructions/terraform.instructions.md`.
- Terraform/HCL workflow jobs and Terraform-specific pre-commit hooks.

### 5.4 — Keep

Keep all of the following:

- PowerShell support, PowerShell CI, PSScriptAnalyzer settings, Pester test structure.
- Markdown support and `markdownlint` configuration.
- JSON instruction file (`.github/instructions/json.instructions.md`).
- YAML instruction file (`.github/instructions/yaml.instructions.md`) and `yamllint` configuration.
- GitHub Actions workflow validation (`actionlint` if present).
- Whitespace, end-of-file, and general pre-commit hygiene hooks.
- The auto-fix pre-commit workflow.
- The placeholder check workflow.

---

## Step 6 — Customize the pull request template

Edit `.github/pull_request_template.md`:

1. Delete the leading HTML comment intended for template users.
2. Delete the entire Python-specific section.
3. Delete any Terraform-specific content.
4. Keep and tailor the PowerShell-specific section.
5. Strengthen the pre-commit verification section so it is unconditional:

   ```markdown
   ### Pre-commit Verification

   - [ ] I have run `pre-commit run --all-files` locally or verified equivalent CI/pre-commit checks passed
   - [ ] I have reviewed and committed all auto-fixes made by pre-commit hooks
   ```

6. Keep the **relative** contributing guidelines link (do not switch to an absolute URL):

   ```markdown
   [contributing guidelines](../blob/HEAD/CONTRIBUTING.md)
   ```

   Rationale: the kit is explicitly designed to be forked, and the relative form survives forks.

7. Add a ProStateKit-specific contract checklist:

   ```markdown
   ### ProStateKit Contract Checks

   - [ ] Detect behavior still maps to `dsc config test`
   - [ ] Remediate behavior still verifies state after set
   - [ ] Raw DSC output is preserved before normalization
   - [ ] Normalized evidence schema is updated if result shape changed
   - [ ] Partial convergence fails closed
   - [ ] Missing or unparseable proof fails closed
   - [ ] No secrets are written to configs, logs, transcripts, stdout, or evidence
   - [ ] Reboot behavior remains durable and re-entrant where applicable
   ```

8. Add a documentation checklist:

   ```markdown
   ### Documentation

   - [ ] README/docs updated for user-facing behavior changes
   - [ ] Exit-code docs updated if exit semantics changed
   - [ ] Evidence schema docs updated if evidence changed
   - [ ] Reboot/secrets docs updated if relevant
   ```

---

## Step 7 — Customize Copilot and agent instruction files

Update `.github/copilot-instructions.md` to lead with ProStateKit-specific rules. Include all of the following as repository-wide rules (rephrase as needed for the file's existing tone, but preserve every rule):

- No secrets in configuration documents, examples, logs, transcripts, stdout, normalized evidence, or raw evidence committed to the repo.
- No live downloads in runtime paths.
- Runtime, DSC binary, PowerShell, resources, and modules must be pinned and bundled when packaging.
- Fail closed when proof is missing.
- Unknown DSC result shape, parse failure, missing evidence, partial convergence, or resource failure must not produce green status.
- Preserve raw DSC output before normalization.
- Normalize evidence into a stable schema.
- Consumers should read wrapper-owned normalized fields, not raw DSC fields directly.
- Execution plane owns targeting, scheduling, identity, delivery, retries, reporting, and reboots.
- DSC v3 payload owns desired state, test, set, and structured result output.
- Detect maps to `dsc config test`.
- Remediate maps to `dsc config set`, then verifies with `dsc config test`.
- Reboots must be re-entrant and durable.
- PowerShell code must use strict error handling and be covered by tests where behavior changes.
- Markdown docs must stay practitioner-first, concrete, and stage-safe.

Update `.github/instructions/powershell.instructions.md` to require:

- `$ErrorActionPreference = 'Stop'`
- `Set-StrictMode -Version Latest`
- safe path handling
- fail-closed parsing
- no secret leakage
- Pester tests for behavior changes
- explicit exit-code contract
- evidence writing rules

Keep `.github/instructions/json.instructions.md` and `.github/instructions/yaml.instructions.md` as-is unless they contain template-specific examples that should be removed.

Update Markdown/documentation instructions (wherever they live in the template) so they require: practitioner-first, direct, concrete, sponsor-safe, no overclaiming, and no "finished product" claims.

Mirror the relevant rules across:

- `CLAUDE.md` (Anthropic Claude Code agent instructions)
- `AGENTS.md` (Codex / generic agent instructions)
- `.gemini/` directory contents (Gemini agent instructions)
- Any other top-level agent instruction file the template ships

If any of those files do not exist in the template you adopted, do not create them.

---

## Step 8 — Replace `README.md`

Replace the template README with a project-specific one. Keep one short attribution sentence noting that the repository was created from `franklesniak/copilot-repo-template`.

The opening paragraph should read substantively like:

```markdown
ProStateKit is a starter kit for reliable endpoint state with DSC v3. It provides reusable runner templates, evidence schemas, sample DSC configuration documents, validation tooling, and management-plane wrappers for Intune and ConfigMgr. It is a starter kit teams can fork and standardize, not a finished product.
```

Include these sections, in this order:

- What ProStateKit is
- What ProStateKit is not
- Native-first decision rule (use native CSPs, Settings Catalog, ConfigMgr Compliance Baselines when they fully meet the requirement; reach for ProStateKit when you need exact drift control, ordering, portability, code review, or durable evidence)
- Execution plane vs. DSC v3 payload
- Execution Template overview
- Supported management planes (Intune, ConfigMgr, Scheduled Task / local runner, CI/lab runner)
- Bundle layout
- Evidence model
- Exit-code model
- Reboot model
- Secrets rule
- Validation and CI
- Releases (state the chosen posture: source plus bundle plus `bundle.manifest.json` plus SHA-256 checksum file)
- Getting started
- Support
- Security
- Contributing
- License (MIT — Frank Lesniak and Blake Cherry)

Add a pinned DSC version callout near the top of the README:

```markdown
> Built and validated against `dsc.exe` version: TBD (to be pinned before MMSMOA 2026).
```

Do not claim production readiness anywhere. Do not delete the existing top-of-file project section if it can be tailored; do delete the template's "Readme for the Copilot Repository Template" section and everything following it.

---

## Step 9 — Customize `CONTRIBUTING.md`

1. Delete the `## For Template Users` section and any preceding HTML comment that exists only for downstream template adopters.
2. Remove Python-specific subsections.
3. Remove Terraform-specific subsections.
4. Keep PowerShell guidance.
5. Add ProStateKit contribution expectations:

   - Keep PRs small and reviewable.
   - Do not include secrets in examples, tests, configs, logs, transcripts, or evidence.
   - Keep sample configs safe for lab use.
   - Runner behavior changes require tests.
   - Schema changes must update schema files, examples, tests, and docs together.
   - Exit-code changes must update `docs/exit-codes.md`.
   - Evidence changes must update `docs/evidence-schema.md`.
   - Reboot behavior changes must update `docs/reboots.md`.
   - Secrets behavior changes must update `docs/secrets.md`.

---

## Step 10 — Customize `CODE_OF_CONDUCT.md`

Keep the Contributor Covenant default. Use the private-staging contact wording from Step 2.3. Optionally add a brief response-timeline paragraph. Do not introduce a public contact email — that is tracked in `_TODO.md`.

---

## Step 11 — Customize `SECURITY.md`

Rewrite for ProStateKit using the private-staging security-reporting wording from Step 2.6. Include all of:

- A supported versions table (with `0.1.0` listed and a "preview" note).
- A "private reporting will be available after public release" note.
- "No public issues for vulnerabilities" guidance.
- "No secrets in examples or reports" guidance.
- Guidance to redact evidence before sharing.

Call out the security-sensitive areas of the kit:

- Runner execution context (especially when invoked under SYSTEM by the Intune Management Extension).
- SYSTEM context behavior.
- Scheduled-task fallback used as a reboot continuation strategy.
- Secrets handling.
- Evidence redaction.
- Bundle integrity.
- Supply-chain pinning.

---

## Step 12 — Customize issue templates

Update the area dropdown in `.github/ISSUE_TEMPLATE/bug_report.yml` (and any equivalent dropdown in feature/documentation forms) to use ProStateKit components:

```yaml
options:
  - Runner
  - Intune wrapper
  - ConfigMgr wrapper
  - DSC configuration
  - Evidence schema
  - Exit codes
  - Reboots
  - Secrets
  - Packaging
  - Validation / CI
  - Documentation
  - Other
```

In `bug_report.yml`, replace generic runtime placeholders with these ProStateKit-specific ones (in the appropriate "Runtime / Environment" textarea or input fields):

```text
ProStateKit version:
DSC version:
PowerShell version:
Windows version:
Execution plane: Intune / ConfigMgr / Scheduled Task / local / CI / other
Run mode: Detect / Remediate
```

Add evidence-prompt fields asking the reporter to include redacted excerpts of:

- `summary.txt`
- `wrapper.result.json`
- A relevant redacted excerpt from `dsc.raw.json`
- The exit code returned
- The execution plane
- Whether a `reboot.marker` file existed

Add a clearly visible warning **not** to paste:

- secrets,
- tenant identifiers,
- customer data,
- private logs,
- unredacted transcripts,
- full evidence bundles.

Update `feature_request.yml` so its categories match the same component list. Update `documentation_issue.yml` so its examples point to `docs/` and `README.md` paths rather than template paths.

---

## Step 13 — Configure pre-commit, workflows, and Dependabot

### 13.1 — Pre-commit

In `.pre-commit-config.yaml`:

- Remove Python-application-only hooks (e.g., `black`, `ruff`) **only if** they exist solely to lint the deleted Python example. If they are configured to run against any retained code, retain them.
- Remove Terraform/HCL hooks (`terraform_fmt`, `tflint`, etc.).
- Keep whitespace and end-of-file hooks.
- Keep JSON checks.
- Keep YAML checks (including `yamllint`).
- Keep `markdownlint` (or `markdownlint-cli2`).
- Keep `actionlint` if present.
- Keep `check-jsonschema` and any other Python-implemented JSON/YAML validators.

### 13.2 — Workflows

Confirm or update `.github/workflows/powershell-ci.yml` so it targets:

- `src/runner/**`
- `src/tools/**`
- `tests/**`

Remove or no-op any Python-application-specific CI jobs. Keep the auto-fix pre-commit workflow. Keep the placeholder check workflow.

### 13.3 — Dependabot

In `.github/dependabot.yml`:

- Keep the `npm` ecosystem block (used by markdown tooling via `package.json`).
- Keep the `github-actions` ecosystem block.
- **Remove the `pip` ecosystem block** if and only if the repository no longer contains any Python dependency manifest (`pyproject.toml`, `requirements.txt`, `requirements-dev.txt`, `setup.cfg`, etc.). Pre-commit-managed Python tools do **not** require a `pip` Dependabot block — pre-commit hook revisions should be managed through `.pre-commit-config.yaml` updates or a dedicated pre-commit autoupdate workflow, not through Dependabot.
- Remove any Terraform ecosystem block.

### 13.4 — `.gitignore`

Add patterns for ProStateKit runtime and build artifacts:

```text
# ProStateKit runtime artifacts
*.zip
BaselineBundle/Runtime/
ProStateKitBundle/
evidence/runtime/
**/Runs/
*.transcript.log
build/
dist/
out/
```

Tune the patterns so they do not accidentally ignore committed sample artifacts under `evidence/sample/` or `schemas/examples/` (Step 18 and Step 22).

---

## Step 14 — Funding file

Do **not** add `.github/FUNDING.yml`. If the template includes one, delete it.

---

## Step 15 — Clean up template-specific files

Delete the following files from the repository root (they are template-distribution artifacts and do not belong in a downstream project):

- `GETTING_STARTED_NEW_REPO.md`
- `GETTING_STARTED_EXISTING_REPO.md`
- `OPTIONAL_CONFIGURATIONS.md`
- `.github/TEMPLATE_DESIGN_DECISIONS.md`

If the template includes any other files whose names or front-matter clearly mark them as template-internal documentation, delete those too. If any setup guidance is genuinely needed for ProStateKit, write project-specific docs under `docs/` (Step 23) instead of preserving template docs.

---

## Step 16 — Schema example placeholder during cleanup

The template ships a "worked example" schema to demonstrate JSON-schema validation in pre-commit. Strategy:

- If removing it immediately would break the repository's CI, retain it temporarily.
- If retained, add a clear in-file `TODO` comment stating it will be replaced by ProStateKit's real schemas (`wrapper-result.schema.json` and `bundle-manifest.schema.json`) defined later in this document.
- Do not leave the generic worked example in long-term project content; replace it as part of Step 19.

---

## Step 17 — Create the project tree

Create the following directory structure (use empty `.gitkeep` files where a directory would otherwise be empty and is not yet populated by later steps):

```text
src/
  runner/
    Runner.ps1
    Intune/
      Detect.ps1
      Remediate.ps1
    ConfigMgr/
      Runner.ps1
  configs/
    baseline.windows.yaml
    baseline.windows.json
  tools/
    Invoke-PreReqChecks.ps1
    Invoke-SchemaLint.ps1
    Invoke-PSScriptAnalyzer.ps1
    New-Package.ps1
    SecretHelper.ps1
schemas/
  wrapper-result.schema.json
  bundle-manifest.schema.json
  examples/
tests/
  PowerShell/
docs/
evidence/
  sample/
prompts/
assets/
  bailout/
    .gitkeep
```

Ensure the structure is reflected anywhere paths are referenced (README, workflows, agent instruction files, pre-commit configuration).

---

## Step 18 — PowerShell skeletons (fail-closed)

### 18.1 — `src/runner/Runner.ps1`

Create the Runner with this parameter signature exactly:

```powershell
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('Detect', 'Remediate')]
    [string] $Mode,

    [Parameter(Mandatory)]
    [string] $ConfigPath,

    [Parameter(Mandatory)]
    [string] $BundleRoot,

    [string] $LogRoot = 'C:\ProgramData\ProStateKit\Baseline',

    [string] $RunId,

    [bool] $Strict = $true
)
```

At the top of the body, set:

- `$ErrorActionPreference = 'Stop'`
- `Set-StrictMode -Version Latest` when `-Strict:$true`

Add commented-out `TODO` sections (do not implement the bodies) for:

- RunId creation (default to `yyyyMMdd-HHmmss-<guid>` when `-RunId` is empty).
- Evidence directory creation under `<LogRoot>\Runs\<RunId>\` (use `New-Item -ItemType Directory -Force` so it never assumes the folder exists).
- Transcript start and stop (`transcript.log`).
- Locating pinned `dsc.exe` under `<BundleRoot>\Runtime\dsc\`.
- Invoking `dsc config test` for Detect mode.
- Invoking `dsc config set` for Remediate mode, then re-invoking `dsc config test` for verification.
- Capturing raw stdout to `dsc.raw.json` before any interpretation.
- Normalizing into `wrapper.result.json` (schema in Step 19).
- Writing a one-page `summary.txt`.
- Calculating the exit code per the contract below.
- Writing `reboot.marker` only when reboot is required.

Document the intended exit-code contract in a comment block:

```text
Detect:
  0 = compliant
  1 = non-compliant
  2 = runtime failure
  3 = parse failure / proof missing

Remediate:
  0 = success after verification
  1 = partial or failed convergence
  2 = runtime failure
  3 = parse failure / proof missing
```

The skeleton **must fail closed**. Until implemented, the body must end with either `throw "Runner.ps1 is not yet implemented; see docs/contract.md."` or a deliberate non-zero exit. A stub must not return success or exit `0`.

### 18.2 — `src/runner/Intune/Detect.ps1`

Stub script for the Intune Remediations detection slot. It should call `Runner.ps1` in `Detect` mode using `$PSScriptRoot`-relative paths to the Runner and the baseline config; fail closed until implemented.

### 18.3 — `src/runner/Intune/Remediate.ps1`

Stub script for the Intune Remediations remediation slot. It should call `Runner.ps1` in `Remediate` mode; fail closed until implemented.

### 18.4 — `src/runner/ConfigMgr/Runner.ps1`

Thin ConfigMgr-side runner front-end matching Configuration Item compliance evaluation semantics. Fail closed until implemented.

All four wrapper stubs must include a leading comment block stating they are preview scaffolds and that production behavior is not yet implemented.

---

## Step 19 — Tool skeletons

In `src/tools/`, create fail-closed or safe placeholder scripts:

### 19.1 — `Invoke-PreReqChecks.ps1`

Will check PowerShell version, presence of `dsc.exe` under `<BundleRoot>\Runtime\dsc\`, presence of pinned resource modules under `<BundleRoot>\Resources\`, and writability of `<LogRoot>`. Stub: fail with TODO.

### 19.2 — `Invoke-SchemaLint.ps1`

Will validate that DSC config documents under `src/configs/` parse and that `wrapper.result.json` examples conform to `schemas/wrapper-result.schema.json`. Stub: fail with TODO.

### 19.3 — `Invoke-PSScriptAnalyzer.ps1`

Wraps a project-wide PSScriptAnalyzer invocation. Stub may either dispatch to `Invoke-ScriptAnalyzer` if available or fail with TODO.

### 19.4 — `New-Package.ps1`

Will, when implemented, build the bundle ZIP, generate `bundle.manifest.json`, and generate a SHA-256 checksum file. Until implemented:

- Must **not** perform any live downloads.
- Must fail safely with a TODO message.
- Must not produce empty, fake, or partial artifacts.

### 19.5 — `SecretHelper.ps1`

Helper for retrieving secrets from `Microsoft.PowerShell.SecretManagement` at execution time. Stub must include leading comments stating, prominently:

- Secrets must never be written to transcripts, stdout, logs, evidence files (`dsc.raw.json`, `wrapper.result.json`, `summary.txt`), or any other captured artifact.
- The helper must redact secret values from any error messages it surfaces.
- The helper records only the fact that a secret was retrieved, the vault name, and the item name — never the value.

Fail safely with a TODO until implemented.

---

## Step 20 — Sample baseline DSC configurations

Create `src/configs/baseline.windows.yaml` and `src/configs/baseline.windows.json` that model the same three demo controls. Both files must express equivalent state.

The three controls, exactly as the talk presents them, are:

1. **Controlled local group membership.** Manage membership of a controlled local group named exactly `Baseline-ControlledLocal`. Do **not** substitute another name; the talk uses this exact string to keep talk content and repo content aligned. Do **not** use the local Administrators group.
2. **Deterministic registry hardening (LLMNR demo state).** Set `EnableMulticast` to a `REG_DWORD` value of `0` at `HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient`. Frame this in comments as demo-visible state, not universal policy advice.
3. **ProgramData "truth marker" file.** Ensure the file `C:\ProgramData\ProStateKit\Baseline\baseline-applied.txt` exists.

Each resource entry should specify a clear `name`, the appropriate DSC v3 resource `type`, and the desired properties for the demo state. Use the YAML form below as the structural template (resource type names and exact property keys may need adjustment for the chosen DSC v3 resource versions; mark uncertain values with TODO comments rather than inventing them):

```yaml
directives:
  description: ProStateKit Windows endpoint baseline (sample)
  version: 0.1.0
  requireVersion: TBD
resources:
  - name: Controlled local group exists
    type: Microsoft.Windows/Group # TODO: confirm exact type with pinned DSC resource version
    properties:
      groupName: Baseline-ControlledLocal
      members: []
  - name: LLMNR disabled
    type: Microsoft.Windows/Registry # TODO: confirm exact type with pinned DSC resource version
    properties:
      keyPath: HKLM\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient
      valueName: EnableMulticast
      valueData: 0
      valueType: REG_DWORD
  - name: Baseline-applied marker file
    type: Microsoft.Windows/File # TODO: confirm exact type with pinned DSC resource version
    properties:
      path: C:\ProgramData\ProStateKit\Baseline\baseline-applied.txt
      ensure: Present
```

Add comments at the top of each file stating that the configurations are **examples for lab use only** and must be reviewed before any production use. Do not include secrets, placeholder-looking secrets, real machine names, real account names, or tenant data.

---

## Step 21 — Schemas and example fixtures

### 21.1 — `schemas/wrapper-result.schema.json`

JSON Schema (Draft 2020-12 or whichever the rest of the kit uses) describing the normalized internal evidence object. Required top-level fields:

- `schemaVersion` (string, e.g., `"1.0"`)
- `runId` (string)
- `mode` (enum: `"Detect"`, `"Remediate"`)
- `startedUtc`, `endedUtc` (RFC 3339 date-time)
- `dscVersion` (string)
- `overall` (object with `succeeded` (bool), `compliant` (bool), `rebootRequired` (bool))
- `resources` (array of objects with `name`, `type`, `succeeded`, `changed`, `error` (string or null), `rebootRequired`)

Mark the schema as additive: extra properties allowed but documented.

### 21.2 — `schemas/bundle-manifest.schema.json`

JSON Schema for the bundle manifest. Required fields: `name`, `version`, `schemaVersion`, `dscVersion`, `builtAt`, `sourceCommit`, `wrapperHash`, `configHash`, `validationStatus`, `supportedPlanes` (array of strings).

### 21.3 — `schemas/examples/`

Provide one valid and one invalid fixture for each schema:

- `examples/wrapper-result.valid.json`
- `examples/wrapper-result.invalid.json` (missing required field, with a comment in a sibling `.md` describing why it should fail)
- `examples/bundle-manifest.valid.json`
- `examples/bundle-manifest.invalid.json`

The valid `wrapper-result` example must be:

```json
{
  "schemaVersion": "1.0",
  "runId": "20260512-093501-0a1b",
  "mode": "Remediate",
  "startedUtc": "2026-05-12T14:35:01Z",
  "endedUtc": "2026-05-12T14:35:09Z",
  "dscVersion": "TBD",
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
  ]
}
```

The valid `bundle-manifest` example must be:

```json
{
  "name": "ProStateKit",
  "version": "0.1.0",
  "schemaVersion": "1.0",
  "dscVersion": "TBD",
  "builtAt": "TBD",
  "sourceCommit": "TBD",
  "wrapperHash": "TBD",
  "configHash": "TBD",
  "validationStatus": "TBD",
  "supportedPlanes": [
    "Intune",
    "ConfigMgr",
    "ScheduledTask",
    "Local"
  ]
}
```

Do **not** invent real-looking SHA hashes, real commit IDs, or real ISO timestamps for the bundle manifest example. Keep the literal `"TBD"` tokens.

---

## Step 22 — Sanitized evidence examples

Create example evidence directories under `evidence/sample/` that show what a real run's evidence folder looks like in each notable state. Use synthetic, clearly sanitized content:

```text
evidence/
  sample/
    compliant-detect/
      dsc.raw.json
      wrapper.result.json
      summary.txt
    noncompliant-detect/
      dsc.raw.json
      wrapper.result.json
      summary.txt
    successful-remediate/
      dsc.raw.json
      wrapper.result.json
      summary.txt
    partial-failure/
      dsc.raw.json
      wrapper.result.json
      summary.txt
    parse-failure/
      dsc.raw.txt
      wrapper.result.json
      summary.txt
```

Notes:

- `parse-failure/` deliberately uses `dsc.raw.txt` (not `.json`) to depict the captured output that failed JSON parsing; the corresponding `wrapper.result.json` should reflect the fail-closed parse-failure state with `mode: "Detect"` (or `"Remediate"`), `overall.succeeded: false`, and a clear `error` description on a synthetic resource entry, with parse-failure exit semantics described in `summary.txt`.
- Do **not** include real machine names, real tenant IDs, real usernames, secrets, customer data, or private logs. All values must be obviously synthetic.
- Each `summary.txt` should be a one-page human-readable digest matching the state.

---

## Step 23 — Documentation under `docs/`

Create the following files. If full prose is not yet ready for a section, write accurate headings and a `TODO:` placeholder line under each — but do **not** describe unimplemented features as complete.

### 23.1 — `docs/contract.md`

The Execution Template specification. Cover:

- Definition (the Runner is a reusable wrapper template, not a Microsoft product).
- Inputs (mirror the Runner parameter signature from Step 18.1).
- Execution semantics (Detect → `dsc config test`; Remediate → `dsc config set` then verify with `dsc config test`).
- Evidence outputs written every run under `<LogRoot>\Runs\<RunId>\`: `transcript.log`, `dsc.raw.json`, `wrapper.result.json`, `summary.txt`, optional `reboot.marker`.
- Exit-code contract (Detect: 0/1/2/3; Remediate: 0/1/2/3 with the meanings from Step 18.1).
- False-green prevention rule (success requires parsing the result payload and confirming every resource succeeded; partial convergence is failure).
- Strictness switch (`-Strict:$true` default).
- Secrets rule (no secrets in configuration documents; runtime retrieval via `SecretManagement`).

### 23.2 — `docs/evidence-schema.md`

- Why raw DSC output is preserved before normalization.
- The normalized schema (`wrapper.result.json`) field by field, matching `schemas/wrapper-result.schema.json`.
- Schema versioning rules.
- Resource result normalization (success requires per-resource success; document the field-resolution chain across DSC versions).
- Fail-closed parsing strategy.
- A sample `wrapper.result.json` block (reuse the example from Step 21.3).

### 23.3 — `docs/exit-codes.md`

- Detect exit codes table.
- Remediate exit codes table.
- Intune Remediations semantics (detection exit `1` triggers remediation; output limited to ~2,048 characters; the wrapper must keep the full evidence behind a single status bit).
- ConfigMgr Configuration Item compliance semantics.
- Parse-failure / proof-missing handling (exit `3`, fail closed).

### 23.4 — `docs/reboots.md`

- The execution plane owns reboot orchestration; the configuration runtime owns idempotent convergence.
- Re-entrant pattern: plane runs Runner → Runner applies what it can and signals "reboot required" → plane reboots → plane re-runs Runner → Runner skips already-correct steps.
- Two signaling-contract options (dedicated exit code plus `reboot.marker`; or always-success plus marker file). State that the kit picks one as default and documents the other; until selected, mark as TODO.
- Scheduled-task fallback governance for planes without reboot orchestration: must be signed, must self-clean on success, must have a TTL, must be auditable under `<LogRoot>\ScheduledTaskAudit\`, must not be persistence-like.
- Note that DSC v3.2 previews removed the `_rebootRequested` schema property; the wrapper's reboot detection must not rely on it. Document the layered detection strategy: explicit resource opt-in property, post-apply probe of pending-reboot signals, and manifest declaration metadata.

### 23.5 — `docs/secrets.md`

- No secrets in configs (not plaintext, not Base64, not "encrypted-but-the-key-is-in-the-repo").
- Runtime retrieval via `Microsoft.PowerShell.SecretManagement` with an approved vault extension (Azure Key Vault is canonical).
- The Runner's secret helper rules (catch and redact values from error messages; never emit to transcript, stdout, or normalized result; record only fact-of-retrieval).
- Failure behavior: on any secret resolution failure, exit non-zero with a distinct code and do **not** apply partial configuration.
- What users must not paste into issues (mirror the issue-template warning list from Step 12).

### 23.6 — `docs/troubleshooting.md`

Triage workflow keyed off the evidence folder:

- Compliant Detect (`exit 0`).
- Non-compliant Detect (`exit 1`).
- Successful Remediate (`exit 0` after verification).
- Partial convergence (`exit 1`, named offending resources in `wrapper.result.json`).
- Runtime failure (`exit 2`).
- Parse failure (`exit 3`, raw output preserved).
- Reboot marker present.

### 23.7 — `docs/resource-gaps.md`

- Decision tree: when to use a DSC resource, when to wrap script logic deliberately, when to write a custom resource.
- How to fail closed inside a script-wrapping resource.
- Testing requirements for resource gaps.

### 23.8 — `docs/packaging.md`

- Pinned runtime principle ("pin everything"; no live downloads).
- Bundle manifest (`bundle.manifest.json`) and SHA-256 checksum file as the supply-chain artifact set.
- Bundle layout:

  ```text
  BaselineBundle/
    Runtime/dsc/          (pinned dsc.exe + shared libs)
    Runtime/PS7/          (optional pinned PowerShell 7)
    Resources/            (pinned resource modules)
    Configs/              (baseline.windows.yaml, baseline.windows.json)
    Runner/               (Runner.ps1, Intune/Detect.ps1, Intune/Remediate.ps1, ConfigMgr/Runner.ps1)
    Tools/                (prereq checks, lint, schema validation, packaging)
    bundle.manifest.json
  ```

- Delivery channels: Intune Win32 app, ConfigMgr application/package, Arc/server extension, golden image bake-in.
- Offline determinism (the Runner fails closed if it cannot find an expected binary under `BundleRoot`).
- **Release output (the chosen posture):** source plus bundle ZIP plus `bundle.manifest.json` plus SHA-256 checksum file.
- **Intended future release workflow** (do not add the workflow file yet — see Step 24): tag pattern such as `v*.*.*`; run `Tools/New-Package.ps1`; generate bundle ZIP; generate `bundle.manifest.json`; generate SHA-256 checksum file; publish a draft GitHub Release; fail closed if any expected artifact is missing.

---

## Step 24 — Release workflow posture

Do **not** add a tag-triggered release workflow yet. `Tools/New-Package.ps1` is currently a fail-closed stub (Step 19.4); a release workflow that runs against it would either fail or, worse, publish empty or fake artifacts.

If you choose to scaffold a workflow file, it must be:

- Named `.github/workflows/release.yml`.
- Triggered **only** by `workflow_dispatch` (no `push: tags:` trigger).
- Required to fail clearly before publishing anything.
- Forbidden from creating draft releases, empty artifact uploads, fake manifests, or fake checksums.

Document the intended future release workflow in `docs/packaging.md` (Step 23.8) instead.

---

## Step 25 — Tests under `tests/PowerShell/`

Add Pester tests at the difficulty level the current implementation supports:

- **Schema example tests:** load `schemas/examples/wrapper-result.valid.json` and `schemas/examples/bundle-manifest.valid.json` and validate them against their respective schemas; load the `.invalid.json` fixtures and assert validation fails.
- **Runner parameter validation:** import `src/runner/Runner.ps1` (or run `Get-Command -Syntax` against it) and assert that `-Mode` accepts only `Detect` and `Remediate`, and that `-ConfigPath` and `-BundleRoot` are mandatory.
- **Fail-closed behavior:** invoking `Runner.ps1` with valid parameters must not return success while implementation is incomplete (assert non-zero exit or thrown exception).
- **No-secret-placeholder check:** scan `src/configs/baseline.windows.yaml` and `src/configs/baseline.windows.json` for obvious secret-shaped tokens (case-insensitive matches for `password`, `secret`, `apikey`, `token`, `bearer`, etc.) and fail if any are found.
- **Path consistency (where practical):** assert that paths referenced in docs (`docs/contract.md`, `docs/packaging.md`) match the actual repository layout from Step 17.

Do not add tests that require host setup (a real DSC v3 runtime, a Windows endpoint, or admin privileges) until the implementation lands and CI supports them.

---

## Step 26 — Prompt guidance under `prompts/`

Create `prompts/README.md`. The first paragraph must include this disclaimer prominently (rephrasing for readability is fine but the substance must be retained):

```markdown
AI-generated output must be reviewed before use. Do not paste secrets, tenant data, customer data, private logs, unredacted transcripts, or unredacted evidence into prompts. AI is not used live in the demo.
```

Keep the directory's other contents optional and clearly separated from any runtime logic. Do not place prompts in a path that the Runner or any other shipped script imports.

---

## Step 27 — No-false-completion guardrails (apply throughout)

These rules apply across every file you touch:

1. Any unimplemented runner, tool, schema behavior, wrapper, packaging command, or validation path must be clearly marked as `TODO:` or "preview" in surrounding comments and any related documentation.
2. Unimplemented execution paths must fail closed (throw, or exit non-zero with a documented exit code).
3. Documentation must not claim production readiness until implementation and tests exist.
4. Do not write phrases like "fully supports Intune," "production-ready ConfigMgr runner," "validated against DSC version X," or similar until they are true.
5. Use "starter kit," "preview," "sample," or "planned" where appropriate.
6. Do not invent version numbers, hashes, commit IDs, or timestamps where the literal token `TBD` is used in this document — preserve the literal `TBD`.

---

## Final self-check before declaring done

Verify every item below before treating your work as complete:

- [ ] `_TODO.md` exists at the repository root with the exact set of public-flip items from Step 1; nothing in it has been performed yet.
- [ ] No file contains `OWNER/REPO`, `@OWNER`, `[INSERT CONTACT METHOD]`, `[security contact email]`, `copilot-repo-template`, `copilot_repo_template`, `my-new-project`, `your-repo-name`, or other template placeholders.
- [ ] `LICENSE` says `Copyright (c) 2026 Frank Lesniak and Blake Cherry` and is the MIT body.
- [ ] `package.json` `version` is `0.1.0`; `name` is `prostatekit`; `author` is `Frank Lesniak and Blake Cherry`.
- [ ] `.vscode/settings.json` `window.title` is `ProStateKit`.
- [ ] `.github/CODEOWNERS` lists `@franklesniak @blakelishly` for every owned path.
- [ ] No Python application code, Python example tests, Python application CI workflow, Terraform code, Terraform CI, or `FUNDING.yml` remain.
- [ ] Pre-commit Python-implemented hooks for JSON/YAML/Markdown validation are still present and configured.
- [ ] `.github/dependabot.yml`'s `pip` block is removed only if no Python dependency manifest remains.
- [ ] All four PowerShell Runner / wrapper stubs fail closed; none returns success.
- [ ] `New-Package.ps1` performs no live downloads and fails safely with a TODO.
- [ ] `SecretHelper.ps1`'s leading comments document the no-leakage rules.
- [ ] `src/configs/baseline.windows.yaml` and `.json` express the same three demo controls and use exactly the demo group name `Baseline-ControlledLocal`, the LLMNR registry path `HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient` with `EnableMulticast = REG_DWORD 0`, and the marker file `C:\ProgramData\ProStateKit\Baseline\baseline-applied.txt`.
- [ ] `schemas/wrapper-result.schema.json` and `schemas/bundle-manifest.schema.json` exist with valid and invalid example fixtures under `schemas/examples/`.
- [ ] The sample `bundle.manifest.json` retains literal `"TBD"` tokens for `dscVersion`, `builtAt`, `sourceCommit`, `wrapperHash`, `configHash`, and `validationStatus`.
- [ ] All eight `docs/*.md` files exist with accurate headings; incomplete sections are explicitly marked TODO.
- [ ] `evidence/sample/` contains the five state directories with synthetic, sanitized content; no real machine names, tenant IDs, usernames, secrets, customer data, or private logs.
- [ ] `prompts/README.md` carries the AI-review disclaimer.
- [ ] No tag-triggered release workflow has been added.
- [ ] Pester tests run and pass.
- [ ] `markdownlint`, `yamllint`, `actionlint`, and JSON-schema validation pass.
- [ ] PowerShell CI workflow targets `src/runner/**`, `src/tools/**`, and `tests/**`.
- [ ] Nothing in any document claims production readiness or fabricates a pinned DSC version.
- [ ] `GETTING_STARTED_NEW_REPO.md`, `GETTING_STARTED_EXISTING_REPO.md`, `OPTIONAL_CONFIGURATIONS.md`, and `.github/TEMPLATE_DESIGN_DECISIONS.md` are deleted.
