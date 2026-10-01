Option Explicit
Dim shell, fso, base, bootstrap, cmd
Set shell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
base = fso.GetParentFolderName(WScript.ScriptFullName)
bootstrap = fso.BuildPath(fso.BuildPath(base, "app"), "Bootstrap.ps1")
cmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & bootstrap & """ -Repair -NoLaunch"
shell.Run cmd, 0, False
