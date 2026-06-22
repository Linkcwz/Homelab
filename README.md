# Linkcwz Homelab

A practical reference architecture for a self-hosted private cloud built from
Proxmox, OPNsense, Caddy, AdGuard Home, Unbound, Samba AD, Authentik, NetBird,
TrueNAS, Nextcloud, Coder, Prometheus, and Grafana.

This is a curated public view of a real operating environment. Product choices,
design decisions, dependency boundaries, failure modes, and reusable examples
are kept concrete. Credentials, personal records, exact internal addressing,
live access paths, and private operational state are excluded.

## Proven Under Fire

This is not a lab diagram. The cluster survived a real migration off one Proxmox
node (NA1) and onto another (Delta), with critical services replicated onto a
Windows workstation (Hermes) and even a pocket-sized travel router — so access
never depended on a single box. The failure-domain separation described below is
exactly what made that migration boring instead of catastrophic.

The platform has since gained **near-instant automatic failover**: a second
Proxmox control-plane node carries floating gateway and DNS virtual IPs plus
block-level storage replication, so losing the primary node fails over to the
standby on its own — automatic resilience layered on top of the manual-migration
resilience it already proved.

You do not have to take that on faith. The recovery dependency order is data, not
prose: run [`scripts/Test-RecoveryPlan.ps1`](scripts/Test-RecoveryPlan.ps1)
against [`examples/recovery-plan.json`](examples/recovery-plan.json) and it
resolves — or rejects — the same dependency graph the migration followed.

## What Is Here

- [Cross-platform terminal rice](utilities/rice/README.md): a single
  zero-dependency `cmd`/`sh` polyglot (`rice.cmd`) plus standalone Linux/Windows
  scripts — FiraCode Nerd Font, Oh My Posh, a previewed theme picker that themes
  every installed terminal, quality-of-life CLI tools, and optional unattended
  AI-agent configuration (Codex + Claude Code).
- [Windows utilities](utilities/windows/README.md): hidden-launcher desktop tools
  — borderless image viewer, Explorer restart, Ethernet DNS toggle, and terminal
  visual-capture, each as an inspectable PowerShell worker + no-flash `.vbs`.
- [Architecture](docs/architecture.md): the platform layers and request paths.
- [Identity-aware ingress](docs/identity-aware-ingress.md): Authentik and Caddy
  forward-auth patterns, including a working example configuration.
- [Split-horizon DNS](docs/split-horizon-dns.md): local routing without breaking
  roaming clients.
- [Browser workstation](docs/browser-workstation.md): persistent Coder and
  browser IDE design.
- [Disaster recovery](docs/disaster-recovery.md): dependency-ordered recovery
  and verification.
- [Repo-backed operations](docs/repo-backed-operations.md): portable operating
  knowledge for humans and AI agents.
- [Travel-router validation](docs/travel-router.md): keeping remote access an
  overlay rather than a dependency.
- [Recovery plan example](examples/recovery-plan.json): a machine-readable
  service dependency graph.
- [Recovery plan validator](scripts/Test-RecoveryPlan.ps1): validates names,
  dependencies, checks, and cycles, then prints a safe recovery order.

## Get The Rice

One file, both platforms. [`utilities/rice/rice.cmd`](utilities/rice/rice.cmd)
is a true zero-dependency `cmd`/`sh` polyglot: the *same* file runs the Windows
ricer under `cmd` and the Linux ricer under `sh`, using only the shell each OS
already ships — nothing to install first.

Linux (downloads the script so you can read it before running):

```sh
curl -fsSLO https://raw.githubusercontent.com/Linkcwz/Homelab/main/utilities/rice/rice.cmd
sh ./rice.cmd
```

Windows PowerShell:

```powershell
Invoke-WebRequest https://raw.githubusercontent.com/Linkcwz/Homelab/main/utilities/rice/rice.cmd -OutFile rice.cmd
.\rice.cmd
```

Prefer per-platform scripts? [`rice.sh`](utilities/rice/rice.sh) (Linux) and
[`rice.ps1`](utilities/rice/rice.ps1) (Windows) are standalone too. Each starts
with an interactive theme picker that shows a live color preview and defaults to
**Solarized Dark** (Solarized Light is also offered). Skip the prompt with
`--theme=solarized-dark` / `-Theme solarized-dark`, or `--no-prompt`.

Every terminal emulator it finds — Windows Terminal, GNOME Terminal, Konsole,
Alacritty, Kitty, WezTerm, foot, xfce4-terminal, Tilix — is themed to match,
along with FiraCode Nerd Font, an Oh My Posh prompt, and quality-of-life CLI
tools (eza, bat, ripgrep, fd, fzf, zoxide).

> **AI agents are left alone by default.** These scripts do **not** touch your
> OpenAI Codex or Claude Code setup unless you explicitly opt in with
> `--with-agent-config` (Linux) / `-WithAgentConfig` (Windows). That optional
> step grants those agents unattended, full-access authority (Codex
> `danger-full-access`, Claude bypass-permissions) — the "YOLO inside a steel
> cage" posture documented in
> [repo-backed operations](docs/repo-backed-operations.md), appropriate only on
> a **personally controlled, already-sandboxed workstation** and **never on a
> shared, untrusted, or production host.**

## Try It

PowerShell 7 is sufficient for the included validation tools:

```powershell
./scripts/Test-PublicRepository.ps1 .
./scripts/Test-RecoveryPlan.ps1 ./examples/recovery-plan.json
```

The example Caddy configuration can be checked with a local Caddy binary:

```sh
caddy validate --config ./examples/Caddyfile --adapter caddyfile
```

Change the example domains and upstream names before deployment.

## Design Position

The project favors integration over service count. The important questions are
not merely which applications are running, but:

1. Which services must recover first?
2. Which identity system authorizes each path?
3. Does local traffic stay local while roaming traffic still works?
4. Can an operator prove the user-facing path from outside the server?
5. Can another person or automation worker reconstruct the reasoning later?

## Public Source Model

Public content is authored in an explicit allowlisted subtree of a private
operations repository. The export is validated, copied into a clean staging
tree, scanned, and published with independent public-only history. Private
repository history is never inherited by this project.

See [Contributing](CONTRIBUTING.md) and [Security](SECURITY.md).
