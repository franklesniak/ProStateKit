[CmdletBinding()]
param(
    [string] $RepositoryRoot = (Split-Path -Path $PSScriptRoot -Parent),

    [switch] $SkipPreCommit
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

Push-Location -LiteralPath $RepositoryRoot
try {
    & npm run lint:md
    if ($LASTEXITCODE -ne 0) {
        throw [System.InvalidOperationException]::new('Markdown lint failed.')
    }

    & npm run lint:md:nested
    if ($LASTEXITCODE -ne 0) {
        throw [System.InvalidOperationException]::new('Nested Markdown lint failed.')
    }

    & npm run lint:md:links
    if ($LASTEXITCODE -ne 0) {
        throw [System.InvalidOperationException]::new('Markdown link lint failed.')
    }

    & pwsh -NoProfile -File 'src/tools/Invoke-SchemaLint.ps1'
    if ($LASTEXITCODE -ne 0) {
        throw [System.InvalidOperationException]::new('Schema lint failed.')
    }

    foreach ($scriptPath in Get-ChildItem -LiteralPath $RepositoryRoot -Include '*.ps1', '*.psm1' -Recurse -File) {
        if ($scriptPath.FullName -match '[\\/](node_modules|\.pre-commit-cache|\.npm-cache|\.pip-cache)[\\/]') {
            continue
        }

        $tokens = $null
        $parseErrors = $null
        $null = [System.Management.Automation.Language.Parser]::ParseFile(
            $scriptPath.FullName,
            [ref] $tokens,
            [ref] $parseErrors
        )
        if ($parseErrors.Count -gt 0) {
            $parseErrors | Format-Table -AutoSize
            throw [System.FormatException]::new('PowerShell parse failed: {0}' -f $scriptPath.FullName)
        }
    }

    & pwsh -NoProfile -File 'src/tools/Invoke-PSScriptAnalyzer.ps1'
    if ($LASTEXITCODE -ne 0) {
        throw [System.InvalidOperationException]::new('PSScriptAnalyzer failed.')
    }

    $pesterResult = Invoke-Pester -Path 'tests/PowerShell' -Output Detailed -PassThru
    if ($pesterResult.FailedCount -gt 0) {
        throw [System.InvalidOperationException]::new('Pester tests failed.')
    }

    if (-not $SkipPreCommit.IsPresent -and (Get-Command -Name pre-commit -ErrorAction SilentlyContinue)) {
        & pre-commit run --all-files
        if ($LASTEXITCODE -ne 0) {
            throw [System.InvalidOperationException]::new('pre-commit failed.')
        }

        $changedFiles = @(
            & git ls-files --modified --others --exclude-standard 2>$null |
                Where-Object -FilterScript {
                    -not [string]::IsNullOrWhiteSpace($_) -and
                    (Test-Path -LiteralPath $_ -PathType Leaf)
                }
        )
        if ($changedFiles.Count -gt 0) {
            & pre-commit run --files @changedFiles
            if ($LASTEXITCODE -ne 0) {
                throw [System.InvalidOperationException]::new('pre-commit failed for changed or untracked files.')
            }
        }
    } elseif (-not $SkipPreCommit.IsPresent) {
        Write-Warning 'pre-commit is not available; skipping pre-commit run.'
    }
} finally {
    Pop-Location
}
