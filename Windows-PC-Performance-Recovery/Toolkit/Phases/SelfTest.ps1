param()
$scriptDir=Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path (Split-Path -Parent $scriptDir) 'Core\Common.ps1')
$packageRoot=Split-Path -Parent (Split-Path -Parent $scriptDir)
$out=Join-Path $packageRoot 'SELF_TEST_REPORT.txt'
$rows=New-Object System.Collections.Generic.List[object]
function Add-Test([string]$Name,[string]$Status,[string]$Detail){$rows.Add([pscustomobject]@{Test=$Name;Status=$Status;Detail=$Detail})}
Add-Test 'PowerShell version' ($(if($PSVersionTable.PSVersion.Major -ge 5){'PASS'}else{'FAIL'})) ([string]$PSVersionTable.PSVersion)
Add-Test 'Administrator' ($(if(Test-ToolkitAdmin){'PASS'}else{'WARN'})) 'Administrator is recommended/required for complete collection and repairs.'
$required=@('Get-CimInstance','Get-WinEvent','Get-Counter','Get-Process','Get-Service','Compress-Archive')
foreach($c in $required){$x=Get-Command $c -ErrorAction SilentlyContinue;Add-Test "Command: $c" ($(if($x){'PASS'}else{'FAIL'})) ($(if($x){$x.Source}else{'Not found'}))}
$optional=@('Get-PhysicalDisk','Get-StorageReliabilityCounter','Get-PnpDevice','Get-MpComputerStatus','Get-WindowsOptionalFeature')
foreach($c in $optional){$x=Get-Command $c -ErrorAction SilentlyContinue;Add-Test "Optional command: $c" ($(if($x){'PASS'}else{'WARN'})) ($(if($x){$x.Source}else{'Not available; related telemetry may be missing'}))}
foreach($exe in @('DISM.exe','sfc.exe','chkdsk.exe','defrag.exe','powercfg.exe','fsutil.exe')){$x=Get-Command $exe -ErrorAction SilentlyContinue;Add-Test "Executable: $exe" ($(if($x){'PASS'}else{'FAIL'})) ($(if($x){$x.Source}else{'Not found'}))}
try{$t=Join-Path $packageRoot 'Runs\.__write_test.tmp';'test'|Set-Content $t -ErrorAction Stop;Remove-Item $t -Force;Add-Test 'Package writable' 'PASS' $packageRoot}catch{Add-Test 'Package writable' 'FAIL' $_.Exception.Message}
$parseErrors=0
Get-ChildItem (Join-Path $packageRoot 'Toolkit') -Recurse -Filter '*.ps1'|ForEach-Object{
    $tokens=$null;$errs=$null;[System.Management.Automation.Language.Parser]::ParseFile($_.FullName,[ref]$tokens,[ref]$errs)|Out-Null
    if($errs.Count -gt 0){$parseErrors+=$errs.Count;Add-Test ("Syntax: "+$_.Name) 'FAIL' (($errs|ForEach-Object{$_.Message}) -join ' | ')}else{Add-Test ("Syntax: "+$_.Name) 'PASS' 'Parser found no syntax errors'}
}
$rows|Format-Table -AutoSize|Out-String -Width 240|Set-Content $out -Encoding UTF8
$fail=@($rows|Where-Object Status -eq 'FAIL').Count
Add-Content $out "`nFailures: $fail; Parser errors: $parseErrors" -Encoding UTF8
Write-Host "Self-test report: $out" -ForegroundColor Cyan
if($fail -gt 0){Write-Host 'One or more required checks FAILED. Review the report before relying on the toolkit.' -ForegroundColor Red;exit 2}else{Write-Host 'Self-test completed without required-command failures.' -ForegroundColor Green;exit 0}
