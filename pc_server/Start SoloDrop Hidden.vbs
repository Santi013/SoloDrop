Option Explicit

Dim fso, shell, appDir, logDir, command

Set fso = CreateObject("Scripting.FileSystemObject")
Set shell = CreateObject("WScript.Shell")

appDir = fso.GetParentFolderName(WScript.ScriptFullName)
logDir = appDir & "\logs"

If Not fso.FolderExists(logDir) Then
    fso.CreateFolder(logDir)
End If

command = "powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File " & _
          Quote(appDir & "\SoloDrop Tray.ps1")

shell.Run command, 0, False

Function Quote(value)
    Quote = Chr(34) & value & Chr(34)
End Function
