Option Explicit
Dim shell, fso, env, base, appDir, bootstrap, gui, cmd, preflight, rc
Set shell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
Set env = shell.Environment("Process")
base = fso.GetParentFolderName(WScript.ScriptFullName)
appDir = fso.BuildPath(base, "app")
bootstrap = fso.BuildPath(appDir, "Bootstrap.ps1")
gui = fso.BuildPath(appDir, "Downloadly_GUI.ps1")

env("DOWNLOADLY_BOOTSTRAP_PREFLIGHT") = bootstrap
env("DOWNLOADLY_GUI_PREFLIGHT") = gui

' Parse both PowerShell files before executing either one.  The command itself
' contains no interpolated file paths, which keeps quoting simple and reliable.
preflight = "$bad=$false;foreach($f in @($env:DOWNLOADLY_BOOTSTRAP_PREFLIGHT,$env:DOWNLOADLY_GUI_PREFLIGHT)){$t=$null;$e=$null;[void][System.Management.Automation.Language.Parser]::ParseFile($f,[ref]$t,[ref]$e);if($e.Count -gt 0){$bad=$true}};if($bad){exit 20}else{exit 0}"
cmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Command """ & preflight & """"
rc = shell.Run(cmd, 0, True)
If rc <> 0 Then
    MsgBox "PowerShell syntax preflight failed. The application was not started." & vbCrLf & vbCrLf & _
           "Use a fresh copy of the package or inspect app\Bootstrap.ps1 and app\Downloadly_GUI.ps1.", 16, "Downloadly Extractor - Preflight Error"
    WScript.Quit rc
End If

cmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & bootstrap & """"
shell.Run cmd, 0, False