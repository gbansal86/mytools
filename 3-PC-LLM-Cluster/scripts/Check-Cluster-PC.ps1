<#
.SYNOPSIS
    Reads the basic hardware and network information needed before creating
    a multi-PC LLM cluster.

.DESCRIPTION
    This script makes no Windows configuration changes.
#>

$ErrorActionPreference = "SilentlyContinue"

Write-Host ""
Write-Host "============================================================"
Write-Host " THREE-PC LLM CLUSTER - COMPUTER INVENTORY"
Write-Host "============================================================"
Write-Host ""

$computer = Get-CimInstance Win32_ComputerSystem
$os = Get-CimInstance Win32_OperatingSystem
$cpu = Get-CimInstance Win32_Processor | Select-Object -First 1

Write-Host "Computer name : $env:COMPUTERNAME"
Write-Host "Windows       : $($os.Caption) $($os.Version)"
Write-Host "CPU           : $($cpu.Name)"
Write-Host ("System RAM    : {0:N1} GB" -f ($computer.TotalPhysicalMemory / 1GB))

Write-Host ""
Write-Host "---- Active Network Adapters ----"
Get-NetAdapter |
    Where-Object {$_.Status -eq "Up"} |
    Select-Object Name, InterfaceDescription, LinkSpeed, MacAddress |
    Format-Table -AutoSize

Write-Host ""
Write-Host "---- IPv4 Addresses ----"
Get-NetIPAddress -AddressFamily IPv4 |
    Where-Object {
        $_.IPAddress -ne "127.0.0.1" -and
        $_.IPAddress -notlike "169.254.*"
    } |
    Select-Object InterfaceAlias, IPAddress, PrefixLength |
    Format-Table -AutoSize

Write-Host ""
Write-Host "---- NVIDIA GPU ----"
$nvidia = Get-Command nvidia-smi -ErrorAction SilentlyContinue

if ($nvidia) {
    & nvidia-smi --query-gpu=name,memory.total,memory.free,driver_version --format=csv
}
else {
    Write-Host "nvidia-smi was not found."
    Write-Host "There may be no NVIDIA GPU, or the NVIDIA driver/tool is unavailable."
}

Write-Host ""
Write-Host "Next:"
Write-Host "1. Confirm all three PCs use wired Ethernet."
Write-Host "2. Note the LinkSpeed shown above."
Write-Host "3. Give each PC a stable IPv4 address."
Write-Host "4. Ping the other PCs."
Write-Host "5. Test the RPC port only after the RPC worker is running."
Write-Host ""
