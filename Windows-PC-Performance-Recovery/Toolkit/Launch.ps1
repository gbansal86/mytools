param(
    [ValidateSet('Menu','ABC','A','B','C','DryRun','Apply','EF','G','Export','Open','SelfTest')]
    [string]$Action='Menu',
    [switch]$Elevated,
    [switch]$CheckOnly
)
$ErrorActionPreference='Stop'
$rc=0
$logging=$false
try {
    $log=Join-Path ([IO.Path]::GetTempPath()) ('PC_Recovery_Startup_{0}_{1}.log' -f (Get-Date -Format yyyyMMdd_HHmmss),$PID)
    try { Start-Transcript -LiteralPath $log -Force | Out-Null; $logging=$true } catch { Write-Host "Logging unavailable: $_" }
    Write-Host "Starting toolkit from: $PSScriptRoot" -ForegroundColor Cyan
    Write-Host "Startup log: $log"
    if($PSVersionTable.PSVersion -lt [version]'5.1'){throw 'Windows PowerShell 5.1 or newer is required.'}
    $root=Split-Path -Parent $PSScriptRoot
    Set-Location -LiteralPath $root
    $required=@('Core\Common.ps1','Dispatch.ps1','Phases\Run_PreRepair_ABC.ps1','Phases\Phase_A_Baseline.ps1','Phases\Phase_B_FullDiagnostic.ps1','Phases\Phase_C_Analyze.ps1','Phases\Phase_D_Repair.ps1','Phases\Phase_E_PostRepair.ps1','Phases\Phase_F_Compare.ps1','Phases\Phase_G_HardwareTrend.ps1','Phases\Export_Latest_Run.ps1','Phases\SelfTest.ps1')
    foreach($relative in $required){if(-not(Test-Path -LiteralPath (Join-Path $PSScriptRoot $relative) -PathType Leaf)){throw "Missing file: $relative. Extract the entire ZIP."}}
    foreach($file in Get-ChildItem -LiteralPath $PSScriptRoot -Filter '*.ps1' -Recurse){
        $tokens=$null;$errors=$null
        [Management.Automation.Language.Parser]::ParseFile($file.FullName,[ref]$tokens,[ref]$errors)|Out-Null
        if($errors.Count){throw ("Syntax error in {0}: {1}" -f $file.FullName,($errors -join '; '))}
    }
    if($CheckOnly){Write-Host 'Startup file and syntax checks passed.';exit 0}
    $principal=New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if(-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){
        if($Elevated){throw 'Elevation returned without administrator rights. Right-click 00_START_HERE.bat and choose Run as administrator.'}
        Write-Host 'Requesting administrator access. Approve the Windows prompt; this window will wait.'
        # Encode the command, escaping apostrophes before embedding the path. No BAT path is executed as code.
        $safePath=$PSCommandPath.Replace("'","''")
        $command="& '$safePath' -Elevated -Action '$Action'; exit `$LASTEXITCODE"
        $encoded=[Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($command))
        $child=Start-Process -FilePath (Join-Path $PSHOME 'powershell.exe') -ArgumentList @('-NoLogo','-NoProfile','-ExecutionPolicy','Bypass','-EncodedCommand',$encoded) -Verb RunAs -WorkingDirectory $root -Wait -PassThru -ErrorAction Stop
        if($child.ExitCode -ne 0){throw "Elevated toolkit exited with code $($child.ExitCode). Review its startup log in TEMP."}
    } else {
        $probe=Join-Path $root ([IO.Path]::GetRandomFileName())
        try {[IO.File]::WriteAllText($probe,'write check')} catch {throw "Package folder is not writable: $root. Extract to a writable local folder. $_"} finally {if(Test-Path -LiteralPath $probe){Remove-Item -LiteralPath $probe -Force}}
        $menuActions=@('ABC','A','B','C','DryRun','Apply','EF','G','Export','Open','SelfTest')
        do {
            $selected=$Action
            if($Action -eq 'Menu'){
                Write-Host "`nWINDOWS PERFORMANCE + HARDWARE HEALTH TOOLKIT v2.0 launcher fix" -ForegroundColor Cyan
                Write-Host @'
 1. Pre-repair phases A + B + C
 2. Baseline only
 3. Full diagnostics
 4. Analyze evidence
 5. Repair DRY RUN
 6. APPLY repair plan (confirmation required)
 7. Post-repair retest + comparison
 8. Hardware history
 9. Export latest run
10. Open latest run
11. Self-test
 0. Exit
'@
                $answer=Read-Host 'Choose'
                if($answer -eq '0'){break}
                if($answer -notmatch '^(?:[1-9]|10|11)$'){Write-Host 'Enter a number from 0 to 11.';continue}
                $selected=$menuActions[[int]$answer-1]
            }
            Write-Host "Starting action: $selected"
            & (Join-Path $PSHOME 'powershell.exe') -NoLogo -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'Dispatch.ps1') -Action $selected
            $actionExit=$LASTEXITCODE
            if($actionExit -ne 0){Write-Host "Action failed (exit $actionExit). Read the error above." -ForegroundColor Red} else {Write-Host 'Action finished. Review its report for findings and warnings.'}
            [void](Read-Host 'Press Enter to continue')
            if($Action -ne 'Menu'){$rc=$actionExit;break}
        } while($true)
    }
} catch {
    $rc=1
    Write-Host "STARTUP ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace
    Write-Host 'If the Windows permission prompt was cancelled, run again and approve it.'
    if($Elevated){[void](Read-Host 'Press Enter to close')}
} finally {if($logging){Stop-Transcript | Out-Null}}
exit $rc
