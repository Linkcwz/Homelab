# Toggle-Ethernet-DNS.ps1
# Switches Ethernet IPv4 DNS between DHCP and manual public DNS.

$InterfaceAlias = "Ethernet"
$ManualDns = @("8.8.8.8", "1.1.1.1")

# Relaunch elevated if needed
$IsAdmin = ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $IsAdmin) {
    Start-Process powershell.exe -Verb RunAs -ArgumentList @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-WindowStyle", "Hidden",
        "-File", "`"$PSCommandPath`""
    ) -WindowStyle Hidden
    exit
}

# If "Ethernet" is not exact, try to find an up Ethernet-ish adapter
$Adapter = Get-NetAdapter |
    Where-Object { $_.Status -eq "Up" -and $_.Name -eq $InterfaceAlias } |
    Select-Object -First 1

if (-not $Adapter) {
    $Adapter = Get-NetAdapter |
        Where-Object { $_.Status -eq "Up" -and $_.Name -like "Ethernet*" } |
        Select-Object -First 1
}

if (-not $Adapter) {
    Add-Type -AssemblyName PresentationFramework
    [System.Windows.MessageBox]::Show("No active Ethernet adapter found.", "DNS Toggle")
    exit 1
}

$InterfaceAlias = $Adapter.Name

$CurrentDns = (Get-DnsClientServerAddress -InterfaceAlias $InterfaceAlias -AddressFamily IPv4).ServerAddresses

$UsingManual = $false
foreach ($dns in $ManualDns) {
    if ($CurrentDns -contains $dns) {
        $UsingManual = $true
    }
}

if ($UsingManual) {
    Set-DnsClientServerAddress -InterfaceAlias $InterfaceAlias -ResetServerAddresses
    ipconfig /flushdns | Out-Null
    $Message = "DNS reset to DHCP on $InterfaceAlias"
} else {
    Set-DnsClientServerAddress -InterfaceAlias $InterfaceAlias -ServerAddresses $ManualDns
    ipconfig /flushdns | Out-Null
    $Message = "DNS set to $($ManualDns -join ', ') on $InterfaceAlias"
}

Add-Type -AssemblyName PresentationFramework
[System.Windows.MessageBox]::Show($Message, "DNS Toggle")
