' Run-Restart-Explorer-Hidden.vbs
' Launches Restart-Explorer.cmd without showing a console window (window style 0).

Set fso = CreateObject("Scripting.FileSystemObject")
Set shell = CreateObject("WScript.Shell")

scriptDir = fso.GetParentFolderName(WScript.ScriptFullName)
scriptPath = fso.BuildPath(scriptDir, "Restart-Explorer.cmd")

If Not fso.FileExists(scriptPath) Then
    MsgBox "Missing script: " & scriptPath, vbCritical, "Restart Explorer"
    WScript.Quit 1
End If

shell.Run "cmd.exe /c " & Quote(scriptPath), 0, False

Function Quote(value)
    Quote = """" & Replace(value, """", """""") & """"
End Function
