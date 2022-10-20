 ## +++ This is a RC version of JC-miniLAPS +++
## Version: RC 1.0
##
## Why is it called 'JC-miniLAPS'?
##   The aim was to create a similar capability to Microsoft's LAPS for Windows-devices
##   while not having the requirements in place. Instead, the OpenDirectory Platform JumpCloud is used.
##   'mini' because it's really lightweight.
##
## Ingredients used:
##   - JumpCloud Tenant
##   - Windows-devices enrolled via JumpCloud Agent (not via self-service, see Caveats below)
##   - This script within a Command (Windows PowerShell) scoped to Windows-devices (tested with 10 Pro and 11 Pro)
## 
## What it does: 
##   By using a Command - which can be scheduled - it will create a random password for a
##   specified Administrator account and write it back to the description field of the respective system.
##   Keep in mind that the password isn't obfuscated in the Admin Console.
##   During execution on each device, the password is handled as a SecureString as much as possible
##   and the password isn't revealed in the in the Command Results.
##   
## Requirements: 
##   This script doesn't require an API- or ConnectKey as it is utilising the SystemContext-API.
##   To work best against a fleet of systems, the Administrator account is unified and most importantly, 
##   in this case, not managed by JumpCloud or any other central IAM solution. 
##   This current version also checks if the specified Administrator exists on a device or not.
##   If not, the account will be created and added to the local group 'Administrators'.
##   Currently, the account will also be enabled, this can be modified of course if not desired.
##
## Caveats: 
##   This script won't work against systems where the SystemContext-API isn't available:
##   Such systems have been enrolled via the JumpCloud UserConsole and they can be identified due the existence of a
##   so-called provisionerID: get-jcsdksystem | where-object {$_.provisionerID}
##   https://github.com/TheJumpCloud/support/issues/320#issuecomment-981730478
## 
## To-Do (under consideration): 
##   - check against existing provisionerID and exit if present
##   - explore other 'distribution channels' for the password
##   i.e.: other fields (tags), Slack, Jira, encrypted file etc.
##   - consider obfuscation and/or encryption methods to further protect the passwords

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

# Referenced Library for RSA
# https://github.com/wing328/PSPetstore/blob/87a2c455a7c62edcfc927ff5bf4955b287ef483b/src/PSOpenAPITools/Private/RSAEncryptionProvider.cs
Add-Type -typedef @"
    using System;
    using System.Collections.Generic;
    using System.IO;
    using System.Net;
    using System.Runtime.InteropServices;
    using System.Security;
    using System.Security.Cryptography;
    using System.Text;

    namespace RSAEncryption
    {
        public class RSAEncryptionProvider
        {
            public static RSACryptoServiceProvider GetRSAProviderFromPemFile(String pemfile, SecureString keyPassPharse = null)
            {
                const String pempubheader = "-----BEGIN PUBLIC KEY-----";
                const String pempubfooter = "-----END PUBLIC KEY-----";
                bool isPrivateKeyFile = true;
                byte[] pemkey = null;

                if (!File.Exists(pemfile)) {
                    throw new Exception("private key file does not exist.");
                }
                string pemstr = File.ReadAllText(pemfile).Trim();

                if (pemstr.StartsWith(pempubheader) && pemstr.EndsWith(pempubfooter)) {
                    isPrivateKeyFile = false;
                }

                if (isPrivateKeyFile) {
                    pemkey = ConvertPrivateKeyToBytes(pemstr, keyPassPharse);
                    if (pemkey == null) {
                        return null;
                    }
                    return DecodeRSAPrivateKey(pemkey);
                }
                return null ;
            }

            static byte[] ConvertPrivateKeyToBytes(String instr, SecureString keyPassPharse = null)
            {
                const String pemprivheader = "-----BEGIN RSA PRIVATE KEY-----";
                const String pemprivfooter = "-----END RSA PRIVATE KEY-----";
                String pemstr = instr.Trim();
                byte[] binkey;

                if (!pemstr.StartsWith(pemprivheader) || !pemstr.EndsWith(pemprivfooter)) {
                    return null;
                }

                StringBuilder sb = new StringBuilder(pemstr);
                sb.Replace(pemprivheader, "");
                sb.Replace(pemprivfooter, "");
                String pvkstr = sb.ToString().Trim();

                try {
                    // if there are no PEM encryption info lines, this is an UNencrypted PEM private key
                    binkey = Convert.FromBase64String(pvkstr);
                    return binkey;
                }
                catch (System.FormatException)
                {
                    StringReader str = new StringReader(pvkstr);

                    //-------- read PEM encryption info. lines and extract salt -----
                    if (!str.ReadLine().StartsWith("Proc-Type: 4,ENCRYPTED"))
                    return null;
                    String saltline = str.ReadLine();
                    if (!saltline.StartsWith("DEK-Info: DES-EDE3-CBC,"))
                    return null;
                    String saltstr = saltline.Substring(saltline.IndexOf(",") + 1).Trim();
                    byte[] salt = new byte[saltstr.Length / 2];
                    for (int i = 0; i < salt.Length; i++)
                    salt[i] = Convert.ToByte(saltstr.Substring(i * 2, 2), 16);
                    if (!(str.ReadLine() == ""))
                    return null;

                    //------ remaining b64 data is encrypted RSA key ----
                    String encryptedstr = str.ReadToEnd();

                    try {
                        //should have b64 encrypted RSA key now
                        binkey = Convert.FromBase64String(encryptedstr);
                    }
                    catch (System.FormatException)
                    { //data is not in base64 fromat
                        return null;
                    }

                    byte[] deskey = GetEncryptedKey(salt, keyPassPharse, 1, 2); // count=1 (for OpenSSL implementation); 2 iterations to get at least 24 bytes
                    if (deskey == null)
                    return null;

                    //------ Decrypt the encrypted 3des-encrypted RSA private key ------
                    byte[] rsakey = DecryptKey(binkey, deskey, salt); //OpenSSL uses salt value in PEM header also as 3DES IV
                    return rsakey;
                }
            }

            public static RSACryptoServiceProvider DecodeRSAPrivateKey(byte[] privkey)
            {
                byte[] MODULUS, E, D, P, Q, DP, DQ, IQ;

                // ---------  Set up stream to decode the asn.1 encoded RSA private key  ------
                MemoryStream mem = new MemoryStream(privkey);
                BinaryReader binr = new BinaryReader(mem); //wrap Memory Stream with BinaryReader for easy reading
                byte bt = 0;
                ushort twobytes = 0;
                int elems = 0;
                try {
                    twobytes = binr.ReadUInt16();
                    if (twobytes == 0x8130) //data read as little endian order (actual data order for Sequence is 30 81)
                    binr.ReadByte(); //advance 1 byte
                    else if (twobytes == 0x8230)
                    binr.ReadInt16(); //advance 2 bytes
                    else
                    return null;

                    twobytes = binr.ReadUInt16();
                    if (twobytes != 0x0102) //version number
                    return null;
                    bt = binr.ReadByte();
                    if (bt != 0x00)
                    return null;

                    //------  all private key components are Integer sequences ----
                    elems = GetIntegerSize(binr);
                    MODULUS = binr.ReadBytes(elems);

                    elems = GetIntegerSize(binr);
                    E = binr.ReadBytes(elems);

                    elems = GetIntegerSize(binr);
                    D = binr.ReadBytes(elems);

                    elems = GetIntegerSize(binr);
                    P = binr.ReadBytes(elems);

                    elems = GetIntegerSize(binr);
                    Q = binr.ReadBytes(elems);

                    elems = GetIntegerSize(binr);
                    DP = binr.ReadBytes(elems);

                    elems = GetIntegerSize(binr);
                    DQ = binr.ReadBytes(elems);

                    elems = GetIntegerSize(binr);
                    IQ = binr.ReadBytes(elems);

                    // ------- create RSACryptoServiceProvider instance and initialize with public key -----
                    RSACryptoServiceProvider RSA = new RSACryptoServiceProvider();
                    RSAParameters RSAparams = new RSAParameters();
                    RSAparams.Modulus = MODULUS;
                    RSAparams.Exponent = E;
                    RSAparams.D = D;
                    RSAparams.P = P;
                    RSAparams.Q = Q;
                    RSAparams.DP = DP;
                    RSAparams.DQ = DQ;
                    RSAparams.InverseQ = IQ;
                    RSA.ImportParameters(RSAparams);
                    return RSA;
                }
                catch (Exception)
                {
                    return null;
                }
                finally { binr.Close(); }
            }

            private static int GetIntegerSize(BinaryReader binr)
            {
                byte bt = 0;
                byte lowbyte = 0x00;
                byte highbyte = 0x00;
                int count = 0;
                bt = binr.ReadByte();
                if (bt != 0x02)     //expect integer
                return 0;
                bt = binr.ReadByte();

                if (bt == 0x81)
                count = binr.ReadByte(); // data size in next byte
                else
                if (bt == 0x82) {
                    highbyte = binr.ReadByte(); // data size in next 2 bytes
                    lowbyte = binr.ReadByte();
                    byte[] modint = { lowbyte, highbyte, 0x00, 0x00 };
                    count = BitConverter.ToInt32(modint, 0);
                }
                else {
                    count = bt; // we already have the data size
                }
                while (binr.ReadByte() == 0x00) {
                    //remove high order zeros in data
                    count -= 1;
                }
                binr.BaseStream.Seek(-1, SeekOrigin.Current);
                //last ReadByte wasn't a removed zero, so back up a byte
                return count;
            }

            static byte[] GetEncryptedKey(byte[] salt, SecureString secpswd, int count, int miter)
            {
                IntPtr unmanagedPswd = IntPtr.Zero;
                int HASHLENGTH = 16;    //MD5 bytes
                byte[] keymaterial = new byte[HASHLENGTH * miter];     //to store contatenated Mi hashed results

                byte[] psbytes = new byte[secpswd.Length];
                unmanagedPswd = Marshal.SecureStringToGlobalAllocAnsi(secpswd);
                Marshal.Copy(unmanagedPswd, psbytes, 0, psbytes.Length);
                Marshal.ZeroFreeGlobalAllocAnsi(unmanagedPswd);

                // --- contatenate salt and pswd bytes into fixed data array ---
                byte[] data00 = new byte[psbytes.Length + salt.Length];
                Array.Copy(psbytes, data00, psbytes.Length);      //copy the pswd bytes
                Array.Copy(salt, 0, data00, psbytes.Length, salt.Length); //concatenate the salt bytes

                // ---- do multi-hashing and contatenate results  D1, D2 ...  into keymaterial bytes ----
                MD5 md5 = new MD5CryptoServiceProvider();
                byte[] result = null;
                byte[] hashtarget = new byte[HASHLENGTH + data00.Length];   //fixed length initial hashtarget

                for (int j = 0; j < miter; j++)
                {
                    // ----  Now hash consecutively for count times ------
                    if (j == 0)
                        result = data00;    //initialize
                    else
                    {
                        Array.Copy(result, hashtarget, result.Length);
                        Array.Copy(data00, 0, hashtarget, result.Length, data00.Length);
                        result = hashtarget;
                    }

                    for (int i = 0; i < count; i++)
                        result = md5.ComputeHash(result);
                    Array.Copy(result, 0, keymaterial, j * HASHLENGTH, result.Length);  //contatenate to keymaterial
                }
                byte[] deskey = new byte[24];
                Array.Copy(keymaterial, deskey, deskey.Length);

                Array.Clear(psbytes, 0, psbytes.Length);
                Array.Clear(data00, 0, data00.Length);
                Array.Clear(result, 0, result.Length);
                Array.Clear(hashtarget, 0, hashtarget.Length);
                Array.Clear(keymaterial, 0, keymaterial.Length);
                return deskey;
            }

            static byte[] DecryptKey(byte[] cipherData, byte[] desKey, byte[] IV)
            {
                MemoryStream memst = new MemoryStream();
                TripleDES alg = TripleDES.Create();
                alg.Key = desKey;
                alg.IV = IV;
                try
                {
                    CryptoStream cs = new CryptoStream(memst, alg.CreateDecryptor(), CryptoStreamMode.Write);
                    cs.Write(cipherData, 0, cipherData.Length);
                    cs.Close();
                }
                catch (Exception){
                    return null;
                }
                byte[] decryptedData = memst.ToArray();
                return decryptedData;
            }
        }
    }

"@

# Format and create the signature request
$now = (Get-Date -Date ((Get-Date).ToUniversalTime()) -UFormat "+%a, %d %h %Y %H:%M:%S GMT")
# create the string to sign from the request-line and the date
$signstr = "PUT /api/systems/$systemKey HTTP/1.1`ndate: $now"
$enc = [system.Text.Encoding]::UTF8
$data = $enc.GetBytes($signstr)
# Create a New SHA256 Crypto Provider
$sha = New-Object System.Security.Cryptography.SHA256CryptoServiceProvider
# Now hash and display results
$result = $sha.ComputeHash($data)
# Private Key Path
$PrivateKeyFilePath = 'C:\Program Files\JumpCloud\Plugins\Contrib\client.key'
$hashAlgo = [System.Security.Cryptography.HashAlgorithmName]::SHA256
[System.Security.Cryptography.RSA]$rsa = [RSAEncryption.RSAEncryptionProvider]::GetRSAProviderFromPemFile($PrivateKeyFilePath)
# Format the Signature
$signedBytes = $rsa.SignHash($result, $hashAlgo, [System.Security.Cryptography.RSASignaturePadding]::Pkcs1)
$signature = [Convert]::ToBase64String($signedBytes)


# Invoke the WebRequest via API to writhe the password into the description of the device
$headers = @{
    Accept        = "application/json"
    Date          = "$now"
    Authorization = "Signature keyId=`"system/$($systemKey)`",headers=`"request-line date`",algorithm=`"rsa-sha256`",signature=`"$($signature)`""
}
$Form = @{
    'description' = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($LAPS_password));
} | ConvertTo-Json
Invoke-RestMethod -Method PUT -Uri "https://console.jumpcloud.com/api/systems/$systemKey" -ContentType 'application/json' -Headers $headers -Body $Form | Out-Null