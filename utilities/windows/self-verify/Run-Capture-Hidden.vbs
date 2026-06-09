' Hidden launcher for Capture-Terminal.ps1 (Windows console hygiene: the driver
' pwsh must not flash a window). The captured Windows Terminal window itself is
' intentionally visible because it is the artifact being screenshotted.
' Window style 0 = hidden. Pass-through args go to the .ps1.
Option Explicit
Dim sh, fso, scriptDir, psArgs, i
Set sh = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
scriptDir = fso.GetParentFolderName(WScript.ScriptFullName)
psArgs = ""
For i = 0 To WScript.Arguments.Count - 1
    psArgs = psArgs & " " & Chr(34) & WScript.Arguments(i) & Chr(34)
Next
sh.Run "pwsh.exe -NoProfile -ExecutionPolicy Bypass -File " & Chr(34) & scriptDir & "\Capture-Terminal.ps1" & Chr(34) & psArgs, 0, False
