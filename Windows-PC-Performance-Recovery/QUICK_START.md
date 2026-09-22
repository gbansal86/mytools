# Quick Start for Beginners

This page assumes you are not a Windows administrator or PowerShell expert.

## Step 1 — Download and extract

![Step 1 — Download and extract](docs/images/step-01-download-extract.svg)

From the main `mytools` repository page choose **Code → Download ZIP** (or clone the repository), extract it, then open the `Windows-PC-Performance-Recovery` folder.

After downloading:

1. Right-click the ZIP.
2. Choose **Extract All...**.
3. Pick a normal local folder such as `C:\PC-Tools\Windows-PC-Recovery`.
4. Open the extracted folder.

Do **not** double-click `00_START_HERE.bat` while still viewing the ZIP contents.

## Step 2 — Start the toolkit

![Step 2 — Start the toolkit and approve UAC](docs/images/step-02-launch-uac.svg)

Double-click:

```text
00_START_HERE.bat
```

Windows may show a User Account Control prompt asking whether to allow Windows PowerShell to make changes. Choose **Yes** if you want complete diagnostics and repair capability.

If the window appears and disappears, see [TROUBLESHOOTING.md](TROUBLESHOOTING.md).

## Step 3 — Run the self-test

![Step 3 — Run the self-test](docs/images/step-03-self-test.svg)

At the menu, choose:

```text
11
```

The self-test checks:

- Windows PowerShell version
- Administrator status
- commands the toolkit needs
- optional storage/device commands
- write permission in the package folder
- PowerShell syntax of every `.ps1` file

It writes `SELF_TEST_REPORT.txt` in the package folder.

If a required item says `FAIL`, fix that before trusting the diagnostics.

## Step 4 — Collect the full baseline + diagnostics + analysis

![Step 4 — Run full pre-repair scan](docs/images/step-04-run-full-scan.svg)

Choose:

```text
1
```

This runs Phases A, B and C.

### Phase A — Baseline

Takes repeated CPU/RAM/disk/process measurements before any repair.

### Phase B — Full diagnostics

Collects the detailed system/hardware evidence.

### Phase C — Local analysis

Produces conservative findings and the repair plan.

Nothing in this A+B+C sequence is intended to apply the repair plan.

## Step 5 — Read the important reports

![Step 5 — Review reports](docs/images/step-05-review-reports.svg)

Open the newest folder under `Runs` and look for the analysis output.

Read these first:

```text
ANALYSIS_REPORT.txt
HARDWARE_HEALTH_REPORT.txt
FINDINGS.csv
REPAIR_PLAN.json
```

Pay special attention to warnings about storage failure, WHEA hardware errors or memory/hardware instability.

## Step 6 — Preview repairs without changing Windows

![Step 6 — Repair dry run](docs/images/step-06-dry-run.svg)

Return to the main menu and choose:

```text
5
```

This is **DRY RUN** mode. It shows what the repair phase would do without applying the changes.

If the dry run proposes something you do not understand, stop and review it before using option 6.

## Step 7 — Apply approved conservative repairs

![Step 7 — Apply repairs](docs/images/step-07-apply-repairs.svg)

Choose:

```text
6

```

The repair script requires confirmation. It logs its actions.

Do not use this as a substitute for replacing failing hardware.

## Step 8 — Reboot when needed

Some Windows repairs do not fully take effect until restart. If DISM/SFC/Windows reports a restart requirement, reboot before the post-repair comparison.

## Step 9 — Measure again

![Step 8 — Post-repair retest](docs/images/step-08-post-repair.svg)

Choose:

```text
7
```

This repeats the diagnostics and builds before/after reports.

Important: compare performance only when the PC is under roughly similar workload conditions.

## Step 10 — Track hardware over time

![Step 9 — Hardware history](docs/images/step-09-hardware-history.svg)

Choose:

```text
8
```

This creates historical hardware/trend files from previous runs. Repeated growth in errors is often more meaningful than one isolated snapshot.

## Step 11 — Export for expert review

![Step 10 — Export latest run](docs/images/step-10-export-results.svg)

Choose:

```text
9
```

The toolkit creates a ZIP of the latest run. Review it for private information before sharing it publicly.
