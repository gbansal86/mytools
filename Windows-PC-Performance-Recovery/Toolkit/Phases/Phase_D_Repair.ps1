param([string]$RunRoot,[switch]$DryRun,[switch]$Yes)
$scriptDir=Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path (Split-Path -Parent $scriptDir) 'Core\Common.ps1')
$packageRoot=Split-Path -Parent (Split-Path -Parent $scriptDir)
if(-not $RunRoot){$RunRoot=Get-LatestToolkitRun $packageRoot}
if(-not $RunRoot){throw 'No run found.'}
$planPath=Join-Path $RunRoot 'Phase_C_Analysis\REPAIR_PLAN.json'
if(-not(Test-Path $planPath)){throw 'REPAIR_PLAN.json is missing. Run Phase C first.'}
$plan=Get-Content $planPath -Raw|ConvertFrom-Json
$out=Join-Path $RunRoot 'Phase_D_Repair';New-Item -ItemType Directory -Force -Path $out|Out-Null
$rollback=Join-Path $out 'Rollback';New-Item -ItemType Directory -Force -Path $rollback|Out-Null
$log=Join-Path $out 'REPAIR_LOG.txt';$summary=New-Object System.Collections.Generic.List[string]
Write-ToolkitLog $log ("Phase D started. DryRun={0}" -f $DryRun)
if(-not(Test-ToolkitAdmin)){Write-ToolkitLog $log 'Administrator rights are required for repair actions.' 'ERROR';throw 'Run the repair BAT as Administrator.'}

function Confirm-Action([string]$Text){if($Yes){return $true};$a=Read-Host "$Text [y/N]";return ($a -match '^[Yy]')}
function Log-Action([string]$Name,[string]$Result){$summary.Add("$Name : $Result");Write-ToolkitLog $log "$Name : $Result"}

# Preserve plan and environment
Copy-Item $planPath (Join-Path $out 'REPAIR_PLAN_USED.json') -Force
Get-ComputerInfo|Select WindowsProductName,WindowsVersion,OsBuildNumber,OsLastBootUpTime|Format-List|Out-File (Join-Path $out 'PRE_REPAIR_STATE.txt') -Encoding UTF8

# Restore point
if($plan.CreateRestorePoint){
    if($DryRun){Log-Action 'Restore point' 'WOULD ATTEMPT'}
    else{try{Enable-ComputerRestore -Drive "$env:SystemDrive\" -ErrorAction SilentlyContinue;Checkpoint-Computer -Description ("WindowsPerformanceToolkit_{0}" -f (Get-Date -Format 'yyyyMMdd_HHmmss')) -RestorePointType MODIFY_SETTINGS -ErrorAction Stop;Log-Action 'Restore point' 'CREATED'}catch{Log-Action 'Restore point' ("FAILED/UNAVAILABLE: $($_.Exception.Message)")}}
}

# Safe temp cleanup (old entries only; no user documents/downloads/browser profiles)
if($plan.CleanupOldTemp){
    $days=[int]$plan.TempAgeDays;if($days -lt 1){$days=7};$cutoff=(Get-Date).AddDays(-$days)
    $targets=@($env:TEMP,(Join-Path $env:windir 'Temp'))|Select-Object -Unique
    $candidates=New-Object System.Collections.Generic.List[object]
    foreach($t in $targets){if(Test-Path $t){Get-ChildItem -LiteralPath $t -Force -ErrorAction SilentlyContinue|Where-Object{$_.LastWriteTime -lt $cutoff}|ForEach-Object{$candidates.Add($_)}}}
    $estimated=0L;foreach($c in $candidates){if($c.PSIsContainer){$estimated+=Get-DirectorySizeBytes $c.FullName}else{$estimated+=[int64]$c.Length}}
    Log-Action 'Old temp cleanup estimate' ("$(Format-Bytes $estimated), older than $days days")
    if($DryRun){Log-Action 'Old temp cleanup' 'WOULD DELETE ELIGIBLE TEMP ITEMS ONLY'}
    elseif(Confirm-Action "Delete eligible temp entries older than $days days (estimated $(Format-Bytes $estimated))?"){
        $deleted=0L
        foreach($c in $candidates){
            try{$sz=if($c.PSIsContainer){Get-DirectorySizeBytes $c.FullName}else{[int64]$c.Length};Remove-Item -LiteralPath $c.FullName -Recurse -Force -ErrorAction Stop;$deleted+=$sz}catch{Write-ToolkitLog $log ("Skipped locked/in-use temp item: $($c.FullName)") 'WARN'}
        }
        Log-Action 'Old temp cleanup' ("COMPLETED; approximately $(Format-Bytes $deleted) removed")
    }else{Log-Action 'Old temp cleanup' 'SKIPPED BY USER'}
}

# Windows component repair only if Phase C evidence enabled it
if($plan.DISMRestoreHealth){
    if($DryRun){Log-Action 'DISM RestoreHealth' 'WOULD RUN'}
    elseif(Confirm-Action 'Run DISM /RestoreHealth because Phase C detected component-store corruption?'){
        & DISM.exe /Online /Cleanup-Image /RestoreHealth 2>&1|Tee-Object -FilePath (Join-Path $out 'DISM_RestoreHealth.txt')
        Log-Action 'DISM RestoreHealth' ("EXITCODE=$LASTEXITCODE")
    }else{Log-Action 'DISM RestoreHealth' 'SKIPPED BY USER'}
}
if($plan.SFCScannow){
    if($DryRun){Log-Action 'SFC /scannow' 'WOULD RUN'}
    elseif(Confirm-Action 'Run SFC /scannow because Phase C detected protected-file integrity issues?'){
        & sfc.exe /scannow 2>&1|Tee-Object -FilePath (Join-Path $out 'SFC_Scannow.txt')
        Log-Action 'SFC /scannow' ("EXITCODE=$LASTEXITCODE")
    }else{Log-Action 'SFC /scannow' 'SKIPPED BY USER'}
}
if($plan.ComponentStoreCleanup){
    if($DryRun){Log-Action 'Component store cleanup' 'WOULD RUN DISM StartComponentCleanup'}
    elseif(Confirm-Action 'Run Windows-supported component-store cleanup because DISM analysis recommended it?'){
        & DISM.exe /Online /Cleanup-Image /StartComponentCleanup 2>&1|Tee-Object -FilePath (Join-Path $out 'DISM_StartComponentCleanup.txt')
        Log-Action 'Component store cleanup' ("EXITCODE=$LASTEXITCODE")
    }else{Log-Action 'Component store cleanup' 'SKIPPED BY USER'}
}

# Explicitly document operations intentionally not automated
@(
'NOT AUTOMATED BY THIS PACKAGE','=============================',
'Driver installation/replacement','BIOS/firmware flashing','Offline CHKDSK repair','Startup-item disabling','Service disabling','Application uninstall','Pagefile hacks','Registry optimization hacks','Security reduction','Network stack reset','Windows Update reset','Disk firmware operations','Hardware stress testing',
'', 'These require evidence-specific/manual review because a generic repair can make the system worse.'
)|Set-Content (Join-Path $out 'MANUAL_ONLY_ACTIONS.txt') -Encoding UTF8

$summary.Insert(0,'WINDOWS PERFORMANCE TOOLKIT - REPAIR SUMMARY');$summary.Insert(1,'============================================');$summary.Insert(2,"DryRun: $DryRun");$summary.Insert(3,"Run: $RunRoot");$summary|Set-Content (Join-Path $out 'REPAIR_SUMMARY.txt') -Encoding UTF8
Write-ToolkitLog $log 'Phase D complete.'
Write-Host "Repair phase complete: $out" -ForegroundColor Green
