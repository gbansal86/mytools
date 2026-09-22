# Known Limitations / Implementation Status

This section is intentionally explicit so users are not misled by the number of files collected.

## Important distinction

**Collected** does not always mean **deeply analyzed**, and **analyzed** does not always mean **automatically repaired**.

### Areas that are broad in collection but shallower in automated analysis

- startup-entry classification
- services analysis
- scheduled-task analysis
- driver age/problem correlation
- boot/login-delay root-cause attribution
- network-consumer analysis
- detailed power-plan interpretation
- GPU utilization/memory-pressure interpretation
- application crash grouping by module/root cause
- Windows Update failure classification

### Storage-health limitations

Windows does not expose every vendor SMART/NVMe value in a uniform way.

The current package captures Windows storage reliability information and provider data where available, but it does **not fully decode every vendor-specific SMART attribute**. In particular, do not assume raw `VendorSpecific` SMART bytes have a universal meaning across all drives.

Detailed NVMe values such as Available Spare, Critical Warning, Data Units Written/Read, Controller Busy Time and Error Information Log entries may not all be present through the generic Windows interfaces used by this version.

### Hardware interpretation limitations

- WHEA events are collected/counted, but component-level decoding is not exhaustive.
- RAM usage pressure is not the same thing as failing RAM.
- built-in Windows temperature telemetry is inconsistent; missing temperature data is not proof of healthy cooling.
- PSU condition cannot normally be measured directly by standard Windows commands.
- BIOS/firmware updates are deliberately manual.

### Repair coverage

The automatic repair phase is intentionally smaller than the diagnostic phase. The current version focuses on conservative Windows integrity/cleanup actions. It does not automatically repair every issue that Phase B may detect.

### Rollback/reboot

The package attempts safe pre-repair protection such as restore-point creation where supported and logs repair actions. It is not a full transactional rollback system for every Windows setting, and it does not automatically resume itself across every reboot scenario.

### Testing limitation

The original package was statically/structurally validated and includes a Windows-side self-test, but the Windows-only diagnostic and repair commands cannot be exhaustively validated on every possible hardware/vendor configuration in advance.
