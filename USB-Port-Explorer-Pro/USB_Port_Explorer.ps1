# USB Port Explorer - Windows 10/11, Windows PowerShell 5.1+
# Read-only USB/PnP topology explorer. No third-party modules or drivers required.
# Optional native hub IOCTL probing is in USB_Hub_Probe.cs; PnP remains the fallback.

$ErrorActionPreference = 'Stop'

try {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
} catch {
    Write-Host "Unable to load Windows Forms: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

[System.Windows.Forms.Application]::EnableVisualStyles()

$script:OutputFolder = Join-Path $PSScriptRoot 'USB_Port_Explorer_Reports'
$script:LabelsFile = Join-Path $script:OutputFolder 'Physical_Port_Labels.json'
$script:Records = @()
$script:RecordsById = @{}
$script:PhysicalLabels = @{}
$script:SelectedRecord = $null
$script:NativePorts = @{}
$script:NativeScan = $null
$script:NativeLoadError = ''
$script:NativeKey = [System.StringComparer]::OrdinalIgnoreCase
$script:StorageDisks = @()

function Initialize-NativeUsbProbe {
    $cs = Join-Path $PSScriptRoot 'USB_Hub_Probe.cs'
    if (-not (Test-Path -LiteralPath $cs)) {
        $script:NativeLoadError = 'Native probe file USB_Hub_Probe.cs is missing.'
        return
    }
    try {
        if (-not ('UsbPortExplorerNative.UsbHubProbe' -as [type])) {
            Add-Type -TypeDefinition (Get-Content -LiteralPath $cs -Raw -Encoding UTF8) -Language CSharp -ErrorAction Stop
        }
    } catch {
        $script:NativeLoadError = "Cannot load native USB probe: $($_.Exception.Message)"
    }
}

function Read-NativeUsbPorts {
    $script:NativePorts = @{}
    $script:NativeScan = $null
    if ($script:NativeLoadError) { return }
    try {
        $script:NativeScan = [UsbPortExplorerNative.UsbHubProbe]::Scan()
        foreach ($port in $script:NativeScan.Ports) {
            $script:NativePorts["$($port.HubInstanceId)|$($port.Port)"] = $port
        }
    } catch {
        $script:NativeLoadError = "Native hub scan failed: $($_.Exception.Message)"
    }
}

function Get-NativePortForRecord {
    param($Record)
    if ($null -eq $Record) { return $null }
    # Only attach a hub IOCTL result when both *the parent hub's PnP ID*
    # and the child's own port number match. A port number by itself is
    # NOT unique across hubs. Walk through USB interface/storage children.
    $cursor = $Record
    for ($depth = 0; $depth -lt 12 -and $null -ne $cursor; $depth++) {
        if ($cursor.ParentId -and $cursor.PortNumber) {
            $key = "$($cursor.ParentId)|$($cursor.PortNumber)"
            if ($script:NativePorts.ContainsKey($key)) { return $script:NativePorts[$key] }
        }
        if (-not $cursor.ParentId -or -not $script:RecordsById.ContainsKey($cursor.ParentId)) { break }
        $cursor = $script:RecordsById[$cursor.ParentId]
    }
    return $null
}


function Update-StorageInventory {
    $script:StorageDisks = @()
    try {
        $script:StorageDisks = @(Get-CimInstance Win32_DiskDrive -ErrorAction Stop | ForEach-Object {
            [pscustomobject]@{
                PnpDeviceId = [string]$_.PNPDeviceID
                PhysicalDrive = [string]$_.DeviceID
                Model = [string]$_.Model
                SerialNumber = ([string]$_.SerialNumber).Trim()
                SizeBytes = [uint64]$_.Size
                InterfaceType = [string]$_.InterfaceType
                MediaType = [string]$_.MediaType
            }
        })
    } catch {
        $script:StorageDisks = @()
    }
}

function Format-ByteSize {
    param([uint64]$Bytes)
    if ($Bytes -le 0) { return '' }
    $tb = $Bytes / 1TB
    $tib = $Bytes / [math]::Pow(1024,4)
    if ($Bytes -ge 1TB) { return ('{0:N2} TB decimal / {1:N2} TiB binary ({2:N0} bytes)' -f ($Bytes/1e12), $tib, $Bytes) }
    if ($Bytes -ge 1GB) { return ('{0:N2} GB decimal / {1:N2} GiB binary ({2:N0} bytes)' -f ($Bytes/1e9), ($Bytes/1GB), $Bytes) }
    return ('{0:N0} bytes' -f $Bytes)
}

function Get-StorageInfoForRecord {
    param($Record)
    if ($null -eq $Record -or -not $script:StorageDisks) { return $null }
    $ids = New-Object System.Collections.Generic.List[string]
    $cursor = $Record
    for ($depth = 0; $depth -lt 10 -and $null -ne $cursor; $depth++) {
        if ($cursor.InstanceId) { [void]$ids.Add([string]$cursor.InstanceId) }
        if (-not $cursor.ParentId -or -not $script:RecordsById.ContainsKey($cursor.ParentId)) { break }
        $cursor = $script:RecordsById[$cursor.ParentId]
    }
    # Also include direct child records, useful when selecting the USB device rather than the USBSTOR disk node.
    foreach ($r in $script:Records) {
        if ($r.ParentId -eq $Record.InstanceId -or $r.ParentId -eq $Record.ParentId) {
            if ($r.InstanceId) { [void]$ids.Add([string]$r.InstanceId) }
        }
    }
    $serialCandidates = @()
    foreach ($id in $ids) {
        $tail = ($id -split '\\')[-1]
        if ($tail) {
            $serialCandidates += (($tail -split '&')[0]).ToUpperInvariant()
        }
    }
    foreach ($disk in $script:StorageDisks) {
        foreach ($id in $ids) {
            if ($disk.PnpDeviceId -and $disk.PnpDeviceId.Equals($id, [StringComparison]::OrdinalIgnoreCase)) { return $disk }
        }
        $d = [string]$disk.PnpDeviceId
        foreach ($serial in $serialCandidates) {
            if ($serial.Length -ge 6 -and $d.ToUpperInvariant().Contains($serial)) { return $disk }
        }
    }
    return $null
}

function Get-LaymanPortText {
    param($Record)
    if ($null -eq $Record) { return '' }
    $native = Get-NativePortForRecord $Record
    $key = Get-PortKey $Record
    $label = if ($key -and $script:PhysicalLabels.ContainsKey($key)) { $script:PhysicalLabels[$key] } else { '(not labeled yet)' }
    $protocol = if ($native) { [string]$native.Protocols } else { 'Not available from the hub query for this node' }
    $speed = if ($native) { [string]$native.LinkSpeed } else { 'Not available' }
    $state = if ($native) { [string]$native.Connection } else { 'Not available' }
    $storage = Get-StorageInfoForRecord $Record

    $plainType = switch ($Record.Kind) {
        'Host controller' { 'USB host controller — the chipset/driver that manages a group of USB ports.' }
        'Root hub' { 'USB root hub — Windows\' logical hub directly attached to the host controller.' }
        'USB hub' { 'USB hub — one upstream USB connection split into multiple downstream ports.' }
        'Hub logical port' { 'Logical USB hub port — this is a Windows/USB topology port, not necessarily a unique visible socket.' }
        'Storage interface' { 'USB storage interface — a disk/SSD/flash-drive function exposed through USB.' }
        default { 'Connected USB device or USB function.' }
    }

    $meaning = 'Windows has not confirmed the current USB signaling rate for this selection.'
    if ($speed -match 'SuperSpeedPlus') {
        $meaning = 'The connected path is operating at SuperSpeedPlus or higher. That confirms at least a USB 3.x high-speed path, but this probe cannot reliably distinguish 10 vs 20 Gb/s.'
    } elseif ($speed -match 'SuperSpeed') {
        $meaning = 'The connected path is operating at SuperSpeed (5 Gb/s class). That confirms the device + cable + socket path is currently using USB 3.x.'
    } elseif ($speed -match 'High-Speed') {
        if ($protocol -match 'USB 3') {
            $meaning = 'This logical port can expose USB 3.x, but the attached device is currently using USB 2.0 High-Speed (480 Mb/s signaling). The device, cable, adapter, or companion path may be limiting it.'
        } else {
            $meaning = 'The attached device is operating at USB 2.0 High-Speed (480 Mb/s signaling). This does not prove the visible socket is limited to USB 2.0.'
        }
    } elseif ($speed -match 'Full-Speed') {
        $meaning = 'The attached device is operating at USB Full-Speed (12 Mb/s), normally seen with older/low-bandwidth USB devices.'
    } elseif ($speed -match 'Low-Speed') {
        $meaning = 'The attached device is operating at USB Low-Speed (1.5 Mb/s), normally used by simple peripherals.'
    }

    $clue = 'No reliable physical color/shape can be inferred from Windows alone.'
    if ($protocol -match 'USB 3' -or $speed -match 'SuperSpeed') {
        $clue = 'Physical clue: on USB-A sockets, many manufacturers use blue/teal plastic or an SS/SuperSpeed mark, but color is NOT standardized and some fast ports are black/red/other colors. USB-C is the small oval reversible connector and may support anything from USB 2.0 to USB4.'
    } elseif ($protocol -match 'USB 2') {
        $clue = 'Physical clue: a black/white USB-A insert is often USB 2.0, but color is not proof. Use the detected link/protocol information and unplug/replug mapping instead.'
    }

    $placement = 'Desktop clue: motherboard rear-panel ports and front-case ports can BOTH be USB 3.x or faster. Do not assume rear = fast or front = slow; map the exact socket by unplugging/replugging the test device.'
    $map = if ($Record.PortNumber) { "Windows currently reports port number $($Record.PortNumber). Label this exact connection as Front-left, Rear-top, USB-C-right, etc. after verifying it physically." } else { 'No Windows port number is available for this selected node.' }

    $storageLines = @()
    if ($storage) {
        $storageLines += "Storage device: $($storage.Model)"
        $storageLines += "Windows disk: $($storage.PhysicalDrive)"
        if ($storage.SizeBytes) { $storageLines += "Capacity: $(Format-ByteSize $storage.SizeBytes)" }
        if ($storage.SerialNumber) { $storageLines += "Disk serial: $($storage.SerialNumber)" }
    }

    $lines = @(
        '=== EASY PORT SUMMARY ===',
        "Selected: $($Record.Name)",
        "What it is: $plainType",
        "Physical label: $label",
        "Connection state: $state",
        "Logical-port capability: $protocol",
        "Current attached-device link: $speed",
        '',
        'WHAT THAT MEANS',
        $meaning,
        '',
        'HOW TO FIND THIS SOCKET ON THE PC',
        $map,
        $clue,
        $placement,
        '',
        'IMPORTANT',
        '• Blue plastic is only a visual hint, not a guarantee of USB 3.x.',
        '• The SS logo is a useful SuperSpeed clue when present, but absence of the logo does not prove the port is slow.',
        '• USB-A/USB-C describes connector shape; it does not by itself tell you the USB speed.',
        '• Current link speed can be lower than the port maximum because of the device, cable, hub, adapter, or fallback companion path.',
        '• A USB 3.x physical socket can have separate USB 2.0 (HSxx) and USB 3.x (SSxx) logical paths.',
        ''
    ) + $storageLines
    return ($lines -join [Environment]::NewLine)
}

function Import-PortLabels {
    $script:PhysicalLabels = @{}
    if (-not (Test-Path -LiteralPath $script:LabelsFile)) { return }
    try {
        $json = Get-Content -LiteralPath $script:LabelsFile -Raw -Encoding UTF8 | ConvertFrom-Json
        foreach ($property in $json.PSObject.Properties) {
            $script:PhysicalLabels[$property.Name] = [string]$property.Value
        }
    } catch {
        [System.Windows.Forms.MessageBox]::Show(
            "Could not read saved physical-port labels: $($_.Exception.Message)",
            'USB Port Explorer', 'OK', 'Warning') | Out-Null
    }
}

function Get-PropertyText {
    param([hashtable]$Properties, [string]$Key)
    if (-not $Properties.ContainsKey($Key)) { return '' }
    $value = $Properties[$Key]
    if ($null -eq $value) { return '' }
    return (@($value) | ForEach-Object { [string]$_ }) -join '; '
}

function Get-UsbKind {
    param($Device)
    $name = [string]$Device.FriendlyName
    $id = [string]$Device.InstanceId
    if ($id -match '^PCI\\' -and $Device.Class -eq 'USB') { return 'Host controller' }
    if ($name -match 'Host Controller|xHCI Controller|USB Controller' -and $Device.Class -eq 'USB') {
        return 'Host controller'
    }
    if ($name -match 'USB4.*(Router|Host)' -or $id -match '^USB4\\') { return 'USB4 device/router' }
    if ($name -match '\bHub\b' -or $id -match '^USB\\ROOT_HUB') {
        if ($id -match '^USB\\ROOT_HUB' -or $name -match 'Root Hub') { return 'Root hub' }
        return 'USB hub'
    }
    if ($id -match '^USBSTOR\\') { return 'Storage interface' }
    if ($id -match '&MI_[0-9A-F]{2}') { return 'USB interface' }
    return 'USB device'
}

function Get-UsbVersionHint {
    param([string]$Name, [string]$Id, [string]$Kind)
    $value = "$Name $Id"
    if ($value -match 'USB\s*4\b|USB4') { return 'USB4 mentioned in device name/ID' }
    if ($value -match 'USB\s*3\.2') { return 'USB 3.2 mentioned in name' }
    if ($value -match 'USB\s*3\.1') { return 'USB 3.1 mentioned in name' }
    if ($value -match 'USB\s*3\.0|SuperSpeed|ROOT_HUB30') { return 'USB 3.x mentioned in name/ID' }
    if ($Kind -eq 'Host controller' -and $value -match 'xHCI|eXtensible') {
        return 'xHCI host controller (may support USB 2 and USB 3; port speed unknown)'
    }
    if ($value -match 'USB\s*2\.0|ROOT_HUB20|EHCI') { return 'USB 2.0 mentioned in name/ID' }
    return 'Not reported by standard Windows PnP properties'
}

function Get-PortKey {
    param($Record)
    if ($null -eq $Record) { return '' }
    # A location path identifies a connection route, unlike a device instance ID.
    if ($Record.Kind -eq 'Hub logical port' -and $Record.ParentId -and $Record.PortNumber) {
        return "$($Record.ParentId)|Port $($Record.PortNumber)"
    }
    if ($Record.LocationPath) { return $Record.LocationPath }
    if ($Record.ParentId -and $Record.PortLocation) {
        return "$($Record.ParentId)|$($Record.PortLocation)"
    }
    return ''
}

function Get-UsbInventory {
    $devices = @(Get-PnpDevice -PresentOnly -ErrorAction Stop | Where-Object {
        $_.InstanceId -match '^(USB|USBSTOR|USB4)\\' -or
        ($_.Class -eq 'USB' -and $_.InstanceId -match '^PCI\\') -or
        ($_.Class -eq 'USB4')
    })

    $results = [System.Collections.Generic.List[object]]::new()
    foreach ($device in $devices) {
        $props = @{}
        try {
            # One property query per device; missing/inaccessible properties are left blank.
            foreach ($p in @(Get-PnpDeviceProperty -InstanceId $device.InstanceId -ErrorAction Stop)) {
                if ($p.KeyName) { $props[[string]$p.KeyName] = $p.Data }
            }
        } catch {
            # Some drivers/devnodes do not expose every property to this process.
        }

        $id = [string]$device.InstanceId
        $name = [string]$device.FriendlyName
        if ([string]::IsNullOrWhiteSpace($name)) {
            $name = Get-PropertyText $props 'DEVPKEY_Device_DeviceDesc'
        }
        if ([string]::IsNullOrWhiteSpace($name)) { $name = '(Unnamed USB device)' }
        $kind = Get-UsbKind $device
        $paths = Get-PropertyText $props 'DEVPKEY_Device_LocationPaths'
        $location = Get-PropertyText $props 'DEVPKEY_Device_LocationInfo'
        $parent = Get-PropertyText $props 'DEVPKEY_Device_Parent'
        $portNumber = ''
        if ($location -match 'Port_#0*(\d+)') { $portNumber = $Matches[1] }
        elseif ($paths -match 'USB\((\d+)\)') {
            $allMatches = [regex]::Matches($paths, 'USB\((\d+)\)')
            if ($allMatches.Count -gt 0) { $portNumber = $allMatches[$allMatches.Count - 1].Groups[1].Value }
        }

        $results.Add([pscustomobject]@{
            Name          = $name
            Kind          = $kind
            Status        = [string]$device.Status
            Class         = [string]$device.Class
            InstanceId    = $id
            ParentId      = $parent
            PortNumber    = $portNumber
            PortLocation  = $location
            LocationPath  = $paths
            VersionHint   = Get-UsbVersionHint $name $id $kind
            Manufacturer  = Get-PropertyText $props 'DEVPKEY_Device_Manufacturer'
            Service       = Get-PropertyText $props 'DEVPKEY_Device_Service'
            BusReported   = Get-PropertyText $props 'DEVPKEY_Device_BusReportedDeviceDesc'
            HardwareIds   = Get-PropertyText $props 'DEVPKEY_Device_HardwareIds'
            CompatibleIds = Get-PropertyText $props 'DEVPKEY_Device_CompatibleIds'
            DeviceDesc     = Get-PropertyText $props 'DEVPKEY_Device_DeviceDesc'
            ClassGuid      = Get-PropertyText $props 'DEVPKEY_Device_ClassGuid'
            DriverKey      = Get-PropertyText $props 'DEVPKEY_Device_Driver'
            DriverVersion  = Get-PropertyText $props 'DEVPKEY_Device_DriverVersion'
            DriverDate     = Get-PropertyText $props 'DEVPKEY_Device_DriverDate'
            DriverInfPath  = Get-PropertyText $props 'DEVPKEY_Device_DriverInfPath'
            DriverProvider = Get-PropertyText $props 'DEVPKEY_Device_DriverProvider'
            EnumeratorName = Get-PropertyText $props 'DEVPKEY_Device_EnumeratorName'
            Address        = Get-PropertyText $props 'DEVPKEY_Device_Address'
            Capabilities   = Get-PropertyText $props 'DEVPKEY_Device_Capabilities'
            InstallDate    = Get-PropertyText $props 'DEVPKEY_Device_InstallDate'
            FirstInstallDate = Get-PropertyText $props 'DEVPKEY_Device_FirstInstallDate'
            LastArrivalDate  = Get-PropertyText $props 'DEVPKEY_Device_LastArrivalDate'
        })
    }
    return $results.ToArray()
}

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
$script:Form = New-Object System.Windows.Forms.Form
$script:Form.Text = 'USB Port Explorer Pro - USB topology + easy physical-port guide'
$script:Form.StartPosition = 'Manual'
# Do not let a changed Windows DPI/font scale expand the outer frame beyond
# the visible desktop. The Shown handler checks the actual screen as well.
$script:Form.AutoScaleMode = [System.Windows.Forms.AutoScaleMode]::None
$script:Form.Font = [System.Drawing.Font]::new('Segoe UI', 9)
$script:Form.Size = [System.Drawing.Size]::new(1200, 760)
$script:Form.MinimumSize = [System.Drawing.Size]::new(700, 480)

$top = New-Object System.Windows.Forms.Panel
$top.Dock = 'Top'
$top.Height = 51
$top.Padding = [System.Windows.Forms.Padding]::new(9, 9, 9, 6)
$script:Form.Controls.Add($top)

$topLayout = New-Object System.Windows.Forms.FlowLayoutPanel
$topLayout.Dock = 'Fill'
$topLayout.WrapContents = $false
$topLayout.AutoScroll = $true
$top.Controls.Add($topLayout)

$refreshButton = New-Object System.Windows.Forms.Button
$refreshButton.Text = 'Refresh devices'
$refreshButton.AutoSize = $true
$refreshButton.Height = 31
$topLayout.Controls.Add($refreshButton)

$exportButton = New-Object System.Windows.Forms.Button
$exportButton.Text = 'Export CSV'
$exportButton.AutoSize = $true
$exportButton.Height = 31
$topLayout.Controls.Add($exportButton)

$searchLabel = New-Object System.Windows.Forms.Label
$searchLabel.Text = '  Search:'
$searchLabel.AutoSize = $true
$searchLabel.Margin = [System.Windows.Forms.Padding]::new(6, 7, 3, 3)
$topLayout.Controls.Add($searchLabel)

$script:SearchText = New-Object System.Windows.Forms.TextBox
$script:SearchText.Width = 245
$script:SearchText.Margin = [System.Windows.Forms.Padding]::new(3, 4, 3, 3)
$topLayout.Controls.Add($script:SearchText)

$searchButton = New-Object System.Windows.Forms.Button
$searchButton.Text = 'Find'
$searchButton.AutoSize = $true
$searchButton.Height = 31
$topLayout.Controls.Add($searchButton)

$clearButton = New-Object System.Windows.Forms.Button
$clearButton.Text = 'Clear search'
$clearButton.AutoSize = $true
$clearButton.Height = 31
$topLayout.Controls.Add($clearButton)

$script:StatusLabel = New-Object System.Windows.Forms.Label
$script:StatusLabel.Dock = 'Bottom'
$script:StatusLabel.Height = 29
$script:StatusLabel.Padding = [System.Windows.Forms.Padding]::new(10, 6, 0, 0)
$script:StatusLabel.Text = 'Ready.'
$script:Form.Controls.Add($script:StatusLabel)

$split = New-Object System.Windows.Forms.SplitContainer
$split.Dock = 'Fill'
$split.Orientation = 'Vertical'
# Do not set SplitterDistance or panel minimums before Windows Forms has
# calculated the final size: the default 150px SplitContainer width can
# cause an exception on some machines when Panel2MinSize is assigned.
$script:Form.Controls.Add($split)
$top.BringToFront()
$script:StatusLabel.BringToFront()

$script:Tree = New-Object System.Windows.Forms.TreeView
$script:Tree.Dock = 'Fill'
$script:Tree.HideSelection = $false
$script:Tree.ShowNodeToolTips = $true
$split.Panel1.Controls.Add($script:Tree)

$detailsLayout = New-Object System.Windows.Forms.TableLayoutPanel
$detailsLayout.Dock = 'Fill'
$detailsLayout.ColumnCount = 1
$detailsLayout.RowCount = 4
$detailsLayout.Padding = [System.Windows.Forms.Padding]::new(10)
[void]$detailsLayout.RowStyles.Add(([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::Percent, 100)))
[void]$detailsLayout.RowStyles.Add(([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::Absolute, 34)))
[void]$detailsLayout.RowStyles.Add(([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::Absolute, 37)))
[void]$detailsLayout.RowStyles.Add(([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::Absolute, 49)))
$split.Panel2.Controls.Add($detailsLayout)

$tabs = New-Object System.Windows.Forms.TabControl
$tabs.Dock = 'Fill'
$detailsLayout.Controls.Add($tabs, 0, 0)

$easyTab = New-Object System.Windows.Forms.TabPage
$easyTab.Text = 'Easy summary'
$tabs.TabPages.Add($easyTab) | Out-Null

$technicalTab = New-Object System.Windows.Forms.TabPage
$technicalTab.Text = 'Technical details'
$tabs.TabPages.Add($technicalTab) | Out-Null

$script:EasyDetails = New-Object System.Windows.Forms.TextBox
$script:EasyDetails.Multiline = $true
$script:EasyDetails.ReadOnly = $true
$script:EasyDetails.ScrollBars = 'Vertical'
$script:EasyDetails.WordWrap = $true
$script:EasyDetails.Dock = 'Fill'
$script:EasyDetails.Font = [System.Drawing.Font]::new('Segoe UI', 10)
$script:EasyDetails.Text = 'Select a USB controller, hub, port, or connected device on the left.'
$easyTab.Controls.Add($script:EasyDetails)

$script:Details = New-Object System.Windows.Forms.TextBox
$script:Details.Multiline = $true
$script:Details.ReadOnly = $true
$script:Details.ScrollBars = 'Both'
$script:Details.WordWrap = $false
$script:Details.Dock = 'Fill'
$script:Details.Font = [System.Drawing.Font]::new('Consolas', 9)
$script:Details.Text = 'Select a USB controller, hub, port, or connected device on the left.'
$technicalTab.Controls.Add($script:Details)

$script:LabelHelp = New-Object System.Windows.Forms.Label
$script:LabelHelp.AutoSize = $false
$script:LabelHelp.Dock = 'Fill'
$script:LabelHelp.Text = 'Physical port labels: plug a device into a port, select the device, then label its location path.'
$detailsLayout.Controls.Add($script:LabelHelp, 0, 1)

$labelPanel = New-Object System.Windows.Forms.FlowLayoutPanel
$labelPanel.Dock = 'Fill'
$labelPanel.WrapContents = $false
$detailsLayout.Controls.Add($labelPanel, 0, 2)

$script:LabelText = New-Object System.Windows.Forms.TextBox
$script:LabelText.Width = 265
$script:LabelText.Enabled = $false
$labelPanel.Controls.Add($script:LabelText)

$script:SaveLabelButton = New-Object System.Windows.Forms.Button
$script:SaveLabelButton.Text = 'Save label'
$script:SaveLabelButton.AutoSize = $true
$script:SaveLabelButton.Enabled = $false
$labelPanel.Controls.Add($script:SaveLabelButton)

$note = New-Object System.Windows.Forms.Label
$note.Text = 'Easy summary explains speed vs port capability and gives safe physical clues (SS/logo/color/connector) without treating them as proof.'
$note.Dock = 'Fill'
$note.ForeColor = [System.Drawing.Color]::DarkRed
$detailsLayout.Controls.Add($note, 0, 3)

$refreshButton.Add_Click({ Refresh-UsbData })
$exportButton.Add_Click({ Export-UsbCsv })
$searchButton.Add_Click({ Show-UsbTree })
$clearButton.Add_Click({ $script:SearchText.Clear(); Show-UsbTree })
$script:SearchText.Add_KeyDown({
    param($sender, $eventArgs)
    if ($eventArgs.KeyCode -eq [System.Windows.Forms.Keys]::Enter) {
        Show-UsbTree
        $eventArgs.SuppressKeyPress = $true
    }
})
$script:Tree.Add_AfterSelect({
    param($sender, $eventArgs)
    if ($null -ne $eventArgs.Node -and $null -ne $eventArgs.Node.Tag) {
        Show-SelectedRecord $eventArgs.Node.Tag
    }
})
$script:SaveLabelButton.Add_Click({ Save-PhysicalLabel })
$script:Form.Add_Shown({
    # Fit the whole window, including its title bar and bottom controls,
    # within this monitor's *working* area (taskbar excluded). This also
    # handles displays where DPI scaling changes the effective frame size.
    $work = [System.Windows.Forms.Screen]::FromControl($script:Form).WorkingArea
    $safeWidth = [Math]::Max(400, [Math]::Min($script:Form.Width, $work.Width - 16))
    $safeHeight = [Math]::Max(360, [Math]::Min($script:Form.Height, $work.Height - 16))
    $script:Form.MinimumSize = [System.Drawing.Size]::new(
        [Math]::Min(700, $safeWidth), [Math]::Min(480, $safeHeight))
    $safeLeft = $work.Left + [Math]::Max(0, [int](($work.Width - $safeWidth) / 2))
    $safeTop = $work.Top + [Math]::Max(0, [int](($work.Height - $safeHeight) / 2))
    $script:Form.Bounds = [System.Drawing.Rectangle]::new(
        $safeLeft, $safeTop, $safeWidth, $safeHeight)

    # Now that Windows Forms has the final dimensions, position the splitter.
    # Avoid startup-only min-size constraints (the original crash).
    $availableWidth = $split.ClientSize.Width - $split.SplitterWidth
    if ($availableWidth -gt 100) {
        $leftWidth = [Math]::Min(460, [Math]::Max(25, $availableWidth - 330))
        $leftWidth = [Math]::Max(25, [Math]::Min($leftWidth, $availableWidth - 25))
        $split.SplitterDistance = [int]$leftWidth
    }
    Refresh-UsbData
})

Initialize-NativeUsbProbe
Import-PortLabels
[void]$script:Form.ShowDialog()
