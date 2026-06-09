# Windows Utilities

These utilities package small desktop workflows as inspectable PowerShell
scripts with no-flash launchers.

## Hidden Launcher Pattern

Each background-style tool uses three layers:

1. a PowerShell worker containing the real logic;
2. a small `.cmd` entry point where command-shell behavior is useful;
3. a VBScript launcher that invokes the command with window style `0`.

For a shortcut, target `wscript.exe` and pass the full path to the matching
`Run-*-Hidden.vbs` file. This keeps a console window from briefly appearing.

## Included Tools

### Borderless Image Viewer

`borderless-image-viewer/Borderless-Image-Viewer.ps1` displays one or more
images in a borderless Windows Forms viewer. Use the hidden VBScript launcher
for normal desktop use.

### Restart Explorer

`restart-explorer/Restart-Explorer.cmd` restarts Windows Explorer. Launch it
through `Run-Restart-Explorer-Hidden.vbs` to avoid a visible console.

### Toggle Ethernet DNS

`toggle-ethernet-dns/Toggle-Ethernet-DNS.ps1` toggles an Ethernet adapter
between DHCP-provided DNS and a configurable manual resolver list. Review the
adapter name and resolver values at the top of the script before use.

### Capture Terminal

`self-verify/Capture-Terminal.ps1` opens a Windows Terminal command, captures
the resulting window to an image, and closes the temporary terminal. It is
useful for visual verification in automated desktop workflows.

## Review Before Use

The scripts modify desktop state and, in the DNS case, network configuration.
Read the worker script first and run it from an existing terminal during initial
testing. Use the hidden launcher only after the behavior matches the local
machine.
