param([string]$RunRoot)
$scriptDir=Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path (Split-Path -Parent $scriptDir) 'Core\Common.ps1')
$packageRoot=Split-Path -Parent (Split-Path -Parent $scriptDir)
if(-not $RunRoot){$RunRoot=Get-LatestToolkitRun $packageRoot}
if(-not $RunRoot){throw 'No run found.'}
$pre=Join-Path $RunRoot 'Phase_A_Baseline\Baseline_Samples.csv';$post=Join-Path $RunRoot 'Phase_E_PostRepair\Baseline\Baseline_Samples.csv'
$out=Join-Path $RunRoot 'Phase_F_Comparison';New-Item -ItemType Directory -Force -Path $out|Out-Null
function Avg([object[]]$x,[string]$p){if(-not$x){return $null};$v=$x|Where-Object{$_.$p -ne '' -and $null-ne $_.$p}|ForEach-Object{[double]$_.$p};if($v){return ($v|Measure-Object -Average).Average};return $null}
if(-not(Test-Path $pre)){throw 'Pre-repair baseline missing.'};if(-not(Test-Path $post)){throw 'Post-repair baseline missing. Run Phase E first.'}
$a=@(Import-Csv $pre);$b=@(Import-Csv $post)
$metrics=@(
    @{Name='Average CPU load (%)';P='CpuLoadPct'},@{Name='Average memory used (%)';P='MemoryUsedPct'},@{Name='Average free physical memory (MB)';P='FreePhysicalMB'},@{Name='Average process count';P='ProcessCount'},@{Name='Average disk transfer latency (s)';P='AvgDiskSecTransfer'},@{Name='Average current disk queue';P='CurrentDiskQueue'}
)
$rows=foreach($m in $metrics){$x=Avg $a $m.P;$y=Avg $b $m.P;[pscustomobject]@{Metric=$m.Name;Before=if($null-ne$x){[math]::Round($x,3)}else{$null};After=if($null-ne$y){[math]::Round($y,3)}else{$null};Change=if($null-ne$x-and$null-ne$y){[math]::Round($y-$x,3)}else{$null};Interpretation='Compare only if workload conditions were similar.'}}
$rows|Export-Csv (Join-Path $out 'BEFORE_AFTER_COMPARISON.csv') -NoTypeInformation -Encoding UTF8
$lines=New-Object System.Collections.Generic.List[string];$lines.Add('BEFORE / AFTER PERFORMANCE COMPARISON');$lines.Add('=====================================');$lines.Add('Measurements are comparable only when the PC workload was similar during both captures.');$lines.Add('')
foreach($r in $rows){$lines.Add("$($r.Metric): BEFORE=$($r.Before) AFTER=$($r.After) CHANGE=$($r.Change)")}
$postFind=Join-Path $RunRoot 'Phase_E_PostRepair\Analysis\FINDINGS.csv'
if(Test-Path $postFind){$pf=@(Import-Csv $postFind);$lines.Add('');$lines.Add('REMAINING POST-REPAIR FINDINGS');$lines.Add('------------------------------');if($pf.Count -eq 0){$lines.Add('No significant issue identified by the conservative local analyzer.')}else{foreach($f in $pf|Sort-Object Priority){$lines.Add("[$($f.Priority)] $($f.Issue) - $($f.Evidence)")}}}
$lines|Set-Content (Join-Path $out 'BEFORE_AFTER_COMPARISON.txt') -Encoding UTF8
$final=New-Object System.Collections.Generic.List[string]
$final.Add('FINAL EXECUTIVE PERFORMANCE & HARDWARE REPORT');$final.Add('============================================');$final.Add("Run: $RunRoot");$final.Add("Generated: $(Get-Date)");$final.Add('')
$final.Add('1. PRE-REPAIR ROOT-CAUSE FINDINGS');$final.Add('---------------------------------')
$preAnalysis=Join-Path $RunRoot 'Phase_C_Analysis\ANALYSIS_REPORT.txt'
if(Test-Path $preAnalysis){Get-Content $preAnalysis|ForEach-Object{$final.Add($_)}}else{$final.Add('Pre-repair analysis not available.')}
$final.Add('');$final.Add('2. REPAIRS PERFORMED / DRY-RUN RESULTS');$final.Add('--------------------------------------')
$repair=Join-Path $RunRoot 'Phase_D_Repair\REPAIR_SUMMARY.txt'
if(Test-Path $repair){Get-Content $repair|ForEach-Object{$final.Add($_)}}else{$final.Add('No repair summary found. Repairs may not have been run.')}
$final.Add('');$final.Add('3. BEFORE / AFTER MEASUREMENTS');$final.Add('-------------------------------')
$lines|ForEach-Object{$final.Add($_)}
$final.Add('');$final.Add('4. POST-REPAIR HARDWARE / REMAINING ISSUES');$final.Add('-------------------------------------------')
$postHardware=Join-Path $RunRoot 'Phase_E_PostRepair\Analysis\HARDWARE_HEALTH_REPORT.txt'
if(Test-Path $postHardware){Get-Content $postHardware|ForEach-Object{$final.Add($_)}}else{$final.Add('Post-repair hardware report not available.')}
$final.Add('');$final.Add('5. SAFETY / INTERPRETATION');$final.Add('--------------------------')
$final.Add('A lower CPU/RAM/disk value is not automatically an improvement unless workload conditions were comparable.')
$final.Add('No missing hardware telemetry is treated as proof of health. Critical storage/WHEA/memory warnings require separate hardware review and data protection.')
$final|Set-Content (Join-Path $out 'FINAL_EXECUTIVE_REPORT.txt') -Encoding UTF8
Write-Host "Comparison and final executive report saved: $out" -ForegroundColor Green
