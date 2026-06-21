#Requires -RunAsAdministrator
[CmdletBinding()]
param(
    [string[]]$AllowedRemoteAddress = @(
        "100.88.225.123",
        "192.168.18.20"
    )
)

$ErrorActionPreference = "Stop"
$bootstrap = Join-Path $PSScriptRoot "pc2-enable-remote-management.ps1"

if (-not (Test-Path -LiteralPath $bootstrap)) {
    throw "Required bootstrap script not found: $bootstrap"
}

& $bootstrap `
    -EnableWinRM `
    -InstallStartupRepair `
    -StartupTaskName "Aurora-Repair-PC3-Maintenance" `
    -AllowedRemoteAddress $AllowedRemoteAddress
