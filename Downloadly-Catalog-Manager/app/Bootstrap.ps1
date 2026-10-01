param(
    [switch]$Repair,
    [switch]$NoLaunch
)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$AppDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$PackageRoot = Split-Path -Parent $AppDir
$RuntimeDir = Join-Path $PackageRoot 'runtime'
$LogsDir = Join-Path $PackageRoot 'logs'
New-Item -ItemType Directory -Force -Path $RuntimeDir,$LogsDir | Out-Null
$VenvDir = Join-Path $RuntimeDir '.venv'
$VenvPython = Join-Path $VenvDir 'Scripts\python.exe'
$Requirements = Join-Path $AppDir 'requirements.txt'
$GuiScript = Join-Path $AppDir 'Downloadly_GUI.ps1'
$SetupLog = Join-Path $LogsDir 'setup.log'

function Q([string]$s) { return '"' + ($s -replace '"','\"') + '"' }

function Append-SetupLog([string]$Text) {
    try {
        $stamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        Add-Content -LiteralPath $SetupLog -Value "[$stamp] $Text" -Encoding UTF8
    } catch { }
}

function Find-SystemPython {
    # Prefer a real python.exe first.  Do not hard-code the legacy `py -3`
    # selector: on some Python 3.14/Windows launcher setups it can be forwarded
    # to python.exe itself, which fails with "Unknown option: -3".
    $candidates = @()
    $python = Get-Command python.exe -ErrorAction SilentlyContinue
    if ($python) { $candidates += [PSCustomObject]@{ File=$python.Source; Prefix=@(); Label='python.exe' } }
    $python3 = Get-Command python3.exe -ErrorAction SilentlyContinue
    if ($python3 -and (-not $python -or $python3.Source -ne $python.Source)) {
        $candidates += [PSCustomObject]@{ File=$python3.Source; Prefix=@(); Label='python3.exe' }
    }
    $py = Get-Command py.exe -ErrorAction SilentlyContinue
    if ($py) { $candidates += [PSCustomObject]@{ File=$py.Source; Prefix=@(); Label='py.exe' } }

    foreach ($candidate in $candidates) {
        try {
            $probeArgs = @($candidate.Prefix) + @('-c','import sys; print(sys.version_info[0]); print(sys.executable)')
            $probe = Run-ProcessHidden $candidate.File $probeArgs 30
            $lines = @($probe.StdOut -split "`r?`n" | Where-Object { $_.Trim() -ne '' })
            if ($probe.ExitCode -eq 0 -and $lines.Count -ge 1 -and $lines[0].Trim() -eq '3') {
                Append-SetupLog "Python candidate OK: $($candidate.Label) -> $($candidate.File)"
                return $candidate
            }
            Append-SetupLog "Rejected Python candidate $($candidate.File): exit=$($probe.ExitCode) stderr=$($probe.StdErr.Trim())"
        } catch {
            Append-SetupLog "Rejected Python candidate $($candidate.File): $($_.Exception.Message)"
        }
    }
    return $null
}


function Assert-PowerShellSyntax([string]$Path) {
    $tokens = $null
    $parseErrors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tokens, [ref]$parseErrors)
    if ($parseErrors -and $parseErrors.Count -gt 0) {
        $details = ($parseErrors | ForEach-Object {
            $line = $_.Extent.StartLineNumber
            $col = $_.Extent.StartColumnNumber
            "Line $line, col ${col}: $($_.Message)"
        }) -join "`r`n"
        throw "PowerShell syntax check failed for $Path.`r`n$details"
    }
}

function Run-ProcessHidden([string]$File, [string[]]$ArgumentValues, [int]$TimeoutSeconds = 0) {
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $File
    $psi.Arguments = ($ArgumentValues | ForEach-Object { Q $_ }) -join ' '
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $psi
    [void]$p.Start()
    $stdoutTask = $p.StandardOutput.ReadToEndAsync()
    $stderrTask = $p.StandardError.ReadToEndAsync()
    $startedAt = Get-Date
    $timedOut = $false
    while (-not $p.HasExited) {
        [System.Windows.Forms.Application]::DoEvents()
        if ($TimeoutSeconds -gt 0 -and ((Get-Date) - $startedAt).TotalSeconds -ge $TimeoutSeconds) {
            $timedOut = $true
            try { $p.Kill() } catch { }
            break
        }
        Start-Sleep -Milliseconds 100
    }
    if ($timedOut) {
        try { $p.WaitForExit(3000) } catch { }
    }
    $out = $stdoutTask.Result
    $err = $stderrTask.Result
    if ($timedOut) {
        $err = ("Process timed out after $TimeoutSeconds seconds. " + $err).Trim()
    }
    if ($out) { Append-SetupLog $out.Trim() }
    if ($err) { Append-SetupLog $err.Trim() }
    $exitCode = if ($timedOut) { -999 } else { $p.ExitCode }
    return [PSCustomObject]@{ ExitCode=$exitCode; StdOut=$out; StdErr=$err; TimedOut=$timedOut }
}

$Form = New-Object System.Windows.Forms.Form
$Form.Text = 'Downloadly Catalog Manager V30 - First Run Setup'
$Form.StartPosition = 'CenterScreen'
$Form.Size = New-Object System.Drawing.Size(620,190)
$Form.FormBorderStyle = 'FixedDialog'
$Form.MaximizeBox = $false
$Form.MinimizeBox = $false
$Form.TopMost = $true
$Form.Font = New-Object System.Drawing.Font('Segoe UI',9)

$Title = New-Object System.Windows.Forms.Label
$Title.Text = 'Preparing Downloadly Catalog Manager V30'
$Title.Location = New-Object System.Drawing.Point(20,18)
$Title.Size = New-Object System.Drawing.Size(560,28)
$Title.Font = New-Object System.Drawing.Font('Segoe UI',12,[System.Drawing.FontStyle]::Bold)
$Form.Controls.Add($Title)

$Status = New-Object System.Windows.Forms.Label
$Status.Text = 'Checking local Python environment...'
$Status.Location = New-Object System.Drawing.Point(20,58)
$Status.Size = New-Object System.Drawing.Size(560,42)
$Form.Controls.Add($Status)

$Bar = New-Object System.Windows.Forms.ProgressBar
$Bar.Location = New-Object System.Drawing.Point(20,108)
$Bar.Size = New-Object System.Drawing.Size(560,22)
$Bar.Style = 'Marquee'
$Bar.MarqueeAnimationSpeed = 25
$Form.Controls.Add($Bar)

$Form.Show()
[System.Windows.Forms.Application]::DoEvents()

try {
    # Clean up a half-created environment left by a failed/aborted setup.
    if ((Test-Path $VenvDir) -and -not (Test-Path $VenvPython)) {
        Append-SetupLog "Removing incomplete venv before retry: $VenvDir"
        Remove-Item -LiteralPath $VenvDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    if ($Repair -and (Test-Path $VenvDir)) {
        $Status.Text = 'Repair requested: recreating the local Python environment...'
        [System.Windows.Forms.Application]::DoEvents()
        Remove-Item -LiteralPath $VenvDir -Recurse -Force -ErrorAction Stop
    }

    $needBaseInstall = $true
    if (Test-Path $VenvPython) {
        $Status.Text = 'Checking required Python packages...'
        [System.Windows.Forms.Application]::DoEvents()
        $check = Run-ProcessHidden $VenvPython @('-c','import requests,bs4,lxml,openpyxl,selenium')
        if ($check.ExitCode -eq 0) { $needBaseInstall = $false }
    }

    if ($needBaseInstall) {
        $sysPy = Find-SystemPython
        if (-not $sysPy) {
            throw 'Python 3 was not found. Install Python 3 from python.org and enable "Add Python to PATH", then launch this app again.'
        }

        if (-not (Test-Path $VenvPython)) {
            $Status.Text = 'Creating a private Python environment (.venv)...'
            [System.Windows.Forms.Application]::DoEvents()
            Append-SetupLog "Creating venv with $($sysPy.File)"
            $venv = Run-ProcessHidden $sysPy.File (@($sysPy.Prefix) + @('-m','venv',$VenvDir)) 180
            if ($venv.ExitCode -ne 0 -or -not (Test-Path $VenvPython)) {
                throw "Could not create .venv.`r`n$($venv.StdErr)"
            }
        }

        $Status.Text = 'Preparing pip...'
        [System.Windows.Forms.Application]::DoEvents()
        $pip = Run-ProcessHidden $VenvPython @('-m','ensurepip','--upgrade')
        if ($pip.ExitCode -ne 0) { Append-SetupLog 'ensurepip returned a non-zero code; continuing to pip check.' }

        $Status.Text = 'Installing required packages (requests, BeautifulSoup, lxml, openpyxl, Selenium)...'
        [System.Windows.Forms.Application]::DoEvents()
        $up = Run-ProcessHidden $VenvPython @('-m','pip','install','--disable-pip-version-check','--upgrade','pip','setuptools','wheel')
        if ($up.ExitCode -ne 0) { Append-SetupLog 'pip/setuptools/wheel upgrade failed; trying requirements anyway.' }
        $install = Run-ProcessHidden $VenvPython @('-m','pip','install','--disable-pip-version-check','-r',$Requirements)
        if ($install.ExitCode -ne 0) {
            throw "Package installation failed.`r`n`r`n$($install.StdErr)`r`n`r`nSee setup.log for details."
        }

        $Status.Text = 'Verifying installation...'
        [System.Windows.Forms.Application]::DoEvents()
        $check2 = Run-ProcessHidden $VenvPython @('-c','import requests,bs4,lxml,openpyxl,selenium')
        if ($check2.ExitCode -ne 0) {
            throw "Required packages still cannot be imported.`r`n$($check2.StdErr)"
        }
    }

    $env:DOWNLOADLY_PYTHON = $VenvPython
    Append-SetupLog "Setup OK. Python=$VenvPython"
    $Status.Text = 'Setup complete. Opening the application...'
    $Bar.Style = 'Continuous'; $Bar.Minimum = 0; $Bar.Maximum = 100; $Bar.Value = 100
    [System.Windows.Forms.Application]::DoEvents()
    Start-Sleep -Milliseconds 350
    $Form.Close()

    if (-not $NoLaunch) {
        $Status.Text = 'Validating PowerShell GUI syntax...'
        [System.Windows.Forms.Application]::DoEvents()
        Assert-PowerShellSyntax $GuiScript
        Append-SetupLog "PowerShell syntax OK: $GuiScript"
        & $GuiScript
    } else {
        [System.Windows.Forms.MessageBox]::Show('Required packages are installed and verified.', 'Setup Complete', 'OK', 'Information') | Out-Null
    }
} catch {
    Append-SetupLog ("ERROR: " + $_.Exception.Message)
    $Form.Close()
    [System.Windows.Forms.MessageBox]::Show(
        $_.Exception.Message + "`r`n`r`nSetup log: " + $SetupLog,
        'Setup Error', 'OK', 'Error'
    ) | Out-Null
    exit 1
}

# V22 compatibility marker retained for legacy regression tests.
