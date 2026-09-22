# Technical Notes

## Design goal

Repair the common local causes of LDPlayer/Firebase Installations token failures without making high-risk host-network changes automatically.

## ADB dependency

LDPlayer ships its own `adb.exe`, commonly under:

```text
C:\LDPlayer\LDPlayer9\adb.exe
```

No separate Android SDK is required.

The script accepts any online ADB target matching:

```text
<serial>    device
```

A typical LDPlayer serial is `emulator-5554`, but the exact serial is not hard-coded.

## Android settings changed

### HTTP proxy

```text
settings put global http_proxy :0
settings delete global global_http_proxy_host
settings delete global global_http_proxy_port
```

Purpose: remove a stale emulator-side proxy.

### Private DNS

```text
settings put global private_dns_mode off
```

Purpose: temporarily remove DNS-over-TLS/custom Private DNS as a failure source.

Restore:

```text
settings put global private_dns_mode opportunistic
```

### Automatic time

```text
settings put global auto_time 1
settings put global auto_time_zone 1
```

Purpose: TLS/authentication tokens depend on reasonably correct clocks.

## Google packages optionally reset

```text
pm clear com.android.vending
pm clear com.google.android.gms
pm clear com.google.android.gsf
```

These commands reset local data for Google Play Store, Google Play Services, and Google Services Framework. They may trigger a Google sign-in prompt afterward.

## Affected-app reset

When the user supplies a package name and explicitly confirms, the script runs:

```text
pm clear <package>
```

This can recreate app-local Firebase installation state, but it also removes that app's local Android data. Therefore it is never performed silently.

## Windows commands

The normal path uses:

```text
netsh winhttp reset proxy
ipconfig /flushdns
w32tm /resync /force
```

The main script intentionally does not automatically run `netsh int ip reset`, install NDIS filters, change bridge drivers, or force public DNS servers.

## Connectivity tests

The script attempts both:

```text
ping -c 1 -W 3 8.8.8.8
ping -c 1 -W 3 google.com
```

The first is intended to test IP reachability; the second adds DNS resolution. ICMP may be blocked, so a failed ping is not treated as definitive proof that HTTPS is broken.

## Security and privacy

The script:

- does not transmit the generated log anywhere;
- does not upload credentials;
- does not read Google passwords;
- does not require Android root;
- does not disable Windows security products;
- does not modify router settings.

Logs remain in the local folder until the user moves/deletes them.

## Why Network Bridge is not automated

Changing LDPlayer/VirtualBox bridge or NDIS drivers can interrupt the Windows host's networking. It is therefore documented as a later manual troubleshooting step rather than automated.

## Scope

This utility can repair local state. It cannot fix remote Firebase configuration, app server outages, revoked credentials, emulator blocks, or account restrictions.
