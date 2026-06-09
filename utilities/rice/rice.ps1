param(
    [string]$Theme = "",
    [switch]$NoPrompt,
    [switch]$SkipFontInstall,
    [switch]$SkipPackageInstall,
    [switch]$SkipTerminals,
    [switch]$WithAgentConfig
)

$ErrorActionPreference = "Stop"

if ($env:OS -ne "Windows_NT") {
    throw "rice.ps1 is the Windows ricer. On Linux, run ./rice.sh."
}

$ManagedStart = "# --- rice-managed start ---"
$ManagedEnd = "# --- rice-managed end ---"
$FontUrl = "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FiraCode.zip"
$FontFace = "FiraCode Nerd Font Mono"
$ScriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$HomePath = [Environment]::GetFolderPath("UserProfile")
$UserBin = Join-Path $HomePath ".local\bin"
$ThemeDir = Join-Path $HomePath ".cache\oh-my-posh\themes"
$ThemeDest = Join-Path $ThemeDir "atomic.omp.json"
$DefaultTheme = "solarized-dark"
$ThemeNames = @("solarized-dark", "solarized-light", "tokyonight")

# Chosen-theme state (set by Select-Theme)
$script:ThemeName = $DefaultTheme
$script:ThemeData = $null

function Write-Step {
    param([string]$Message)
    Write-Host "==> $Message"
}

function Ensure-Directory {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Refresh-ProcessPath {
    $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path = @($machinePath, $userPath) -join ";"
}

# ---------------------------------------------------------------------------
# Theme registry + interactive picker
# ---------------------------------------------------------------------------

function Get-ThemeColors {
    param([string]$Name)
    switch ($Name) {
        'solarized-dark' {
            return @{
                Bg = '#002b36'; Fg = '#839496'; Cursor = '#839496'; SelBg = '#073642'
                Palette = @('#073642', '#dc322f', '#859900', '#b58900', '#268bd2', '#d33682', '#2aa198', '#eee8d5',
                            '#002b36', '#cb4b16', '#586e75', '#657b83', '#839496', '#6c71c4', '#93a1a1', '#fdf6e3')
                BatTheme = 'Solarized (dark)'
            }
        }
        'solarized-light' {
            return @{
                Bg = '#fdf6e3'; Fg = '#657b83'; Cursor = '#657b83'; SelBg = '#eee8d5'
                Palette = @('#073642', '#dc322f', '#859900', '#b58900', '#268bd2', '#d33682', '#2aa198', '#eee8d5',
                            '#002b36', '#cb4b16', '#586e75', '#657b83', '#839496', '#6c71c4', '#93a1a1', '#fdf6e3')
                BatTheme = 'Solarized (light)'
            }
        }
        'tokyonight' {
            return @{
                Bg = '#1a1b26'; Fg = '#c0caf5'; Cursor = '#c0caf5'; SelBg = '#283457'
                Palette = @('#15161e', '#f7768e', '#9ece6a', '#e0af68', '#7aa2f7', '#bb9af7', '#7dcfff', '#a9b1d6',
                            '#414868', '#f7768e', '#9ece6a', '#e0af68', '#7aa2f7', '#bb9af7', '#7dcfff', '#c0caf5')
                BatTheme = 'base16'
            }
        }
        default { return $null }
    }
}

function ConvertFrom-HexColor {
    param([string]$Hex)
    $h = $Hex.TrimStart('#')
    return @([Convert]::ToInt32($h.Substring(0, 2), 16), [Convert]::ToInt32($h.Substring(2, 2), 16), [Convert]::ToInt32($h.Substring(4, 2), 16))
}

function Show-ThemePreview {
    param([string]$Name)
    $t = Get-ThemeColors $Name
    if (-not $t) { return }
    $e = [char]27
    $line = ("  {0,-16} " -f $Name)
    foreach ($c in $t.Palette) {
        $rgb = ConvertFrom-HexColor $c
        $line += "$e[48;2;$($rgb[0]);$($rgb[1]);$($rgb[2])m  $e[0m"
    }
    $bg = ConvertFrom-HexColor $t.Bg
    $fg = ConvertFrom-HexColor $t.Fg
    $line += "  $e[48;2;$($bg[0]);$($bg[1]);$($bg[2])m$e[38;2;$($fg[0]);$($fg[1]);$($fg[2])m Aa `$ ~ $e[0m"
    Write-Host $line
}

function Select-Theme {
    if ($Theme) {
        if ($Theme -eq 'none') { $script:ThemeName = 'none'; $script:ThemeData = $null; Write-Step "Theme: none (font only)"; return }
        $data = Get-ThemeColors $Theme
        if (-not $data) { throw "Unknown theme: $Theme (use solarized-dark | solarized-light | tokyonight | none)" }
        $script:ThemeName = $Theme; $script:ThemeData = $data; Write-Step "Theme: $Theme (from -Theme)"; return
    }
    if ($NoPrompt -or [Console]::IsInputRedirected) {
        $script:ThemeName = $DefaultTheme; $script:ThemeData = Get-ThemeColors $DefaultTheme
        Write-Step "Theme: $DefaultTheme (default, non-interactive)"; return
    }
    Write-Host ""
    Write-Host "  Choose a terminal color theme - applied to every terminal found:"
    Write-Host ""
    $i = 1
    foreach ($n in $ThemeNames) { Write-Host -NoNewline ("  {0})" -f $i); Show-ThemePreview $n; $i++ }
    Write-Host ("  {0}) none  (keep current colors; set font only)" -f $i)
    Write-Host ""
    $choice = Read-Host ("  Selection [1-{0}, Enter = 1 ({1})]" -f $i, $DefaultTheme)
    if ([string]::IsNullOrWhiteSpace($choice)) { $choice = "1" }
    if ($choice -eq "$i" -or $choice -eq 'none') { $script:ThemeName = 'none'; $script:ThemeData = $null; Write-Step "Theme: none (font only)"; return }
    $picked = $null
    if ($choice -match '^\d+$' -and [int]$choice -ge 1 -and [int]$choice -le $ThemeNames.Count) {
        $picked = $ThemeNames[[int]$choice - 1]
    } elseif (Get-ThemeColors $choice) {
        $picked = $choice
    }
    if (-not $picked) { $picked = $DefaultTheme }
    $script:ThemeName = $picked; $script:ThemeData = Get-ThemeColors $picked
    Write-Step "Theme: $picked"
}

# ---------------------------------------------------------------------------
# Installers
# ---------------------------------------------------------------------------

function Install-WingetPackage {
    param(
        [Parameter(Mandatory)][string]$Id,
        [Parameter(Mandatory)][string]$Name,
        [switch]$Optional
    )
    if ($SkipPackageInstall) { Write-Step "Skipping package install for $Name"; return }
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Warning "winget is not available; cannot install $Name automatically."
        return
    }
    $installed = & winget list --id $Id --exact --source winget 2>$null
    if ($LASTEXITCODE -eq 0 -and ($installed -join "`n") -match [regex]::Escape($Id)) {
        Write-Step "$Name already installed"; return
    }
    Write-Step "Installing $Name"
    & winget install --id $Id --exact --source winget --accept-source-agreements --accept-package-agreements
    if ($LASTEXITCODE -ne 0) {
        if ($Optional) { Write-Warning "Optional package $Name failed to install; continuing." }
        else { Write-Warning "winget install failed for $Name (exit $LASTEXITCODE); continuing." }
    }
    Refresh-ProcessPath
}

function Install-QolTools {
    Install-WingetPackage -Id "eza-community.eza" -Name "eza" -Optional
    Install-WingetPackage -Id "sharkdp.bat" -Name "bat" -Optional
    Install-WingetPackage -Id "BurntSushi.ripgrep.MSVC" -Name "ripgrep" -Optional
    Install-WingetPackage -Id "sharkdp.fd" -Name "fd" -Optional
    Install-WingetPackage -Id "junegunn.fzf" -Name "fzf" -Optional
    Install-WingetPackage -Id "ajeetdsouza.zoxide" -Name "zoxide" -Optional
    if (-not $SkipPackageInstall -and -not (Get-Module -ListAvailable PSFzf)) {
        try {
            Write-Step "Installing PSFzf module (CurrentUser)"
            if (-not (Get-PackageProvider -ListAvailable -Name NuGet -ErrorAction SilentlyContinue)) {
                Install-PackageProvider -Name NuGet -Scope CurrentUser -Force -ErrorAction SilentlyContinue | Out-Null
            }
            Install-Module PSFzf -Scope CurrentUser -Force -ErrorAction Stop
        } catch { Write-Warning "PSFzf module not installed: $($_.Exception.Message)" }
    }
}

function Install-FiraCodeNerdFont {
    if ($SkipFontInstall) { Write-Step "Skipping font install"; return }
    $fontRegistry = "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts"
    $existing = Get-ItemProperty -Path $fontRegistry -ErrorAction SilentlyContinue
    if ($existing -and (($existing.PSObject.Properties.Name -join "`n") -match "FiraCode")) {
        Write-Step "FiraCode Nerd Font already appears to be installed"; return
    }
    $fontDir = Join-Path $env:LOCALAPPDATA "Microsoft\Windows\Fonts"
    Ensure-Directory $fontDir
    $tempDir = Join-Path ([IO.Path]::GetTempPath()) ("rice-fonts-" + [Guid]::NewGuid().ToString("N"))
    $zipPath = Join-Path $tempDir "FiraCode.zip"
    Ensure-Directory $tempDir
    try {
        Write-Step "Downloading FiraCode Nerd Font"
        Invoke-WebRequest -Uri $FontUrl -OutFile $zipPath -UseBasicParsing
        Expand-Archive -LiteralPath $zipPath -DestinationPath $tempDir -Force
        $fonts = Get-ChildItem -LiteralPath $tempDir -Filter "*.ttf" -Recurse
        foreach ($font in $fonts) {
            Copy-Item -LiteralPath $font.FullName -Destination (Join-Path $fontDir $font.Name) -Force
            $displayName = [IO.Path]::GetFileNameWithoutExtension($font.Name) + " (TrueType)"
            New-ItemProperty -Path $fontRegistry -Name $displayName -Value $font.Name -PropertyType String -Force | Out-Null
        }
        Write-Step "Installed $($fonts.Count) FiraCode Nerd Font files"
    } catch {
        Write-Warning "Font install failed: $($_.Exception.Message)"
    } finally {
        Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Install-AtomicTheme {
    Ensure-Directory $ThemeDir
    # Custom atomic oh-my-posh theme inlined so rice.ps1 is a single self-contained file.
    $json = @'
{
  "$schema": "https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/schema.json",
  "blocks": [

    {
      "alignment": "left",
      "segments": [
        {
          "background": "#0077c2",
          "foreground": "#ffffff",
          "leading_diamond": "\u256d\u2500\ue0b6",
          "style": "diamond",
          "template": "\uf120 {{ .Name }} ",
          "type": "shell"
        },
        {
          "background": "#ef5350",
          "foreground": "#FFFB38",
          "style": "diamond",
          "template": "<parentBackground>\ue0b0</> \uf292 ",
          "type": "root"
        },
        {
          "background": "#FF9248",
          "foreground": "#2d3436",
          "powerline_symbol": "\ue0b0",
          "properties": {
            "folder_icon": " \uf07b ",
            "home_icon": "\ue617",
            "style": "folder"
          },
          "style": "powerline",
          "template": " \uf07b\uea9c {{ .Path }} ",
          "type": "path"
        },
        {
          "background": "#FFFB38",
          "background_templates": [
            "{{ if or (.Working.Changed) (.Staging.Changed) }}#ffeb95{{ end }}",
            "{{ if and (gt .Ahead 0) (gt .Behind 0) }}#c5e478{{ end }}",
            "{{ if gt .Ahead 0 }}#C792EA{{ end }}",
            "{{ if gt .Behind 0 }}#C792EA{{ end }}"
          ],
          "foreground": "#011627",
          "powerline_symbol": "\ue0b0",
          "properties": {
            "branch_icon": "\ue725 ",
            "fetch_status": true,
            "fetch_upstream_icon": true
          },
          "style": "powerline",
          "template": " {{ .UpstreamIcon }}{{ .HEAD }}{{if .BranchStatus }} {{ .BranchStatus }}{{ end }}{{ if .Working.Changed }} \uf044 {{ .Working.String }}{{ end }}{{ if and (.Working.Changed) (.Staging.Changed) }} |{{ end }}{{ if .Staging.Changed }}<#ef5350> \uf046 {{ .Staging.String }}</>{{ end }} ",
          "type": "git"
        },
        {
          "background": "#83769c",
          "foreground": "#ffffff",
          "properties": {
            "style": "roundrock",
            "threshold": 0
          },
          "style": "diamond",
          "template": " \ueba2 {{ .FormattedMs }}\u2800",
          "trailing_diamond": "\ue0b4",
          "type": "executiontime"
        }
      ],
      "type": "prompt"
    },
    {
      "alignment": "right",
      "segments": [
        {
          "background": "#303030",
          "foreground": "#3C873A",
          "leading_diamond": "\ue0b6",
          "properties": {
            "fetch_package_manager": true,
            "npm_icon": " <#cc3a3a>\ue5fa</> ",
            "yarn_icon": " <#348cba>\ue6a7</>"
          },
          "style": "diamond",
          "template": "\ue718 {{ if .PackageManagerIcon }}{{ .PackageManagerIcon }} {{ end }}{{ .Full }}",
          "trailing_diamond": "\ue0b4 ",
          "type": "node"
        },
        {
          "background": "#306998",
          "foreground": "#FFE873",
          "leading_diamond": "\ue0b6",
          "style": "diamond",
          "template": "\ue235 {{ if .Error }}{{ .Error }}{{ else }}{{ if .Venv }}{{ .Venv }} {{ end }}{{ .Full }}{{ end }}",
          "trailing_diamond": "\ue0b4 ",
          "type": "python"
        },
        {
          "background": "#0e8ac8",
          "foreground": "#ffffff",
          "leading_diamond": "\ue0b6",
          "style": "diamond",
          "template": "\ue738 {{ if .Error }}{{ .Error }}{{ else }}{{ .Full }}{{ end }}",
          "trailing_diamond": "\ue0b4 ",
          "type": "java"
        },
        {
          "background": "#0e0e0e",
          "foreground": "#0d6da8",
          "leading_diamond": "\ue0b6",
          "style": "diamond",
          "template": "\ue77f {{ if .Unsupported }}\uf071{{ else }}{{ .Full }}{{ end }}",
          "trailing_diamond": "\ue0b4 ",
          "type": "dotnet"
        },
        {
          "background": "#ffffff",
          "foreground": "#06aad5",
          "leading_diamond": "\ue0b6",
          "style": "diamond",
          "template": "\ue626 {{ if .Error }}{{ .Error }}{{ else }}{{ .Full }}{{ end }}",
          "trailing_diamond": "\ue0b4 ",
          "type": "go"
        },
        {
          "background": "#f3f0ec",
          "foreground": "#925837",
          "leading_diamond": "\ue0b6",
          "style": "diamond",
          "template": "\ue7a8 {{ if .Error }}{{ .Error }}{{ else }}{{ .Full }}{{ end }}",
          "trailing_diamond": "\ue0b4 ",
          "type": "rust"
        },
        {
          "background": "#e1e8e9",
          "foreground": "#055b9c",
          "leading_diamond": " \ue0b6",
          "style": "diamond",
          "template": "\ue798 {{ if .Error }}{{ .Error }}{{ else }}{{ .Full }}{{ end }}",
          "trailing_diamond": "\ue0b4 ",
          "type": "dart"
        },
        {
          "background": "#ffffff",
          "foreground": "#ce092f",
          "leading_diamond": " \ue0b6",
          "style": "diamond",
          "template": "\ue753 {{ if .Error }}{{ .Error }}{{ else }}{{ .Full }}{{ end }}",
          "trailing_diamond": "\ue0b4 ",
          "type": "angular"
        },
        {
          "background": "#ffffff",
          "foreground": "#de1f84",
          "leading_diamond": " \ue0b6",
          "style": "diamond",
          "template": "\u03b1 {{ if .Error }}{{ .Error }}{{ else }}{{ .Full }}{{ end }}",
          "trailing_diamond": "\ue0b4 ",
          "type": "aurelia"
        },
        {
          "background": "#1e293b",
          "foreground": "#ffffff",
          "leading_diamond": " \ue0b6",
          "style": "diamond",
          "template": "{{ if .Error }}{{ .Error }}{{ else }}Nx {{ .Full }}{{ end }}",
          "trailing_diamond": "\ue0b4 ",
          "type": "nx"
        },
        {
          "background": "#945bb3",
          "foreground": "#359a25",
          "leading_diamond": " \ue0b6",
          "style": "diamond",
          "template": "<#ca3c34>\ue624</> {{ if .Error }}{{ .Error }}{{ else }}{{ .Full }}{{ end }}",
          "trailing_diamond": "\ue0b4 ",
          "type": "julia"
        },
        {
          "background": "#ffffff",
          "foreground": "#9c1006",
          "leading_diamond": "\ue0b6",
          "style": "diamond",
          "template": "\ue791 {{ if .Error }}{{ .Error }}{{ else }}{{ .Full }}{{ end }}",
          "trailing_diamond": "\ue0b4 ",
          "type": "ruby"
        },
        {
          "background": "#ffffff",
          "foreground": "#5398c2",
          "leading_diamond": "\ue0b6",
          "style": "diamond",
          "template": "\uf104<#f5bf45>\uf0e7</>\uf105 {{ if .Error }}{{ .Error }}{{ else }}{{ .Full }}{{ end }}",
          "trailing_diamond": "\ue0b4 ",
          "type": "azfunc"
        },
        {
          "background": "#565656",
          "foreground": "#faa029",
          "leading_diamond": "\ue0b6",
          "style": "diamond",
          "template": "\ue7ad {{.Profile}}{{if .Region}}@{{.Region}}{{end}}",
          "trailing_diamond": "\ue0b4 ",
          "type": "aws"
        },
        {
          "background": "#316ce4",
          "foreground": "#ffffff",
          "leading_diamond": "\ue0b6",
          "style": "diamond",
          "template": "\uf308 {{.Context}}{{if .Namespace}} :: {{.Namespace}}{{end}}",
          "trailing_diamond": "\ue0b4",
          "type": "kubectl"
        },
        {
          "background": "#b2bec3",
          "foreground": "#222222",
          "leading_diamond": "\ue0b6",
          "trailing_diamond": "<transparent,background>\ue0b2</>",
          "properties": {
            "linux": "\ue712",
            "macos": "\ue711",
            "windows": "\ue70f"
          },
          "style": "diamond",
          "template": " {{ if .WSL }}WSL at {{ end }}{{.Icon}} ",
          "type": "os"
        },
        {
          "background": "#f36943",
          "background_templates": [
            "{{if eq \"Charging\" .State.String}}#b8e994{{end}}",
            "{{if eq \"Discharging\" .State.String}}#fff34e{{end}}",
            "{{if eq \"Full\" .State.String}}#33DD2D{{end}}"
          ],
          "foreground": "#262626",
          "invert_powerline": true,
          "powerline_symbol": "\ue0b2",
          "properties": {
            "charged_icon": "\uf240 ",
            "charging_icon": "\uf1e6 ",
            "discharging_icon": "\ue234 "
          },
          "style": "powerline",
          "template": " {{ if not .Error }}{{ .Icon }}{{ .Percentage }}{{ end }}{{ .Error }}\uf295 ",
          "type": "battery"
        },
        {
          "background": "#40c4ff",
          "foreground": "#ffffff",
          "invert_powerline": true,
          "leading_diamond": "\ue0b2",
          "properties": {
            "time_format": "_2,15:04"
          },
          "style": "diamond",
          "template": " \uf073 {{ .CurrentDate | date .Format }} ",
          "trailing_diamond": "\ue0b4",
          "type": "time"
        }
      ],
      "type": "prompt"
    },
    {
      "alignment": "left",
      "newline": true,
      "segments": [
        {
          "foreground": "#21c7c7",
          "style": "plain",
          "template": "\u2570\u2500",
          "type": "text"
        },
        {
          "foreground": "#e0f8ff",
          "foreground_templates": ["{{ if gt .Code 0 }}#ef5350{{ end }}"],
          "properties": {
            "always_enabled": true
          },
          "style": "plain",
          "template": "\ue285\ueab6 ",
          "type": "status"
        }
      ],
      "type": "prompt"
    }
  ],
  "version": 3
}
'@
    Set-Content -LiteralPath $ThemeDest -Value $json -Encoding UTF8
    Write-Step "Installed inlined atomic.omp.json"
}

function Set-CodexYoloConfig {
    $codexDir = Join-Path $HomePath ".codex"
    $configPath = Join-Path $codexDir "config.toml"
    Ensure-Directory $codexDir
    if (-not (Test-Path -LiteralPath $configPath)) { New-Item -ItemType File -Path $configPath -Force | Out-Null }
    $content = Get-Content -LiteralPath $configPath -Raw -ErrorAction SilentlyContinue
    if ($null -eq $content) { $content = "" }
    $lines = $content -split "\r?\n"
    $rootKeys = @(
        'approval_policy = "never"',
        'sandbox_mode = "danger-full-access"',
        'model = "gpt-5.5"',
        'model_reasoning_effort = "high"'
    )
    $out = [Collections.Generic.List[string]]::new()
    $inserted = $false
    foreach ($line in $lines) {
        if ($line -match "^\s*(approval_policy|sandbox_mode|model|model_reasoning_effort)\s*=") { continue }
        if (-not $inserted -and $line -match "^\s*\[") {
            foreach ($key in $rootKeys) { $out.Add($key) }
            $out.Add("")
            $inserted = $true
        }
        $out.Add($line)
    }
    if (-not $inserted) { foreach ($key in $rootKeys) { $out.Add($key) } }
    $homeForToml = $HomePath.Replace("'", "''")
    if (($out -join "`n") -notmatch [regex]::Escape("[projects.'$homeForToml']")) {
        $out.Add("")
        $out.Add("[projects.'$homeForToml']")
        $out.Add('trust_level = "trusted"')
    }
    Set-Content -LiteralPath $configPath -Value ($out -join [Environment]::NewLine) -Encoding UTF8
    Write-Step "Configured OpenAI Codex for unrestricted local execution"
}

function Set-ClaudeBypassConfig {
    $dir = Join-Path $HomePath ".claude"
    $cfg = Join-Path $dir "settings.json"
    Ensure-Directory $dir
    $obj = $null
    if (Test-Path -LiteralPath $cfg) {
        try { $obj = Get-Content -Raw -LiteralPath $cfg | ConvertFrom-Json } catch { $obj = $null }
    }
    if (-not $obj) { $obj = [pscustomobject]@{} }
    if (-not $obj.permissions) {
        $obj | Add-Member -NotePropertyName permissions -NotePropertyValue ([pscustomobject]@{}) -Force
    }
    $obj.permissions | Add-Member -NotePropertyName defaultMode -NotePropertyValue "bypassPermissions" -Force
    $obj | Add-Member -NotePropertyName skipDangerousModePermissionPrompt -NotePropertyValue $true -Force
    $obj | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $cfg -Encoding UTF8
    Write-Step "Configured Claude Code bypass-permissions"
}

# ---------------------------------------------------------------------------
# PowerShell profile (managed block)
# ---------------------------------------------------------------------------

function Get-ProfileBlock {
    $batTheme = if ($script:ThemeData) { $script:ThemeData.BatTheme } else { "" }
    $fzfOpts = ""
    if ($script:ThemeData) {
        $d = $script:ThemeData
        $fzfOpts = "--height 40% --layout=reverse --border --color=bg:$($d.Bg),fg:$($d.Fg),hl:$($d.Palette[4]),bg+:$($d.SelBg),fg+:$($d.Palette[15]),hl+:$($d.Palette[6]),info:$($d.Palette[2]),prompt:$($d.Palette[4]),pointer:$($d.Palette[5]),marker:$($d.Palette[2]),header:$($d.Palette[10])"
    }
@"
$ManagedStart
`$riceUserBin = Join-Path `$HOME ".local\bin"
if (Test-Path -LiteralPath `$riceUserBin) {
    `$env:Path = "`$riceUserBin;`$env:Path"
}

if ((Get-Command fastfetch -ErrorAction SilentlyContinue) -and -not [Console]::IsOutputRedirected -and -not [Console]::IsInputRedirected) {
    if (-not `$env:FASTFETCH_RAN) {
        `$env:FASTFETCH_RAN = "1"
        fastfetch
    }
}

`$riceTheme = Join-Path `$HOME ".cache\oh-my-posh\themes\atomic.omp.json"
if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
    if (Test-Path -LiteralPath `$riceTheme) {
        oh-my-posh init pwsh --config `$riceTheme | Invoke-Expression
    }
    else {
        oh-my-posh init pwsh | Invoke-Expression
    }
}

if (-not [Console]::IsOutputRedirected -and -not [Console]::IsInputRedirected) {
    if ('$batTheme') { `$env:BAT_THEME = '$batTheme' }
    if ('$fzfOpts') { `$env:FZF_DEFAULT_OPTS = '$fzfOpts' }
    if (Get-Command rg -ErrorAction SilentlyContinue) { `$env:FZF_DEFAULT_COMMAND = 'rg --files --hidden --glob "!.git/*"' }
    if (Get-Command zoxide -ErrorAction SilentlyContinue) { Invoke-Expression (& { (zoxide init powershell | Out-String) }) }
    if (Get-Command eza -ErrorAction SilentlyContinue) {
        function ls { eza --group-directories-first --icons=auto `@args }
        function ll { eza -lah --group-directories-first --icons=auto --git `@args }
        function la { eza -a --group-directories-first --icons=auto `@args }
        function lt { eza --tree --level=2 --icons=auto `@args }
    }
    if (Get-Module -ListAvailable PSFzf) {
        Import-Module PSFzf -ErrorAction SilentlyContinue
        Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r' -ErrorAction SilentlyContinue
    }
    if (Get-Command Set-PSReadLineOption -ErrorAction SilentlyContinue) {
        Set-PSReadLineOption -PredictionSource History -ErrorAction SilentlyContinue
        Set-PSReadLineOption -PredictionViewStyle ListView -ErrorAction SilentlyContinue
    }
}

# Add your own host/ssh shortcut functions here.
function update {
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        winget upgrade --all --include-unknown --accept-source-agreements --accept-package-agreements
    }
}
$ManagedEnd
"@
}

function Update-ManagedProfile {
    param([Parameter(Mandatory)][string]$ProfilePath)
    Ensure-Directory (Split-Path -Parent $ProfilePath)
    $block = Get-ProfileBlock
    $content = if (Test-Path -LiteralPath $ProfilePath) { Get-Content -LiteralPath $ProfilePath -Raw } else { "" }
    $pattern = "(?s)" + [regex]::Escape($ManagedStart) + ".*?" + [regex]::Escape($ManagedEnd) + "\r?\n?"
    if ($content -match [regex]::Escape($ManagedStart)) {
        $content = [regex]::Replace($content, $pattern, $block + [Environment]::NewLine)
    } else {
        if ($content.Length -gt 0 -and -not $content.EndsWith([Environment]::NewLine)) { $content += [Environment]::NewLine }
        $content += $block + [Environment]::NewLine
    }
    Set-Content -LiteralPath $ProfilePath -Value $content -Encoding UTF8
    Write-Step "Updated $ProfilePath"
}

# ---------------------------------------------------------------------------
# Terminal emulators (font + chosen theme)
# ---------------------------------------------------------------------------

function Get-WtSchemeObject {
    $d = $script:ThemeData
    return [ordered]@{
        name = "SharedRice"
        background = $d.Bg; foreground = $d.Fg; cursorColor = $d.Cursor; selectionBackground = $d.SelBg
        black = $d.Palette[0]; red = $d.Palette[1]; green = $d.Palette[2]; yellow = $d.Palette[3]
        blue = $d.Palette[4]; purple = $d.Palette[5]; cyan = $d.Palette[6]; white = $d.Palette[7]
        brightBlack = $d.Palette[8]; brightRed = $d.Palette[9]; brightGreen = $d.Palette[10]; brightYellow = $d.Palette[11]
        brightBlue = $d.Palette[12]; brightPurple = $d.Palette[13]; brightCyan = $d.Palette[14]; brightWhite = $d.Palette[15]
    }
}

function Update-WindowsTerminal {
    $settingsPath = Join-Path $env:LOCALAPPDATA "Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
    if (-not (Test-Path -LiteralPath $settingsPath)) {
        $settingsPath = Join-Path $env:LOCALAPPDATA "Microsoft\Windows Terminal\settings.json"
        if (-not (Test-Path -LiteralPath $settingsPath)) { Write-Step "Windows Terminal settings not found; skipping"; return }
    }
    try {
        $json = Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json
        if (-not $json.profiles) { $json | Add-Member -MemberType NoteProperty -Name profiles -Value ([pscustomobject]@{}) -Force }
        if (-not $json.profiles.defaults) { $json.profiles | Add-Member -MemberType NoteProperty -Name defaults -Value ([pscustomobject]@{}) -Force }
        if (-not $json.profiles.defaults.font) { $json.profiles.defaults | Add-Member -MemberType NoteProperty -Name font -Value ([pscustomobject]@{}) -Force }
        $json.profiles.defaults.font | Add-Member -MemberType NoteProperty -Name face -Value $FontFace -Force

        if ($script:ThemeName -ne 'none') {
            $scheme = [pscustomobject](Get-WtSchemeObject)
            $schemes = @()
            if ($json.schemes) { $schemes = @($json.schemes | Where-Object { $_.name -ne 'SharedRice' }) }
            $schemes += $scheme
            $json | Add-Member -MemberType NoteProperty -Name schemes -Value $schemes -Force
            $json.profiles.defaults | Add-Member -MemberType NoteProperty -Name colorScheme -Value "SharedRice" -Force
        }
        $json | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $settingsPath -Encoding UTF8
        Write-Step "Windows Terminal: font$(if($script:ThemeName -ne 'none'){' + SharedRice scheme'})"
    } catch {
        Write-Warning "Could not update Windows Terminal settings: $($_.Exception.Message)"
    }
}

function Update-WezTerm {
    $cfg = Join-Path $HomePath ".wezterm.lua"
    $cfgAlt = Join-Path $HomePath ".config\wezterm\wezterm.lua"
    $hasWez = (Get-Command wezterm -ErrorAction SilentlyContinue) -or (Test-Path -LiteralPath $cfg) -or (Test-Path -LiteralPath (Split-Path -Parent $cfgAlt))
    if (-not $hasWez) { return }
    $colorsDir = Join-Path $HomePath ".config\wezterm\colors"
    Ensure-Directory $colorsDir
    if ($script:ThemeName -ne 'none') {
        $d = $script:ThemeData
        $ansi = ($d.Palette[0..7] | ForEach-Object { "`"$_`"" }) -join ","
        $bright = ($d.Palette[8..15] | ForEach-Object { "`"$_`"" }) -join ","
        $toml = @"
[colors]
background = "$($d.Bg)"
foreground = "$($d.Fg)"
cursor_bg = "$($d.Cursor)"
cursor_fg = "$($d.Bg)"
selection_bg = "$($d.SelBg)"
ansi = [$ansi]
brights = [$bright]
"@
        Set-Content -LiteralPath (Join-Path $colorsDir "SharedRice.toml") -Value $toml -Encoding UTF8
    }
    if (-not (Test-Path -LiteralPath $cfg) -and -not (Test-Path -LiteralPath $cfgAlt)) {
        $scheme = if ($script:ThemeName -ne 'none') { "  color_scheme = 'SharedRice'," } else { "" }
        $lua = @"
local wezterm = require 'wezterm'
return {
  font = wezterm.font('$FontFace'),
  font_size = 11.0,
$scheme
}
"@
        Set-Content -LiteralPath $cfg -Value $lua -Encoding UTF8
        Write-Step "WezTerm configured (new .wezterm.lua)"
    } else {
        Write-Step "WezTerm color scheme written; existing config left intact (set color_scheme='SharedRice')"
    }
}

function Update-Alacritty {
    $dir = Join-Path $env:APPDATA "alacritty"
    if (-not (Get-Command alacritty -ErrorAction SilentlyContinue) -and -not (Test-Path -LiteralPath $dir)) { return }
    Ensure-Directory $dir
    $d = $script:ThemeData
    $body = "# generated by rice.ps1`n[font]`nsize = 11.0`nnormal = { family = `"$FontFace`", style = `"Regular`" }`n"
    if ($script:ThemeName -ne 'none') {
        $body += "`n[colors.primary]`nbackground = `"$($d.Bg)`"`nforeground = `"$($d.Fg)`"`n"
        $body += "`n[colors.normal]`nblack = `"$($d.Palette[0])`"`nred = `"$($d.Palette[1])`"`ngreen = `"$($d.Palette[2])`"`nyellow = `"$($d.Palette[3])`"`nblue = `"$($d.Palette[4])`"`nmagenta = `"$($d.Palette[5])`"`ncyan = `"$($d.Palette[6])`"`nwhite = `"$($d.Palette[7])`"`n"
        $body += "`n[colors.bright]`nblack = `"$($d.Palette[8])`"`nred = `"$($d.Palette[9])`"`ngreen = `"$($d.Palette[10])`"`nyellow = `"$($d.Palette[11])`"`nblue = `"$($d.Palette[12])`"`nmagenta = `"$($d.Palette[13])`"`ncyan = `"$($d.Palette[14])`"`nwhite = `"$($d.Palette[15])`"`n"
    }
    Set-Content -LiteralPath (Join-Path $dir "shared-rice.toml") -Value $body -Encoding UTF8
    $main = Join-Path $dir "alacritty.toml"
    $importLine = 'general.import = ["~/.config/alacritty/shared-rice.toml", "' + (Join-Path $dir 'shared-rice.toml').Replace('\','\\') + '"]'
    $existing = if (Test-Path -LiteralPath $main) { Get-Content -LiteralPath $main -Raw } else { "" }
    $existing = [regex]::Replace($existing, "(?s)" + [regex]::Escape($ManagedStart) + ".*?" + [regex]::Escape($ManagedEnd) + "\r?\n?", "")
    $block = "$ManagedStart`n$importLine`n$ManagedEnd`n"
    Set-Content -LiteralPath $main -Value ($block + $existing) -Encoding UTF8
    Write-Step "Alacritty configured"
}

function Update-Terminals {
    if ($SkipTerminals) { Write-Step "Skipping terminal-emulator configuration"; return }
    Write-Step "Configuring installed terminal emulators (theme=$($script:ThemeName))"
    Update-WindowsTerminal
    Update-WezTerm
    Update-Alacritty
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

Write-Step "Preparing Windows rice for $env:COMPUTERNAME"
Select-Theme
Ensure-Directory $UserBin
Install-WingetPackage -Id "Fastfetch-cli.Fastfetch" -Name "fastfetch" -Optional
Install-WingetPackage -Id "JanDeDobbeleer.OhMyPosh" -Name "Oh My Posh"
if ($WithAgentConfig) { Install-WingetPackage -Id "OpenAI.Codex" -Name "OpenAI Codex" -Optional }
Install-QolTools
Install-FiraCodeNerdFont
Install-AtomicTheme
if ($WithAgentConfig) {
    Set-CodexYoloConfig
    Set-ClaudeBypassConfig
} else {
    Write-Step "AI agent configuration is off (pass -WithAgentConfig to enable)"
}

$profiles = @(
    (Join-Path ([Environment]::GetFolderPath("MyDocuments")) "WindowsPowerShell\Microsoft.PowerShell_profile.ps1"),
    (Join-Path ([Environment]::GetFolderPath("MyDocuments")) "PowerShell\Microsoft.PowerShell_profile.ps1")
)
foreach ($profilePath in $profiles) {
    Update-ManagedProfile -ProfilePath $profilePath
}
Update-Terminals

Write-Step "Windows rice complete. Open a new PowerShell tab to see it."
