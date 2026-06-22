#!/usr/bin/env bash
set -euo pipefail

# Native Linux ricer for any distro + every terminal emulator that is installed.
# Cross-platform terminal rice: fonts, themes, QoL CLI tools, and an Oh My Posh
# prompt. AI-agent config (Codex + Claude) is ON by default; pass --skip-agent-config to skip.

SKIP_FONT_INSTALL=0
SKIP_PACKAGE_INSTALL=0
SKIP_SHELL_CHANGE=0
SKIP_TERMINALS=0
WITH_AGENT_CONFIG=1
NO_PROMPT=0
THEME=""
DEFAULT_THEME="solarized-dark"
THEME_NAMES="solarized-dark solarized-light tokyonight"

for arg in "$@"; do
  case "$arg" in
    --skip-font-install) SKIP_FONT_INSTALL=1 ;;
    --skip-package-install) SKIP_PACKAGE_INSTALL=1 ;;
    --skip-shell-change) SKIP_SHELL_CHANGE=1 ;;
    --skip-terminals) SKIP_TERMINALS=1 ;;
    --with-agent-config) WITH_AGENT_CONFIG=1 ;;
    --skip-agent-config) WITH_AGENT_CONFIG=0 ;;
    --no-prompt) NO_PROMPT=1 ;;
    --theme=*) THEME="${arg#*=}" ;;
    -h|--help)
      cat <<'EOF'
Usage: ./rice.sh [options]

Native Linux ricer for Arch, CachyOS, Ubuntu, Debian, Proxmox, Fedora/RHEL,
openSUSE, Alpine, and any other distro with a supported package manager.
Configures every terminal emulator it finds with FiraCode Nerd Font and the
chosen color theme.

Options:
  --theme=NAME             Apply NAME without prompting
                           (solarized-dark | solarized-light | tokyonight | none)
  --no-prompt              Skip the interactive theme picker; use the default
                           (solarized-dark)
  --skip-terminals         Do not touch terminal-emulator configs
  --with-agent-config      (no-op; agent config is ON by default)
  --skip-agent-config      Skip AI agent config (Codex + Claude); pass to opt out
  --skip-font-install      Do not install FiraCode Nerd Font
  --skip-package-install   Do not install OS packages
  --skip-shell-change      Do not run chsh to make fish the default shell
EOF
      exit 0
      ;;
    *) echo "Unknown option: $arg" >&2; exit 2 ;;
  esac
done

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FiraCode.zip"
FONT_DIR="$HOME/.local/share/fonts"
FONT_FAMILY="FiraCode Nerd Font Mono"
FONT_SIZE=11
POSH_THEMES="$HOME/.cache/oh-my-posh/themes"
CONFIG_FISH="$HOME/.config/fish/config.fish"
BASHRC="$HOME/.bashrc"
ZSHRC="$HOME/.zshrc"
CODEX_CONFIG="$HOME/.codex/config.toml"
RICE_ENV_DIR="$HOME/.config/rice"
MANAGED_START="# --- rice-managed start ---"
MANAGED_END="# --- rice-managed end ---"
PKG_MGR=""
PKG_UPDATED=0

export PATH="$HOME/.local/bin:/usr/local/bin:$PATH"

step() {
  printf '==> %s\n' "$*"
}

have() {
  command -v "$1" >/dev/null 2>&1
}

need_root() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  elif have sudo; then
    sudo "$@"
  else
    echo "sudo is required for: $*" >&2
    return 1
  fi
}

# ---------------------------------------------------------------------------
# Color helpers
# ---------------------------------------------------------------------------

hex_to_rgb_commas() {
  local h=${1#\#}
  printf '%d,%d,%d' "0x${h:0:2}" "0x${h:2:2}" "0x${h:4:2}"
}

hex_to_ansi_fg() {
  local rgb; rgb=$(hex_to_rgb_commas "$1")
  printf '38;2;%s' "${rgb//,/;}"
}

# theme_colors NAME -> 20 space-separated hex fields:
#   bg fg c0..c15 cursor selection_bg
theme_colors() {
  case "$1" in
    solarized-dark)
      echo "#002b36 #839496 #073642 #dc322f #859900 #b58900 #268bd2 #d33682 #2aa198 #eee8d5 #002b36 #cb4b16 #586e75 #657b83 #839496 #6c71c4 #93a1a1 #fdf6e3 #839496 #073642"
      ;;
    solarized-light)
      echo "#fdf6e3 #657b83 #073642 #dc322f #859900 #b58900 #268bd2 #d33682 #2aa198 #eee8d5 #002b36 #cb4b16 #586e75 #657b83 #839496 #6c71c4 #93a1a1 #fdf6e3 #657b83 #eee8d5"
      ;;
    tokyonight)
      echo "#1a1b26 #c0caf5 #15161e #f7768e #9ece6a #e0af68 #7aa2f7 #bb9af7 #7dcfff #a9b1d6 #414868 #f7768e #9ece6a #e0af68 #7aa2f7 #bb9af7 #7dcfff #c0caf5 #c0caf5 #283457"
      ;;
    *) return 1 ;;
  esac
}

load_theme() {
  local data
  data=$(theme_colors "$1") || return 1
  [ -n "$data" ] || return 1
  read -r TH_BG TH_FG TH_C0 TH_C1 TH_C2 TH_C3 TH_C4 TH_C5 TH_C6 TH_C7 \
          TH_C8 TH_C9 TH_C10 TH_C11 TH_C12 TH_C13 TH_C14 TH_C15 TH_CURSOR TH_SELBG <<EOF_THEME
$data
EOF_THEME
  TH_PALETTE="$TH_C0 $TH_C1 $TH_C2 $TH_C3 $TH_C4 $TH_C5 $TH_C6 $TH_C7 $TH_C8 $TH_C9 $TH_C10 $TH_C11 $TH_C12 $TH_C13 $TH_C14 $TH_C15"
  THEME="$1"
}

preview_theme() {
  local name=$1 data hex i=0 r g b
  data=$(theme_colors "$name") || return 0
  printf '  %-16s ' "$name"
  for hex in $data; do
    i=$((i + 1))
    # fields 1=bg 2=fg are shown as a framing pair; 3..18 are the 16 ANSI swatches
    if [ "$i" -ge 3 ] && [ "$i" -le 18 ]; then
      r=$((16#${hex:1:2})); g=$((16#${hex:3:2})); b=$((16#${hex:5:2}))
      printf '\033[48;2;%d;%d;%dm  \033[0m' "$r" "$g" "$b"
    fi
  done
  # sample fg-on-bg text so the contrast is visible
  r=$((16#${TH_PREVIEW_BG:-0})) 2>/dev/null || true
  local bg fg
  bg=$(echo "$data" | awk '{print $1}'); fg=$(echo "$data" | awk '{print $2}')
  local bgr bgg bgb fgr fgg fgb
  bgr=$((16#${bg:1:2})); bgg=$((16#${bg:3:2})); bgb=$((16#${bg:5:2}))
  fgr=$((16#${fg:1:2})); fgg=$((16#${fg:3:2})); fgb=$((16#${fg:5:2}))
  printf '  \033[48;2;%d;%d;%dm\033[38;2;%d;%d;%dm Aa $ ~ \033[0m\n' \
    "$bgr" "$bgg" "$bgb" "$fgr" "$fgg" "$fgb"
}

select_theme() {
  if [ -n "$THEME" ]; then
    if [ "$THEME" = none ]; then
      step "Theme: none (font only, terminal colors left untouched)"
      return
    fi
    load_theme "$THEME" || { echo "Unknown theme: $THEME" >&2; exit 2; }
    step "Theme: $THEME (from --theme)"
    return
  fi

  if [ "$NO_PROMPT" -eq 1 ] || [ ! -r /dev/tty ]; then
    load_theme "$DEFAULT_THEME"
    step "Theme: $DEFAULT_THEME (default, non-interactive)"
    return
  fi

  printf '\n  Choose a terminal color theme — applied to EVERY terminal found:\n\n'
  local i=1 name
  for name in $THEME_NAMES; do
    printf '  %d)' "$i"
    preview_theme "$name"
    i=$((i + 1))
  done
  printf '  %d) none  (keep each terminal'\''s current colors; set font only)\n\n' "$i"
  printf '  Selection [1-%d, Enter = 1 (%s)]: ' "$i" "$DEFAULT_THEME"

  local choice=""
  read -r choice < /dev/tty || choice=""
  [ -z "$choice" ] && choice=1

  local none_index=$i
  if [ "$choice" = "$none_index" ] || [ "$choice" = none ]; then
    THEME="none"
    step "Theme: none (font only)"
    return
  fi

  local picked=""
  case "$choice" in
    ''|*[!0-9]*) picked="$choice" ;;            # treat as a name
    *) picked=$(echo "$THEME_NAMES" | awk -v n="$choice" '{print $n}') ;;
  esac
  [ -z "$picked" ] && picked="$DEFAULT_THEME"
  load_theme "$picked" || load_theme "$DEFAULT_THEME"
  step "Theme: $THEME"
}

# ---------------------------------------------------------------------------
# Package management (any distro)
# ---------------------------------------------------------------------------

detect_role() {
  local id="unknown" like="" pretty="" issue=""
  if [ -r /etc/os-release ]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    id="${ID:-unknown}"
    like="${ID_LIKE:-}"
    pretty="${PRETTY_NAME:-}"
  fi
  issue="$(cat /etc/issue 2>/dev/null || true)"

  if printf '%s %s\n' "$pretty" "$issue" | grep -qi 'Proxmox'; then
    echo proxmox
  elif [ "$id" = arch ] || [ "$id" = cachyos ] || [ "$id" = endeavouros ] || [ "$id" = manjaro ] \
       || printf '%s\n' "$like" | grep -qi arch; then
    echo arch
  elif [ "$id" = ubuntu ] || [ "$id" = debian ] || [ "$id" = pop ] || [ "$id" = linuxmint ] \
       || printf '%s\n' "$like" | grep -qi debian; then
    echo ubuntu_debian
  elif [ "$id" = fedora ] || [ "$id" = rhel ] || [ "$id" = centos ] || [ "$id" = rocky ] \
       || [ "$id" = almalinux ] || printf '%s\n' "$like" | grep -Eqi 'fedora|rhel'; then
    echo fedora_rhel
  elif printf '%s %s\n' "$id" "$like" | grep -qi suse; then
    echo suse
  elif [ "$id" = alpine ]; then
    echo alpine
  else
    echo generic
  fi
}

detect_pkg_mgr() {
  for m in pacman apt-get dnf zypper apk yum; do
    if have "$m"; then
      case "$m" in
        apt-get) PKG_MGR=apt ;;
        *) PKG_MGR="$m" ;;
      esac
      return
    fi
  done
  PKG_MGR=""
}

pkg_refresh() {
  [ "$PKG_UPDATED" -eq 1 ] && return
  PKG_UPDATED=1
  case "$PKG_MGR" in
    apt) need_root env DEBIAN_FRONTEND=noninteractive apt-get update || true ;;
    apk) need_root apk update || true ;;
  esac
}

# install_pkg COMMAND CANDIDATE...   -> install the first candidate that yields COMMAND
install_pkg() {
  local cmd=$1; shift
  have "$cmd" && return 0
  [ "$SKIP_PACKAGE_INSTALL" -eq 1 ] && return 0
  [ -z "$PKG_MGR" ] && return 0
  local cand
  for cand in "$@"; do
    case "$PKG_MGR" in
      pacman) need_root pacman -S --needed --noconfirm "$cand" || true ;;
      apt) pkg_refresh; need_root env DEBIAN_FRONTEND=noninteractive apt-get install -y "$cand" || true ;;
      dnf) need_root dnf install -y "$cand" || true ;;
      yum) need_root yum install -y "$cand" || true ;;
      zypper) need_root zypper --non-interactive install -y "$cand" || true ;;
      apk) pkg_refresh; need_root apk add --no-cache "$cand" || true ;;
    esac
    have "$cmd" && return 0
  done
  return 0
}

install_packages() {
  local role="$1"
  [ "$SKIP_PACKAGE_INSTALL" -eq 0 ] || { step "Skipping package install"; return; }
  detect_pkg_mgr
  if [ -z "$PKG_MGR" ]; then
    step "No supported package manager found; skipping package install"
    return
  fi
  step "Using package manager: $PKG_MGR (role=$role)"

  # Base packages with per-distro name fallbacks.
  install_pkg curl curl
  install_pkg unzip unzip
  install_pkg git git
  install_pkg fish fish
  install_pkg fc-cache fontconfig
  install_pkg fastfetch fastfetch
  case "$role" in
    arch) install_pkg node nodejs && install_pkg npm npm ;;
    *)    install_pkg node nodejs && install_pkg npm npm ;;
  esac

  install_qol_tools
}

install_qol_tools() {
  [ "$SKIP_PACKAGE_INSTALL" -eq 0 ] || return 0
  [ -z "$PKG_MGR" ] && return 0
  step "Installing QoL tools (eza, bat, ripgrep, fd, fzf, zoxide)"
  install_pkg eza eza exa
  install_pkg bat bat batcat
  install_pkg rg ripgrep
  install_pkg fd fd fd-find
  install_pkg fzf fzf
  install_pkg zoxide zoxide

  # Debian/Ubuntu ship bat as batcat and fd as fdfind; expose canonical names.
  mkdir -p "$HOME/.local/bin"
  if ! have bat && have batcat; then ln -sf "$(command -v batcat)" "$HOME/.local/bin/bat"; fi
  if ! have fd && have fdfind; then ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"; fi
}

# ---------------------------------------------------------------------------
# Fonts, prompt, codex
# ---------------------------------------------------------------------------

install_fonts() {
  [ "$SKIP_FONT_INSTALL" -eq 0 ] || { step "Skipping font install"; return; }
  have curl || return 0
  have unzip || return 0
  mkdir -p "$FONT_DIR"
  local tmpdir
  tmpdir="$(mktemp -d)"
  if curl -fL "$FONT_URL" -o "$tmpdir/FiraCode.zip"; then
    unzip -o "$tmpdir/FiraCode.zip" -d "$FONT_DIR" >/dev/null 2>&1 || true
    have fc-cache && fc-cache -f "$FONT_DIR" >/dev/null 2>&1 || true
  fi
  rm -rf "$tmpdir"
}

install_ohmyposh() {
  have oh-my-posh && { step "Oh My Posh already installed"; return; }
  mkdir -p "$HOME/.local/bin"
  curl -s https://ohmyposh.dev/install.sh | bash -s -- -d "$HOME/.local/bin" || true
  if ! have oh-my-posh; then
    need_root curl -L https://cdn.ohmyposh.dev/releases/latest/posh-linux-amd64 -o /usr/local/bin/oh-my-posh || true
    need_root chmod +x /usr/local/bin/oh-my-posh || true
  fi
}

install_codex() {
  have npm || { step "npm unavailable; skipping Codex install"; return; }
  need_root npm install -g @openai/codex || step "Codex install failed; continuing"
}

configure_codex_yolo() {
  local tmp
  mkdir -p "$(dirname "$CODEX_CONFIG")"
  touch "$CODEX_CONFIG"
  tmp="$(mktemp)"
  awk '
    BEGIN { inserted = 0; inroot = 1 }
    inroot && /^[[:space:]]*(approval_policy|sandbox_mode|model|model_reasoning_effort)[[:space:]]*=/ { next }
    inroot && !inserted && /^[[:space:]]*\[/ {
      print "approval_policy = \"never\""
      print "sandbox_mode = \"danger-full-access\""
      print "model = \"gpt-4.5-mini\""
      print "model_reasoning_effort = \"high\""
      print ""
      inserted = 1
      inroot = 0
    }
    /^[[:space:]]*\[/ { inroot = 0 }
    { print }
    END {
      if (!inserted) {
        print "approval_policy = \"never\""
        print "sandbox_mode = \"danger-full-access\""
        print "model = \"gpt-4.5-mini\""
        print "model_reasoning_effort = \"high\""
      }
    }
  ' "$CODEX_CONFIG" > "$tmp"
  mv "$tmp" "$CODEX_CONFIG"

  if ! grep -q "^\[projects.'$HOME'\]" "$CODEX_CONFIG" 2>/dev/null; then
    {
      printf '\n'
      printf "[projects.'%s']\n" "$HOME"
      printf 'trust_level = "trusted"\n'
    } >> "$CODEX_CONFIG"
  fi

  upsert_toml_section_key "$CODEX_CONFIG" "features" "hooks" "true"
  upsert_toml_section_key "$CODEX_CONFIG" "tui" "theme" '"monokai-extended-origin"'
  upsert_toml_section_key "$CODEX_CONFIG" "tui" "pet" '"null-signal"'
  upsert_toml_section_key "$CODEX_CONFIG" 'plugins."github@openai-curated"' "enabled" "true"
}

upsert_toml_section_key() {
  local file="$1" section="$2" key="$3" value="$4" tmp
  tmp="${file}.rice-section-tmp.$$"
  awk -v header="[$section]" -v key="$key" -v value="$value" '
    BEGIN { in_section = 0; found_section = 0; wrote = 0 }
    $0 == header {
      in_section = 1
      found_section = 1
      print
      next
    }
    in_section && /^[[:space:]]*\[/ {
      if (!wrote) print key " = " value
      in_section = 0
      wrote = 1
    }
    in_section && $0 ~ "^[[:space:]]*" key "[[:space:]]*=" {
      if (!wrote) print key " = " value
      wrote = 1
      next
    }
    { print }
    END {
      if (in_section && !wrote) print key " = " value
      if (!found_section) {
        print ""
        print header
        print key " = " value
      }
    }
  ' "$file" > "$tmp"
  mv "$tmp" "$file"
}

configure_claude_bypass() {
  local dir="$HOME/.claude" cfg="$HOME/.claude/settings.json"
  mkdir -p "$dir"
  if [ ! -s "$cfg" ]; then
    cat > "$cfg" <<'JSON'
{
  "model": "claude-sonnet-4-6",
  "permissions": { "defaultMode": "auto" }
}
JSON
    step "Configured Claude Code (claude-sonnet-4-6, auto mode, new settings.json)"
    return
  fi
  if have node; then
    node -e 'const fs=require("fs"),p=process.argv[1];let j={};try{j=JSON.parse(fs.readFileSync(p,"utf8")||"{}")}catch(e){}; j.model="claude-sonnet-4-6"; j.permissions=j.permissions||{}; j.permissions.defaultMode="auto"; delete j.skipDangerousModePermissionPrompt; fs.writeFileSync(p,JSON.stringify(j,null,2)+"\n")' "$cfg" \
      && step "Merged Claude sonnet-4-6 + auto mode into settings.json"
  elif have python3; then
    python3 - "$cfg" <<'PY'
import json, sys
p = sys.argv[1]
try:
    j = json.load(open(p))
except Exception:
    j = {}
j["model"] = "claude-sonnet-4-6"
j.setdefault("permissions", {})["defaultMode"] = "auto"
j.pop("skipDangerousModePermissionPrompt", None)
json.dump(j, open(p, "w"), indent=2)
open(p, "a").write("\n")
PY
    step "Merged Claude sonnet-4-6 + auto mode into settings.json"
  else
    step "Claude settings.json exists; set model=claude-sonnet-4-6 and permissions.defaultMode=auto manually (no node/python3)"
  fi
}

install_theme() {
  mkdir -p "$POSH_THEMES"
  # Custom atomic oh-my-posh theme inlined so rice.sh is a single, self-contained file.
  cat > "$POSH_THEMES/atomic.omp.json" <<'OMPJSON'
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
          "template": " {{ .Icon }} ",
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
OMPJSON
  chmod 0644 "$POSH_THEMES/atomic.omp.json" || true
}

# Theme-derived env (FZF colors, BAT_THEME) consumed by the static shell blocks.
write_theme_env() {
  mkdir -p "$RICE_ENV_DIR"
  if [ "${THEME:-none}" = none ]; then
    : > "$RICE_ENV_DIR/theme.sh"
    : > "$RICE_ENV_DIR/theme.fish"
    return
  fi
  local fzf_opts bat_theme
  fzf_opts="--height 40% --layout=reverse --border --color=bg:$TH_BG,fg:$TH_FG,hl:$TH_C4,bg+:$TH_SELBG,fg+:$TH_C15,hl+:$TH_C6,info:$TH_C2,prompt:$TH_C4,pointer:$TH_C5,marker:$TH_C2,spinner:$TH_C5,header:$TH_C10"
  case "$THEME" in
    solarized-dark) bat_theme="Solarized (dark)" ;;
    solarized-light) bat_theme="Solarized (light)" ;;
    *) bat_theme="base16" ;;
  esac

  cat > "$RICE_ENV_DIR/theme.sh" <<EOF_ENV
# generated by rice.sh — theme: $THEME
export FZF_DEFAULT_OPTS='$fzf_opts'
export BAT_THEME='$bat_theme'
EOF_ENV

  cat > "$RICE_ENV_DIR/theme.fish" <<EOF_ENVF
# generated by rice.sh — theme: $THEME
set -gx FZF_DEFAULT_OPTS '$fzf_opts'
set -gx BAT_THEME '$bat_theme'
EOF_ENVF
}

# ---------------------------------------------------------------------------
# Shell startup blocks
# ---------------------------------------------------------------------------

replace_managed_block() {
  local file="$1" block="$2" tmp
  mkdir -p "$(dirname "$file")"
  touch "$file"
  tmp="$(mktemp)"
  sed "/^$MANAGED_START\$/,/^$MANAGED_END\$/d" "$file" > "$tmp"
  {
    cat "$tmp"
    printf '\n%s\n' "$block"
  } > "$file"
  rm -f "$tmp"
}

configure_bash() {
  local block
  block="$(cat <<'EOF'
# --- rice-managed start ---
export PATH="$HOME/.local/bin:/usr/local/bin:$PATH"

case $- in
  *i*)
    if command -v fastfetch >/dev/null 2>&1 && [ -z "${FASTFETCH_RAN:-}" ]; then
      export FASTFETCH_RAN=1
      fastfetch
    fi
    if command -v oh-my-posh >/dev/null 2>&1; then
      if [ -f "$HOME/.cache/oh-my-posh/themes/atomic.omp.json" ]; then
        eval "$(oh-my-posh init bash --config "$HOME/.cache/oh-my-posh/themes/atomic.omp.json")"
      else
        eval "$(oh-my-posh init bash)"
      fi
    fi

    [ -r "$HOME/.config/rice/theme.sh" ] && . "$HOME/.config/rice/theme.sh"

    if command -v eza >/dev/null 2>&1; then
      alias ls='eza --group-directories-first --icons=auto'
      alias ll='eza -lah --group-directories-first --icons=auto --git'
      alias la='eza -a --group-directories-first --icons=auto'
      alias lt='eza --tree --level=2 --icons=auto'
    else
      alias ll='ls -alF'
      alias la='ls -A'
      alias l='ls -CF'
    fi
    if command -v bat >/dev/null 2>&1; then
      alias cat='bat --paging=never'
    elif command -v batcat >/dev/null 2>&1; then
      alias bat='batcat'
      alias cat='batcat --paging=never'
    fi
    if ! command -v fd >/dev/null 2>&1 && command -v fdfind >/dev/null 2>&1; then
      alias fd='fdfind'
    fi
    if command -v rg >/dev/null 2>&1; then
      export FZF_DEFAULT_COMMAND='rg --files --hidden --glob "!.git/*"'
      export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
    fi
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
    command -v zoxide >/dev/null 2>&1 && eval "$(zoxide init bash)"
    ;;
esac

# Add your own host/ssh shortcut aliases here.
alias update='if command -v apt >/dev/null 2>&1; then sudo apt update -y && sudo apt full-upgrade -y; elif command -v pacman >/dev/null 2>&1; then sudo pacman -Syu --noconfirm; elif command -v dnf >/dev/null 2>&1; then sudo dnf upgrade -y; elif command -v zypper >/dev/null 2>&1; then sudo zypper --non-interactive update; elif command -v apk >/dev/null 2>&1; then sudo apk upgrade; fi'
# --- rice-managed end ---
EOF
)"
  replace_managed_block "$BASHRC" "$block"
  replace_managed_block "$ZSHRC" "$block"
}

configure_fish() {
  local block
  block="$(cat <<'EOF'
# --- rice-managed start ---
set -gx PATH $HOME/.local/bin /usr/local/bin $PATH

if status is-interactive; and command -q fastfetch; and not set -q FASTFETCH_RAN
    set -gx FASTFETCH_RAN 1
    fastfetch
end

if command -q oh-my-posh
    if test -f $HOME/.cache/oh-my-posh/themes/atomic.omp.json
        oh-my-posh init fish --config $HOME/.cache/oh-my-posh/themes/atomic.omp.json | source
    else
        oh-my-posh init fish | source
    end
end

if status is-interactive
    test -r "$HOME/.config/rice/theme.fish"; and source "$HOME/.config/rice/theme.fish"

    if command -q eza
        alias ls='eza --group-directories-first --icons=auto'
        alias ll='eza -lah --group-directories-first --icons=auto --git'
        alias la='eza -a --group-directories-first --icons=auto'
        alias lt='eza --tree --level=2 --icons=auto'
    end
    if command -q bat
        alias cat='bat --paging=never'
    else if command -q batcat
        alias bat='batcat'
        alias cat='batcat --paging=never'
    end
    if not command -q fd; and command -q fdfind
        alias fd='fdfind'
    end
    if command -q rg
        set -gx FZF_DEFAULT_COMMAND 'rg --files --hidden --glob "!.git/*"'
    end
    command -q zoxide; and zoxide init fish | source

    abbr -a gst 'git status'
    abbr -a ga 'git add'
    abbr -a gc 'git commit'
    abbr -a gco 'git checkout'
    abbr -a gsw 'git switch'
    abbr -a gp 'git push'
    abbr -a gl 'git pull'
    abbr -a gd 'git diff'
    abbr -a gb 'git branch'
    abbr -a glog 'git log --oneline --graph --decorate'

    bind \t complete-and-search
end

# Add your own host shortcuts and helper functions here.

# Sudo-transparent wrappers for commands that commonly need root.
function __rice_sudo_wrap --argument-names cmd
    if command -q $cmd
        function $cmd --wraps $cmd --inherit-variable cmd
            command sudo $cmd $argv
        end
    end
end

# AUR helpers such as yay/paru and makepkg intentionally stay unwrapped; Arch expects them to run as your user.
for cmd in apt apt-get dpkg snap pacman pacman-key reflector rankmirrors cachyos-rate-mirrors mkinitcpio dracut depmod grub-mkconfig grub-install bootctl kernel-install dkms modprobe rmmod insmod dnf zypper apk npm npx corepack yarn pnpm docker docker-compose systemctl journalctl service systemd-analyze loginctl networkctl resolvectl systemd-resolve nmcli mount umount reboot shutdown poweroff ip iw rfkill iptables ip6tables nft firewall-cmd ufw sysctl sysctl.d usermod groupmod gpasswd chown chmod chgrp mkdir rmdir rm cp mv ln tee sed nano vim nvim vi touch install update-alternatives chsh visudo crontab timedatectl localectl hostnamectl hwclock locale-gen
    __rice_sudo_wrap $cmd
end

functions -e __rice_sudo_wrap
function update
    if command -q apt
        command sudo apt update -y; and command sudo apt full-upgrade -y
    else if command -q pacman
        command sudo pacman -Syu --noconfirm
    else if command -q dnf
        command sudo dnf upgrade -y
    else if command -q zypper
        command sudo zypper --non-interactive update
    else if command -q apk
        command sudo apk upgrade
    end
end
# --- rice-managed end ---
EOF
)"
  replace_managed_block "$CONFIG_FISH" "$block"
}

install_fisher_plugins() {
  have fish || return 0
  fish -c 'curl -sL https://git.io/fisher | source; and fisher install jorgebucaran/fisher' || true
  fish -c 'fisher install PatrickF1/fzf.fish jorgebucaran/autopair.fish franciscolourenco/done jorgebucaran/nvm.fish' || true
}

# ---------------------------------------------------------------------------
# Terminal emulators (font + chosen theme; only those that are installed)
# ---------------------------------------------------------------------------

set_ini_key() {
  local file=$1 group=$2 key=$3 value=$4 tmp
  mkdir -p "$(dirname "$file")"
  touch "$file"
  tmp="$(mktemp)"
  awk -v group="$group" -v key="$key" -v value="$value" '
    BEGIN { wanted="[" group "]"; in_group=0; seen=0; written=0 }
    /^\[/ {
      if (in_group && !written) { print key "=" value; written=1 }
      in_group=($0==wanted); if (in_group) seen=1
      print; next
    }
    in_group && index($0, key "=")==1 { if (!written){print key "=" value; written=1} next }
    { print }
    END {
      if (!seen) { print wanted; print key "=" value }
      else if (in_group && !written) { print key "=" value }
    }
  ' "$file" > "$tmp"
  install -m 0644 "$tmp" "$file"
  rm -f "$tmp"
}

gsettings_schema_available() {
  have gsettings || return 1
  { gsettings list-schemas 2>/dev/null; gsettings list-relocatable-schemas 2>/dev/null; } | grep -qxF "$1"
}

gnome_default_profile_id() {
  local d l
  d=$(gsettings get org.gnome.Terminal.ProfilesList default 2>/dev/null | sed "s/^'//;s/'$//" || true)
  if [ -n "$d" ] && [ "$d" != "''" ]; then printf '%s\n' "$d"; return; fi
  l=$(gsettings get org.gnome.Terminal.ProfilesList list 2>/dev/null || true)
  printf '%s\n' "$l" | sed -n "s/.*'\\([^']\\+\\)'.*/\\1/p" | head -1
}

gnome_palette_array() {
  local c out=""
  for c in $TH_PALETTE; do
    out="$out${out:+, }'$c'"
  done
  printf '[%s]' "$out"
}

configure_term_gnome() {
  gsettings_schema_available "org.gnome.Terminal.Legacy.Profile" || return 0
  local pid path
  pid=$(gnome_default_profile_id); [ -n "$pid" ] || return 0
  path="org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$pid/"
  gsettings set "$path" use-system-font false || true
  gsettings set "$path" font "$FONT_FAMILY $FONT_SIZE" || true
  if [ "$THEME" != none ]; then
    gsettings set "$path" use-theme-colors false || true
    gsettings set "$path" background-color "$TH_BG" || true
    gsettings set "$path" foreground-color "$TH_FG" || true
    gsettings set "$path" bold-color-same-as-fg true || true
    gsettings set "$path" palette "$(gnome_palette_array)" || true
  fi
  step "GNOME Terminal configured"
}

configure_term_konsole() {
  have konsole || return 0
  local share="$HOME/.local/share/konsole" fish_path
  fish_path=$(command -v fish || printf '/usr/bin/fish')
  mkdir -p "$share"
  cat > "$share/SharedRice.profile" <<EOF
[Appearance]
ColorScheme=SharedRice
Font=$FONT_FAMILY,$FONT_SIZE,-1,5,50,0,0,0,0,0

[General]
Command=$fish_path
Name=SharedRice
Parent=FALLBACK/

[Scrolling]
HistoryMode=2
EOF
  if [ "$THEME" != none ]; then
    {
      printf '[Background]\nColor=%s\n\n' "$(hex_to_rgb_commas "$TH_BG")"
      printf '[BackgroundIntense]\nColor=%s\n\n' "$(hex_to_rgb_commas "$TH_C8")"
      printf '[Foreground]\nColor=%s\n\n' "$(hex_to_rgb_commas "$TH_FG")"
      printf '[ForegroundIntense]\nColor=%s\n\n' "$(hex_to_rgb_commas "$TH_C15")"
      local idx=0 c
      for c in $TH_C0 $TH_C1 $TH_C2 $TH_C3 $TH_C4 $TH_C5 $TH_C6 $TH_C7; do
        printf '[Color%d]\nColor=%s\n\n' "$idx" "$(hex_to_rgb_commas "$c")"
        idx=$((idx + 1))
      done
      idx=0
      for c in $TH_C8 $TH_C9 $TH_C10 $TH_C11 $TH_C12 $TH_C13 $TH_C14 $TH_C15; do
        printf '[Color%dIntense]\nColor=%s\n\n' "$idx" "$(hex_to_rgb_commas "$c")"
        idx=$((idx + 1))
      done
      printf '[General]\nDescription=SharedRice\nOpacity=1\n'
    } > "$share/SharedRice.colorscheme"
  fi
  if have kwriteconfig6; then
    kwriteconfig6 --file "$HOME/.config/konsolerc" --group "Desktop Entry" --key DefaultProfile "SharedRice.profile" 2>/dev/null || \
      set_ini_key "$HOME/.config/konsolerc" "Desktop Entry" "DefaultProfile" "SharedRice.profile"
  elif have kwriteconfig5; then
    kwriteconfig5 --file "$HOME/.config/konsolerc" --group "Desktop Entry" --key DefaultProfile "SharedRice.profile" 2>/dev/null || \
      set_ini_key "$HOME/.config/konsolerc" "Desktop Entry" "DefaultProfile" "SharedRice.profile"
  else
    set_ini_key "$HOME/.config/konsolerc" "Desktop Entry" "DefaultProfile" "SharedRice.profile"
  fi
  step "Konsole configured"
}

configure_term_alacritty() {
  have alacritty || [ -d "$HOME/.config/alacritty" ] || return 0
  local dir="$HOME/.config/alacritty"
  mkdir -p "$dir"
  {
    printf '# generated by rice.sh\n'
    printf '[font]\nsize = %s.0\n' "$FONT_SIZE"
    printf 'normal = { family = "%s", style = "Regular" }\n' "$FONT_FAMILY"
    if [ "$THEME" != none ]; then
      printf '\n[colors.primary]\nbackground = "%s"\nforeground = "%s"\n' "$TH_BG" "$TH_FG"
      printf '\n[colors.cursor]\ntext = "%s"\ncursor = "%s"\n' "$TH_BG" "$TH_CURSOR"
      printf '\n[colors.selection]\nbackground = "%s"\ntext = "CellForeground"\n' "$TH_SELBG"
      printf '\n[colors.normal]\nblack = "%s"\nred = "%s"\ngreen = "%s"\nyellow = "%s"\nblue = "%s"\nmagenta = "%s"\ncyan = "%s"\nwhite = "%s"\n' \
        "$TH_C0" "$TH_C1" "$TH_C2" "$TH_C3" "$TH_C4" "$TH_C5" "$TH_C6" "$TH_C7"
      printf '\n[colors.bright]\nblack = "%s"\nred = "%s"\ngreen = "%s"\nyellow = "%s"\nblue = "%s"\nmagenta = "%s"\ncyan = "%s"\nwhite = "%s"\n' \
        "$TH_C8" "$TH_C9" "$TH_C10" "$TH_C11" "$TH_C12" "$TH_C13" "$TH_C14" "$TH_C15"
    fi
  } > "$dir/shared-rice.toml"

  local import_line="general.import = [\"$dir/shared-rice.toml\"]"
  local main="$dir/alacritty.toml" tmp
  touch "$main"
  tmp="$(mktemp)"
  sed "/^$MANAGED_START\$/,/^$MANAGED_END\$/d" "$main" > "$tmp"
  {
    printf '%s\n%s\n%s\n' "$MANAGED_START" "$import_line" "$MANAGED_END"
    cat "$tmp"
  } > "$main"
  rm -f "$tmp"
  step "Alacritty configured"
}

configure_term_kitty() {
  have kitty || [ -d "$HOME/.config/kitty" ] || return 0
  local dir="$HOME/.config/kitty"
  mkdir -p "$dir"
  {
    printf '# generated by rice.sh\n'
    printf 'font_family %s\nfont_size %s.0\n' "$FONT_FAMILY" "$FONT_SIZE"
    if [ "$THEME" != none ]; then
      printf 'background %s\nforeground %s\n' "$TH_BG" "$TH_FG"
      printf 'cursor %s\ncursor_text_color %s\n' "$TH_CURSOR" "$TH_BG"
      printf 'selection_background %s\nselection_foreground %s\n' "$TH_SELBG" "$TH_FG"
      local idx=0 c
      for c in $TH_PALETTE; do
        printf 'color%d %s\n' "$idx" "$c"
        idx=$((idx + 1))
      done
    fi
  } > "$dir/shared-rice.conf"

  local main="$dir/kitty.conf" tmp
  touch "$main"
  tmp="$(mktemp)"
  sed "/^$MANAGED_START\$/,/^$MANAGED_END\$/d" "$main" > "$tmp"
  {
    cat "$tmp"
    printf '%s\ninclude shared-rice.conf\n%s\n' "$MANAGED_START" "$MANAGED_END"
  } > "$main"
  rm -f "$tmp"
  step "Kitty configured"
}

configure_term_wezterm() {
  have wezterm || [ -d "$HOME/.config/wezterm" ] || return 0
  local dir="$HOME/.config/wezterm"
  mkdir -p "$dir/colors"
  if [ "$THEME" != none ]; then
    cat > "$dir/colors/SharedRice.toml" <<EOF
[colors]
background = "$TH_BG"
foreground = "$TH_FG"
cursor_bg = "$TH_CURSOR"
cursor_fg = "$TH_BG"
cursor_border = "$TH_CURSOR"
selection_bg = "$TH_SELBG"
selection_fg = "$TH_FG"
ansi = ["$TH_C0","$TH_C1","$TH_C2","$TH_C3","$TH_C4","$TH_C5","$TH_C6","$TH_C7"]
brights = ["$TH_C8","$TH_C9","$TH_C10","$TH_C11","$TH_C12","$TH_C13","$TH_C14","$TH_C15"]
EOF
  fi
  # Only create wezterm.lua if the user has none, to avoid clobbering a custom config.
  if [ ! -e "$dir/wezterm.lua" ]; then
    local scheme_line=""
    [ "$THEME" != none ] && scheme_line="  color_scheme = 'SharedRice',"
    cat > "$dir/wezterm.lua" <<EOF
local wezterm = require 'wezterm'
return {
  font = wezterm.font('$FONT_FAMILY'),
  font_size = $FONT_SIZE.0,
$scheme_line
}
EOF
    step "WezTerm configured (new wezterm.lua)"
  else
    step "WezTerm color scheme written; existing wezterm.lua left intact (add color_scheme='SharedRice')"
  fi
}

configure_term_xfce4() {
  have xfce4-terminal || [ -f "$HOME/.config/xfce4/terminal/terminalrc" ] || return 0
  local rc="$HOME/.config/xfce4/terminal/terminalrc"
  set_ini_key "$rc" "Configuration" "FontName" "$FONT_FAMILY $FONT_SIZE"
  set_ini_key "$rc" "Configuration" "FontUseSystem" "FALSE"
  if [ "$THEME" != none ]; then
    set_ini_key "$rc" "Configuration" "ColorForeground" "$TH_FG"
    set_ini_key "$rc" "Configuration" "ColorBackground" "$TH_BG"
    set_ini_key "$rc" "Configuration" "ColorCursor" "$TH_CURSOR"
    local pal c
    pal=""
    for c in $TH_PALETTE; do pal="$pal${pal:+;}$c"; done
    set_ini_key "$rc" "Configuration" "ColorPalette" "$pal"
  fi
  step "xfce4-terminal configured"
}

configure_term_foot() {
  have foot || [ -f "$HOME/.config/foot/foot.ini" ] || return 0
  local rc="$HOME/.config/foot/foot.ini"
  set_ini_key "$rc" "main" "font" "$FONT_FAMILY:size=$FONT_SIZE"
  if [ "$THEME" != none ]; then
    set_ini_key "$rc" "colors" "background" "${TH_BG#\#}"
    set_ini_key "$rc" "colors" "foreground" "${TH_FG#\#}"
    local idx=0 c
    for c in $TH_C0 $TH_C1 $TH_C2 $TH_C3 $TH_C4 $TH_C5 $TH_C6 $TH_C7; do
      set_ini_key "$rc" "colors" "regular$idx" "${c#\#}"; idx=$((idx + 1))
    done
    idx=0
    for c in $TH_C8 $TH_C9 $TH_C10 $TH_C11 $TH_C12 $TH_C13 $TH_C14 $TH_C15; do
      set_ini_key "$rc" "colors" "bright$idx" "${c#\#}"; idx=$((idx + 1))
    done
  fi
  step "foot configured"
}

configure_term_tilix() {
  have tilix || return 0
  have dconf || return 0
  local uuid base
  uuid=$(dconf read /com/gexperts/Tilix/profiles/default 2>/dev/null | sed "s/^'//;s/'$//" || true)
  [ -n "$uuid" ] || return 0
  base="/com/gexperts/Tilix/profiles/$uuid"
  dconf write "$base/use-system-font" false 2>/dev/null || true
  dconf write "$base/font" "'$FONT_FAMILY $FONT_SIZE'" 2>/dev/null || true
  if [ "$THEME" != none ]; then
    dconf write "$base/use-theme-colors" false 2>/dev/null || true
    dconf write "$base/background-color" "'$TH_BG'" 2>/dev/null || true
    dconf write "$base/foreground-color" "'$TH_FG'" 2>/dev/null || true
    dconf write "$base/palette" "$(gnome_palette_array)" 2>/dev/null || true
  fi
  step "Tilix configured"
}

configure_terminals() {
  [ "$SKIP_TERMINALS" -eq 0 ] || { step "Skipping terminal-emulator configuration"; return; }
  step "Configuring installed terminal emulators (theme=$THEME)"
  configure_term_gnome
  configure_term_konsole
  configure_term_alacritty
  configure_term_kitty
  configure_term_wezterm
  configure_term_xfce4
  configure_term_foot
  configure_term_tilix
}

write_fastfetch() {
  [ "${THEME:-none}" = none ] && return 0
  local cfg="$HOME/.config/fastfetch/config.jsonc"
  mkdir -p "$(dirname "$cfg")"
  local keys title sep
  keys=$(hex_to_ansi_fg "$TH_C6")
  title=$(hex_to_ansi_fg "$TH_C4")
  sep=$(hex_to_ansi_fg "$TH_C4")
  cat > "$cfg" <<EOF
{
  "\$schema": "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json",
  "logo": { "type": "auto" },
  "display": {
    "separator": " -> ",
    "color": { "keys": "$keys", "title": "$title", "separator": "$sep" }
  },
  "modules": [
    "title", "separator", "os", "host", "kernel", "uptime", "packages",
    "shell", "de", "wm", "terminal", "cpu", "gpu", "memory", "disk",
    "localip", "break", "colors"
  ]
}
EOF
  step "fastfetch themed"
}

configure_shell_change() {
  [ "$SKIP_SHELL_CHANGE" -eq 0 ] || return 0
  have fish || return 0
  local fish_path
  fish_path="$(command -v fish)"
  if ! grep -qxF "$fish_path" /etc/shells 2>/dev/null; then
    printf '%s\n' "$fish_path" | need_root tee -a /etc/shells >/dev/null || true
  fi
  chsh -s "$fish_path" 2>/dev/null || step "Could not change shell automatically. Run: chsh -s $fish_path"
}

main() {
  local role
  role="$(detect_role)"
  step "Preparing Linux rice for role=$role, host=$(hostname)"
  select_theme
  install_packages "$role"
  install_ohmyposh
  if [ "$WITH_AGENT_CONFIG" -eq 1 ]; then
    install_codex
    configure_codex_yolo
    configure_claude_bypass
  else
    step "AI agent configuration skipped (--skip-agent-config)"
  fi
  install_fonts
  install_theme
  write_theme_env
  configure_bash
  configure_fish
  install_fisher_plugins
  write_fastfetch
  configure_terminals
  configure_shell_change
  step "Linux rice complete. Open a new terminal, or run: exec fish"
}

main
