<# GitHub source segment 4B; loaded by the root wrapper. Do not run directly. #>
function Export-UsbCsv {
    try {
        New-Item -ItemType Directory -Force -Path $script:OutputFolder | Out-Null
        $filename = 'USB_Inventory_{0}.csv' -f (Get-Date -Format 'yyyyMMdd_HHmmss')
        $path = Join-Path $script:OutputFolder $filename
        $script:Records | ForEach-Object {
            $r = $_
            $key = Get-PortKey $r
            $label = ''
            if ($key -and $script:PhysicalLabels.ContainsKey($key)) { $label = $script:PhysicalLabels[$key] }
            [pscustomobject]@{
                PhysicalPortLabel = $label
                Name = $r.Name
                Kind = $r.Kind
                Status = $r.Status
                PortNumber = $r.PortNumber
                PortLocation = $r.PortLocation
                LocationPath = $r.LocationPath
                USBGenerationHint = $r.VersionHint
                LogicalPortProtocols = $( $p = Get-NativePortForRecord $r; if ($p) { $p.Protocols } else { 'Unknown' } )
                AttachedDeviceLinkSpeed = $( $p = Get-NativePortForRecord $r; if ($p) { $p.LinkSpeed } else { 'Unknown' } )
                HubConnectionState = $( $p = Get-NativePortForRecord $r; if ($p) { $p.Connection } else { 'Unknown' } )
                NativeHubProbeDetails = $( $p = Get-NativePortForRecord $r; if ($p) { $p.Details } else { '' } )
                ParentId = $r.ParentId
                InstanceId = $r.InstanceId
                Manufacturer = $r.Manufacturer
                Class = $r.Class
                Service = $r.Service
                BusReported = $r.BusReported
                HardwareIds = $r.HardwareIds
                CompatibleIds = $r.CompatibleIds
            }
        } | Export-Csv -LiteralPath $path -NoTypeInformation -Encoding UTF8
        [System.Windows.Forms.MessageBox]::Show("Exported $($script:Records.Count) nodes to:`r`n$path", 'USB Port Explorer') | Out-Null
    } catch {
        [System.Windows.Forms.MessageBox]::Show("CSV export failed: $($_.Exception.Message)", 'USB Port Explorer', 'OK', 'Error') | Out-Null
    }
}

function Save-PhysicalLabel {
    $record = $script:SelectedRecord
    $key = Get-PortKey $record
    if (-not $key) { return }
    $label = $script:LabelText.Text.Trim()
    try {
        if ($label) { $script:PhysicalLabels[$key] = $label }
        else { $script:PhysicalLabels.Remove($key) | Out-Null }
        New-Item -ItemType Directory -Force -Path $script:OutputFolder | Out-Null
        ConvertTo-Json -InputObject $script:PhysicalLabels -Depth 3 |
            Set-Content -LiteralPath $script:LabelsFile -Encoding UTF8
        Show-UsbTree
        if ($script:RecordsById.ContainsKey($record.InstanceId)) {
            Show-SelectedRecord $script:RecordsById[$record.InstanceId]
        }
        $script:StatusLabel.Text = 'Port label saved. Select the device again to see its updated tree label.'
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Could not save port label: $($_.Exception.Message)", 'USB Port Explorer', 'OK', 'Error') | Out-Null
    }
}

# --- Windows Forms GUI ---
