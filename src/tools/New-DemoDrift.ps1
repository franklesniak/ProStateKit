[CmdletBinding(SupportsShouldProcess)]
param(
    [string] $RegistryPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient',

    [string] $ValueName = 'EnableMulticast',

    [int] $DriftValue = 1,

    [string] $MarkerPath = ''
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if (-not [string]::IsNullOrWhiteSpace($MarkerPath)) {
    if ([System.Environment]::OSVersion.Platform -ne [System.PlatformID]::Win32NT -and $MarkerPath -like 'C:\*') {
        throw [System.PlatformNotSupportedException]::new('Default demo drift path is Windows-only. Pass -MarkerPath for non-Windows tests.')
    }

    if ($PSCmdlet.ShouldProcess($MarkerPath, 'Remove demo marker file to create drift')) {
        Remove-Item -LiteralPath $MarkerPath -Force -ErrorAction SilentlyContinue
    }
    return
}

if ([System.Environment]::OSVersion.Platform -ne [System.PlatformID]::Win32NT) {
    throw [System.PlatformNotSupportedException]::new('Default demo drift registry path is Windows-only. Pass -MarkerPath for non-Windows tests.')
}

$target = '{0}\{1}' -f $RegistryPath, $ValueName
if ($PSCmdlet.ShouldProcess($target, 'Set LLMNR demo registry value to a noncompliant value')) {
    if (-not (Test-Path -LiteralPath $RegistryPath)) {
        [void] (New-Item -Path $RegistryPath -Force)
    }
    [void] (New-ItemProperty -LiteralPath $RegistryPath -Name $ValueName -PropertyType DWord -Value $DriftValue -Force)
}
