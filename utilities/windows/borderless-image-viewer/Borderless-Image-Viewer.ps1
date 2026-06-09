# Borderless-Image-Viewer.ps1
# Lightweight borderless image viewer with drag/drop and keyboard navigation.

param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]] $Path,
    [switch] $Windowed
)

$ErrorActionPreference = "Stop"

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms

$extensions = @(
    ".avif", ".bmp", ".gif", ".jfif", ".jpe", ".jpeg", ".jpg", ".png",
    ".tif", ".tiff", ".wdp", ".webp"
)

$script:Files = New-Object System.Collections.Generic.List[string]
$script:Index = 0
$script:IsFullscreen = -not $Windowed
$script:WindowedState = $null

function Test-ImagePath {
    param([string] $Candidate)

    if (-not $Candidate -or -not (Test-Path -LiteralPath $Candidate)) {
        return $false
    }

    $item = Get-Item -LiteralPath $Candidate
    if ($item.PSIsContainer) {
        return $true
    }

    return $extensions -contains $item.Extension.ToLowerInvariant()
}

function Expand-ImagePath {
    param([string[]] $InputPath)

    $expanded = New-Object System.Collections.Generic.List[string]
    foreach ($candidate in $InputPath) {
        if (-not (Test-ImagePath $candidate)) {
            continue
        }

        $item = Get-Item -LiteralPath $candidate
        if ($item.PSIsContainer) {
            Get-ChildItem -LiteralPath $item.FullName -File |
                Where-Object { $extensions -contains $_.Extension.ToLowerInvariant() } |
                Sort-Object Name |
                ForEach-Object { $expanded.Add($_.FullName) | Out-Null }
        } else {
            $expanded.Add($item.FullName) | Out-Null
        }
    }

    return @($expanded | Select-Object -Unique)
}

function Open-ImageDialog {
    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    $dialog.Filter = "Images|*.avif;*.bmp;*.gif;*.jfif;*.jpe;*.jpeg;*.jpg;*.png;*.tif;*.tiff;*.wdp;*.webp|All files|*.*"
    $dialog.Multiselect = $true
    $dialog.Title = "Open images"

    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        return @($dialog.FileNames)
    }

    return @()
}

function Set-ImageList {
    param(
        [string[]] $NewFiles,
        [string] $Preferred
    )

    $expanded = Expand-ImagePath -InputPath $NewFiles
    if (-not $expanded -or $expanded.Count -eq 0) {
        return $false
    }

    $script:Files.Clear()
    foreach ($file in $expanded) {
        $script:Files.Add($file) | Out-Null
    }

    $script:Index = 0
    if ($Preferred) {
        $preferredIndex = [Array]::IndexOf($script:Files.ToArray(), (Get-Item -LiteralPath $Preferred).FullName)
        if ($preferredIndex -ge 0) {
            $script:Index = $preferredIndex
        }
    }

    Show-CurrentImage
    return $true
}

function Show-CurrentImage {
    if ($script:Files.Count -eq 0) {
        return
    }

    $file = $script:Files[$script:Index]
    $bitmap = New-Object System.Windows.Media.Imaging.BitmapImage
    $bitmap.BeginInit()
    $bitmap.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
    $bitmap.UriSource = New-Object System.Uri($file)
    $bitmap.EndInit()
    $bitmap.Freeze()

    $script:Image.Source = $bitmap
    $script:Window.Title = [System.IO.Path]::GetFileName($file)
}

function Move-Image {
    param([int] $Delta)

    if ($script:Files.Count -eq 0) {
        return
    }

    $script:Index = ($script:Index + $Delta) % $script:Files.Count
    if ($script:Index -lt 0) {
        $script:Index += $script:Files.Count
    }
    Show-CurrentImage
}

function Set-Fullscreen {
    param([bool] $Enable)

    if ($Enable -eq $script:IsFullscreen) {
        return
    }

    if ($Enable) {
        $script:WindowedState = [pscustomobject]@{
            Left = $script:Window.Left
            Top = $script:Window.Top
            Width = $script:Window.Width
            Height = $script:Window.Height
            WindowState = $script:Window.WindowState
        }
        $script:Window.WindowState = "Maximized"
    } elseif ($script:WindowedState) {
        $script:Window.WindowState = $script:WindowedState.WindowState
        $script:Window.Left = $script:WindowedState.Left
        $script:Window.Top = $script:WindowedState.Top
        $script:Window.Width = $script:WindowedState.Width
        $script:Window.Height = $script:WindowedState.Height
    } else {
        $script:Window.WindowState = "Normal"
    }

    $script:IsFullscreen = $Enable
}

$initialFiles = Expand-ImagePath -InputPath $Path
if (-not $initialFiles -or $initialFiles.Count -eq 0) {
    $initialFiles = Open-ImageDialog
}

if (-not $initialFiles -or $initialFiles.Count -eq 0) {
    exit
}

$script:Window = New-Object System.Windows.Window
$script:Window.WindowStyle = "None"
$script:Window.ResizeMode = "CanResizeWithGrip"
$script:Window.Background = [System.Windows.Media.Brushes]::Black
$script:Window.Width = 1200
$script:Window.Height = 800
$script:Window.MinWidth = 320
$script:Window.MinHeight = 240
$script:Window.WindowStartupLocation = "CenterScreen"
$script:Window.AllowDrop = $true
$script:Window.Topmost = $false

$grid = New-Object System.Windows.Controls.Grid
$grid.Background = [System.Windows.Media.Brushes]::Black

$script:Image = New-Object System.Windows.Controls.Image
$script:Image.Stretch = "Uniform"
$script:Image.HorizontalAlignment = "Stretch"
$script:Image.VerticalAlignment = "Stretch"
$script:Image.SnapsToDevicePixels = $true

$grid.Children.Add($script:Image) | Out-Null
$script:Window.Content = $grid

$script:Window.Add_Loaded({
    if ($script:IsFullscreen) {
        $script:Window.WindowState = "Maximized"
    }
    Show-CurrentImage
})

$script:Window.Add_KeyDown({
    param($sender, $event)

    switch ($event.Key) {
        "Right" { Move-Image 1; $event.Handled = $true }
        "Space" { Move-Image 1; $event.Handled = $true }
        "Left" { Move-Image -1; $event.Handled = $true }
        "Back" { Move-Image -1; $event.Handled = $true }
        "F" { Set-Fullscreen (-not $script:IsFullscreen); $event.Handled = $true }
        "F11" { Set-Fullscreen (-not $script:IsFullscreen); $event.Handled = $true }
        "O" {
            $opened = Open-ImageDialog
            if ($opened -and $opened.Count -gt 0) {
                Set-ImageList -NewFiles $opened | Out-Null
            }
            $event.Handled = $true
        }
        "Escape" { $script:Window.Close(); $event.Handled = $true }
    }
})

$script:Window.Add_Drop({
    param($sender, $event)

    if ($event.Data.GetDataPresent([System.Windows.DataFormats]::FileDrop)) {
        $dropped = $event.Data.GetData([System.Windows.DataFormats]::FileDrop)
        Set-ImageList -NewFiles $dropped -Preferred $dropped[0] | Out-Null
        $event.Handled = $true
    }
})

$script:Window.Add_MouseLeftButtonDown({
    param($sender, $event)

    if ($event.ClickCount -ge 2) {
        Set-Fullscreen (-not $script:IsFullscreen)
        $event.Handled = $true
        return
    }

    if (-not $script:IsFullscreen) {
        try {
            $script:Window.DragMove()
        } catch {
        }
    }
})

Set-ImageList -NewFiles $initialFiles | Out-Null
$script:Window.ShowDialog() | Out-Null
