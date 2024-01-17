Import-Module JumpCloud
Import-Module Posh-CVE

# Define your API key for the NVD Databse
$apiKey = 'YOUR_NVD_API_KEY'  # Replace with your actual API key

# User input for the app or keyword to search 
$targetAppName = Read-Host "Enter the App Name or Keyword to search for: "

# Prepare a collection for vulnerability data
$vulnerabilityData = @()

# Get all systems managed by JumpCloud
$systems = Get-JCSystem

# Loop through each system
foreach ($system in $systems) {
    $systemId = $system.id
    $os = $system.os
    $hostname = $system.displayName

    # Get all apps installed on the system related to the target app
    $apps = Get-JCSystemApp -SystemID $systemId -name $targetAppName -Search

    Write-Output "System ID: $systemId, System Name: $hostname, OS: $os"

    foreach ($app in $apps) {
        $name = $app.name
        if ($os -eq "Mac OS X" -and $name.EndsWith(".app")) {
            $name = $name.Substring(0, $name.Length - 4)
        }
        $version = if ($os -eq "windows") { $app.version } else { $app.BundleShortVersion }

        Write-Output "`tName: $name, Version: $version"

        # Get all vulnerabilities for the app
        $vulnerabilities = Get-CVE -KeyWord $name -Version $version -APIKey $apiKey -FilterAffectedProducts

        if ($vulnerabilities) {
            Write-Output "`tVulnerabilities: $($vulnerabilities.Count) $($vulnerabilities.CVE)"
            foreach ($vuln in $vulnerabilities) {
                $vulnerabilityData += [PSCustomObject]@{
                    CVE = $vuln.CVE
                    Score = $vuln.CVSSv3Score
                    Severity = $vuln.CVSSv3Severity
                    Description = $vuln.Description
                    OS = $os
                    SystemID = $systemId
                    Hostname = $hostname
                }
            }
        } else {
            Write-Output "`tNo known vulnerabilities found."
        }
    }
}

# Export to CSV
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$fileName = "Vulnerabilities-${targetAppName}-${timestamp}.csv"
$vulnerabilityData | Export-Csv -Path $fileName -NoTypeInformation

Write-Output "Exported vulnerabilities to $fileName"