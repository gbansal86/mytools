# How the Toolkit Works

## The design principle

The tool follows this lifecycle:

**Baseline → Diagnose → Analyze → Dry run → Repair → Re-test → Compare → Trend**

It is intentionally different from a generic “PC optimizer” that applies dozens of registry/service tweaks without proving they are needed.

## Phase A — Baseline

Script: `Toolkit/Phases/Phase_A_Baseline.ps1`

Purpose: measure the PC before repair so later results can be compared.

It takes multiple samples of CPU, memory and aggregate disk counters, plus top RAM/CPU processes and basic system-drive state.

## Phase B — Full diagnostic and hardware health

Script: `Toolkit/Phases/Phase_B_FullDiagnostic.ps1`

This is the largest evidence-collection phase. It writes structured CSV/TXT data covering system inventory, storage, devices, Event Logs, startup/services/tasks, drivers, Windows health, networking, power/battery, virtualization, browser/process impact and related areas.

A key safety rule is that Phase B is meant to **observe**, not optimize.

## Phase C — Analysis

Script: `Toolkit/Phases/Phase_C_Analyze.ps1`

It reads the latest diagnostic run, applies conservative local rules and produces:

- `FINDINGS.csv`
- `ANALYSIS_REPORT.txt`
- `HARDWARE_HEALTH_REPORT.txt`
- `REPAIR_PLAN.json`

The current analyzer does not deeply interpret every file Phase B collects. See [KNOWN_LIMITATIONS.md](KNOWN_LIMITATIONS.md).

## Phase D — Repair

Script: `Toolkit/Phases/Phase_D_Repair.ps1`

Supports:

- dry run
- confirmation before applying repairs
- restore-point attempt where possible
- repair logging
- selected low-risk cleanup/Windows integrity actions when enabled by the repair plan

It intentionally avoids high-risk generic changes.

## Phase E — Post-repair diagnostics

Script: `Toolkit/Phases/Phase_E_PostRepair.ps1`

Runs comparable measurements after repair.

## Phase F — Before/after comparison

Script: `Toolkit/Phases/Phase_F_Compare.ps1`

Compares selected pre/post metrics and writes the final comparison/report.

A lower number does not automatically mean “better” if the workload was different, so the report includes interpretation cautions.

## Phase G — Hardware trend

Script: `Toolkit/Phases/Phase_G_HardwareTrend.ps1`

Combines snapshots across multiple runs so you can see whether certain available hardware/error values are changing over time.

## Launcher and dispatcher

`00_START_HERE.bat` starts `Toolkit/Launch.ps1`.

The launcher:

- locates Windows PowerShell
- checks required package files
- parses PowerShell scripts before elevation
- requests Administrator rights
- waits for the elevated process
- logs startup errors to `%TEMP%\PC_Recovery_Startup_*.log`
- keeps errors visible instead of silently closing
- sends menu actions to `Toolkit/Dispatch.ps1`

## Why the toolkit asks for Administrator access

Some Windows data sources and repairs are restricted. Without elevation, results may be incomplete. The self-test reports whether Administrator access is present.
