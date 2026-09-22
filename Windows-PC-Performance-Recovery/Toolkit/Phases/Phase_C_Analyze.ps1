param([string]$RunRoot,[switch]$PostRepair)
$scriptDir=Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path (Split-Path -Parent $scriptDir) 'Core\Common.ps1')
$packageRoot=Split-Path -Parent (Split-Path -Parent $scriptDir)
if(-not $RunRoot){$RunRoot=Get-LatestToolkitRun $packageRoot}
if(-not $RunRoot -or -not(Test-Path $RunRoot)){throw 'No run found. Run Phase A/B first.'}
$diag=if($PostRepair){Join-Path $RunRoot 'Phase_E_PostRepair\Diagnostics'}else{Join-Path $RunRoot 'Phase_B_Diagnostics'}
$base=if($PostRepair){Join-Path $RunRoot 'Phase_E_PostRepair\Baseline'}else{Join-Path $RunRoot 'Phase_A_Baseline'}
$out=if($PostRepair){Join-Path $RunRoot 'Phase_E_PostRepair\Analysis'}else{Join-Path $RunRoot 'Phase_C_Analysis'}
New-Item -ItemType Directory -Force -Path $out|Out-Null
$log=Join-Path $out 'PHASE_C.log';Write-ToolkitLog $log 'Evidence analysis started.'
$findings=New-Object System.Collections.Generic.List[object]
$hardware=New-Object System.Collections.Generic.List[object]
function Add-Finding([string]$Priority,[string]$Class,[string]$Issue,[string]$Evidence,[string]$Impact,[string]$Action,[string]$Auto,[string]$Confidence='MEDIUM'){
    $findings.Add([pscustomobject]@{Priority=$Priority;Classification=$Class;Issue=$Issue;Confidence=$Confidence;Evidence=$Evidence;Impact=$Impact;RecommendedAction=$Action;Automation=$Auto})
}
function Import-CsvSafe([string]$p){if(Test-Path $p){try{return @(Import-Csv $p)}catch{return @()}}return @()}
function Read-TextSafe([string]$p){if(Test-Path $p){return (Get-Content $p -Raw -ErrorAction SilentlyContinue)}return ''}

# Baseline CPU/RAM/disk pressure
$samples=Import-CsvSafe (Join-Path $base 'Baseline_Samples.csv')
if($samples.Count -gt 0){
    $avgCpu=($samples|Measure-Object CpuLoadPct -Average).Average
    $avgMem=($samples|Measure-Object MemoryUsedPct -Average).Average
    $maxLat=($samples|Where-Object{$_.AvgDiskSecTransfer -ne ''}|ForEach-Object{[double]$_.AvgDiskSecTransfer}|Measure-Object -Maximum).Maximum
    if($avgCpu -ge 70){Add-Finding 'P2' 'HIGH-CONFIDENCE CONTRIBUTOR' 'Sustained high CPU during baseline' ("Average CPU {0:N1}% across {1} samples" -f $avgCpu,$samples.Count) 'Can directly reduce responsiveness.' 'Review top CPU process report; do not terminate unknown processes automatically.' 'MANUAL REVIEW' 'HIGH'}
    elseif($avgCpu -ge 45){Add-Finding 'P3' 'POSSIBLE CONTRIBUTOR' 'Elevated CPU during sample' ("Average CPU {0:N1}%" -f $avgCpu) 'May affect responsiveness if this was intended to be an idle sample.' 'Correlate with top CPU processes and repeat during idle.' 'NO AUTO CHANGE' 'MEDIUM'}
    if($avgMem -ge 90){Add-Finding 'P2' 'HIGH-CONFIDENCE CONTRIBUTOR' 'Severe memory pressure' ("Average physical memory use {0:N1}%" -f $avgMem) 'May cause paging and application stalls.' 'Review top RAM consumers and page activity; consider capacity if persistent.' 'MANUAL REVIEW' 'HIGH'}
    elseif($avgMem -ge 80){Add-Finding 'P3' 'POSSIBLE CONTRIBUTOR' 'High memory utilization' ("Average physical memory use {0:N1}%" -f $avgMem) 'May contribute to paging under load.' 'Review RAM consumers and page activity.' 'MANUAL REVIEW' 'MEDIUM'}
    if($maxLat -and $maxLat -ge 0.05){Add-Finding 'P2' 'HIGH-CONFIDENCE CONTRIBUTOR' 'High disk transfer latency observed' ("Peak sampled Avg Disk sec/Transfer {0:N4}s" -f $maxLat) 'Can cause pauses and slow application/file access.' 'Correlate with SMART/reliability counters, storage events, and paging.' 'NO BLIND REPAIR' 'MEDIUM'}
}

# Volumes/free space
$vols=Import-CsvSafe (Join-Path $diag 'Storage\Volumes.csv')
foreach($v in $vols){
    $size=0.0;$free=0.0;[double]::TryParse([string]$v.Size,[ref]$size)|Out-Null;[double]::TryParse([string]$v.SizeRemaining,[ref]$free)|Out-Null
    if($size -gt 0){$pct=100*$free/$size
        if($pct -lt 5){Add-Finding 'P1' 'CONFIRMED BOTTLENECK' ("Critically low free space on {0}:" -f $v.DriveLetter) ("{0:N1}% free" -f $pct) 'Can slow updates, paging, temp files, and applications.' 'Free space safely; investigate largest consumers.' 'SAFE CLEANUP MAY HELP' 'HIGH'}
        elseif($pct -lt 10){Add-Finding 'P2' 'HIGH-CONFIDENCE CONTRIBUTOR' ("Low free space on {0}:" -f $v.DriveLetter) ("{0:N1}% free" -f $pct) 'Can reduce Windows and application headroom.' 'Free safe temporary data and review large applications/files.' 'SAFE CLEANUP MAY HELP' 'HIGH'}
        elseif($pct -lt 15){Add-Finding 'P3' 'POSSIBLE CONTRIBUTOR' ("Limited free space on {0}:" -f $v.DriveLetter) ("{0:N1}% free" -f $pct) 'May become a constraint.' 'Monitor and free space if practical.' 'OPTIONAL' 'HIGH'}
    }
}

# Storage health
$pds=Import-CsvSafe (Join-Path $diag 'Storage\Physical_Disks.csv')
$rel=Import-CsvSafe (Join-Path $diag 'Storage\Storage_Reliability_Counters.csv')
$smart=Import-CsvSafe (Join-Path $diag 'Storage\SMART_FailurePredictStatus.csv')
foreach($d in $pds){
    $status='HEALTHY';$risk='Low';$ev=@()
    if($d.HealthStatus -and $d.HealthStatus -ne 'Healthy'){$status='DEGRADATION DETECTED';$risk='High';$ev+="HealthStatus=$($d.HealthStatus)";Add-Finding 'P0' 'CONFIRMED PROBLEM' ("Storage health warning: {0}" -f $d.FriendlyName) ("HealthStatus=$($d.HealthStatus); Operational=$($d.OperationalStatus)") 'Potential data-loss/performance risk.' 'Back up important data before write-heavy repair; investigate drive replacement/diagnostics.' 'DO NOT AUTOMATE' 'HIGH'}
    $r=$rel|Where-Object{$_.FriendlyName -eq $d.FriendlyName}|Select-Object -First 1
    if($r){
        $ru=0.0;$wu=0.0;$wear=0.0
        [double]::TryParse([string]$r.ReadErrorsUncorrected,[ref]$ru)|Out-Null;[double]::TryParse([string]$r.WriteErrorsUncorrected,[ref]$wu)|Out-Null;[double]::TryParse([string]$r.Wear,[ref]$wear)|Out-Null
        if($ru -gt 0 -or $wu -gt 0){$status='HIGH FAILURE RISK';$risk='High';$ev+="UncorrectedErrors R=$ru W=$wu";Add-Finding 'P0' 'CONFIRMED PROBLEM' ("Uncorrected storage errors: {0}" -f $d.FriendlyName) ("ReadUncorrected=$ru; WriteUncorrected=$wu") 'May cause retries, corruption, severe stalls or data loss.' 'Back up data and run vendor diagnostics/replacement assessment.' 'DO NOT AUTOMATE' 'HIGH'}
        if($wear -ge 90){$status='DEGRADATION DETECTED';$risk='High';$ev+="Wear=$wear";Add-Finding 'P1' 'HIGH-CONFIDENCE CONTRIBUTOR' ("SSD endurance heavily consumed: {0}" -f $d.FriendlyName) ("Windows reliability Wear=$wear") 'May indicate the drive is approaching endurance limits; interpretation remains device-dependent.' 'Confirm with vendor SMART/NVMe utility and plan replacement if corroborated.' 'DO NOT AUTOMATE' 'MEDIUM'}
        elseif($wear -ge 80){$status='HEALTHY WITH MINOR WARNINGS';$risk='Moderate';$ev+="Wear=$wear";Add-Finding 'P2' 'POSSIBLE CONTRIBUTOR' ("High reported SSD wear: {0}" -f $d.FriendlyName) ("Windows reliability Wear=$wear") 'Potential endurance concern.' 'Confirm with vendor health utility.' 'DO NOT AUTOMATE' 'MEDIUM'}
    }
    $hardware.Add([pscustomobject]@{Component=('Storage: '+$d.FriendlyName);Health=$status;Risk=$risk;Evidence=($ev -join '; ');Action=if($risk -eq 'High'){'Back up and investigate'}else{'Monitor'}})
}
foreach($s in $smart){if(([string]$s.PredictFailure) -match 'True') {Add-Finding 'P0' 'CONFIRMED PROBLEM' 'SMART predicts storage failure' ("Instance=$($s.InstanceName); Reason=$($s.Reason)") 'High data-loss and performance risk.' 'Back up important data immediately and replace/diagnose the affected drive.' 'DO NOT AUTOMATE' 'HIGH'}}

# WHEA/storage events/problem devices
$whea=Import-CsvSafe (Join-Path $diag 'EventLogs\WHEA_7d.csv')
if($whea.Count -gt 0){$pri=if($whea.Count -ge 5){'P1'}else{'P2'};Add-Finding $pri 'HIGH-CONFIDENCE CONTRIBUTOR' 'Hardware error events (WHEA) detected' ("$($whea.Count) WHEA events in last 7 days") 'Can indicate CPU, RAM, PCIe, motherboard, GPU, or storage instability.' 'Inspect event details; correlate component/error type before replacing anything.' 'DO NOT AUTOMATE' 'HIGH';$hardware.Add([pscustomobject]@{Component='CPU/RAM/PCIe platform';Health='DEGRADATION/INSTABILITY SIGNAL';Risk='Moderate-High';Evidence="$($whea.Count) WHEA events/7d";Action='Analyze WHEA records'})}
else{$hardware.Add([pscustomobject]@{Component='CPU/RAM/PCIe platform';Health='NO WHEA WARNING OBSERVED';Risk='Low/Unknown';Evidence='No WHEA events collected in 7-day window';Action='Continue monitoring'})}
$storageEv=Import-CsvSafe (Join-Path $diag 'EventLogs\Storage_Related_7d.csv')
if($storageEv.Count -ge 3){Add-Finding 'P2' 'HIGH-CONFIDENCE CONTRIBUTOR' 'Recurring storage/controller warnings or errors' ("$($storageEv.Count) storage-related warning/error events in 7 days") 'May cause I/O retries, latency, or instability.' 'Correlate provider/Event IDs with the affected disk/controller.' 'DO NOT AUTOMATE' 'HIGH'}
$dev=Import-CsvSafe (Join-Path $diag 'Devices\Problem_Devices.csv')
if($dev.Count -gt 0){Add-Finding 'P2' 'CONFIRMED PROBLEM' 'Device Manager reports problem devices' ("$($dev.Count) devices with non-zero ConfigManagerErrorCode") 'Driver/device problems can cause poor performance or instability.' 'Review the problem-device CSV and update/repair from trusted vendor sources.' 'MANUAL REVIEW' 'HIGH'}

# RAM hardware evidence
$memDiag=Import-CsvSafe (Join-Path $diag 'EventLogs\MemoryDiagnostic_30d.csv')
$memText=(($memDiag|ForEach-Object{$_.Message}) -join " `n")
if($memText -match '(?i)hardware problems were detected|memory problems were detected'){
    Add-Finding 'P0' 'CONFIRMED PROBLEM' 'Windows Memory Diagnostic reported hardware problems' 'MemoryDiagnostics-Results contains a hardware/memory-problem result.' 'Unstable RAM can cause crashes, corruption, retries and severe slowness.' 'Back up important work and perform an offline extended memory test; inspect modules/slots.' 'DO NOT AUTOMATE' 'HIGH'
    $hardware.Add([pscustomobject]@{Component='RAM';Health='HIGH FAILURE/INSTABILITY RISK';Risk='High';Evidence='Windows Memory Diagnostic reported hardware problems';Action='Offline extended memory testing/manual hardware review'})
}elseif($memText -match '(?i)no errors|no memory errors|tested the computer''s memory and detected no errors'){
    $hardware.Add([pscustomobject]@{Component='RAM';Health='NO ERROR REPORTED BY RECENT WINDOWS MEMORY DIAGNOSTIC';Risk='Low/Unknown';Evidence='Recent MemoryDiagnostics-Results reported no errors';Action='Monitor; this does not prove all RAM faults are impossible'})
}else{
    $hardware.Add([pscustomobject]@{Component='RAM';Health='UNKNOWN - NO CONCLUSIVE MEMORY TEST RESULT';Risk='Unknown';Evidence='No conclusive recent Windows Memory Diagnostic result parsed';Action='Run offline memory test only if crashes/WHEA/corruption suggest RAM instability'})
}

# GPU hardware/driver stability evidence
$gpuEv=Import-CsvSafe (Join-Path $diag 'EventLogs\Display_GPU_7d.csv')
if($gpuEv.Count -ge 3){
    Add-Finding 'P2' 'HIGH-CONFIDENCE CONTRIBUTOR' 'Recurring GPU/display driver errors' ("$($gpuEv.Count) GPU/display-related warning/error events in 7 days") 'Can cause UI stutter, freezes, resets or application slowdowns.' 'Correlate driver/provider/Event IDs; review trusted GPU/OEM driver and thermal/power evidence.' 'MANUAL REVIEW' 'HIGH'
    $hardware.Add([pscustomobject]@{Component='GPU';Health='INSTABILITY SIGNAL';Risk='Moderate';Evidence="$($gpuEv.Count) display/GPU warning/error events in 7 days";Action='Review event IDs, driver, thermals and power'})
}elseif($gpuEv.Count -gt 0){
    $hardware.Add([pscustomobject]@{Component='GPU';Health='MINOR/ISOLATED WARNING OBSERVED';Risk='Low-Moderate';Evidence="$($gpuEv.Count) display/GPU event(s) in 7 days";Action='Monitor for recurrence'})
}else{
    $hardware.Add([pscustomobject]@{Component='GPU';Health='NO RECURRING GPU ERROR OBSERVED';Risk='Low/Unknown';Evidence='No matching display/GPU warning/error events collected in 7 days';Action='Continue monitoring'})
}

# Battery/thermal telemetry availability
$batFile=Join-Path $diag 'PowerThermal\battery-report.html'
if(Test-Path $batFile){$hardware.Add([pscustomobject]@{Component='Battery';Health='TELEMETRY AVAILABLE - REVIEW CAPACITY REPORT';Risk='Unknown';Evidence='Windows battery-report.html generated';Action='Compare Full Charge Capacity with Design Capacity'})}
else{$hardware.Add([pscustomobject]@{Component='Battery';Health='NOT PRESENT / NOT EXPOSED';Risk='N/A';Evidence='No Windows battery report generated (normal on desktops)';Action='None'})}
$thermalRaw=Import-CsvSafe (Join-Path $diag 'PowerThermal\ThermalZone_Raw.csv')
if($thermalRaw.Count -gt 0){$hardware.Add([pscustomobject]@{Component='Cooling/Thermal';Health='RAW ACPI TELEMETRY AVAILABLE';Risk='Unknown';Evidence='ACPI thermal-zone data captured; not treated as CPU/GPU core temperature';Action='Correlate with throttling/events; use vendor sensor telemetry if needed'})}
else{$hardware.Add([pscustomobject]@{Component='Cooling/Thermal';Health='INSUFFICIENT BUILT-IN TELEMETRY';Risk='Unknown';Evidence='Reliable temperature data not exposed through collected Windows interfaces';Action='Use reputable vendor/sensor telemetry only if thermal symptoms exist'})}

# Windows integrity
$dism=Read-TextSafe (Join-Path $diag 'WindowsHealth\DISM_CheckHealth.txt')
$sfc=Read-TextSafe (Join-Path $diag 'WindowsHealth\SFC_VerifyOnly.txt')
$analyze=Read-TextSafe (Join-Path $diag 'WindowsHealth\DISM_AnalyzeComponentStore.txt')
$dismRepair=($dism -match '(?i)repairable|component store is repairable|corruption detected') -and -not($dism -match '(?i)No component store corruption detected')
$sfcRepair=($sfc -match '(?i)found integrity violations|found corrupt files') -and -not($sfc -match '(?i)did not find any integrity violations')
$cleanupRecommended=($analyze -match '(?i)Component Store Cleanup Recommended\s*:\s*Yes')
if($dismRepair){Add-Finding 'P2' 'CONFIRMED PROBLEM' 'Windows component-store corruption indicated' 'DISM CheckHealth reported a repairable/corruption condition.' 'May affect updates, servicing, and stability.' 'Run DISM RestoreHealth, then SFC.' 'SAFE TO AUTOMATE WITH RESTORE POINT' 'MEDIUM'}
if($sfcRepair){Add-Finding 'P2' 'CONFIRMED PROBLEM' 'Windows protected-file integrity violations indicated' 'SFC verify-only output indicates integrity violations/corrupt files.' 'Can cause Windows/application instability.' 'Run SFC /scannow; use DISM first if component store is unhealthy.' 'SAFE TO AUTOMATE WITH RESTORE POINT' 'MEDIUM'}

# Temp data estimate
$temp=Read-TextSafe (Join-Path $diag 'Applications\Temporary_Data_Estimate.txt');$tempBytes=0L
if($temp -match 'TotalTempBytes=(\d+)'){$tempBytes=[int64]$Matches[1]}
if($tempBytes -ge 2GB){Add-Finding 'P4' 'MINOR OPTIMIZATION' 'Large temporary-data footprint' ("Estimated user/Windows temp: $(Format-Bytes $tempBytes)") 'Mainly consumes space; only indirectly affects performance when storage is constrained.' 'Delete old temp entries only; never personal folders.' 'SAFE TO AUTOMATE' 'HIGH'}

# Event/app reliability summaries
$appEv=Import-CsvSafe (Join-Path $diag 'EventLogs\Application_Warnings_Errors_7d.csv')
if($appEv.Count -ge 50){Add-Finding 'P3' 'POSSIBLE CONTRIBUTOR' 'High volume of application warnings/errors' ("$($appEv.Count) application warning/error events collected in 7 days") 'Recurring crashes/hangs may degrade experience.' 'Group by provider/Event ID and fix the repeat offender rather than all events.' 'MANUAL REVIEW' 'MEDIUM'}

# Plan: deliberately narrow and evidence-gated
$plan=[ordered]@{
    Version='2.0';Generated=(Get-Date -Format o);RunRoot=$RunRoot;
    CreateRestorePoint=$true;
    CleanupOldTemp=($tempBytes -ge 512MB);
    TempAgeDays=7;
    DISMRestoreHealth=[bool]$dismRepair;
    SFCScannow=[bool]$sfcRepair;
    ComponentStoreCleanup=[bool]$cleanupRecommended;
    FlushDns=$false;
    ReTrimSystemSSD=$false;
    ClearRecycleBin=$false;
    WindowsUpdateReset=$false;
    NetworkStackReset=$false;
    DisableStartupItems=$false;
    DisableServices=$false;
    DriverInstall=$false;
    FirmwareUpdate=$false;
    OfflineChkdskRepair=$false;
    Notes=@('Only low-risk evidence-gated actions are enabled automatically.','Review hardware warnings before repair.','Missing telemetry is not interpreted as healthy.')
}
$plan['CreateRestorePoint']=[bool]($plan.CleanupOldTemp -or $plan.DISMRestoreHealth -or $plan.SFCScannow -or $plan.ComponentStoreCleanup)
$plan|ConvertTo-Json -Depth 5|Set-Content (Join-Path $out 'REPAIR_PLAN.json') -Encoding UTF8

# Reports
$findings|Export-Csv (Join-Path $out 'FINDINGS.csv') -NoTypeInformation -Encoding UTF8
$hardware|Export-Csv (Join-Path $out 'HARDWARE_HEALTH.csv') -NoTypeInformation -Encoding UTF8
$priorityOrder=@{'P0'=0;'P1'=1;'P2'=2;'P3'=3;'P4'=4;'P5'=5}
$sorted=$findings|Sort-Object @{e={$priorityOrder[$_.Priority]}},Issue
$report=New-Object System.Collections.Generic.List[string]
$report.Add('WINDOWS PERFORMANCE ROOT-CAUSE ANALYSIS');$report.Add('======================================');$report.Add("Run: $RunRoot");$report.Add("Generated: $(Get-Date)");$report.Add('')
if($sorted.Count -eq 0){$report.Add('NO SIGNIFICANT PROBLEM DETECTED BY THE CONSERVATIVE LOCAL RULE SET.');$report.Add('This is not proof that every component is healthy; review raw telemetry and unavailable-data notes.')}
foreach($f in $sorted){$report.Add("[$($f.Priority)] $($f.Issue)");$report.Add("  Classification: $($f.Classification)");$report.Add("  Confidence: $($f.Confidence)");$report.Add("  Evidence: $($f.Evidence)");$report.Add("  Impact: $($f.Impact)");$report.Add("  Action: $($f.RecommendedAction)");$report.Add("  Automation: $($f.Automation)");$report.Add('')}
$report|Set-Content (Join-Path $out 'ANALYSIS_REPORT.txt') -Encoding UTF8
$hardware|Format-Table -AutoSize|Out-String -Width 240|Set-Content (Join-Path $out 'HARDWARE_HEALTH_REPORT.txt') -Encoding UTF8
@('REPAIR PLAN SUMMARY','===================',"CleanupOldTemp: $($plan.CleanupOldTemp)","DISMRestoreHealth: $($plan.DISMRestoreHealth)","SFCScannow: $($plan.SFCScannow)","ComponentStoreCleanup: $($plan.ComponentStoreCleanup)",'','All other potentially disruptive repairs remain disabled/manual by default.')|Set-Content (Join-Path $out 'REPAIR_PLAN_SUMMARY.txt') -Encoding UTF8
Write-ToolkitLog $log 'Evidence analysis complete.'
Write-Host "Analysis saved: $out" -ForegroundColor Green
