<#
.COMPONENT
    Get-SystemReport

.DESCRIPTION
    This script will generate a report of all systems in JumpCloud. The report will include the following information:
    - System ID
    - Hostname
    - User
    - Days
    - Hours
    - Minutes
    - Seconds
    - Total Uptime (s)
    - Battery Health
    - Battery State
    - Battery Manufacturer
    - Battery Model
    - Battery Serial Number
    - Battery Cycle Count
    - Battery Capacity (%)
    - CPU Brand
    - CPU Type
    - Hardware Model
    - Hardware Serial
    - Physical Memory
    ... and more

    The report will be displayed in a table format and exported to a CSV file.

.PARAMETER IncludeUptime
    Include system uptime information in the report.

.PARAMETER IncludeBattery  
    Include battery information in the report.

.PARAMETER IncludeSystemInfo
    Include system information in the report.

.EXAMPLE    
    Get-SystemReport -IncludeBattery -IncludeSystemInfo -IncludeUptime
    This example will generate a report of all systems in JumpCloud. 
    The report will include system uptime, battery, and system information.

.NOTES

    Author:         Juergen Klaassen

    Last Updated:   2023-"may the 4th be with you"

    Version:        1.0

    Change Log:

        1.0     2023-05-04      Initial release.

.REQUIREMENTS
    - JumpCloud PowerShell module 
    - PowerShell 5.1 or later
    - A JumpCloud API key with at least Read permissions

.LINK
    Repo: https://github.com/juergen-kc/JumpCloud/blob/main/JC%20-%20Get-SystemReport.ps1
    Article: https://community.jumpcloud.com/t5/community-scripts/powershell-function-get-systemreport-with-details-on-systeminfo/m-p/2806/highlight/true#M233
#>

# Check if the JumpCloud PowerShell module is installed
if (-not (Get-Module -Name JumpCloud -ListAvailable)) {
    # If the module is not installed, install it
    Install-Module -Name JumpCloud -Scope CurrentUser -Force
}

# Import the JumpCloud PowerShell module
Import-Module JumpCloud -Force

# Define the function to generate the report and accept the desired parameters as input from the user.
function Get-SystemReport {
    param (
        [switch]$IncludeUptime,
        [switch]$IncludeBattery,
        [switch]$IncludeSystemInfo
    )

    # Get all systems
    $systems = Get-JCSystem

    # Initialize an empty array to store the results
    $results = @()

    # Loop through each system
    foreach ($system in $systems) {
        # Initialize an empty custom object
        $result = [PSCustomObject]@{
            'System ID' = $system.id
            'Hostname'  = $system.hostname
            'User'      = $system.userMetrics.userName
            'OS'        = $system.os
            'OS Version' = $system.Version
            # Note: you can add additional properties here if desired, for example:
            # 'Last Seen' = $system.lastSeen
        }

        if ($IncludeUptime) {
            # Get system uptime using Get-JcSdkSystemInsightUptime filtered by SystemId
            $uptime = Get-JcSdkSystemInsightUptime | Where-Object { $_.SystemId -eq $system.id }

            # Add uptime information to the custom object
            $result | Add-Member -MemberType NoteProperty -Name 'Days' -Value $uptime.Days
            $result | Add-Member -MemberType NoteProperty -Name 'Hours' -Value $uptime.Hours
            $result | Add-Member -MemberType NoteProperty -Name 'Minutes' -Value $uptime.Minutes
            $result | Add-Member -MemberType NoteProperty -Name 'Seconds' -Value $uptime.Seconds
            $result | Add-Member -MemberType NoteProperty -Name 'Total Uptime (s)' -Value $uptime.TotalSeconds
        }

        if ($IncludeBattery) {
            # Get battery information using Get-JcSdkSystemInsightBattery filtered by SystemId
            $battery = Get-JcSdkSystemInsightBattery | Where-Object { $_.SystemId -eq $system.id }

            # Add battery information to the custom object
            $result | Add-Member -MemberType NoteProperty -Name 'Battery Health' -Value $battery.Health
            $result | Add-Member -MemberType NoteProperty -Name 'Battery State' -Value $battery.State
            $result | Add-Member -MemberType NoteProperty -Name 'Battery Manufacturer' -Value $battery.Manufacturer
            $result | Add-Member -MemberType NoteProperty -Name 'Battery Model' -Value $battery.Model
            $result | Add-Member -MemberType NoteProperty -Name 'Battery Serial Number' -Value $battery.SerialNumber
            $result | Add-Member -MemberType NoteProperty -Name 'Battery Cycle Count' -Value $battery.CycleCount
            $result | Add-Member -MemberType NoteProperty -Name 'Battery Capacity (%)' -Value $battery.PercentRemaining
        }

        if ($IncludeSystemInfo) {
            # Get system information using Get-JcSdkSystemInsightSystemInfo filtered by SystemId
            $systemInfo = Get-JcSdkSystemInsightSystemInfo | Where-Object { $_.SystemId -eq $system.id }

            # Add system information to the custom object
            $result | Add-Member -MemberType NoteProperty -Name 'CPU Brand' -Value $systemInfo.CpuBrand
            $result | Add-Member -MemberType NoteProperty -Name 'CPU Type' -Value $systemInfo.CpuType
            $result | Add-Member -MemberType NoteProperty -Name 'Hardware Model' -Value $systemInfo.HardwareModel
            $result | Add-Member -MemberType NoteProperty -Name 'Hardware Serial' -Value $systemInfo.HardwareSerial
            $result | Add-Member -MemberType NoteProperty -Name 'Physical Memory' -Value $systemInfo.PhysicalMemory
            # Note: you can add additional properties here if desired, for example:
            # $result | Add-Member -MemberType NoteProperty -Name 'System Manufacturer' -Value $systemInfo.SystemManufacturer
            # $result | Add-Member -MemberType NoteProperty -Name 'System Model' -Value $systemInfo.SystemModel
        }

        # Add the custom object to the results array
        $results += $result
    }

    # Display the results in a table format in the console window 
    $results | Format-Table

    # Export the results to a CSV file in the current directory 
    $results | Export-Csv -Path "SystemReport.csv" -NoTypeInformation
}

# Call the function with the desired parameters 
# Call the function with no parameters to generate a report of all systems in JumpCloud including their users, OS and OS Version only
Get-SystemReport -IncludeUptime -IncludeBattery -IncludeSystemInfo 
