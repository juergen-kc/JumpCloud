# Import the JumpCloud PowerShell Module
Import-Module JumpCloud

# Function to convert bytes to a more readable format
function Convert-Bytes {
    param (
        [Parameter(Mandatory=$true)]
        [double]$Bytes,
        [ValidateSet("MB", "GB")]
        [string]$Unit = "GB"
    )
    switch ($Unit) {
        "MB" { return [math]::round($Bytes / 1MB, 2) }
        "GB" { return [math]::round($Bytes / 1GB, 2) }
    }
}

# Get Logical Drive Information
$logicalDrives = Get-JCSystemInsights -Table LogicalDrive

# Create a hashtable to store system information
$systemInfo = @{}

# Loop through each logical drive entry
foreach ($drive in $logicalDrives) {
    $systemId = $drive.SystemId

    # Check if system info has already been retrieved
    if (-not $systemInfo.ContainsKey($systemId)) {
        # Retrieve system information using Get-JCSystem
        $system = Get-JCSystem -Id $systemId
        $systemInfo[$systemId] = [PSCustomObject]@{
            Hostname = $system.hostname
            DisplayName = $system.displayName
            OS = $system.os
        }
    }
}

# Create a report
$report = foreach ($drive in $logicalDrives) {
    $systemId = $drive.SystemId
    [PSCustomObject]@{
        Hostname = $systemInfo[$systemId].Hostname
        DisplayName = $systemInfo[$systemId].DisplayName
        # OS = $systemInfo[$systemId].OS
        BootPartition = $drive.BootPartition
        CollectionTime = $drive.CollectionTime
        DeviceId = $drive.DeviceId
        FileSystem = $drive.FileSystem
        Size_GB = Convert-Bytes -Bytes $drive.Size -Unit "GB"
        FreeSpace_GB = Convert-Bytes -Bytes $drive.FreeSpace -Unit "GB"
        FreeSpace_Percent = [math]::round($drive.FreeSpace / $drive.Size * 100, 2)
        UsedSpace_GB = Convert-Bytes -Bytes ($drive.Size - $drive.FreeSpace) -Unit "GB"
        UsedSpace_Percent = [math]::round(($drive.Size - $drive.FreeSpace) / $drive.Size * 100, 2)
    }
}

# Export the report to a CSV file
$report | Export-Csv -Path "WindowsDiskUsageReport.csv" -NoTypeInformation

# Output the report
$report