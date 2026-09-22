<#
.SYNOPSIS
    Tests basic reachability of three PCs in an LLM cluster.

.DESCRIPTION
    Edit the example IP addresses below to match your LAN.
    Set RPCPort to a real port only after checking your current llama.cpp build.
    This script makes no system changes.
#>

$ClusterPCs = @(
    @{ Name = "PC1"; IP = "192.168.50.11" },
    @{ Name = "PC2"; IP = "192.168.50.12" },
    @{ Name = "PC3"; IP = "192.168.50.13" }
)

$RPCPort = 0

Write-Host ""
Write-Host "============================================================"
Write-Host " THREE-PC LLM CLUSTER - NETWORK TEST"
Write-Host "============================================================"
Write-Host ""

foreach ($pc in $ClusterPCs) {
    Write-Host "Testing $($pc.Name) - $($pc.IP)"

    $pingOK = Test-Connection -ComputerName $pc.IP -Count 1 -Quiet

    if ($pingOK) {
        Write-Host "  Ping : PASS"
    }
    else {
        Write-Host "  Ping : FAIL"
    }

    if ($RPCPort -gt 0) {
        $tcp = Test-NetConnection -ComputerName $pc.IP -Port $RPCPort -WarningAction SilentlyContinue
        if ($tcp.TcpTestSucceeded) {
            Write-Host "  RPC  : PASS"
        }
        else {
            Write-Host "  RPC  : FAIL"
        }
    }

    Write-Host ""
}

if ($RPCPort -eq 0) {
    Write-Host "RPC port test skipped because RPCPort is 0."
    Write-Host "Edit RPCPort after checking the current llama.cpp RPC documentation."
}
