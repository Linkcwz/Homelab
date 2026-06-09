# Cross-Platform Terminal Rice

The ricing utilities configure a practical terminal environment on Linux and
Windows. They are intended to be readable, rerunnable, and easy to fork.

## One File, Both Platforms

`rice.cmd` is a true zero-dependency `cmd`/`sh` polyglot. Run the *same* file
under `cmd` on Windows or `sh` on Linux and it dispatches to the matching ricer
below — using only the shell each OS already ships.

```sh
sh ./rice.cmd      # Linux / macOS
```

```powershell
.\rice.cmd         # Windows
```

Each run opens with an interactive theme picker (live color preview) defaulting
to **Solarized Dark** (Solarized Light and `none` are also offered). Pass
`--theme=solarized-dark` / `-Theme solarized-dark`, or `--no-prompt`, to skip it.

## Linux

`rice.sh` detects common distribution families and package managers, installs
the available command-line tools (eza, bat, ripgrep, fd, fzf, zoxide), installs
FiraCode Nerd Font and Oh My Posh, configures Bash, Zsh, and Fish, themes every
installed terminal emulator to match. It can also configure OpenAI Codex and
Claude Code for unattended local execution, but only when you opt in with
`--with-agent-config` (off by default).

Supported package managers include `pacman`, `apt`, `dnf`, `yum`, `zypper`, and
`apk`. Terminal configuration covers GNOME Terminal, Konsole, Alacritty, Kitty,
WezTerm, Xfce Terminal, foot, and Tilix when present.

```sh
chmod +x ./rice.sh
./rice.sh          # interactive theme picker, defaults to Solarized Dark
```

Available themes:

- `solarized-dark` (default)
- `solarized-light`
- `none` to leave terminal colors unchanged

Useful options:

```text
--no-prompt
--skip-terminals
--with-agent-config
--skip-font-install
--skip-package-install
--skip-shell-change
```

The script writes managed blocks to shell startup files so rerunning it replaces
its own configuration instead of appending duplicate blocks. Review the script
before running it: package installation and changing the login shell require
elevated privileges.

## Windows

`rice.ps1` uses WinGet for Fastfetch, Oh My Posh, and the QoL CLI tools; installs
FiraCode Nerd Font for the current user; writes managed PowerShell profile
blocks; and themes Windows Terminal (font + a generated `SharedRice` color
scheme) plus WezTerm/Alacritty when present. It can optionally install and
configure OpenAI Codex and Claude Code for unattended local execution with
`-WithAgentConfig` (off by default).

```powershell
Set-ExecutionPolicy -Scope Process Bypass
./rice.ps1
```

To skip package or font installation:

```powershell
./rice.ps1 -SkipPackageInstall -SkipFontInstall
```

Pass `-WithAgentConfig` to opt in to installing and configuring the AI agents;
by default they are left untouched.

## Unattended Agent Configuration (opt-in)

This is **off by default** — the scripts do not touch your AI tools unless you
pass `--with-agent-config` (Linux) or `-WithAgentConfig` (Windows).

> ⚠️ When enabled, this grants local AI coding agents unattended, full-access
> authority. It assumes an **already-sandboxed, personally controlled
> workstation** and is **not appropriate on a shared, untrusted, or production
> machine.**

When enabled, both platform scripts write these root settings to the OpenAI
Codex `config.toml` and mark the current home directory as trusted:

```toml
approval_policy = "never"
sandbox_mode = "danger-full-access"
model = "gpt-5.5"
model_reasoning_effort = "high"
```

They also set Claude Code to bypass-permissions in `~/.claude/settings.json`
(`permissions.defaultMode = "bypassPermissions"`), merging into any existing
settings rather than overwriting them.

This gives the agent the same filesystem and process authority as the account
running it — deliberate inside a controlled, sandboxed environment, dangerous
outside one. The surrounding repository guardrails (scoped staging, mechanically
enforced rules, isolated public export) are what make that posture safe here; a
random downloader does not have them, which is why it is opt-in.

## Theme

`atomic.omp.json` is the included Oh My Posh prompt theme. Both `rice.sh` and
`rice.ps1` also embed an inline copy, so each runs as a single downloaded file —
and the polyglot `rice.cmd` carries both.

## Extending

Keep environment-specific functions — host/ssh shortcuts, network helpers — in a
separate profile file so updates to the shared ricer stay easy to consume.
