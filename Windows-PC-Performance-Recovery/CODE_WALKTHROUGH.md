# Code Walkthrough — Plain English

You do not need to understand PowerShell to use the toolkit. This page explains the main code path.

## 1. `00_START_HERE.bat`

This tiny BAT file is the front door.

It does four things:

1. prints a visible startup message
2. finds Windows PowerShell
3. verifies `Toolkit\Launch.ps1` exists
4. starts the PowerShell launcher and **pauses if it returns an error**

That final behavior is important because an older launcher could appear to do nothing when UAC/elevation failed.

## 2. `Toolkit/Launch.ps1`

Think of this as the receptionist.

It:

- creates a startup transcript in `%TEMP%`
- verifies PowerShell 5.1+
- verifies the phase files exist
- asks the PowerShell parser to syntax-check every `.ps1`
- checks Administrator rights
- safely asks Windows for elevation if required
- shows the numbered menu
- calls `Dispatch.ps1` for the selected action
- keeps errors visible

## 3. `Toolkit/Dispatch.ps1`

This is the traffic controller. It maps menu choices to scripts.

For example:

```text
Menu 1 -> Run_PreRepair_ABC.ps1
Menu 5 -> Phase_D_Repair.ps1 -DryRun
Menu 6 -> Phase_D_Repair.ps1
Menu 7 -> Phase_E_PostRepair.ps1, then Phase_F_Compare.ps1
Menu 11 -> SelfTest.ps1
```

## 4. `Toolkit/Core/Common.ps1`

Shared helper functions live here so every phase does not have to repeat the same code.

Helpers cover things such as:

- checking Administrator state
- creating/finding run folders
- writing logs
- writing CSV/TXT output safely

## 5. Phase A

`Phase_A_Baseline.ps1` measures CPU, memory and disk activity repeatedly before repair.

Why repeated samples? One random CPU spike should not automatically be called a bottleneck.

## 6. Phase B

`Phase_B_FullDiagnostic.ps1` is the main collector. It asks Windows for broad evidence and saves structured files under the current run folder.

It is intentionally much larger than the other scripts because it covers many categories.

## 7. Phase C

`Phase_C_Analyze.ps1` reads selected Phase B evidence and creates findings plus `REPAIR_PLAN.json`.

It is intentionally conservative. The current analyzer does **not** deeply interpret every diagnostic artifact; see `KNOWN_LIMITATIONS.md`.

## 8. Phase D

`Phase_D_Repair.ps1` is the part that can change Windows.

Use dry-run first. The repair script only acts on enabled repair-plan items and intentionally leaves many risky actions manual.

## 9. Phases E and F

After repair, Phase E re-runs measurement/diagnostics. Phase F compares pre/post values and writes a final summary.

## 10. Phase G

Phase G reads snapshots from multiple previous runs to help identify changes over time, especially available storage reliability/error values.

## Why the code is split into phases

Keeping phases separate makes the toolkit easier to audit and reduces the risk of mixing diagnostic commands with repair commands. It also lets advanced users run only the phase they need.
