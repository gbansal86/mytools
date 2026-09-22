# Package QA / Validation Notes

## What was checked before publication

- Launcher and phase paths were checked for consistency.
- The corrected launcher checks required files before elevation.
- The corrected launcher asks the Windows PowerShell parser to parse every `.ps1` file before running a phase.
- Menu choices map to explicit phase scripts through `Dispatch.ps1`.
- Repair mode has a dry-run path and confirmation prompts.
- Post-repair comparison requires post-repair baseline output.
- Runtime output folders are ignored by Git through `.gitignore`.
- Documentation distinguishes collected telemetry from deeply analyzed/automated behavior.

## What must be validated on an actual Windows PC

Windows-only behavior depends on the machine. Run **menu option 11 — Self-test** first. In particular, actual availability varies for:

- Storage module cmdlets such as `Get-StorageReliabilityCounter`
- SMART WMI provider classes
- GPU performance counters
- ACPI thermal-zone telemetry
- Defender cmdlets
- Event Log channels
- Secure Boot
- battery telemetry
- permissions/elevation
- DISM/SFC servicing state

A missing optional source should be treated as unavailable telemetry, not as evidence that the component is healthy.

## Repair QA rule

Always use **menu option 5 — DRY RUN** before menu option 6. Back up irreplaceable files before repairs. If storage or WHEA findings indicate possible physical failure, prioritize data protection/hardware investigation over optimization.
