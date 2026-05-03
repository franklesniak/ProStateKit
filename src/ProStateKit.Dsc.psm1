function ConvertFrom-ProStateKitDscJson {
    param(
        [Parameter(Mandatory)]
        [string] $Json,

        [ValidateSet('Detect', 'Remediate')]
        [string] $Mode = 'Detect'
    )

    $parsed = $Json | ConvertFrom-Json -ErrorAction Stop
    $candidateCollections = foreach ($propertyName in @('resources', 'results', 'result', 'actualState')) {
        $property = $parsed.PSObject.Properties[$propertyName]
        if ($null -ne $property) {
            $property.Value
        }
    }
    $items = @()

    foreach ($collection in $candidateCollections) {
        if ($null -eq $collection) {
            continue
        }

        $items = @($collection)
        if ($items.Count -gt 0) {
            break
        }
    }

    if ($items.Count -eq 0) {
        $rootProperties = @($parsed.PSObject.Properties.Name)
        if ($rootProperties -contains 'name' -or
            $rootProperties -contains 'resourceName' -or
            $rootProperties -contains 'type' -or
            $rootProperties -contains 'resourceType') {
            $items = @($parsed)
        } else {
            throw [System.FormatException]::new('DSC JSON did not include resource proof.')
        }
    }

    $resources = foreach ($item in $items) {
        $properties = $item.PSObject.Properties
        $nameProperty = @(
            $properties['name']
            $properties['resourceName']
            $properties['instanceName']
        ) | Where-Object -FilterScript { $null -ne $_ } | Select-Object -First 1
        $typeProperty = @(
            $properties['type']
            $properties['resourceType']
            $properties['fullyQualifiedTypeName']
        ) | Where-Object -FilterScript { $null -ne $_ } | Select-Object -First 1
        $errorProperty = @(
            $properties['error']
            $properties['errorMessage']
            $properties['message']
        ) | Where-Object -FilterScript { $null -ne $_ } | Select-Object -First 1

        $name = 'Unnamed DSC resource'
        $type = 'Unknown'
        $errorValue = $null
        if ($null -ne $nameProperty -and -not [string]::IsNullOrWhiteSpace([string] $nameProperty.Value)) {
            $name = [string] $nameProperty.Value
        }
        if ($null -ne $typeProperty -and -not [string]::IsNullOrWhiteSpace([string] $typeProperty.Value)) {
            $type = [string] $typeProperty.Value
        }
        if ($null -ne $errorProperty) {
            $errorValue = $errorProperty.Value
        }

        $succeeded = $false
        foreach ($propertyName in @('succeeded', 'success', 'inDesiredState', 'compliant')) {
            if ($null -ne $properties[$propertyName]) {
                $succeeded = [bool] $properties[$propertyName].Value
                break
            }
        }

        if ($null -ne $properties['result']) {
            $resultText = [string] $properties['result'].Value
            if ($resultText -match '^(Success|Succeeded|Compliant|InDesiredState)$') {
                $succeeded = $true
            } elseif ($resultText -match '(Fail|Error|NonCompliant|NotInDesiredState)') {
                $succeeded = $false
            }
        }

        $changed = $false
        foreach ($propertyName in @('changed', 'wasChanged', 'rebootRequired')) {
            if ($null -ne $properties[$propertyName]) {
                $changed = [bool] $properties[$propertyName].Value
                break
            }
        }
        if ($Mode -eq 'Detect') {
            $changed = $false
        }

        $rebootRequired = $false
        if ($null -ne $properties['rebootRequired']) {
            $rebootRequired = [bool] $properties['rebootRequired'].Value
        }

        [pscustomobject]@{
            name = $name
            type = $type
            succeeded = $succeeded
            changed = $changed
            error = $errorValue
            rebootRequired = $rebootRequired
        }
    }

    if (@($resources).Count -eq 0) {
        throw [System.FormatException]::new('DSC JSON did not normalize to any resource results.')
    }

    return @($resources)
}

Export-ModuleMember -Function 'ConvertFrom-ProStateKitDscJson'
