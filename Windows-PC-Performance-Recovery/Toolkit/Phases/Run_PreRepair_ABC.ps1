$scriptDir=Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path (Split-Path -Parent $scriptDir) 'Core\Common.ps1')
$packageRoot=Split-Path -Parent (Split-Path -Parent $scriptDir)
$run=New-ToolkitRun $packageRoot
Write-Host "New run: $run" -ForegroundColor Cyan
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $scriptDir 'Phase_A_Baseline.ps1') -RunRoot $run
if($LASTEXITCODE -ne 0){Write-Warning 'Phase A returned a non-zero exit code; continuing to collect diagnostics.'}
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $scriptDir 'Phase_B_FullDiagnostic.ps1') -RunRoot $run
if($LASTEXITCODE -ne 0){Write-Warning 'Phase B returned a non-zero exit code; Phase C will analyze what was collected.'}
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $scriptDir 'Phase_C_Analyze.ps1') -RunRoot $run
Write-Host '';Write-Host 'PHASES A+B+C COMPLETE' -ForegroundColor Green;Write-Host "Review: $run\Phase_C_Analysis\ANALYSIS_REPORT.txt" -ForegroundColor Yellow;Write-Host "Plan:   $run\Phase_C_Analysis\REPAIR_PLAN.json" -ForegroundColor Yellow
