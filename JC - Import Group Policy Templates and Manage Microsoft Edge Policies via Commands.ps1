### Policy Templates from: https://www.microsoft.com/en-us/edge/business/download?form=MA13FJ ###
$URLadmx = "https://custom-pkg.s3.ap-southeast-1.amazonaws.com/msedge.admx"
$URLadml = "https://custom-pkg.s3.ap-southeast-1.amazonaws.com/msedge.adml" 

### Custom Policy Settings from reference device ###
$EdgePolicyFile = "C:\Windows\Temp\EdgePolicy.reg"

### Download the templates from a public S3-bucket ###
### Place them in the respective folders; reference: https://learn.microsoft.com/en-us/deployedge/configure-microsoft-edge#add-the-administrative-template-to-an-individual-computer ###
Invoke-WebRequest -Uri $URLadmx -OutFile "C:\Windows\PolicyDefinitions\msedge.admx" 
Invoke-WebRequest -Uri $URLadml -OutFile "C:\Windows\PolicyDefinitions\en-US\msedge.adml"

### Import the Custom Edge Policy ###
Reg import $EdgePolicyFile

### Force update of Group Policies ###
gpupdate /force 

### Remove the Custom Edge Policy file from the respective folder ###
Remove-Item $EdgePolicyFile
