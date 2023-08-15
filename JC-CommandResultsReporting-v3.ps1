<#
.SYNOPSIS
    A script to retrieve and display JumpCloud command results, allowing filtering by Command ID and timeframe.

.DESCRIPTION
    This script queries JumpCloud commands and their results. Users can specify a Command ID and timeframe for filtering, and choose various output formats for displaying the results.

.COMPONENT
    Requires JumpCloud cmdlets and optional modules:
    - GraphicalTools (for GridView): https://github.com/PowerShell/GraphicalTools/
    - PowerShellAI (for AI insights): https://github.com/dfinke/PowerShellAI/

.EXAMPLE
    PS C:\> .\YourScriptName.ps1
    Follow the prompts to filter results by Command ID and timeframe, and select the desired output format.

.FUNCTIONALITY
    PowerShell

.OUTPUTS
    Outputs the results as plain text, formatted table, GridView, sends to AI for insights and statistics, or writes to a CSV file.

.NOTES
    Ensure that the required optional modules are installed if using GridView or AI insights.

.VERSION
    Version 3.0 (2023-08-15)

.AUTHOR
    Juergen Klaassen

.COPYRIGHT
    Copyright (c) 2023, Juergen Klaassen
#>

# Display help if requested
if ($args[0] -eq "-Help") {
    Get-Help $MyInvocation.MyCommand.Definition
    exit
}

function Get-TimeFrame {
    $timeframeDays = Read-Host -Prompt "Enter the number of days for the timeframe (or press Enter to skip)"
    if ($timeframeDays -eq "") {
        return $null
    }
    elseif ($timeframeDays -match '^\d+$') {
        return [int]$timeframeDays
    }
    else {
        Write-Host "Invalid input. Please enter a positive integer or leave it blank."
        return Get-TimeFrame
    }
}

function Get-CommandResults {
    param (
        [string]$specificCommandId,
        [int]$timeframeDays
    )

    $results = @()
    $commands = Get-JCCommand

    foreach ($command in $commands) {
        if ($specificCommandId -and $command._id -ne $specificCommandId) {
            continue
        }

        $commandResults = Get-JCCommandResult -CommandID $command._id -ByCommandID

        foreach ($result in $commandResults) {
            $requestTime = [DateTime]::ParseExact($result.requestTime, "MM/dd/yyyy HH:mm:ss", [System.Globalization.CultureInfo]::InvariantCulture)

            if ($timeframeDays -and $requestTime -le (Get-Date).AddDays(-$timeframeDays)) {
                continue
            }

            $users = Get-JCSystemUser -SystemID $result.systemId
            $adminUsers = ($users | Where-Object { $_.Administrator -eq "True" } | ForEach-Object { $_.username }) -join ', '

            $results += New-Object PSObject -Property ([ordered]@{
                'Date' = $requestTime.ToShortDateString()
                'Time' = $requestTime.ToShortTimeString()
                'Command Name' = $command.name
                'Command ID' = $command._id
                'Device Name' = $result.system
                'Associated Users' = if ($users.username) { ($users.username) -join ', ' } else { "No Associated Users" }
                'Admin Users' = if ($adminUsers) { "$adminUsers" } else { "No Admin Users" }
                'Result' = if ($result.exitCode -eq 0) { "Success" } else { "Failure" }
                'Exit Code' = $result.exitCode
            })
        }
    }

    return $results
}

function Display-Results {
    param (
        [array]$results
    )

    $outputOption = Read-Host -Prompt @"
Select how you'd like to view the results:
1) Display results
2) Display results in a table
3) Display results in a GridView (requires PowerShell GraphicalTools module)
4) Send results to AI for insights and statistics (requires PowerShellAI module)
5) Write results to a CSV file
Enter the number corresponding to your choice:
"@

    switch ($outputOption) {
        "1" { $results }
        "2" { $results | Format-Table -AutoSize }
        "3" {
            Import-Module -Name Microsoft.PowerShell.GraphicalTools
            $results | Out-ConsoleGridView
        }
        "4" {
            Import-Module -Name PowerShellAI
            $results | AI "Insights and statistics"
        }
        "5" {
            $csvPath = Read-Host -Prompt "Enter the full path for the CSV file (e.g., C:\path\to\file.csv)"
            $results | Export-Csv -Path $csvPath -NoTypeInformation
            Write-Host "Results written to $csvPath"
        }
        Default { Write-Host "Invalid option selected. Displaying results"; $results }
    }
}

# Main script execution
try {
    $specificCommandId = Read-Host -Prompt "Enter a specific Command ID (or press Enter to skip)"
    $timeframeDays = Get-TimeFrame
    $results = Get-CommandResults -specificCommandId $specificCommandId -timeframeDays $timeframeDays
    Display-Results -results $results
}
catch {
    Write-Host "An error occurred: $_"
}
