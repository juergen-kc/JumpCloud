<#
.DESCRIPTION
This script creates policies from .mobileconfig files, checks if a Policy Group with the specified name exists or creates a new one if needed, and then adds the created policies to that Policy Group using the Set-JcSdkPolicyGroupMember cmdlet.

.COMPONENT
JumpCloud PowerShell Module

.NOTES
Requires JumpCloud PowerShell Module and API key.

.EXAMPLE
.\YourScriptName.ps1

.FUNCTIONALITY
- Connects to JumpCloud using API key.
- Reads .mobileconfig files from a specified folder.
- Creates policies based on .mobileconfig files.
- Checks if a Policy Group with the specified name exists or creates a new one if needed.
- Adds created policies to the Policy Group using Set-JcSdkPolicyGroupMember cmdlet.

.INPUTS
$apiKey: Your JumpCloud API key.
$mobileConfigFolderPath: The path to the folder containing .mobileconfig files.
$templateID: The template ID for creating policies in JumpCloud.
$policyGroupName: The name of the Policy Group you want to add policies to or create.

.OUTPUTS
Displays progress messages during script execution and outputs the final result with success message and Policy Group ID.

.LINK
https://github.com/TheJumpCloud/support/tree/master/PowerShell
https://community.jumpcloud.com/t5/community-scripts/new-jcpolicy-set-jcpolicy-create-and-update-jumpcloud-policies/m-p/2790/highlight/true#M231
https://github.com/TheJumpCloud/jcapi-powershell

.ROLE
JumpCloud Administrator

.AUTHOR
Juergen Klaassen

.DATE
2023-06-02

.VERSION
1.0

.DISCLAIMER
This script is provided "as is" without warranty of any kind.
#>
# ------------------------------
# Customizable Variables
# ------------------------------
$apiKey = "YOUR_JUMPCLOUD_API_KEY"
$mobileConfigFolderPath = "YOUR_MOBILECONFIG_FOLDER_PATH"
$templateID = "5f21c4d3b544067fd53ba0af"
$policyGroupName = "YOUR_POLICY_GROUP_NAME"
# ------------------------------

# Import the JumpCloud module
Write-Host "Importing JumpCloud module..." -ForegroundColor Cyan
Import-Module JumpCloud

# Connect to JumpCloud using Connect-JC cmdlet
Write-Host "Connecting to JumpCloud..." -ForegroundColor Cyan
Connect-JCOnline $apiKey

# Get all .mobileconfig files in the folder
Write-Host "Getting all .mobileconfig files in the folder..." -ForegroundColor Cyan
$mobileConfigFiles = Get-ChildItem -Path $mobileConfigFolderPath -Filter *.mobileconfig

# Create an empty list to store policy IDs of created policies
$policyIds = @()

foreach ($file in $mobileConfigFiles) {
    # Read and convert the mobileconfig file content to base64 format
    Write-Host "Reading and converting $($file.Name) to base64 format..." -ForegroundColor Cyan
    $content = Get-Content -Path $file.FullName -Raw
    $base64Content = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($content))

    # Extract PayloadDisplayName value from the content
    Write-Host "Extracting PayloadDisplayName value from the content..." -ForegroundColor Cyan
    $payloadDisplayNamePattern = '(?<=<key>PayloadDisplayName<\/key>\s*<string>).*?(?=<\/string>)'
    $payloadDisplayName = [regex]::Match($content, $payloadDisplayNamePattern).Value

    # Create a new policy using New-JCPolicy cmdlet with required parameters
    Write-Host "Creating a new policy using New-JCPolicy cmdlet with required parameters..." -ForegroundColor Cyan
    $policyName = "Custom CIS $($payloadDisplayName)"
    $payloadValue = @{
        configFieldID   = "5f21c4d3b544067fd53ba0b0"
        configFieldName = "payload"
        sensitive       = $false
        value           = $base64Content
    }

    # Create the policy and store its ID in the list of policy IDs
    Write-Host "Creating the policy and storing its ID in the list of policy IDs..." -ForegroundColor Cyan
    $createdPolicy = New-JCPolicy -name $policyName -templateID $templateID -values $payloadValue
    $policyIds += $createdPolicy.id
}

# Check if a Policy Group with the specified name already exists
Write-Host "Checking if a Policy Group with the specified name already exists..." -ForegroundColor Cyan
$existingPolicyGroup = Get-JcSdkPolicyGroup | Where-Object { $_.name -eq $policyGroupName }

if ($existingPolicyGroup) {
    # Use the existing Policy Group ID to add policies to it
    Write-Host "Using the existing Policy Group ID to add policies to it..." -ForegroundColor Cyan
    $policyGroupId = $($existingPolicyGroup.id)
} else {
    # Create a new Policy Group and use its ID to add policies to it
    Write-Host "Creating a new Policy Group and using its ID to add policies to it..." -ForegroundColor Cyan
    $createdPolicyGroup = New-JcSdkPolicyGroup -name $policyGroupName
    $policyGroupId = $($createdPolicyGroup.id)
}

# Add policies to the Policy Group using Set-JcSdkPolicyGroupMember cmdlet
Write-Host "Adding policies to the Policy Group using Set-JcSdkPolicyGroupMember cmdlet..." -ForegroundColor Cyan
foreach ($policyId in $policyIds) {
    Set-JcSdkPolicyGroupMember -groupid $($policyGroupId) -id $($policyId) -op add
}
Write-Host "All policies have been added to the Policy Group successfully!" -ForegroundColor Green
Write-Host "Policy Group ID: $($policyGroupId)" -ForegroundColor Green
Write-Host "Job done!"