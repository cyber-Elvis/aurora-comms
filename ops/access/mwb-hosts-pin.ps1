#Requires -Version 5.1
<#
.SYNOPSIS
  Health-aware MWB peer pinner with Wi-Fi-primary / Tailscale-fallback.

  For each peer it decides the live path and pins the short-name accordingly:
    - Wi-Fi healthy  -> pin short-name to the native Wi-Fi IP (fast; survives MWB's
                        per-desktop-switch reconnect).
    - Wi-Fi down/unreachable -> pin short-name to the Tailscale IP so MWB falls back
                        (works over relay; laggier, but beats a dead peer).
  The managed Tailscale short-name alias is always stripped (the .ts.net FQDN is kept
  for SSH/management) so MWB resolves the peer to exactly the IP we chose -- MWB does
  not fail over between two IPs on its own and picks unpredictably when both resolve.

  On a path CHANGE it bounces MWB (into the interactive session) so MWB re-resolves
  onto the new path. Rewriting hosts alone does not move MWB; a bounce is required.
  Steady-state runs make no change and do not bounce.

  Designed to run as a SYSTEM scheduled task (needs admin to write hosts; uses a
  one-shot Interactive task to relaunch MWB in the logged-on user's session).
.NOTES
  "Wi-Fi healthy" = the route to the peer's Wi-Fi IP egresses our 192.168.18.x
  interface (rules out the Ethernet/ICS hairpin) AND the peer answers on TCP 15101.
#>
[CmdletBinding()]
param(
    [array]$Peers = @(),
    [switch]$Quiet
)

$ErrorActionPreference = "Stop"
$hostsFile = Join-Path $env:windir "System32\drivers\etc\hosts"
$marker    = "# Aurora MWB pin"
$stateDir  = Join-Path $env:ProgramData "Aurora"
$statePath = Join-Path $stateDir "mwb-pin-state.txt"
$mwbExe    = Join-Path $env:ProgramFiles "PowerToys\PowerToys.MouseWithoutBorders.exe"
New-Item -ItemType Directory -Force $stateDir | Out-Null

# Auto-config by machine. MWB mesh: PC1<->PC2 wired (not managed here; always native).
# PC1<->PC3 and PC3<->PC1/PC2 ride Wi-Fi with Tailscale fallback.
if ($Peers.Count -eq 0) {
    switch ($env:COMPUTERNAME.ToUpper()) {
        "FORTY3S-PC1" {
            $Peers = @(@{ Name = "forty3s-pc3"; WifiIP = "192.168.18.29"; TailscaleIP = "100.110.254.10" })
        }
        "FORTY3S-PC3" {
            $Peers = @(
                @{ Name = "forty3s-pc1"; WifiIP = "192.168.18.20"; TailscaleIP = "100.88.225.123" },
                @{ Name = "forty3s-pc2"; WifiIP = "192.168.18.18"; TailscaleIP = "100.109.74.61" }
            )
        }
        default { if (-not $Quiet) { Write-Host "No auto-config for $($env:COMPUTERNAME); nothing to do." }; return }
    }
}

function Test-WifiHealthy {
    param([string]$WifiIP)
    $src = Find-NetRoute -RemoteIPAddress $WifiIP -ErrorAction SilentlyContinue |
        Where-Object { $_.IPAddress -like '192.168.18.*' } | Select-Object -First 1
    if (-not $src) { return $false }   # hairpinned via Ethernet/ICS, or Wi-Fi down
    $c = [Net.Sockets.TcpClient]::new()
    try { $t = $c.ConnectAsync($WifiIP, 15101); return ($t.Wait(1500) -and $c.Connected) }
    catch { return $false } finally { $c.Dispose() }
}

# 1) Decide desired IP per peer.
$desired = @{}
foreach ($p in $Peers) {
    $desired[$p.Name] = if (Test-WifiHealthy $p.WifiIP) { $p.WifiIP } else { $p.TailscaleIP }
}
$names = @($Peers | ForEach-Object { $_.Name })

# 2) Rebuild hosts: drop our prior pins, strip managed short-name aliases (keep FQDN),
#    re-add the chosen pins on top.
$lines = @(Get-Content -LiteralPath $hostsFile)
$kept = foreach ($ln in $lines) {
    if ($ln -match 'Aurora MWB|MWB direct Wi-Fi') { continue }   # drop any prior pin style
    $out = $ln
    if ($out -match 'tail[0-9a-f]+\.ts\.net') {
        foreach ($n in $names) { $out = $out -replace ('\s+' + [regex]::Escape($n) + '(?=\s|$)'), '' }
    }
    $out
}
$pinLines = foreach ($p in $Peers) {
    "{0} {1} {2}   {3}" -f $desired[$p.Name], $p.Name.ToUpper(), $p.Name.ToLower(), $marker
}
$desiredText = ((@($pinLines) + @($kept)) -join "`r`n") + "`r`n"

$current = if (Test-Path $hostsFile) { [IO.File]::ReadAllText($hostsFile) } else { "" }
if ($current -ne $desiredText) {
    [IO.File]::WriteAllText($hostsFile, $desiredText, (New-Object Text.UTF8Encoding($false)))
    & ipconfig /flushdns | Out-Null
}

# 3) Detect path transitions vs saved state.
$prev = @{}
if (Test-Path $statePath) {
    foreach ($l in (Get-Content $statePath)) { $kv = $l -split '=', 2; if ($kv.Count -eq 2) { $prev[$kv[0]] = $kv[1] } }
}
$changed = $false
foreach ($n in $names) { if ($prev[$n] -ne $desired[$n]) { $changed = $true } }
($names | ForEach-Object { "$_=$($desired[$_])" }) | Set-Content $statePath -Encoding ascii

# 4) On a real change (not first run) bounce MWB into the interactive session so it re-resolves.
$firstRun = ($prev.Count -eq 0)
if ($changed -and -not $firstRun) {
    $user = (Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue).UserName
    if ($user) {
        Get-Process PowerToys.MouseWithoutBorders, PowerToys.MouseWithoutBordersHelper -ErrorAction SilentlyContinue | Stop-Process -Force
        try {
            $prin = New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Limited
            $act  = New-ScheduledTaskAction -Execute $mwbExe
            Register-ScheduledTask -TaskName "Aurora-MWB-Bounce" -Action $act -Principal $prin -Force | Out-Null
            Start-ScheduledTask -TaskName "Aurora-MWB-Bounce"
            Start-Sleep 6
            Unregister-ScheduledTask -TaskName "Aurora-MWB-Bounce" -Confirm:$false
        } catch {}
    }
}

if (-not $Quiet) {
    foreach ($p in $Peers) {
        $mode = if ($desired[$p.Name] -eq $p.WifiIP) { "Wi-Fi" } else { "Tailscale FALLBACK" }
        Write-Host ("  {0} -> {1}  [{2}]" -f $p.Name, $desired[$p.Name], $mode)
    }
    if ($changed -and -not $firstRun) { Write-Host "  path changed -> bounced MWB" }
    elseif ($firstRun) { Write-Host "  (first run; state recorded, no bounce)" }
    else { Write-Host "  no change" }
}
