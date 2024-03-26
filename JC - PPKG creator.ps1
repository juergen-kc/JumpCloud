<#
.DESCRIPTION
This script downloads the JumpCloud MDM configuration files and customizes them for bulk deployment into JC-MDM. 
The script will:
- prompt the user for the JumpCloud API key
- prompt the user for the desired prefix for the hostname
- prompt the user for the desired username and password to be added to the <Users> section of the customizations.xml file
- generate a new GUID for the package ID
- construct the customizations.xml file with the <Users> section
- query the registry for the path to the ICD.exe and check if it exists
- copy the Desktop Store File to the Common Store File to work around a bug in ICD.exe
- create the PPKG using the ICD.exe and the customizations.xml file
- restore the Store Files back to the original state

.COMPONENT
JumpCloud API Key
Windows 10 ADK

.NOTES
File Name      : JC - PPKG creator.ps1
Author         : Juergen Klaassen
Prerequisite   : Windows 10 ADK installed
Copyright 2024

.EXAMPLE
.\JC - PPKG creator.ps1.ps1

.FUNCTIONALITY
JC-MDM Bulk Deployment via customised PPKG

.INPUTS
API Key, Prefix, Username, Password

.OUTPUTS
PPKG file

#>

# Variables to configure if desired:
$outfile = "config.zip"

# Prompt for the API key
$jc_api_key = Read-Host "Enter the JumpCloud API key"

# Prompt for the prefix of the Hostname
$prefix = Read-Host "Enter the desired prefix for the hostname (prefix+serial)"

# Prompt the user for the desired username and password
$UserName = Read-Host "Enter the desired username"
$Password = Read-Host "Enter the desired password" -AsSecureString
# Confirm the password
$PasswordConfirm = Read-Host "Confirm the password" -AsSecureString

# Convert secure strings to plain text
$Ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password)
$PlainTextPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($Ptr)
[System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($Ptr)

$PtrConfirm = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($PasswordConfirm)
$PlainTextPasswordConfirm = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($PtrConfirm)
[System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($PtrConfirm)

# Compare the plain text passwords
if ($PlainTextPassword -ne $PlainTextPasswordConfirm) {
    Write-Error "Passwords do not match."
    return
} 

# If matching, proceed / no exit yet
Write-Output "Passwords match."

# Download and extract JumpCloud Configuration Files (zipped)
Invoke-RestMethod -Uri "https://console.jumpcloud.com/api/v2/microsoft-mdm/configuration-files" `
-Method Post `
-Headers @{
    "content-type" = "application/json"
    "x-api-key" = $jc_api_key
} `
-OutFile $outfile

# Extract the downloaded zip file to a folder named "config"
Expand-Archive -LiteralPath $outfile -DestinationPath "config" -Force

# Generate a new GUID for package ID
$packageID = (New-Guid).Guid

# Query the admin for details from the downloaded XML
[xml]$downloadedXml = Get-Content -Path "config\customizations.xml"
$upn = $downloadedXml.WindowsCustomizations.Settings.Customizations.Common.Workplace.Enrollments.UPN.UPN
$serviceFullUrl = $downloadedXml.WindowsCustomizations.Settings.Customizations.Common.Workplace.Enrollments.UPN.DiscoveryServiceFullUrl -replace 'Discovery', ''
$secret = $downloadedXml.WindowsCustomizations.Settings.Customizations.Common.Workplace.Enrollments.UPN.Secret

# Construct the customizations.xml file with <Users> section
$customizationsXmlPath = "$(Get-Location)\config\customizations_new.xml"
$customizationsContent = @"
<?xml version="1.0" encoding="utf-8"?>
<WindowsCustomizations>
    <PackageConfig xmlns="urn:schemas-Microsoft-com:Windows-ICD-Package-Config.v1.0">
        <ID>{$packageID}</ID>
        <Name>JC MDM Enrolment</Name>
        <Version>1.0</Version>
        <OwnerType>ITAdmin</OwnerType>
        <Rank>0</Rank>
    </PackageConfig>
    <Settings xmlns="urn:schemas-microsoft-com:windows-provisioning">
        <Customizations>
            <Common>
                <Accounts>
                    <Users>
                        <User UserName="$UserName" Password="$Password">
                            <UserGroup>Administrators</UserGroup>
                        </User>
                    </Users>
                </Accounts>
                <DevDetail>
                    <DNSComputerName>$prefix-%SERIAL%</DNSComputerName>
                </DevDetail>
                <OOBE>
                    <Desktop>
                        <HideOobe>True</HideOobe>
                    </Desktop>
                </OOBE>
                <Workplace>
                    <Enrollments>
                        <UPN UPN="$upn" Name="$upn">
                            <AuthPolicy>OnPremise</AuthPolicy>
                            <DiscoveryServiceFullUrl>$serviceFullUrl/EnrollmentServer/Discovery.svc</DiscoveryServiceFullUrl>
                            <Secret>$secret</Secret>
                        </UPN>
                    </Enrollments>
                </Workplace>
                <ProvisioningCommands>
                    <PrimaryContext>
                        <Command>
                            <CommandConfig Name="get_vc_redist">
                                <CommandLine>cmd.exe /c curl https://aka.ms/vs/17/release/vc_redist.x64.exe -fsLo %TEMP%\vc_redist.x64.exe &amp;&amp; cmd.exe /c %TEMP%\vc_redist.x64.exe /install /quiet /norestart</CommandLine>
                            </CommandConfig>
                        </Command>
                    </PrimaryContext>
                </ProvisioningCommands>
            </Common>
        </Customizations>
    </Settings>
</WindowsCustomizations>
"@
Out-File -FilePath $customizationsXmlPath -Encoding UTF8 -InputObject $customizationsContent -Force


# Find the ADK and ICD.exe path
if (Test-Path "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows Kits\Installed Roots") {
    $kitsRoot = Get-ItemPropertyValue -Path "HKLM:\Software\WOW6432Node\Microsoft\Windows Kits\Installed Roots" -Name KitsRoot10
} elseif (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows Kits\Installed Roots") {
    $kitsRoot = Get-ItemPropertyValue -Path "HKLM:\Software\Microsoft\Windows Kits\Installed Roots" -Name KitsRoot10
} else {
    Write-Error "ADK is not installed."
    return
}
$icdPath = "$kitsRoot\Assessment and Deployment Kit\Imaging and Configuration Designer\x86"
$icdExe = "$kitsRoot\Assessment and Deployment Kit\Imaging and Configuration Designer\x86\ICD.exe"
if (-not (Test-Path $icdExe)) {
    Write-Error "ICD.exe not found."
    return
}

# ICD.exe has currently a bug and therefore we need to shuffle the Store Files around and revert post execution 
# Backup Existing Common Store File
ren $icdPath\Microsoft-Common-Provisioning.dat Microsoft-Common-Provisioning.bak

# Copy The Desktop Store File to Common Store
cp $icdPath\Microsoft-Desktop-Provisioning.dat $icdPath\Microsoft-Common-Provisioning.dat

# Create the PPKG
$ppkgPath = "$(Get-Location)\JC-MDM-Enrolment.ppkg"
& "$icdExe" /Build-ProvisioningPackage /CustomizationXML:$customizationsXmlPath /PackagePath:$ppkgPath 

# Restore the Store Files back to the original state
del $icdPath\Microsoft-Common-Provisioning.dat
ren $icdPath\Microsoft-Common-Provisioning.bak Microsoft-Common-Provisioning.dat 