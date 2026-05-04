<!-- markdownlint-disable MD013 -->
# Windows 11 Quickstart

## Metadata

- **Status:** Draft
- **Owner:** Repository Maintainers
- **Last Updated:** 2026-05-04
- **Scope:** Fresh Windows 11 VM setup for validating the ProStateKit repository and reaching the expected fail-closed DSC preview checkpoint. This runbook does not replace the pinned-runtime review workflow or claim production readiness.
- **Related:** [README](../../README.md), [Demo Runbook](demo-runbook.md), [Runtime Distribution](../runtime-distribution.md), [Packaging](../packaging.md), [Troubleshooting](../troubleshooting.md)

## Goal

This runbook gets a brand new Windows 11 VM from nothing installed to a validated ProStateKit checkout.

The clean-checkout success condition is:

- Repository validation passes.
- The local DSC run fails closed because `runtime/dsc/dsc.exe` and `bundle.manifest.json` are intentionally missing.
- Evidence is written so you can see the failure was expected and controlled.

Do not treat the missing-runtime failure as a broken VM. The repository does not ship a pinned DSC runtime yet.

## Step 1 - Open PowerShell

Open **Windows Terminal** or **PowerShell** as Administrator for tool installation.

Run:

```powershell
$PSVersionTable.PSVersion
winget --version
```

Expected result:

- PowerShell prints a version table.
- `winget` prints a version.

If `winget` is missing, finish Windows Update and update **App Installer** from the Microsoft Store before continuing.

## Step 2 - Install Base Tools

Run these from the Administrator shell:

```powershell
winget install --exact --id Microsoft.PowerShell --source winget --accept-package-agreements --accept-source-agreements
winget install --exact --id Git.Git --source winget --accept-package-agreements --accept-source-agreements
winget install --exact --id OpenJS.NodeJS.LTS --source winget --accept-package-agreements --accept-source-agreements
winget install --exact --id Python.Python.3.12 --source winget --accept-package-agreements --accept-source-agreements
```

Close the shell and open a new **PowerShell 7** window. The title or prompt should say `PowerShell 7`, or `pwsh` should be available.

Run:

```powershell
pwsh --version
git --version
node --version
npm --version
py --version
```

Expected result:

- `pwsh` is version 7 or later.
- `node` is version 20 or later.
- `git`, `npm`, and `py` print versions.

## Step 3 - Install Validation Tools

Run these from PowerShell 7:

```powershell
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
Install-Module -Name Pester -MinimumVersion 5.0 -Force -Scope CurrentUser
Install-Module -Name PSScriptAnalyzer -Force -Scope CurrentUser
py -m pip install --user pre-commit
```

Add the Python user scripts directory to this shell session and confirm `pre-commit` works:

```powershell
$env:Path = "$env:APPDATA\Python\Python312\Scripts;$env:Path"
pre-commit --version
```

If `pre-commit` is still not found, close PowerShell 7 and open it again. Then run:

```powershell
$env:Path = "$env:APPDATA\Python\Python312\Scripts;$env:Path"
pre-commit --version
```

If the executable still is not on `Path`, use the Python module form while you fix `Path`:

```powershell
py -m pre_commit --version
```

## Step 4 - Clone The Repository

Replace `REPLACE_WITH_REPOSITORY_URL` before running this block.

```powershell
$RepositoryRoot = Join-Path -Path $HOME -ChildPath 'GitHub\ProStateKit'
$RepositoryParent = Split-Path -Path $RepositoryRoot -Parent
New-Item -Path $RepositoryParent -ItemType Directory -Force
git clone 'REPLACE_WITH_REPOSITORY_URL' $RepositoryRoot
Set-Location $RepositoryRoot
```

If you already cloned the repository another way, just go to the repository root:

```powershell
Set-Location (Join-Path -Path $HOME -ChildPath 'GitHub\ProStateKit')
```

## Step 5 - Install Repo Packages

Run:

```powershell
npm install
```

Expected result:

- `node_modules` is created locally.
- `npm` exits successfully.

Do not commit `node_modules`.

## Step 6 - Run Validation

Run the full repository validation wrapper:

```powershell
npm run validate
```

Expected result:

- Markdown lint passes.
- Schema lint passes.
- PowerShell parse checks pass.
- PSScriptAnalyzer passes.
- Pester tests pass.
- `pre-commit run --all-files` passes when `pre-commit` is available.

If you want the individual checks while troubleshooting, run:

```powershell
npm run lint:md
pwsh -NoProfile -File .\src\tools\Invoke-SchemaLint.ps1
pwsh -NoProfile -File .\src\tools\Invoke-PSScriptAnalyzer.ps1
Invoke-Pester -Path tests\PowerShell -Output Detailed
pre-commit run --all-files
```

If `pre-commit` is installed but not on `Path`, run the final line as:

```powershell
py -m pre_commit run --all-files
```

If Windows reports that a script is blocked because it came from the internet, run this from the repository root and retry validation:

```powershell
Get-ChildItem -Path . -Recurse -File | Unblock-File
```

## Step 7 - Confirm The Expected Preview Failure

Use a temp evidence root so this works without writing to `C:\ProgramData`:

```powershell
$EvidenceRoot = Join-Path -Path $env:TEMP -ChildPath 'ProStateKit\Evidence'
pwsh -File .\src\Invoke-ProStateKit.ps1 `
    -Mode Detect `
    -Plane Local `
    -ConfigPath .\configs\baseline.dsc.yaml `
    -RuntimeMode PinnedBundle `
    -BundleRoot . `
    -EvidenceRoot $EvidenceRoot
$LASTEXITCODE
```

Expected result on a clean checkout:

- The command exits `1`.
- Evidence under `$EvidenceRoot\Runs\...` explains a runtime failure.
- The normalized Runner decision in `wrapper.result.json` is runtime failure, not compliant.

Open the newest evidence folder:

```powershell
Get-ChildItem -Path (Join-Path -Path $EvidenceRoot -ChildPath 'Runs') -Directory |
    Sort-Object -Property LastWriteTime -Descending |
    Select-Object -First 1 |
    ForEach-Object {
        Get-Content -LiteralPath (Join-Path -Path $_.FullName -ChildPath 'summary.txt')
        Get-Content -LiteralPath (Join-Path -Path $_.FullName -ChildPath 'wrapper.result.json') -Raw
    }
```

## Step 8 - Confirm Bundle Build Is Still Blocked

Run:

```powershell
pwsh -File .\tools\Build-Bundle.ps1
$LASTEXITCODE
```

Expected preview result:

- The command fails before creating release artifacts.
- The error says the reviewed pinned DSC runtime must be placed under `runtime/dsc/`.

This is correct until the runtime review workflow is complete.

## Step 9 - Stop Or Move To Runtime Review

Stop here if your goal is to work on repo docs, tests, wrapper code, schemas, or sample evidence.

Move to runtime review only if you are the build owner or are working with the build owner. The production path MUST use a reviewed runtime, not a live endpoint download.

Runtime review checklist:

1. Select the official PowerShell/DSC release asset for the target platform.
2. Record the release URL and source archive SHA-256.
3. Use [.github/scripts/Save-DscRuntimeCandidate.ps1](../../.github/scripts/Save-DscRuntimeCandidate.ps1) in a disposable temp directory.
4. Review the extracted payload.
5. Copy the full reviewed archive payload into `runtime/dsc/`; do not copy only `dsc.exe`.
6. Run `pwsh -File .\tools\Build-Bundle.ps1`.
7. Replace the staged bundle root and validate the staged bundle:

   ```powershell
   $StagedBundleRoot = 'REPLACE_WITH_STAGED_BUNDLE_ROOT'
   pwsh -File .\tools\Test-Bundle.ps1 -BundleRoot $StagedBundleRoot
   ```

8. Follow [Runtime Distribution](../runtime-distribution.md) before committing runtime files.

## Common Fresh-VM Problems

| Symptom | What To Do |
| --- | --- |
| `winget` is not recognized. | Finish Windows Update, update App Installer, and reopen PowerShell. |
| `node` or `git` is not recognized after installation. | Close the shell and open a new PowerShell 7 window. |
| `pre-commit` is not recognized. | Add `$env:APPDATA\Python\Python312\Scripts` to `Path`, reopen PowerShell, or use `py -m pre_commit run --all-files`. |
| `PSScriptAnalyzer is not available`. | Re-run `Install-Module -Name PSScriptAnalyzer -Force -Scope CurrentUser`. |
| `Invoke-Pester` is not available. | Re-run `Install-Module -Name Pester -MinimumVersion 5.0 -Force -Scope CurrentUser`. |
| Build or Detect says the DSC runtime is missing. | This is expected before pinned runtime review and placement. |
| Detect says `ConfigPath must resolve inside BundleRoot`. | Run commands from the repository root and keep `-ConfigPath` under `.\configs\`. |

## Done Check

The fresh Windows 11 VM is ready for ProStateKit development when:

- `npm run validate` passes.
- `pre-commit run --all-files` passes.
- The Detect command in this runbook exits `1` with runtime-failure evidence.
- You can explain that the runtime failure is expected until `runtime/dsc/` contains a reviewed pinned DSC runtime and the bundle manifest exists.
