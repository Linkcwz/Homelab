param(
    [string]$Theme = "",
    [switch]$NoPrompt,
    [switch]$SkipFontInstall,
    [switch]$SkipPackageInstall,
    [switch]$SkipTerminals,
    [switch]$SkipAgentConfig
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
    Install-WingetPackage -Id "uutils.coreutils" -Name "coreutils" -Optional
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
        'model = "gpt-4.5-mini"',
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
    Set-TomlSectionKey -Path $configPath -Section "features" -Key "hooks" -Value "true"
    Set-TomlSectionKey -Path $configPath -Section "tui" -Key "theme" -Value '"monokai-extended-origin"'
    Set-TomlSectionKey -Path $configPath -Section "tui" -Key "pet" -Value '"null-signal"'
    Set-TomlSectionKey -Path $configPath -Section 'plugins."github@openai-curated"' -Key "enabled" -Value "true"
    Write-Step "Configured OpenAI Codex defaults and appearance"
}

function Set-TomlSectionKey {
    param(
        [string]$Path,
        [string]$Section,
        [string]$Key,
        [string]$Value
    )
    $header = "[$Section]"
    $lines = @()
    if (Test-Path -LiteralPath $Path) {
        $lines = @(Get-Content -LiteralPath $Path -ErrorAction SilentlyContinue)
    }
    $out = [Collections.Generic.List[string]]::new()
    $inSection = $false
    $foundSection = $false
    $wrote = $false
    foreach ($line in $lines) {
        if ($line -eq $header) {
            $inSection = $true
            $foundSection = $true
            $out.Add($line)
            continue
        }
        if ($inSection -and $line -match '^\s*\[') {
            if (-not $wrote) { $out.Add("$Key = $Value") }
            $inSection = $false
            $wrote = $true
        }
        if ($inSection -and $line -match ("^\s*" + [regex]::Escape($Key) + "\s*=")) {
            if (-not $wrote) { $out.Add("$Key = $Value") }
            $wrote = $true
            continue
        }
        $out.Add($line)
    }
    if ($inSection -and -not $wrote) { $out.Add("$Key = $Value") }
    if (-not $foundSection) {
        $out.Add("")
        $out.Add($header)
        $out.Add("$Key = $Value")
    }
    Set-Content -LiteralPath $Path -Value $out -Encoding UTF8
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
    $obj | Add-Member -NotePropertyName model -NotePropertyValue "claude-sonnet-4-6" -Force
    if (-not $obj.permissions) {
        $obj | Add-Member -NotePropertyName permissions -NotePropertyValue ([pscustomobject]@{}) -Force
    }
    $obj.permissions | Add-Member -NotePropertyName defaultMode -NotePropertyValue "auto" -Force
    if ($obj.PSObject.Properties['skipDangerousModePermissionPrompt']) {
        $obj.PSObject.Properties.Remove('skipDangerousModePermissionPrompt')
    }
    $obj | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $cfg -Encoding UTF8
    Write-Step "Configured Claude Code (claude-sonnet-4-6, auto mode)"
}

function Install-ClaudeCode {
    if (Get-Command claude -ErrorAction SilentlyContinue) {
        Write-Step "Claude Code already installed ($((claude --version 2>$null | Select-Object -First 1)))"
        return
    }
    # Anthropic's preferred install is the native PowerShell installer (user-scoped).
    try {
        Write-Step "Installing Claude Code (native installer)"
        Invoke-Expression (Invoke-RestMethod -Uri 'https://claude.ai/install.ps1')
        Refresh-ProcessPath
    } catch {
        Write-Warning "Native Claude Code installer failed: $($_.Exception.Message)"
    }
    if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
        if (Get-Command npm -ErrorAction SilentlyContinue) {
            Write-Step "Falling back to npm for Claude Code"
            & npm install -g '@anthropic-ai/claude-code'
            Refresh-ProcessPath
        } else {
            Write-Warning "Claude Code not installed (no native installer success and npm unavailable)."
        }
    }
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
    if (Get-Command rg -ErrorAction SilentlyContinue) {
        `$env:FZF_DEFAULT_COMMAND = 'rg --files --hidden --glob "!.git/*"'
    } elseif (Get-Command fd -ErrorAction SilentlyContinue) {
        `$env:FZF_DEFAULT_COMMAND = 'fd --type f --hidden --exclude .git'
    }
    if (`$env:FZF_DEFAULT_COMMAND) { `$env:FZF_CTRL_T_COMMAND = `$env:FZF_DEFAULT_COMMAND }
    if (Get-Command bat -ErrorAction SilentlyContinue) {
        `$env:FZF_CTRL_T_OPTS = "--preview 'bat --color=always --style=numbers --line-range=:200 {}'"
    }
    if (Get-Command zoxide -ErrorAction SilentlyContinue) { Invoke-Expression (& { (zoxide init powershell | Out-String) }) }

    # modern CLI replacements
    if (Get-Command eza -ErrorAction SilentlyContinue) {
        function ls { eza --group-directories-first --icons=auto `@args }
        function ll { eza -lah --group-directories-first --icons=auto --git `@args }
        function la { eza -a --group-directories-first --icons=auto `@args }
        function lt { eza --tree --level=2 --icons=auto `@args }
        function ltt { eza --tree --level=4 --icons=auto `@args }
    }
    if (Get-Command bat -ErrorAction SilentlyContinue) { function cat { bat --paging=never `@args } }
    if (Get-Command rg  -ErrorAction SilentlyContinue) { function grep { rg `@args } }
    if (Get-Command fd  -ErrorAction SilentlyContinue) { function find { fd `@args } }

    if (Get-Module -ListAvailable PSFzf) {
        Import-Module PSFzf -ErrorAction SilentlyContinue
        Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r' -ErrorAction SilentlyContinue
    }
    if (Get-Command Set-PSReadLineOption -ErrorAction SilentlyContinue) {
        Set-PSReadLineOption -HistoryNoDuplicates -ErrorAction SilentlyContinue
        Set-PSReadLineOption -HistorySearchCursorMovesToEnd -ErrorAction SilentlyContinue
        Set-PSReadLineOption -MaximumHistoryCount 100000 -ErrorAction SilentlyContinue
        Set-PSReadLineOption -BellStyle None -ErrorAction SilentlyContinue
        # Prediction (inline/list suggestions from history) needs PSReadLine >= 2.2;
        # PS 5.1 ships 2.0.0 where these params don't exist, so version-guard them.
        `$ricePsrl = (Get-Module PSReadLine | Select-Object -First 1).Version
        if (`$ricePsrl -and `$ricePsrl -ge [version]'2.2.0') {
            Set-PSReadLineOption -PredictionSource History -ErrorAction SilentlyContinue
            Set-PSReadLineOption -PredictionViewStyle ListView -ErrorAction SilentlyContinue
        }
    }
    # Tab shows a selectable completion LIST (menu), not a one-at-a-time cycle.
    if (Get-Command Set-PSReadLineKeyHandler -ErrorAction SilentlyContinue) {
        Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete -ErrorAction SilentlyContinue
        Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward -ErrorAction SilentlyContinue
        Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward -ErrorAction SilentlyContinue
        Set-PSReadLineKeyHandler -Key Ctrl+w -Function BackwardKillWord -ErrorAction SilentlyContinue
    }
}

# quality-of-life functions
function .. { Set-Location .. }
function ... { Set-Location ../.. }
function .... { Set-Location ../../.. }
function mkcd { param([Parameter(Mandatory)][string]`$Path) New-Item -ItemType Directory -Force -Path `$Path | Out-Null; Set-Location `$Path }
function which { param([Parameter(Mandatory)][string]`$Name) (Get-Command `$Name -ErrorAction SilentlyContinue).Source }
function touch { param([Parameter(Mandatory)][string]`$Path) if (Test-Path -LiteralPath `$Path) { (Get-Item -LiteralPath `$Path).LastWriteTime = Get-Date } else { New-Item -ItemType File -Path `$Path | Out-Null } }
function reload { . `$PROFILE }

# git shortcuts
function gst { git status `@args }
function ga  { git add `@args }
function gc  { git commit `@args }
function gco { git checkout `@args }
function gsw { git switch `@args }
function gp  { git push `@args }
function gl  { git pull `@args }
function gd  { git diff `@args }
function gb  { git branch `@args }
function glog { git log --oneline --graph --decorate `@args }

# Add your own host/ssh shortcut functions here.
function update {
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        winget upgrade --all --include-unknown --accept-source-agreements --accept-package-agreements
    }
}
$ManagedEnd
"@
}

function Set-ManagedBlock {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Block,
        [switch]$Bash   # write LF + UTF-8 without BOM (required by bash/MSYS)
    )
    Ensure-Directory (Split-Path -Parent $Path)
    $nl = if ($Bash) { "`n" } else { [Environment]::NewLine }
    $content = if (Test-Path -LiteralPath $Path) { Get-Content -LiteralPath $Path -Raw } else { "" }
    $pattern = "(?s)" + [regex]::Escape($ManagedStart) + ".*?" + [regex]::Escape($ManagedEnd) + "\r?\n?"
    if ($content -match [regex]::Escape($ManagedStart)) {
        $content = [regex]::Replace($content, $pattern, ($Block -replace '\$', '$$$$') + $nl)
    } else {
        if ($content.Length -gt 0 -and -not $content.EndsWith($nl)) { $content += $nl }
        $content += $Block + $nl
    }
    if ($Bash) {
        # bash chokes on a UTF-8 BOM and on CRLF inside eval "$(...)"; force LF + no BOM.
        $lf = ($content -replace "`r`n", "`n") -replace "`r", "`n"
        [System.IO.File]::WriteAllText($Path, $lf, (New-Object System.Text.UTF8Encoding($false)))
    } else {
        Set-Content -LiteralPath $Path -Value $content -Encoding UTF8
    }
    Write-Step "Updated $Path"
}

function Update-ManagedProfile {
    param([Parameter(Mandatory)][string]$ProfilePath)
    Set-ManagedBlock -Path $ProfilePath -Block (Get-ProfileBlock)
}

# ---------------------------------------------------------------------------
# Git Bash / MSYS bash (Windows) — same comprehensive QoL block as rice.sh
# ---------------------------------------------------------------------------

function Get-BashBlock {
    # Kept byte-for-byte in sync with rice.sh `bash_managed_block windows`.
    # Single-quoted here-string: $ and \ are literal, exactly what bash wants.
    return @'
# --- rice-managed start ---
export PATH="$HOME/.local/bin:$PATH"

case $- in
  *i*)
    # --- history: big, deduped, shared, timestamped -----------------------
    HISTSIZE=100000
    HISTFILESIZE=200000
    HISTCONTROL=ignoreboth:erasedups
    HISTTIMEFORMAT='%F %T '
    HISTIGNORE='ls:ll:la:cd:pwd:clear:exit:history:bg:fg'
    shopt -s histappend cmdhist 2>/dev/null
    PROMPT_COMMAND="history -a${PROMPT_COMMAND:+; $PROMPT_COMMAND}"

    # --- sane interactive shell options -----------------------------------
    shopt -s checkwinsize globstar nocaseglob extglob dotglob 2>/dev/null
    shopt -s autocd cdspell dirspell 2>/dev/null

    # --- readline: Tab shows the LIST of matches (not cycle-one-at-a-time) -
    bind 'set show-all-if-ambiguous on'     2>/dev/null  # first Tab lists matches
    bind 'set show-all-if-unmodified on'    2>/dev/null
    bind 'set completion-ignore-case on'    2>/dev/null
    bind 'set completion-map-case on'       2>/dev/null  # treat - and _ alike
    bind 'set colored-stats on'             2>/dev/null
    bind 'set colored-completion-prefix on' 2>/dev/null
    bind 'set visible-stats on'             2>/dev/null
    bind 'set mark-symlinked-directories on' 2>/dev/null
    bind 'set page-completions off'         2>/dev/null
    bind 'set completion-query-items 200'   2>/dev/null
    bind '"\e[A": history-search-backward'  2>/dev/null  # Up = prefix history search
    bind '"\e[B": history-search-forward'   2>/dev/null  # Down = prefix history search
    bind '"\t": complete'                   2>/dev/null  # Tab = complete + list, never menu-cycle

    # --- programmable completion ------------------------------------------
    if ! shopt -oq posix; then
      if [ -r /usr/share/bash-completion/bash_completion ]; then
        . /usr/share/bash-completion/bash_completion
      elif [ -r /etc/bash_completion ]; then
        . /etc/bash_completion
      fi
    fi

    # --- fastfetch greeting -----------------------------------------------
    if command -v fastfetch >/dev/null 2>&1 && [ -z "${FASTFETCH_RAN:-}" ]; then
      export FASTFETCH_RAN=1
      fastfetch
    fi

    # --- oh-my-posh prompt -------------------------------------------------
    if command -v oh-my-posh >/dev/null 2>&1; then
      if [ -f "$HOME/.cache/oh-my-posh/themes/atomic.omp.json" ]; then
        eval "$(oh-my-posh init bash --config "$HOME/.cache/oh-my-posh/themes/atomic.omp.json")"
      else
        eval "$(oh-my-posh init bash)"
      fi
    fi

    [ -r "$HOME/.config/rice/theme.sh" ] && . "$HOME/.config/rice/theme.sh"

    # --- modern CLI replacements ------------------------------------------
    if command -v eza >/dev/null 2>&1; then
      alias ls='eza --group-directories-first --icons=auto'
      alias ll='eza -lah --group-directories-first --icons=auto --git'
      alias la='eza -a --group-directories-first --icons=auto'
      alias lt='eza --tree --level=2 --icons=auto'
      alias ltt='eza --tree --level=4 --icons=auto'
    else
      alias ll='ls -alF'
      alias la='ls -A'
      alias l='ls -CF'
    fi
    if command -v bat >/dev/null 2>&1; then
      alias cat='bat --paging=never'
      export BAT_PAGER='less -RF'
      export MANPAGER="sh -c 'col -bx | bat -l man -p'"
      export MANROFFOPT='-c'
    elif command -v batcat >/dev/null 2>&1; then
      alias bat='batcat'
      alias cat='batcat --paging=never'
      export MANPAGER="sh -c 'col -bx | batcat -l man -p'"
      export MANROFFOPT='-c'
    fi
    if ! command -v fd >/dev/null 2>&1 && command -v fdfind >/dev/null 2>&1; then
      alias fd='fdfind'
    fi
    command -v rg >/dev/null 2>&1 && alias grep='rg'

    # --- fzf: fuzzy finder, themed preview, history & file widgets ---------
    if command -v rg >/dev/null 2>&1; then
      export FZF_DEFAULT_COMMAND='rg --files --hidden --glob "!.git/*"'
      export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
    elif command -v fd >/dev/null 2>&1; then
      export FZF_DEFAULT_COMMAND='fd --type f --hidden --exclude .git'
      export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
    fi
    if command -v bat >/dev/null 2>&1; then
      export FZF_CTRL_T_OPTS="--preview 'bat --color=always --style=numbers --line-range=:200 {}'"
    elif command -v batcat >/dev/null 2>&1; then
      export FZF_CTRL_T_OPTS="--preview 'batcat --color=always --style=numbers --line-range=:200 {}'"
    fi
    export FZF_CTRL_R_OPTS="--reverse"
    export FZF_ALT_C_OPTS="--preview 'ls -la {}'"
    if command -v fzf >/dev/null 2>&1; then
      if fzf --bash >/dev/null 2>&1; then
        eval "$(fzf --bash)"
      else
        for __f in /usr/share/fzf/key-bindings.bash /usr/share/doc/fzf/examples/key-bindings.bash /usr/share/fzf/shell/key-bindings.bash; do
          [ -r "$__f" ] && . "$__f" && break
        done
        for __f in /usr/share/fzf/completion.bash /usr/share/doc/fzf/examples/completion.bash /usr/share/fzf/shell/completion.bash; do
          [ -r "$__f" ] && . "$__f" && break
        done
      fi
    fi

    # --- zoxide: smarter cd (use `z <dir>`, `zi` for interactive) --------
    command -v zoxide >/dev/null 2>&1 && eval "$(zoxide init bash)"

    # --- handy aliases & functions ----------------------------------------
    alias ..='cd ..'
    alias ...='cd ../..'
    alias ....='cd ../../..'
    alias mkdir='mkdir -p'
    alias df='df -h'
    alias du='du -h'
    alias free='free -h'
    alias path='echo "$PATH" | tr ":" "\n"'
    alias ports='ss -tulpn 2>/dev/null || netstat -tulpn'
    alias reload='exec "$BASH"'
    mkcd() { mkdir -p -- "$1" && cd -- "$1"; }
    extract() {
      [ -f "$1" ] || { echo "extract: '$1' is not a file" >&2; return 1; }
      case "$1" in
        *.tar.bz2|*.tbz2) tar xjf "$1" ;; *.tar.gz|*.tgz) tar xzf "$1" ;;
        *.tar.xz) tar xJf "$1" ;; *.tar) tar xf "$1" ;;
        *.bz2) bunzip2 "$1" ;; *.gz) gunzip "$1" ;; *.xz) unxz "$1" ;;
        *.zip) unzip "$1" ;; *.rar) unrar x "$1" ;; *.7z) 7z x "$1" ;;
        *) echo "extract: don't know how to extract '$1'" >&2; return 1 ;;
      esac
    }

    # --- git shortcuts -----------------------------------------------------
    alias gst='git status'
    alias ga='git add'
    alias gc='git commit'
    alias gco='git checkout'
    alias gsw='git switch'
    alias gp='git push'
    alias gl='git pull'
    alias gd='git diff'
    alias gb='git branch'
    alias glog='git log --oneline --graph --decorate'
    ;;
esac

# Add your own host/ssh shortcut aliases here.
alias update='winget upgrade --all --include-unknown --accept-source-agreements --accept-package-agreements'
# --- rice-managed end ---
'@
}

function Configure-GitBash {
    # Rice Git Bash / MSYS2 bash if one is present. Writes ~/.bashrc and makes
    # the login ~/.bash_profile source it (Git for Windows uses a login shell).
    $bashFound = (Get-Command bash -ErrorAction SilentlyContinue) -ne $null
    if (-not $bashFound) {
        $candidates = @(
            (Join-Path $env:ProgramFiles 'Git\bin\bash.exe'),
            (Join-Path ${env:ProgramFiles(x86)} 'Git\bin\bash.exe'),
            (Join-Path $env:LOCALAPPDATA 'Programs\Git\bin\bash.exe')
        )
        foreach ($c in $candidates) { if ($c -and (Test-Path -LiteralPath $c)) { $bashFound = $true; break } }
    }
    if (-not $bashFound) { Write-Step "No Git Bash / MSYS bash detected; skipping bash rice"; return }

    $bashrc = Join-Path $HomePath ".bashrc"
    Set-ManagedBlock -Path $bashrc -Block (Get-BashBlock) -Bash

    $bashProfile = Join-Path $HomePath ".bash_profile"
    $sourceBlock = "$ManagedStart`n# Load ~/.bashrc for login shells (Git Bash starts a login shell).`nif [ -f ""`$HOME/.bashrc"" ]; then . ""`$HOME/.bashrc""; fi`n$ManagedEnd"
    Set-ManagedBlock -Path $bashProfile -Block $sourceBlock -Bash
    Write-Step "Configured Git Bash (~/.bashrc + ~/.bash_profile)"
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
if (-not $SkipAgentConfig) {
    if (Get-Command codex -ErrorAction SilentlyContinue) {
        Write-Step "OpenAI Codex already installed ($((codex --version 2>$null | Select-Object -First 1)))"
    } else {
        Install-WingetPackage -Id "OpenAI.Codex" -Name "OpenAI Codex" -Optional
    }
    Install-ClaudeCode
}
Install-QolTools
Install-FiraCodeNerdFont
Install-AtomicTheme
if (-not $SkipAgentConfig) {
    Set-CodexYoloConfig
    Set-ClaudeBypassConfig
} else {
    Write-Step "AI agent configuration skipped (-SkipAgentConfig)"
}

$profiles = @(
    (Join-Path ([Environment]::GetFolderPath("MyDocuments")) "WindowsPowerShell\Microsoft.PowerShell_profile.ps1"),
    (Join-Path ([Environment]::GetFolderPath("MyDocuments")) "PowerShell\Microsoft.PowerShell_profile.ps1")
)
foreach ($profilePath in $profiles) {
    Update-ManagedProfile -ProfilePath $profilePath
}
Configure-GitBash
Update-Terminals

Write-Step "Windows rice complete. Open a new PowerShell tab to see it."
