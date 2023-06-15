<#
.DESCRIPTION
This script will create a new custom policy for each .reg file in the specified folder. The policy name will be the .reg filename prefixed with the specified prefix. 
The script will then update the policy with the registry keys and values from the .reg file.

.COMPONENT


.FUNCTIONALITY
v1.0 - Initial release


.EXAMPLE
PS C:\> .\JumpCloud - Bulk REG Importer to Custom Policies.ps1

.INPUTS
Reg files containing registry keys and values

.OUTPUTS
Custom policies with registry keys and values from the .reg files

.PARAMETER
none

.NOTES
Author: Jeroen Klaassen
Date: 2020-07-09
Version: 1.0


.LINK

#>

# Function: REG Importer to Custom Policies
# Description: This script will create a new custom policy for each .reg file in the specified folder. 
# The policy name will be the .reg filename prefixed with the specified prefix.

function Update-PolicyWithRegistryKeys {
    param (
        [string]$policyID,
        [string]$policyName,
        [hashtable]$headers,
        [string]$registryFilePath
    )
    # Construct the request body containing existing and new registry keys
    Write-Host "Constructing the request body containing existing and new registry keys..." -ForegroundColor Cyan
    $url = "https://console.jumpcloud.com/api/v2/policies/" + $policyID
    $regContent = Get-Content -Path $registryFilePath
    $response = Invoke-RestMethod -Uri $url -Method GET -Headers $headers

    # Parse registry file content and create new key-value pairs
    $newkeysOut = @()
    foreach ($line in $regContent) {
        if ($line.StartsWith(";")) {
            # Extract ID and Name from comment line (not used in this version)
        } elseif ($line.StartsWith("[")) {
            # Extract registry path from line
            $path = ($line.TrimStart("[").TrimEnd("]")).Replace("HKEY_LOCAL_MACHINE", "").Replace("\\\\", "\\").TrimStart("\")
        } else {
            # Extract value name, type, and data from line
            if ($line.Contains("=")) {
                $valueParts = $($line.Split("=")).Trim("`"")
                $valueName = $($valueParts[0]).Trim()
                if ($($valueParts[1]).StartsWith("dword:")) {
                    # DWORD value type
                    $type = "DWORD"
                    $data = $($valueParts[1]).Substring(6)
                } else {
                    # String value type
                    $type = "String"
                    $data = $($valueParts[1]).Trim("`"")
                }

                # Add new key to the list
                $newKey =  [pscustomobject]@{
                    "customLocation" = $path
                    "customValueName" = $valueName
                    "customRegType" = $type
                    "customData" = $data
                }
                $newkeysOut += $newKey
            }
        }
    }

    if ($null -ne $response.values.value) {
        $newkeysOut +=$response.values.value
    }

    # Continue building the body
    $body = @{
        "name"     = $($policyName)
        "values"   = @(@{
            "configFieldID"   = '5f07273cb544065386e1ce70'
            "configFieldName" = 'customRegTable'
            "sensitive"       = $($false)
            "value"           = @($newkeysOut)
        })
        "template" = @{
            "id"          =$($response.template.id)
        }
    }

    # Convert the body to JSON and update the policy with the new registry keys
    Write-Host "Updating the policy with the new registry keys:" -ForegroundColor Cyan

    try {
        Invoke-RestMethod -Uri $url -Method Put -Headers $headers -ContentType 'application/json' -Body (ConvertTo-Json -InputObject($body) -Depth 10 | ForEach-Object { $_ -replace 'Values','values' })
    } catch {
        Write-Host ("Error updating policy: {0}`n{1}" -f $_.Exception.Response.StatusCode.Value__, $_.Exception.Message) -ForegroundColor Red
        Write-Host ("Request body:`n{0}" -f (ConvertTo-Json -InputObject($body) -Depth 10 | ForEach-Object { $_ -replace 'Values','values' })) -ForegroundColor Yellow
    }
}

# Function: Create-NewPolicy
# Description: This function will create a new empty policy and return its ID
function Create-NewPolicy {
    param (
        [string]$policyName,
        [hashtable]$headers
    )

    $url = "https://console.jumpcloud.com/api/v2/policies"
    $body = @{
        "name" = $policyName
        "template" = @{
            "id" = "5f07273cb544065386e1ce6f"
        }
    }

    $bodyJson = ConvertTo-Json -InputObject($body)
    $response = Invoke-RestMethod -Uri $url -Method POST -Headers $headers -ContentType 'application/json' -Body $($bodyJson)

    return $response.id
}

# Main script
# Replace values where indicated:
$folderPath = "/Users/jklaassen/Downloads/CIS Custom Practical/" # Replace with your folder path
$prefix = "_" # Replace with your custom prefix

$headers=@{}
$headers.Add("x-org-id", "<YOUR_ORG_ID>") # Replace with your JumpCloud organization ID
$headers.Add("x-api-key", "<YOUR_API_KEY>") # Replace with your JumpCloud API key
$headers.Add("content-type", "application/json")

# Do not change code below this line
Get-ChildItem -LiteralPath $folderPath -Filter *.reg | ForEach-Object {
    try {
        $filenameWithoutExtension = [System.IO.Path]::GetFileNameWithoutExtension($_.FullName)
        $newPolicyName = "$prefix$filenameWithoutExtension"

        Write-Host "Creating new policy: '$newPolicyName'"
        
        # Create a new empty policy and get its ID
        $newPolicyID = Create-NewPolicy -policyName $newPolicyName -headers $headers

        Write-Host "Updating the new policy with the values from the .reg file: '$($_.FullName)'"
        
        # Update the newly created policy with the values from the .reg file
        Update-PolicyWithRegistryKeys `
            -policyID $newPolicyID `
            -policyName $newPolicyName `
            -headers $headers `
            -registryFilePath $_.FullName
    } catch {
        Write-Host "Error processing file '$($_.FullName)': $($_.Exception.Message)" -ForegroundColor Red
    }
}
