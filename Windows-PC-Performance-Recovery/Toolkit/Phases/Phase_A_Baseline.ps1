param([string]$RunRoot,[int]$Samples=15,[int]$IntervalSeconds=2,[string]$OutputSubfolder='Phase_A_Baseline')
$scriptDir=Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path (Split-Path -Parent $scriptDir) 'Core\Common.ps1')
$packageRoot=Split-Path -Parent (Split-Path -Parent $scriptDir)
if(-not $RunRoot){$RunRoot=Get-LatestToolkitRun $packageRoot;if(-not $RunRoot){$RunRoot=New-ToolkitRun $packageRoot}}
$out=Join-Path $RunRoot $OutputSubfolder;New-Item -ItemType Directory -Force -Path $out|Out-Null
$log=Join-Path $out 'PHASE_A.log';Write-ToolkitLog $log 'Phase A baseline started.'

Save-ToolkitText (Join-Path $out 'System_State.txt') {
    "Collected: $(Get-Date -Format o)";"Computer: $env:COMPUTERNAME";"Administrator: $(Test-ToolkitAdmin)"
    Get-CimInstance Win32_OperatingSystem|Select Caption,Version,BuildNumber,LastBootUpTime,FreePhysicalMemory,TotalVisibleMemorySize|Format-List
    Get-CimInstance Win32_ComputerSystem|Select Manufacturer,Model,TotalPhysicalMemory,NumberOfLogicalProcessors|Format-List
}

$rows=New-Object System.Collections.Generic.List[object]
for($i=1;$i -le $Samples;$i++){
    $os=Get-CimInstance Win32_OperatingSystem
    $cpu=(Get-CimInstance Win32_Processor|Measure-Object LoadPercentage -Average).Average
    $disk=$null
    try{$disk=Get-CimInstance Win32_PerfFormattedData_PerfDisk_PhysicalDisk -ErrorAction Stop|Where-Object{$_.Name -eq '_Total'}|Select-Object -First 1}catch{}
    $memUsedPct=100*(1-([double]$os.FreePhysicalMemory/[double]$os.TotalVisibleMemorySize))
    $rows.Add([pscustomobject]@{
        Sample=$i;Timestamp=(Get-Date -Format o);CpuLoadPct=[math]::Round([double]$cpu,1);MemoryUsedPct=[math]::Round($memUsedPct,1);
        FreePhysicalMB=[math]::Round([double]$os.FreePhysicalMemory/1024,1);ProcessCount=(Get-Process).Count;
        DiskReadBytesSec=if($disk){$disk.DiskReadBytesPersec}else{$null};DiskWriteBytesSec=if($disk){$disk.DiskWriteBytesPersec}else{$null};
        AvgDiskSecTransfer=if($disk){$disk.AvgDisksecPerTransfer}else{$null};CurrentDiskQueue=if($disk){$disk.CurrentDiskQueueLength}else{$null}
    })
    if($i -lt $Samples){Start-Sleep -Seconds $IntervalSeconds}
}
$rows|Export-Csv (Join-Path $out 'Baseline_Samples.csv') -NoTypeInformation -Encoding UTF8

Save-ToolkitCsv (Join-Path $out 'Top_RAM_Processes.csv') {Get-Process|Sort-Object WorkingSet64 -Descending|Select-Object -First 30 Name,Id,@{n='WorkingSetMB';e={[math]::Round($_.WorkingSet64/1MB,2)}},@{n='PrivateMB';e={[math]::Round($_.PrivateMemorySize64/1MB,2)}},CPU,Handles,Path}
Save-ToolkitCsv (Join-Path $out 'Top_CPU_Delta_Processes.csv') {
    $a=@{};Get-Process|ForEach-Object{$a[$_.Id]=[double]$_.CPU};Start-Sleep 5
    $cpuRows = foreach($p in Get-Process){ if($a.ContainsKey($p.Id) -and $null -ne $p.CPU){ [pscustomobject]@{Name=$p.Name;Id=$p.Id;CPUSecondsDelta5s=[math]::Round(([double]$p.CPU-$a[$p.Id]),3);WorkingSetMB=[math]::Round($p.WorkingSet64/1MB,2);Path=$p.Path} } }
    $cpuRows | Sort-Object CPUSecondsDelta5s -Descending | Select-Object -First 30
}

$sysdrive=$env:SystemDrive
Save-ToolkitText (Join-Path $out 'System_Drive_FreeSpace.txt') {Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$sysdrive'"|Select DeviceID,Size,FreeSpace,@{n='FreePct';e={if($_.Size){[math]::Round(100*$_.FreeSpace/$_.Size,1)}}}|Format-List}
Write-ToolkitLog $log 'Phase A baseline complete.'
Write-Host "Baseline saved: $out" -ForegroundColor Green
