[CmdletBinding()]
param(
    [string] $RepositoryRoot = (Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent)
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$strSettingsPath = Join-Path -Path $RepositoryRoot -ChildPath '.github/linting/PSScriptAnalyzerSettings.psd1'
if (-not (Get-Command -Name Invoke-ScriptAnalyzer -ErrorAction SilentlyContinue)) {
    throw [System.NotImplementedException]::new('PSScriptAnalyzer is not available; install it before this wrapper can run.')
}

foreach ($path in @('.github/scripts', 'src', 'planes', 'tests', 'tools')) {
    $analysisPath = Join-Path -Path $RepositoryRoot -ChildPath $path
    if (Test-Path -LiteralPath $analysisPath) {
        foreach ($scriptPath in Get-ChildItem -LiteralPath $analysisPath -Include '*.ps1', '*.psm1' -Recurse -File) {
            $analyzerParameters = @{
                Path = $scriptPath.FullName
                Settings = $strSettingsPath
            }
            try {
                $results = @(Invoke-ScriptAnalyzer @analyzerParameters)
            } catch {
                throw [System.InvalidOperationException]::new(
                    ('PSScriptAnalyzer failed while analyzing {0}: {1}' -f $scriptPath.FullName, $_.Exception.Message),
                    $_.Exception
                )
            }

            if ($results.Count -gt 0) {
                $results | Format-Table -AutoSize
                throw [System.InvalidOperationException]::new('PSScriptAnalyzer found violations in {0}.' -f $scriptPath.FullName)
            }
        }
    }
}
