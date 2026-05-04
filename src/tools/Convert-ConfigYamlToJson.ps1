[CmdletBinding()]
param(
    [string] $SourcePath = 'configs/baseline.dsc.yaml',

    [string] $DestinationPath = 'configs/generated/baseline.dsc.json',

    [string] $DependencyRoot = (Get-Location).Path
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$sourcePathFull = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($SourcePath)
$destinationPathFull = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($DestinationPath)
$dependencyRootFull = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($DependencyRoot)
$yamlModulePath = Join-Path -Path $dependencyRootFull -ChildPath 'node_modules/js-yaml/index.js'

if (-not (Test-Path -LiteralPath $sourcePathFull -PathType Leaf)) {
    throw [System.IO.FileNotFoundException]::new('Source YAML config was not found.', $sourcePathFull)
}

if (-not (Test-Path -LiteralPath $yamlModulePath -PathType Leaf)) {
    throw [System.IO.FileNotFoundException]::new(
        ('js-yaml parser dependency was not found. Run npm install before converting YAML: {0}' -f $yamlModulePath),
        $yamlModulePath
    )
}

[void] (New-Item -Path (Split-Path -Path $destinationPathFull -Parent) -ItemType Directory -Force)
$nodeScript = @'
const fs = require('fs');
const yaml = require(process.argv[1]);
const sourcePath = process.argv[2];
const destinationPath = process.argv[3];
const parsed = yaml.load(fs.readFileSync(sourcePath, 'utf8'), { filename: sourcePath });
fs.writeFileSync(destinationPath, JSON.stringify(parsed, null, 2) + '\n', 'utf8');
'@

& node -e $nodeScript $yamlModulePath $sourcePathFull $destinationPathFull
if ($LASTEXITCODE -ne 0) {
    throw [System.InvalidOperationException]::new('YAML to JSON conversion failed.')
}

Write-Output $destinationPathFull
