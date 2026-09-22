param([string]$RunRoot)
$scriptDir=Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path (Split-Path -Parent $scriptDir) 'Core\Common.ps1')
$packageRoot=Split-Path -Parent (Split-Path -Parent $scriptDir)
if(-not $RunRoot){$RunRoot=Get-LatestToolkitRun $packageRoot}
if(-not $RunRoot){throw 'No run found.'}
$post=Join-Path $RunRoot 'Phase_E_PostRepair';New-Item -ItemType Directory -Force -Path $post|Out-Null
$phaseA=Join-Path $scriptDir 'Phase_A_Baseline.ps1';$phaseB=Join-Path $scriptDir 'Phase_B_FullDiagnostic.ps1';$phaseC=Join-Path $scriptDir 'Phase_C_Analyze.ps1'
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $phaseA -RunRoot $RunRoot -Samples 15 -IntervalSeconds 2 -OutputSubfolder 'Phase_E_PostRepair\Baseline'
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $phaseB -RunRoot $RunRoot -PostRepair
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $phaseC -RunRoot $RunRoot -PostRepair
Write-Host "Post-repair retest complete: $post" -ForegroundColor Green
