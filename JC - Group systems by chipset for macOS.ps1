# Create Groups for Macs based on chipset

# Edit the variables below, you shouldn't need to edit any other lines.
$jcApiKey = '<YOUR API KEY>'
$groupNames = @{
    intelGroupName = 'Mac - Intel Systems'
    m1GroupName    = 'Mac - M1 Systems'
}

# Check if JumpCloud module is installed, if not, install it and connect.
try {
    if (-not (Get-Module -ListAvailable JumpCloud)) {
        Install-Module -Name JumpCloud -Scope CurrentUser -Force
    }
    Import-Module -Name JumpCloud
    Connect-JCOnline -JumpCloudApiKey $jcApiKey
} catch {
    Write-Error "Something went wrong connecting to JumpCloud! $($_.Exception.Message)" -ErrorAction Stop
}

# Create the groups if they don't exist.
try {
    Write-Host "`nCreating JumpCloud System Groups if needed..." -ForegroundColor Green
    foreach ($group in $groupNames.GetEnumerator()) {
        if (-not (Get-JCGroup -Type system -Name $group.Value -ErrorAction SilentlyContinue)) {
            New-JCSystemGroup -GroupName $group.Value | Out-Null
            Write-Host $group.Value 'System Group created in JumpCloud.'
        } else {
            Write-Host $group.Value 'System Group already exists in JumpCloud.'
        }
    }
} catch {
    Write-Error "Something went wrong when checking for groups! $($_.Exception.Message)" -ErrorAction Stop
}

# Populate the groups with the relevant systems.
try {
    Write-Host "`nPopulating JumpCloud System Groups with relevant systems..." -ForegroundColor Green
    $macSystems = Get-JCSystem -os 'Mac OS X' -returnProperties os,displayName,arch | Sort-Object arch
    $m1GroupMembers = Get-JCSystemGroupMember -GroupName $groupNames.m1GroupName
    $intelGroupMembers = Get-JCSystemGroupMember -GroupName $groupNames.intelGroupName

    foreach ($system in $macSystems) {
        if (($system.arch -eq 'x86_64') -and ($system._id -notin $intelGroupMembers.SystemID)) {
            Add-JCSystemGroupMember -SystemID $system._id -GroupName $groupNames.intelGroupName
        }
        if (($system.arch -eq 'arm64') -and ($system._id -notin $m1GroupMembers.SystemID)) {
            Add-JCSystemGroupMember -SystemID $system._id -GroupName $groupNames.m1GroupName
        }
    }
} catch {
    Write-Error "Something went wrong when trying to add our systems to the groups! $($_.Exception.Message)" -ErrorAction Stop
}
