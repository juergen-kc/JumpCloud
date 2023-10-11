<#
.DESCRIPTION
This script imports a CSV file containing a list of bookmarks and creates these bookmarks in JumpCloud using the JumpCloud PowerShell SDK. 
Each bookmark is then presented in the UserConsole.

.EXAMPLE
.\CreateBookmarks.ps1

.FUNCTIONALITY
- Imports a CSV file named 'bookmarks.csv' with headers 'Name' and 'Url'.
- Iterates through each line of the CSV, reading the bookmark name and URL.
- Creates a new bookmark in JumpCloud with the read information.
- Outputs the name and URL of each bookmark to the console for debugging purposes.

.NOTES
- Requires you to have the JumpCloud PowerShell Module installed.
- Requires you to have a CSV file with headers 'Name' and 'Url' in the same directory as this script.
- Requires you to have a JumpCloud API and the JumpCloud ORG ID. You will be prompted for these two during execution.

.LINK
[JumpCloud PowerShell SDK](https://github.com/TheJumpCloud/jcapi-powershell)
#>

# Import the CSV file
# Ensure the CSV file has headers 'Name' and 'Url'
$bookmarkList = Import-Csv -Path 'bookmarks.csv'

# Define an empty application config object
$ApplicationConfig = [JumpCloud.SDK.V1.Models.IApplicationConfig]@{}

# Iterate through each line of the CSV file
foreach ($bookmark in $bookmarkList){
    # Write to console (optional, for debugging purposes)
    Write-Host $bookmark.Name $bookmark.Url
    
    # Prepare the application object
    $Application = @{
        Name        = 'bookmark'
        ssoUrl      = $bookmark.Url
        config      = $ApplicationConfig
        DisplayName = $bookmark.Name
        DisplayLabel = $bookmark.Name
    }
    
    # Create the bookmark in JumpCloud
    New-JcSdkApplication @Application
}
