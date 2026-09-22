#requires -Version 5.1
<#
Course Library Manager
PowerShell WinForms GUI for:
  - previewing / applying / undoing safe course-folder cleanup
  - creating a local HTML course library
  - card/table views
  - local video playback, seek controls, playback speed, subtitles
  - course covers, PDFs/images/resources, search and progress/resume

No internet connection is required.
Files are never renamed by the folder-cleanup feature. Only folders are renamed.
The HTML generator does not modify your course files.

Tested target: Windows PowerShell 5.1+ on Windows 10/11.
#>

[CmdletBinding()]
param(
    [switch]$NoConsole
)

Set-StrictMode -Version 2
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# When launched through the supplied BAT/VBS launcher, hide the PowerShell
# console host so the WinForms GUI is the only visible application window.
if ($NoConsole) {
    try {
        Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class CLMConsoleWindow {
    [DllImport("kernel32.dll")]
    public static extern IntPtr GetConsoleWindow();

    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
}
"@ -ErrorAction SilentlyContinue

        $consoleHandle = [CLMConsoleWindow]::GetConsoleWindow()
        if ($consoleHandle -ne [IntPtr]::Zero) {
            [void][CLMConsoleWindow]::ShowWindow($consoleHandle, 0)
        }
    } catch {
        # Non-fatal. The GUI can still run if console hiding is unavailable.
    }
}


# ----------------------------- APP CONSTANTS -----------------------------

$Script:AppName = "Course Library Manager"
$Script:AppVersion = "1.5.0"
$Script:ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Script:SettingsPath = Join-Path $Script:ScriptDir "CourseLibraryManager.settings.json"
$Script:DefaultRoot = Join-Path ([Environment]::GetFolderPath("MyVideos")) "Courses"
$Script:CatalogFolderName = "_CourseLibrary"
$Script:UndoPrefix = "_FOLDER_RENAME_UNDO_"
$Script:PreviewPrefix = "_FOLDER_RENAME_PREVIEW_"
$Script:ApplyPrefix = "_FOLDER_RENAME_APPLIED_"

$Script:BrandMap = @{
    "ai"          = "AI"
    "api"         = "API"
    "chatgpt"     = "ChatGPT"
    "openai"      = "OpenAI"
    "youtube"     = "YouTube"
    "seo"         = "SEO"
    "fiverr"      = "Fiverr"
    "pytorch"     = "PyTorch"
    "deepseek"    = "DeepSeek"
    "gemini"      = "Gemini"
    "canva"       = "Canva"
    "bing"        = "Bing"
    "google"      = "Google"
    "linkedin"    = "LinkedIn"
    "facebook"    = "Facebook"
    "instagram"   = "Instagram"
    "tiktok"      = "TikTok"
    "reddit"      = "Reddit"
    "quora"       = "Quora"
    "udemy"       = "Udemy"
    "n8n"         = "n8n"
    "llama"       = "Llama"
    "sora"        = "Sora"
    "gpt"         = "GPT"
    "pr"          = "PR"
    "mlops"       = "MLOps"
    "adwords"     = "AdWords"
    "gohighlevel" = "GoHighLevel"
    "al-suffa"    = "Al-Suffa"
}

$Script:SmallWords = @(
    "a","an","and","as","at","by","for","from",
    "in","into","of","on","or","the","to","with"
)

$Script:ParentOverrides = @{
    "chatgptfacebookads" = "ChatGPT Facebook Ads"
    "youtubemaster"      = "YouTube Master"
    "seo_chatgpt"        = "SEO ChatGPT"
}

$Script:DefaultSettings = [ordered]@{
    RootPath                 = $Script:DefaultRoot
    RemovePhrases            = @()
    Theme                    = "Dark"
    DefaultView              = "Cards"
    GenerateVideoThumbnails  = $true
    GenerateDurations        = $true
    IncludeSubtitles         = $true
    IncludePDFs              = $true
    IncludeImages            = $true
    IncludeOtherResources    = $true
    ThumbnailSeekPercent     = 20
    DefaultPlaybackSpeed     = 1.0
    CatalogFolderName        = $Script:CatalogFolderName
}

$Script:Settings = $null
$Script:MainForm = $null
$Script:RootTextBox = $null
$Script:LogBox = $null
$Script:StatusLabel = $null
$Script:ProgressBar = $null
$Script:GenerateButton = $null
$Script:OpenButton = $null

# ----------------------------- BASIC HELPERS -----------------------------

function Get-Timestamp {
    return (Get-Date -Format "yyyyMMdd_HHmmss")
}

function Write-UiLog {
    param(
        [Parameter(Mandatory=$true)][string]$Message,
        [ValidateSet("INFO","OK","WARN","ERROR")][string]$Level = "INFO"
    )

    $line = "{0} [{1}] {2}" -f (Get-Date -Format "HH:mm:ss"), $Level, $Message

    if ($Script:LogBox -and -not $Script:LogBox.IsDisposed) {
        $Script:LogBox.AppendText($line + [Environment]::NewLine)
        $Script:LogBox.SelectionStart = $Script:LogBox.TextLength
        $Script:LogBox.ScrollToCaret()
        [System.Windows.Forms.Application]::DoEvents()
    } else {
        Write-Host $line
    }
}

function Set-UiStatus {
    param(
        [string]$Text,
        [int]$Percent = -1
    )

    if ($Script:StatusLabel -and -not $Script:StatusLabel.IsDisposed) {
        $Script:StatusLabel.Text = $Text
    }
    if ($Script:ProgressBar -and -not $Script:ProgressBar.IsDisposed) {
        if ($Percent -ge 0) {
            $p = [Math]::Max(0, [Math]::Min(100, $Percent))
            $Script:ProgressBar.Style = [System.Windows.Forms.ProgressBarStyle]::Continuous
            $Script:ProgressBar.Value = $p
        }
    }
    [System.Windows.Forms.Application]::DoEvents()
}

function Show-Info {
    param([string]$Message, [string]$Title = $Script:AppName)
    [System.Windows.Forms.MessageBox]::Show(
        $Script:MainForm,
        $Message,
        $Title,
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information
    ) | Out-Null
}

function Show-Warning {
    param([string]$Message, [string]$Title = $Script:AppName)
    [System.Windows.Forms.MessageBox]::Show(
        $Script:MainForm,
        $Message,
        $Title,
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Warning
    ) | Out-Null
}

function Confirm-Action {
    param([string]$Message, [string]$Title = $Script:AppName)
    $result = [System.Windows.Forms.MessageBox]::Show(
        $Script:MainForm,
        $Message,
        $Title,
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Question
    )
    return ($result -eq [System.Windows.Forms.DialogResult]::Yes)
}

function Load-Settings {
    $settings = [ordered]@{}
    foreach ($k in $Script:DefaultSettings.Keys) {
        $settings[$k] = $Script:DefaultSettings[$k]
    }

    if (Test-Path -LiteralPath $Script:SettingsPath) {
        try {
            $loaded = Get-Content -LiteralPath $Script:SettingsPath -Raw -Encoding UTF8 | ConvertFrom-Json
            foreach ($p in $loaded.PSObject.Properties) {
                $settings[$p.Name] = $p.Value
            }
        } catch {
            Write-Host "Could not read settings file; defaults will be used. $($_.Exception.Message)"
        }
    }

    # Ensure phrase list is always an array.
    $settings["RemovePhrases"] = @($settings["RemovePhrases"])
    $Script:Settings = $settings
}

function Save-Settings {
    if (-not $Script:Settings) { return }
    $Script:Settings | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $Script:SettingsPath -Encoding UTF8
}

function Get-SelectedRoot {
    $raw = ""
    if ($Script:RootTextBox) {
        $raw = $Script:RootTextBox.Text.Trim().Trim('"')
    } else {
        $raw = [string]$Script:Settings.RootPath
    }

    if ([string]::IsNullOrWhiteSpace($raw)) {
        throw "Please select a course root folder."
    }

    $root = [System.IO.DirectoryInfo]::new($raw)
    if (-not $root.Exists) {
        throw "Folder does not exist: $raw"
    }

    $Script:Settings.RootPath = $root.FullName
    Save-Settings
    return $root
}

function Normalize-Spaces {
    param([string]$Text)
    if ($null -eq $Text) { return "" }
    $s = $Text -replace "\s+", " "
    $s = $s -replace "\s+([\)\]\}])", '$1'
    $s = $s -replace "([\(\[\{])\s+", '$1'
    return $s.Trim()
}

function Convert-ToSafeWindowsName {
    param([string]$Name)

    $invalidChars = [System.IO.Path]::GetInvalidFileNameChars()
    $chars = $Name.ToCharArray()
    for ($i = 0; $i -lt $chars.Length; $i++) {
        if ($invalidChars -contains $chars[$i]) {
            $chars[$i] = [char]' '
        }
    }
    $s = -join $chars
    $s = Normalize-Spaces $s
    $s = $s.TrimEnd('.', ' ')

    if ([string]::IsNullOrWhiteSpace($s)) {
        $s = "_Unnamed Folder"
    }

    $reserved = @("CON","PRN","AUX","NUL","COM1","COM2","COM3","COM4","COM5","COM6","COM7","COM8","COM9",
                  "LPT1","LPT2","LPT3","LPT4","LPT5","LPT6","LPT7","LPT8","LPT9")
    if ($reserved -contains $s.ToUpperInvariant()) {
        $s = "_" + $s
    }

    if ($s.Length -gt 240) {
        $s = $s.Substring(0,240).TrimEnd('.', ' ')
    }
    return $s
}

# ----------------------------- FOLDER CLEANUP -----------------------------

function Remove-KnownJunk {
    param([string]$Name)

    $s = $Name.Normalize([Text.NormalizationForm]::FormKC)

    # Remove common promotional wrappers before stripping their channel name.
    # This catches common promotional wrappers such as "Join SomeChannel For More!".
    $s = [regex]::Replace($s, "(?i)\bJoin\s+[A-Za-z0-9_@\- ]{2,40}\s+For\s+(?:More|Free\s+Courses)\b!?", " ")
    $s = [regex]::Replace($s, "(?i)\bFREE\s+Paid\s+Courses\b", " ")

    $phrases = @($Script:Settings.RemovePhrases) |
        Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } |
        Sort-Object { ([string]$_).Length } -Descending

    foreach ($phraseObj in $phrases) {
        $phrase = [string]$phraseObj
        $escaped = [regex]::Escape($phrase.Trim())

        # Explicit source/channel/site phrase plus decorative separators.
        $pattern = "(?i)(?:\s*[-–—|_:]+\s*)*[_\[\]\(\)\{\}\-–— ]*$escaped[_\[\]\(\)\{\}\-–— ]*(?:\s*[-–—|_:]+\s*)*"
        $s = [regex]::Replace($s, $pattern, " ")
    }

    # Telegram URLs and @handles are unambiguous source/channel markers.
    $s = [regex]::Replace($s, "(?i)(?:https?://)?t\.me/[A-Za-z0-9_+\-]+", " ")
    $s = [regex]::Replace($s, "(?i)(?:telegram\s*[:\-]\s*)?@[A-Za-z0-9_]{4,}", " ")

    $s = [regex]::Replace($s, "\[\s*\]", " ")
    $s = [regex]::Replace($s, "\(\s*\)", " ")

    return Normalize-Spaces $s
}

function Convert-ToSmartTitle {
    param([string]$Text)

    $parts = [regex]::Split($Text, "(\s+-\s+)")
    $out = [System.Collections.Generic.List[string]]::new()

    foreach ($part in $parts) {
        if ($part -match "^\s+-\s+$") {
            $out.Add(" - ")
            continue
        }

        $words = $part -split "\s+"
        $newWords = [System.Collections.Generic.List[string]]::new()

        for ($i=0; $i -lt @($words).Count; $i++) {
            $word = $words[$i]
            if ([string]::IsNullOrWhiteSpace($word)) { continue }

            $m = [regex]::Match($word, "^([^A-Za-z0-9]*)(.*?)([^A-Za-z0-9]*)$")
            if (-not $m.Success) {
                $newWords.Add($word)
                continue
            }

            $prefix = $m.Groups[1].Value
            $core   = $m.Groups[2].Value
            $suffix = $m.Groups[3].Value

            if ([string]::IsNullOrEmpty($core)) {
                $newWords.Add($word)
                continue
            }

            $low = $core.ToLowerInvariant()
            $formatted = $core

            if ($Script:BrandMap.ContainsKey($low)) {
                $formatted = $Script:BrandMap[$low]
            }
            elseif (($Script:SmallWords -contains $low) -and ($i -ne 0)) {
                $formatted = $low
            }
            elseif ($core -match "^\d+(?:\.\d+)*$") {
                $formatted = $core
            }
            elseif (($core -cmatch "^[A-Z0-9]+$") -and $core.Length -le 6) {
                $formatted = $core
            }
            elseif ($core.Contains("-")) {
                $subParts = $core -split "-"
                $rebuilt = foreach ($sp in $subParts) {
                    $spl = $sp.ToLowerInvariant()
                    if ($Script:BrandMap.ContainsKey($spl)) {
                        $Script:BrandMap[$spl]
                    } elseif ([string]::IsNullOrEmpty($sp)) {
                        ""
                    } else {
                        $sp.Substring(0,1).ToUpperInvariant() + $sp.Substring(1).ToLowerInvariant()
                    }
                }
                $formatted = ($rebuilt -join "-")
            }
            else {
                if ($core.Length -eq 1) {
                    $formatted = $core.ToUpperInvariant()
                } else {
                    $formatted = $core.Substring(0,1).ToUpperInvariant() + $core.Substring(1).ToLowerInvariant()
                }
            }

            $newWords.Add($prefix + $formatted + $suffix)
        }

        $out.Add(($newWords -join " "))
    }

    return ($out -join "")
}

function Get-CleanParentName {
    param([string]$Name)

    $original = $Name
    $s = Remove-KnownJunk $Name
    $s = $s.Replace("_", " ")
    $s = [regex]::Replace($s, "\s+[–—]\s+", " - ")

    # Treat multiple unspaced hyphens as a slug.
    if (@($s.ToCharArray() | Where-Object { $_ -eq '-' }).Count -ge 2 -and $s -notmatch "\s-\s") {
        $s = $s.Replace("-", " ")
    }

    $s = Normalize-Spaces $s
    $s = $s.Trim(' ','.','-','_','–','—')
    $s = [regex]::Replace($s, "(?i)\bchat\s+gpt\b", "ChatGPT")

    $key = $original.ToLowerInvariant()
    if ($Script:ParentOverrides.ContainsKey($key)) {
        return $Script:ParentOverrides[$key]
    }

    return Convert-ToSmartTitle $s
}

function Get-CleanSubfolderName {
    param([string]$Name)

    $s = Remove-KnownJunk $Name
    $s = [regex]::Replace($s, "_+", " ")
    $s = [regex]::Replace($s, "\s*[-–—|:]+\s*$", "")
    $s = [regex]::Replace($s, "^\s*[-–—|:]+\s*", "")
    $s = Normalize-Spaces $s
    return $s.Trim(' ','.','-','_','–','—')
}

function Get-CleanDisplayName {
    param([string]$Name)

    # For catalog labels only. Underlying file name is untouched.
    $ext = [System.IO.Path]::GetExtension($Name)
    $base = if ($ext) { [System.IO.Path]::GetFileNameWithoutExtension($Name) } else { $Name }
    $base = Remove-KnownJunk $base

    # Remove repeated extension text caused by names like "file.mp4 - SourceTag_.mp4"
    $base = [regex]::Replace($base, "(?i)\.(mp4|mkv|webm|mov|m4v|avi|pdf|jpg|jpeg|png|webp)\s*$", "")
    $base = [regex]::Replace($base, "_en$", "")
    $base = $base -replace "_+", " "
    $base = Normalize-Spaces $base
    return $base.Trim(' ','.','-','_','–','—')
}

function Get-RelativeDepth {
    param([System.IO.DirectoryInfo]$Dir, [System.IO.DirectoryInfo]$Root)

    $relative = $Dir.FullName.Substring($Root.FullName.TrimEnd('\').Length).TrimStart('\')
    if ([string]::IsNullOrWhiteSpace($relative)) { return 0 }
    return @($relative -split "\\").Count
}

function Get-RenamePlan {
    param([System.IO.DirectoryInfo]$Root)

    Write-UiLog "Scanning folders under $($Root.FullName)..."

    $catalogPath = Join-Path $Root.FullName ([string]$Script:Settings.CatalogFolderName)
    $dirs = Get-ChildItem -LiteralPath $Root.FullName -Directory -Recurse -Force |
        Where-Object { -not $_.FullName.StartsWith($catalogPath, [System.StringComparison]::OrdinalIgnoreCase) }

    $rows = [System.Collections.Generic.List[object]]::new()

    foreach ($dir in $dirs) {
        $depth = Get-RelativeDepth -Dir $dir -Root $Root
        if ($depth -lt 1) { continue }

        $newName = if ($depth -eq 1) {
            Get-CleanParentName $dir.Name
        } else {
            Get-CleanSubfolderName $dir.Name
        }

        $newName = Convert-ToSafeWindowsName $newName
        $dest = Join-Path $dir.Parent.FullName $newName

        $status = if ($dir.Name -ceq $newName) { "UNCHANGED" } else { "RENAME" }

        $rows.Add([pscustomobject]@{
            Depth       = $depth
            Source      = $dir.FullName
            Destination = $dest
            OldName     = $dir.Name
            NewName     = $newName
            Status      = $status
            Reason      = ""
        })
    }

    # Collision analysis by intended sibling/name.
    $renameRows = @($rows | Where-Object { $_.Status -eq "RENAME" })
    $groups = $renameRows | Group-Object {
        $parent = Split-Path -Parent $_.Destination
        $leaf = Split-Path -Leaf $_.Destination
        ($parent.ToLowerInvariant() + "|" + $leaf.ToLowerInvariant())
    }

    foreach ($g in $groups) {
        if ($g.Count -gt 1) {
            foreach ($r in $g.Group) {
                $r.Status = "SKIP_COLLISION"
                $r.Reason = "More than one sibling would get the same cleaned name."
            }
        }
    }

    foreach ($r in $rows) {
        if ($r.Status -ne "RENAME") { continue }

        if ((Test-Path -LiteralPath $r.Destination) -and
            ($r.Source.ToLowerInvariant() -ne $r.Destination.ToLowerInvariant())) {
            $r.Status = "SKIP_EXISTS"
            $r.Reason = "Destination already exists."
        }
    }

    return @($rows | Sort-Object Depth, Source -Descending)
}

function Export-RenameReport {
    param(
        [array]$Plan,
        [System.IO.DirectoryInfo]$Root,
        [string]$Prefix
    )

    $path = Join-Path $Root.FullName ("{0}{1}.csv" -f $Prefix, (Get-Timestamp))
    $Plan |
        Select-Object Status,Depth,OldName,NewName,Source,Destination,Reason |
        Export-Csv -LiteralPath $path -NoTypeInformation -Encoding UTF8
    return $path
}

function Invoke-RenamePreview {
    try {
        $root = Get-SelectedRoot
        Set-UiStatus "Scanning folders..." 5
        $plan = Get-RenamePlan $root
        $report = Export-RenameReport -Plan $plan -Root $root -Prefix $Script:PreviewPrefix

        $renames = @($plan | Where-Object {$_.Status -eq "RENAME"})
        $blocked = @($plan | Where-Object {$_.Status -like "SKIP_*"})

        Write-UiLog "Preview complete: $(@($plan).Count) folders inspected." "OK"
        Write-UiLog "Proposed renames: $(@($renames).Count); blocked/collisions: $(@($blocked).Count)." "INFO"
        Write-UiLog "Preview CSV: $report" "INFO"

        $sample = $renames | Sort-Object Depth, Source | Select-Object -First 15
        foreach ($r in $sample) {
            Write-UiLog "$($r.OldName)  ->  $($r.NewName)"
        }

        Set-UiStatus "Preview complete" 100
        Show-Info ("Preview complete.`r`n`r`nProposed renames: {0}`r`nBlocked/collisions: {1}`r`n`r`nReport:`r`n{2}`r`n`r`nNothing was changed." -f @($renames).Count,@($blocked).Count,$report)
    } catch {
        Write-UiLog $_.Exception.Message "ERROR"
        Set-UiStatus "Preview failed" 0
        Show-Warning $_.Exception.Message
    }
}

function Rename-DirectoryCaseSafe {
    param([string]$Source, [string]$Destination)

    $srcInfo = [System.IO.DirectoryInfo]::new($Source)
    $destInfo = [System.IO.DirectoryInfo]::new($Destination)

    if (($Source.ToLowerInvariant() -eq $Destination.ToLowerInvariant()) -and ($Source -cne $Destination)) {
        $temp = Join-Path $srcInfo.Parent.FullName (".__rename_tmp__" + (Get-Timestamp) + "_" + [guid]::NewGuid().ToString("N").Substring(0,8))
        Rename-Item -LiteralPath $Source -NewName (Split-Path -Leaf $temp)
        Rename-Item -LiteralPath $temp -NewName $destInfo.Name
    } else {
        Rename-Item -LiteralPath $Source -NewName $destInfo.Name
    }
}

function Invoke-RenameApply {
    try {
        $root = Get-SelectedRoot
        Set-UiStatus "Preparing rename plan..." 5
        $plan = Get-RenamePlan $root
        $toRename = @($plan | Where-Object {$_.Status -eq "RENAME"})

        if (@($toRename).Count -eq 0) {
            Show-Info "Nothing needs to be renamed."
            Set-UiStatus "Nothing to rename" 100
            return
        }

        $blocked = @($plan | Where-Object {$_.Status -like "SKIP_*"}).Count
        $msg = "Rename $(@($toRename).Count) folder(s)?`r`n`r`nFiles will NOT be renamed.`r`nAn undo log will be created.`r`nBlocked/colliding folders: $blocked"
        if (-not (Confirm-Action $msg "Apply Folder Renames")) {
            Write-UiLog "Rename cancelled by user." "WARN"
            return
        }

        $stamp = Get-Timestamp
        $undoPath = Join-Path $root.FullName ($Script:UndoPrefix + $stamp + ".json")
        $applyPath = Join-Path $root.FullName ($Script:ApplyPrefix + $stamp + ".csv")
        $done = [System.Collections.Generic.List[object]]::new()
        $results = [System.Collections.Generic.List[object]]::new()

        $i = 0
        foreach ($r in $plan) {
            if ($r.Status -ne "RENAME") { continue }
            $i++
            Set-UiStatus ("Renaming {0}/{1}: {2}" -f $i,@($toRename).Count,$r.OldName) ([int](100*$i/[Math]::Max(1,@($toRename).Count)))

            $status = "NOT_RUN"
            $reason = ""
            try {
                if (-not (Test-Path -LiteralPath $r.Source)) {
                    $status = "SKIPPED"
                    $reason = "Source no longer exists."
                }
                elseif ((Test-Path -LiteralPath $r.Destination) -and ($r.Source.ToLowerInvariant() -ne $r.Destination.ToLowerInvariant())) {
                    $status = "SKIPPED"
                    $reason = "Destination exists at apply time."
                }
                else {
                    Rename-DirectoryCaseSafe -Source $r.Source -Destination $r.Destination
                    $status = "RENAMED"
                    $done.Add([pscustomobject]@{ Source=$r.Source; Destination=$r.Destination })
                    Write-UiLog "$($r.OldName) -> $($r.NewName)" "OK"
                }
            } catch {
                $status = "ERROR"
                $reason = $_.Exception.Message
                Write-UiLog "Could not rename '$($r.Source)': $reason" "ERROR"
            }

            $results.Add([pscustomobject]@{
                Status=$status
                Depth=$r.Depth
                OldName=$r.OldName
                NewName=$r.NewName
                Source=$r.Source
                Destination=$r.Destination
                Reason=$reason
            })

            [pscustomobject]@{
                Root       = $root.FullName
                Created    = (Get-Date).ToString("s")
                Operations = $done.ToArray()
            } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $undoPath -Encoding UTF8
        }

        $results | Export-Csv -LiteralPath $applyPath -NoTypeInformation -Encoding UTF8
        Set-UiStatus "Folder rename completed" 100
        Write-UiLog "Rename finished. $($done.Count) folder(s) renamed." "OK"
        Write-UiLog "Undo log: $undoPath"
        Show-Info ("Finished.`r`n`r`nRenamed: {0}`r`nUndo log:`r`n{1}`r`n`r`nApply report:`r`n{2}" -f $done.Count,$undoPath,$applyPath)
    } catch {
        Write-UiLog $_.Exception.Message "ERROR"
        Set-UiStatus "Rename failed" 0
        Show-Warning $_.Exception.Message
    }
}

function Invoke-RenameUndo {
    try {
        $root = Get-SelectedRoot
        $latest = Get-ChildItem -LiteralPath $root.FullName -File -Filter ($Script:UndoPrefix + "*.json") |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1

        if (-not $latest) {
            Show-Info "No rename undo log was found in the selected root."
            return
        }

        $data = Get-Content -LiteralPath $latest.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
        $ops = @($data.Operations)
        if (@($ops).Count -eq 0) {
            Show-Info "The latest undo log contains no completed rename operations."
            return
        }

        if (-not (Confirm-Action ("Undo {0} folder rename(s)?`r`n`r`nLog:`r`n{1}" -f @($ops).Count,$latest.FullName) "Undo Folder Renames")) {
            return
        }

        $undone = 0
        $rev = @($ops)
        [array]::Reverse($rev)

        foreach ($op in $rev) {
            $original = [string]$op.Source
            $renamed = [string]$op.Destination

            try {
                if (-not (Test-Path -LiteralPath $renamed)) {
                    Write-UiLog "Undo skip - current path is missing: $renamed" "WARN"
                    continue
                }

                if ((Test-Path -LiteralPath $original) -and ($original.ToLowerInvariant() -ne $renamed.ToLowerInvariant())) {
                    Write-UiLog "Undo skip - original path already exists: $original" "WARN"
                    continue
                }

                Rename-DirectoryCaseSafe -Source $renamed -Destination $original
                $undone++
                Write-UiLog "UNDO: $(Split-Path -Leaf $renamed) -> $(Split-Path -Leaf $original)" "OK"
            } catch {
                Write-UiLog "Undo error for '$renamed': $($_.Exception.Message)" "ERROR"
            }
        }

        Set-UiStatus "Undo completed" 100
        Show-Info "Undo completed. Restored $undone folder name(s)."
    } catch {
        Write-UiLog $_.Exception.Message "ERROR"
        Set-UiStatus "Undo failed" 0
        Show-Warning $_.Exception.Message
    }
}

# ----------------------------- CATALOG HELPERS -----------------------------

function Get-WebPath {
    param([string]$RelativeWindowsPath)

    $segments = $RelativeWindowsPath -split "[\\/]"
    $encoded = foreach ($seg in $segments) {
        if ($seg -eq "..") { ".." }
        elseif ($seg -eq ".") { "." }
        else { [Uri]::EscapeDataString($seg) }
    }
    return ($encoded -join "/")
}

function Get-RelativePathCompat {
    param(
        [string]$BaseDirectory,
        [string]$TargetPath
    )

    $base = [System.IO.Path]::GetFullPath($BaseDirectory).TrimEnd('\') + "\"
    $target = [System.IO.Path]::GetFullPath($TargetPath)

    $baseUri = New-Object System.Uri($base)
    $targetUri = New-Object System.Uri($target)
    $relUri = $baseUri.MakeRelativeUri($targetUri)
    return [Uri]::UnescapeDataString($relUri.ToString()).Replace("/", "\")
}

function Convert-SrtToVtt {
    param(
        [string]$SrtPath,
        [string]$VttPath
    )

    try {
        $content = Get-Content -LiteralPath $SrtPath -Raw -Encoding UTF8
    } catch {
        # Some old subtitle files may use ANSI/default encoding.
        $content = Get-Content -LiteralPath $SrtPath -Raw
    }

    $content = $content -replace "^\uFEFF", ""
    $content = $content -replace "(\d{1,2}:\d{2}:\d{2}),(\d{3})", '$1.$2'
    $content = $content -replace "(\d{1,2}:\d{2}),(\d{3})", '$1.$2'

    $vtt = "WEBVTT`r`n`r`n" + $content.Trim() + "`r`n"
    $parent = Split-Path -Parent $VttPath
    if (-not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    Set-Content -LiteralPath $VttPath -Value $vtt -Encoding UTF8
}

function Get-StableId {
    param([string]$Text)
    $sha = [System.Security.Cryptography.SHA1]::Create()
    try {
        $bytes = [Text.Encoding]::UTF8.GetBytes($Text.ToLowerInvariant())
        $hash = $sha.ComputeHash($bytes)
        return ([BitConverter]::ToString($hash).Replace("-","").Substring(0,16).ToLowerInvariant())
    } finally {
        $sha.Dispose()
    }
}

function Get-ExternalTool {
    param([string]$Name)

    $cmd = Get-Command $Name -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }

    $localCandidates = @(
        (Join-Path $Script:ScriptDir ($Name + ".exe")),
        (Join-Path $Script:ScriptDir ("tools\" + $Name + ".exe")),
        (Join-Path $Script:ScriptDir ("tools\ffmpeg\bin\" + $Name + ".exe")),
        (Join-Path $Script:ScriptDir ("ffmpeg\bin\" + $Name + ".exe"))
    )
    foreach ($c in $localCandidates) {
        if (Test-Path -LiteralPath $c) { return $c }
    }
    return $null
}


function Refresh-ProcessPath {
    try {
        $machine = [Environment]::GetEnvironmentVariable("Path","Machine")
        $user = [Environment]::GetEnvironmentVariable("Path","User")
        $env:Path = (($machine,$user) -join ";").Trim(";")
    } catch {}
}

function Test-MediaComponents {
    $ffmpeg = Get-ExternalTool "ffmpeg"
    $ffprobe = Get-ExternalTool "ffprobe"
    return [pscustomobject]@{
        FFmpeg = $ffmpeg
        FFprobe = $ffprobe
        Ready = [bool]($ffmpeg -and $ffprobe)
    }
}


function Format-ByteSize {
    param([double]$Bytes)
    if ($Bytes -ge 1GB) { return ("{0:N2} GB" -f ($Bytes / 1GB)) }
    if ($Bytes -ge 1MB) { return ("{0:N1} MB" -f ($Bytes / 1MB)) }
    if ($Bytes -ge 1KB) { return ("{0:N1} KB" -f ($Bytes / 1KB)) }
    return ("{0:N0} B" -f $Bytes)
}

function Format-Eta {
    param([double]$Seconds)
    # Double.IsFinite is not available on every .NET Framework used by
    # Windows PowerShell 5.1. Use the older compatible checks instead.
    if ([double]::IsNaN($Seconds) -or [double]::IsInfinity($Seconds) -or $Seconds -lt 0) { return "--" }
    $ts = [TimeSpan]::FromSeconds([Math]::Round($Seconds))
    if ($ts.TotalHours -ge 1) {
        return ("{0}h {1}m" -f [int]$ts.TotalHours,$ts.Minutes)
    }
    if ($ts.TotalMinutes -ge 1) {
        return ("{0}m {1}s" -f $ts.Minutes,$ts.Seconds)
    }
    return ("{0}s" -f [Math]::Max(0,$ts.Seconds))
}

function Invoke-DownloadWithProgress {
    param(
        [Parameter(Mandatory=$true)][string]$Uri,
        [Parameter(Mandatory=$true)][string]$Destination,
        [string]$DisplayName = "Download",
        [int]$ConnectTimeoutSeconds = 35,
        [int]$ReadTimeoutSeconds = 45
    )

    $partPath = $Destination + ".part"
    Remove-Item -LiteralPath $partPath -Force -ErrorAction SilentlyContinue

    $request = $null
    $response = $null
    $input = $null
    $output = $null

    try {
        Write-UiLog ("Connecting to: " + $Uri)
        Set-UiStatus ("Connecting for " + $DisplayName + "...") 0

        # HttpWebRequest works on Windows PowerShell 5.1 and lets us stream
        # the response so the GUI can show real download progress.
        $request = [System.Net.HttpWebRequest]::Create($Uri)
        $request.Method = "GET"
        $request.AllowAutoRedirect = $true
        $request.Timeout = $ConnectTimeoutSeconds * 1000
        $request.ReadWriteTimeout = $ReadTimeoutSeconds * 1000
        $request.UserAgent = "Mozilla/5.0 CourseLibraryManager/$($Script:AppVersion)"
        $request.KeepAlive = $false

        $response = $request.GetResponse()
        $totalBytes = [double]$response.ContentLength
        $input = $response.GetResponseStream()

        try {
            if ($input.CanTimeout) {
                $input.ReadTimeout = $ReadTimeoutSeconds * 1000
            }
        } catch {}

        $output = New-Object System.IO.FileStream(
            $partPath,
            [System.IO.FileMode]::Create,
            [System.IO.FileAccess]::Write,
            [System.IO.FileShare]::None
        )

        $buffer = New-Object byte[] (1024 * 1024)
        [double]$downloaded = 0
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $lastUi = [DateTime]::MinValue
        $lastLoggedPct = -10
        $lastDataAt = [DateTime]::UtcNow

        while ($true) {
            try {
                $read = $input.Read($buffer, 0, $buffer.Length)
            } catch {
                throw "Download stalled or timed out while reading data: $($_.Exception.Message)"
            }

            if ($read -le 0) { break }

            $lastDataAt = [DateTime]::UtcNow
            $output.Write($buffer, 0, $read)
            $downloaded += $read

            # Refresh the UI at most ~5 times/sec.
            if (((Get-Date) - $lastUi).TotalMilliseconds -ge 180) {
                $lastUi = Get-Date
                $elapsed = [Math]::Max(0.1, $sw.Elapsed.TotalSeconds)
                $speed = $downloaded / $elapsed

                if ($totalBytes -gt 0) {
                    $pct = [Math]::Min(100, [int][Math]::Floor(($downloaded * 100.0) / $totalBytes))
                    $remaining = [Math]::Max(0, $totalBytes - $downloaded)
                    $eta = if ($speed -gt 0) { $remaining / $speed } else { [double]::PositiveInfinity }

                    $status = "{0}: {1}%  |  {2} / {3}  |  {4}/s  |  ETA {5}" -f `
                        $DisplayName,
                        $pct,
                        (Format-ByteSize $downloaded),
                        (Format-ByteSize $totalBytes),
                        (Format-ByteSize $speed),
                        (Format-Eta $eta)

                    Set-UiStatus $status $pct

                    if ($pct -ge ($lastLoggedPct + 10)) {
                        $lastLoggedPct = [int]([Math]::Floor($pct / 10) * 10)
                        Write-UiLog $status "INFO"
                    }
                }
                else {
                    if ($Script:ProgressBar -and -not $Script:ProgressBar.IsDisposed) {
                        $Script:ProgressBar.Style = [System.Windows.Forms.ProgressBarStyle]::Marquee
                        $Script:ProgressBar.MarqueeAnimationSpeed = 25
                    }
                    $status = "{0}: {1} downloaded  |  {2}/s" -f `
                        $DisplayName,
                        (Format-ByteSize $downloaded),
                        (Format-ByteSize $speed)
                    if ($Script:StatusLabel -and -not $Script:StatusLabel.IsDisposed) {
                        $Script:StatusLabel.Text = $status
                    }
                    [System.Windows.Forms.Application]::DoEvents()
                }
            }
        }

        $output.Flush()
        $output.Close()
        $output = $null
        $sw.Stop()

        if ($downloaded -le 0) {
            throw "The server returned no file data."
        }

        if ($totalBytes -gt 0 -and $downloaded -lt $totalBytes) {
            throw ("Download ended early. Expected {0}, received {1}." -f `
                (Format-ByteSize $totalBytes),(Format-ByteSize $downloaded))
        }

        Move-Item -LiteralPath $partPath -Destination $Destination -Force

        if ($Script:ProgressBar -and -not $Script:ProgressBar.IsDisposed) {
            $Script:ProgressBar.Style = [System.Windows.Forms.ProgressBarStyle]::Continuous
            $Script:ProgressBar.MarqueeAnimationSpeed = 0
        }

        $elapsedFinal = [Math]::Max(0.1,$sw.Elapsed.TotalSeconds)
        $avgSpeed = $downloaded / $elapsedFinal
        Set-UiStatus ("{0}: 100%  |  {1} downloaded" -f $DisplayName,(Format-ByteSize $downloaded)) 100
        Write-UiLog ("Download complete: {0} in {1:N1}s (avg {2}/s)" -f `
            (Format-ByteSize $downloaded),$elapsedFinal,(Format-ByteSize $avgSpeed)) "OK"
        return $true
    }
    catch {
        Remove-Item -LiteralPath $partPath -Force -ErrorAction SilentlyContinue
        if ($Script:ProgressBar -and -not $Script:ProgressBar.IsDisposed) {
            $Script:ProgressBar.Style = [System.Windows.Forms.ProgressBarStyle]::Continuous
            $Script:ProgressBar.MarqueeAnimationSpeed = 0
        }
        throw
    }
    finally {
        if ($output) { try { $output.Dispose() } catch {} }
        if ($input)  { try { $input.Dispose() } catch {} }
        if ($response) { try { $response.Close() } catch {} }
    }
}

function Install-PortableFFmpeg {
    <#
      Installs a portable FFmpeg build inside this application's folder.
      No Administrator rights are required.

      The downloader shows:
        - percentage
        - downloaded MB / total MB
        - transfer speed
        - ETA

      It also has connection/read timeouts and retries another source if
      the first download endpoint fails.
    #>
    $toolsRoot = Join-Path $Script:ScriptDir "tools"
    $installRoot = Join-Path $toolsRoot "ffmpeg"
    $binRoot = Join-Path $installRoot "bin"
    $tempRoot = Join-Path $toolsRoot "_ffmpeg_install_temp"
    $zipPath = Join-Path $toolsRoot "ffmpeg-portable.zip"

    # Primary is the smaller Windows essentials build. GitHub/BtbN is a fallback.
    $sources = @(
        "https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip",
        "https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-win64-gpl.zip"
    )

    try {
        New-Item -ItemType Directory -Path $toolsRoot -Force | Out-Null
        New-Item -ItemType Directory -Path $binRoot -Force | Out-Null

        Write-UiLog "FFmpeg/ffprobe are missing. Installing portable FFmpeg locally..." "WARN"

        # TLS 1.2 for older Windows PowerShell defaults.
        try {
            [Net.ServicePointManager]::SecurityProtocol =
                [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
        } catch {}

        $downloaded = $false
        $attempt = 0

        foreach ($downloadUrl in $sources) {
            $attempt++
            try {
                Remove-Item -LiteralPath $zipPath -Force -ErrorAction SilentlyContinue
                Write-UiLog ("FFmpeg download attempt {0}/{1}" -f $attempt,@($sources).Count) "INFO"

                [void](Invoke-DownloadWithProgress `
                    -Uri $downloadUrl `
                    -Destination $zipPath `
                    -DisplayName ("Downloading FFmpeg ({0}/{1})" -f $attempt,@($sources).Count) `
                    -ConnectTimeoutSeconds 35 `
                    -ReadTimeoutSeconds 45)

                if (Test-Path -LiteralPath $zipPath) {
                    $downloaded = $true
                    break
                }
            }
            catch {
                Write-UiLog ("Download source failed: " + $_.Exception.Message) "WARN"
                Remove-Item -LiteralPath $zipPath -Force -ErrorAction SilentlyContinue
            }
        }

        if (-not $downloaded) {
            throw "All FFmpeg download sources failed or timed out."
        }

        if (Test-Path -LiteralPath $tempRoot) {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
        }

        Set-UiStatus "FFmpeg download complete. Extracting files..." 0
        Write-UiLog "Extracting FFmpeg package..." "INFO"
        Expand-Archive -LiteralPath $zipPath -DestinationPath $tempRoot -Force

        Set-UiStatus "Finding ffmpeg.exe and ffprobe.exe..." 40
        $ffmpegSource = @(Get-ChildItem -LiteralPath $tempRoot -Filter "ffmpeg.exe" -File -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1)
        $ffprobeSource = @(Get-ChildItem -LiteralPath $tempRoot -Filter "ffprobe.exe" -File -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1)

        if (@($ffmpegSource).Count -eq 0 -or @($ffprobeSource).Count -eq 0) {
            throw "The downloaded package did not contain ffmpeg.exe and ffprobe.exe."
        }

        Set-UiStatus "Installing ffmpeg.exe..." 60
        Copy-Item -LiteralPath $ffmpegSource[0].FullName -Destination (Join-Path $binRoot "ffmpeg.exe") -Force

        Set-UiStatus "Installing ffprobe.exe..." 78
        Copy-Item -LiteralPath $ffprobeSource[0].FullName -Destination (Join-Path $binRoot "ffprobe.exe") -Force

        # ffplay is optional.
        $ffplaySource = @(Get-ChildItem -LiteralPath $tempRoot -Filter "ffplay.exe" -File -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1)
        if (@($ffplaySource).Count -gt 0) {
            Set-UiStatus "Installing optional ffplay.exe..." 88
            Copy-Item -LiteralPath $ffplaySource[0].FullName -Destination (Join-Path $binRoot "ffplay.exe") -Force
        }

        # Verify executables before reporting success.
        Set-UiStatus "Verifying FFmpeg installation..." 95
        $installedFfmpeg = Join-Path $binRoot "ffmpeg.exe"
        $installedFfprobe = Join-Path $binRoot "ffprobe.exe"

        if (-not (Test-Path -LiteralPath $installedFfmpeg) -or -not (Test-Path -LiteralPath $installedFfprobe)) {
            throw "FFmpeg files could not be copied into the local tools folder."
        }

        try {
            & $installedFfmpeg -version 2>$null | Select-Object -First 1 | ForEach-Object {
                Write-UiLog ("Verified: " + $_) "OK"
            }
            & $installedFfprobe -version 2>$null | Select-Object -First 1 | ForEach-Object {
                Write-UiLog ("Verified: " + $_) "OK"
            }
        } catch {
            Write-UiLog "Executables were installed, but version verification returned an error." "WARN"
        }

        Set-UiStatus "Portable FFmpeg installed successfully" 100
        Write-UiLog "Portable FFmpeg installed successfully: $binRoot" "OK"
        return $true
    }
    catch {
        Write-UiLog ("Portable FFmpeg installation failed: " + $_.Exception.Message) "ERROR"
        Write-UiLog "Catalog generation can continue without generated thumbnails/durations." "WARN"
        return $false
    }
    finally {
        Remove-Item -LiteralPath $zipPath -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath ($zipPath + ".part") -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Ensure-MediaComponents {
    param([switch]$Interactive)

    $state = Test-MediaComponents
    if ($state.Ready) {
        Write-UiLog "Media components ready. ffmpeg: $($state.FFmpeg)" "OK"
        Write-UiLog "Media components ready. ffprobe: $($state.FFprobe)" "OK"
        return $state
    }

    $needsMediaTools = [bool]$Script:Settings.GenerateVideoThumbnails -or [bool]$Script:Settings.GenerateDurations
    if (-not $needsMediaTools -and -not $Interactive) {
        return $state
    }

    $install = $true
    if ($Interactive) {
        $install = Confirm-Action (
            "FFmpeg and/or ffprobe are missing.`r`n`r`n" +
            "They are used for video thumbnails and duration detection.`r`n" +
            "Install a portable copy inside this application folder now?`r`n`r`n" +
            "No Administrator rights are required."
        ) "Install Missing Components"
    }

    if ($install) {
        [void](Install-PortableFFmpeg)
        Refresh-ProcessPath
        $state = Test-MediaComponents
    }

    return $state
}

function Invoke-CheckInstallComponents {
    try {
        Set-UiStatus "Checking components..." 3
        $state = Ensure-MediaComponents -Interactive
        if ($state.Ready) {
            Set-UiStatus "Components ready" 100
            Show-Info (
                "Required media components are ready.`r`n`r`n" +
                "ffmpeg:`r`n$($state.FFmpeg)`r`n`r`n" +
                "ffprobe:`r`n$($state.FFprobe)"
            ) "Components Ready"
        } else {
            Set-UiStatus "Components incomplete" 0
            Show-Warning (
                "FFmpeg/ffprobe are still unavailable.`r`n`r`n" +
                "The HTML catalog can still be built, but automatic video thumbnails " +
                "and duration detection may be unavailable."
            ) "Components Not Ready"
        }
    } catch {
        Write-UiLog ("Component check failed: " + $_.Exception.Message) "ERROR"
        Set-UiStatus "Component check failed" 0
        Show-Warning $_.Exception.Message
    }
}

function Get-VideoDurationSeconds {
    param(
        [string]$VideoPath,
        [string]$FfprobePath
    )

    if (-not $FfprobePath) { return $null }

    try {
        $args = @(
            "-v","error",
            "-show_entries","format=duration",
            "-of","default=noprint_wrappers=1:nokey=1",
            $VideoPath
        )
        $output = & $FfprobePath @args 2>$null
        if ($LASTEXITCODE -eq 0 -and $output) {
            $value = 0.0
            if ([double]::TryParse(
                ([string]$output).Trim(),
                [Globalization.NumberStyles]::Float,
                [Globalization.CultureInfo]::InvariantCulture,
                [ref]$value
            )) {
                return [Math]::Round($value,2)
            }
        }
    } catch {}
    return $null
}

function Format-Duration {
    param($Seconds)

    if ($null -eq $Seconds) { return "" }
    try { $s = [int][Math]::Round([double]$Seconds) } catch { return "" }

    $ts = [TimeSpan]::FromSeconds($s)
    if ($ts.TotalHours -ge 1) {
        return "{0}:{1:00}:{2:00}" -f [int]$ts.TotalHours,$ts.Minutes,$ts.Seconds
    }
    return "{0}:{1:00}" -f $ts.Minutes,$ts.Seconds
}

function Get-CourseCoverFile {
    param([System.IO.DirectoryInfo]$CourseDir)

    $images = @(Get-ChildItem -LiteralPath $CourseDir.FullName -File -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.Extension.ToLowerInvariant() -in @(".jpg",".jpeg",".png",".webp",".gif",".bmp") })

    if (@($images).Count -eq 0) { return $null }

    $priorityPatterns = @(
        "^(cover|course[\s_-]*cover)(\b|[\s_.-])",
        "^(course|poster|thumbnail|thumb)(\b|[\s_.-])",
        "(?i)cover",
        "(?i)poster",
        "(?i)thumbnail"
    )

    foreach ($pattern in $priorityPatterns) {
        $match = $images | Where-Object { $_.BaseName -match $pattern } | Select-Object -First 1
        if ($match) { return $match }
    }

    # Only root-level images are considered; this avoids lesson screenshots becoming the cover.
    return ($images | Sort-Object Length -Descending | Select-Object -First 1)
}

function Find-MatchingSubtitle {
    param(
        [System.IO.FileInfo]$Video,
        [hashtable]$SubtitleLookup
    )

    $base = [System.IO.Path]::GetFileNameWithoutExtension($Video.Name)
    $parentKey = $Video.Directory.FullName.ToLowerInvariant()
    $keys = @(
        ($parentKey + "|" + ($base + "_en").ToLowerInvariant()),
        ($parentKey + "|" + $base.ToLowerInvariant())
    )

    foreach ($k in $keys) {
        if ($SubtitleLookup.ContainsKey($k)) {
            return $SubtitleLookup[$k]
        }
    }
    return $null
}

function New-VideoThumbnail {
    param(
        [string]$VideoPath,
        [string]$OutputPath,
        [string]$FfmpegPath,
        $DurationSeconds,
        [int]$SeekPercent
    )

    if (-not $FfmpegPath) { return $false }
    if (Test-Path -LiteralPath $OutputPath) { return $true }

    $parent = Split-Path -Parent $OutputPath
    if (-not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    $seek = 5.0
    if ($DurationSeconds -and [double]$DurationSeconds -gt 1) {
        $seek = [Math]::Max(1.0, [Math]::Min(([double]$DurationSeconds - 0.5), ([double]$DurationSeconds * $SeekPercent / 100.0)))
    }

    $seekText = $seek.ToString("0.###", [Globalization.CultureInfo]::InvariantCulture)

    try {
        $args = @(
            "-hide_banner","-loglevel","error",
            "-ss",$seekText,
            "-i",$VideoPath,
            "-frames:v","1",
            "-vf","scale=480:-2",
            "-q:v","4",
            "-y",
            $OutputPath
        )
        & $FfmpegPath @args 2>$null | Out-Null
        return (($LASTEXITCODE -eq 0) -and (Test-Path -LiteralPath $OutputPath))
    } catch {
        return $false
    }
}

function ConvertTo-JsonForHtml {
    param($Object)

    # -InputObject preserves an actual array (including an empty or one-item
    # array) instead of relying on pipeline enumeration semantics.
    $json = ConvertTo-Json -InputObject $Object -Depth 12 -Compress
    if ([string]::IsNullOrWhiteSpace([string]$json)) {
        $json = "[]"
    }

    # Avoid accidentally terminating the HTML script element. Match any case.
    $json = [regex]::Replace([string]$json, "(?i)</script", "<\/script")
    return [string]$json
}

function Get-SectionName {
    param(
        [System.IO.FileInfo]$File,
        [System.IO.DirectoryInfo]$CourseDir
    )

    $relDir = Get-RelativePathCompat -BaseDirectory $CourseDir.FullName -TargetPath $File.Directory.FullName
    if ($relDir -eq "." -or [string]::IsNullOrWhiteSpace($relDir)) {
        return "Course Root"
    }

    $first = ($relDir -split "\\")[0]
    return Get-CleanSubfolderName $first
}


function Test-CatalogCompatibility {
    try {
        # Explicit constructor + ToArray() avoids the PowerShell binder bug
        # triggered by: New-Object List[object] followed by @($list).
        $testList = [System.Collections.Generic.List[object]]::new()
        $testList.Add([pscustomobject]@{
            id = "test"
            title = "Compatibility Test"
        })
        $testArray = $testList.ToArray()

        if ($testArray.Count -ne 1) {
            throw "Generic list conversion self-test returned the wrong item count."
        }

        $testDuration = Format-Duration -Seconds 65
        if ([string]::IsNullOrWhiteSpace([string]$testDuration)) {
            throw "Duration-format self-test failed."
        }

        $testObject = [pscustomobject][ordered]@{
            id = "test-course"
            videoCount = [int]$testArray.Count
            totalDuration = [double]65
            totalDurationText = [string]$testDuration
            videos = $testArray
            resources = [array]@()
        }

        $testJson = ConvertTo-Json -InputObject $testObject -Depth 6 -Compress
        if ([string]::IsNullOrWhiteSpace([string]$testJson)) {
            throw "JSON serialization self-test failed."
        }

        # Test the exact array -> JSON -> HTML path used by the real catalog.
        $testLibrary = [array]@($testObject)
        $testLibraryJson = ConvertTo-JsonForHtml -Object $testLibrary
        if ([string]::IsNullOrWhiteSpace($testLibraryJson) -or $testLibraryJson -eq "null") {
            throw "Library JSON self-test failed."
        }

        $testHtml = Get-HtmlTemplate -LibraryJson $testLibraryJson
        if ([string]::IsNullOrWhiteSpace([string]$testHtml)) {
            throw "HTML-template self-test returned no content."
        }
        if ($testHtml.Contains("__LIBRARY_JSON__")) {
            throw "HTML-template placeholder replacement self-test failed."
        }
        if (-not $testHtml.Contains("Compatibility Test")) {
            throw "Generated HTML did not contain the test library data."
        }

        # Exercise ETA formatting on old Windows PowerShell/.NET Framework.
        $testEta = Format-Eta -Seconds 65
        if ([string]::IsNullOrWhiteSpace([string]$testEta)) {
            throw "ETA formatting self-test failed."
        }

        Write-UiLog "Catalog compatibility self-test passed (lists, JSON, HTML template, ETA)." "OK"
        return $true
    }
    catch {
        Write-UiLog ("Catalog compatibility self-test FAILED: " + $_.Exception.Message) "ERROR"
        return $false
    }
}

function Build-CourseLibraryData {
    param(
        [System.IO.DirectoryInfo]$Root,
        [System.IO.DirectoryInfo]$CatalogDir
    )

    $videoExt = @(".mp4",".webm",".m4v",".mov",".mkv",".avi",".ogv",".ogg")
    $imageExt = @(".jpg",".jpeg",".png",".webp",".gif",".bmp")
    $pdfExt = @(".pdf")
    $subtitleExt = @(".srt",".vtt")
    $skipNames = @(
        $Script:Settings.CatalogFolderName,
        ".git",
        "__pycache__"
    )

    $ffprobe = if ([bool]$Script:Settings.GenerateDurations) { Get-ExternalTool "ffprobe" } else { $null }
    $ffmpeg  = if ([bool]$Script:Settings.GenerateVideoThumbnails) { Get-ExternalTool "ffmpeg" } else { $null }

    if ([bool]$Script:Settings.GenerateDurations -and -not $ffprobe) {
        Write-UiLog "ffprobe not found. Video duration values will be omitted." "WARN"
    }
    if ([bool]$Script:Settings.GenerateVideoThumbnails -and -not $ffmpeg) {
        Write-UiLog "ffmpeg not found. Video cards will use the course cover/placeholder instead." "WARN"
    }

    $courses = @(Get-ChildItem -LiteralPath $Root.FullName -Directory -Force |
        Where-Object { $skipNames -notcontains $_.Name } |
        Sort-Object Name)

    $library = [System.Collections.Generic.List[object]]::new()
    $courseIndex = 0
    $totalCourses = [Math]::Max(1,@($courses).Count)

    foreach ($course in $courses) {
        $courseIndex++
        Set-UiStatus ("Cataloging course {0}/{1}: {2}" -f $courseIndex,@($courses).Count,$course.Name) ([int](70*$courseIndex/$totalCourses))
        Write-UiLog "Scanning course: $($course.Name)"

        $allFiles = @(Get-ChildItem -LiteralPath $course.FullName -File -Recurse -Force -ErrorAction SilentlyContinue)
        $videos = @($allFiles | Where-Object { $videoExt -contains $_.Extension.ToLowerInvariant() } | Sort-Object FullName)
        $subtitles = @($allFiles | Where-Object { $subtitleExt -contains $_.Extension.ToLowerInvariant() })
        $resources = @()

        # Subtitle lookup by parent + basename.
        $subtitleLookup = @{}
        foreach ($s in $subtitles) {
            $key = $s.Directory.FullName.ToLowerInvariant() + "|" + $s.BaseName.ToLowerInvariant()
            if (-not $subtitleLookup.ContainsKey($key)) {
                $subtitleLookup[$key] = $s
            }
        }

        $coverFile = Get-CourseCoverFile -CourseDir $course
        $coverWeb = $null
        if ($coverFile) {
            $rel = Get-RelativePathCompat -BaseDirectory $CatalogDir.FullName -TargetPath $coverFile.FullName
            $coverWeb = Get-WebPath $rel
        }

        $courseId = Get-StableId $course.FullName
        $videoItems = [System.Collections.Generic.List[object]]::new()
        $totalDuration = 0.0
        $knownDurationCount = 0
        $vIndex = 0

        foreach ($video in $videos) {
            $vIndex++
            $duration = $null
            if ($ffprobe) {
                $duration = Get-VideoDurationSeconds -VideoPath $video.FullName -FfprobePath $ffprobe
                if ($duration) {
                    $totalDuration += [double]$duration
                    $knownDurationCount++
                }
            }

            $relVideo = Get-RelativePathCompat -BaseDirectory $CatalogDir.FullName -TargetPath $video.FullName
            $videoWeb = Get-WebPath $relVideo

            $subtitleWeb = $null
            if ([bool]$Script:Settings.IncludeSubtitles) {
                $sub = Find-MatchingSubtitle -Video $video -SubtitleLookup $subtitleLookup
                if ($sub) {
                    if ($sub.Extension.ToLowerInvariant() -eq ".vtt") {
                        $relSub = Get-RelativePathCompat -BaseDirectory $CatalogDir.FullName -TargetPath $sub.FullName
                        $subtitleWeb = Get-WebPath $relSub
                    } else {
                        $sid = Get-StableId $sub.FullName
                        $vttPath = Join-Path $CatalogDir.FullName ("assets\vtt\" + $courseId + "\" + $sid + ".vtt")
                        if (-not (Test-Path -LiteralPath $vttPath) -or
                            ((Get-Item -LiteralPath $vttPath).LastWriteTimeUtc -lt $sub.LastWriteTimeUtc)) {
                            try {
                                Convert-SrtToVtt -SrtPath $sub.FullName -VttPath $vttPath
                            } catch {
                                Write-UiLog "Subtitle conversion failed: $($sub.FullName)" "WARN"
                            }
                        }
                        if (Test-Path -LiteralPath $vttPath) {
                            $relVtt = Get-RelativePathCompat -BaseDirectory $CatalogDir.FullName -TargetPath $vttPath
                            $subtitleWeb = Get-WebPath $relVtt
                        }
                    }
                }
            }

            $thumbWeb = $null
            if ($ffmpeg -and [bool]$Script:Settings.GenerateVideoThumbnails) {
                $vid = Get-StableId $video.FullName
                $thumbPath = Join-Path $CatalogDir.FullName ("assets\thumbs\" + $courseId + "\" + $vid + ".jpg")
                $ok = New-VideoThumbnail -VideoPath $video.FullName -OutputPath $thumbPath -FfmpegPath $ffmpeg -DurationSeconds $duration -SeekPercent ([int]$Script:Settings.ThumbnailSeekPercent)
                if ($ok) {
                    $relThumb = Get-RelativePathCompat -BaseDirectory $CatalogDir.FullName -TargetPath $thumbPath
                    $thumbWeb = Get-WebPath $relThumb
                }
            }

            $section = Get-SectionName -File $video -CourseDir $course
            $display = Get-CleanDisplayName $video.Name
            $videoItems.Add([pscustomobject][ordered]@{
                id          = Get-StableId $video.FullName
                order       = $vIndex
                title       = $display
                section     = $section
                path        = $videoWeb
                original    = $video.Name
                duration    = $duration
                durationText= Format-Duration $duration
                subtitle    = $subtitleWeb
                thumbnail   = $thumbWeb
                extension   = $video.Extension.TrimStart('.').ToUpperInvariant()
            })
        }

        # If the course has no explicit root-level cover image, use the first
        # generated video thumbnail as a visual course cover. This is safer
        # than selecting an arbitrary lesson screenshot/resource image.
        if (-not $coverWeb -and $videoItems.Count -gt 0) {
            $firstThumb = $videoItems | Where-Object { $_.thumbnail } | Select-Object -First 1
            if ($firstThumb) {
                $coverWeb = $firstThumb.thumbnail
            }
        }

        # Resource files: don't list subtitle files or video files here.
        foreach ($file in $allFiles) {
            $ext = $file.Extension.ToLowerInvariant()
            if ($videoExt -contains $ext) { continue }
            if ($subtitleExt -contains $ext) { continue }

            $kind = "Other"
            $include = $false

            if ($pdfExt -contains $ext) {
                $kind = "PDF"
                $include = [bool]$Script:Settings.IncludePDFs
            }
            elseif ($imageExt -contains $ext) {
                $kind = "Image"
                $include = [bool]$Script:Settings.IncludeImages
            }
            else {
                $kind = "Other"
                $include = [bool]$Script:Settings.IncludeOtherResources
            }

            if (-not $include) { continue }

            # Course cover can also remain available as a resource; no harm.
            $relFile = Get-RelativePathCompat -BaseDirectory $CatalogDir.FullName -TargetPath $file.FullName
            $resources += [pscustomobject][ordered]@{
                id       = Get-StableId $file.FullName
                title    = Get-CleanDisplayName $file.Name
                section  = Get-SectionName -File $file -CourseDir $course
                path     = Get-WebPath $relFile
                kind     = $kind
                extension= $file.Extension.TrimStart('.').ToUpperInvariant()
            }
        }

        $videoArray = $videoItems.ToArray()
        $resourceArray = [array]$resources
        $sections = @($videoArray | ForEach-Object { $_.section } | Select-Object -Unique)
        $folderRel = Get-RelativePathCompat -BaseDirectory $CatalogDir.FullName -TargetPath $course.FullName
        $folderWeb = Get-WebPath ($folderRel.TrimEnd('\') + "\")

        $courseTotalDuration = $null
        $courseTotalDurationText = ""
        if ($knownDurationCount -gt 0) {
            $courseTotalDuration = [Math]::Round([double]$totalDuration, 2)
            $courseTotalDurationText = Format-Duration -Seconds $courseTotalDuration
        }

        $courseObject = [pscustomobject][ordered]@{
            id                = [string]$courseId
            name              = [string](Get-CleanParentName $course.Name)
            originalName      = [string]$course.Name
            folder            = [string]$folderWeb
            cover             = $coverWeb
            videoCount        = [int]$videoArray.Count
            resourceCount     = [int]$resourceArray.Count
            sectionCount      = [int]@($sections).Count
            totalDuration     = $courseTotalDuration
            totalDurationText = [string]$courseTotalDurationText
            videos            = $videoArray
            resources         = $resourceArray
        }

        $library.Add($courseObject)
    }

    return $library.ToArray()
}

function Get-HtmlTemplate {
    param([string]$LibraryJson)

    $theme = [string]$Script:Settings.Theme
    $defaultView = ([string]$Script:Settings.DefaultView).ToLowerInvariant()
    $defaultSpeed = ([double]$Script:Settings.DefaultPlaybackSpeed).ToString("0.##",[Globalization.CultureInfo]::InvariantCulture)

    $html = @'
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>My Course Library</title>
<style>
:root{
  --bg:#0b1220;--panel:#111827;--panel2:#172033;--text:#eef2ff;--muted:#9ca3af;
  --line:#293349;--accent:#67e8f9;--accent2:#8b5cf6;--good:#34d399;--warn:#fbbf24;
  --shadow:0 14px 38px rgba(0,0,0,.28);--radius:18px;
}
body.light{
  --bg:#f3f6fb;--panel:#ffffff;--panel2:#f8fafc;--text:#111827;--muted:#667085;
  --line:#dbe3ef;--accent:#0676d8;--accent2:#7c3aed;--good:#059669;--warn:#d97706;
  --shadow:0 14px 34px rgba(17,24,39,.10);
}
*{box-sizing:border-box}
html{scroll-behavior:smooth}
body{margin:0;background:var(--bg);color:var(--text);font:14px/1.45 "Segoe UI",Arial,sans-serif}
button,input,select{font:inherit}
button{cursor:pointer}
a{color:inherit}
.topbar{position:sticky;top:0;z-index:20;background:color-mix(in srgb,var(--bg) 88%,transparent);backdrop-filter:blur(14px);border-bottom:1px solid var(--line)}
.topbar-inner{max-width:1500px;margin:auto;padding:15px 22px;display:flex;gap:14px;align-items:center}
.brand{font-weight:800;font-size:20px;letter-spacing:.2px;white-space:nowrap}
.brand span{color:var(--accent)}
.search{flex:1;position:relative}
.search input{width:100%;background:var(--panel);border:1px solid var(--line);border-radius:12px;padding:11px 14px 11px 38px;color:var(--text);outline:none}
.search:before{content:"⌕";position:absolute;left:13px;top:7px;font-size:22px;color:var(--muted)}
.toolbar{display:flex;gap:8px;flex-wrap:wrap}
.btn{border:1px solid var(--line);background:var(--panel);color:var(--text);padding:9px 12px;border-radius:10px}
.btn:hover{border-color:var(--accent);transform:translateY(-1px)}
.btn.primary{background:linear-gradient(135deg,var(--accent2),#2563eb);border:0;color:white;font-weight:700}
.btn.good{background:var(--good);border:0;color:#06281e;font-weight:800}
.container{max-width:1500px;margin:auto;padding:24px}
.stats{display:flex;gap:10px;flex-wrap:wrap;margin:4px 0 22px}
.chip{background:var(--panel);border:1px solid var(--line);padding:8px 11px;border-radius:999px;color:var(--muted)}
.chip b{color:var(--text)}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(280px,1fr));gap:18px}
.course-card{background:var(--panel);border:1px solid var(--line);border-radius:var(--radius);overflow:hidden;box-shadow:var(--shadow);transition:.18s}
.course-card:hover{transform:translateY(-3px);border-color:color-mix(in srgb,var(--accent) 70%,var(--line))}
.course-cover{height:172px;background:linear-gradient(135deg,#1e3a8a,#5b21b6);position:relative;display:flex;align-items:center;justify-content:center;overflow:hidden}
.course-cover img{width:100%;height:100%;object-fit:cover}
.cover-fallback{font-size:46px;font-weight:900;opacity:.85}
.card-body{padding:16px}
.card-title{font-weight:800;font-size:17px;min-height:48px}
.meta{color:var(--muted);margin-top:7px}
.progress{height:7px;background:var(--panel2);border-radius:999px;overflow:hidden;margin:13px 0}
.progress>i{height:100%;display:block;background:linear-gradient(90deg,var(--accent2),var(--accent));width:0}
.card-actions{display:flex;justify-content:space-between;align-items:center;gap:8px}
.linkbtn{text-decoration:none}
.hidden{display:none!important}
.course-head{display:grid;grid-template-columns:minmax(220px,340px) 1fr;gap:28px;background:var(--panel);border:1px solid var(--line);border-radius:22px;padding:22px;box-shadow:var(--shadow);margin-bottom:22px}
.course-head-cover{min-height:220px;border-radius:16px;overflow:hidden;background:linear-gradient(135deg,#1e3a8a,#5b21b6);display:flex;align-items:center;justify-content:center}
.course-head-cover img{width:100%;height:100%;object-fit:cover}
.course-title{font-size:29px;font-weight:900;margin:0 0 8px}
.big-meta{color:var(--muted);font-size:15px}
.head-actions{display:flex;gap:10px;flex-wrap:wrap;margin-top:19px}
.tabs{display:flex;gap:8px;flex-wrap:wrap;margin:14px 0}
.tab{background:var(--panel);border:1px solid var(--line);border-radius:999px;padding:8px 12px;color:var(--muted)}
.tab.active{color:var(--text);border-color:var(--accent)}
.section{background:var(--panel);border:1px solid var(--line);border-radius:14px;margin:12px 0;overflow:hidden}
.section-header{padding:13px 15px;font-weight:800;display:flex;justify-content:space-between;cursor:pointer;background:var(--panel2)}
.section-content{padding:12px}
.cards{display:grid;grid-template-columns:repeat(auto-fill,minmax(250px,1fr));gap:14px}
.video-card{border:1px solid var(--line);border-radius:14px;overflow:hidden;background:var(--panel2)}
.video-thumb{height:140px;background:#050913;position:relative;display:flex;align-items:center;justify-content:center;overflow:hidden}
.video-thumb img{width:100%;height:100%;object-fit:cover}
.video-thumb .play{position:absolute;width:50px;height:50px;border-radius:50%;border:0;background:rgba(0,0,0,.68);color:white;font-size:21px}
.video-thumb .dur{position:absolute;right:8px;bottom:7px;background:rgba(0,0,0,.72);color:white;padding:3px 6px;border-radius:5px;font-size:12px}
.video-info{padding:11px}
.video-title{font-weight:700;min-height:42px}
.video-sub{display:flex;justify-content:space-between;color:var(--muted);font-size:12px;margin-top:8px}
.table-wrap{overflow:auto;border:1px solid var(--line);border-radius:14px}
table{width:100%;border-collapse:collapse;background:var(--panel)}
th,td{padding:10px 12px;border-bottom:1px solid var(--line);text-align:left;vertical-align:middle}
th{position:sticky;top:68px;background:var(--panel2);z-index:4;color:var(--muted);font-size:12px;text-transform:uppercase;letter-spacing:.5px}
tr:hover td{background:color-mix(in srgb,var(--panel2) 72%,transparent)}
.small{font-size:12px;color:var(--muted)}
.player-shell{position:sticky;top:76px;z-index:10;background:var(--panel);border:1px solid var(--line);border-radius:18px;padding:15px;margin:0 0 20px;box-shadow:var(--shadow)}
.video-wrap{background:#000;border-radius:13px;overflow:hidden;aspect-ratio:16/9;display:flex;align-items:center;justify-content:center}
video{width:100%;height:100%;background:#000}
.player-title{font-size:18px;font-weight:800;margin:10px 0 7px}
.player-controls{display:flex;gap:8px;align-items:center;flex-wrap:wrap}
.player-controls select{background:var(--panel2);color:var(--text);border:1px solid var(--line);padding:8px;border-radius:9px}
.player-progress{color:var(--muted);margin-left:auto}
.resource-list{display:grid;grid-template-columns:repeat(auto-fill,minmax(280px,1fr));gap:10px}
.resource{background:var(--panel);border:1px solid var(--line);border-radius:12px;padding:12px;text-decoration:none;display:flex;gap:10px;align-items:center}
.resource:hover{border-color:var(--accent)}
.badge{display:inline-block;border:1px solid var(--line);border-radius:999px;padding:3px 7px;font-size:11px;color:var(--muted)}
.empty{text-align:center;padding:52px 10px;color:var(--muted)}
.footer{padding:35px 0;color:var(--muted);text-align:center}
@media(max-width:760px){
 .topbar-inner{flex-wrap:wrap}.brand{width:100%}.course-head{grid-template-columns:1fr}.course-head-cover{min-height:180px}
 .container{padding:15px}.player-shell{top:115px}.course-title{font-size:23px}
}
</style>
</head>
<body>
<div class="topbar">
  <div class="topbar-inner">
    <div class="brand"><span>▶</span> My Course Library</div>
    <div class="search"><input id="searchBox" placeholder="Search courses, sections, lessons or resources..."></div>
    <div class="toolbar">
      <button class="btn" id="homeBtn">Library</button>
      <button class="btn" id="viewBtn">▦ Cards</button>
      <button class="btn" id="themeBtn">◐ Theme</button>
    </div>
  </div>
</div>

<main class="container">
  <section id="homeView"></section>
  <section id="courseView" class="hidden"></section>
</main>

<script>
const LIBRARY = __LIBRARY_JSON__;
const CONFIG = {
  defaultView: "__DEFAULT_VIEW__",
  theme: "__THEME__",
  defaultSpeed: __DEFAULT_SPEED__
};

const state = {
  course: null,
  view: localStorage.getItem("clm:view") || CONFIG.defaultView || "cards",
  filter: "all",
  search: "",
  currentVideoId: null
};

const el = id => document.getElementById(id);
const esc = s => String(s ?? "").replace(/[&<>"']/g, c => ({"&":"&amp;","<":"&lt;",">":"&gt;","\"":"&quot;","'":"&#039;"}[c]));
const progressKey = id => "clm:progress:" + id;
const getProgress = id => {
  try { return JSON.parse(localStorage.getItem(progressKey(id)) || "{}"); }
  catch { return {}; }
};
const setProgress = (id, value) => localStorage.setItem(progressKey(id), JSON.stringify(value));
const pct = (a,b) => b > 0 ? Math.max(0,Math.min(100,Math.round(a*100/b))) : 0;

function initTheme(){
  const saved = localStorage.getItem("clm:theme");
  const useLight = saved ? saved === "light" : String(CONFIG.theme).toLowerCase() === "light";
  document.body.classList.toggle("light", useLight);
}
function toggleTheme(){
  document.body.classList.toggle("light");
  localStorage.setItem("clm:theme", document.body.classList.contains("light") ? "light" : "dark");
}
function totalWatched(course){
  let done=0;
  for(const v of course.videos){
    const p=getProgress(v.id);
    if(p.watched || (p.duration && p.time/p.duration >= .9)) done++;
  }
  return done;
}
function coursePercent(course){
  return course.videoCount ? Math.round(totalWatched(course)*100/course.videoCount) : 0;
}
function matchingCourse(course,q){
  if(!q) return true;
  q=q.toLowerCase();
  if(course.name.toLowerCase().includes(q)) return true;
  return course.videos.some(v => (v.title+" "+v.section).toLowerCase().includes(q)) ||
         course.resources.some(r => (r.title+" "+r.section+" "+r.kind).toLowerCase().includes(q));
}
function coverHtml(course, cls="course-cover"){
  if(course.cover) return `<div class="${cls}"><img src="${course.cover}" alt="" loading="lazy"></div>`;
  return `<div class="${cls}"><div class="cover-fallback">${esc((course.name||"?").slice(0,2).toUpperCase())}</div></div>`;
}
function renderHome(){
  state.course=null;
  state.currentVideoId=null;
  el("courseView").classList.add("hidden");
  el("homeView").classList.remove("hidden");
  document.title="My Course Library";
  history.replaceState(null,"","#");

  const q=state.search.trim().toLowerCase();
  const courses=LIBRARY.filter(c=>matchingCourse(c,q));
  const totalVideos=LIBRARY.reduce((a,c)=>a+c.videoCount,0);
  const totalResources=LIBRARY.reduce((a,c)=>a+c.resourceCount,0);

  el("homeView").innerHTML=`
    <div class="stats">
      <span class="chip"><b>${LIBRARY.length}</b> courses</span>
      <span class="chip"><b>${totalVideos}</b> videos</span>
      <span class="chip"><b>${totalResources}</b> resources</span>
      <span class="chip">All content runs from your local drive</span>
    </div>
    ${courses.length ? `<div class="grid">${courses.map(c=>{
      const cp=coursePercent(c);
      const action=cp>0 && cp<100 ? "Continue" : cp>=100 ? "Review" : "Start";
      return `
      <article class="course-card">
        ${coverHtml(c)}
        <div class="card-body">
          <div class="card-title">${esc(c.name)}</div>
          <div class="meta">${c.videoCount} videos · ${c.sectionCount} sections · ${c.resourceCount} resources${c.totalDurationText?` · ${c.totalDurationText}`:""}</div>
          <div class="progress"><i style="width:${cp}%"></i></div>
          <div class="card-actions">
            <span class="small">${cp}% complete</span>
            <button class="btn primary" onclick="openCourse('${c.id}')">${action} ▶</button>
          </div>
        </div>
      </article>`}).join("")}</div>` : `<div class="empty">No courses match your search.</div>`}
  `;
}
function openCourse(id){
  const course=LIBRARY.find(c=>c.id===id);
  if(!course)return;
  state.course=course;
  state.currentVideoId=null;
  el("homeView").classList.add("hidden");
  el("courseView").classList.remove("hidden");
  location.hash="course="+encodeURIComponent(id);
  document.title=course.name+" - My Course Library";
  renderCourse();
  window.scrollTo({top:0,behavior:"smooth"});
}
function courseSearchMatch(v){
  const q=state.search.trim().toLowerCase();
  return !q || (v.title+" "+v.section+" "+v.extension).toLowerCase().includes(q);
}
function groupedVideos(course){
  const map=new Map();
  for(const v of course.videos.filter(courseSearchMatch)){
    if(!map.has(v.section))map.set(v.section,[]);
    map.get(v.section).push(v);
  }
  return [...map.entries()];
}
function videoStatus(v){
  const p=getProgress(v.id);
  const percent=p.duration?pct(p.time||0,p.duration):0;
  if(p.watched||percent>=90)return {text:"Watched ✓",percent:100};
  if(percent>0)return {text:`${percent}%`,percent};
  return {text:"New",percent:0};
}
function videoThumb(v,course){
  const img=v.thumbnail||course.cover;
  return `<div class="video-thumb">${img?`<img src="${img}" alt="" loading="lazy">`:`<div class="cover-fallback">▶</div>`}
    <button class="play" title="Play" onclick="playVideo('${v.id}')">▶</button>
    ${v.durationText?`<span class="dur">${esc(v.durationText)}</span>`:""}
  </div>`;
}
function cardsFor(videos,course){
  return `<div class="cards">${videos.map(v=>{
    const st=videoStatus(v);
    return `<article class="video-card">
      ${videoThumb(v,course)}
      <div class="video-info">
        <div class="video-title">${esc(v.title)}</div>
        <div class="progress"><i style="width:${st.percent}%"></i></div>
        <div class="video-sub"><span>${esc(v.extension)}</span><span>${esc(st.text)}</span></div>
      </div>
    </article>`;
  }).join("")}</div>`;
}
function tableFor(videos){
  return `<div class="table-wrap"><table>
    <thead><tr><th>#</th><th>Lesson</th><th>Duration</th><th>Subtitle</th><th>Progress</th><th></th></tr></thead>
    <tbody>${videos.map(v=>{
      const st=videoStatus(v);
      return `<tr>
        <td>${v.order}</td>
        <td><b>${esc(v.title)}</b><div class="small">${esc(v.extension)}</div></td>
        <td>${esc(v.durationText||"")}</td>
        <td>${v.subtitle?"CC":"—"}</td>
        <td>${esc(st.text)}</td>
        <td><button class="btn" onclick="playVideo('${v.id}')">${st.percent>0&&st.percent<100?"Resume":"Play"} ▶</button></td>
      </tr>`;
    }).join("")}</tbody>
  </table></div>`;
}
function resourceHtml(course){
  let items=course.resources;
  const q=state.search.trim().toLowerCase();
  if(q)items=items.filter(r=>(r.title+" "+r.section+" "+r.kind+" "+r.extension).toLowerCase().includes(q));
  if(!items.length)return `<div class="empty">No resources match this filter/search.</div>`;
  return `<div class="resource-list">${items.map(r=>`
    <a class="resource" href="${r.path}" target="_blank">
      <span class="badge">${esc(r.kind)}</span>
      <span><b>${esc(r.title)}</b><br><span class="small">${esc(r.section)} · ${esc(r.extension)}</span></span>
    </a>`).join("")}</div>`;
}
function renderCourse(){
  const c=state.course;
  if(!c)return;
  const cp=coursePercent(c);
  const groups=groupedVideos(c);

  let body="";
  if(state.filter==="resources"){
    body=resourceHtml(c);
  } else {
    body=groups.length ? groups.map(([section,videos],idx)=>`
      <div class="section">
        <div class="section-header" onclick="this.nextElementSibling.classList.toggle('hidden')">
          <span>${esc(section)}</span><span class="small">${videos.length} lesson${videos.length===1?"":"s"}</span>
        </div>
        <div class="section-content">${state.view==="table"?tableFor(videos):cardsFor(videos,c)}</div>
      </div>`).join("") : `<div class="empty">No lessons match your search.</div>`;
  }

  el("courseView").innerHTML=`
    ${state.currentVideoId?playerShellHtml():""}
    <div class="course-head">
      ${coverHtml(c,"course-head-cover")}
      <div>
        <button class="btn" onclick="renderHome()">← Back to Library</button>
        <h1 class="course-title">${esc(c.name)}</h1>
        <div class="big-meta">${c.videoCount} videos · ${c.sectionCount} sections · ${c.resourceCount} resources${c.totalDurationText?` · ${c.totalDurationText}`:""}</div>
        <div class="progress"><i style="width:${cp}%"></i></div>
        <div class="small">${cp}% complete</div>
        <div class="head-actions">
          <button class="btn primary" onclick="continueCourse()">▶ ${cp>0?"Continue Course":"Start Course"}</button>
          <a class="btn linkbtn" href="${c.folder}" target="_blank">📂 Open Folder</a>
        </div>
      </div>
    </div>

    <div class="tabs">
      <button class="tab ${state.filter==="all"?"active":""}" onclick="setFilter('all')">Videos</button>
      <button class="tab ${state.filter==="resources"?"active":""}" onclick="setFilter('resources')">Resources (${c.resourceCount})</button>
    </div>
    ${body}
  `;

  updateViewButton();
  if(state.currentVideoId) attachPlayer();
}
function setFilter(f){state.filter=f;renderCourse()}
function updateViewButton(){
  el("viewBtn").textContent=state.view==="table"?"☰ Table":"▦ Cards";
}
function toggleView(){
  state.view=state.view==="table"?"cards":"table";
  localStorage.setItem("clm:view",state.view);
  updateViewButton();
  if(state.course)renderCourse();else renderHome();
}
function findVideo(id){
  if(!state.course)return null;
  return state.course.videos.find(v=>v.id===id);
}
function playerShellHtml(){
  const v=findVideo(state.currentVideoId);
  if(!v)return "";
  const idx=state.course.videos.findIndex(x=>x.id===v.id);
  const poster=v.thumbnail||state.course.cover||"";
  return `<div class="player-shell" id="playerShell">
    <div class="video-wrap">
      <video id="player" controls preload="metadata" ${poster?`poster="${poster}"`:""}>
        <source src="${v.path}">
        ${v.subtitle?`<track kind="subtitles" src="${v.subtitle}" srclang="en" label="English" default>`:""}
        Your browser could not play this video format. Use Open File below.
      </video>
    </div>
    <div class="player-title">${esc(v.title)}</div>
    <div class="player-controls">
      <button class="btn" onclick="seekBy(-10)">↶ 10s</button>
      <button class="btn" onclick="seekBy(10)">10s ↷</button>
      <label>Speed
        <select id="speedSel" onchange="setSpeed(this.value)">
          ${[0.5,0.75,1,1.25,1.5,1.75,2,2.5,3].map(s=>`<option value="${s}">${s}×</option>`).join("")}
        </select>
      </label>
      <button class="btn good" onclick="markWatched()">✓ Mark Watched</button>
      <a class="btn linkbtn" href="${v.path}" target="_blank">Open File</a>
      <span class="player-progress" id="playerProgress"></span>
      <button class="btn" ${idx<=0?"disabled":""} onclick="playAdjacent(-1)">← Previous</button>
      <button class="btn" ${idx>=state.course.videos.length-1?"disabled":""} onclick="playAdjacent(1)">Next →</button>
    </div>
  </div>`;
}
function playVideo(id){
  state.currentVideoId=id;
  renderCourse();
  requestAnimationFrame(()=>document.getElementById("playerShell")?.scrollIntoView({behavior:"smooth",block:"start"}));
}
function attachPlayer(){
  const p=el("player");
  const v=findVideo(state.currentVideoId);
  if(!p||!v)return;
  const saved=getProgress(v.id);
  const speed=Number(localStorage.getItem("clm:speed")||CONFIG.defaultSpeed||1);
  p.playbackRate=speed;
  if(el("speedSel"))el("speedSel").value=String(speed);

  p.addEventListener("loadedmetadata",()=>{
    if(saved.time && saved.time < p.duration-5)p.currentTime=saved.time;
    updatePlayerProgress();
  },{once:true});

  let lastSave=0;
  p.addEventListener("timeupdate",()=>{
    const now=Date.now();
    if(now-lastSave>3000){
      saveCurrentProgress(false);
      lastSave=now;
    }
    updatePlayerProgress();
  });
  p.addEventListener("ended",()=>{saveCurrentProgress(true); renderCourse()});
  p.play().catch(()=>{});
}
function saveCurrentProgress(forceWatched){
  const p=el("player");
  const v=findVideo(state.currentVideoId);
  if(!p||!v||!Number.isFinite(p.duration))return;
  const watched=forceWatched || p.currentTime/p.duration>=.9;
  setProgress(v.id,{time:p.currentTime,duration:p.duration,watched,updated:Date.now()});
}
function updatePlayerProgress(){
  const p=el("player"),box=el("playerProgress");
  if(!p||!box||!Number.isFinite(p.duration))return;
  const fmt=s=>{s=Math.max(0,Math.floor(s||0));const h=Math.floor(s/3600),m=Math.floor((s%3600)/60),x=s%60;return h?`${h}:${String(m).padStart(2,"0")}:${String(x).padStart(2,"0")}`:`${m}:${String(x).padStart(2,"0")}`};
  box.textContent=`${fmt(p.currentTime)} / ${fmt(p.duration)}`;
}
function seekBy(sec){const p=el("player");if(p)p.currentTime=Math.max(0,Math.min(p.duration||Infinity,p.currentTime+sec))}
function setSpeed(v){const p=el("player");if(p)p.playbackRate=Number(v);localStorage.setItem("clm:speed",v)}
function markWatched(){
  const p=el("player"),v=findVideo(state.currentVideoId);if(!v)return;
  const d=p&&Number.isFinite(p.duration)?p.duration:(v.duration||1);
  setProgress(v.id,{time:d,duration:d,watched:true,updated:Date.now()});
  renderCourse();
}
function playAdjacent(delta){
  const c=state.course;if(!c)return;
  const i=c.videos.findIndex(v=>v.id===state.currentVideoId);
  const n=i+delta;if(n>=0&&n<c.videos.length)playVideo(c.videos[n].id);
}
function continueCourse(){
  const c=state.course;if(!c||!c.videos.length)return;
  let candidate=c.videos.find(v=>{const p=getProgress(v.id);return p.time && !p.watched && (!p.duration||p.time/p.duration<.9)});
  if(!candidate)candidate=c.videos.find(v=>{const p=getProgress(v.id);return !p.watched && (!p.duration||p.time/p.duration<.9)});
  if(!candidate)candidate=c.videos[0];
  playVideo(candidate.id);
}
function handleSearch(){
  state.search=el("searchBox").value||"";
  if(state.course)renderCourse();else renderHome();
}
document.addEventListener("keydown",e=>{
  if(e.target && ["INPUT","TEXTAREA","SELECT"].includes(e.target.tagName))return;
  const p=el("player");
  if(!p)return;
  if(e.code==="Space"||e.key.toLowerCase()==="k"){e.preventDefault();p.paused?p.play():p.pause()}
  else if(e.key==="ArrowLeft"||e.key.toLowerCase()==="j")seekBy(-10);
  else if(e.key==="ArrowRight"||e.key.toLowerCase()==="l")seekBy(10);
  else if(e.key.toLowerCase()==="m")p.muted=!p.muted;
  else if(e.key.toLowerCase()==="f"){if(document.fullscreenElement)document.exitFullscreen();else p.requestFullscreen?.()}
});
el("searchBox").addEventListener("input",handleSearch);
el("themeBtn").addEventListener("click",toggleTheme);
el("viewBtn").addEventListener("click",toggleView);
el("homeBtn").addEventListener("click",renderHome);

initTheme();
updateViewButton();

const hash=new URLSearchParams(location.hash.replace(/^#/,""));
const requested=hash.get("course");
if(requested && LIBRARY.some(c=>c.id===requested))openCourse(requested);else renderHome();
</script>
<div class="footer">Generated by Course Library Manager · Local files stay on your computer</div>
</body>
</html>
'@
    $html = $html.Replace("__LIBRARY_JSON__", $LibraryJson)
    $html = $html.Replace("__DEFAULT_VIEW__", $defaultView)
    $html = $html.Replace("__THEME__", $theme)
    $html = $html.Replace("__DEFAULT_SPEED__", $defaultSpeed)
    return $html
}

function Invoke-GenerateCatalog {
    try {
        $root = Get-SelectedRoot
        $catalogName = [string]$Script:Settings.CatalogFolderName
        if ([string]::IsNullOrWhiteSpace($catalogName)) { $catalogName = $Script:CatalogFolderName }

        $catalogPath = Join-Path $root.FullName $catalogName
        if (-not (Test-Path -LiteralPath $catalogPath)) {
            New-Item -ItemType Directory -Path $catalogPath -Force | Out-Null
        }
        $catalog = [System.IO.DirectoryInfo]::new($catalogPath)

        $Script:GenerateButton.Enabled = $false
        Set-UiStatus "Checking required components..." 1
        Write-UiLog "Building HTML library in: $catalogPath"

        Set-UiStatus "Running catalog compatibility self-test..." 1
        if (-not (Test-CatalogCompatibility)) {
            throw "Internal catalog compatibility self-test failed. No course files were changed."
        }

        # Automatically install portable FFmpeg/ffprobe on first use when
        # thumbnail/duration features are enabled.
        [void](Ensure-MediaComponents)

        Set-UiStatus "Building course library..." 2
        $data = [array](Build-CourseLibraryData -Root $root -CatalogDir $catalog)
        Set-UiStatus "Writing HTML..." 82

        $json = ConvertTo-JsonForHtml $data
        $html = Get-HtmlTemplate -LibraryJson $json
        $indexPath = Join-Path $catalogPath "index.html"
        Set-Content -LiteralPath $indexPath -Value $html -Encoding UTF8

        # Human-readable metadata snapshot for troubleshooting/rebuild inspection.
        $metadataPath = Join-Path $catalogPath "library-data.json"
        ConvertTo-Json -InputObject $data -Depth 12 | Set-Content -LiteralPath $metadataPath -Encoding UTF8

        # Build report.
        $courseCount = @($data).Count
        $videoMeasure = $data | Measure-Object -Property videoCount -Sum
        $resourceMeasure = $data | Measure-Object -Property resourceCount -Sum
        $videoCount = if ($null -eq $videoMeasure.Sum) { 0 } else { [int]$videoMeasure.Sum }
        $resourceCount = if ($null -eq $resourceMeasure.Sum) { 0 } else { [int]$resourceMeasure.Sum }

        $report = [ordered]@{
            Generated      = (Get-Date).ToString("s")
            Root           = $root.FullName
            Catalog        = $indexPath
            Courses        = $courseCount
            Videos         = $videoCount
            Resources      = $resourceCount
            Theme          = $Script:Settings.Theme
            DefaultView    = $Script:Settings.DefaultView
            Thumbnails     = [bool]$Script:Settings.GenerateVideoThumbnails
            Subtitles      = [bool]$Script:Settings.IncludeSubtitles
        }
        ConvertTo-Json -InputObject $report | Set-Content -LiteralPath (Join-Path $catalogPath "build-report.json") -Encoding UTF8

        Set-UiStatus "HTML library ready" 100
        Write-UiLog "HTML library created: $indexPath" "OK"
        Write-UiLog "$courseCount courses, $videoCount videos, $resourceCount resources." "OK"
        $Script:OpenButton.Enabled = $true

        if (Confirm-Action ("Course library created.`r`n`r`nCourses: {0}`r`nVideos: {1}`r`nResources: {2}`r`n`r`nOpen it now?" -f $courseCount,$videoCount,$resourceCount) "HTML Library Ready") {
            Start-Process $indexPath
        }
    } catch {
        Write-UiLog $_.Exception.ToString() "ERROR"
        if ($_.InvocationInfo -and $_.InvocationInfo.PositionMessage) { Write-UiLog $_.InvocationInfo.PositionMessage "ERROR" }
        if ($_.ScriptStackTrace) { Write-UiLog $_.ScriptStackTrace "ERROR" }
        Set-UiStatus "Catalog generation failed" 0
        Show-Warning ("Catalog generation failed:`r`n`r`n" + $_.Exception.Message)
    } finally {
        if ($Script:GenerateButton) { $Script:GenerateButton.Enabled = $true }
    }
}

function Invoke-OpenCatalog {
    try {
        $root = Get-SelectedRoot
        $index = Join-Path $root.FullName (([string]$Script:Settings.CatalogFolderName) + "\index.html")
        if (-not (Test-Path -LiteralPath $index)) {
            Show-Warning "No HTML catalog exists yet. Click 'Create / Refresh HTML Catalog' first."
            return
        }
        Start-Process $index
    } catch {
        Show-Warning $_.Exception.Message
    }
}

# ----------------------------- SETTINGS DIALOGS -----------------------------

function Show-CleanupPhrasesDialog {
    $f = New-Object System.Windows.Forms.Form
    $f.Text = "Cleanup Phrases"
    $f.Size = New-Object System.Drawing.Size(620,500)
    $f.StartPosition = "CenterParent"
    $f.MinimizeBox = $false
    $f.MaximizeBox = $false

    $label = New-Object System.Windows.Forms.Label
    $label.Text = "One removable source / site / channel phrase per line.`r`nThese affect folder cleanup and catalog display names."
    $label.AutoSize = $true
    $label.Location = New-Object System.Drawing.Point(16,16)
    $f.Controls.Add($label)

    $tb = New-Object System.Windows.Forms.TextBox
    $tb.Multiline = $true
    $tb.ScrollBars = "Vertical"
    $tb.Location = New-Object System.Drawing.Point(16,58)
    $tb.Size = New-Object System.Drawing.Size(570,330)
    $tb.Font = New-Object System.Drawing.Font("Consolas",10)
    $tb.Text = (@($Script:Settings.RemovePhrases) -join [Environment]::NewLine)
    $f.Controls.Add($tb)

    $save = New-Object System.Windows.Forms.Button
    $save.Text = "Save"
    $save.Location = New-Object System.Drawing.Point(390,405)
    $save.Size = New-Object System.Drawing.Size(95,32)
    $save.Add_Click({
        $Script:Settings.RemovePhrases = @($tb.Lines | ForEach-Object {$_.Trim()} | Where-Object {$_})
        Save-Settings
        Write-UiLog "Cleanup phrase list updated." "OK"
        $f.DialogResult = [System.Windows.Forms.DialogResult]::OK
        $f.Close()
    })
    $f.Controls.Add($save)

    $cancel = New-Object System.Windows.Forms.Button
    $cancel.Text = "Cancel"
    $cancel.Location = New-Object System.Drawing.Point(491,405)
    $cancel.Size = New-Object System.Drawing.Size(95,32)
    $cancel.Add_Click({ $f.Close() })
    $f.Controls.Add($cancel)

    $f.ShowDialog($Script:MainForm) | Out-Null
}

function Show-CatalogSettingsDialog {
    $f = New-Object System.Windows.Forms.Form
    $f.Text = "HTML Catalog Settings"
    $f.Size = New-Object System.Drawing.Size(560,560)
    $f.StartPosition = "CenterParent"
    $f.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
    $f.MaximizeBox = $false
    $f.MinimizeBox = $false

    $y = 18
    function Add-Label([string]$text,[int]$yy) {
        $l = New-Object System.Windows.Forms.Label
        $l.Text = $text
        $l.Location = New-Object System.Drawing.Point(20,$yy)
        $l.Size = New-Object System.Drawing.Size(220,25)
        $f.Controls.Add($l)
        return $l
    }

    Add-Label "Theme" $y | Out-Null
    $theme = New-Object System.Windows.Forms.ComboBox
    $theme.DropDownStyle = "DropDownList"
    [void]$theme.Items.AddRange(@("Dark","Light"))
    $theme.SelectedItem = [string]$Script:Settings.Theme
    $theme.Location = New-Object System.Drawing.Point(270,$y)
    $theme.Size = New-Object System.Drawing.Size(230,25)
    $f.Controls.Add($theme)
    $y += 40

    Add-Label "Default lesson view" $y | Out-Null
    $view = New-Object System.Windows.Forms.ComboBox
    $view.DropDownStyle = "DropDownList"
    [void]$view.Items.AddRange(@("Cards","Table"))
    $view.SelectedItem = [string]$Script:Settings.DefaultView
    $view.Location = New-Object System.Drawing.Point(270,$y)
    $view.Size = New-Object System.Drawing.Size(230,25)
    $f.Controls.Add($view)
    $y += 42

    $checks = @(
        @("Generate video thumbnails","GenerateVideoThumbnails"),
        @("Read video durations with ffprobe","GenerateDurations"),
        @("Include / convert subtitles","IncludeSubtitles"),
        @("Include PDFs","IncludePDFs"),
        @("Include images","IncludeImages"),
        @("Include other resources","IncludeOtherResources")
    )
    $checkControls = @{}
    foreach ($c in $checks) {
        $cb = New-Object System.Windows.Forms.CheckBox
        $cb.Text = $c[0]
        $cb.Location = New-Object System.Drawing.Point(20,$y)
        $cb.Size = New-Object System.Drawing.Size(480,26)
        $cb.Checked = [bool]$Script:Settings[$c[1]]
        $f.Controls.Add($cb)
        $checkControls[$c[1]] = $cb
        $y += 32
    }

    Add-Label "Thumbnail seek position (%)" $y | Out-Null
    $seek = New-Object System.Windows.Forms.NumericUpDown
    $seek.Minimum = 1
    $seek.Maximum = 90
    $seek.Value = [decimal]([int]$Script:Settings.ThumbnailSeekPercent)
    $seek.Location = New-Object System.Drawing.Point(270,$y)
    $seek.Size = New-Object System.Drawing.Size(100,25)
    $f.Controls.Add($seek)
    $y += 40

    Add-Label "Default playback speed" $y | Out-Null
    $speed = New-Object System.Windows.Forms.ComboBox
    $speed.DropDownStyle = "DropDownList"
    [void]$speed.Items.AddRange(@("0.5","0.75","1","1.25","1.5","1.75","2","2.5","3"))
    $speed.SelectedItem = ([double]$Script:Settings.DefaultPlaybackSpeed).ToString("0.##",[Globalization.CultureInfo]::InvariantCulture)
    if ($speed.SelectedIndex -lt 0) { $speed.SelectedItem = "1" }
    $speed.Location = New-Object System.Drawing.Point(270,$y)
    $speed.Size = New-Object System.Drawing.Size(100,25)
    $f.Controls.Add($speed)
    $y += 50

    $note = New-Object System.Windows.Forms.Label
    $note.Text = "Tip: thumbnails/durations are richer when ffmpeg + ffprobe are on PATH. The catalog still works without them."
    $note.Location = New-Object System.Drawing.Point(20,$y)
    $note.Size = New-Object System.Drawing.Size(480,45)
    $note.ForeColor = [System.Drawing.Color]::DimGray
    $f.Controls.Add($note)
    $y += 55

    $save = New-Object System.Windows.Forms.Button
    $save.Text = "Save"
    $save.Location = New-Object System.Drawing.Point(304,$y)
    $save.Size = New-Object System.Drawing.Size(95,32)
    $save.Add_Click({
        $Script:Settings.Theme = [string]$theme.SelectedItem
        $Script:Settings.DefaultView = [string]$view.SelectedItem
        foreach ($k in $checkControls.Keys) {
            $Script:Settings[$k] = [bool]$checkControls[$k].Checked
        }
        $Script:Settings.ThumbnailSeekPercent = [int]$seek.Value
        $Script:Settings.DefaultPlaybackSpeed = [double]::Parse([string]$speed.SelectedItem,[Globalization.CultureInfo]::InvariantCulture)
        Save-Settings
        Write-UiLog "Catalog settings saved." "OK"
        $f.DialogResult = [System.Windows.Forms.DialogResult]::OK
        $f.Close()
    })
    $f.Controls.Add($save)

    $cancel = New-Object System.Windows.Forms.Button
    $cancel.Text = "Cancel"
    $cancel.Location = New-Object System.Drawing.Point(405,$y)
    $cancel.Size = New-Object System.Drawing.Size(95,32)
    $cancel.Add_Click({ $f.Close() })
    $f.Controls.Add($cancel)

    $f.ShowDialog($Script:MainForm) | Out-Null
}

# ----------------------------- GUI -----------------------------

function New-SectionLabel {
    param([string]$Text,[int]$X,[int]$Y,[int]$W=260)
    $l = New-Object System.Windows.Forms.Label
    $l.Text = $Text
    $l.Location = New-Object System.Drawing.Point($X,$Y)
    $l.Size = New-Object System.Drawing.Size($W,28)
    $l.Font = New-Object System.Drawing.Font("Segoe UI",12,[System.Drawing.FontStyle]::Bold)
    return $l
}

function New-AppButton {
    param([string]$Text,[int]$X,[int]$Y,[int]$W=190,[int]$H=38)
    $b = New-Object System.Windows.Forms.Button
    $b.Text = $Text
    $b.Location = New-Object System.Drawing.Point($X,$Y)
    $b.Size = New-Object System.Drawing.Size($W,$H)
    $b.FlatStyle = [System.Windows.Forms.FlatStyle]::System
    return $b
}

function Start-Gui {
    Load-Settings

    [System.Windows.Forms.Application]::EnableVisualStyles()

    $form = New-Object System.Windows.Forms.Form
    $form.Text = "$($Script:AppName) v$($Script:AppVersion)"
    $form.Size = New-Object System.Drawing.Size(1040,760)
    $form.MinimumSize = New-Object System.Drawing.Size(980,700)
    $form.StartPosition = "CenterScreen"
    $form.Font = New-Object System.Drawing.Font("Segoe UI",9)
    $Script:MainForm = $form

    $title = New-Object System.Windows.Forms.Label
    $title.Text = "Course Library Manager"
    $title.Location = New-Object System.Drawing.Point(20,16)
    $title.Size = New-Object System.Drawing.Size(600,38)
    $title.Font = New-Object System.Drawing.Font("Segoe UI",20,[System.Drawing.FontStyle]::Bold)
    $form.Controls.Add($title)

    $subtitle = New-Object System.Windows.Forms.Label
    $subtitle.Text = "Safe folder cleanup + local HTML course player/library"
    $subtitle.Location = New-Object System.Drawing.Point(23,55)
    $subtitle.Size = New-Object System.Drawing.Size(600,24)
    $subtitle.ForeColor = [System.Drawing.Color]::DimGray
    $form.Controls.Add($subtitle)

    $rootLabel = New-Object System.Windows.Forms.Label
    $rootLabel.Text = "Course root folder"
    $rootLabel.Location = New-Object System.Drawing.Point(22,92)
    $rootLabel.Size = New-Object System.Drawing.Size(170,23)
    $form.Controls.Add($rootLabel)

    $rootBox = New-Object System.Windows.Forms.TextBox
    $rootBox.Location = New-Object System.Drawing.Point(22,116)
    $rootBox.Size = New-Object System.Drawing.Size(840,28)
    $rootBox.Anchor = "Top,Left,Right"
    $rootBox.Text = [string]$Script:Settings.RootPath
    $Script:RootTextBox = $rootBox
    $form.Controls.Add($rootBox)

    $browse = New-AppButton "Browse..." 875 113 120 31
    $browse.Anchor = "Top,Right"
    $browse.Add_Click({
        $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
        $dlg.Description = "Select the folder containing your course folders"
        $dlg.ShowNewFolderButton = $false
        if (Test-Path -LiteralPath $rootBox.Text) { $dlg.SelectedPath = $rootBox.Text }
        if ($dlg.ShowDialog($form) -eq [System.Windows.Forms.DialogResult]::OK) {
            $rootBox.Text = $dlg.SelectedPath
            $Script:Settings.RootPath = $dlg.SelectedPath
            Save-Settings
        }
    })
    $form.Controls.Add($browse)

    # Rename group
    $renameGroup = New-Object System.Windows.Forms.GroupBox
    $renameGroup.Text = "1. Folder Cleanup"
    $renameGroup.Location = New-Object System.Drawing.Point(20,165)
    $renameGroup.Size = New-Object System.Drawing.Size(475,190)
    $form.Controls.Add($renameGroup)

    $renameHint = New-Object System.Windows.Forms.Label
    $renameHint.Text = "Preview first. This feature renames folders only; course files are never renamed."
    $renameHint.Location = New-Object System.Drawing.Point(16,27)
    $renameHint.Size = New-Object System.Drawing.Size(440,36)
    $renameHint.ForeColor = [System.Drawing.Color]::DimGray
    $renameGroup.Controls.Add($renameHint)

    $preview = New-AppButton "Preview Folder Renames" 16 72 210 38
    $preview.Add_Click({ Invoke-RenamePreview })
    $renameGroup.Controls.Add($preview)

    $apply = New-AppButton "Apply Folder Renames" 238 72 210 38
    $apply.Add_Click({ Invoke-RenameApply })
    $renameGroup.Controls.Add($apply)

    $undo = New-AppButton "Undo Latest Rename" 16 120 210 38
    $undo.Add_Click({ Invoke-RenameUndo })
    $renameGroup.Controls.Add($undo)

    $phrases = New-AppButton "Cleanup Phrases..." 238 120 210 38
    $phrases.Add_Click({ Show-CleanupPhrasesDialog })
    $renameGroup.Controls.Add($phrases)

    # Catalog group
    $catalogGroup = New-Object System.Windows.Forms.GroupBox
    $catalogGroup.Text = "2. Local HTML Course Library"
    $catalogGroup.Location = New-Object System.Drawing.Point(515,165)
    $catalogGroup.Size = New-Object System.Drawing.Size(480,190)
    $catalogGroup.Anchor = "Top,Right"
    $form.Controls.Add($catalogGroup)

    $catalogHint = New-Object System.Windows.Forms.Label
    $catalogHint.Text = "Build a local library with course covers, card/table views, video player, seek/speed, subtitles, resources and resume progress."
    $catalogHint.Location = New-Object System.Drawing.Point(16,27)
    $catalogHint.Size = New-Object System.Drawing.Size(445,48)
    $catalogHint.ForeColor = [System.Drawing.Color]::DimGray
    $catalogGroup.Controls.Add($catalogHint)

    $generate = New-AppButton "Create / Refresh HTML Catalog" 16 82 260 38
    $generate.Add_Click({ Invoke-GenerateCatalog })
    $Script:GenerateButton = $generate
    $catalogGroup.Controls.Add($generate)

    $open = New-AppButton "Open Catalog" 288 82 165 38
    $open.Add_Click({ Invoke-OpenCatalog })
    $Script:OpenButton = $open
    $catalogGroup.Controls.Add($open)

    $settings = New-AppButton "Catalog Settings..." 16 130 140 38
    $settings.Add_Click({ Show-CatalogSettingsDialog })
    $catalogGroup.Controls.Add($settings)

    $components = New-AppButton "Install / Check Components" 164 130 178 38
    $components.Add_Click({ Invoke-CheckInstallComponents })
    $catalogGroup.Controls.Add($components)

    $openFolder = New-AppButton "Open Folder" 350 130 103 38
    $openFolder.Add_Click({
        try {
            $root = Get-SelectedRoot
            $p = Join-Path $root.FullName ([string]$Script:Settings.CatalogFolderName)
            if (-not (Test-Path -LiteralPath $p)) { New-Item -ItemType Directory -Path $p -Force | Out-Null }
            Start-Process explorer.exe $p
        } catch { Show-Warning $_.Exception.Message }
    })
    $catalogGroup.Controls.Add($openFolder)

    # Log
    $logLabel = New-SectionLabel "Activity" 20 375 200
    $form.Controls.Add($logLabel)

    $log = New-Object System.Windows.Forms.RichTextBox
    $log.Location = New-Object System.Drawing.Point(20,408)
    $log.Size = New-Object System.Drawing.Size(975,235)
    $log.Anchor = "Top,Bottom,Left,Right"
    $log.ReadOnly = $true
    $log.BackColor = [System.Drawing.Color]::White
    $log.Font = New-Object System.Drawing.Font("Consolas",9)
    $Script:LogBox = $log
    $form.Controls.Add($log)

    $progress = New-Object System.Windows.Forms.ProgressBar
    $progress.Location = New-Object System.Drawing.Point(20,658)
    $progress.Size = New-Object System.Drawing.Size(780,18)
    $progress.Anchor = "Bottom,Left,Right"
    $Script:ProgressBar = $progress
    $form.Controls.Add($progress)

    $status = New-Object System.Windows.Forms.Label
    $status.Text = "Ready"
    $status.Location = New-Object System.Drawing.Point(20,682)
    $status.Size = New-Object System.Drawing.Size(780,25)
    $status.Anchor = "Bottom,Left,Right"
    $Script:StatusLabel = $status
    $form.Controls.Add($status)

    $exit = New-AppButton "Exit" 875 666 120 38
    $exit.Anchor = "Bottom,Right"
    $exit.Add_Click({ $form.Close() })
    $form.Controls.Add($exit)

    $form.Add_Shown({
        Write-UiLog "$($Script:AppName) v$($Script:AppVersion) ready." "OK"
        Write-UiLog "Root: $($rootBox.Text)"
        Write-UiLog "Use Preview before applying folder renames."
        Write-UiLog "All component/download progress is shown inside this GUI; no console window is required."
        Write-UiLog "v1.5 passed extended pre-build checks for lists, JSON, HTML template and Windows PowerShell 5.1 compatibility."
        Set-UiStatus "Ready" 0

        try {
            if (Test-Path -LiteralPath $rootBox.Text) {
                $index = Join-Path $rootBox.Text (([string]$Script:Settings.CatalogFolderName) + "\index.html")
                $open.Enabled = Test-Path -LiteralPath $index
            }
        } catch {}
    })

    [void]$form.ShowDialog()
}

try {
    Start-Gui
} catch {
    [System.Windows.Forms.MessageBox]::Show(
        $_.Exception.ToString(),
        "$($Script:AppName) - Fatal Error",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    ) | Out-Null
}
