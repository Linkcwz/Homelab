<#
.SYNOPSIS
    Spawn a Windows Terminal window and screenshot it so an agent can visually
    self-verify terminal rendering (prompt glyphs, powerline separators, colors).

.DESCRIPTION
    There is no GUI-free way to "see" how Windows Terminal paints glyphs, so an
    agent must capture a real window. This helper launches a dedicated WT window
    (its own -w name so it does not disturb the operator's windows), waits for
    the profile/rice to finish, captures the window with PrintWindow
    (PW_RENDERFULLCONTENT, works even when occluded), saves a PNG, and closes
    just that window via WM_CLOSE (never killing the shared WindowsTerminal.exe
    process).

    Why GetForegroundWindow instead of FindWindow-by-title: the configured
    "PowerShell" profile sets suppressApplicationTitle:true, so --title is
    ignored and title matching fails. A freshly launched WT window takes
    foreground, so GetForegroundWindow is the reliable handle.

.EXAMPLE
    pwsh -NoProfile -File Capture-Terminal.ps1 -OutFile "$env:TEMP\verify.png"

.EXAMPLE
    pwsh -NoProfile -File Capture-Terminal.ps1 -Command "git -C $HOME\project status -s" -OutFile out.png
#>
[CmdletBinding()]
param(
    [string]$Profile = 'PowerShell',
    [string]$Command,
    [string]$OutFile = "$env:TEMP\wt-self-verify.png",
    [int]$SettleMs = 6000,
    [switch]$KeepOpen
)

Add-Type @"
using System;
using System.Runtime.InteropServices;
public class WtCap {
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr dc, uint f);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
}
"@ -ReferencedAssemblies System.Drawing
Add-Type -AssemblyName System.Drawing

$winName = 'cverify-' + (Get-Random)
if ($Command) {
    $wtArgs = @('-w', $winName, 'new-tab', 'pwsh.exe', '-NoExit', '-Command', $Command)
} else {
    $wtArgs = @('-w', $winName, 'new-tab', '--profile', $Profile)
}

Start-Process wt.exe -ArgumentList $wtArgs
Start-Sleep -Milliseconds $SettleMs

$hwnd = [WtCap]::GetForegroundWindow()
$r = New-Object WtCap+RECT
[void][WtCap]::GetWindowRect($hwnd, [ref]$r)
$w = $r.Right - $r.Left
$h = $r.Bottom - $r.Top
if ($w -le 0 -or $h -le 0) { throw "Foreground window has no client area (w=$w h=$h); WT may not have taken focus." }

$bmp = New-Object System.Drawing.Bitmap $w, $h
$g = [System.Drawing.Graphics]::FromImage($bmp)
$hdc = $g.GetHdc()
$ok = [WtCap]::PrintWindow($hwnd, $hdc, 2)  # 2 = PW_RENDERFULLCONTENT
$g.ReleaseHdc($hdc)
$bmp.Save($OutFile, [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $bmp.Dispose()

if (-not $KeepOpen) {
    [void][WtCap]::PostMessage($hwnd, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero)  # WM_CLOSE, this window only
}

[pscustomobject]@{ Ok = $ok; Width = $w; Height = $h; OutFile = $OutFile } | Format-List
