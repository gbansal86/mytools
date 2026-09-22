<#
Source module 1 of 5 for USB Port Explorer Pro.
This file is loaded by USB_Port_Explorer.ps1. Run the root launcher rather than this module directly.
The split keeps the project easier to read on GitHub; functional statements are kept in original order.
#>

<#
USB Port Explorer Pro
=====================

BEGINNER SUMMARY
----------------
This is the main Windows PowerShell GUI. It reads USB information that Windows
already exposes and presents it in two ways:
  1. Easy Summary     - plain-English explanation for normal users.
  2. Technical Details - PnP IDs, drivers, location paths, protocol clues, etc.

The script is READ-ONLY with respect to USB devices. It does not install drivers,
change the registry, change USB power settings, format disks, or modify files on
connected devices.

HOW THE FILES WORK TOGETHER
---------------------------
- USB_Port_Explorer.ps1 : GUI, PnP inventory, storage matching, labels, CSV export.
- USB_Hub_Probe.cs      : low-level Windows USB hub queries for logical-port
                          protocol support and current device link-speed clues.
- Run_USB_Port_Explorer.bat : simple double-click launcher.

IMPORTANT TERMINOLOGY
---------------------
"Current link speed" is the signaling mode Windows reports for the attached
USB path. It is NOT a benchmark result and is NOT automatically the maximum
speed of the visible physical socket.

A blue/teal insert, an SS logo, USB-A/USB-C shape, or front/rear location can be
useful physical clues, but none of those alone proves a USB version or speed.
#>

$ErrorActionPreference = 'Stop'

try {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
} catch {
    Write-Host "Unable to load Windows Forms: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

[System.Windows.Forms.Application]::EnableVisualStyles()

$script:OutputFolder = Join-Path $script:AppRoot 'USB_Port_Explorer_Reports'
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
    $cs = Join-Path $script:AppRoot 'USB_Hub_Probe.cs'
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
        'Root hub' { 'USB root hub — Windows'' logical hub directly attached to the host controller.' }
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

