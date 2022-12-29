<#
Onboarder Script for JumpCloud v1 (RC)

Article: https://community.jumpcloud.com/t5/community-scripts/onboarder-exe-to-assign-users-by-using-a-command-after-agent/m-p/1983/highlight/true#M191

#>

# Set the execution policy to bypass for the current session
Set-ExecutionPolicy Bypass -Scope Process -Force

# Starting Transcript - this is for troubleshooting purposes -> DO NOT USE IN PRODUCTION
# Start-Transcript -OutputDirectory "C:\Windows\Temp\" -Verbose -ErrorAction Continue 

# Importing the secure PSCredential Object
$PSScredentialUser = "MyUserName" 
$SecretFile = "C:\Windows\Temp\EncryptedSecret.txt"
$KeyFile = "C:\Windows\Temp\AES.key"
$key = Get-Content $KeyFile
$MyCredential = New-Object -TypeName System.Management.Automation.PSCredential `
-ArgumentList $PSScredentialUser, (Get-Content $SecretFile | ConvertTo-SecureString -Key $key)

$MyCredential.Password | ConvertFrom-SecureString -key $key
# For debugging purposes only: Write-Host 'decrypted:' $MyCredential.GetNetworkCredential().Password 

# Wait for successful network connection (literally pinging Google's DNS)
do {
    $ping = test-connection -comp 8.8.8.8 -count 1 -Quiet
} until ($ping)

# Installing the NuGet Package Provider
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force 

# Install and import the JumpCloud Powershell Module
Write-Host "Installing the JumpCloud PowerShell Module" -BackgroundColor Black -ForegroundColor Cyan
Install-Module -Name JumpCloud -Force 
Import-Module -Name JumpCloud -Force 

# Connect to your JumpCloud-Tenant by using the API-key from the PSCredential Object
Write-Host "Connecting to your JumpCloud tenant." -BackgroundColor Black -ForegroundColor Cyan
Connect-JCOnline $MyCredential.GetNetworkCredential().Password -Force -Verbose

# Removing the sensitive files instantly after use
Remove-Item -Path $SecretFile -Force
Remove-Item -Path $KeyFile -Force

# Ask for the username of the user that should be assigned to the device
Add-Type -AssemblyName Microsoft.VisualBasic
$Username = [Microsoft.VisualBasic.Interaction]::InputBox('Username:', 'JumpCloud Onboarder', "Enter username here")

# Ask for the EmployeeID as a 'second factor' and validate against the directory
$EmployeeID = [Microsoft.VisualBasic.Interaction]::InputBox('EmployeeID:', 'JumpCloud Onboarder', "Enter EmployeeID here")

#Acquire the EmployeeID from the directory for validation
$EmployeeIDSource = Get-JCUser -username $Username -returnProperties employeeIdentifier

# Validate $EmployeeID against EmployeeIDSource and do if-else
if ($EmployeeID -ne $EmployeeIDSource.employeeIdentifier) {
    # Display a message box that there's no match and stop the execution
    [System.Windows.Forms.MessageBox]::Show("Employee ID does not match.") 
    Exit 1
}
else {
    # Display a message box that the EmployeeID is correct
    [System.Windows.Forms.MessageBox]::Show("Employee ID validated. Click OK to continue. Hang on... ")
    # continue with the script
}

# Acquire SystemID from jcagent.conf 
Write-Host "Acquiring the System ID" -BackgroundColor Black -ForegroundColor Cyan
$agentconf = Get-Content "C:\Program Files\JumpCloud\Plugins\Contrib\jcagent.conf" | ConvertFrom-Json
$agentconf.systemKey

# Add this device to the designated default System Group used for Onboarding
# Write-Host "Adding this system to the Group $DefaultSystemGroup" -BackgroundColor Black -ForegroundColor Cyan
# If desired: Add-JCSystemGroupMember -GroupName $DefaultSystemGroup -SystemID $agentconf.systemKey

# Assign the user to the device without being an Administrator
Write-Host "Assigning $username to this system as a Standard User" -BackgroundColor Black -ForegroundColor Cyan
Add-JCSystemUser -Username $username -SystemID $agentconf.systemKey -Administrator $False


# Turn on MFA on the device
Write-Host "Enabling MFA on the device-level" -BackgroundColor Black -ForegroundColor Cyan
Set-JCSystem -SystemID $agentconf.systemKey -allowMultiFactorAuthentication $true

[System.Windows.Forms.MessageBox]::Show("You have successfully onboarded. Yay! Click OK to continue. The device will reboot and you're able to login with your JumpCloud credentials.")

# Wait for 5 seconds
Start-Sleep 5

# Reboot the device
Write-Host "Rebooting the device" -BackgroundColor Black -ForegroundColor Cyan
Restart-Computer -Force
