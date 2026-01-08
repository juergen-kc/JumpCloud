# CLAUDE.md - JumpCloud PowerShell Scripts Repository

This file provides guidance for AI assistants working with this repository.

## Repository Overview

This is a collection of **PowerShell scripts for JumpCloud administration**. JumpCloud is a cloud-based directory platform that provides identity and access management (IAM) for IT organizations. The scripts automate various JumpCloud operations including:

- System management and reporting
- User and group management
- Policy creation and deployment
- Security configurations (BitLocker, LAPS, certificates)
- Windows registry and Group Policy management
- Conditional Access Policy (CAP) creation

## Directory Structure

```
/
├── *.ps1                           # Main PowerShell scripts (root level)
├── BitLocker2Barcode public/       # BitLocker recovery key to barcode tool
│   ├── BitLocker2Barcode.ps1       # Main script using WPF GUI
│   └── code128/                    # Code128 barcode module
│       ├── code128.psm1            # PowerShell module for barcode generation
│       ├── LICENSE                 # MIT license
│       └── README.md               # Module documentation
├── *.csv                           # Configuration/data files
├── *.zip                           # Packaged tools (SSSIP, etc.)
└── README.md                       # Basic repository description
```

## Script Categories

### System Management
- `Get-JCSystemStatistics.ps1` - Aggregates system statistics (online/offline counts, agent versions, OS distributions)
- `JC - Get-SystemReport.ps1` - Generates comprehensive system reports
- `JC - Group systems by software installed.ps1` - Auto-groups systems based on installed software
- `JC - Group systems by chipset for macOS.ps1` - Groups macOS systems by processor architecture
- `JC - Group systems geolocation.ps1` - Groups systems by geographic location
- `JC - Windows Disk Usage Report - public.ps1` - Reports on Windows disk usage

### User & Group Management
- `JC - Create User Group with Reply Attributes from JSON array - public.ps1` - Creates user groups with RADIUS attributes
- `JC - Create User Group with Reply Attributes from CSV file - public.ps1` - Same as above but from CSV input
- `JC - OrgChart via DrawIO - public.ps1` - Generates organization charts

### Policy Management
- `JC - CAP Wizard v2_2 - public.ps1` - Interactive wizard for creating Conditional Access Policies
- `JC - Registry-Importer v1_2 - public.ps1` - Imports Windows registry keys to JumpCloud policies
- `JC - macOS Policy Bulk Importer - public.ps1` - Bulk imports .mobileconfig files as policies
- `JC - Import Group Policy Templates and Manage Microsoft Edge Policies via Commands.ps1`
- `JumpCloud - Bulk REG Importer to multiple Custom Policies - public.ps1`
- `JumpCloud - HardeningKitty to multiple REG - public.ps1` - Converts HardeningKitty configs to registry policies

### Security & Encryption
- `API-Encrypter.ps1` - Generates encrypted API key storage (AES key + SecureString)
- `JC-miniLAPS-rc1.ps1` - Local Administrator Password Solution using SystemContext API
- `JC-miniLAPS-with-API-key.ps1` - LAPS variant using API key authentication
- `JC-Wi-Fi-EAP-TTLS-PAP-with-JumpCloud+Cert-Install.ps1` - Wi-Fi certificate installation
- `JumpCloud - CA with Device Posture - public.ps1` - Conditional Access with device posture checks
- `BitLocker2Barcode public/` - Displays BitLocker recovery keys as scannable barcodes

### Deployment & Onboarding
- `Onboarder.ps1` - User onboarding script with device assignment
- `JC - Pre-Configure ADI - public.ps1` - Pre-configures Active Directory Integration
- `JC - Download and Install PPKG.ps1` - Provisioning package deployment
- `JC - PPKG creator.ps1` - Creates Windows provisioning packages
- `JC - Install Winget - SystemContext` - Installs winget in system context

### Reporting
- `JC-CommandResultsReporting-v3.ps1` - Aggregates and reports on command execution results
- `JC - Get Vulneranilites for an installed Application - public.ps1` - Vulnerability reporting

### Windows Configuration
- `ASR-Rule: Configure All [Customise as needed].ps1` - Attack Surface Reduction rules configuration
- `Configure AppLocker - Deny Teams and MS Paint` - AppLocker policy example
- `Remove Teams consumer app on Windows 11.ps1` - Removes Teams consumer edition
- `JC - Create a Scheduled Task to Restart or Shutdown after an idle time of X - public.ps1`

## Key Conventions

### Script Naming
- Scripts prefixed with `JC - ` are JumpCloud-specific automation tools
- Scripts ending with `- public.ps1` are intended for public/community sharing
- Version numbers are often included in names (e.g., `v1_2`, `v2_2`, `RC1`)

### Script Structure Pattern
Most scripts follow this structure:
1. **Header block** - Comment block with `.DESCRIPTION`, `.NOTES`, `.INPUTS`, `.EXAMPLE`, `.AUTHOR`, `.VERSION`
2. **Customizable variables section** - User-configurable parameters at the top
3. **API headers setup** - Standard JumpCloud API authentication headers
4. **Core logic** - Main script functionality
5. **Output/reporting** - Results display using `Write-Host` with color coding

### API Authentication Patterns

**Direct API Key (simpler scripts):**
```powershell
$apikey = "<API KEY>"
$org_id = "<ORG ID>"
$headers = @{
    "x-org-id" = $org_id
    "x-api-key" = $apikey
    "content-type" = "application/json"
}
```

**Encrypted API Key (secure scripts):**
```powershell
$KeyFile = "AES.key"
$SecretFile = "EncryptedSecret.txt"
$key = Get-Content $KeyFile
$Secret = Get-Content $SecretFile | ConvertTo-SecureString -key $key
```

**SystemContext API (agent-based, no API key needed):**
```powershell
$config = get-content 'C:\Program Files\JumpCloud\Plugins\Contrib\jcagent.conf'
$regex = 'systemKey\":\"(\w+)\"'
$systemKey = [regex]::Match($config, $regex).Groups[1].Value
```

### JumpCloud PowerShell Module Usage
Scripts typically use the official JumpCloud PowerShell module:
```powershell
Import-Module JumpCloud
Connect-JCOnline $apiKey
```

Common cmdlets used:
- `Get-JCSystem` / `Get-JcSdkSystem` - Retrieve systems
- `Get-JCUser` - Retrieve users
- `Get-JCGroup` / `Get-JcSdkSystemGroup` - Manage groups
- `New-JCPolicy` / `Set-JCPolicy` - Policy management
- `Get-JCSystemInsights` - System Insights queries

### REST API Endpoints
Scripts interact with these JumpCloud API endpoints:
- `https://console.jumpcloud.com/api/` - v1 API
- `https://console.jumpcloud.com/api/v2/` - v2 API
- Common resources: `/systems`, `/policies`, `/groups`, `/users`, `/authn/policies`, `/iplists`

### Output Conventions
- `Write-Host` with `-ForegroundColor Cyan` for progress messages
- `Write-Host` with `-ForegroundColor Green` for success
- `Write-Host` with `-ForegroundColor Red` for errors
- `Write-Host` with `-ForegroundColor Yellow` for warnings

## Development Guidelines

### When Modifying Scripts
1. **Preserve header blocks** - Maintain existing documentation format
2. **Keep customizable variables at the top** - Users expect configuration at the start
3. **Use SecureString for sensitive data** - Never store plaintext credentials
4. **Test on both Windows 10 and Windows 11** - Platform compatibility matters
5. **Handle API pagination** - Many scripts use `?limit=100` for API calls

### Security Considerations
- API keys should be encrypted using `API-Encrypter.ps1` pattern
- Use SystemContext API when possible (avoids API key exposure)
- Scripts may run in SYSTEM context - handle paths accordingly
- Remove sensitive files after use (see `Onboarder.ps1` pattern)

### PowerShell Version Compatibility
- Most scripts target PowerShell 5.1 (Windows PowerShell)
- Some cryptographic features may not work with PowerShell 2.0
- Cross-platform scripts should work on macOS with PowerShell Core

### Common Placeholders to Replace
When using scripts, users must replace:
- `<YOUR_API_KEY_GOES_HERE>` or `"YOUR_JUMPCLOUD_API_KEY"`
- `<ORG ID>` or `$org_id`
- `<POLICY ID>` or `$policyID`
- `<PATH TO...>` for file system paths

## Testing

There is no formal test framework. Scripts are typically tested manually against JumpCloud tenants. When modifying scripts:
1. Test with a limited scope first (single system/user)
2. Verify API responses before bulk operations
3. Check command results via JumpCloud Admin Console

## External Dependencies

- **JumpCloud PowerShell Module**: `Install-Module JumpCloud`
- **NuGet Package Provider**: Required for module installation
- **Libre Barcode 128 Font**: For BitLocker barcode display
- **.NET Framework/Crypto libraries**: For RSA signing operations

## Related Resources

- [JumpCloud Support GitHub](https://github.com/TheJumpCloud/support)
- [JumpCloud PowerShell SDK](https://github.com/TheJumpCloud/jcapi-powershell)
- [JumpCloud API Documentation](https://docs.jumpcloud.com/api/)
- [JumpCloud Community Scripts](https://community.jumpcloud.com/t5/community-scripts/ct-p/Scripts)
