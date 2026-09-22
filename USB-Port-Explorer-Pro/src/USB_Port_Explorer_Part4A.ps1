<# GitHub source segment 4A; loaded by the root wrapper. Do not run directly. #>
<#
Source module 4 of 5 for USB Port Explorer Pro.
This file is loaded by USB_Port_Explorer.ps1. Run the root launcher rather than this module directly.
The split keeps the project easier to read on GitHub; functional statements are kept in original order.
#>

function Refresh-UsbData {
    $script:Form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
    $script:StatusLabel.Text = 'Reading present USB devices and their Windows location paths...'
    [System.Windows.Forms.Application]::DoEvents()
    try {
        Update-StorageInventory
        $script:Records = @(Get-UsbInventory)
        $script:RecordsById = @{}
        foreach ($r in $script:Records) { $script:RecordsById[$r.InstanceId] = $r }
        Read-NativeUsbPorts
        # Show occupied AND empty logical hub ports, not just attached devices.
        # These are read-only GUI records, never actual Windows PnP instance IDs.
        $addedPorts = [System.Collections.Generic.List[object]]::new()
        if ($script:NativeScan) {
            foreach ($port in $script:NativeScan.Ports) {
                if (-not $script:RecordsById.ContainsKey($port.HubInstanceId)) { continue }
                $virtualId = "HUBPORT|$($port.HubInstanceId)|$($port.Port)"
                $addedPorts.Add([pscustomobject]@{
                    Name = "USB port $($port.Port) - $($port.Connection)"
                    Kind = 'Hub logical port'
                    Status = 'OK'
                    Class = 'USB Hub API'
                    InstanceId = $virtualId
                    ParentId = $port.HubInstanceId
                    PortNumber = [string]$port.Port
                    PortLocation = "Hub port $($port.Port)"
                    LocationPath = ''
                    VersionHint = 'Native USB hub port (see protocols)'
                    Manufacturer = ''
                    Service = ''
                    BusReported = ''
                    HardwareIds = ''
                    CompatibleIds = ''
                    DeviceDesc = ''
                    ClassGuid = ''
                    DriverKey = ''
                    DriverVersion = ''
                    DriverDate = ''
                    DriverInfPath = ''
                    DriverProvider = ''
                    EnumeratorName = ''
                    Address = ''
                    Capabilities = ''
                    InstallDate = ''
                    FirstInstallDate = ''
                    LastArrivalDate = ''
                })
            }
        }
        $script:Records = @($script:Records) + @($addedPorts.ToArray())
        foreach ($r in $addedPorts) { $script:RecordsById[$r.InstanceId] = $r }
        Show-UsbTree
    } catch {
        $script:StatusLabel.Text = 'USB scan failed.'
        [System.Windows.Forms.MessageBox]::Show(
            "Could not read USB devices:`r`n$($_.Exception.Message)`r`n`r`nTry running on Windows 10/11 with Windows PowerShell 5.1.",
            'USB Port Explorer', 'OK', 'Error') | Out-Null
    } finally {
        $script:Form.Cursor = [System.Windows.Forms.Cursors]::Default
    }
}

