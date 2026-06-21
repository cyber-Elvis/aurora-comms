#Requires -Version 5.1
[CmdletBinding()]
param(
    [switch]$ApplySafeFixes,
    [switch]$DisableWifiDevicePowerSaving,
    [string[]]$AllowedControllers = @("100.88.225.123", "100.109.74.61"),
    [string]$FirewallRuleName = "Aurora-MWB-PC3-Inbound"
)

$ErrorActionPreference = "Stop"

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-MwbProcesses {
    Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match "^MouseWithoutBorders.*\.exe$" }
}

function Get-MwbExecutable {
    $processPath = Get-MwbProcesses |
        Where-Object { $_.Name -eq "MouseWithoutBorders.exe" -and $_.ExecutablePath } |
        Select-Object -First 1 -ExpandProperty ExecutablePath

    if ($processPath) {
        return $processPath
    }

    $knownPaths = @(
        "${env:ProgramFiles(x86)}\Microsoft Garage\Mouse without Borders\MouseWithoutBorders.exe",
        "$env:ProgramFiles\PowerToys\WinUI3Apps\PowerToys.MouseWithoutBorders.exe",
        "$env:LOCALAPPDATA\PowerToys\PowerToys.MouseWithoutBorders.exe"
    )

    return $knownPaths | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
}

function Show-Section {
    param([Parameter(Mandatory = $true)][string]$Title)
    Write-Host ""
    Write-Host "== $Title =="
}

Show-Section "Identity"
Write-Host "Computer: $env:COMPUTERNAME"
Write-Host "User:     $env:USERDOMAIN\$env:USERNAME"
Write-Host "Admin:    $(Test-IsAdministrator)"

Show-Section "Mouse Without Borders processes"
$mwbProcesses = Get-MwbProcesses
$mwbProcesses |
    Select-Object Name, ProcessId, ExecutablePath, CommandLine |
    Format-Table -AutoSize

$mwbExecutable = Get-MwbExecutable
if ($mwbExecutable) {
    $file = Get-Item -LiteralPath $mwbExecutable
    Write-Host "Executable:     $mwbExecutable"
    Write-Host "File version:   $($file.VersionInfo.FileVersion)"
    Write-Host "Product version:$($file.VersionInfo.ProductVersion)"
} else {
    Write-Warning "Mouse Without Borders executable was not found."
}

Show-Section "MWB listeners and connections"
Get-NetTCPConnection -ErrorAction SilentlyContinue |
    Where-Object {
        $_.LocalPort -in 15100, 15101 -or
        $_.RemotePort -in 15100, 15101
    } |
    Select-Object State, LocalAddress, LocalPort, RemoteAddress, RemotePort, OwningProcess |
    Sort-Object State, LocalPort |
    Format-Table -AutoSize

Show-Section "MWB firewall rules"
$mwbRules = Get-NetFirewallRule -ErrorAction SilentlyContinue |
    Where-Object {
        $_.Name -eq $FirewallRuleName -or
        $_.DisplayName -match "Mouse.*Borders|MouseWithoutBorders"
    }

$mwbRules | ForEach-Object {
    $rule = $_
    $ports = Get-NetFirewallPortFilter -AssociatedNetFirewallRule $rule
    $addresses = Get-NetFirewallAddressFilter -AssociatedNetFirewallRule $rule
    [pscustomobject]@{
        Name = $rule.Name
        Enabled = $rule.Enabled
        Direction = $rule.Direction
        Action = $rule.Action
        Profile = $rule.Profile
        Protocol = $ports.Protocol -join ","
        LocalPort = $ports.LocalPort -join ","
        RemoteAddress = $addresses.RemoteAddress -join ","
    }
} | Format-List

Show-Section "Network profiles"
Get-NetConnectionProfile |
    Select-Object InterfaceAlias, Name, NetworkCategory, IPv4Connectivity |
    Format-Table -AutoSize

Show-Section "Wi-Fi state"
& netsh.exe wlan show interfaces

$wifiAdapters = Get-NetAdapter -Physical -ErrorAction SilentlyContinue |
    Where-Object { $_.InterfaceDescription -match "Wireless|Wi-Fi|802\.11" }

$wifiAdapters |
    Select-Object Name, InterfaceDescription, Status, LinkSpeed, MediaConnectionState |
    Format-Table -AutoSize

foreach ($adapter in $wifiAdapters) {
    Get-NetAdapterPowerManagement -Name $adapter.Name -ErrorAction SilentlyContinue |
        Select-Object Name, SelectiveSuspend, DeviceSleepOnDisconnect |
        Format-Table -AutoSize
}

Show-Section "Tailscale path to PC1"
if (Get-Command tailscale.exe -ErrorAction SilentlyContinue) {
    & tailscale.exe status
    & tailscale.exe ping --timeout=5s 100.88.225.123
} else {
    Write-Warning "tailscale.exe was not found."
}

Show-Section "Name resolution"
Resolve-DnsName forty3s-pc1 -ErrorAction SilentlyContinue |
    Select-Object Name, Type, IPAddress, NameHost |
    Format-Table -AutoSize

if (-not $ApplySafeFixes) {
    Write-Host ""
    Write-Host "Diagnostic only. Re-run as Administrator with -ApplySafeFixes to:"
    Write-Host "  - allow inbound TCP 15100-15101 only from PC1/PC2 Tailscale IPs"
    Write-Host "  - set Wi-Fi power saving to Maximum Performance while plugged in"
    Write-Host "Add -DisableWifiDevicePowerSaving to also disable Wi-Fi selective suspend/sleep-on-disconnect."
    exit 0
}

if (-not (Test-IsAdministrator)) {
    throw "ApplySafeFixes requires an Administrator PowerShell session."
}

Show-Section "Applying safe fixes"
Get-NetFirewallRule -Name $FirewallRuleName -ErrorAction SilentlyContinue |
    Remove-NetFirewallRule

New-NetFirewallRule `
    -Name $FirewallRuleName `
    -DisplayName "Aurora MWB inbound from PC1 and PC2" `
    -Enabled True `
    -Direction Inbound `
    -Action Allow `
    -Profile Any `
    -Protocol TCP `
    -LocalPort "15100-15101" `
    -RemoteAddress $AllowedControllers | Out-Null

Write-Host "Created restricted firewall rule $FirewallRuleName."

# Wireless Adapter Settings -> Power Saving Mode -> Maximum Performance on AC.
$wirelessSettingsSubgroup = "19cbb8fa-5279-450e-9fac-8a3d5fedd0c1"
$powerSavingSetting = "12bbebe6-58d6-4636-95bb-3217ef867c1a"
& powercfg.exe /setacvalueindex scheme_current $wirelessSettingsSubgroup $powerSavingSetting 0
& powercfg.exe /setactive scheme_current
Write-Host "Set Wi-Fi power saving to Maximum Performance while plugged in."

if ($DisableWifiDevicePowerSaving) {
    foreach ($adapter in $wifiAdapters) {
        Set-NetAdapterPowerManagement `
            -Name $adapter.Name `
            -SelectiveSuspend Disabled `
            -DeviceSleepOnDisconnect Disabled `
            -ErrorAction Stop
        Write-Host "Disabled selective suspend and sleep-on-disconnect for Wi-Fi adapter: $($adapter.Name)"
    }
}

Write-Host ""
Write-Host "In Mouse Without Borders settings on PC3:"
Write-Host "  1. Turn off 'Same subnet only'."
Write-Host "  2. Use host name 'forty3s-pc1' for PC1."
Write-Host "  3. Select 'Refresh connections'."
Write-Host "  4. Keep the same MWB implementation/version on all three PCs."
