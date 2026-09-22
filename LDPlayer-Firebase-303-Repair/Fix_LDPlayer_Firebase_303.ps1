#requires -version 5.1
<#
.SYNOPSIS
    Repairs common LDPlayer Internet / Firebase Installations #303 problems.

.DESCRIPTION
    This script:
      - locates LDPlayer 9 and its bundled ADB tool;
      - performs low-risk Windows proxy/DNS/time cleanup;
      - verifies that ADB can see the Android emulator;
      - guides the user to enable "ADB debugging -> Enable local connection"
        when ADB is not reachable;
      - clears Android proxy settings and temporarily disables Private DNS;
      - enables automatic Android time and time zone;
      - tests Android IP and DNS reachability;
      - optionally clears Google Play / Play Services / Services Framework data;
      - optionally clears one affected Android app;
      - reboots LDPlayer Android;
      - writes a timestamped troubleshooting log.

    The script deliberately does NOT install/remove bridge drivers, root LDPlayer,
    disable antivirus/firewall, edit the registry, or permanently change Windows DNS.

.NOTES
    Clearing Google service data may require signing into Google Play again.
    Clearing an affected app resets that app's local Android data.
#>

[CmdletBinding()]
param(
    [string]$AppPackage = "",
    [switch]$SkipGoogleDataClear
)

$ErrorActionPreference = "Continue"
$Host.UI.RawUI.WindowTitle = "LDPlayer Firebase #303 Repair"

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host ("=" * 78) -ForegroundColor Cyan
    Write-Host $Message -ForegroundColor Yellow
    Write-Host ("=" * 78) -ForegroundColor Cyan
}

function Test-Administrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Relaunch ourselves as Administrator when needed.
if (-not (Test-Administrator)) {
    Write-Host "Administrator access is required for the Windows repair steps." -ForegroundColor Yellow
    Write-Host "Requesting UAC permission..."

    $args = @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", ('"' + $PSCommandPath + '"')
    )

    if ($AppPackage) {
        $args += @("-AppPackage", ('"' + $AppPackage + '"'))
    }
    if ($SkipGoogleDataClear) {
        $args += "-SkipGoogleDataClear"
    }

    Start-Process powershell.exe -Verb RunAs -ArgumentList $args
    exit
}

# Keep a log beside the script. It is useful if the repair does not solve the problem.
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$logFile = Join-Path $PSScriptRoot ("LDPlayer_Repair_" + $timestamp + ".log")

try {
    Start-Transcript -Path $logFile -Force | Out-Null
} catch {
    Write-Host "Warning: Could not start transcript logging." -ForegroundColor DarkYellow
}

Write-Host ""
Write-Host "LDPlayer Internet / Firebase #303 Repair" -ForegroundColor Green
Write-Host "Log file: $logFile"
Write-Host ""
Write-Host "This utility changes only common PC/emulator networking and Google-service state."
Write-Host "It cannot repair a Firebase project or remote app server owned by the app developer."

# ---------------------------------------------------------------------------
# STEP 1 - Find LDPlayer and ADB
# ---------------------------------------------------------------------------
Write-Step "1/7 - Finding LDPlayer and ADB"

$commonFolders = @(
    "C:\LDPlayer\LDPlayer9",
    "C:\Program Files\LDPlayer\LDPlayer9",
    "C:\Program Files (x86)\LDPlayer\LDPlayer9",
    "D:\LDPlayer\LDPlayer9"
)

$ldFolder = $null
$adb = $null
$player = $null

foreach ($folder in $commonFolders) {
    $candidateAdb = Join-Path $folder "adb.exe"
    if (Test-Path $candidateAdb) {
        $ldFolder = $folder
        $adb = $candidateAdb
        break
    }
}

# If LDPlayer is installed somewhere unusual, search common LDPlayer parent folders.
if (-not $adb) {
    $parents = @(
        "C:\LDPlayer",
        "C:\Program Files\LDPlayer",
        "C:\Program Files (x86)\LDPlayer",
        "D:\LDPlayer"
    )

    foreach ($parent in $parents) {
        if (Test-Path $parent) {
            $found = Get-ChildItem -Path $parent -Filter "adb.exe" -Recurse -ErrorAction SilentlyContinue |
                     Select-Object -First 1
            if ($found) {
                $adb = $found.FullName
                $ldFolder = $found.DirectoryName
                break
            }
        }
    }
}

if (-not $adb) {
    Write-Host ""
    Write-Host "LDPlayer's adb.exe could not be found automatically." -ForegroundColor Red
    Write-Host "Expected example: C:\LDPlayer\LDPlayer9\adb.exe"
    Write-Host "No Android settings were changed."
    try { Stop-Transcript | Out-Null } catch {}
    Read-Host "Press ENTER to close"
    exit 2
}

Write-Host "LDPlayer folder: $ldFolder" -ForegroundColor Green
Write-Host "ADB executable : $adb" -ForegroundColor Green

foreach ($name in @("dnplayer.exe", "LDPlayer.exe")) {
    $candidate = Join-Path $ldFolder $name
    if (Test-Path $candidate) {
        $player = $candidate
        break
    }
}

# ---------------------------------------------------------------------------
# STEP 2 - Low-risk Windows cleanup
# ---------------------------------------------------------------------------
Write-Step "2/7 - Refreshing basic Windows network state"

Write-Host "Resetting WinHTTP proxy to direct access..."
& netsh winhttp reset proxy | Out-Host

Write-Host ""
Write-Host "Flushing the Windows DNS resolver cache..."
& ipconfig /flushdns | Out-Host

Write-Host ""
Write-Host "Synchronizing Windows time..."
try {
    Set-Service -Name w32time -StartupType Automatic -ErrorAction SilentlyContinue
    Start-Service -Name w32time -ErrorAction SilentlyContinue
    & w32tm /resync /force | Out-Host
} catch {
    Write-Host "Time synchronization warning: $($_.Exception.Message)" -ForegroundColor DarkYellow
}

Write-Host ""
Write-Host "NOTE: The script does not change Windows DNS servers or network drivers."

# ---------------------------------------------------------------------------
# STEP 3 - Start LDPlayer and make ADB reachable
# ---------------------------------------------------------------------------
Write-Step "3/7 - Connecting to Android inside LDPlayer"

if (-not (Get-Process -Name "dnplayer","LDPlayer" -ErrorAction SilentlyContinue)) {
    if ($player) {
        Write-Host "Starting LDPlayer..."
        Start-Process $player
        Start-Sleep -Seconds 5
    } else {
        Write-Host "LDPlayer executable was not found beside ADB." -ForegroundColor DarkYellow
        Write-Host "Please start LDPlayer manually."
    }
}

& $adb kill-server | Out-Null
& $adb start-server | Out-Null

function Get-OnlineAdbDevice {
    $lines = & $adb devices 2>&1
    $online = $lines | Where-Object { $_ -match "^\S+\s+device\s*$" }
    if ($online) {
        return ($online | Select-Object -First 1)
    }
    return $null
}

$device = $null

# First give LDPlayer time to boot normally.
for ($i = 1; $i -le 20; $i++) {
    $device = Get-OnlineAdbDevice
    if ($device) { break }
    Write-Host "Waiting for ADB device... $i/20"
    Start-Sleep -Seconds 2
}

# LDPlayer commonly exposes ADB on localhost. Try several common odd-numbered ports.
if (-not $device) {
    Write-Host ""
    Write-Host "ADB is not visible yet. Trying common LDPlayer local ports..."
    foreach ($port in @(5555,5557,5559,5561,5563,5565)) {
        & $adb connect ("127.0.0.1:" + $port) 2>&1 | Out-Host
        Start-Sleep -Milliseconds 500
        $device = Get-OnlineAdbDevice
        if ($device) { break }
    }
}

# If still unavailable, give a clear layman-friendly instruction and retry.
if (-not $device) {
    Write-Host ""
    Write-Host "LDPlayer is running, but ADB is not accessible." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "In LDPlayer do this:"
    Write-Host "  Settings -> Others -> ADB debugging -> Enable local connection"
    Write-Host "  Save/restart LDPlayer if it asks."
    Write-Host ""
    Read-Host "After doing that and waiting for Android to load, press ENTER here"

    & $adb kill-server | Out-Null
    & $adb start-server | Out-Null

    for ($i = 1; $i -le 30; $i++) {
        $device = Get-OnlineAdbDevice
        if ($device) { break }
        Start-Sleep -Seconds 2
    }
}

if (-not $device) {
    Write-Host ""
    Write-Host "ADB still cannot see LDPlayer." -ForegroundColor Red
    Write-Host "Run this manually to confirm:"
    Write-Host ('"' + $adb + '" devices')
    Write-Host ""
    Write-Host "Expected output contains something like: emulator-5554    device"
    try { Stop-Transcript | Out-Null } catch {}
    Read-Host "Press ENTER to close"
    exit 3
}

Write-Host ""
Write-Host "ADB connected successfully:" -ForegroundColor Green
Write-Host "  $device"

# ---------------------------------------------------------------------------
# STEP 4 - Fix Android proxy, Private DNS, and time
# ---------------------------------------------------------------------------
Write-Step "4/7 - Repairing Android network/authentication settings"

function Invoke-AdbShell {
    param([string]$Command)
    Write-Host ("ADB> " + $Command) -ForegroundColor DarkGray
    & $adb shell $Command 2>&1 | Out-Host
}

# Remove Android-side HTTP proxy settings.
Invoke-AdbShell "settings put global http_proxy :0"
Invoke-AdbShell "settings delete global global_http_proxy_host"
Invoke-AdbShell "settings delete global global_http_proxy_port"

# Disable Private DNS temporarily. This is reversible; see README.md.
Invoke-AdbShell "settings put global private_dns_mode off"

# Correct clock-related settings, important for TLS and auth tokens.
Invoke-AdbShell "settings put global auto_time 1"
Invoke-AdbShell "settings put global auto_time_zone 1"

# ---------------------------------------------------------------------------
# STEP 5 - Test Android connectivity
# ---------------------------------------------------------------------------
Write-Step "5/7 - Testing Android Internet and DNS"

Write-Host "Testing direct IP reachability (8.8.8.8)..."
$ipTest = & $adb shell "ping -c 1 -W 3 8.8.8.8" 2>&1
$ipTest | Out-Host

Write-Host ""
Write-Host "Testing DNS/name reachability (google.com)..."
$dnsTest = & $adb shell "ping -c 1 -W 3 google.com" 2>&1
$dnsTest | Out-Host

Write-Host ""
if (($ipTest -match "1 packets transmitted") -and ($ipTest -match "1 received|1 packets received")) {
    Write-Host "Direct IP connectivity appears to work." -ForegroundColor Green
} else {
    Write-Host "Direct IP ping did not confirm connectivity." -ForegroundColor Yellow
    Write-Host "Some Android builds block ping, so also test Chrome after reboot."
}

if (($dnsTest -match "1 packets transmitted") -and ($dnsTest -match "1 received|1 packets received")) {
    Write-Host "DNS/name connectivity appears to work." -ForegroundColor Green
} else {
    Write-Host "DNS ping did not confirm connectivity." -ForegroundColor Yellow
}

# ---------------------------------------------------------------------------
# STEP 6 - Optional Google/Firebase local-state cleanup
# ---------------------------------------------------------------------------
Write-Step "6/7 - Optional Google/Firebase state cleanup"

if (-not $SkipGoogleDataClear) {
    Write-Host "Clearing Google service data can make Google Play ask you to sign in again."
    $answer = Read-Host "Clear Google Play Store / Play Services / Services Framework data? [Y/n]"

    if ([string]::IsNullOrWhiteSpace($answer) -or $answer -match "^[Yy]") {
        Invoke-AdbShell "pm clear com.android.vending"
        Invoke-AdbShell "pm clear com.google.android.gms"
        Invoke-AdbShell "pm clear com.google.android.gsf"
    } else {
        Write-Host "Google service data was not cleared."
    }
} else {
    Write-Host "Google data cleanup skipped by -SkipGoogleDataClear."
}

if (-not $AppPackage) {
    Write-Host ""
    Write-Host "Optional: enter the Android package of the affected app."
    Write-Host "Example format: com.example.app"
    Write-Host "Press ENTER to leave the app itself untouched."
    $AppPackage = Read-Host "Affected app package"
}

if ($AppPackage) {
    Write-Host ""
    Write-Host "WARNING: Clearing an app resets that app's local Android data." -ForegroundColor Yellow
    $clearApp = Read-Host "Clear local data for '$AppPackage'? [y/N]"
    if ($clearApp -match "^[Yy]") {
        Invoke-AdbShell ("pm clear " + $AppPackage)
    } else {
        Write-Host "Affected app data was not cleared."
    }
}

# ---------------------------------------------------------------------------
# STEP 7 - Reboot LDPlayer Android
# ---------------------------------------------------------------------------
Write-Step "7/7 - Rebooting Android and finishing"

& $adb reboot 2>&1 | Out-Host

Write-Host ""
Write-Host ("=" * 78) -ForegroundColor Green
Write-Host "REPAIR COMPLETE" -ForegroundColor Green
Write-Host ("=" * 78) -ForegroundColor Green
Write-Host ""
Write-Host "Next:"
Write-Host "  1. Wait 1-2 minutes for LDPlayer to finish booting."
Write-Host "  2. Open Chrome and test a website."
Write-Host "  3. Open Play Store and sign in again if requested."
Write-Host "  4. Test the app that showed Firebase/App configuration #303."
Write-Host ""
Write-Host "If Chrome works but only that app still fails, the problem may be app/Firebase-server-side."
Write-Host "Troubleshooting log: $logFile"

try { Stop-Transcript | Out-Null } catch {}

Write-Host ""
Read-Host "Press ENTER to close"
