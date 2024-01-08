# Define the presigned URL of the .ppkg file
$ppkgUrl = "https://custom-pkg.s3.ap-southeast-1.amazonaws.com/jumpcloud_ppkg.ppkg?AWSAccessKeyId=AKIA4FRBAMIMEZE3KTUH&Expires=1712451171&Signature=grVM6LUJc4GYTj3KvJn7WyF4Bt4%3D"

# Define the local path to save the .ppkg file
$localPpkgPath = "C:\Windows\Temp\JumpCloud.ppkg"

# Expected SHA256 hash of the .ppkg file
$expectedHash = "ieQp9Aa5jumX/32o1BS0s1TQE9XMCSyDASrhBjWPeXk="

# Download the .ppkg file
Invoke-WebRequest -Uri $ppkgUrl -OutFile $localPpkgPath

# Calculate the SHA256 hash of the downloaded file
# $calculatedHash = (Get-FileHash -Path $localPpkgPath -Algorithm SHA256).Hash

# Compare the expected hash with the calculated hash
# if ($calculatedHash -eq $expectedHash) {
    # Hashes match, proceed with installation
    Install-ProvisioningPackage -Path $localPpkgPath -QuietInstall -ForceInstall -Verbose
    Write-Host "Installation successful."
# }
# else {
    # Hashes do not match, handle the error
#    Write-Host "Hash mismatch. The file may be corrupted or tampered with."
# }

# Optionally, remove the downloaded file
Remove-Item -Path $localPpkgPath
