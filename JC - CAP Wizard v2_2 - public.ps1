# Step 1: Authentication and Setup
function Authenticate-JumpCloud {
    param (
        [string]$ApiKey
    )
    $headers = @{
        "x-api-key" = $ApiKey
        "Content-Type" = "application/json"
    }
    return $headers
}

# Step 2: Define Policy Name, Description, and Status (Enabled/Disabled)
function Get-PolicyDetails {
    $policyName = Read-Host "Enter the policy name" # Example: "Require MFA for Specific Applications"
    $policyDescription = Read-Host "Enter the policy description" # Example: "This policy requires MFA for specific applications."
    $policyEnabled = Read-Host "Should the policy be enabled? (true/false)" # Example: "true"
    $disabled = if ($policyEnabled -eq "true") { $false } else { $true }
    return @{
        Name = $policyName
        Description = $policyDescription
        Disabled = $disabled
    }
}

# Step 3: Fetch and Display IP Lists
function Fetch-IPLists {
    param (
        [hashtable]$headers
    )
    Write-Host "Fetching the list of available IP lists..." -ForegroundColor Cyan
    $ipListsResponse = Invoke-RestMethod -Uri 'https://console.jumpcloud.com/api/v2/iplists?limit=100' -Method GET -Headers $headers

    # Debug output to verify response
    # Write-Host "Raw response from API:"
    # Write-Host ($ipListsResponse | ConvertTo-Json -Depth 4)

    if (-not $ipListsResponse -or $ipListsResponse.Count -eq 0) {
        Write-Host "No IP lists found or response is null." -ForegroundColor Yellow
        return $null
    }

    $ipLists = $ipListsResponse | ForEach-Object {
        [PSCustomObject]@{
            Id = $_.id
            Name = $_.name
        }
    }

    Write-Host "Parsed IP lists:"
    $ipLists | ForEach-Object { Write-Host "$($_.Name) - $($_.Id)" }

    return $ipLists
}

# Step 4: Set Conditions
function Get-PolicyConditions {
    param (
        [hashtable]$headers
    )
    $conditions = @()

    $deviceManaged = Read-Host "Should the device be managed? (true/false)" # Example: "true"
    if ($deviceManaged -eq "true") {
        $conditions += @{
            "deviceManaged" = $true
        }
    }

    $excludeOperatingSystems = Read-Host "Enter operating systems to exclude (comma-separated, e.g., android,ios,linux) or press Enter to skip"
    if ($excludeOperatingSystems) {
        $osList = @($excludeOperatingSystems -split ",")
        $conditions += @{
            "not" = @{
                "operatingSystemIn" = $osList
            }
        }
    }

    $countries = Read-Host "Enter allowed countries (comma-separated, e.g., US,CA,DE) or press Enter to skip"
    if ($countries) {
        $conditions += @{
            "locationIn" = @{
                "countries" = @($countries -split ",")
            }
        }
    }

    $ipLists = Fetch-IPLists -headers $headers
    if ($ipLists) {
        for ($i = 0; $i -lt $ipLists.Count; $i++) {
            Write-Host "$($i + 1). $($ipLists[$i].Name) - $($ipLists[$i].Id)"
        }

        $selectedIpNumbers = Read-Host "Enter the numbers of the IP lists to include (comma-separated) or press Enter to skip"
        if ($selectedIpNumbers) {
            $selectedIps = $selectedIpNumbers -split "," | ForEach-Object {
                $ipLists[($_.Trim() - 1)].Id
            }
            if ($selectedIps.Count -gt 0) {
                $conditions += @{
                    "ipAddressIn" = @($selectedIps)  # Ensure this is an array
                }
            }
        }
    }

    if ($conditions.Count -gt 1) {
        return @{
            "all" = $conditions
        }
    } elseif ($conditions.Count -eq 1) {
        return $conditions[0]
    } else {
        return @{}
    }
}

# Step 5: Set Effect
function Get-PolicyEffect {
    $allowAccess = Read-Host "Allow access? (true/false)"
    $action = if ($allowAccess -eq "true") { "allow" } else { "deny" }

    $effect = @{
        "action" = $action
    }

    if ($action -eq "allow") {
        $effect["obligations"] = @{
            "mfa" = @{
                "required" = $true
            }
            "userVerification" = @{
                "requirement" = "none"
            }
        }
    }

    return $effect
}

# Step 6: Fetch and Display Applications
function Fetch-Applications {
    param (
        [hashtable]$headers
    )
    Write-Host "Fetching the list of available applications..."
    $appsResponse = Invoke-RestMethod -Uri 'https://console.jumpcloud.com/api/applications' -Method GET -Headers $headers

    # Debug output to verify response
    # Write-Host "Raw response from API:"
    # Write-Host ($appsResponse | ConvertTo-Json -Depth 4)

    if (-not $appsResponse.results -or $appsResponse.results.Count -eq 0) {
        Write-Host "No applications found or response is null." -ForegroundColor Yellow
        return $null
    }

    $apps = $appsResponse.results | ForEach-Object {
        [PSCustomObject]@{
            Id = $_._id
            Name = $_.displayName
        }
    }

    Write-Host "Parsed applications:"
    $apps | ForEach-Object { Write-Host "$($_.Name) - $($_.Id)" }

    for ($i = 0; $i -lt $apps.Count; $i++) {
        Write-Host "$($i + 1). $($apps[$i].Name) - $($apps[$i].Id)"
    }

    $selectedAppNumbers = Read-Host "Enter the numbers of the applications to include (comma-separated)"
    $selectedApps = $selectedAppNumbers -split "," | ForEach-Object {
        $apps[($_.Trim() - 1)]
    }
    $resources = $selectedApps | ForEach-Object {
        @{
            "type" = "application"
            "id" = $_.Id
        }
    }

    return $resources
}

# Step 7: Fetch and Display Groups
function Fetch-Groups {
    param (
        [hashtable]$headers
    )
    Write-Host "Fetching the list of available groups..." -ForegroundColor Cyan
    $groupsResponse = Invoke-RestMethod -Uri 'https://console.jumpcloud.com/api/v2/groups?limit=100' -Method GET -Headers $headers

    # Debug output to verify response
    # Write-Host "Raw response from API:"
    # Write-Host ($groupsResponse | ConvertTo-Json -Depth 4)

    if (-not $groupsResponse -or $groupsResponse.Count -eq 0) {
        Write-Host "No groups found or response is null." -ForegroundColor Yellow
        return $null
    }

    $groups = $groupsResponse | Where-Object { $_.type -eq "user_group" } | ForEach-Object {
        [PSCustomObject]@{
            Id = $_.id
            Name = $_.name
        }
    }

    Write-Host "Parsed groups:"
    $groups | ForEach-Object { Write-Host "$($_.Name) - $($_.Id)" }

    for ($i = 0; $i -lt $groups.Count; $i++) {
        Write-Host "$($i + 1). $($groups[$i].Name) - $($groups[$i].Id)"
    }

    $selectedGroupNumbers = Read-Host "Enter the numbers of the groups to include (comma-separated)"
    $selectedGroups = $selectedGroupNumbers -split "," | ForEach-Object {
        $groups[($_.Trim() - 1)]
    }
    $groupIds = $selectedGroups | ForEach-Object {
        $_.Id
    }

    return $groupIds
}

# Step 8: Review and Confirm
function ReviewAndConfirm {
    param (
        [hashtable]$policyDetails,
        [hashtable]$policyConditions,
        [hashtable]$policyEffect,
        [array]$policyTargets,
        [array]$groupIds
    )
    Write-Host "Review your policy settings:" -ForegroundColor Cyan
    Write-Host "Name: $($policyDetails.Name)"
    Write-Host "Description: $($policyDetails.Description)"
    Write-Host "Conditions: $($policyConditions | ConvertTo-Json -Depth 4)"
    Write-Host "Effect: $($policyEffect | ConvertTo-Json -Depth 4)"
    Write-Host "Targets: $($policyTargets | ConvertTo-Json -Depth 4)"
    Write-Host "Groups: $($groupIds -join ', ')"
    Write-Host "Disabled: $($policyDetails.Disabled)"

    $confirmation = Read-Host "Do you want to proceed with creating this policy? (yes/no)"
    return $confirmation -eq "yes"
}

# Main Script Execution
$apiKey = Read-Host "Enter your JumpCloud API Key"
$headers = Authenticate-JumpCloud -ApiKey $apiKey
$policyDetails = Get-PolicyDetails
$policyEffect = Get-PolicyEffect
$policyTargets = Fetch-Applications -headers $headers
$groupIds = Fetch-Groups -headers $headers
$policyConditions = Get-PolicyConditions -headers $headers

if ($policyTargets -eq $null -or $groupIds -eq $null) {
    Write-Host "Policy creation aborted due to missing targets or groups." -ForegroundColor Red
    return
}

if (ReviewAndConfirm -policyDetails $policyDetails -policyConditions $policyConditions -policyEffect $policyEffect -policyTargets $policyTargets -groupIds $groupIds) {
    $policy = @{
        "name" = $policyDetails.Name
        "description" = $policyDetails.Description
        "disabled" = $policyDetails.Disabled
        "conditions" = $policyConditions
        "effect" = $policyEffect
        "targets" = @{
            "resources" = @($policyTargets)  # Ensure resources is an array
            "userGroups" = @{
                "inclusions" = @($groupIds)  # Ensure inclusions is an array
            }
        }
        "type" = "application"  # hard-code to application for now
    }

    # Debugging output to verify the JSON structure
    $policyJson = $policy | ConvertTo-Json -Depth 10 -Compress
    # Write-Host "JSON Payload:" -ForegroundColor Yellow
    # Write-Host $policyJson

    # Correctly convert to JSON string and send request
    $response = Invoke-RestMethod -Uri 'https://console.jumpcloud.com/api/v2/authn/policies' -Method POST -Headers $headers -ContentType 'application/json' -Body $policyJson
    Write-Host "Policy created successfully: $($response | ConvertTo-Json -Depth 4)" -ForegroundColor Cyan
} else {
    Write-Host "Policy creation aborted." -ForegroundColor Red
}
