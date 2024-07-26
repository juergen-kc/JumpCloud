<#
Download the Libre Barcode font from
https://fonts.google.com/specimen/Libre+Barcode+128

Script is based on: https://github.com/RobWoltz/BitLockertoBarcode
#>

param (
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string] $ComputerName
)

# Define the paths to the module and font
$modulePath = "<PATH TO THE DOWNLOADED MODULE>\code128.psm1" # please adjust accordingly
$fontPath = "<PATH TO THE DOWNLOADED FONT>\LibreBarcode128-Regular.ttf" # please adjust accordingly

# Import the Barcode encoding script
import-module $modulePath

# Function to get BitLocker Recovery Key using Get-JCSystem
function Get-BitLockerRecoveryKey {
    param (
        [string] $ComputerName
    )

    # Get the system details for the given hostname
    $System = Get-JCSystem -hostname $ComputerName

    if (-not $System) {
        Write-Host "System with hostname $ComputerName not found." -ForegroundColor Red
        exit
    }

    $SystemId = $System._id

    # Get the BitLocker recovery key for the system
    $RecoveryKey = Get-JCSystem -SystemID $SystemId -SystemFDEKey | Select-Object -ExpandProperty key

    return $RecoveryKey
}

# Generate a form to query the hostname
Add-Type -AssemblyName PresentationFramework

[xml]$inputXaml = @"
<Window
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Title="Enter Hostname"
    Height="200"
    Width="400"
    WindowStartupLocation="CenterScreen">
    <Grid>
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        <Grid.ColumnDefinitions>
            <ColumnDefinition Width="*"/>
        </Grid.ColumnDefinitions>
        <TextBox x:Name="HostnameTextBox" Grid.Row="0" Margin="10" FontSize="16" VerticalContentAlignment="Center"/>
        <Button x:Name="SubmitButton" Grid.Row="1" Margin="10" FontSize="16" Content="Submit" HorizontalAlignment="Center" VerticalAlignment="Center"/>
    </Grid>
</Window>
"@

$inputReader = (New-Object System.Xml.XmlNodeReader $inputXaml)
$inputWindow = [Windows.Markup.XamlReader]::Load($inputReader)

$SubmitButton = $inputWindow.FindName("SubmitButton")
$HostnameTextBox = $inputWindow.FindName("HostnameTextBox")

$SubmitButton.Add_Click({
    $inputWindow.DialogResult = $true
    $inputWindow.Close()
})

if ($inputWindow.ShowDialog() -eq $true) {
    $ComputerName = $HostnameTextBox.Text.Trim()
} else {
    Write-Host "Hostname input cancelled." -ForegroundColor Red
    exit
}

# Get the BitLocker recovery key
$RecoveryKey = Get-BitLockerRecoveryKey -ComputerName $ComputerName

if (-not $RecoveryKey) {
    Write-Host "No BitLocker recovery key found for $ComputerName." -ForegroundColor Red
    exit
}

# Split the recovery key into parts
$KeyParts = $RecoveryKey -split "-"

# Generate barcodes for each part
$BarcodeArray = @()
foreach ($part in $KeyParts) {
    $BarcodeArray += Get-Code128String -Text $part -Type B
}

# Generate a simple WPF form to display the barcodes
Add-Type -AssemblyName PresentationFramework

[xml]$xaml = @"
<Window
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    x:Name="Window"
    Width="800"
    Height="600"
    WindowStartupLocation="CenterScreen">
    <Grid x:Name="Grid">
        <Grid.Resources >
            <Style TargetType="Grid" >
                <Setter Property="Margin" Value="10" />
            </Style>
        </Grid.Resources>
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        <Grid.ColumnDefinitions>
            <ColumnDefinition Width="Auto"/>
        </Grid.ColumnDefinitions>
        <Label x:Name="BLInfo"
            Grid.Column="0"
            Grid.Row="0"
            Width="700"
            Content="BitLocker Code for $($ComputerName.ToUpper())`n`n$RecoveryKey`n`nScan the barcodes below from top to bottom."
        />
        <Label x:Name="BLBarcode1"
            Grid.Column="0"
            Grid.Row="1"
            Width="700"
            FontSize="42"
            HorizontalContentAlignment="Center"
            FontFamily="$fontPath#Libre Barcode 128"
        />
        <Label x:Name="BLBarcode2"
            Grid.Column="0"
            Grid.Row="2"
            Width="700"
            FontSize="42"
            HorizontalContentAlignment="Center"
            FontFamily="$fontPath#Libre Barcode 128"
        />
        <Label x:Name="BLBarcode3"
            Grid.Column="0"
            Grid.Row="3"
            Width="700"
            FontSize="42"
            HorizontalContentAlignment="Center"
            FontFamily="$fontPath#Libre Barcode 128"
        />
        <Label x:Name="BLBarcode4"
            Grid.Column="0"
            Grid.Row="4"
            Width="700"
            FontSize="42"
            HorizontalContentAlignment="Center"
            FontFamily="$fontPath#Libre Barcode 128"
        />
        <Label x:Name="BLBarcode5"
            Grid.Column="0"
            Grid.Row="5"
            Width="700"
            FontSize="42"
            HorizontalContentAlignment="Center"
            FontFamily="$fontPath#Libre Barcode 128"
        />
        <Label x:Name="BLBarcode6"
            Grid.Column="0"
            Grid.Row="6"
            Width="700"
            FontSize="42"
            HorizontalContentAlignment="Center"
            FontFamily="$fontPath#Libre Barcode 128"
        />
        <Label x:Name="BLBarcode7"
            Grid.Column="0"
            Grid.Row="7"
            Width="700"
            FontSize="42"
            HorizontalContentAlignment="Center"
            FontFamily="$fontPath#Libre Barcode 128"
        />
        <Label x:Name="BLBarcode8"
            Grid.Column="0"
            Grid.Row="8"
            Width="700"
            FontSize="42"
            HorizontalContentAlignment="Center"
            FontFamily="$fontPath#Libre Barcode 128"
        />
    </Grid>
</Window>
"@

$reader = (New-Object System.Xml.XmlNodeReader $xaml)

$window = [Windows.Markup.XamlReader]::Load($reader)

# Set the values of the labels of the form
# And set the font to the Barcode font
$window.FindName("BLBarcode1").Content = $BarcodeArray[0]
$window.FindName("BLBarcode2").Content = $BarcodeArray[1]
$window.FindName("BLBarcode3").Content = $BarcodeArray[2]
$window.FindName("BLBarcode4").Content = $BarcodeArray[3]
$window.FindName("BLBarcode5").Content = $BarcodeArray[4]
$window.FindName("BLBarcode6").Content = $BarcodeArray[5]
$window.FindName("BLBarcode7").Content = $BarcodeArray[6]
$window.FindName("BLBarcode8").Content = $BarcodeArray[7]

$window.ShowDialog()

exit