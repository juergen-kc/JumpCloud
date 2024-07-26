<#
.SYNOPSIS

Converts text into values that can be rendered as a barcode when used with a barcode font such as Libre Barcode 128.

.EXAMPLE

# Get type A barcode. Based on wikipedia example.
Get-Code128String "PJJ123C" -Debug

ËPJJ123CVÎ

.EXAMPLE

# Pipeline usage plus debug
PJJ123C" | Get-Code128String -Type 'A'
#>
function Get-Code128String {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True,Position=0,ValueFromPipeline=$True)]
        [ValidateNotNullOrEmpty()]
        [string] $Text,

        # Code Type. Not a char because hash lookup below will not work.
        [Parameter(Mandatory=$True,Position=1)]
        [ValidateSet("A", "B", "C")]
        [string] $Type
    )
    
    begin {
        # Codes represent values used to calculate checksum.
        $CODES = 32..126 + 195..206
        switch ($Type) {
            'A' { $Output = [char][byte]203; $ProductSum = 103; break }
            'B' { $Output = [char][byte]204; $ProductSum = 104; break }
            'C' { $Output = [char][byte]205; $ProductSum = 105; break }
        }
        Write-Debug "Test $Output" 
    }
    
    process {
        for ($i = 0; $i -lt $($Text.Length); $i++)
        {
            $Output += $Char = $Text[$i]
            
            # Ensure our input is allowed in this codeset.
            if (-not (Test-Code128Value $Char -Type $Type)) {
                throw "Value `"$Char`" not allowed in Codeset $Type"
            }

            $UnicodeValue = [byte][char]$Char - 32
            $ProductSum += $UnicodeValue * ($i + 1)
            Write-Debug "Unicode value for $Char is $UnicodeValue"
        }
    }
    
    end {
        $Checksum = $ProductSum % 103
        Write-Debug "ProductSum: $ProductSum"
        Write-Debug "Checksum: $Checksum"

        $Output += [char][byte]$CODES[$Checksum]
        $Output += [char][byte]206  # Stop code

        return $Output
    }
}

<#
.SYNOPSIS

Checks whether a given value is valid for a given code set.

.EXAMPLE
Test-Code128Value 'P' -Type 'A'
Test-Code128Value 'p' -Type 'A'

True
False
#>
function Test-Code128Value {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True,Position=0,ValueFromPipeline=$True)]
        [ValidateNotNullOrEmpty()]
        [string] $Value,

        # Code Type. Not a char because hash lookup below will not work.
        [Parameter(Mandatory=$True,Position=1)]
        [ValidateSet("A", "B", "C")]
        [string] $Type  
    )
    
    # Covers 0-9, A-Z, control codes, special characters, and FNC 1-4
    [byte[]] $CodeSetA = 0..95 + @(202, 197, 196, 201)
    
    # Covers 0-9, A-Z, a-z, special characters, and FNC 1-4
    [byte[]] $CodeSetB = 32..127 + @(207, 202, 201, 205)

    $IsValid = $True
    switch($Type) {
        'A' { if (-not $CodeSetA.Contains([byte][char]$Value)) { $IsValid = $False }; break}
        'B' { if (-not $CodeSetB.Contains([byte][char]$Value)) { $IsValid = $False }; break}
        'C' { if (-not [char]::IsDigit($Value)) { $IsValid = $False }; break}
    }
    return $IsValid
}