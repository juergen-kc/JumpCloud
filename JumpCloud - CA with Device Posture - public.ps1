# Import the JumpCloud Module
Import-Module JumpCloud -Force

# Get all systems
$systems = Get-JCSystem

# Get timestamp
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"

# Initialize dictionaries to hold compliant and non-compliant systems
$compliantSystems = @()
$nonCompliantSystems = @()

# Classify each system as compliant or non-compliant
foreach ($system in $systems) {
    $isCompliant = ($system.policyStats.failed -eq 0) -and
                   ($system.policyStats.pending -eq 0) -and
                   ($system.allowMultiFactorAuthentication -eq $true) -and
                   ((($system.os -eq "Mac OS X") -or ($system.os -eq "Windows") -or ($system.os -eq "Linux")) -and
                    ($system.lastContact -gt (Get-Date).AddDays(-30)) -and
                    ($system.agentVersion -gt "1.162.1") -and
                    ($system.version -gt "14.2.1") -and
                    ($system.osVersionDetail.releaseName -eq "Sonoma"))

    if ($isCompliant) {
        $compliantSystems += $system
    } else {
        $nonCompliantSystems += $system
    }
}

# Function to update user descriptions based on system compliance
function Update-UserDescriptions {
    param (
        $systems,
        $complianceStatus
    )
    foreach ($system in $systems) {
        # Query associated managed users for the current system
        $systemUsers = Get-JCSystemUser -SystemId $system.id

        # Loop through each user
        foreach ($user in $systemUsers) {
            # Extract the username from the user object
            $username = $user.username

            # Verifying we have a username before attempting to set the description
            if (-not [string]::IsNullOrWhiteSpace($username)) {
                $description = "device ${complianceStatus}: ${timestamp}"
                Write-Host "Adding description '$description' to user $username on system $($system.id)."
                Set-JCUser -UserName $username -Description $description
            }
            else {
                Write-Host "User $($user.id) does not have a valid username."
            }
        }
    }
}

# Update descriptions for users with compliant devices
Update-UserDescriptions -systems $compliantSystems -complianceStatus "compliant"

# Update descriptions for users with non-compliant devices
Update-UserDescriptions -systems $nonCompliantSystems -complianceStatus "not compliant"
