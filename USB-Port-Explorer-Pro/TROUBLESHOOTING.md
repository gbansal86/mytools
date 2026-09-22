# Troubleshooting — USB Port Explorer Pro

## The window is cut off

Use the latest version in this folder. The GUI calculates the SplitContainer layout only after Windows has created the final form size, which avoids the `Panel2MinSize` / `SplitterDistance` startup error seen on some DPI/display configurations.

If the window still does not fit:

1. Maximize it.
2. Temporarily reduce Windows display scaling.
3. Confirm you are running the latest `USB_Port_Explorer.ps1` from the same folder as the launcher.

## `Panel2MinSize` / `SplitterDistance` exception

An older build could fail with a message similar to:

```text
Exception setting "Panel2MinSize":
"SplitterDistance must be between Panel1MinSize and Width - Panel2MinSize."
```

Replace the old script with the current version. Do not keep an old `USB_Port_Explorer.ps1` beside a new launcher.

## Native probe unavailable

The status bar may report that the native hub query is unavailable while the normal PnP tree still works.

Check that `USB_Hub_Probe.cs` is in the **same folder** as `USB_Port_Explorer.ps1`.

Then:

1. Close the program.
2. Re-extract the whole folder.
3. Run `Run_USB_Port_Explorer.bat` again.

Some hardware/driver combinations simply do not return every USB hub query. PnP information remains usable.

## Link speed says `Unknown` or `Not available`

This does not necessarily mean the port is slow. It means the selected node could not be confidently mapped to a native hub connection result or the hub driver did not return that field.

Try selecting:

- the connected USB device rather than one of its child interfaces
- the corresponding `USB port N` node under its hub
- the parent hub

Then click **Refresh devices**.

## The device is on an xHCI/USB 3 controller but shows High-Speed

That can be normal. High-Speed means the **current path** is using USB 2.0-class signaling.

Possible reasons include:

- the device is USB 2.0 only
- the cable is USB 2.0 only
- an adapter/hub is limiting the path
- the physical USB-A socket's USB 2 companion path is the one currently active
- a connector/cable problem prevented SuperSpeed negotiation

Test with a known USB 3.x device and known-good SuperSpeed cable.

## `Port 3` — does that mean USB 3.0?

No. `Port 3` is only the third logical port on a particular hub. It says nothing about USB generation.

Use the logical-port protocol and current link-speed fields instead.

## `HS03` in the location path — does that mean USB 3?

No. `HS` commonly refers to a USB 2.0 High-Speed companion path. A visible socket may also have a separate SuperSpeed companion path.

Do not infer the full physical connector capability from `HS03` alone.

## Blue plastic — is it definitely USB 3?

No. Blue/teal is a common manufacturer convention for USB 3.x USB-A ports, but it is not universal.

Treat color as a clue and confirm with the program using a known USB 3.x device/cable.

## USB-C — is it automatically fast?

No. USB-C is a connector shape. USB-C ports can expose very different capabilities.

This program does not comprehensively determine Power Delivery, charging wattage, DisplayPort Alt Mode, or Thunderbolt support.

## Storage information is blank

The selected USB node may not map cleanly to a `Win32_DiskDrive` instance.

Try selecting the `USBSTOR` / storage-interface child in the tree. Storage matching is best-effort and can be obscured by enclosures, bridges, RAID controllers, card readers, or vendor drivers.

## The drive size looks different from Windows Explorer

The application may show both decimal TB/GB and binary TiB/GiB.

For example, a manufacturer may sell a drive as 4.0 TB (decimal), while binary conversion is about 3.64 TiB. That is normal unit conversion, not lost storage.

## Search returns nothing

Clear the search and click **Refresh devices**. Then try a shorter term such as:

```text
WD
Passport
USBSTOR
Port 3
1058
```

## Saved label is wrong

Select the relevant connection path, clear or replace the physical-port label, and save again.

To reset all labels, close the program and delete:

```text
USB_Port_Explorer_Reports\Physical_Port_Labels.json
```

This does not affect USB devices or drivers.

## PowerShell execution-policy message

Use `Run_USB_Port_Explorer.bat`. It starts PowerShell with a process-scoped execution-policy option; it does not permanently change the machine's configured execution policy.

In managed corporate environments, security policy may still block scripts. In that case, use your organization's approved process rather than disabling security controls.

## Windows says a hub cannot be opened

The program may show a native-query warning but continue.

Possible causes include:

- driver restrictions
- virtual USB hardware
- unusual vendor USB stacks
- an interface disappearing during refresh
- Windows permission/policy restrictions

The PnP tree can still be useful even when one native hub cannot be queried.

## Reporting a problem

When reporting an issue, include:

- Windows 10/11 version
- whether Windows PowerShell 5.1 was used
- the status-bar native hub summary
- the selected node's **Technical Details** text with personal labels/serial numbers redacted if desired
- what type of device/cable was connected
- which physical socket was being tested
- exact error text or screenshot

Do not post disk serial numbers or other identifiers publicly unless you are comfortable sharing them.
