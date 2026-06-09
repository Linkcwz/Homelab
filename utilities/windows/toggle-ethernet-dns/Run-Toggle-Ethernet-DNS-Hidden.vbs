' Run-Toggle-Ethernet-DNS-Hidden.vbs
' Launches Toggle-Ethernet-DNS.ps1 without showing a console window.

Set fso = CreateObject("Scripting.FileSystemObject")
Set shell = CreateObject("WScript.Shell")

scriptDir = fso.GetParentFolderName(WScript.ScriptFullName)
scriptPath = fso.BuildPath(scriptDir, "Toggle-Ethernet-DNS.ps1")

If Not fso.FileExists(scriptPath) Then
    MsgBox "Missing script: " & scriptPath, vbCritical, "DNS Toggle"
    WScript.Quit 1
End If

command = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File " & Quote(scriptPath)
shell.Run command, 0, False

Function Quote(value)
    Quote = """" & Replace(value, """", """""") & """"
End Function
