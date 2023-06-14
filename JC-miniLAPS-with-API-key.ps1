### >>> Please specify your administrative account name here: <<<
$LocalAdministrator = 'Administrator'
### >>> Please specify the desired length of the password here: $lenght = N  [default: 12]<<<
function Update-Password ($length = 12) 
{
    If ($length -lt 4) { $length = 4 }   #Password must be at least 4 characters long in order to satisfy complexity requirements.

    #Use the .NET crypto random number generator, not the weaker System.Random class with Get-Random:
    $RngProv = [System.Security.Cryptography.RNGCryptoServiceProvider]::Create()
    [byte[]] $onebyte = @(255)
    [Int32] $x = 0

    Do {
        [byte[]] $password = @() 
        
        $hasupper =     $false    #Has uppercase letter character flag.
        $haslower =     $false    #Has lowercase letter character flag.
        $hasnumber =    $false    #Has number character flag.
        $hasnonalpha =  $false    #Has non-alphanumeric character flag.
        $isstrong =     $true    #Assume password is not complex until tested otherwise.
        
        For ($i = $length; $i -gt 0; $i--)
        {                                                         
            While ($true)
            {   
                #Generate a random US-ASCII code point number.
                $RngProv.GetNonZeroBytes( $onebyte ) 
                [Int32] $x = $onebyte[0]                  
                if ($x -ge 32 -and $x -le 126){ break }   
            }
            
            # Even though it reduces randomness, eliminate problem characters to preserve sanity while debugging.
            # If you're worried, increase the length of the password or comment out the undesired line(s):
            If ($x -eq 32) { $x++ }    #Eliminates the space character; causes problems for other scripts/tools.
            If ($x -eq 34) { $x-- }    #Eliminates double-quote; causes problems for other scripts/tools.
            If ($x -eq 39) { $x-- }    #Eliminates single-quote; causes problems for other scripts/tools.
            If ($x -eq 47) { $x-- }    #Eliminates the forward slash; causes problems for net.exe.
            If ($x -eq 96) { $x-- }    #Eliminates the backtick; causes problems for PowerShell.
            If ($x -eq 48) { $x++ }    #Eliminates zero; causes problems for humans who see capital O.
            If ($x -eq 79) { $x++ }    #Eliminates capital O; causes problems for humans who see zero. 
            
            $password += [System.BitConverter]::GetBytes( [System.Char] $x ) 

            If ($x -ge 65 -And $x -le 90)  { $hasupper = $true }   #Non-USA users may wish to customize the code point numbers by hand,
            If ($x -ge 97 -And $x -le 122) { $haslower = $true }   #which is why we don't use functions like IsLower() or IsUpper() here.
            If ($x -ge 48 -And $x -le 57)  { $hasnumber = $true } 
            If (($x -ge 32 -And $x -le 47) -Or ($x -ge 58 -And $x -le 64) -Or ($x -ge 91 -And $x -le 96) -Or ($x -ge 123 -And $x -le 126)) { $hasnonalpha = $true } 
            If ($hasupper -And $haslower -And $hasnumber -And $hasnonalpha) { $isstrong = $true } 
        } 
    } While ($isstrong -eq $false)

    #$RngProv.Dispose() #Not compatible with PowerShell 2.0.

    ([System.Text.Encoding]::Unicode).GetString($password) #Make sure output is encoded as UTF16LE. 
}


# +++ Section 01: Check if specified Administrator exists and if a member of Administrators +++
if (Get-LocalUser | Where-Object -Property Name -EQ $LocalAdministrator) { 
    Write-Host $LocalAdministrator 'exists, continue...'
} Else {
New-LocalUser -Name $LocalAdministrator -FullName "Local Administrator" -NoPassword 
Write-Host $LocalAdministrator 'created.'
}

if (Get-LocalGroupMember -Group 'Administrators' -Member $LocalAdministrator) {
    Write-Host $LocalAdministrator 'is already a member of the local group Administrators'
}
else {
    Add-LocalGroupMember -Group 'Administrators' -Member $LocalAdministrator
    Write-Host $LocalAdministrator 'added to the local group Administrators'
}


# +++ Section 02: Generate a random password +++ 
# Sourced from: 
# https://www.sans.org/cyber-security-courses/securing-windows-with-powershell/
# https://blueteampowershell.com

# +++ Section 03: Change the administrator password +++
$LAPS_password = Update-Password | ConvertTo-SecureString -AsPlainText -Force 

####################################################################################
# Returns true if password reset accepted, false if there is an error.
# Sourced from: 
# https://www.sans.org/cyber-security-courses/securing-windows-with-powershell/
# https://blueteampowershell.com
####################################################################################

# +++ Section 04: Set the password and make sure the account is enabled (if desired) +++
# sourced from: https://github.com/TheJumpCloud/support/blob/master/scripts/api/system_context/windows_examples/system_put_self.ps1
Set-LocalUser -Name $LocalAdministrator -Password $LAPS_password
Get-LocalUser -Name $LocalAdministrator | Enable-LocalUser #optional

# +++ Section 05: Acquire SystemKey to be used for the SystemContextAPI +++
$config = get-content 'C:\Program Files\JumpCloud\Plugins\Contrib\jcagent.conf'
$regex = 'systemKey\":\"(\w+)\"'
$systemKey = [regex]::Match($config, $regex).Groups[1].Value

# Replace "YOUR_API_KEY" with your actual JumpCloud API key
$apiKey = "<YOUR_API_KEY>"
$now = (Get-Date -Date ((Get-Date).ToUniversalTime()) -UFormat "+%a, %d %h %Y %H:%M:%S GMT")

# Set up headers for the request
$headers = @{
    Date          = "$now"
    'x-org-id'    = ""
    'x-api-key'   = $apiKey
    'content-type'= "application/json"
}

# Convert password to string and create JSON body
$Form = @{
    'description' = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($LAPS_password));
} | ConvertTo-Json

# Invoke the WebRequest via API to write the password into the description of the device
Invoke-RestMethod -Method PUT -Uri "https://console.jumpcloud.com/api/systems/$systemKey" -ContentType 'application/json' -Headers $headers -Body $Form | Out-Null