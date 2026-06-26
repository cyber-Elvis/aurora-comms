#Requires -Version 5.1
<#
  Tailscale data-plane watchdog for PC3.

  Detects "half-up": service running, peers visible in tailscale status,
  but actual TCP to peers via their Tailscale IP fails (data plane dead
  after sleep/endpoint flip). Fix: Restart-Service Tailscale -Force.

  Run as SYSTEM scheduled task (Aurora-Tailscale-Health) every 3 minutes.
#>
[CmdletBinding()]
param(
    [array]$TestPeers = @(
        @{ Name = "PC1"; TailscaleIP = "100.88.225.123"; TestPort = 22 }
    ),
    [int]$ConnectTimeoutMs = 3000,
    [int]$CooldownMinutes = 10
)

$ErrorActionPreference = "Stop"
$stateDir = Join-Path $env:ProgramData "Aurora"
$logPath = Join-Path $stateDir "tailscale-repair.log"
$statePath = Join-Path $stateDir "tailscale-repair.state"
New-Item -ItemType Directory -Force $stateDir | Out-Null

# Per-machine peer selection. The scheduled-task action invokes this script with a
# bare -File (no args), so the peer this host watches is supplied out-of-band via a
# sidecar config written by Install-TailscaleWatchdog.ps1. An explicit -TestPeers
# argument always wins; otherwise load the config if present.
$peersConfig = Join-Path $stateDir "tailscale-peers.json"
if (-not $PSBoundParameters.ContainsKey('TestPeers') -and (Test-Path $peersConfig)) {
    $TestPeers = @(Get-Content -Raw -LiteralPath $peersConfig | ConvertFrom-Json | ForEach-Object {
        @{ Name = $_.Name; TailscaleIP = $_.TailscaleIP; TestPort = [int]$_.TestPort }
    })
}

function Write-TsLog {
    param([string]$Message)
    Add-Content -LiteralPath $logPath -Value ("{0:yyyy-MM-dd HH:mm:ss} {1}" -f (Get-Date), $Message)
}

function Test-TcpPort {
    param([string]$Address, [int]$Port)
    $c = [Net.Sockets.TcpClient]::new()
    try { $t = $c.ConnectAsync($Address, $Port); return ($t.Wait($ConnectTimeoutMs) -and $c.Connected) }
    catch { return $false }
    finally { $c.Dispose() }
}

$svc = Get-Service Tailscale -ErrorAction SilentlyContinue
if (-not $svc -or $svc.Status -ne 'Running') {
    Write-TsLog "Tailscale service not running; starting."
    Start-Service Tailscale -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 15
    $svc = Get-Service Tailscale -ErrorAction SilentlyContinue
    if (-not $svc -or $svc.Status -ne 'Running') {
        Write-TsLog "Tailscale failed to start."
        return
    }
}

$halfUp = $false
foreach ($tp in $TestPeers) {
    if (Test-TcpPort -Address $tp.TailscaleIP -Port $tp.TestPort) { continue }

    # TCP failed — could be peer offline (normal) or data plane dead (half-up).
    # Distinguish: if tailscale ping (disco/DERP) reaches the peer but TCP doesn't,
    # the data plane is broken.
    $pingOut = & tailscale.exe ping -c 1 --timeout 5s $tp.TailscaleIP 2>&1
    if ($pingOut -match 'pong from') {
        Write-TsLog "HALF-UP: $($tp.Name) ($($tp.TailscaleIP)) disco pong OK but TCP :$($tp.TestPort) dead"
        $halfUp = $true
    }
}

if (-not $halfUp) { return }

$lastRepair = [datetime]::MinValue
if (Test-Path $statePath) {
    [void][datetime]::TryParse((Get-Content -Raw $statePath), [ref]$lastRepair)
}
if ((Get-Date) -lt $lastRepair.AddMinutes($CooldownMinutes)) {
    Write-TsLog "Half-up detected but in cooldown ($CooldownMinutes min)."
    return
}

Write-TsLog "Restarting Tailscale to recover data plane."
Restart-Service Tailscale -Force
Start-Sleep -Seconds 15
(Get-Date).ToString("o") | Set-Content $statePath -Encoding ascii

$recovered = $true
foreach ($tp in $TestPeers) {
    if (-not (Test-TcpPort -Address $tp.TailscaleIP -Port $tp.TestPort)) {
        Write-TsLog "POST-RESTART: $($tp.Name) still unreachable on :$($tp.TestPort)"
        $recovered = $false
    }
}
if ($recovered) { Write-TsLog "Data plane recovered." }
