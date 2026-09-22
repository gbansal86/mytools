<#
Source module 2 of 5 for USB Port Explorer Pro.
This file is loaded by USB_Port_Explorer.ps1. Run the root launcher rather than this module directly.
The split keeps the project easier to read on GitHub; functional statements are kept in original order.
#>

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

