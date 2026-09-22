CORRECTED LAUNCHER: Extract the entire repository/ZIP, then double-click 00_START_HERE.bat.
Approve the administrator prompt. Choose 11 for self-test.
Errors remain visible. Logs: %TEMP%\PC_Recovery_Startup_*.log

WINDOWS PERFORMANCE + HARDWARE HEALTH MASTER PACKAGE v2.0
========================================================

START HERE
----------
1. Download/clone this repository and open the Windows-PC-Performance-Recovery folder.
2. Double-click 00_START_HERE.bat. Approve the Administrator prompt.
3. First run option 11: toolkit self-test / syntax / capability check.
4. Choose option 1: Phases A + B + C.
5. Review ANALYSIS_REPORT.txt, HARDWARE_HEALTH_REPORT.txt and REPAIR_PLAN.json.
6. Run Phase D in DRY RUN mode before applying anything.
7. If the dry run looks appropriate, run Phase D APPLY.
8. Reboot if Windows/repair output requires it.
9. Run Phase E + F to re-test and create BEFORE_AFTER_COMPARISON.txt.
10. Use Phase G after future runs to track hardware degradation over time.
11. Use Export latest run to create a ZIP that can be uploaded for deeper review.

SAFETY MODEL
------------
- Diagnostics run before repairs.
- Local analysis is conservative and evidence-gated.
- Missing telemetry is NOT considered proof of health.
- Storage failure/WHEA/hardware warnings are escalated instead of "optimized".
- The repair phase does NOT automatically install drivers, flash BIOS, disable security,
  disable services/startup entries, uninstall software, alter pagefile, run offline CHKDSK,
  perform registry hacks, or run hardware stress tests.
- Safe cleanup deletes only old entries in Windows/user TEMP locations, never Downloads,
  Documents, Desktop, browser profiles, passwords, cookies, source code, or project folders.
