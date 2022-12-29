<#
API-Encrypter to generate a secret- and key-file
#>

# Creating AES key with random data and export to file
$KeyFile = "AES.key"
$Key = New-Object Byte[] 32   
[Security.Cryptography.RNGCryptoServiceProvider]::Create().GetBytes($Key)
$Key | out-file $KeyFile

# Creating SecureString object
$SecretFile = "EncryptedSecret.txt"
$Key = Get-Content $KeyFile
$Secret = "<YOUR_API_KEY_GOES_HERE>" | ConvertTo-SecureString -AsPlainText -Force
$Secret | ConvertFrom-SecureString -key $Key | Out-File $SecretFile
