Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$AppDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$PackageRoot = Split-Path -Parent $AppDir
$PipelineScript = Join-Path $AppDir 'catalog_v23.py'
$MaintenanceScript = Join-Path $AppDir 'package_maintenance.py'
$SchedulerScript = Join-Path $AppDir 'scheduler_windows.py'
$BackgroundRunner = Join-Path $AppDir 'background_scheduler.py'
$DefaultData = Join-Path $PackageRoot 'data'
# V18 compatibility marker: offline HTTP remains the only automatic mode. $ModeCombo.SelectedIndex = 0
# V21 compatibility marker: blocked wait remains configurable in V24.
# V20 compatibility: the former 3 minute maintenance cycle is superseded by buffered durable queue/report saves.
# V21 compatibility: the former rolling 2-month discovery mode is superseded by selected-topic durable discovery.
$LegacyUrlList = Join-Path $PackageRoot 'config\urls.txt' # retained for V11-V21 data/package compatibility
$script:WorkerProcess = $null
$script:ScheduledAction = $null
$script:ScheduledArgs = $null
$script:WorkerStdErr = New-Object System.Text.StringBuilder
$script:UserStopRequested = $false
$script:StopDeadline = $null
$script:CloseAfterStop = $false

function Quote-Arg([string]$Value) {
    if ($null -eq $Value) { return '""' }
    return '"' + ($Value -replace '"','\"') + '"'
}

function Find-Python {
    if ($env:DOWNLOADLY_PYTHON -and (Test-Path $env:DOWNLOADLY_PYTHON)) { return $env:DOWNLOADLY_PYTHON }
    $local = Join-Path $PackageRoot 'runtime\.venv\Scripts\python.exe'
    if (Test-Path $local) { return $local }
    $p = Get-Command python.exe -ErrorAction SilentlyContinue
    if ($p) { return $p.Source }
    throw 'Python 3 was not found. Launch through Launch_Downloadly_GUI.vbs so setup can create the private environment.'
}

function Add-Label([string]$Text,[int]$X,[int]$Y,[int]$W=160,[int]$H=22) {
    $c = New-Object System.Windows.Forms.Label
    $c.Text=$Text; $c.Location=New-Object System.Drawing.Point($X,$Y); $c.Size=New-Object System.Drawing.Size($W,$H)
    $Form.Controls.Add($c); return $c
}
function Add-Button([string]$Text,[int]$X,[int]$Y,[int]$W=110,[int]$H=31) {
    $c=New-Object System.Windows.Forms.Button; $c.Text=$Text; $c.Location=New-Object System.Drawing.Point($X,$Y); $c.Size=New-Object System.Drawing.Size($W,$H)
    $Form.Controls.Add($c); return $c
}
function Add-TextBox([int]$X,[int]$Y,[int]$W=500,[int]$H=25) {
    $c=New-Object System.Windows.Forms.TextBox; $c.Location=New-Object System.Drawing.Point($X,$Y); $c.Size=New-Object System.Drawing.Size($W,$H)
    $Form.Controls.Add($c); return $c
}

$TopicMap = [ordered]@{
 'video-tutorials'='Video Tutorial'; 'software'='Software'; 'utility'='Utility'; 'driver'='Driver'; 'data-recovery'='Data Recovery';
 'network-server'='Network / Server'; 'operating-system'='Operating System'; 'antivirus-firewall'='Antivirus / Firewall';
 'engineering-specialized'='Engineering / Specialized'; 'development'='Development'; 'lifestyle'='Lifestyle';
 'personal-development'='Personal Development'; 'converter'='Converter'; 'graphic'='Graphic'; 'programming'='Programming';
 'audio-video-editors'='Audio / Video Editors'; 'ebook'='Ebook'; 'office-productivity'='Office Productivity'
}

$Form=New-Object System.Windows.Forms.Form
$Form.Text='Downloadly Catalog Manager V30'
$Form.StartPosition='CenterScreen'
$Form.AutoScaleMode=[System.Windows.Forms.AutoScaleMode]::Dpi
$Form.AutoScroll=$true
$Form.Size=New-Object System.Drawing.Size(1110,960)
$Form.MinimumSize=New-Object System.Drawing.Size(1030,820)
$Form.Font=New-Object System.Drawing.Font('Segoe UI',9)

$Title=Add-Label 'Downloadly Catalog Manager' 20 14 520 34
$Title.Font=New-Object System.Drawing.Font('Segoe UI',17,[System.Drawing.FontStyle]::Bold)
$Sub=Add-Label 'Discover all selected-topic URLs first → durable queue → process URLs one by one → master Excel/CSV → searchable HTML catalog' 22 50 1000 24
$Sub.ForeColor=[System.Drawing.Color]::DimGray

Add-Label 'Topics' 22 90 90 24 | Out-Null
$TopicButton=Add-Button 'Topics (1 selected) ▼' 110 84 230 31
$TopicList=New-Object System.Windows.Forms.CheckedListBox
$TopicList.CheckOnClick=$true; $TopicList.Location=New-Object System.Drawing.Point(110,116); $TopicList.Size=New-Object System.Drawing.Size(310,330); $TopicList.Visible=$false
foreach($kv in $TopicMap.GetEnumerator()) { [void]$TopicList.Items.Add($kv.Value) }
$TopicList.SetItemChecked(0,$true)
$Form.Controls.Add($TopicList); $TopicList.BringToFront()
$TopicButton.Add_Click({ $TopicList.Visible = -not $TopicList.Visible; if($TopicList.Visible){$TopicList.BringToFront()} })
$TopicList.Add_ItemCheck({
    $Form.BeginInvoke([System.Action]{
        $n=$TopicList.CheckedItems.Count
        if($n -lt 1){$TopicButton.Text='Topics (0 selected) ▼'}else{$TopicButton.Text="Topics ($n selected) ▼"}
    }) | Out-Null
})

Add-Label 'Data folder' 450 90 90 24 | Out-Null
$DataBox=Add-TextBox 535 86 405 25; $DataBox.Text=$DefaultData
$Browse=Add-Button 'Browse...' 950 84 90 29
$Browse.Add_Click({$d=New-Object System.Windows.Forms.FolderBrowserDialog;$d.SelectedPath=$DataBox.Text;if($d.ShowDialog() -eq 'OK'){$DataBox.Text=$d.SelectedPath;Refresh-Progress}})

$StageGroup=New-Object System.Windows.Forms.GroupBox; $StageGroup.Text='Run'; $StageGroup.Location=New-Object System.Drawing.Point(20,125); $StageGroup.Size=New-Object System.Drawing.Size(1018,135); $Form.Controls.Add($StageGroup)
$PipelineRadio=New-Object System.Windows.Forms.RadioButton; $PipelineRadio.Text='Discover all selected topics, then process queue'; $PipelineRadio.Location=New-Object System.Drawing.Point(18,25); $PipelineRadio.Size=New-Object System.Drawing.Size(300,24); $PipelineRadio.Checked=$true; $StageGroup.Controls.Add($PipelineRadio)
$DiscoverRadio=New-Object System.Windows.Forms.RadioButton; $DiscoverRadio.Text='Discovery only'; $DiscoverRadio.Location=New-Object System.Drawing.Point(335,25); $DiscoverRadio.Size=New-Object System.Drawing.Size(130,24); $StageGroup.Controls.Add($DiscoverRadio)
$ProcessRadio=New-Object System.Windows.Forms.RadioButton; $ProcessRadio.Text='Process saved queue only'; $ProcessRadio.Location=New-Object System.Drawing.Point(485,25); $ProcessRadio.Size=New-Object System.Drawing.Size(175,24); $StageGroup.Controls.Add($ProcessRadio)
$RefreshDiscovery=New-Object System.Windows.Forms.CheckBox; $RefreshDiscovery.Text='Refresh discovery from beginning (existing records/HTML stay untouched)'; $RefreshDiscovery.Location=New-Object System.Drawing.Point(18,57); $RefreshDiscovery.AutoSize=$true; $StageGroup.Controls.Add($RefreshDiscovery)
$DownloadImages=New-Object System.Windows.Forms.CheckBox; $DownloadImages.Text='Save thumbnails locally'; $DownloadImages.Location=New-Object System.Drawing.Point(18,92); $DownloadImages.AutoSize=$true; $StageGroup.Controls.Add($DownloadImages)
$RetryFailed=New-Object System.Windows.Forms.CheckBox; $RetryFailed.Text='Retry failed items on Resume/Start'; $RetryFailed.Checked=$true; $RetryFailed.Location=New-Object System.Drawing.Point(230,92); $RetryFailed.AutoSize=$true; $StageGroup.Controls.Add($RetryFailed)

$ResGroup=New-Object System.Windows.Forms.GroupBox; $ResGroup.Text='Network, blocking and reports'; $ResGroup.Location=New-Object System.Drawing.Point(20,270); $ResGroup.Size=New-Object System.Drawing.Size(1018,135); $Form.Controls.Add($ResGroup)
$l=New-Object System.Windows.Forms.Label;$l.Text='Block wait (min)';$l.Location=New-Object System.Drawing.Point(18,28);$l.Size=New-Object System.Drawing.Size(105,22);$ResGroup.Controls.Add($l)
$BlockWait=New-Object System.Windows.Forms.NumericUpDown;$BlockWait.Minimum=1;$BlockWait.Maximum=120;$BlockWait.Value=3;$BlockWait.Location=New-Object System.Drawing.Point(125,26);$BlockWait.Size=New-Object System.Drawing.Size(58,24);$ResGroup.Controls.Add($BlockWait)
$Increasing=New-Object System.Windows.Forms.CheckBox;$Increasing.Text='Increase wait after repeated blocks';$Increasing.Location=New-Object System.Drawing.Point(205,27);$Increasing.AutoSize=$true;$ResGroup.Controls.Add($Increasing)
$l=New-Object System.Windows.Forms.Label;$l.Text='Max wait';$l.Location=New-Object System.Drawing.Point(440,28);$l.Size=New-Object System.Drawing.Size(58,22);$ResGroup.Controls.Add($l)
$MaxWait=New-Object System.Windows.Forms.NumericUpDown;$MaxWait.Minimum=1;$MaxWait.Maximum=240;$MaxWait.Value=30;$MaxWait.Location=New-Object System.Drawing.Point(500,26);$MaxWait.Size=New-Object System.Drawing.Size(58,24);$ResGroup.Controls.Add($MaxWait)
$l=New-Object System.Windows.Forms.Label;$l.Text='Timeout';$l.Location=New-Object System.Drawing.Point(580,28);$l.Size=New-Object System.Drawing.Size(55,22);$ResGroup.Controls.Add($l)
$Timeout=New-Object System.Windows.Forms.NumericUpDown;$Timeout.Minimum=10;$Timeout.Maximum=180;$Timeout.Value=45;$Timeout.Location=New-Object System.Drawing.Point(635,26);$Timeout.Size=New-Object System.Drawing.Size(58,24);$ResGroup.Controls.Add($Timeout)
$l=New-Object System.Windows.Forms.Label;$l.Text='Report every';$l.Location=New-Object System.Drawing.Point(18,66);$l.Size=New-Object System.Drawing.Size(85,22);$ResGroup.Controls.Add($l)
$ReportEvery=New-Object System.Windows.Forms.NumericUpDown;$ReportEvery.Minimum=1;$ReportEvery.Maximum=1000;$ReportEvery.Value=100;$ReportEvery.Location=New-Object System.Drawing.Point(105,64);$ReportEvery.Size=New-Object System.Drawing.Size(68,24);$ResGroup.Controls.Add($ReportEvery)
$l=New-Object System.Windows.Forms.Label;$l.Text='items or';$l.Location=New-Object System.Drawing.Point(170,66);$l.Size=New-Object System.Drawing.Size(50,22);$ResGroup.Controls.Add($l)
$ReportSeconds=New-Object System.Windows.Forms.NumericUpDown;$ReportSeconds.Minimum=10;$ReportSeconds.Maximum=1800;$ReportSeconds.Value=300;$ReportSeconds.Location=New-Object System.Drawing.Point(230,64);$ReportSeconds.Size=New-Object System.Drawing.Size(70,24);$ResGroup.Controls.Add($ReportSeconds)
$l=New-Object System.Windows.Forms.Label;$l.Text='seconds';$l.Location=New-Object System.Drawing.Point(305,66);$l.Size=New-Object System.Drawing.Size(58,22);$ResGroup.Controls.Add($l)
$l=New-Object System.Windows.Forms.Label;$l.Text='Processing workers';$l.Location=New-Object System.Drawing.Point(385,66);$l.Size=New-Object System.Drawing.Size(118,22);$ResGroup.Controls.Add($l)
$Workers=New-Object System.Windows.Forms.NumericUpDown;$Workers.Minimum=1;$Workers.Maximum=100;$Workers.Value=3;$Workers.Location=New-Object System.Drawing.Point(505,64);$Workers.Size=New-Object System.Drawing.Size(58,24);$ResGroup.Controls.Add($Workers)
$SpeedNote=New-Object System.Windows.Forms.Label;$SpeedNote.Text='1-100 allowed; 3 default. High values may trigger site blocking.';$SpeedNote.Location=New-Object System.Drawing.Point(575,66);$SpeedNote.Size=New-Object System.Drawing.Size(360,22);$SpeedNote.ForeColor=[System.Drawing.Color]::DimGray;$ResGroup.Controls.Add($SpeedNote)
$CookieNote=New-Object System.Windows.Forms.Label;$CookieNote.Text='Fast HTTP first. If a page is blocked, V30 tries bounded headless Selenium; still-blocked items are deferred so the queue continues.';$CookieNote.Location=New-Object System.Drawing.Point(18,96);$CookieNote.Size=New-Object System.Drawing.Size(960,28);$CookieNote.ForeColor=[System.Drawing.Color]::DimGray;$ResGroup.Controls.Add($CookieNote)
$ClearCookiesCheck=New-Object System.Windows.Forms.CheckBox;$ClearCookiesCheck.Text='Clear app site cookies before run';$ClearCookiesCheck.Checked=$true;$ClearCookiesCheck.Location=New-Object System.Drawing.Point(710,26);$ClearCookiesCheck.AutoSize=$true;$ResGroup.Controls.Add($ClearCookiesCheck)
$CookieBrowser=New-Object System.Windows.Forms.Button;$CookieBrowser.Text='Cookie Browser';$CookieBrowser.Location=New-Object System.Drawing.Point(900,25);$CookieBrowser.Size=New-Object System.Drawing.Size(100,25);$ResGroup.Controls.Add($CookieBrowser)

$TransGroup=New-Object System.Windows.Forms.GroupBox;$TransGroup.Text='Optional English title translation';$TransGroup.Location=New-Object System.Drawing.Point(20,415);$TransGroup.Size=New-Object System.Drawing.Size(500,95);$Form.Controls.Add($TransGroup)
$Translation=New-Object System.Windows.Forms.ComboBox;$Translation.DropDownStyle='DropDownList';[void]$Translation.Items.Add('Disabled (default)');[void]$Translation.Items.Add('Argos Translate (local CPU)');$Translation.SelectedIndex=0;$Translation.Location=New-Object System.Drawing.Point(18,28);$Translation.Size=New-Object System.Drawing.Size(225,25);$TransGroup.Controls.Add($Translation)
$ArgosAuto=New-Object System.Windows.Forms.CheckBox;$ArgosAuto.Text='Auto-install language packs if available';$ArgosAuto.Location=New-Object System.Drawing.Point(255,28);$ArgosAuto.AutoSize=$true;$TransGroup.Controls.Add($ArgosAuto)
$InstallArgos=New-Object System.Windows.Forms.Button;$InstallArgos.Text='Install Argos';$InstallArgos.Location=New-Object System.Drawing.Point(18,55);$InstallArgos.Size=New-Object System.Drawing.Size(105,24);$TransGroup.Controls.Add($InstallArgos)

$ScheduleGroup=New-Object System.Windows.Forms.GroupBox;$ScheduleGroup.Text='Schedule';$ScheduleGroup.Location=New-Object System.Drawing.Point(538,415);$ScheduleGroup.Size=New-Object System.Drawing.Size(500,95);$Form.Controls.Add($ScheduleGroup)
$ScheduleStart=New-Object System.Windows.Forms.CheckBox;$ScheduleStart.Text='Start at';$ScheduleStart.Location=New-Object System.Drawing.Point(15,27);$ScheduleStart.AutoSize=$true;$ScheduleGroup.Controls.Add($ScheduleStart)
$StartPicker=New-Object System.Windows.Forms.DateTimePicker;$StartPicker.Format='Custom';$StartPicker.CustomFormat='yyyy-MM-dd hh:mm tt';$StartPicker.Value=(Get-Date);$StartPicker.Location=New-Object System.Drawing.Point(85,25);$StartPicker.Size=New-Object System.Drawing.Size(180,24);$ScheduleGroup.Controls.Add($StartPicker)
$Allowed=New-Object System.Windows.Forms.CheckBox;$Allowed.Text='Allowed hours';$Allowed.Location=New-Object System.Drawing.Point(280,27);$Allowed.AutoSize=$true;$ScheduleGroup.Controls.Add($Allowed)
$AllowedFrom=New-Object System.Windows.Forms.TextBox;$AllowedFrom.Text='00:00';$AllowedFrom.Location=New-Object System.Drawing.Point(15,55);$AllowedFrom.Size=New-Object System.Drawing.Size(55,24);$ScheduleGroup.Controls.Add($AllowedFrom)
$l=New-Object System.Windows.Forms.Label;$l.Text='to';$l.Location=New-Object System.Drawing.Point(75,58);$l.Size=New-Object System.Drawing.Size(20,20);$ScheduleGroup.Controls.Add($l)
$AllowedTo=New-Object System.Windows.Forms.TextBox;$AllowedTo.Text='07:00';$AllowedTo.Location=New-Object System.Drawing.Point(98,55);$AllowedTo.Size=New-Object System.Drawing.Size(55,24);$ScheduleGroup.Controls.Add($AllowedTo)

$StatusLabel=Add-Label 'Ready' 22 525 1000 26
$StatusLabel.Font=New-Object System.Drawing.Font('Segoe UI',10,[System.Drawing.FontStyle]::Bold)
$Progress=New-Object System.Windows.Forms.ProgressBar;$Progress.Location=New-Object System.Drawing.Point(22,555);$Progress.Size=New-Object System.Drawing.Size(1016,20);$Progress.Style='Continuous';$Form.Controls.Add($Progress)
$Stats=Add-Label 'No run in progress.' 22 581 1000 24;$Stats.ForeColor=[System.Drawing.Color]::DimGray

$Start=Add-Button 'START' 22 615 95 32
$Pause=Add-Button 'PAUSE' 125 615 95 32
$Resume=Add-Button 'RESUME / Resume Offline' 228 615 165 32
$Stop=Add-Button 'STOP' 401 615 95 32
$OpenReport=Add-Button 'Open Reports' 510 615 105 32
$OpenCatalog=Add-Button 'Open Catalog' 622 615 105 32
$OpenQueue=Add-Button 'Open Queue CSV' 734 615 110 32
$ImportEdits=Add-Button 'Import HTML Edits' 851 615 145 32
$UpdateZip=Add-Button 'Update from ZIP' 22 657 125 30
$SupportMode=New-Object System.Windows.Forms.ComboBox;$SupportMode.DropDownStyle='DropDownList';[void]$SupportMode.Items.Add('Code only');[void]$SupportMode.Items.Add('Diagnostic + logs');$SupportMode.SelectedIndex=0;$SupportMode.Location=New-Object System.Drawing.Point(160,659);$SupportMode.Size=New-Object System.Drawing.Size(150,25);$Form.Controls.Add($SupportMode)
$CreateSupport=Add-Button 'Create Support Package' 322 657 165 30
$MaintenanceNote=Add-Label 'Updater preserves data/runtime/logs/config; support packages exclude downloaded HTML/images/database/cookies.' 500 660 520 36; $MaintenanceNote.MaximumSize=New-Object System.Drawing.Size(520,40); $MaintenanceNote.AutoSize=$true
$MaintenanceNote.ForeColor=[System.Drawing.Color]::DimGray
$RebuildCache=Add-Button 'Rebuild Catalog from Saved HTML' 22 700 220 30
$DuplicateCheck=Add-Button 'Run Duplicate Checker' 250 700 165 30
$BackgroundSchedulerButton=Add-Button 'Background Scheduler...' 423 700 175 30
$Pause.Enabled=$false;$Resume.Enabled=$false;$Stop.Enabled=$false

$LogBox=New-Object System.Windows.Forms.TextBox;$LogBox.Multiline=$true;$LogBox.ScrollBars='Vertical';$LogBox.ReadOnly=$true;$LogBox.Font=New-Object System.Drawing.Font('Consolas',9);$LogBox.Location=New-Object System.Drawing.Point(22,745);$LogBox.Size=New-Object System.Drawing.Size(1016,165);$LogBox.Anchor=[System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right;$Form.Controls.Add($LogBox)

function Get-SelectedTopicSlugs {
    $result=New-Object System.Collections.Generic.List[string]
    foreach($checked in $TopicList.CheckedItems){
        foreach($kv in $TopicMap.GetEnumerator()){if($kv.Value -eq [string]$checked){$result.Add($kv.Key);break}}
    }
    return ,$result.ToArray()
}

function Set-Running([bool]$running){
    $Start.Enabled=-not $running;$Stop.Enabled=$running;$Pause.Enabled=$running;$Resume.Enabled=$false
    $TopicButton.Enabled=-not $running;$Browse.Enabled=-not $running;$PipelineRadio.Enabled=-not $running;$DiscoverRadio.Enabled=-not $running;$ProcessRadio.Enabled=-not $running
    $RebuildCache.Enabled=-not $running;$DuplicateCheck.Enabled=-not $running;$BackgroundSchedulerButton.Enabled=-not $running
}

function Test-WorkerRunning {
    if(-not $script:WorkerProcess){ return $false }
    try{
        $script:WorkerProcess.Refresh()
        return (-not $script:WorkerProcess.HasExited)
    }catch{ return $false }
}

function Attach-ExistingWorker {
    if(Test-WorkerRunning){ return $true }
    try{
        $pipelineFull=[System.IO.Path]::GetFullPath($PipelineScript)
        $dataFull=[System.IO.Path]::GetFullPath($DataBox.Text)
        $expectedPython=$null
        try{$expectedPython=[System.IO.Path]::GetFullPath((Find-Python))}catch{}
        $fallback=$null
        $candidates=Get-CimInstance Win32_Process -Filter "Name='python.exe'" -ErrorAction SilentlyContinue
        foreach($c in $candidates){
            $cmd=[string]$c.CommandLine
            if([string]::IsNullOrWhiteSpace($cmd)){ continue }
            if($cmd.IndexOf($pipelineFull,[System.StringComparison]::OrdinalIgnoreCase) -lt 0){ continue }
            if($cmd.IndexOf($dataFull,[System.StringComparison]::OrdinalIgnoreCase) -lt 0){ continue }
            if(-not $fallback){$fallback=$c}
            if($expectedPython -and $c.ExecutablePath -and ([System.IO.Path]::GetFullPath([string]$c.ExecutablePath) -ieq $expectedPython)){$fallback=$c;break}
        }
        if($fallback){
            try{
                $p=[System.Diagnostics.Process]::GetProcessById([int]$fallback.ProcessId)
                if(-not $p.HasExited){
                    $script:WorkerProcess=$p
                    $script:UserStopRequested=$false
                    $script:StopDeadline=$null
                    Set-Running $true
                    $StatusLabel.ForeColor=[System.Drawing.Color]::DarkGreen
                    $StatusLabel.Text="Attached to running worker PID $($p.Id)"
                    return $true
                }
            }catch{}
        }
    }catch{}
    return $false
}

function Read-Progress {
    $p=Join-Path $DataBox.Text 'state\run_progress.json'; if(-not(Test-Path $p)){return $null}
    $fs=$null;$sr=$null
    try{$share=[System.IO.FileShare]::ReadWrite -bor [System.IO.FileShare]::Delete;$fs=New-Object System.IO.FileStream($p,[System.IO.FileMode]::Open,[System.IO.FileAccess]::Read,$share);$sr=New-Object System.IO.StreamReader($fs);$t=$sr.ReadToEnd();if([string]::IsNullOrWhiteSpace($t)){return $null};return $t|ConvertFrom-Json}catch{return $null}finally{if($sr){$sr.Dispose()}elseif($fs){$fs.Dispose()}}
}
function Refresh-Log {
    $p=Join-Path $DataBox.Text 'logs\run.log'
    if(Test-Path $p){
        $fs=$null;$sr=$null
        try{
            $share=[System.IO.FileShare]::ReadWrite -bor [System.IO.FileShare]::Delete
            $fs=New-Object System.IO.FileStream($p,[System.IO.FileMode]::Open,[System.IO.FileAccess]::Read,$share)
            $utf8=New-Object System.Text.UTF8Encoding($false)
            $sr=New-Object System.IO.StreamReader($fs,$utf8,$true)
            $text=$sr.ReadToEnd()
            $lines=[System.Text.RegularExpressions.Regex]::Split($text,"`r?`n")
            if($lines.Count -gt 100){$lines=$lines[($lines.Count-100)..($lines.Count-1)]}
            $LogBox.Lines=[string[]]$lines
            $LogBox.SelectionStart=$LogBox.TextLength;$LogBox.ScrollToCaret()
        }catch{}finally{if($sr){$sr.Dispose()}elseif($fs){$fs.Dispose()}}
    }
}
function Refresh-Progress {
    $x=Read-Progress
    if($x){
        $StatusLabel.Text="Status: $($x.status) | Phase: $($x.phase) | $($x.message)"
        $pieces=@();foreach($k in @('topic','batch','total_batches','remaining_batches','discovered','current_item','pending','completed','failed','blocked','items')){if($null -ne $x.$k){$pieces += "$k=$($x.$k)"}};$Stats.Text=$pieces -join '   '
        if($x.batch -and $x.total_batches -and [int]$x.total_batches -gt 0){
            $Progress.Value=[Math]::Min(100,[Math]::Max(0,[int](100*[double]$x.batch/[double]$x.total_batches)))
        }elseif($null -ne $x.completed -and $x.items -and [int]$x.items -gt 0){
            $Progress.Value=[Math]::Min(100,[Math]::Max(0,[int](100*[double]$x.completed/[double]$x.items)))
        }else{$Progress.Value=0}
        $workerRunning=(Test-WorkerRunning)
        if($workerRunning){
            if(@('paused','paused_blocked') -contains [string]$x.status){$Resume.Enabled=$true}else{$Resume.Enabled=$false}
            $Stop.Enabled=$true
        } else {
            if(@('paused','paused_blocked','stopped','cancelled','error') -contains [string]$x.status){$Resume.Enabled=$true}else{$Resume.Enabled=$false}
        }
    } else {
        $tp=Join-Path $DataBox.Text 'state\topic_progress.json'
        if(Test-Path $tp){try{$j=Get-Content -LiteralPath $tp -Raw|ConvertFrom-Json;$parts=@();foreach($t in $j.topics){$parts += ("{0}: {1}, next batch {2}/{3}" -f $t.topic_slug,$t.status,$t.next_batch,$t.total_batches)};if($parts.Count -gt 0){$Stats.Text='Saved topic progress: '+($parts -join ' | ')}}catch{}}
    }
    Refresh-Log
}

function Build-Args([string]$phase){
    $topics=Get-SelectedTopicSlugs;if($topics.Count -eq 0){throw 'Select at least one topic.'}
    $a=@($PipelineScript,'--data-dir',$DataBox.Text,'--topics',($topics -join ','),'--phase',$phase,'--timeout',[string]$Timeout.Value,'--workers',[string]$Workers.Value,'--block-wait-minutes',[string]$BlockWait.Value,'--max-wait-minutes',[string]$MaxWait.Value,'--report-buffer-courses',[string]$ReportEvery.Value,'--report-seconds',[string]$ReportSeconds.Value)
    if($RefreshDiscovery.Checked){$a+='--refresh-discovery'};if($DownloadImages.Checked){$a+='--download-images'};if($Increasing.Checked){$a+='--increasing-wait'};if($ClearCookiesCheck.Checked){$a+='--clear-cookies-before-run'};if($RetryFailed.Checked){$a+='--retry-failed'}
    # V18-V21 compatibility switches are accepted by V30; the durable queue supersedes the old loops.
    $a+=@('--blocked-retry-seconds',[string]([int]$BlockWait.Value*60),'--maintenance-seconds','180','--rolling-months','2','--max-block-retries','1')
    if($Translation.SelectedIndex -eq 1){$a+=@('--translation','argos');if($ArgosAuto.Checked){$a+='--argos-auto-install'}}else{$a+=@('--translation','disabled')}
    if($Allowed.Checked){$a+=@('--allowed-from',$AllowedFrom.Text,'--allowed-to',$AllowedTo.Text)}
    return ,$a
}

function Start-Worker([string]$phase){
    if(Test-WorkerRunning){return}else{$script:WorkerProcess=$null}
    $py=Find-Python;$args=Build-Args $phase
    New-Item -ItemType Directory -Force -Path (Join-Path $DataBox.Text 'logs'),(Join-Path $DataBox.Text 'state') | Out-Null
    foreach($f in @('pause.requested','stop.requested','cancel.requested')){Remove-Item -LiteralPath (Join-Path $DataBox.Text ('state\'+$f)) -Force -ErrorAction SilentlyContinue}
    $psi=New-Object System.Diagnostics.ProcessStartInfo;$psi.FileName=$py;$psi.Arguments=($args|ForEach-Object{Quote-Arg $_}) -join ' ';$psi.UseShellExecute=$false;$psi.CreateNoWindow=$true;$psi.RedirectStandardError = $true
    $p=New-Object System.Diagnostics.Process;$p.StartInfo=$psi;$script:WorkerStdErr.Clear()|Out-Null
    $p.add_ErrorDataReceived({param($s,$e) if($e.Data){[void]$script:WorkerStdErr.AppendLine($e.Data);try{[System.IO.File]::AppendAllText((Join-Path $DataBox.Text 'logs\worker_crash.log'),$e.Data+[Environment]::NewLine)}catch{}}})
    [void]$p.Start();$p.BeginErrorReadLine();$script:WorkerProcess=$p;$script:UserStopRequested=$false;$script:StopDeadline=$null;Set-Running $true;$StatusLabel.Text='Worker started';if($Monitor){$Monitor.Start()}
}

function Request-Start {
    $phase='pipeline';if($DiscoverRadio.Checked){$phase='discover'}elseif($ProcessRadio.Checked){$phase='process'}
    if($ScheduleStart.Checked -and $StartPicker.Value -gt (Get-Date)){$script:ScheduledAction=$phase;$ScheduledTimer.Start();$StatusLabel.Text="Scheduled for $($StartPicker.Value)";return}
    Start-Worker $phase
}

$Start.Add_Click({try{Request-Start}catch{[System.Windows.Forms.MessageBox]::Show($_.Exception.Message,'Cannot start')|Out-Null}})
$Pause.Add_Click({try{New-Item -ItemType File -Force -Path (Join-Path $DataBox.Text 'state\pause.requested')|Out-Null;$Pause.Enabled=$false;$Resume.Enabled=$true;$StatusLabel.Text='Pause requested; current safe operation will finish first.'}catch{}})
$Resume.Add_Click({try{
    Remove-Item -LiteralPath (Join-Path $DataBox.Text 'state\pause.requested') -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath (Join-Path $DataBox.Text 'state\stop.requested') -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath (Join-Path $DataBox.Text 'state\cancel.requested') -Force -ErrorAction SilentlyContinue
    if(Test-WorkerRunning){
        $Pause.Enabled=$true;$Resume.Enabled=$false;$StatusLabel.Text='Resume requested; continuing current worker.'
    }else{
        $script:WorkerProcess=$null
        $StatusLabel.Text='Resume starting saved SQLite queue...';$Resume.Enabled=$false
        Start-Worker 'resume'
    }
}catch{[System.Windows.Forms.MessageBox]::Show($_.Exception.Message,'Cannot resume')|Out-Null}})
$Stop.Add_Click({try{
    New-Item -ItemType File -Force -Path (Join-Path $DataBox.Text 'state\stop.requested')|Out-Null
    $script:UserStopRequested=$true
    $script:StopDeadline=(Get-Date).AddSeconds(4)
    $Stop.Enabled=$false
    $StatusLabel.ForeColor=[System.Drawing.Color]::DarkOrange
    $StatusLabel.Text='Stop requested. Waiting up to 4 seconds for a safe checkpoint; then the worker will be force-stopped.'
    try{[System.IO.File]::AppendAllText((Join-Path $DataBox.Text 'logs\run.log'),"[$((Get-Date).ToString('yyyy-MM-ddTHH:mm:ss'))] STOP requested from GUI; safe-stop grace=4s`r`n",[System.Text.UTF8Encoding]::new($false))}catch{}
    $StopGraceTimer.Start()
}catch{}})
$OpenReport.Add_Click({$p=Join-Path $DataBox.Text 'reports';if(Test-Path $p){Start-Process explorer.exe $p}})
$OpenCatalog.Add_Click({$p=Join-Path $DataBox.Text 'catalog\catalog.html';if(Test-Path $p){Start-Process $p}else{[System.Windows.Forms.MessageBox]::Show('Catalog has not been generated yet.')|Out-Null}})
$OpenQueue.Add_Click({$p=Join-Path $DataBox.Text 'discovery\discovered_items.csv';if(Test-Path $p){Start-Process $p}else{[System.Windows.Forms.MessageBox]::Show('Discovery queue does not exist yet.')|Out-Null}})
$ImportEdits.Add_Click({$d=New-Object System.Windows.Forms.OpenFileDialog;$d.Filter='Catalog edits (*.json)|*.json';if($d.ShowDialog() -eq 'OK'){try{$py=Find-Python;$a=@($PipelineScript,'--data-dir',$DataBox.Text,'--phase','import-edits','--topics','video-tutorials','--edits-file',$d.FileName);$psi=New-Object System.Diagnostics.ProcessStartInfo;$psi.FileName=$py;$psi.Arguments=($a|ForEach-Object{Quote-Arg $_}) -join ' ';$psi.UseShellExecute=$false;$psi.CreateNoWindow=$true;$p=[System.Diagnostics.Process]::Start($psi);$p.WaitForExit();[System.Windows.Forms.MessageBox]::Show('Catalog edits imported. Reports/catalog regenerated.')|Out-Null}catch{[System.Windows.Forms.MessageBox]::Show($_.Exception.Message)|Out-Null}}})
function Invoke-PythonCapture([string[]]$ArgumentValues){
    $py=Find-Python;$psi=New-Object System.Diagnostics.ProcessStartInfo;$psi.FileName=$py;$psi.Arguments=($ArgumentValues|ForEach-Object{Quote-Arg $_}) -join ' ';$psi.UseShellExecute=$false;$psi.CreateNoWindow=$true;$psi.RedirectStandardOutput=$true;$psi.RedirectStandardError=$true;$p=New-Object System.Diagnostics.Process;$p.StartInfo=$psi;[void]$p.Start();$out=$p.StandardOutput.ReadToEnd();$err=$p.StandardError.ReadToEnd();$p.WaitForExit();return [PSCustomObject]@{ExitCode=$p.ExitCode;StdOut=$out;StdErr=$err}
}

$RebuildCache.Add_Click({
    if(Test-WorkerRunning){[System.Windows.Forms.MessageBox]::Show('Stop the worker before rebuilding from cache.')|Out-Null;return}
    $r=[System.Windows.Forms.MessageBox]::Show("Rebuild the catalog using SAVED HTML ONLY?`r`n`r`nNo network requests will be made. Existing manual Status/Notes are preserved. Links/reports/catalog are re-extracted from html_archive.",'Rebuild Catalog from Saved HTML',[System.Windows.Forms.MessageBoxButtons]::OKCancel,[System.Windows.Forms.MessageBoxIcon]::Information)
    if($r -eq [System.Windows.Forms.DialogResult]::OK){try{Start-Worker 'rebuild-cache'}catch{[System.Windows.Forms.MessageBox]::Show($_.Exception.Message,'Rebuild failed to start')|Out-Null}}
})
$DuplicateCheck.Add_Click({
    if(Test-WorkerRunning){[System.Windows.Forms.MessageBox]::Show('Stop the worker before running duplicate check.')|Out-Null;return}
    try{Start-Worker 'dedupe'}catch{[System.Windows.Forms.MessageBox]::Show($_.Exception.Message,'Duplicate checker failed to start')|Out-Null}
})

function Show-BackgroundSchedulerDialog {
    $topics=Get-SelectedTopicSlugs
    if($topics.Count -eq 0){[System.Windows.Forms.MessageBox]::Show('Select at least one topic first.')|Out-Null;return}
    $cfgPath=Join-Path $DataBox.Text 'state\background_schedule.json'
    New-Item -ItemType Directory -Force -Path (Split-Path $cfgPath -Parent)|Out-Null
    $sf=New-Object System.Windows.Forms.Form;$sf.Text='Background Scheduler';$sf.StartPosition='CenterParent';$sf.Size=New-Object System.Drawing.Size(590,535);$sf.FormBorderStyle='FixedDialog';$sf.MaximizeBox=$false;$sf.MinimizeBox=$false
    $y=20
    $lab=New-Object System.Windows.Forms.Label;$lab.Text='Selected topics: '+(($topics|ForEach-Object{$TopicMap[$_]}) -join ', ');$lab.Location=New-Object System.Drawing.Point(20,$y);$lab.Size=New-Object System.Drawing.Size(540,42);$sf.Controls.Add($lab);$y=68
    $l=New-Object System.Windows.Forms.Label;$l.Text='Daily start';$l.Location=New-Object System.Drawing.Point(20,$y+4);$l.Size=New-Object System.Drawing.Size(80,22);$sf.Controls.Add($l)
    $sp=New-Object System.Windows.Forms.DateTimePicker;$sp.Format='Custom';$sp.CustomFormat='HH:mm';$sp.ShowUpDown=$true;$sp.Value=[datetime]::Today.AddHours(2);$sp.Location=New-Object System.Drawing.Point(105,$y);$sp.Size=New-Object System.Drawing.Size(80,25);$sf.Controls.Add($sp)
    $l=New-Object System.Windows.Forms.Label;$l.Text='Safe exit';$l.Location=New-Object System.Drawing.Point(205,$y+4);$l.Size=New-Object System.Drawing.Size(70,22);$sf.Controls.Add($l)
    $ep=New-Object System.Windows.Forms.DateTimePicker;$ep.Format='Custom';$ep.CustomFormat='HH:mm';$ep.ShowUpDown=$true;$ep.Value=[datetime]::Today.AddHours(7);$ep.Location=New-Object System.Drawing.Point(275,$y);$ep.Size=New-Object System.Drawing.Size(80,25);$sf.Controls.Add($ep)
    $l=New-Object System.Windows.Forms.Label;$l.Text='Recheck every';$l.Location=New-Object System.Drawing.Point(375,$y+4);$l.Size=New-Object System.Drawing.Size(88,22);$sf.Controls.Add($l)
    $rp=New-Object System.Windows.Forms.NumericUpDown;$rp.Minimum=0;$rp.Maximum=1440;$rp.Value=60;$rp.Location=New-Object System.Drawing.Point(465,$y);$rp.Size=New-Object System.Drawing.Size(55,25);$sf.Controls.Add($rp)
    $l=New-Object System.Windows.Forms.Label;$l.Text='min';$l.Location=New-Object System.Drawing.Point(525,$y+4);$l.Size=New-Object System.Drawing.Size(35,22);$sf.Controls.Add($l);$y+=42
    $l=New-Object System.Windows.Forms.Label;$l.Text='Max block retries per scheduled run';$l.Location=New-Object System.Drawing.Point(20,$y+4);$l.Size=New-Object System.Drawing.Size(210,22);$sf.Controls.Add($l)
    $mr=New-Object System.Windows.Forms.NumericUpDown;$mr.Minimum=1;$mr.Maximum=20;$mr.Value=1;$mr.Location=New-Object System.Drawing.Point(235,$y);$mr.Size=New-Object System.Drawing.Size(55,25);$sf.Controls.Add($mr);$y+=38
    $wake=New-Object System.Windows.Forms.CheckBox;$wake.Text='Wake computer to run task';$wake.Location=New-Object System.Drawing.Point(20,$y);$wake.AutoSize=$true;$sf.Controls.Add($wake)
    $miss=New-Object System.Windows.Forms.CheckBox;$miss.Text='Run missed task when computer becomes available';$miss.Checked=$true;$miss.Location=New-Object System.Drawing.Point(235,$y);$miss.AutoSize=$true;$sf.Controls.Add($miss);$y+=35
    $desc=New-Object System.Windows.Forms.Label;$desc.Text='Scheduled runs use NEW-POST discovery only, process the saved queue, clear extractor cookies/session after blocks, rebuild reports/catalog, run duplicate checking, and exit safely at the configured end time.';$desc.Location=New-Object System.Drawing.Point(20,$y);$desc.Size=New-Object System.Drawing.Size(535,58);$desc.ForeColor=[System.Drawing.Color]::DimGray;$sf.Controls.Add($desc);$y+=70
    $last=New-Object System.Windows.Forms.Label;$last.Text='Last run: not available';$last.Location=New-Object System.Drawing.Point(20,$y);$last.Size=New-Object System.Drawing.Size(535,45);$sf.Controls.Add($last);$y+=50
    $lastPath=Join-Path $DataBox.Text 'state\scheduled_last_run.json';if(Test-Path $lastPath){try{$j=Get-Content -LiteralPath $lastPath -Raw -Encoding UTF8|ConvertFrom-Json;$last.Text="Last run: $($j.updated_at) | exit=$($j.exit_code) | runs=$($j.runs_this_window)"}catch{}}
    if(Test-Path $cfgPath){try{$old=Get-Content -LiteralPath $cfgPath -Raw -Encoding UTF8|ConvertFrom-Json;$sp.Value=[datetime]::Today.Add([timespan]::Parse($old.start_time));$ep.Value=[datetime]::Today.Add([timespan]::Parse($old.end_time));$rp.Value=[decimal]$old.repeat_minutes;if($null -ne $old.max_block_retries){$mr.Value=[decimal]$old.max_block_retries};$wake.Checked=[bool]$old.wake_to_run;$miss.Checked=[bool]$old.start_when_available}catch{}}
    function Save-BgConfig {
        $obj=[ordered]@{task_name='Downloadly Catalog Manager V30';package_root=$PackageRoot;data_dir=$DataBox.Text;topics=@($topics);start_time=$sp.Value.ToString('HH:mm');end_time=$ep.Value.ToString('HH:mm');repeat_minutes=[int]$rp.Value;max_block_retries=[int]$mr.Value;wake_to_run=$wake.Checked;start_when_available=$miss.Checked;timeout=[int]$Timeout.Value;workers=[int]$Workers.Value;block_wait_minutes=[double]$BlockWait.Value;max_wait_minutes=[double]$MaxWait.Value;increasing_wait=$Increasing.Checked;report_every=[int]$ReportEvery.Value;report_seconds=[int]$ReportSeconds.Value;download_images=$DownloadImages.Checked;translation=$(if($Translation.SelectedIndex -eq 1){'argos'}else{'disabled'})}
        [System.IO.File]::WriteAllText($cfgPath,($obj|ConvertTo-Json -Depth 6),[System.Text.UTF8Encoding]::new($false));return $cfgPath
    }
    $install=New-Object System.Windows.Forms.Button;$install.Text='Install Schedule';$install.Location=New-Object System.Drawing.Point(20,$y);$install.Size=New-Object System.Drawing.Size(120,30);$sf.Controls.Add($install)
    $disable=New-Object System.Windows.Forms.Button;$disable.Text='Disable Schedule';$disable.Location=New-Object System.Drawing.Point(150,$y);$disable.Size=New-Object System.Drawing.Size(120,30);$sf.Controls.Add($disable)
    $run=New-Object System.Windows.Forms.Button;$run.Text='Run Scheduled Job Now';$run.Location=New-Object System.Drawing.Point(280,$y);$run.Size=New-Object System.Drawing.Size(150,30);$sf.Controls.Add($run)
    $test=New-Object System.Windows.Forms.Button;$test.Text='Test Schedule Now';$test.Location=New-Object System.Drawing.Point(440,$y);$test.Size=New-Object System.Drawing.Size(120,30);$sf.Controls.Add($test);$y+=42
    $view=New-Object System.Windows.Forms.Button;$view.Text='View Last Scheduled Log';$view.Location=New-Object System.Drawing.Point(20,$y);$view.Size=New-Object System.Drawing.Size(160,30);$sf.Controls.Add($view)
    $close=New-Object System.Windows.Forms.Button;$close.Text='Close';$close.Location=New-Object System.Drawing.Point(440,$y);$close.Size=New-Object System.Drawing.Size(120,30);$sf.Controls.Add($close)
    $install.Add_Click({try{$c=Save-BgConfig;$x=Invoke-PythonCapture @($SchedulerScript,'install','--package-root',$PackageRoot,'--data-dir',$DataBox.Text,'--config',$c);if($x.ExitCode -ne 0){throw $x.StdErr};[System.Windows.Forms.MessageBox]::Show('Background schedule installed/updated.'+[Environment]::NewLine+$x.StdOut,'Background Scheduler')|Out-Null}catch{[System.Windows.Forms.MessageBox]::Show($_.Exception.Message,'Schedule install failed')|Out-Null}})
    $disable.Add_Click({try{$c=Save-BgConfig;$x=Invoke-PythonCapture @($SchedulerScript,'disable','--config',$c);if($x.ExitCode -ne 0){throw $x.StdErr};[System.Windows.Forms.MessageBox]::Show('Background schedule disabled.')|Out-Null}catch{[System.Windows.Forms.MessageBox]::Show($_.Exception.Message,'Disable failed')|Out-Null}})
    $run.Add_Click({try{$c=Save-BgConfig;$x=Invoke-PythonCapture @($SchedulerScript,'run','--config',$c);if($x.ExitCode -ne 0){throw $x.StdErr};[System.Windows.Forms.MessageBox]::Show('Scheduled task start requested. It runs hidden in the background.')|Out-Null}catch{[System.Windows.Forms.MessageBox]::Show($_.Exception.Message,'Run failed')|Out-Null}})
    $test.Add_Click({try{$c=Save-BgConfig;$py=Find-Python;$psi=New-Object System.Diagnostics.ProcessStartInfo;$psi.FileName=$py;$psi.Arguments=(Quote-Arg $BackgroundRunner)+' --config '+(Quote-Arg $c)+' --test-once';$psi.UseShellExecute=$false;$psi.CreateNoWindow=$true;[void][System.Diagnostics.Process]::Start($psi);[System.Windows.Forms.MessageBox]::Show('Test schedule started in the background. Watch the main Run Log / progress files for activity.')|Out-Null}catch{[System.Windows.Forms.MessageBox]::Show($_.Exception.Message,'Test schedule failed')|Out-Null}})
    $view.Add_Click({$p=Join-Path $DataBox.Text 'logs\run.log';if(Test-Path $p){Start-Process notepad.exe $p}else{[System.Windows.Forms.MessageBox]::Show('No scheduled/run log exists yet.')|Out-Null}})
    $close.Add_Click({$sf.Close()})
    [void]$sf.ShowDialog($Form)
}
$BackgroundSchedulerButton.Add_Click({Show-BackgroundSchedulerDialog})
$UpdateZip.Add_Click({
    if($script:WorkerProcess -and -not $script:WorkerProcess.HasExited){[System.Windows.Forms.MessageBox]::Show('Stop the worker before updating program files.')|Out-Null;return}
    $d=New-Object System.Windows.Forms.OpenFileDialog;$d.Filter='Downloadly package ZIP (*.zip)|*.zip'
    if($d.ShowDialog() -ne 'OK'){return}
    $r=[System.Windows.Forms.MessageBox]::Show("Update program files from:`r`n$($d.FileName)`r`n`r`nYour data, runtime, logs and config\urls.txt will be preserved. Changed program files are backed up first.",'Update from ZIP',[System.Windows.Forms.MessageBoxButtons]::OKCancel,[System.Windows.Forms.MessageBoxIcon]::Information)
    if($r -ne [System.Windows.Forms.DialogResult]::OK){return}
    try{
        $x=Invoke-PythonCapture @($MaintenanceScript,'update','--package-root',$PackageRoot,'--zip',$d.FileName)
        if($x.ExitCode -ne 0){throw $x.StdErr}
        $launcher=Join-Path $PackageRoot 'Launch_Downloadly_GUI.vbs'
        [System.Windows.Forms.MessageBox]::Show("Update applied.`r`n`r`n$($x.StdOut)`r`n`r`nThe GUI will restart automatically now.",'Update complete')|Out-Null
        if(Test-Path $launcher){
            $wscript=Join-Path $env:SystemRoot 'System32\wscript.exe'
            Start-Process -FilePath $wscript -ArgumentList @('//nologo',(' + $launcher + '))
            $Form.Close()
        } else {
            [System.Windows.Forms.MessageBox]::Show('Update succeeded, but the launcher was not found. Please reopen the app manually.','Restart required')|Out-Null
        }
    }catch{[System.Windows.Forms.MessageBox]::Show($_.Exception.Message,'Update failed')|Out-Null}
})
$CreateSupport.Add_Click({
    $d=New-Object System.Windows.Forms.FolderBrowserDialog;$d.Description='Choose where to save the support ZIP';$d.SelectedPath=$PackageRoot;if($d.ShowDialog() -ne 'OK'){return}
    $mode=if($SupportMode.SelectedIndex -eq 1){'diagnostic'}else{'code'}
    try{$x=Invoke-PythonCapture @($MaintenanceScript,'support','--package-root',$PackageRoot,'--output-dir',$d.SelectedPath,'--mode',$mode);if($x.ExitCode -ne 0){throw $x.StdErr};$path=$x.StdOut.Trim();[System.Windows.Forms.MessageBox]::Show("Support package created:`r`n$path",'Support package')|Out-Null}catch{[System.Windows.Forms.MessageBox]::Show($_.Exception.Message,'Support package failed')|Out-Null}
})
$CookieBrowser.Add_Click({
    $p=Join-Path $DataBox.Text 'state\downloadly_cookie_snapshot.json'
    if(-not(Test-Path $p)){[System.Windows.Forms.MessageBox]::Show('No extractor cookie snapshot is currently saved. Cookie values are not shown.')|Out-Null;return}
    try{$obj=Get-Content -LiteralPath $p -Raw|ConvertFrom-Json;$lines=@();foreach($c in $obj.cookies){$lines += ('Name={0}  Domain={1}  Path={2}  Secure={3}  Expires={4}  ValueLength={5}' -f $c.name,$c.domain,$c.path,$c.secure,$c.expires,$c.value_length)};[System.Windows.Forms.MessageBox]::Show(($lines -join [Environment]::NewLine),'Downloadly app cookies (values hidden)')|Out-Null}catch{[System.Windows.Forms.MessageBox]::Show('Cookie snapshot could not be read.')|Out-Null}
})
$InstallArgos.Add_Click({try{$py=Find-Python;$psi=New-Object System.Diagnostics.ProcessStartInfo;$psi.FileName=$py;$psi.Arguments='-m pip install argostranslate';$psi.UseShellExecute=$true;$psi.CreateNoWindow=$false;$p=[System.Diagnostics.Process]::Start($psi);$p.WaitForExit();[System.Windows.Forms.MessageBox]::Show('Argos install command finished. Translation remains optional and disabled until selected.')|Out-Null}catch{[System.Windows.Forms.MessageBox]::Show($_.Exception.Message)|Out-Null}})

$Monitor=New-Object System.Windows.Forms.Timer;$Monitor.Interval=700;$Monitor.Add_Tick({
    Refresh-Progress
    if($script:WorkerProcess){
        $script:WorkerProcess.Refresh()
        if($script:WorkerProcess.HasExited){
            $code=$script:WorkerProcess.ExitCode;$StopGraceTimer.Stop();Set-Running $false;$Pause.Enabled=$false;$Resume.Enabled=$false
            $wasUserStop=$script:UserStopRequested;$script:WorkerProcess=$null;$script:StopDeadline=$null
            Refresh-Progress
            if($wasUserStop){
                $StatusLabel.ForeColor=[System.Drawing.Color]::DarkGreen
                if(-not $Resume.Enabled){$Resume.Enabled=$true}
                if($StatusLabel.Text -notmatch 'stopped'){ $StatusLabel.Text='Stopped by user. Saved queue can be resumed.' }
                $script:UserStopRequested=$false
                if($script:CloseAfterStop){$script:CloseAfterStop=$false;$Form.BeginInvoke([System.Action]{$Form.Close()})|Out-Null}
            }elseif($code -ne 0){
                $StatusLabel.ForeColor=[System.Drawing.Color]::DarkRed;$StatusLabel.Text="Worker crashed/exited with code $code. See logs\worker_crash.log and logs\run.log."
            }else{$StatusLabel.ForeColor=[System.Drawing.Color]::DarkGreen}
        }
    }
})
$StopGraceTimer=New-Object System.Windows.Forms.Timer;$StopGraceTimer.Interval=250;$StopGraceTimer.Add_Tick({
    if(-not $script:UserStopRequested){$StopGraceTimer.Stop();return}
    if(-not $script:WorkerProcess -or $script:WorkerProcess.HasExited){$StopGraceTimer.Stop();return}
    if($script:StopDeadline -and (Get-Date) -ge $script:StopDeadline){
        try{
            $StatusLabel.Text='Safe stop timed out; force-stopping worker now. Saved SQLite state will be recovered on Resume.'
            try{[System.IO.File]::AppendAllText((Join-Path $DataBox.Text 'logs\run.log'),"[$((Get-Date).ToString('yyyy-MM-ddTHH:mm:ss'))] FORCE STOP: safe-stop grace expired; terminating worker PID=$($script:WorkerProcess.Id)`r`n",[System.Text.UTF8Encoding]::new($false))}catch{}
            try{& (Join-Path $env:SystemRoot 'System32\taskkill.exe') /PID $script:WorkerProcess.Id /T /F | Out-Null}catch{$script:WorkerProcess.Kill()}
            try{$script:WorkerProcess.WaitForExit(2000)|Out-Null}catch{}
            $progressPath=Join-Path $DataBox.Text 'state\run_progress.json'
            $payload=[ordered]@{status='stopped';phase='stopped';message='Force-stopped by user after 4-second safe-stop grace. Interrupted item will return to pending on Resume.';updated_at=(Get-Date).ToString('s');version=30}
            [System.IO.File]::WriteAllText($progressPath,($payload|ConvertTo-Json -Depth 4),[System.Text.UTF8Encoding]::new($false))
        }catch{
            $StatusLabel.Text="Force stop failed: $($_.Exception.Message)"
        }finally{$StopGraceTimer.Stop()}
    }
})
$ScheduledTimer=New-Object System.Windows.Forms.Timer;$ScheduledTimer.Interval=1000;$ScheduledTimer.Add_Tick({if($script:ScheduledAction -and (Get-Date) -ge $StartPicker.Value){$ScheduledTimer.Stop();$p=$script:ScheduledAction;$script:ScheduledAction=$null;Start-Worker $p}})

$Form.Add_FormClosing({param($sender,$e)
    if($script:CloseAfterStop){$e.Cancel=$true;return}
    if(Test-WorkerRunning){
        $r=[System.Windows.Forms.MessageBox]::Show('A manual worker is still running. The GUI will stop it safely before closing.

OK = Stop worker and close
Cancel = keep GUI open.','Worker is running',[System.Windows.Forms.MessageBoxButtons]::OKCancel,[System.Windows.Forms.MessageBoxIcon]::Warning)
        if($r -eq [System.Windows.Forms.DialogResult]::Cancel){$e.Cancel=$true;return}
        $e.Cancel=$true;$script:CloseAfterStop=$true;$script:UserStopRequested=$true;$script:StopDeadline=(Get-Date).AddSeconds(4)
        New-Item -ItemType File -Force -Path (Join-Path $DataBox.Text 'state\stop.requested')|Out-Null
        $StatusLabel.Text='Closing after worker stops safely...';$StopGraceTimer.Start();$Monitor.Start()
    }
})

if(Attach-ExistingWorker){$Monitor.Start()}
Refresh-Progress
[void]$Form.ShowDialog()
