# Nested Archive Extractor GUI v3
# ------------------------------------------------------------
# Beginner summary:
# This Windows PowerShell tool extracts an archive, checks the
# files that came out of it, and if one of those files is itself
# another archive, extracts that too. It repeats this until the
# final normal files are reached or the selected depth limit is hit.
#
# Originals are never deleted or changed.
# Requirement: Windows PowerShell 5.1+ and 7z.exe or 7zz.exe.

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

# ----- Locate the 7-Zip command-line program automatically -----
function Find-7Zip {
    foreach ($p in @(
        (Join-Path $env:ProgramFiles '7-Zip\7z.exe'),
        (Join-Path $env:LOCALAPPDATA '7-Zip\7z.exe'),
        (Join-Path $PSScriptRoot '7z.exe'),
        (Join-Path $PSScriptRoot '7zz.exe')
    )) {
        if ($p -and (Test-Path -LiteralPath $p -PathType Leaf)) { return $p }
    }
    foreach ($n in @('7z.exe','7zz.exe')) {
        $c = Get-Command $n -ErrorAction SilentlyContinue
        if ($c) { return $c.Source }
    }
    return ''
}

# ----- GUI -----
$form = New-Object Windows.Forms.Form
$form.Text = 'Nested Archive Extractor v3'
$form.Size = New-Object Drawing.Size(1050,760)
$form.StartPosition = 'CenterScreen'
$form.Font = New-Object Drawing.Font('Segoe UI',9)

function Label($t,$x,$y,$w) {
    $c = New-Object Windows.Forms.Label
    $c.Text=$t; $c.Location=New-Object Drawing.Point($x,$y)
    $c.Size=New-Object Drawing.Size($w,24); $form.Controls.Add($c); return $c
}
function Button($t,$x,$y,$w) {
    $c = New-Object Windows.Forms.Button
    $c.Text=$t; $c.Location=New-Object Drawing.Point($x,$y)
    $c.Size=New-Object Drawing.Size($w,31); $form.Controls.Add($c); return $c
}
function Box($x,$y,$w) {
    $c = New-Object Windows.Forms.TextBox
    $c.Location=New-Object Drawing.Point($x,$y)
    $c.Size=New-Object Drawing.Size($w,26); $form.Controls.Add($c); return $c
}

$h=Label 'Extract archives inside archives automatically' 20 15 800
$h.Font=New-Object Drawing.Font('Segoe UI',13,[Drawing.FontStyle]::Bold)
[void](Label 'Add files/folders or paste one full path per line. Original archives stay untouched.' 20 48 940)

[void](Label 'INPUT FILES / FOLDERS' 20 80 300)
$input=New-Object Windows.Forms.TextBox
$input.Multiline=$true; $input.ScrollBars='Both'; $input.WordWrap=$false
$input.Location=New-Object Drawing.Point(20,106); $input.Size=New-Object Drawing.Size(790,112)
$form.Controls.Add($input)

$addFiles=Button 'Add files...' 825 106 185
$addFolder=Button 'Add folder...' 825 145 185
$clearPaths=Button 'Clear paths' 825 184 185

[void](Label 'OUTPUT FOLDER' 20 233 200)
$output=Box 20 258 790
$output.Text=Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'Extracted_Nested_Archives'
$browseOutput=Button 'Browse...' 825 256 185

[void](Label '7-ZIP EXECUTABLE' 20 297 250)
$seven=Box 20 322 790
$seven.Text=Find-7Zip
$browseSeven=Button 'Browse 7z.exe...' 825 320 185

$recursive=New-Object Windows.Forms.CheckBox
$recursive.Text='Include subfolders when input is a folder'
$recursive.Checked=$true; $recursive.Location=New-Object Drawing.Point(20,360)
$recursive.Size=New-Object Drawing.Size(350,25); $form.Controls.Add($recursive)

[void](Label 'Maximum archive nesting:' 430 363 180)
$depth=New-Object Windows.Forms.NumericUpDown
$depth.Location=New-Object Drawing.Point(615,360); $depth.Size=New-Object Drawing.Size(65,25)
$depth.Minimum=1; $depth.Maximum=20; $depth.Value=8; $form.Controls.Add($depth)

$start=Button 'START EXTRACTION' 20 399 180
$cancel=Button 'Cancel after current archive' 210 399 210
$cancel.Enabled=$false
$clearResults=Button 'Clear results pane' 430 399 155

$status=Label 'Ready.' 20 440 980

$results=New-Object Windows.Forms.RichTextBox
$results.Location=New-Object Drawing.Point(20,470)
$results.Size=New-Object Drawing.Size(990,225)
$results.ReadOnly=$true; $results.WordWrap=$false
$results.Font=New-Object Drawing.Font('Consolas',9)
$form.Controls.Add($results)

$script:cancelRequested=$false
$script:report=$null
$script:stats=@{Outer=0;Partial=0;Inner=0;Files=0;Failed=0;Skipped=0}
$script:workRoot=$null
$script:stage=0

# ----- Logging: every message is shown in the GUI AND saved to TXT -----
function Log($kind,$text) {
    $line='[{0}] {1,-7}| {2}' -f (Get-Date -Format 'HH:mm:ss'),$kind,$text
    $results.AppendText($line+[Environment]::NewLine)
    $results.SelectionStart=$results.TextLength; $results.ScrollToCaret()
    if ($script:report) { Add-Content -LiteralPath $script:report -Value $line -Encoding UTF8 }
    [Windows.Forms.Application]::DoEvents()
}

# ----- File/folder pickers -----
function Add-Paths($paths) {
    $old=$input.Text.TrimEnd()
    if ($old) { $old += [Environment]::NewLine }
    $input.Text=$old+($paths -join [Environment]::NewLine)
}
$addFiles.Add_Click({
    $d=New-Object Windows.Forms.OpenFileDialog
    $d.Filter='All files (*.*)|*.*'; $d.Multiselect=$true
    if ($d.ShowDialog($form)-eq 'OK') { Add-Paths $d.FileNames }
    $d.Dispose()
})
$addFolder.Add_Click({
    $d=New-Object Windows.Forms.FolderBrowserDialog
    if ($d.ShowDialog($form)-eq 'OK') { Add-Paths @($d.SelectedPath) }
    $d.Dispose()
})
$browseOutput.Add_Click({
    $d=New-Object Windows.Forms.FolderBrowserDialog
    if ($d.ShowDialog($form)-eq 'OK') { $output.Text=$d.SelectedPath }
    $d.Dispose()
})
$browseSeven.Add_Click({
    $d=New-Object Windows.Forms.OpenFileDialog
    $d.Filter='7-Zip command line|7z.exe;7zz.exe|Executables|*.exe'
    if ($d.ShowDialog($form)-eq 'OK') { $seven.Text=$d.FileName }
    $d.Dispose()
})
$clearPaths.Add_Click({$input.Clear()})
$clearResults.Add_Click({$results.Clear()})
$cancel.Add_Click({
    $script:cancelRequested=$true
    $cancel.Enabled=$false
    $status.Text='Cancellation requested. The current 7-Zip operation will finish first.'
})

# ----- Unique names prevent overwriting existing output -----
function Unique-Folder($parent,$name) {
    if (-not $name) {$name='Archive'}
    $p=Join-Path $parent $name; $n=2
    while(Test-Path -LiteralPath $p){$p=Join-Path $parent ($name+'_'+$n);$n++}
    return $p
}
function Unique-File($parent,$name) {
    $p=Join-Path $parent $name
    if(-not(Test-Path -LiteralPath $p)){return $p}
    $stem=[IO.Path]::GetFileNameWithoutExtension($name)
    $ext=[IO.Path]::GetExtension($name);$n=2
    do{$p=Join-Path $parent ($stem+'_'+$n+$ext);$n++}while(Test-Path -LiteralPath $p)
    return $p
}

# ----- Ask 7-Zip to identify a file.
# This allows many archives with NO extension to be recognized. -----
function Is-Archive($path) {
    try {
        $p=Start-Process -FilePath $seven.Text -ArgumentList @('t','-bd','--',$path) -Wait -PassThru -NoNewWindow
        return ($p.ExitCode -eq 0)
    } catch { return $false }
}

# ----- Run one extraction with 7-Zip -----
function Extract-With7Zip($archive,$target) {
    & $seven.Text x -y -bd -bso0 -bsp0 ('-o'+$target) -- $archive 2>&1 | Out-Null
    return $LASTEXITCODE
}

# ----- Recursively inspect what 7-Zip produced -----
function Process-Stage($stageFolder,$finalFolder,$level) {
    $allOK=$true
    foreach($item in @(Get-ChildItem -LiteralPath $stageFolder -Force)) {
        if($script:cancelRequested){return $false}

        if($item.PSIsContainer) {
            $child=Join-Path $finalFolder $item.Name
            if(Test-Path -LiteralPath $child){$child=Unique-Folder $finalFolder $item.Name}
            [void](New-Item -ItemType Directory -Path $child -Force)
            if(-not(Process-Stage $item.FullName $child $level)){$allOK=$false}
            continue
        }

        $archive=Is-Archive $item.FullName
        if($archive -and $level -lt [int]$depth.Value) {
            $name=[IO.Path]::GetFileNameWithoutExtension($item.Name)
            if(-not $name){$name=$item.Name}
            $dest=Unique-Folder $finalFolder ($name+'_contents')
            [void](New-Item -ItemType Directory -Path $dest)
            Log 'NESTED' ($item.FullName+' -> '+$dest)
            if(Extract-Recursive $item.FullName $dest ($level+1)){
                $script:stats.Inner++
            }else{
                $allOK=$false
                $saved=Unique-File $finalFolder $item.Name
                Move-Item -LiteralPath $item.FullName -Destination $saved -Force
                Log 'WARNING' ('Nested archive retained: '+$saved)
            }
        } else {
            $dest=Unique-File $finalFolder $item.Name
            Move-Item -LiteralPath $item.FullName -Destination $dest -Force
            $script:stats.Files++
            if($archive){Log 'LIMIT' ('Depth limit reached; archive kept: '+$dest)}
            else{Log 'FILE' $dest}
        }
    }
    return $allOK
}

# ----- Extract one archive, then inspect the extracted contents -----
function Extract-Recursive($archive,$destination,$level) {
    $script:stage++
    $stageFolder=Join-Path $script:workRoot ('s'+$script:stage)
    [void](New-Item -ItemType Directory -Path $stageFolder -Force)

    try {
        $code=Extract-With7Zip $archive $stageFolder
        if($code -ne 0) {
            $script:stats.Failed++; Log 'FAILED' ($archive+' | 7-Zip exit code '+$code)
            return $false
        }

        # ZST/GZ/XZ/BZ2 are often one-file wrappers. If that one file
        # is itself an archive, continue directly into it. This avoids
        # a redundant folder level and reduces path length.
        $ext=[IO.Path]::GetExtension($archive).ToLowerInvariant()
        $top=@(Get-ChildItem -LiteralPath $stageFolder -Force)
        if($level -eq 1 -and
           $ext -in @('.zst','.zstd','.gz','.xz','.bz2','.tgz','.txz','.tzst') -and
           $top.Count -eq 1 -and -not $top[0].PSIsContainer -and
           (Is-Archive $top[0].FullName) -and $level -lt [int]$depth.Value) {
            Log 'UNWRAP' 'Single inner archive detected; continuing directly.'
            $script:stats.Inner++
            return (Extract-Recursive $top[0].FullName $destination ($level+1))
        }

        $ok=Process-Stage $stageFolder $destination $level
        if($ok){Log 'OK' $archive}else{Log 'PARTIAL' $archive}
        return $ok
    } catch {
        $script:stats.Failed++; Log 'FAILED' ($archive+' | '+$_.Exception.Message)
        return $false
    }
}

# ----- Main START button -----
$start.Add_Click({
    try {
        $sources=@($input.Text -split '\r\n|\n|\r' | ForEach-Object{$_.Trim().Trim('"')} | Where-Object{$_})
        if($sources.Count -eq 0){throw 'Add at least one file or folder.'}
        if(-not(Test-Path -LiteralPath $seven.Text -PathType Leaf)){throw '7z.exe / 7zz.exe was not found.'}
        if([IO.Path]::GetFileName($seven.Text)-notin @('7z.exe','7zz.exe')){throw 'Select 7z.exe or 7zz.exe.'}
        if(-not $output.Text.Trim()){throw 'Choose an output folder.'}

        $out=[IO.Path]::GetFullPath($output.Text.Trim().Trim('"'))
        [void](New-Item -ItemType Directory -Path $out -Force)

        $script:report=Join-Path $out ('Nested_Extraction_Report_'+(Get-Date -Format 'yyyyMMdd_HHmmss_fff')+'.txt')
        [IO.File]::WriteAllText($script:report,'')
        $script:stats=@{Outer=0;Partial=0;Inner=0;Files=0;Failed=0;Skipped=0}
        $script:stage=0;$script:cancelRequested=$false
        $root=[IO.Path]::GetPathRoot($out)
        $script:workRoot=Join-Path $root ('NAE_'+[guid]::NewGuid().ToString('N').Substring(0,10))
        [void](New-Item -ItemType Directory -Path $script:workRoot -Force)

        $start.Enabled=$false;$cancel.Enabled=$true
        Log 'START' ('Destination: '+$out)
        Log 'REPORT' $script:report
        Log 'TEMP' $script:workRoot

        $archives=New-Object 'Collections.Generic.List[string]'
        $seen=New-Object 'Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)

        foreach($source in $sources) {
            if($script:cancelRequested){break}
            if(Test-Path -LiteralPath $source -PathType Leaf) {
                $full=[IO.Path]::GetFullPath($source)
                if((Is-Archive $full)-and $seen.Add($full)){[void]$archives.Add($full)}
                else{$script:stats.Skipped++;Log 'SKIP' ('Not an archive: '+$source)}
            } elseif(Test-Path -LiteralPath $source -PathType Container) {
                Log 'SCAN' $source
                if($recursive.Checked){$files=Get-ChildItem -LiteralPath $source -File -Force -Recurse}
                else{$files=Get-ChildItem -LiteralPath $source -File -Force}
                foreach($f in $files) {
                    $ext=[IO.Path]::GetExtension($f.Name).ToLowerInvariant()
                    if($ext -notin @('.7z','.rar','.zip','.zst','.zstd','.tar','.gz','.tgz','.xz','.bz2','.tbz2','.txz','.tzst','')){continue}
                    if((Is-Archive $f.FullName)-and $seen.Add($f.FullName)){[void]$archives.Add($f.FullName)}
                }
            } else {
                $script:stats.Skipped++;Log 'SKIP' ('Path does not exist: '+$source)
            }
        }

        Log 'FOUND' ($archives.Count.ToString()+' outer archive(s)')

        foreach($a in $archives) {
            if($script:cancelRequested){Log 'CANCEL' 'Stopped before next outer archive.';break}
            $name=[IO.Path]::GetFileNameWithoutExtension($a)
            if($name -match '(?i)\.tar$'){$name=$name.Substring(0,$name.Length-4)}
            $dest=Unique-Folder $out $name
            [void](New-Item -ItemType Directory -Path $dest)
            Log 'OUTER' ($a+' -> '+$dest)
            if(Extract-Recursive $a $dest 1){$script:stats.Outer++}
            else{$script:stats.Partial++;Log 'PARTIAL' ('Outer not counted fully successful: '+$a)}
        }

        Log 'DONE' ('Successful outer: {0} | Incomplete outer: {1} | Inner: {2} | Final files: {3} | Failures: {4} | Skipped: {5}' -f
            $script:stats.Outer,$script:stats.Partial,$script:stats.Inner,$script:stats.Files,$script:stats.Failed,$script:stats.Skipped)

        if($script:stats.Failed -eq 0 -and -not $script:cancelRequested) {
            Remove-Item -LiteralPath $script:workRoot -Recurse -Force -ErrorAction SilentlyContinue
        } else {
            Log 'RECOVER' ('Temporary workspace preserved: '+$script:workRoot)
        }

        $status.Text='Finished. Report: '+$script:report
    } catch {
        [Windows.Forms.MessageBox]::Show($form,$_.Exception.Message,'Extraction error')|Out-Null
        if($script:workRoot -and (Test-Path -LiteralPath $script:workRoot)){Log 'RECOVER' ('Temporary workspace preserved: '+$script:workRoot)}
    } finally {
        $start.Enabled=$true;$cancel.Enabled=$false
    }
})

[void]$form.ShowDialog()
$form.Dispose()
