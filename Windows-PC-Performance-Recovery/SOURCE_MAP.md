# Source Map — What Each File Does

This page is for people who want to understand the code without reading every PowerShell line.

## Top level

| File/folder | Purpose |
|---|---|
| `00_START_HERE.bat` | Main beginner entry point. Finds Windows PowerShell and launches the safer PowerShell launcher. |
| `Toolkit/` | Runtime scripts and phase logic. |
| `Runs/` | Diagnostic output created on the user's PC. |
| `History/` | Cross-run hardware trend output. |
| `Docs/` | Original package QA/phase notes. |
| `docs/images/` | GitHub visual guides added for this repository. |

## Toolkit launcher

| File | Purpose |
|---|---|
| `Toolkit/Launch.ps1` | Validates required files/syntax, obtains Administrator access, shows the menu and keeps errors visible. |
| `Toolkit/Dispatch.ps1` | Converts menu choices into phase script calls. |
| `Toolkit/00_MASTER_MENU.bat` | Alternate BAT entry point inside the Toolkit folder. |
| `Toolkit/Core/Common.ps1` | Shared helper functions for runs, logging, CSV/text output and admin checks. |

## Phases

| File | Phase | Purpose |
|---|---|---|
| `Phase_A_Baseline.ps1` | A | Repeated pre-change CPU/RAM/disk/process measurements. |
| `Phase_B_FullDiagnostic.ps1` | B | Broad system, storage, hardware, Windows, driver, Event Log, network, power and application evidence collection. |
| `Phase_C_Analyze.ps1` | C | Conservative local findings + repair plan generation. |
| `Phase_D_Repair.ps1` | D | Dry-run / conservative repair engine. |
| `Phase_E_PostRepair.ps1` | E | Repeats measurements after repair. |
| `Phase_F_Compare.ps1` | F | Before/after comparison and final executive report. |
| `Phase_G_HardwareTrend.ps1` | G | Combines available hardware/error snapshots across runs. |
| `Run_PreRepair_ABC.ps1` | A+B+C | Convenience wrapper for the recommended pre-repair sequence. |
| `SelfTest.ps1` | Utility | Checks commands, permissions and PowerShell syntax. |
| `Export_Latest_Run.ps1` | Utility | Creates a ZIP of the latest run. |

## BAT wrappers

The `RUN_PHASE_*.bat` files are convenience launchers. They all route through the fixed PowerShell launcher so errors and elevation are handled consistently.
