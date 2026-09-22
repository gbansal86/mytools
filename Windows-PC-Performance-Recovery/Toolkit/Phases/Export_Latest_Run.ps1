param([string]$RunRoot)
$scriptDir=Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path (Split-Path -Parent $scriptDir) 'Core\Common.ps1')
$packageRoot=Split-Path -Parent (Split-Path -Parent $scriptDir)
if(-not $RunRoot){$RunRoot=Get-LatestToolkitRun $packageRoot}
if(-not $RunRoot){throw 'No run found.'}
$dest=Join-Path $packageRoot ((Split-Path $RunRoot -Leaf)+'_FOR_REVIEW.zip')
if(Test-Path $dest){Remove-Item $dest -Force}
Compress-Archive -Path (Join-Path $RunRoot '*') -DestinationPath $dest -CompressionLevel Optimal
Write-Host "Created: $dest" -ForegroundColor Green
