# Technical Notes — USB Port Explorer Pro

This document explains how the program obtains its information and why its output is intentionally separated into **PnP metadata**, **logical USB-port information**, and **physical-port interpretation**.

## Architecture

The program has two runtime components.

### `USB_Port_Explorer.ps1`

The PowerShell layer is responsible for:

- Windows Forms GUI
- `Get-PnpDevice` enumeration
- `Get-PnpDeviceProperty` metadata collection
- parent/child topology reconstruction
- Windows location paths and port numbers
- device classification for the tree
- driver metadata
- storage inventory through `Win32_DiskDrive`
- best-effort USB-to-disk matching
- Easy Summary generation
- physical-port labels
- search and CSV export
- graceful fallback when native hub probing is unavailable

### `USB_Hub_Probe.cs`

The C# helper is compiled in memory by PowerShell with `Add-Type`. It uses documented Windows SetupAPI and USB hub IOCTL calls.

It does **not** install a kernel driver.

The helper:

1. Enumerates present USB hub device interfaces.
2. Obtains each hub device path and PnP instance ID.
3. Opens the hub interface using `CreateFile`.
4. Requests hub information and the number of downstream logical ports.
5. Queries each logical port for connection/protocol information.
6. Returns a small in-memory object model to the PowerShell GUI.

## Windows interfaces used

The helper uses standard Windows functions including:

- `SetupDiGetClassDevs`
- `SetupDiEnumDeviceInterfaces`
- `SetupDiGetDeviceInterfaceDetail`
- `SetupDiGetDeviceInstanceId`
- `CreateFile`
- `DeviceIoControl`

The principal USB requests used are:

- `IOCTL_USB_GET_NODE_INFORMATION`
- `IOCTL_USB_GET_NODE_CONNECTION_INFORMATION_EX`
- `IOCTL_USB_GET_NODE_CONNECTION_INFORMATION_EX_V2`

Microsoft Learn references:

- https://learn.microsoft.com/windows-hardware/drivers/ddi/usbioctl/ni-usbioctl-ioctl_usb_get_node_information
- https://learn.microsoft.com/windows-hardware/drivers/ddi/usbioctl/ni-usbioctl-ioctl_usb_get_node_connection_information_ex
- https://learn.microsoft.com/windows-hardware/drivers/ddi/usbioctl/ni-usbioctl-ioctl_usb_get_node_connection_information_ex_v2
- https://learn.microsoft.com/windows-hardware/drivers/install/setupapi

## Why normal PnP properties are not enough

PnP information can tell us a great deal about a node — friendly name, parent, hardware IDs, service, location path, driver metadata, and more — but a name such as `USB Root Hub (USB 3.0)` does not prove that a specific connected device is currently using SuperSpeed.

Likewise, a device may be attached to an xHCI controller while currently negotiating only USB 2.0 High-Speed.

The native hub query adds connection-state and protocol clues for the downstream logical port.

## Mapping a PnP node to a native hub port

A port number alone is not globally unique. Many hubs can each have `Port 1`, `Port 2`, etc.

The application therefore uses a compound relationship:

```text
Parent hub PnP instance ID + child port number
```

The PowerShell code can also walk upward through interface/storage child nodes until it finds a parent/port pair that matches the native hub scan.

This avoids incorrectly assigning `Port 3` from one hub to a device on `Port 3` of another hub.

## Logical ports versus visible physical sockets

Windows USB topology is logical. A visible USB-A socket can have companion paths, for example:

- a USB 2.0 High-Speed path
- a USB 3.x SuperSpeed path

Which path appears depends on the attached device and cable.

Therefore the application avoids treating a single logical node as definitive proof of a visible connector's complete capabilities.

## Link speed versus real transfer speed

The values shown by the native probe are **signaling modes**, not benchmark results.

Examples:

| Driver-reported mode | Nominal signaling class | Practical meaning |
|---|---:|---|
| Low-Speed | 1.5 Mb/s | Very low-bandwidth USB 1.x device |
| Full-Speed | 12 Mb/s | USB 1.x-class connection |
| High-Speed | 480 Mb/s | USB 2.0-class signaling |
| SuperSpeed | 5 Gb/s | USB 3.x SuperSpeed path |
| SuperSpeedPlus or higher | above the basic SuperSpeed class | Exact 10/20 Gb/s distinction is not guaranteed by this implementation |

Real file-transfer speed can be much lower because of the disk, flash memory, filesystem, protocol overhead, encryption, CPU load, hub sharing, and other factors.

## Device and disk nodes are separate

USB storage commonly appears as several related Windows nodes:

```text
USB device
  -> USB interface
     -> USBSTOR disk node
        -> Windows disk / PhysicalDrive
```

`Win32_DiskDrive` exposes storage information such as:

- `DeviceID` (`\\.\PhysicalDriveN`)
- model
- serial number
- size
- interface/media type

The PowerShell layer performs a best-effort match using PnP IDs and serial-like identifiers. A match can fail when a bridge, enclosure, RAID layer, virtual disk, or driver changes the identifiers.

## Physical-port labels

A human label is stored against a connection route rather than a device serial where possible. This is intentional: the goal is to remember **which socket/path** was labeled, regardless of which USB device is connected later.

Saved labels live in:

```text
USB_Port_Explorer_Reports\Physical_Port_Labels.json
```

## Why the program does not trust port color

USB connector color is not a reliable API-level property and is not consistently standardized by PC manufacturers.

The Easy Summary therefore treats:

- blue/teal plastic
- `SS` / SuperSpeed logos
- red/yellow/black inserts
- USB-A / USB-C shape
- front/rear placement

as physical clues only.

## Read-only design

The program intentionally excludes actions that could change device state. There are no commands to:

- disable/enable a USB device
- uninstall a device or driver
- modify registry values
- alter selective suspend / power policy
- format/eject/write to disks
- change firmware

The `CreateFile` handle in the native helper is used to query the Windows USB hub driver with `DeviceIoControl`; the tool does not issue write commands to attached storage.

## Error handling and fallback

Native probing can fail for some hubs. Causes can include:

- a hub driver that does not expose the queried interface
- access restrictions
- older/nonstandard hardware
- virtual/remote USB stacks
- an unexpected structure/driver behavior

When this occurs, the program keeps the PnP inventory and marks native data as unavailable instead of failing the entire GUI.

## Development/testing note

USB behavior is highly hardware-dependent. Any change to the native structures, offsets, IOCTL buffer handling, or parent/port mapping should be tested on multiple Windows 10/11 machines and with USB 2.0, USB 3.x, hubs, storage devices, and USB-C hardware before being considered broadly validated.
