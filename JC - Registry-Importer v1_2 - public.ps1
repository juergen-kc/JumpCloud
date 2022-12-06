 <#
##############################################################################################################################
.FUNCTIONALITY
This script will export an existing registry keys from a reference machine and import them to a JumpCloud Policy.

.DESCRIPTION 
...

Authors: Juergen Klaassen & Shawn Song
Version: 1.2
Date: 2022-12-01

.NOTES
This script is provided as-is without any warranty. Use at your own risk.
This script was tested on Windows 10 and Windows 11 as well as on macOS (without the registry export).

.INPUTS
- PowerShell 5.1
- JumpCloud API Key
- JumpCloud Organization ID
- JumpCloud Policy ID (please create the policy in advance  and use the policy ID)
- JumpCloud Policy Name (please create the policy in advance and use the policy name)
- A reference machine (Windows only) with the registry keys configured you want to import
- Policy Templates must be deployed to the reference and target machines

.EXAMPLE
1. $org_id: Your Organization ID from the JumpCloud Admin Console 
   (https://console.jumpcloud.com/#/settings/organization#general)
2. $apikey: Your API Key from the JumpCloud Admin Console 
   (https://console.jumpcloud.com/#/settings/apikeys)
3. $policyID: The ID of the Policy you want to import the registry keys into
4. $policyName: The name of the Policy you want to import the registry keys into
5. $csvPath: The path to the CSV file containing the registry keys to import
6. $path_to_export: The path in the registry to be exported and imported into JumpCloud

.KEYWORDS JumpCloud, Policy, Registry, Import, Export, Registry-Importer

Known Issues:
- none so far
##############################################################################################################################
#>

# Put in your JumpCloud org ID & API Key (Writeable):
$org_id = "<ORG ID>"
$apikey = "<API Key>"

# Change the policy ID & name accordingly: 
$policyID = "<Policy ID>"
$policyName = "Zoom General Settings" # e.g. "Advanced: Imported Custom Registry Keys"

# Specify the path to the CSV file including the filename:
$csvPath = "C:\Users\juergen\Documents\ZoomGeneralSettings.csv"

# Full Registry Path to be exported (e.g. HKLM:\SOFTWARE\Policies\Microsoft\Edge)
# Copy it from the registry editor
$path_to_export = "HKLM:\SOFTWARE\Policies\Zoom\Zoom Meetings\"

##############################################################################################################################
# Don't Change the code below this line! #
##############################################################################################################################

# Headers to be used for the API calls
$headers = @{
    "x-org-id" = $org_id
    "x-api-key" = $apikey
    "content-type" = "application/json"
}

# Get the current registry keys from the policy into an CSV file
Function Export-Registry {

    <#
       .Synopsis
        Export registry item properties.
        .Description
        Export item properties for a give registry key. The default is to write results to the pipeline
        but you can export to either a CSV or XML file. Use -NoBinary to omit any binary registry values.
        .Parameter Path
        The path to the registry key to export.
        .Parameter ExportType
        The type of export, either CSV or XML.
        .Parameter ExportPath
        The filename for the export file.
        .Parameter NoBinary
        Do not export any binary registry values
       .Example
        PS C:\> Export-Registry "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Winlogon" -ExportType xml -exportpath c:\files\WinLogon.xml
        
        .Example
        PS C:\> "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\MobileOptionPack","HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft SQL Server 10" | export-registry
      
        .Example
        PS C:\> dir hklm:\software\microsoft\windows\currentversion\uninstall | export-registry -ExportType Csv -ExportPath "C:\work\uninstall.csv" -NoBinary
        
       .Notes
        NAME: Export-Registry
        VERSION: 1.0
        AUTHOR: Jeffery Hicks
        LASTEDIT: 10/14/2010 
        
        Learn more with a copy of Windows PowerShell 2.0: TFM (SAPIEN Press 2010)
        
       .Link
        Http://jdhitsolutions.com/blog
        
        .Link
        Get-ItemProperty
        Export-CSV
        Export-CliXML
        
       .Inputs
        [string[]]
       .Outputs
        [object]
    #>
    
    [cmdletBinding()]
    
    Param(
    [Parameter(Position=0,Mandatory=$True,
    HelpMessage="Enter a registry path using the PSDrive format.",
    ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True)]
    [ValidateScript({(Test-Path $_) -AND ((Get-Item $_).PSProvider.Name -match "Registry")})]
    [Alias("PSPath")]
    [string[]]$Path,
    
    [Parameter()]
    [ValidateSet("csv","xml")]
    [string]$ExportType,
    
    [Parameter()]
    [string]$ExportPath,
    
    [switch]$NoBinary
    
    )
    
    Begin {
        Write-Verbose -Message "$(Get-Date) Starting $($myinvocation.mycommand)"
        #initialize an array to hold the results
        $data=@()
     } #close Begin
    
    Process {
        # Go through each pipelined path
        $hiveKeys = (Get-ChildItem -Recurse -Path $path | Select-Object pspath).pspath

        # If the designated key path has an empty value, step 1 level to the left for recursive crawling
        if ($null -eq $hiveKeys){
            $hiveKeys = (Get-ChildItem -Recurse (get-itemproperty -path $path | Select-Object PSParentPath).PSParentPath).pspath            
        
        }
        else{
            Write-Verbose "$path is empty, please consider try a path at least 2 level up.."
            break
        }
    
        Foreach ($item in $hiveKeys) {
            Write-Verbose "Exporting non binary properties from $item"
            # get property names
            $item = $item.Replace("Microsoft.PowerShell.Core\Registry::HKEY_LOCAL_MACHINE","HKLM:")
            $properties= Get-ItemProperty -path $item | 
            # exclude the PS properties
             Select-Object * -Exclude PS*Path,PSChildName,PSDrive,PSProvider |
             Get-Member -MemberType NoteProperty,Property -erroraction "SilentlyContinue"
            if ($NoBinary)
            {
                # filter out binary items
                Write-Verbose "Filtering out binary properties"
                $properties=$properties | Where-Object {$_.definition -notmatch "byte"}
            }
            Write-Verbose "Retrieved $(($properties | measure-object).count) properties"
            # enumrate each property getting itsname,value and type
            foreach ($property in $properties) {
                Write-Verbose "Exporting $property"
                $value=(get-itemproperty -path $item -name $property.name).$($property.name)
                
                if (-not ($properties))
                {
                    # no item properties were found so create a default entry
                    $value=$Null
                    $PropertyItem="(Default)"
                    $RegType="System.String"
                }
                else
                {
                    # get the registry value type
                    $regType=$property.Definition.Split()[0]
                    $PropertyItem=$property.name
                }
                # create a custom object for each entry and add it the temporary array
                $data+=New-Object -TypeName PSObject -Property @{
                    "Path"=$item
                    "Name"=$propertyItem
                    "Value"=$value
                    "Type"=$regType
                }
            } # foreach $property
        }# close Foreach 
     } # close process
    
    End {
      # make sure we got something back
      if ($data)
      {
        # export to a file both a type and path were specified
        if ($ExportType -AND $ExportPath)
        {
          Write-Verbose "Exporting $ExportType data to $ExportPath"
          Switch ($exportType) {
            "csv" { $data | Export-CSV -Path $ExportPath -noTypeInformation }
            "xml" { $data | Export-CLIXML -Path $ExportPath }
          } # switch
        } # if $exportType
        elseif ( ($ExportType -AND (-not $ExportPath)) -OR ($ExportPath -AND (-not $ExportType)) )
        {
            Write-Warning "You forgot to specify both an export type and file."
        }
        else 
        {
            # write data to the pipeline
            $data 
        }  
       } #if $#data
       else 
       {
            Write-Verbose "No data found"
            Write "No data found"
       }
         #exit the function
         Write-Verbose -Message "$(Get-Date) Ending $($myinvocation.mycommand)"
     } #close End
    
    } #end Function
   
# Calling the function to export the registry keys
Write-Host "Exporting the registry keys to the specified CSV file" $csvPath -ForegroundColor Cyan
Export-Registry $path_to_export -ExportType csv -ExportPath $csvPath -NoBinary 

# Constructing objects for the request body
Write-Host "Constructing the request body containing existing and new registry keys..." -ForegroundColor Cyan
$url = "https://console.jumpcloud.com/api/v2/policies/" + $policyID
$importedKeys = Import-Csv $csvPath
$response = Invoke-RestMethod -Uri $url -Method GET -Headers $headers

$body = @{} | Select-Object name,values,template
$newvalue = @{} | Select-Object value,configFieldID,configFieldName,sensitive
$newkeysOut = @()
$existingkeys = $response.values.value

foreach ($iKey in $importedKeys){

    # Mapping the key types from the CSV to JC policy console
    switch ($ikey.type) {
        "int" {$type = "DWORD"}
        "uint32"{$type = "DWORD"}
        "string" {$type = "String"}
        "long"{$type = "QWORD"}
        # More to map later
        Default {}
    }

    # Our reg key policy only supports HKLM at the moment:
    #https://support.jumpcloud.com/s/article/Create-Your-Own-Windows-Policy-Using-Registry-Keys
    if ($ikey.Path -contains "HKCU:") {
        Write-Output "$($iKey.path) $($ikey.Name) will not be imported as the policy doesn't support keys in HKCU"
    }
    else {
        $newKey =  [pscustomobject]@{
            "customLocation" = $ikey.path.replace("HKLM:\","")
            "customValueName" = $ikey.name
            "customRegType" = $type
            "customData" = $iKey.value
    
        }
    }
    $newkeysOut += $newKey
}

if ($null -ne $existingkeys) {
    $newkeysOut += $existingkeys
}

# Contiune building the $body
$newvalue.value += $newkeysOut
$newvalue.configFieldID = $response.values.configFieldID
$newvalue.configFieldName = $response.values.configFieldName
$newvalue.sensitive = $response.values.sensitive

$body.name = $policyName
$body.template = @{"id"="5f07273cb544065386e1ce6f"} # hardcoding the universally applicable template ID: Do not change!
$body.values += $newvalue
$body = $body | ConvertTo-Json -Depth 10
$body = $body.Replace("Values","values")

# Updating the policy with the new registry entries
Write-Host "Updating the policy with the new registry keys:" -ForegroundColor Cyan
Write-Host $newvalue -ForegroundColor Cyan

$change  = Invoke-RestMethod -Uri $url -Method Put -Headers $headers -Body $body

Write-Host "Completed." -ForegroundColor Cyan
#EOF 
