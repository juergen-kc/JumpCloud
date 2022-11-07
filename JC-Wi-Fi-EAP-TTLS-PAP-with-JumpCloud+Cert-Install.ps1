<# WLAN_profile schema: 
https://learn.microsoft.com/en-us/windows/win32/nativewifi/wlan-profileschema-elements
Based on the 'WPA2-Personal profile sample':
https://learn.microsoft.com/en-us/windows/win32/nativewifi/wpa2-personal-profile-sample

### Wi-Fi-EAP-TTLS-PAP-with-JumpCloud ###

Please define the parameters below according to your environment.
#>

### Start of configuration ###
# Please specify the name of your network here:
$Name = 'MyNetwork'
# Please specify your PreShareKey (or other type of credentials) here:
#not-in-use-here $PSK = 'MyPreSharedKey' # https://learn.microsoft.com/en-us/windows/win32/nativewifi/wlan-profileschema-elements
# Please specify the name of the SSID here:
$SSID = 'MySSID'
# Please specify the Connection Type (IBSS for AdHoc; ESS for Infrastructure) here:
$ConnectionType = 'ESS' 
# Please specify the Connection Mode (Auto or Manual) here:
#not-in-use-here $ConnectionMode = 'Auto' 
### End of configuration ###

# Generate random Guid for the profile
$guid = New-Guid
# 'hexing' the SSID
$HexArray = $SSID.ToCharArray() | foreach-object { [System.String]::Format("{0:X}", [System.Convert]::ToUInt32($_)) }
$HexSSID = $HexArray -join ""

# Generate the XML-Profile
@"
<?xml version="1.0"?>
<WLANProfile xmlns="http://www.microsoft.com/networking/WLAN/profile/v1">
	<name>$Name</name>
	<SSIDConfig>
		<SSID>
			<hex>$HexSSID</hex>
			<name>$SSID</name>
		</SSID>
		<nonBroadcast>true</nonBroadcast>
	</SSIDConfig>
	<connectionType>$ConnectionType</connectionType>
	<connectionMode>auto</connectionMode>
	<autoSwitch>false</autoSwitch>
	<MSM>
		<security>
			<authEncryption>
				<authentication>WPA2</authentication>
				<encryption>AES</encryption>
				<useOneX>true</useOneX>
			</authEncryption>
			<OneX xmlns="http://www.microsoft.com/networking/OneX/v1">
				<cacheUserData>true</cacheUserData>
				<authMode>user</authMode>
				<EAPConfig><EapHostConfig xmlns="http://www.microsoft.com/provisioning/EapHostConfig"><EapMethod><Type xmlns="http://www.microsoft.com/provisioning/EapCommon">21</Type><VendorId xmlns="http://www.microsoft.com/provisioning/EapCommon">0</VendorId><VendorType xmlns="http://www.microsoft.com/provisioning/EapCommon">0</VendorType><AuthorId xmlns="http://www.microsoft.com/provisioning/EapCommon">311</AuthorId></EapMethod><Config xmlns="http://www.microsoft.com/provisioning/EapHostConfig"><EapTtls xmlns="http://www.microsoft.com/provisioning/EapTtlsConnectionPropertiesV1"><ServerValidation><ServerNames></ServerNames><TrustedRootCAHash>c8 e1 81 f5 2d 8c d3 17 ae 6b 32 43 fb 9c b 2e 5e f5 d3 37</TrustedRootCAHash><DisablePrompt>false</DisablePrompt></ServerValidation><Phase2Authentication><PAPAuthentication/></Phase2Authentication><Phase1Identity><IdentityPrivacy>true</IdentityPrivacy><AnonymousIdentity>anonymous</AnonymousIdentity></Phase1Identity></EapTtls></Config></EapHostConfig></EAPConfig>
			</OneX>
		</security>
	</MSM>
</WLANProfile>

"@ | out-file "C:\Windows\Temp\$guid.xml" 

# Apply Wifi-Profile
netsh wlan add profile filename="C:\Windows\Temp\$guid.xml" user=all

# Download and install JumpCloud RADIUS certificate
$RadiusCertURI = "https://jumpcloud-kb.s3.amazonaws.com/radius.jumpcloud.com-2022.crt"
$RadiusCertOutFilePath = "C:\Windows\Temp\radius.jumpcloud.com-2022.crt"
$RadiusCertHashURI = "https://jumpcloud-kb.s3.amazonaws.com/radius.jumpcloud.com-2022.crt.md5"
$RadiusCertHashOutFilePath = "C:\Windows\Temp\radius.jumpcloud.com-2022.crt.md5"
function DownloadFiles() {
    try {
        Invoke-WebRequest -URI $RadiusCertURI -OutFile $RadiusCertOutFilePath
    } catch {
        Write-Error -Message "Failed to download RADIUS certificate"
        Write-Host $_
        exit 1
    }
    try {
        Invoke-WebRequest -URI $RadiusCertHashURI -OutFile $RadiusCertHashOutFilePath
    } catch {
        Write-Error -Message "Failed to download MD5 hash of RADIUS certificate"
        Write-Host $_
        exit 1
    }
}
function ValidateHash() {
    try {
        $HashToValidate = certutil -hashfile $RadiusCertOutFilePath MD5 | Out-String | ForEach-Object {($_ -split '\r?\n')[1]};
        $HashPattern = "[a-fA-F0-9]{32}";
        $KnownHash = Select-String -Path $RadiusCertHashOutFilePath -Pattern $HashPattern | ForEach-Object {$_.matches.Groups[0]} | ForEach-Object {$_.Value}
        return ($HashToValidate -eq $KnownHash)
    } catch {
        Write-Error -Message "Failed to validate MD5 hash of RADIUS certificate"
        Write-Host $_
        exit 1
    }
}
function InstallCertificate() {
    try {
        DownloadFiles
        $HashMatches = ValidateHash
        if ($HashMatches -ne 1) {
            Write-Error -Message "Failed to validate MD5 hash of RADIUS certificate"
            Write-Host $_
            exit 1
        }
        Remove-Item -Path $RadiusCertHashOutFilePath -Force
        Import-Certificate -FilePath $RadiusCertOutFilePath -CertStoreLocation Cert:\LocalMachine\Root
    } catch {
        Write-Error -Message "Failed to install RADIUS certificate"
        Write-Host $_
        exit 1   
    }
}
InstallCertificate

# Cleanup
remove-item "C:\Windows\Temp\$guid.xml" -Force
remove-item $RadiusCertOutFilePath -Force

