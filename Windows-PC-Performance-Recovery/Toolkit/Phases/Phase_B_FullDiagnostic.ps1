# Windows Performance & Hardware Health Diagnostic Toolkit v2.0
# Phase B: evidence collection only; no intentional optimization changes.
param([string]$RunRoot,[switch]$PostRepair)
$scriptDir=Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path (Split-Path -Parent $scriptDir) 'Core\Common.ps1')
$packageRoot=Split-Path -Parent (Split-Path -Parent $scriptDir)
if(-not $RunRoot){$RunRoot=Get-LatestToolkitRun $packageRoot;if(-not $RunRoot){$RunRoot=New-ToolkitRun $packageRoot}}

$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'
$script:Started = Get-Date
$script:Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$phaseFolder = if($PostRepair){'Phase_E_PostRepair\Diagnostics'}else{'Phase_B_Diagnostics'}
$script:Out = Join-Path $RunRoot $phaseFolder

$subdirs = @(
  'Hardware','Performance','Storage','Processes','Startup','Services','ScheduledTasks',
  'Drivers','Devices','WindowsHealth','EventLogs','Network','Security','PowerThermal',
  'Applications','BootReliability','Logs','Summary'
)
New-Item -Path $script:Out -ItemType Directory -Force | Out-Null
foreach ($d in $subdirs) { New-Item -Path (Join-Path $script:Out $d) -ItemType Directory -Force | Out-Null }

$script:MasterLog = Join-Path $script:Out 'Logs\DIAGNOSTIC_RUN.log'
$script:Warnings = New-Object System.Collections.Generic.List[string]
$script:QuickFindings = New-Object System.Collections.Generic.List[string]

function Write-Log {
    param([string]$Message,[string]$Level='INFO')
    $line = "{0} [{1}] {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'),$Level,$Message
    Add-Content -Path $script:MasterLog -Value $line -Encoding UTF8
    Write-Host $line
}

function Save-Text {
    param([string]$RelativePath,[scriptblock]$Action)
    $path = Join-Path $script:Out $RelativePath
    try {
        & $Action 2>&1 | Out-File -FilePath $path -Encoding UTF8 -Width 4096
        Write-Log "Wrote $RelativePath"
    } catch {
        "FAILED: $($_.Exception.Message)" | Out-File -FilePath $path -Encoding UTF8
        Write-Log "Failed $RelativePath : $($_.Exception.Message)" 'WARN'
        $script:Warnings.Add("$RelativePath : $($_.Exception.Message)")
    }
}

function Save-Csv {
    param([string]$RelativePath,[scriptblock]$Action)
    $path = Join-Path $script:Out $RelativePath
    try {
        $data = & $Action
        if ($null -eq $data) {
            'NO DATA / NOT AVAILABLE' | Out-File -FilePath ($path -replace '\.csv$','.txt') -Encoding UTF8
        } else {
            $data | Export-Csv -Path $path -NoTypeInformation -Encoding UTF8
        }
        Write-Log "Wrote $RelativePath"
    } catch {
        "FAILED: $($_.Exception.Message)" | Out-File -FilePath ($path -replace '\.csv$','.txt') -Encoding UTF8
        Write-Log "Failed $RelativePath : $($_.Exception.Message)" 'WARN'
        $script:Warnings.Add("$RelativePath : $($_.Exception.Message)")
    }
}

function Test-Admin {
    try {
        $id = [Security.Principal.WindowsIdentity]::GetCurrent()
        $p = New-Object Security.Principal.WindowsPrincipal($id)
        return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch { return $false }
}

function Get-RegValueSafe {
    param([string]$Path,[string]$Name)
    try { return (Get-ItemProperty -Path $Path -Name $Name -ErrorAction Stop).$Name } catch { return $null }
}

function Get-ShortHash {
    param([object]$Value)
    if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value)) { return $null }
    try {
        $sha = [System.Security.Cryptography.SHA256]::Create()
        $bytes = [Text.Encoding]::UTF8.GetBytes([string]$Value)
        $hash = $sha.ComputeHash($bytes)
        return (($hash | ForEach-Object { $_.ToString('x2') }) -join '').Substring(0,12)
    } catch { return 'HASH-UNAVAILABLE' }
}

$IsAdmin = Test-Admin
Write-Log "Diagnostic started. Output: $script:Out"
Write-Log "Administrator: $IsAdmin"

# ---------------------------------------------------------------------------
# System / hardware inventory
# ---------------------------------------------------------------------------
Save-Text 'Hardware\System_Summary.txt' {
    "Collected: $(Get-Date -Format o)"
    "Computer: $env:COMPUTERNAME"
    "User: $env:USERNAME"
    "Administrator: $IsAdmin"
    Get-ComputerInfo | Select-Object WindowsProductName,WindowsEditionId,WindowsVersion,OsBuildNumber,
        OsArchitecture,OsInstallDate,OsLastBootUpTime,CsManufacturer,CsModel,CsSystemType,
        CsProcessors,CsNumberOfLogicalProcessors,CsTotalPhysicalMemory,BiosManufacturer,
        BiosSMBIOSBIOSVersion,BiosReleaseDate | Format-List
}

Save-Csv 'Hardware\Computer_System.csv' {
    Get-CimInstance Win32_ComputerSystem | Select-Object Manufacturer,Model,SystemType,TotalPhysicalMemory,
        NumberOfProcessors,NumberOfLogicalProcessors,Domain,PartOfDomain,HypervisorPresent
}
Save-Csv 'Hardware\Operating_System.csv' {
    Get-CimInstance Win32_OperatingSystem | Select-Object Caption,Version,BuildNumber,OSArchitecture,InstallDate,LastBootUpTime,FreePhysicalMemory,TotalVisibleMemorySize
}
Save-Csv 'Hardware\BIOS.csv' {
    Get-CimInstance Win32_BIOS | Select-Object Manufacturer,SMBIOSBIOSVersion,ReleaseDate,Version
}
Save-Csv 'Hardware\Motherboard.csv' {
    Get-CimInstance Win32_BaseBoard | Select-Object Manufacturer,Product,Version
}
Save-Csv 'Hardware\CPU.csv' {
    Get-CimInstance Win32_Processor | Select-Object Name,Manufacturer,NumberOfCores,NumberOfLogicalProcessors,
        MaxClockSpeed,CurrentClockSpeed,LoadPercentage,Status
}
Save-Csv 'Hardware\Memory_Modules.csv' {
    Get-CimInstance Win32_PhysicalMemory | Select-Object BankLabel,DeviceLocator,Capacity,Speed,ConfiguredClockSpeed,Manufacturer,PartNumber
}
Save-Csv 'Hardware\GPU.csv' {
    Get-CimInstance Win32_VideoController | Select-Object Name,AdapterRAM,DriverVersion,DriverDate,VideoProcessor,CurrentHorizontalResolution,CurrentVerticalResolution,Status,PNPDeviceID
}

Save-Text 'Hardware\SecureBoot.txt' {
    try { "SecureBoot: $(Confirm-SecureBootUEFI -ErrorAction Stop)" } catch { "SecureBoot: NOT AVAILABLE / $($_.Exception.Message)" }
}

# ---------------------------------------------------------------------------
# Baseline CPU / memory / process snapshots
# ---------------------------------------------------------------------------
Save-Csv 'Processes\Top_RAM_Processes.csv' {
    Get-Process | Sort-Object WorkingSet64 -Descending | Select-Object -First 30 Name,Id,
      @{n='WorkingSetMB';e={[math]::Round($_.WorkingSet64/1MB,2)}},
      @{n='PrivateMB';e={[math]::Round($_.PrivateMemorySize64/1MB,2)}},CPU,Handles,Threads,Path
}

Save-Csv 'Processes\Top_CPU_Delta_Processes.csv' {
    $a = @{}
    Get-Process | ForEach-Object { $a[$_.Id] = [double]($_.CPU) }
    Start-Sleep -Seconds 5
    $rows = foreach ($p in Get-Process) {
        if ($a.ContainsKey($p.Id) -and $null -ne $p.CPU) {
            $delta = [double]$p.CPU - $a[$p.Id]
            [pscustomobject]@{Name=$p.Name;Id=$p.Id;CPUSecondsDelta5s=[math]::Round($delta,3);WorkingSetMB=[math]::Round($p.WorkingSet64/1MB,2);Path=$p.Path}
        }
    }
    $rows | Sort-Object CPUSecondsDelta5s -Descending | Select-Object -First 30
}

Save-Csv 'Performance\Baseline_Samples.csv' {
    $samples = New-Object System.Collections.Generic.List[object]
    for ($i=1; $i -le 12; $i++) {
        $os = Get-CimInstance Win32_OperatingSystem
