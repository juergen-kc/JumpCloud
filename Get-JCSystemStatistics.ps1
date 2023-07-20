# Import the JumpCloud module for PowerShell
# Import-Module JumpCloud

# Get all systems
$systems = Get-JCSystem

# Initialize counters
$onlineCount = 0
$offlineCount = 0
$inactiveCount = 0
$inactiveSystems = @()

# Initialize hashtables for unique public IPs, agentVersions, archs, oses, and systemTimezones
$uniqueIPs = @{}
$agentVersions = @{}
$archs = @{}
$oses = @{}
$systemTimezones = @{}

# Iterate over each system
foreach ($system in $systems) {
    # Count online and offline systems
    if ($system.active) {
        $onlineCount++
    } else {
        $offlineCount++
    }

    # Get systems that haven't contacted for more than 7 days
    $lastContact = [DateTime]::Parse($system.lastContact)
    if ((Get-Date).AddDays(-7) -gt $lastContact) {
        $inactiveCount++
        $inactiveSystems += $system
    }

    # Count unique public IPs and do a simple ping test
    if ($null -ne $system.remoteIP) {
        if (-not $uniqueIPs.ContainsKey($system.remoteIP)) {
            $reachable = if (Test-Connection -ComputerName $system.remoteIP -Count 1 -Quiet) { 'Yes' } else { 'No' }
            $uniqueIPs[$system.remoteIP] = @{
                'Count' = 1
                'Reachable' = $reachable
            }
        } else {
            $uniqueIPs[$system.remoteIP]['Count']++
        }
    }

    # Count systems by agent version
    if ($null -ne $system.agentVersion) {
        if (-not $agentVersions.ContainsKey($system.agentVersion)) {
            $agentVersions[$system.agentVersion] = @{ 'Online' = 0; 'Offline' = 0 }
        }

        if ($system.active) {
            $agentVersions[$system.agentVersion]['Online']++
        } else {
            $agentVersions[$system.agentVersion]['Offline']++
        }
    }

    # Count systems by arch
    if ($null -ne $system.arch) {
        if (-not $archs.ContainsKey($system.arch)) {
            $archs[$system.arch] = @{ 'Online' = 0; 'Offline' = 0 }
        }

        if ($system.active) {
            $archs[$system.arch]['Online']++
        } else {
            $archs[$system.arch]['Offline']++
        }
    }

    # Count systems by os
    if ($system.active) {
        if (-not $oses.ContainsKey($system.os)) {
            $oses[$system.os] = @{ 'Online' = 0; 'Offline' = 0 }
        }
        $oses[$system.os]['Online']++
    } else {
        if (-not $oses.ContainsKey($system.os)) {
            $oses[$system.os] = @{ 'Online' = 0; 'Offline' = 0 }
        }
        $oses[$system.os]['Offline']++
    }

    # Count systems by system timezone
    if ($system.active) {
        if (-not $systemTimezones.ContainsKey($system.systemTimezone)) {
            $systemTimezones[$system.systemTimezone] = @{ 'Online' = 0; 'Offline' = 0 }
        }
        $systemTimezones[$system.systemTimezone]['Online']++
    } else {
        if (-not $systemTimezones.ContainsKey($system.systemTimezone)) {
            $systemTimezones[$system.systemTimezone] = @{ 'Online' = 0; 'Offline' = 0 }
        }
        $systemTimezones[$system.systemTimezone]['Offline']++
    }
}

# Display the results
Write-Host "`nTotal number of systems: $($systems.Count)"
Write-Host "Number of online systems: $onlineCount" -ForegroundColor Green
Write-Host "Number of offline systems: $offlineCount" -ForegroundColor Red
Write-Host "`nSystems that haven't contacted for more than 7 days:"
$inactiveSystems | Select-Object lastContact, id, osFamily, version | Sort-Object lastContact | Format-Table -AutoSize
Write-Host "`nUnique public IPs and their system counts:"
foreach ($ip in $uniqueIPs.Keys) {
    Write-Host "$ip : Total Count = $($uniqueIPs[$ip].Count), Reachable = $($uniqueIPs[$ip].Reachable)"
}

# Convert hashtables to custom objects and format them as tables
Write-Host "`nOnline and offline statistics for agentVersion:"
$agentVersions.GetEnumerator() | ForEach-Object { New-Object PSObject -Property @{AgentVersion=$_.Key; Online=$_.Value.Online; Offline=$_.Value.Offline} } | Format-Table -AutoSize

Write-Host "`nOnline and offline statistics for arch:"
$archs.GetEnumerator() | ForEach-Object { New-Object PSObject -Property @{Arch=$_.Key; Online=$_.Value.Online; Offline=$_.Value.Offline} } | Format-Table -AutoSize

Write-Host "`nOnline and offline statistics for os:"
$oses.GetEnumerator() | ForEach-Object { New-Object PSObject -Property @{OS=$_.Key; Online=$_.Value.Online; Offline=$_.Value.Offline} } | Format-Table -AutoSize

Write-Host "`nOnline and offline statistics for systemTimezone:"
$systemTimezones.GetEnumerator() | ForEach-Object { New-Object PSObject -Property @{SystemTimezone=$_.Key; Online=$_.Value.Online; Offline=$_.Value.Offline} } | Format-Table -AutoSize
