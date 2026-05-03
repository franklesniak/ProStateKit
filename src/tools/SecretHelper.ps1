[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $VaultName,

    [Parameter(Mandatory)]
    [string] $ItemName
)

# Preview scaffold only. Secret retrieval is not implemented.
# Sensitive values must never be written to transcripts, stdout, logs, evidence files
# (dsc.raw.json, wrapper.result.json, summary.txt), or any other captured artifact.
# Any surfaced error message must be redacted before it leaves this helper.
# The helper may record only fact-of-retrieval metadata: vault name and item name, never value material.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$objSecretRequest = [pscustomobject]@{
    VaultName = $VaultName
    ItemName = $ItemName
}
$null = $objSecretRequest

# TODO: Retrieve runtime values through Microsoft.PowerShell.SecretManagement.
# TODO: Redact surfaced failures and return non-zero status on resolution failure.

throw [System.NotImplementedException]::new('SecretHelper.ps1 is not yet implemented.')
