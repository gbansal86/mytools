<#
Source module 3 of 5 for USB Port Explorer Pro.
This file is loaded by USB_Port_Explorer.ps1. Run the root launcher rather than this module directly.
The split keeps the project easier to read on GitHub; functional statements are kept in original order.
#>

function Get-RecordText {
    param($Record)
    if ($null -eq $Record) { return '' }
    $key = Get-PortKey $Record
    $label = ''
    if ($key -and $script:PhysicalLabels.ContainsKey($key)) { $label = $script:PhysicalLabels[$key] }
    $native = Get-NativePortForRecord $Record
    $nativeProtocols = 'Not available (hub query not mapped to this PnP node)'
    $nativeConnection = 'Not available'
    $nativeSpeed = 'Not available'
    $nativeSource = 'PnP fallback only'
    $nativeExtra = ''
    if ($native) {
        $nativeProtocols = $native.Protocols
        $nativeConnection = $native.Connection
        $nativeSpeed = $native.LinkSpeed
        $nativeSource = $native.Source
        $nativeExtra = $native.Details
    }
    $lines = @(
        "Device / controller: $($Record.Name)",
        "Device type: $($Record.Kind)",
        "Status: $($Record.Status)",
        "USB version clue (name / ID only): $($Record.VersionHint)",
        "Hub logical port protocols: $nativeProtocols",
        "Port connection state: $nativeConnection",
        "Attached-device link speed: $nativeSpeed",
        "Speed information source: $nativeSource",
        "Native probe details: $nativeExtra",

        'Connector shape (USB-A / USB-C): Not reported reliably',
        "Physical port label: $label",
        "Port number (Windows-reported): $($Record.PortNumber)",
        "Port location: $($Record.PortLocation)",
        "Location path: $($Record.LocationPath)",
        "Parent PnP ID: $($Record.ParentId)",
        "PnP instance ID: $($Record.InstanceId)",
        "Manufacturer: $($Record.Manufacturer)",
        "Windows device class: $($Record.Class)",
        "Driver service: $($Record.Service)",
        "Bus-reported description: $($Record.BusReported)",
        "Hardware IDs: $($Record.HardwareIds)",
        "Compatible IDs: $($Record.CompatibleIds)",
        "Device description: $($Record.DeviceDesc)",
        "Class GUID: $($Record.ClassGuid)",
        "Driver key: $($Record.DriverKey)",
        "Driver version: $($Record.DriverVersion)",
        "Driver date: $($Record.DriverDate)",
        "Driver INF: $($Record.DriverInfPath)",
        "Driver provider: $($Record.DriverProvider)",
        "Enumerator: $($Record.EnumeratorName)",
        "Address: $($Record.Address)",
        "Capabilities: $($Record.Capabilities)",
        "Install date: $($Record.InstallDate)",
        "First install date: $($Record.FirstInstallDate)",
        "Last arrival date: $($Record.LastArrivalDate)",
        '',
        'STORAGE INFO (when this USB device maps to a Windows disk):',
        $( $d = Get-StorageInfoForRecord $Record; if ($d) { "Physical drive: $($d.PhysicalDrive)" } else { 'Physical drive: Not mapped' } ),
        $( if ($d -and $d.Model) { "Disk model: $($d.Model)" } else { 'Disk model: ' } ),
        $( if ($d -and $d.SizeBytes) { "Disk size: $(Format-ByteSize $d.SizeBytes)" } else { 'Disk size: ' } ),
        $( if ($d -and $d.SerialNumber) { "Disk serial: $($d.SerialNumber)" } else { 'Disk serial: ' } ),
        '',
        'SPEED NOTE:',
        'Native speed is a driver-reported signaling speed, NOT a measured transfer rate.',
        'USB 3.x labeling does not identify Gen 1 vs Gen 2 or 5/10/20 Gb/s precisely.',
        'USB 2.0 HSxx and USB 3.x SSxx can be companion paths at one physical socket.',
        'A logical-port protocol is NOT the physical socket maximum capability.',
        'USB4, USB-A vs USB-C, and USB Power Delivery require separate evidence.'
    )
    return ($lines -join [Environment]::NewLine)
}

function Get-NodeLabel {
    param($Record)
    $prefix = ''
    if ($Record.PortNumber) { $prefix = "[Port $($Record.PortNumber)] " }
    $key = Get-PortKey $Record
    $label = ''
    if ($key -and $script:PhysicalLabels.ContainsKey($key)) {
        $label = " [$($script:PhysicalLabels[$key])]"
    }
    return "$prefix$($Record.Name)$label"
}

function Show-SelectedRecord {
    param($Record)
    $script:SelectedRecord = $Record
    $script:EasyDetails.Text = Get-LaymanPortText $Record
    $script:Details.Text = Get-RecordText $Record
    if ($script:NativeLoadError) { $script:Details.AppendText("`r`n`r`nNative probe: $($script:NativeLoadError)") }
    if ($script:NativeScan -and $script:NativeScan.Warnings.Count) {
        $script:Details.AppendText("`r`n`r`nNative hub warnings (first 5):`r`n" + (($script:NativeScan.Warnings | Select-Object -First 5) -join "`r`n"))
    }
    # Selecting a different node should show the first details line, not retain
    # the previous device's vertical scroll position.
    $script:EasyDetails.SelectionStart = 0
    $script:EasyDetails.SelectionLength = 0
    $script:EasyDetails.ScrollToCaret()
    $script:Details.SelectionStart = 0
    $script:Details.SelectionLength = 0
    $script:Details.ScrollToCaret()
    $script:LabelText.Text = ''
    $key = Get-PortKey $Record
    if ($key -and $script:PhysicalLabels.ContainsKey($key)) {
        $script:LabelText.Text = $script:PhysicalLabels[$key]
    }
    $script:LabelText.Enabled = [bool]$key
    $script:SaveLabelButton.Enabled = [bool]$key
    if ($key) {
        $script:LabelHelp.Text = 'Label this connection path (e.g. Front-left or Rear USB-C). Verify by unplugging/replugging a device.'
    } else {
        $script:LabelHelp.Text = 'No stable port path was reported for this item; port labeling is unavailable.'
    }
}

function Show-UsbTree {
    $script:Tree.BeginUpdate()
    try {
        $script:Tree.Nodes.Clear()
        $script:SelectedRecord = $null
        $script:EasyDetails.Clear()
        $script:Details.Clear()
        $script:LabelText.Text = ''
        $script:LabelText.Enabled = $false
        $script:SaveLabelButton.Enabled = $false

        $query = $script:SearchText.Text.Trim()
        $visible = @{}
        if (-not $query) {
            foreach ($r in $script:Records) { $visible[$r.InstanceId] = $true }
        } else {
            foreach ($r in $script:Records) {
                $searchable = "$($r.Name) $($r.Kind) $($r.PortLocation) $($r.PortNumber) $($r.InstanceId) $($r.LocationPath)"
                if ($searchable.IndexOf($query, [StringComparison]::OrdinalIgnoreCase) -ge 0) {
                    $current = $r
                    $limit = 0
                    while ($null -ne $current -and $limit -lt 30) {
                        $visible[$current.InstanceId] = $true
                        if (-not $script:RecordsById.ContainsKey($current.ParentId)) { break }
                        $current = $script:RecordsById[$current.ParentId]
                        $limit++
                    }
                }
            }
        }

        $nodes = @{}
        foreach ($r in $script:Records) {
            if (-not $visible.ContainsKey($r.InstanceId)) { continue }
            $node = [System.Windows.Forms.TreeNode]::new((Get-NodeLabel $r))
            $node.Tag = $r
            switch ($r.Kind) {
                'Host controller' { $node.ForeColor = [System.Drawing.Color]::DarkBlue }
                'Root hub'       { $node.ForeColor = [System.Drawing.Color]::DarkGreen }
                'USB hub'        { $node.ForeColor = [System.Drawing.Color]::DarkGreen }
                'Hub logical port' { $node.ForeColor = [System.Drawing.Color]::DarkSlateBlue }
                default          { $node.ForeColor = [System.Drawing.Color]::Black }
            }
            $nodes[$r.InstanceId] = $node
        }
        foreach ($r in $script:Records) {
            if (-not $nodes.ContainsKey($r.InstanceId)) { continue }
            $node = $nodes[$r.InstanceId]
            $parentNodeId = $r.ParentId
            if ($r.Kind -ne 'Hub logical port' -and $r.PortNumber -and $r.ParentId) {
                $candidatePort = "HUBPORT|$($r.ParentId)|$($r.PortNumber)"
                if ($nodes.ContainsKey($candidatePort)) { $parentNodeId = $candidatePort }
            }
            if ($parentNodeId -and $parentNodeId -ne $r.InstanceId -and $nodes.ContainsKey($parentNodeId)) {
                [void]$nodes[$parentNodeId].Nodes.Add($node)
            } else {
                [void]$script:Tree.Nodes.Add($node)
            }
        }
        $script:Tree.ExpandAll()
        $hostCount = @($script:Records | Where-Object Kind -eq 'Host controller').Count
        $hubCount = @($script:Records | Where-Object { $_.Kind -in @('Root hub', 'USB hub') }).Count
        $probeText = 'Native probe unavailable'
        if ($script:NativeScan) {
            $probeText = "Native hub query: $($script:NativeScan.HubsOpened)/$($script:NativeScan.HubsFound) hubs; $($script:NativeScan.Ports.Count) logical ports"
            if ($script:NativeScan.Warnings.Count) { $probeText += "; $($script:NativeScan.Warnings.Count) warning(s)" }
        }
        $script:StatusLabel.Text = "PnP nodes: $($script:Records.Count) | Controllers: $hostCount | Hubs: $hubCount | $probeText"
        if ($nodes.Count -eq 0) {
            $script:EasyDetails.Text = "No matching present USB nodes. Clear the search, then select Refresh."
            $script:Details.Text = "No matching present USB nodes."
        }
    } finally {
        $script:Tree.EndUpdate()
    }
}

