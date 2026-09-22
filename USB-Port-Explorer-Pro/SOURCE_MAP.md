# Source Map — USB Port Explorer Pro

This page helps a non-developer understand where each part of the program lives.

## What to run

Normal users should run `Run_USB_Port_Explorer.bat`. Do not run files under `src/` individually.

```text
Run_USB_Port_Explorer.bat
        |
        v
USB_Port_Explorer.ps1
        |
        +--> loads the src/ files in order
        |
        +--> uses USB_Hub_Probe.cs for extra Windows USB hub information
```

## Source files in plain English

| File | What it does |
|---|---|
| `USB_Port_Explorer.ps1` | Small wrapper that checks and loads the source modules in the correct order. |
| `src/USB_Port_Explorer_Part1.ps1` | Startup helpers, storage mapping, native-probe bridge, and the Easy Summary text. |
| `src/USB_Port_Explorer_Part2.ps1` | Reads Windows Plug-and-Play devices, parents, port/location paths, IDs, drivers, and related properties. |
| `src/USB_Port_Explorer_Part3.ps1` | Builds Technical Details and the controller/hub/device tree shown in the GUI. |
| `src/USB_Port_Explorer_Part4A.ps1` | Refreshes Windows data and combines PnP nodes with logical USB hub ports. |
| `src/USB_Port_Explorer_Part4B.ps1` | CSV export plus saving/removing human physical-port labels. |
| `src/USB_Port_Explorer_Part5A.ps1` | Creates the Windows Forms layout, tabs, search controls, details boxes, and label controls. |
| `src/USB_Port_Explorer_Part5B.ps1` | Connects buttons/events, performs safe screen sizing, positions the splitter after layout, refreshes data, and opens the window. |
| `USB_Hub_Probe.cs` | Read-only Windows USB hub queries for logical-port protocol support and current connection-speed clues. |
| `Run_USB_Port_Explorer.bat` | Double-click launcher for Windows users. |

## How information is combined

```text
Windows Plug and Play
  -> name / parent / IDs / driver / location / port number
                                  |
Windows USB hub information ------+--> logical-port protocol and link clue
                                  |
Windows disk inventory -----------+--> PhysicalDrive / model / serial / capacity
                                  |
Saved label JSON -----------------+--> Rear top, Front left, USB-C right, etc.
                                  |
                                  v
                     Easy Summary + Technical Details
```

These sources answer different questions, so the application keeps them separate rather than guessing.

## A key rule in this project

The code does not treat any one of the following as proof of the maximum speed of the physical socket:

- `Port 3`
- an xHCI controller name
- `ROOT_HUB30`
- `HS03`
- blue plastic
- an `SS` mark
- USB-A versus USB-C shape
- front versus rear case location

Those can be useful clues. The application explains what Windows actually reported and tells the user when a conclusion still needs a physical test with a known-capable device and cable.

## Where to make common changes

| Goal | Start here |
|---|---|
| Change beginner explanations | `src/USB_Port_Explorer_Part1.ps1` |
| Add another Windows device property | `src/USB_Port_Explorer_Part2.ps1` |
| Add a Technical Details field | `src/USB_Port_Explorer_Part3.ps1` |
| Change refresh/topology behavior | `src/USB_Port_Explorer_Part4A.ps1` |
| Add CSV fields or change saved labels | `src/USB_Port_Explorer_Part4B.ps1` |
| Change the GUI layout | `src/USB_Port_Explorer_Part5A.ps1` |
| Change button/event or startup sizing behavior | `src/USB_Port_Explorer_Part5B.ps1` |
| Change low-level USB hub queries | `USB_Hub_Probe.cs` |

## Generated files

The application writes local reports and labels under `USB_Port_Explorer_Reports/`. That folder is ignored by Git so machine-specific hardware details are not accidentally committed.
