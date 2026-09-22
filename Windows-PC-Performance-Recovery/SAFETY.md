# Safety Model

## What the toolkit is designed to protect

The package is deliberately conservative. It does not treat “more cleanup” as “more speed.”

### Diagnostics before repair

The intended sequence is always:

1. measure
2. collect evidence
3. analyze
4. dry-run the repair
5. apply approved repairs
6. re-test

### Hardware warnings take priority

If evidence suggests a failing drive or serious hardware instability, the correct first action is usually to protect important data, not to run more write-heavy optimization.

### Personal data

The repair logic is not intended to delete:

- Downloads
- Desktop
- Documents
- Pictures
- Videos
- browser profiles
- saved passwords
- cookies
- source code
- project folders

### Security

The toolkit does not automatically disable:

- Microsoft Defender
- Windows Firewall
- UAC
- SmartScreen
- Windows Update permanently

### High-risk actions intentionally left manual

- BIOS/firmware flashing
- driver installation from the Internet
- offline CHKDSK repair modes
- startup/service disabling
- pagefile/registry memory hacks
- BCDEdit/HPET timer tweaks
- application uninstall
- destructive storage testing
- broad network reset

## Before applying repairs

1. Read the Phase C reports.
2. Run **DRY RUN** first.
3. Back up irreplaceable files.
4. If storage-health warnings are serious, investigate the drive before running unnecessary write-heavy actions.
5. If the PC is managed by an employer, follow organizational IT policy.
