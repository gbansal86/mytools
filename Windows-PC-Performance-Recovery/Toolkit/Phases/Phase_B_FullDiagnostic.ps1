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
        $cpu = Get-CimInstance Win32_Processor | Measure-Object -Property LoadPercentage -Average
        $disk = $null
        try {
            $disk = Get-CimInstance Win32_PerfFormattedData_PerfDisk_PhysicalDisk -ErrorAction Stop |
                Where-Object { $_.Name -eq '_Total' } | Select-Object -First 1
        } catch {}
        $samples.Add([pscustomobject]@{
            Timestamp=(Get-Date -Format o)
            CpuLoadPct=[math]::Round([double]$cpu.Average,1)
            FreePhysicalMB=[math]::Round([double]$os.FreePhysicalMemory/1024,1)
            TotalVisibleMB=[math]::Round([double]$os.TotalVisibleMemorySize/1024,1)
            DiskReadBytesSec=if($disk){$disk.DiskReadBytesPersec}else{$null}
            DiskWriteBytesSec=if($disk){$disk.DiskWriteBytesPersec}else{$null}
            AvgDiskSecTransfer=if($disk){$disk.AvgDisksecPerTransfer}else{$null}
            CurrentDiskQueue=if($disk){$disk.CurrentDiskQueueLength}else{$null}
            ProcessCount=(Get-Process).Count
        })
        Start-Sleep -Seconds 2
    }
    $samples
}

Save-Text 'Performance\Performance_Counters.txt' {
    try {
        Get-Counter -Counter '\Processor(_Total)\% Processor Time','\Memory\Available MBytes','\Memory\Committed Bytes','\Memory\Pages/sec','\PhysicalDisk(_Total)\Avg. Disk sec/Transfer','\PhysicalDisk(_Total)\Current Disk Queue Length' -SampleInterval 1 -MaxSamples 5 |
            Select-Object -ExpandProperty CounterSamples |
            Select-Object Timestamp,Path,CookedValue | Format-Table -AutoSize
    } catch {
        "Get-Counter unavailable/localized/failed: $($_.Exception.Message)"
    }
}

# ---------------------------------------------------------------------------
# Storage health / reliability / SMART provider data
# ---------------------------------------------------------------------------
Save-Csv 'Storage\Physical_Disks.csv' {
    Get-PhysicalDisk -ErrorAction Stop | Select-Object FriendlyName,@{n='DeviceHash';e={Get-ShortHash $_.UniqueId}},MediaType,BusType,HealthStatus,OperationalStatus,Size,AllocatedSize,Usage
}
Save-Csv 'Storage\Disks.csv' {
    Get-Disk | Select-Object Number,FriendlyName,@{n='DeviceHash';e={Get-ShortHash $_.UniqueId}},BusType,PartitionStyle,HealthStatus,OperationalStatus,Size,IsBoot,IsSystem,IsReadOnly,IsOffline
}
Save-Csv 'Storage\Volumes.csv' {
    Get-Volume | Select-Object DriveLetter,FileSystemLabel,FileSystem,HealthStatus,OperationalStatus,Size,SizeRemaining,Path
}
Save-Csv 'Storage\Win32_DiskDrive.csv' {
    Get-CimInstance Win32_DiskDrive | Select-Object Index,Model,@{n='DeviceHash';e={Get-ShortHash $_.PNPDeviceID}},FirmwareRevision,InterfaceType,MediaType,Size,Status
}
Save-Csv 'Storage\Storage_Reliability_Counters.csv' {
    $rows = @()
    foreach ($pd in (Get-PhysicalDisk -ErrorAction Stop)) {
        try {
            $r = Get-StorageReliabilityCounter -PhysicalDisk $pd -ErrorAction Stop
            $rows += [pscustomobject]@{
                FriendlyName=$pd.FriendlyName;DeviceHash=(Get-ShortHash $pd.UniqueId);Temperature=$r.Temperature;TemperatureMax=$r.TemperatureMax;
                Wear=$r.Wear;PowerOnHours=$r.PowerOnHours;ReadErrorsTotal=$r.ReadErrorsTotal;ReadErrorsUncorrected=$r.ReadErrorsUncorrected;
                WriteErrorsTotal=$r.WriteErrorsTotal;WriteErrorsUncorrected=$r.WriteErrorsUncorrected;ReadLatencyMax=$r.ReadLatencyMax;
                WriteLatencyMax=$r.WriteLatencyMax;FlushLatencyMax=$r.FlushLatencyMax;LoadUnloadCycleCount=$r.LoadUnloadCycleCount;
                StartStopCycleCount=$r.StartStopCycleCount;PowerCycleCount=$r.PowerCycleCount
            }
        } catch {
            $rows += [pscustomobject]@{FriendlyName=$pd.FriendlyName;DeviceHash=(Get-ShortHash $pd.UniqueId);Error="NOT EXPOSED / $($_.Exception.Message)"}
        }
    }
    $rows
}
Save-Csv 'Storage\SMART_FailurePredictStatus.csv' {
    Get-CimInstance -Namespace root\wmi -ClassName MSStorageDriver_FailurePredictStatus -ErrorAction Stop |
        Select-Object InstanceName,PredictFailure,Reason
}
Save-Csv 'Storage\SMART_FailurePredictData.csv' {
    Get-CimInstance -Namespace root\wmi -ClassName MSStorageDriver_FailurePredictData -ErrorAction Stop |
        Select-Object InstanceName,@{n='VendorSpecificHex';e={($_.VendorSpecific | ForEach-Object { $_.ToString('X2') }) -join ''}}
}
Save-Csv 'Storage\SMART_FailurePredictThresholds.csv' {
    Get-CimInstance -Namespace root\wmi -ClassName MSStorageDriver_FailurePredictThresholds -ErrorAction Stop |
        Select-Object InstanceName,@{n='VendorSpecificHex';e={($_.VendorSpecific | ForEach-Object { $_.ToString('X2') }) -join ''}}
}
Save-Text 'Storage\TRIM_Status.txt' { fsutil behavior query DisableDeleteNotify }
Save-Text 'Storage\Dirty_Volume_Status.txt' {
    Get-Volume | Where-Object DriveLetter | ForEach-Object {
        "### $($_.DriveLetter):"
        fsutil dirty query "$($_.DriveLetter):" 2>&1
    }
}

# Hardware trend snapshot for future runs
Save-Csv 'Storage\Hardware_Trend_Snapshot.csv' {
    $rows = New-Object System.Collections.Generic.List[object]
    try {
        foreach ($pd in Get-PhysicalDisk) {
            $r = $null; try { $r = Get-StorageReliabilityCounter -PhysicalDisk $pd -ErrorAction Stop } catch {}
            $rows.Add([pscustomobject]@{
                Timestamp=(Get-Date -Format o);ComponentType='Storage';Name=$pd.FriendlyName;DeviceHash=(Get-ShortHash $pd.UniqueId);
                Health=$pd.HealthStatus;Operational=($pd.OperationalStatus -join ',');MediaType=$pd.MediaType;BusType=$pd.BusType;
                Wear=if($r){$r.Wear}else{$null};Temperature=if($r){$r.Temperature}else{$null};PowerOnHours=if($r){$r.PowerOnHours}else{$null};
                ReadErrorsUncorrected=if($r){$r.ReadErrorsUncorrected}else{$null};WriteErrorsUncorrected=if($r){$r.WriteErrorsUncorrected}else{$null}
            })
        }
    } catch {}
    $rows
}

# ---------------------------------------------------------------------------
# Startup, services, tasks, installed software
# ---------------------------------------------------------------------------
Save-Csv 'Startup\Startup_Commands.csv' {
    Get-CimInstance Win32_StartupCommand | Select-Object Name,Command,Location,User
}
Save-Text 'Startup\Registry_Run_Entries.txt' {
    $paths = @(
      'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run',
      'HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce',
      'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run',
      'HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce',
      'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run'
    )
    foreach ($p in $paths) {
        "### $p"
        try { Get-ItemProperty $p -ErrorAction Stop | Format-List } catch { "NOT AVAILABLE: $($_.Exception.Message)" }
    }
}
Save-Csv 'Services\Services.csv' {
    Get-CimInstance Win32_Service | Select-Object Name,DisplayName,State,StartMode,StartName,PathName,ExitCode,ProcessId
}
Save-Csv 'ScheduledTasks\Scheduled_Tasks.csv' {
    $out = foreach ($t in Get-ScheduledTask -ErrorAction Stop) {
        $info = $null; try { $info = Get-ScheduledTaskInfo -TaskName $t.TaskName -TaskPath $t.TaskPath -ErrorAction Stop } catch {}
        [pscustomobject]@{
            TaskPath=$t.TaskPath;TaskName=$t.TaskName;State=$t.State;Author=$t.Author;
            LastRunTime=if($info){$info.LastRunTime}else{$null};NextRunTime=if($info){$info.NextRunTime}else{$null};
            LastTaskResult=if($info){$info.LastTaskResult}else{$null};Actions=(($t.Actions | ForEach-Object { "$($_.Execute) $($_.Arguments)" }) -join ' | ')
        }
    }
    $out
}
Save-Csv 'Applications\Installed_Applications.csv' {
    $keys = @(
      'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
      'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
      'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    foreach ($k in $keys) {
        Get-ItemProperty $k -ErrorAction SilentlyContinue | Where-Object DisplayName |
          Select-Object DisplayName,DisplayVersion,Publisher,InstallDate,InstallLocation,UninstallString
    }
}

# ---------------------------------------------------------------------------
# Devices / drivers
# ---------------------------------------------------------------------------
Save-Csv 'Devices\PnP_Devices.csv' {
    if (Get-Command Get-PnpDevice -ErrorAction SilentlyContinue) {
        Get-PnpDevice | Select-Object Status,Class,FriendlyName,InstanceId,Problem
    } else {
        Get-CimInstance Win32_PnPEntity | Select-Object Status,PNPClass,Name,PNPDeviceID,ConfigManagerErrorCode
    }
}
Save-Csv 'Devices\Problem_Devices.csv' {
    Get-CimInstance Win32_PnPEntity | Where-Object { $_.ConfigManagerErrorCode -ne 0 } |
        Select-Object Name,PNPClass,PNPDeviceID,Status,ConfigManagerErrorCode
}
Save-Csv 'Drivers\Signed_Drivers.csv' {
    Get-CimInstance Win32_PnPSignedDriver | Select-Object DeviceName,DeviceClass,DriverProviderName,DriverVersion,DriverDate,IsSigned,InfName,DeviceID
}

# ---------------------------------------------------------------------------
# Windows health / update / pending reboot
# ---------------------------------------------------------------------------
Save-Text 'WindowsHealth\DISM_CheckHealth.txt' { DISM.exe /Online /Cleanup-Image /CheckHealth }
Save-Text 'WindowsHealth\SFC_VerifyOnly.txt' { sfc.exe /verifyonly }
Save-Text 'WindowsHealth\Pending_Reboot.txt' {
    $checks = [ordered]@{}
    $checks['CBS_RebootPending'] = Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending'
    $checks['WU_RebootRequired'] = Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'
    $checks['PendingFileRenameOperations'] = [bool](Get-RegValueSafe 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' 'PendingFileRenameOperations')
    $checks.GetEnumerator() | Format-Table -AutoSize
}
Save-Text 'WindowsHealth\Windows_Update_Service.txt' {
    Get-Service wuauserv,bits,cryptsvc -ErrorAction SilentlyContinue | Format-Table Name,Status,StartType -AutoSize
}

# ---------------------------------------------------------------------------
# Security
# ---------------------------------------------------------------------------
Save-Text 'Security\Defender_Status.txt' {
    if (Get-Command Get-MpComputerStatus -ErrorAction SilentlyContinue) { Get-MpComputerStatus | Format-List }
    else { 'Get-MpComputerStatus not available.' }
}
Save-Csv 'Security\Registered_Antivirus.csv' {
    Get-CimInstance -Namespace root\SecurityCenter2 -ClassName AntivirusProduct -ErrorAction Stop |
        Select-Object displayName,pathToSignedProductExe,pathToSignedReportingExe,productState
}

# ---------------------------------------------------------------------------
# Network
# ---------------------------------------------------------------------------
Save-Csv 'Network\Network_Adapters.csv' {
    Get-CimInstance Win32_NetworkAdapter | Where-Object PhysicalAdapter |
      Select-Object Name,NetConnectionID,NetEnabled,Speed,MACAddress,Manufacturer,PNPDeviceID
}
Save-Csv 'Network\Network_Adapter_Config.csv' {
    Get-CimInstance Win32_NetworkAdapterConfiguration | Where-Object IPEnabled |
      Select-Object Description,DHCPEnabled,IPAddress,IPSubnet,DefaultIPGateway,DNSServerSearchOrder,MACAddress
}
Save-Text 'Network\IPConfig_All.txt' { ipconfig /all }
Save-Text 'Network\TCP_Global.txt' { netsh int tcp show global }
Save-Text 'Network\WinHTTP_Proxy.txt' { netsh winhttp show proxy }
Save-Text 'Network\Route_Print.txt' { route print }

# ---------------------------------------------------------------------------
# Power / battery / virtualization / browser summaries
# ---------------------------------------------------------------------------
Save-Text 'PowerThermal\Active_Power_Plan.txt' { powercfg /getactivescheme; powercfg /q }
$batHtml = Join-Path $script:Out 'PowerThermal\battery-report.html'
try {
    powercfg /batteryreport /output "$batHtml" | Out-Null
    if (Test-Path $batHtml) { Write-Log 'Wrote PowerThermal\battery-report.html' }
} catch { Write-Log "Battery report unavailable: $($_.Exception.Message)" 'WARN' }

Save-Csv 'Applications\Browser_Process_Summary.csv' {
    $browserNames = 'chrome','msedge','firefox','brave','opera','vivaldi'
    $rows = foreach ($n in $browserNames) {
        $p = Get-Process -Name $n -ErrorAction SilentlyContinue
        if ($p) {
            [pscustomobject]@{Browser=$n;ProcessCount=$p.Count;WorkingSetMB=[math]::Round((($p|Measure-Object WorkingSet64 -Sum).Sum)/1MB,2);CPUSeconds=[math]::Round((($p|Measure-Object CPU -Sum).Sum),2)}
        }
    }
    $rows
}
Save-Text 'Applications\Virtualization_Features.txt' {
    "HypervisorPresent: $((Get-CimInstance Win32_ComputerSystem).HypervisorPresent)"
    foreach ($f in 'Microsoft-Windows-Subsystem-Linux','VirtualMachinePlatform','Microsoft-Hyper-V-All','Containers-DisposableClientVM') {
        try { Get-WindowsOptionalFeature -Online -FeatureName $f -ErrorAction Stop | Select-Object FeatureName,State | Format-Table -AutoSize } catch { "$f : NOT AVAILABLE" }
    }
    "Relevant running processes:"
    Get-Process -ErrorAction SilentlyContinue | Where-Object Name -Match 'wsl|vmmem|docker|vmware|virtualbox|vbox|qemu|sqlservr|mysqld|postgres' |
      Select-Object Name,Id,@{n='WorkingSetMB';e={[math]::Round($_.WorkingSet64/1MB,2)}},CPU | Format-Table -AutoSize
}

# ---------------------------------------------------------------------------
# Event logs and reliability
# ---------------------------------------------------------------------------
$since7 = (Get-Date).AddDays(-7)
$since1 = (Get-Date).AddDays(-1)

Save-Csv 'EventLogs\System_Warnings_Errors_7d.csv' {
    Get-WinEvent -FilterHashtable @{LogName='System';StartTime=$since7;Level=1,2,3} -ErrorAction Stop |
      Select-Object -First 5000 TimeCreated,Id,LevelDisplayName,ProviderName,MachineName,Message
}
Save-Csv 'EventLogs\Application_Warnings_Errors_7d.csv' {
    Get-WinEvent -FilterHashtable @{LogName='Application';StartTime=$since7;Level=1,2,3} -ErrorAction Stop |
      Select-Object -First 5000 TimeCreated,Id,LevelDisplayName,ProviderName,MachineName,Message
}
Save-Csv 'EventLogs\WHEA_7d.csv' {
    Get-WinEvent -FilterHashtable @{LogName='System';ProviderName='Microsoft-Windows-WHEA-Logger';StartTime=$since7} -ErrorAction Stop |
      Select-Object TimeCreated,Id,LevelDisplayName,ProviderName,Message
}
Save-Csv 'EventLogs\Storage_Related_7d.csv' {
    $providers = 'disk|ntfs|storport|storahci|stornvme|iastor|volmgr|volsnap'
    Get-WinEvent -FilterHashtable @{LogName='System';StartTime=$since7;Level=1,2,3} -ErrorAction Stop |
      Where-Object { $_.ProviderName -match $providers } |
      Select-Object TimeCreated,Id,LevelDisplayName,ProviderName,Message
}
Save-Csv 'EventLogs\Kernel_Power_7d.csv' {
