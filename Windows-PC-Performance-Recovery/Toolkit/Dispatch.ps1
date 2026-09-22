param([Parameter(Mandatory=$true)][string]$Action)
$ErrorActionPreference='Stop'
try {
    $phases=Join-Path $PSScriptRoot 'Phases'
    switch($Action){
        'ABC' { & (Join-Path $phases 'Run_PreRepair_ABC.ps1') }
        {$_ -in 'A','B','Open'} {
            . (Join-Path $PSScriptRoot 'Core\Common.ps1')
            $ErrorActionPreference='Stop'
            $root=Split-Path -Parent $PSScriptRoot
            $run=Get-LatestToolkitRun $root
            if($Action -eq 'Open'){
                if($run){Start-Process explorer.exe -ArgumentList ('"{0}"' -f $run)}else{Write-Host 'No run exists yet.'}
            } else {
                if(-not $run){$run=New-ToolkitRun $root}
                $name=if($Action -eq 'A'){'Phase_A_Baseline.ps1'}else{'Phase_B_FullDiagnostic.ps1'}
                & (Join-Path $phases $name) -RunRoot $run
            }
        }
        'C' { & (Join-Path $phases 'Phase_C_Analyze.ps1') }
        'DryRun' { & (Join-Path $phases 'Phase_D_Repair.ps1') -DryRun }
        'Apply' { & (Join-Path $phases 'Phase_D_Repair.ps1') }
        'EF' {
            & (Join-Path $PSHOME 'powershell.exe') -NoProfile -ExecutionPolicy Bypass -File (Join-Path $phases 'Phase_E_PostRepair.ps1')
            if($LASTEXITCODE -ne 0){throw "Post-repair phase failed with exit $LASTEXITCODE. Comparison skipped."}
            & (Join-Path $phases 'Phase_F_Compare.ps1')
        }
        'G' { & (Join-Path $phases 'Phase_G_HardwareTrend.ps1') }
        'Export' { & (Join-Path $phases 'Export_Latest_Run.ps1') }
        'SelfTest' { & (Join-Path $phases 'SelfTest.ps1') }
        default {throw "Unknown action: $Action"}
    }
} catch {Write-Host "ACTION ERROR: $_" -ForegroundColor Red;Write-Host $_.ScriptStackTrace;exit 1}
