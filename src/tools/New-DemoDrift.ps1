[CmdletBinding(SupportsShouldProcess)]
param(
    [string] $MarkerPath = 'C:\ProgramData\ProStateKit\Baseline\baseline-applied.txt'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if ([System.Environment]::OSVersion.Platform -ne [System.PlatformID]::Win32NT -and $MarkerPath -like 'C:\*') {
    throw [System.PlatformNotSupportedException]::new('Default demo drift path is Windows-only. Pass -MarkerPath for non-Windows tests.')
}

if ($PSCmdlet.ShouldProcess($MarkerPath, 'Remove demo marker file to create drift')) {
    Remove-Item -LiteralPath $MarkerPath -Force -ErrorAction SilentlyContinue
}
