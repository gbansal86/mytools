param([string]$PackageRoot)
$scriptDir=Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path (Split-Path -Parent $scriptDir) 'Core\Common.ps1')
if(-not $PackageRoot){$PackageRoot=Split-Path -Parent (Split-Path -Parent $scriptDir)}
$out=Join-Path $PackageRoot 'History';New-Item -ItemType Directory -Force -Path $out|Out-Null
$rows=New-Object System.Collections.Generic.List[object]
Get-ChildItem (Join-Path $PackageRoot 'Runs') -Directory -ErrorAction SilentlyContinue|Sort-Object Name|ForEach-Object{
    $run=$_.Name
    $p=Join-Path $_.FullName 'Phase_B_Diagnostics\Storage\Hardware_Trend_Snapshot.csv'
    if(Test-Path $p){foreach($r in Import-Csv $p){$rows.Add([pscustomobject]@{Run=$run;Timestamp=$r.Timestamp;ComponentType=$r.ComponentType;Name=$r.Name;DeviceHash=$r.DeviceHash;Health=$r.Health;Operational=$r.Operational;MediaType=$r.MediaType;BusType=$r.BusType;Wear=$r.Wear;Temperature=$r.Temperature;PowerOnHours=$r.PowerOnHours;ReadErrorsUncorrected=$r.ReadErrorsUncorrected;WriteErrorsUncorrected=$r.WriteErrorsUncorrected})}}
}
$csv=Join-Path $out 'Hardware_Trend_History.csv';$rows|Export-Csv $csv -NoTypeInformation -Encoding UTF8
$report=New-Object System.Collections.Generic.List[string];$report.Add('HARDWARE DEGRADATION TREND REPORT');$report.Add('=================================');$report.Add("Snapshots: $($rows.Count)");$report.Add('')
foreach($g in ($rows|Group-Object DeviceHash)){
    $s=@($g.Group|Sort-Object Timestamp);if($s.Count -lt 1){continue};$first=$s[0];$last=$s[-1]
    $report.Add("$($last.Name) [$($last.DeviceHash)]");$report.Add("  First: $($first.Timestamp) Health=$($first.Health) Wear=$($first.Wear) ReadUncorr=$($first.ReadErrorsUncorrected) WriteUncorr=$($first.WriteErrorsUncorrected)");$report.Add("  Latest: $($last.Timestamp) Health=$($last.Health) Wear=$($last.Wear) ReadUncorr=$($last.ReadErrorsUncorrected) WriteUncorr=$($last.WriteErrorsUncorrected)")
    $report.Add('  Review increases in wear or uncorrected errors; missing values mean the drive/Windows did not expose that metric.');$report.Add('')
}

$platformRows=New-Object System.Collections.Generic.List[object]
Get-ChildItem (Join-Path $PackageRoot 'Runs') -Directory -ErrorAction SilentlyContinue|Sort-Object Name|ForEach-Object{
    $run=$_.Name;$d=Join-Path $_.FullName 'Phase_B_Diagnostics'
    if(Test-Path $d){
        function CountCsvLocal([string]$q){if(Test-Path $q){try{return @(Import-Csv $q).Count}catch{return 0}}return 0}
        $platformRows.Add([pscustomobject]@{
            Run=$run;
            WHEA_7d=CountCsvLocal (Join-Path $d 'EventLogs\WHEA_7d.csv');
            StorageEvents_7d=CountCsvLocal (Join-Path $d 'EventLogs\Storage_Related_7d.csv');
            GPUDisplayEvents_7d=CountCsvLocal (Join-Path $d 'EventLogs\Display_GPU_7d.csv');
            ProblemDevices=CountCsvLocal (Join-Path $d 'Devices\Problem_Devices.csv');
            MemoryDiagnosticRecords_30d=CountCsvLocal (Join-Path $d 'EventLogs\MemoryDiagnostic_30d.csv')
        })
    }
}
$platformRows|Export-Csv (Join-Path $out 'Platform_Trend_History.csv') -NoTypeInformation -Encoding UTF8
$report.Add('PLATFORM ERROR SNAPSHOTS BY RUN')
$report.Add('-------------------------------')
$report.Add('Counts use rolling diagnostic windows (for example 7 days), so compare trends cautiously rather than treating them as cumulative counters.')
foreach($r in $platformRows){$report.Add("$($r.Run): WHEA=$($r.WHEA_7d), StorageEvents=$($r.StorageEvents_7d), GPUDisplayEvents=$($r.GPUDisplayEvents_7d), ProblemDevices=$($r.ProblemDevices), MemoryDiagRecords=$($r.MemoryDiagnosticRecords_30d)")}
$report.Add('')

$report|Set-Content (Join-Path $out 'Hardware_Trend_Report.txt') -Encoding UTF8
Write-Host "Hardware trend report saved: $out" -ForegroundColor Green
