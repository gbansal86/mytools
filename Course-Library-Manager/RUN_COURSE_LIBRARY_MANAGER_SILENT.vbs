Option Explicit
Dim shell, fso, scriptDir, ps1, cmd

Set shell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")

scriptDir = fso.GetParentFolderName(WScript.ScriptFullName)
ps1 = fso.BuildPath(scriptDir, "Course_Library_Manager.ps1")

cmd = "powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -STA -File " & _
      Chr(34) & ps1 & Chr(34) & " -NoConsole"

' 0 = hidden window, False = do not wait.
shell.Run cmd, 0, False
