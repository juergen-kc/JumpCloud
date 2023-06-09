# JumpCloud - HardeningKitty to multiple REG - public.ps1
$url = "https://raw.githubusercontent.com/scipag/HardeningKitty/master/lists/finding_list_cis_microsoft_windows_11_enterprise_21h2_machine.csv"

$response = Invoke-WebRequest -Uri $url
$csvData = $response.Content.Split("`n") | ConvertFrom-Csv

$regFiles = @{}

foreach ($row in $csvData) {
    if ($row.'Method' -eq 'Registry') {
        $key = $row.'RegistryPath'
        $valueName = $row.'RegistryItem'
        $recommendedValue = $row.'RecommendedValue'
        $idAndNameComment = "; " + $row.'ID' + " : " + $row.'Name'

        if ($key -and $valueName -and ($null -ne $recommendedValue)) {
            # Remove 'HKLM:' from the key path
            $key = $key.Replace('HKLM:', 'HKEY_LOCAL_MACHINE')

            # Check if it's a DWORD value
            if ([int32]::TryParse($recommendedValue, [ref]$null)) {
                # Add registry data as DWORD value with ID and name comment
                $registryLine = "${idAndNameComment}`n[${key}]`n"
                $registryLine += "`"${valueName}`"=dword:${recommendedValue}`n`n"
            } else {
                # Add registry data as string value with ID and name comment
                $registryLine = "${idAndNameComment}`n[${key}]`n"
                $registryLine += "`"${valueName}`"=`"${recommendedValue}`"`n`n"
            }

            # Get the control section (e.g., 2.0, 2.1, etc.)
            $controlSection = $row.'ID'.Split('.')[0..1] -join '.'

            if (-not $regFiles.ContainsKey($controlSection)) {
                $regFiles[$controlSection] = "Windows Registry Editor Version 5.00`n`n"
            }

            $regFiles[$controlSection] += $registryLine
        }
    }
}

foreach ($controlSection in $regFiles.Keys) {
    Set-Content -Path "CIS_machine_$($controlSection).reg" -Value $regFiles[$controlSection]
}
