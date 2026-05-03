[CmdletBinding()]
param(
    [string] $SourcePath = 'configs/baseline.dsc.yaml',

    [string] $DestinationPath = 'configs/generated/baseline.dsc.json'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$sourcePathFull = [System.IO.Path]::GetFullPath($SourcePath)
$destinationPathFull = [System.IO.Path]::GetFullPath($DestinationPath)

if (-not (Test-Path -LiteralPath $sourcePathFull -PathType Leaf)) {
    throw [System.IO.FileNotFoundException]::new('Source YAML config was not found.', $sourcePathFull)
}

[void] (New-Item -Path (Split-Path -Path $destinationPathFull -Parent) -ItemType Directory -Force)
$nodeScript = @'
const fs = require('fs');
const yaml = require('js-yaml');
const sourcePath = process.argv[1];
const destinationPath = process.argv[2];
const parsed = yaml.load(fs.readFileSync(sourcePath, 'utf8'), { filename: sourcePath });
fs.writeFileSync(destinationPath, JSON.stringify(parsed, null, 2) + '\n', 'utf8');
'@

& node -e $nodeScript $sourcePathFull $destinationPathFull
if ($LASTEXITCODE -ne 0) {
    throw [System.InvalidOperationException]::new('YAML to JSON conversion failed.')
}

Write-Output $destinationPathFull
