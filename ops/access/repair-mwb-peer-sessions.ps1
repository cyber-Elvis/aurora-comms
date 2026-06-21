#Requires -Version 5.1
[CmdletBinding()]
param(
    # Each peer maps to ALL IPs MWB might use for it (Wi-Fi LAN + Tailscale).
    # MWB flip-flops between paths, so the peer is "present" if connected via ANY of them.
    # Matching only one IP causes the watchdog to restart MWB on every path switch (churn).
    [hashtable]$ExpectedPeers = @{
        "PC2" = @("192.168.137.1", "100.109.74.61")
        "PC3" = @("192.168.18.29", "100.110.254.10")
    },
    [int]$Port = 15101,
    [int]$ConnectTimeoutMs = 1200,
    [int]$CooldownMinutes = 20
)

$ErrorActionPreference = "Stop"
$stateDirectory = Join-Path $env:LOCALAPPDATA "Aurora"
$statePath = Join-Path $stateDirectory "mwb-peer-repair.state"
$logPath = Join-Path $stateDirectory "mwb-peer-repair.log"
$powerToysExe = Join-Path $env:ProgramFiles "PowerToys\PowerToys.exe"
$mwbExe = Join-Path $env:ProgramFiles "PowerToys\PowerToys.MouseWithoutBorders.exe"

New-Item -ItemType Directory -Path $stateDirectory -Force | Out-Null

function Write-RepairLog {
    param([Parameter(Mandatory = $true)][string]$Message)
    Add-Content -LiteralPath $logPath -Value ("{0:yyyy-MM-dd HH:mm:ss} {1}" -f (Get-Date), $Message)
}

function Test-TcpPort {
    param(
        [Parameter(Mandatory = $true)][string]$Address,
        [Parameter(Mandatory = $true)][int]$RemotePort
    )
    $client = [Net.Sockets.TcpClient]::new()
    try { $task = $client.ConnectAsync($Address, $RemotePort); return $task.Wait($ConnectTimeoutMs) -and $client.Connected }
    catch { return $false }
    finally { $client.Dispose() }
}

function Restart-MouseWithoutBorders {
    Get-Process -Name @(
        "PowerToys.MouseWithoutBordersHelper",
        "PowerToys.MouseWithoutBorders",
        "PowerToys"
    ) -ErrorAction SilentlyContinue | Stop-Process -Force

    Start-Sleep -Seconds 3
    Start-Process -FilePath $powerToysExe
    Start-Sleep -Seconds 10
    if (-not (Get-Process PowerToys.MouseWithoutBorders -ErrorAction SilentlyContinue)) {
        Start-Process -FilePath $mwbExe
    }
}

$establishedAddresses = @(
    Get-NetTCPConnection -State Established -ErrorAction SilentlyContinue |
        Where-Object { $_.LocalPort -in 15100, 15101 -or $_.RemotePort -in 15100, 15101 } |
        Select-Object -ExpandProperty RemoteAddress -Unique
)

$missingReachablePeers = @()
foreach ($peer in $ExpectedPeers.GetEnumerator()) {
    $ips = @($peer.Value)
    # Present if connected via ANY known IP (Wi-Fi LAN or Tailscale).
    if ($ips | Where-Object { $establishedAddresses -contains $_ }) { continue }
    # Missing: only flag if at least one path is actually reachable (peer is online).
    if ($ips | Where-Object { Test-TcpPort -Address $_ -RemotePort $Port }) {
        $missingReachablePeers += $peer.Key
    }
}

if ($missingReachablePeers.Count -eq 0) {
    Write-RepairLog "Healthy or waiting for an offline peer."
    return
}

$lastRepair = [datetime]::MinValue
if (Test-Path -LiteralPath $statePath) {
    [void][datetime]::TryParse((Get-Content -LiteralPath $statePath -Raw), [ref]$lastRepair)
}

if ((Get-Date) -lt $lastRepair.AddMinutes($CooldownMinutes)) {
    Write-RepairLog "Repair skipped during cooldown: $($missingReachablePeers -join ', ')."
    return
}

Write-RepairLog "Restarting MWB for reachable missing peers: $($missingReachablePeers -join ', ')."
Restart-MouseWithoutBorders
(Get-Date).ToString("o") | Set-Content -LiteralPath $statePath -Encoding ascii
