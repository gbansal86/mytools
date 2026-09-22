<#
USB Port Explorer Pro - main launcher script

Layman note: the working source is split into small files under .\src so the
GitHub project is easier to read and maintain. This wrapper loads them in order.
Keep this file, USB_Hub_Probe.cs, and the src folder together.
#>

$ErrorActionPreference = 'Stop'
$script:AppRoot = $PSScriptRoot
$sourceDir = Join-Path $script:AppRoot 'src'
$parts = @(
    'USB_Port_Explorer_Part1.ps1',
    'USB_Port_Explorer_Part2.ps1',
    'USB_Port_Explorer_Part3.ps1',
    'USB_Port_Explorer_Part4A.ps1',
    'USB_Port_Explorer_Part4B.ps1',
    'USB_Port_Explorer_Part5A.ps1',
    'USB_Port_Explorer_Part5B.ps1'
)
foreach ($name in $parts) {
    $part = Join-Path $sourceDir $name
    if (-not (Test-Path -LiteralPath $part)) { throw "Required source module is missing: $part" }
    . $part
}
