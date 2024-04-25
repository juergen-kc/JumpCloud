 <#
.SYNOPSIS

    JumpCloud AD Integration Script to prepare the environment on your Domain Controller.
    This script sets up users and groups in Active Directory and optionally creates a self-signed certificate for LDAP over SSL (LDAPS).

.DESCRIPTION
    The script performs the following functions:
    - Imports the Active Directory module.
    - Creates a security group if it does not exist.
    - Creates specified users if they do not exist.
    - Optionally generates a self-signed certificate for LDAPS.
    - Applies specified permissions to users.

.PARAMETER DistinguishedName
    The distinguished name of the target organizational unit, i.e. 'CN=Users,DC=mydomain,DC=com'.

.PARAMETER GroupName
    The name of the group to create, with 'JumpCloud' as the default.

.PARAMETER GroupDescription
    A description for the group to be created.

.PARAMETER UserPrincipalNameSuffix
    The suffix for the UserPrincipalName (e.g., '@mydomain.com').

.PARAMETER ServiceAccountPassword
    The password for the service accounts, which will be converted to a secure string.

.PARAMETER CreateCert
    Indicates whether to create a self-signed certificate for LDAPS. Accepts 'Y' or 'N'.

.EXAMPLE
    .\ScriptName.ps1 -DistinguishedName "CN=Users,DC=mydomain,DC=com" -GroupName "JumpCloud" -GroupDescription "Description Here" -UserPrincipalNameSuffix "@mydomain.com" -ServiceAccountPassword "YourSecurePassword" -CreateCert "Y"
#>

# Load Active Directory module
Import-Module ActiveDirectory

# Collect input from user for required parameters and optional parameters with default values if not provided by the user
$DistinguishedName = Read-Host "Enter the Distinguished Name (DN) of the target OU, i.e.: 'CN=Users,DC=mydomain,DC=com'"
$GroupName = Read-Host "Enter the group name (default: 'JumpCloud')"
if ([string]::IsNullOrWhiteSpace($GroupName)) {
    $GroupName = "JumpCloud"
}
$GroupDescription = Read-Host "Enter the group description"
$UserPrincipalNameSuffix = Read-Host "Enter the suffix for UserPrincipalName (e.g., '@mydomain.com')"
$ServiceAccountPassword = Read-Host "Enter the password for the service accounts" -AsSecureString
$CreateCert = Read-Host "Create a self-signed certificate for LDAPS? (Y/N)"

# Function to create AD group if it does not exist
function Create-ADGroup {
    param(
        [string]$Name,
        [string]$Description,
        [string]$OU
    )
    $existingGroup = Get-ADGroup -Filter "Name -eq '$Name'" -ErrorAction SilentlyContinue
    if (-not $existingGroup) {
        New-ADGroup -Name $Name -GroupScope Global -GroupCategory Security -Path $OU -Description $Description
        Write-Output "Security group '$Name' created successfully." 
    } else {
        Write-Output "Security group '$Name' already exists. Skipping creation."
    }
}

# Function to create AD users if they do not exist
function Create-ADUsers {
    param(
        [string]$UPNSuffix,
        [string]$OU,
        [securestring]$Password
    )
    $users = @(
        @{SamAccountName='jcsync'; UserPrincipalName="jcsync$UPNSuffix"; Name='JC Sync User'; Path=$OU},
        @{SamAccountName='jcimport'; UserPrincipalName="jcimport$UPNSuffix"; Name='JC Import User'; Path=$OU}
    )
    foreach ($user in $users) {
        if (-not (Get-ADUser -Filter "SamAccountName -eq '$($user.SamAccountName)'")) {
            try {
                New-ADUser @user -AccountPassword $Password -ChangePasswordAtLogon $false -PasswordNeverExpires $true -Enabled $true -ErrorAction Stop
                Write-Output "User $($user.Name) created successfully."
            } catch {
                Write-Error "Failed to create user $($user.Name): $($_.Exception.Message)"
            }
        } else {
            Write-Output "User $($user.Name) already exists. Skipping creation."
        }
    }
}

# Function to create a self-signed certificate for LDAPS (optional)
function Create-SelfSignedCertificate {
    if ($CreateCert -eq 'Y') {
        try {
            # Get the DNS name of the computer
            $computerDNSName = [System.Net.Dns]::GetHostEntry([System.Net.Dns]::GetHostName()).HostName
            $certDNSName = $computerDNSName, $env:COMPUTERNAME
            $cert = New-SelfSignedCertificate -DnsName $certDNSName -CertStoreLocation cert:\LocalMachine\My
            $tempCertFile = [System.IO.Path]::GetTempFileName()
            Export-Certificate -Cert $cert -FilePath $tempCertFile
            $rootStore = "cert:\LocalMachine\Root"
            Import-Certificate -FilePath $tempCertFile -CertStoreLocation $rootStore
            Remove-Item $tempCertFile
            Write-Output "Self-signed certificate for LDAPS created successfully. Waiting for a minute to apply the changes..."
            Start-Sleep -Seconds 60
            Write-Output "Done."
        } catch {
            Write-Error "Failed to create self-signed certificate: $($_.Exception.Message)"
        }
    }
}

# Main execution
Create-ADGroup -Name $GroupName -Description $GroupDescription -OU $DistinguishedName
Create-ADUsers -UPNSuffix $UserPrincipalNameSuffix -OU $DistinguishedName -Password $ServiceAccountPassword
Create-SelfSignedCertificate

Write-Output "Script execution completed. Please validate the Users, Group, Permissions and LDAPS (optional)."