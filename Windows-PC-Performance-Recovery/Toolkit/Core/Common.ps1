Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Continue'

function Test-ToolkitAdmin {
    try {
        $id=[Security.Principal.WindowsIdentity]::GetCurrent()
        $p=New-Object Security.Principal.WindowsPrincipal($id)
        return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch { return $false }
}

function New-ToolkitRun {
    param([Parameter(Mandatory=$true)][string]$PackageRoot)
    $stamp=Get-Date -Format 'yyyyMMdd_HHmmss'
    $run=Join-Path $PackageRoot ("Runs\RUN_{0}" -f $stamp)
    New-Item -ItemType Directory -Force -Path $run | Out-Null
    $marker=Join-Path $PackageRoot 'Toolkit\.latest_run.txt'
    $run | Set-Content -Path $marker -Encoding UTF8
    return $run
}

function Get-LatestToolkitRun {
    param([Parameter(Mandatory=$true)][string]$PackageRoot)
    $marker=Join-Path $PackageRoot 'Toolkit\.latest_run.txt'
    if(Test-Path $marker){
        $p=(Get-Content $marker -Raw -ErrorAction SilentlyContinue).Trim()
        if($p -and (Test-Path $p)){ return $p }
    }
    $runs=Get-ChildItem (Join-Path $PackageRoot 'Runs') -Directory -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending
    if($runs){ return $runs[0].FullName }
    return $null
}

function Write-ToolkitLog {
    param([string]$Path,[string]$Message,[string]$Level='INFO')
    $line="{0} [{1}] {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'),$Level,$Message
    $dir=Split-Path -Parent $Path
    if($dir -and -not(Test-Path $dir)){New-Item -ItemType Directory -Force -Path $dir|Out-Null}
    Add-Content -Path $Path -Value $line -Encoding UTF8
    Write-Host $line
}

function Get-DirectorySizeBytes {
    param([string]$Path)
    if(-not(Test-Path $Path)){return [int64]0}
    try {
        $m=Get-ChildItem -LiteralPath $Path -File -Force -Recurse -ErrorAction SilentlyContinue | Measure-Object Length -Sum
        if($m.Sum){return [int64]$m.Sum}
    } catch {}
    return [int64]0
}

function Format-Bytes {
    param([double]$Bytes)
    if($Bytes -ge 1TB){return ('{0:N2} TB' -f ($Bytes/1TB))}
    if($Bytes -ge 1GB){return ('{0:N2} GB' -f ($Bytes/1GB))}
    if($Bytes -ge 1MB){return ('{0:N2} MB' -f ($Bytes/1MB))}
    if($Bytes -ge 1KB){return ('{0:N2} KB' -f ($Bytes/1KB))}
    return ('{0:N0} bytes' -f $Bytes)
}

function Save-ToolkitCsv {
    param([string]$Path,[scriptblock]$Action)
    try {
        $data=& $Action
        if($null -eq $data){'NO DATA / NOT AVAILABLE'|Set-Content ($Path -replace '\.csv$','.txt') -Encoding UTF8}
        else {$data|Export-Csv -Path $Path -NoTypeInformation -Encoding UTF8}
    } catch {"FAILED: $($_.Exception.Message)"|Set-Content ($Path -replace '\.csv$','.txt') -Encoding UTF8}
}

function Save-ToolkitText {
    param([string]$Path,[scriptblock]$Action)
    try { & $Action 2>&1 | Out-File -FilePath $Path -Encoding UTF8 -Width 4096 }
    catch { "FAILED: $($_.Exception.Message)" | Out-File -FilePath $Path -Encoding UTF8 }
}

function Get-ShortHash {
    param([object]$Value)
    if($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value)){return $null}
    try {
        $sha=[System.Security.Cryptography.SHA256]::Create()
        $bytes=[Text.Encoding]::UTF8.GetBytes([string]$Value)
        $hash=$sha.ComputeHash($bytes)
        return (($hash|ForEach-Object{$_.ToString('x2')}) -join '').Substring(0,12)
    } catch {return 'HASH-UNAVAILABLE'}
}
