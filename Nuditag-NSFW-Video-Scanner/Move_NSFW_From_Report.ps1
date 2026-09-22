param(
    [Parameter(Mandatory = $true)]
    [string]$Report,

    [Parameter(Mandatory = $true)]
    [string]$LogDir,

    [switch]$DryRun
)

<#
.SYNOPSIS
    Moves paths listed in ALL_NSFW_VIDEOS.csv into an NSFW subfolder.

.DESCRIPTION
    Conservative behavior:
      * Dry-run mode changes nothing.
      * Existing files are never overwritten.
      * A collision gets _1, _2, ... appended to the destination filename.
      * Missing sources are logged and skipped.
      * Files already directly inside a folder named NSFW are skipped.
      * Every attempted action is written to a CSV log.

    This script does not decide whether a file is NSFW. It trusts the reviewed
    Nuditag report supplied by the caller.
#>

$ErrorActionPreference = "Stop"

function Get-UniqueDestination {
    param(
        [Parameter(Mandatory = $true)]
        [string]$DestinationFolder,

        [Parameter(Mandatory = $true)]
        [string]$FileName
    )

    $candidate = Join-Path $DestinationFolder $FileName

    if (-not (Test-Path -LiteralPath $candidate)) {
        return $candidate
    }

    $base = [System.IO.Path]::GetFileNameWithoutExtension($FileName)
    $ext = [System.IO.Path]::GetExtension($FileName)
    $i = 1

    while ($true) {
        $candidate = Join-Path $DestinationFolder ("{0}_{1}{2}" -f $base, $i, $ext)

        if (-not (Test-Path -LiteralPath $candidate)) {
            return $candidate
        }

        $i++
    }
}

if (-not (Test-Path -LiteralPath $Report)) {
    Write-Host "ERROR: Report not found: $Report" -ForegroundColor Red
    exit 1
}

New-Item -ItemType Directory -Force -Path $LogDir | Out-Null

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$mode = if ($DryRun) { "DRY_RUN" } else { "MOVE" }
$logPath = Join-Path $LogDir ("NSFW_Move_Log_{0}_{1}.csv" -f $mode, $timestamp)

$rows = Import-Csv -LiteralPath $Report
$results = New-Object System.Collections.Generic.List[object]

$total = 0
$moved = 0
$wouldMove = 0
$skipped = 0
$missing = 0
$errors = 0

foreach ($row in $rows) {
    $total++

    $source = [string]$row.path
    $score = [string]$row.score
    $tag = [string]$row.tag

    if ([string]::IsNullOrWhiteSpace($source)) {
        $skipped++

        $results.Add([pscustomobject]@{
            Source      = $source
            Destination = ""
            Score       = $score
            Tag         = $tag
            Status      = "SKIPPED"
            Message     = "Blank path in report"
        })

        continue
    }

    try {
        if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
            Write-Host "[MISSING] $source" -ForegroundColor Yellow
            $missing++

            $results.Add([pscustomobject]@{
                Source      = $source
                Destination = ""
                Score       = $score
                Tag         = $tag
                Status      = "MISSING"
                Message     = "Source file does not exist"
            })

            continue
        }

        $sourceItem = Get-Item -LiteralPath $source
        $parent = $sourceItem.Directory

        if ($parent.Name -ieq "NSFW") {
            Write-Host "[SKIP] Already in NSFW folder: $source"
            $skipped++

            $results.Add([pscustomobject]@{
                Source      = $source
                Destination = $source
                Score       = $score
                Tag         = $tag
                Status      = "SKIPPED"
                Message     = "Already inside an NSFW folder"
            })

            continue
        }

        $destFolder = Join-Path $parent.FullName "NSFW"
        $destination = Get-UniqueDestination `
            -DestinationFolder $destFolder `
            -FileName $sourceItem.Name

        if ($DryRun) {
            Write-Host ("[DRY RUN] {0} -> {1}" -f $source, $destination)
            $wouldMove++

            $results.Add([pscustomobject]@{
                Source      = $source
                Destination = $destination
                Score       = $score
                Tag         = $tag
                Status      = "WOULD_MOVE"
                Message     = ""
            })

            continue
        }

        New-Item -ItemType Directory -Force -Path $destFolder | Out-Null
        Move-Item -LiteralPath $source -Destination $destination

        Write-Host ("[MOVED] {0} -> {1}" -f $source, $destination) -ForegroundColor Green
        $moved++

        $results.Add([pscustomobject]@{
            Source      = $source
            Destination = $destination
            Score       = $score
            Tag         = $tag
            Status      = "MOVED"
            Message     = ""
        })
    }
    catch {
        Write-Host ("[ERROR] {0} :: {1}" -f $source, $_.Exception.Message) -ForegroundColor Red
        $errors++

        $results.Add([pscustomobject]@{
            Source      = $source
            Destination = ""
            Score       = $score
            Tag         = $tag
            Status      = "ERROR"
            Message     = $_.Exception.Message
        })
    }
}

$results | Export-Csv -LiteralPath $logPath -NoTypeInformation -Encoding UTF8

Write-Host ""
Write-Host "============================================================"
Write-Host "SUMMARY"
Write-Host "============================================================"
Write-Host ("Mode:        {0}" -f $mode)
Write-Host ("Rows:        {0}" -f $total)

if ($DryRun) {
    Write-Host ("Would move:  {0}" -f $wouldMove)
}
else {
    Write-Host ("Moved:       {0}" -f $moved)
}

Write-Host ("Skipped:     {0}" -f $skipped)
Write-Host ("Missing:     {0}" -f $missing)
Write-Host ("Errors:      {0}" -f $errors)
Write-Host ("Log:         {0}" -f $logPath)

if ($errors -gt 0) {
    exit 2
}

exit 0
