' Run-Borderless-Image-Viewer-Hidden.vbs
' Launches Borderless-Image-Viewer.cmd without showing a console window.

Set fso = CreateObject("Scripting.FileSystemObject")
Set shell = CreateObject("WScript.Shell")

scriptDir = fso.GetParentFolderName(WScript.ScriptFullName)
scriptPath = fso.BuildPath(scriptDir, "Borderless-Image-Viewer.cmd")

If Not fso.FileExists(scriptPath) Then
    MsgBox "Missing script: " & scriptPath, vbCritical, "Borderless Image Viewer"
    WScript.Quit 1
End If

command = "cmd.exe /c " & Quote(scriptPath)
For Each arg In WScript.Arguments
    command = command & " " & Quote(arg)
Next

shell.Run command, 0, False

Function Quote(value)
    Quote = """" & Replace(value, """", """""") & """"
End Function
