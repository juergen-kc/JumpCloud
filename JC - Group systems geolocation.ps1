# Source: https://community.jumpcloud.com/t5/community-scripts/add-the-systems-to-a-system-group-depends-on-where-they-are-geo/td-p/1733
# a function to query the geo info from an IP supplied
function Get-IPGeolocation {
    Param
    (
      [string]$IPAddress
    )
   
    $request = Invoke-RestMethod -Method Get -Uri "http://ip-api.com/json/$IPAddress"
   
    [PSCustomObject]@{
      IP      = $request.query
      City    = $request.city
      Country = $request.country
      Isp     = $request.isp
    }
  }

# Setting the dates - depends on how often you run this
[int32]$backTracingDays = 1 # Recommended schedule
$anchorDate = (Get-Date -Hour 23 -Minute 59 -Second 59).AddDays(-$backTracingDays)

# Getting the system only created after the backtracingdays
$jcsystemInfo = Get-JCSystem | where {$_.created -gt $anchorDate}

# Adding the systems to these geo related groups
if ($null -ne $jcsystemInfo){
    foreach ($system in $jcsystemInfo){
        $geolocation = Get-IPGeolocation -IPAddress $system.remoteIP
    
        $targetGroup = $geolocation.Country.Replace(' ','') + "_" + $system.osFamily
        
        # Adding the system to the target group
        $testGroup = Get-JCGroup -Type System -Name $targetGroup -ErrorAction SilentlyContinue
        $testMember = Get-JCSystemGroupMember -GroupName $targetGroup | where system -eq $system.displayName
    
        if ($null -eq $testGroup){
            $newGroup = New-JCSystemGroup -GroupName $targetGroup
            Add-JCSystemGroupMember -GroupID $newGroup.id -SystemID $system._id 
            Write-Output "$($system.displayname) has been added to $($newgroup.name) system group! `n "
    
        }
        elseif ($null -ne $testGroup -and $null -eq $testMember) {
            Add-JCSystemGroupMember -GroupID $testGroup.id -SystemID $system._id
            Write-Output "$($system.displayname) has been added to $($testGroup.name) system group! `n "
        }
        else {
            Write-Output "$($system.displayname) already exists in $($testGroup.name) system group! `n "
        }
    }
}
else {
    Write-Output "Phew! No systems has been create for the past $backTracingDays days, take a day off!"
}