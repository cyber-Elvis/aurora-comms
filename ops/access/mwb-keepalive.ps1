#Requires -Version 5.1
<#
  Ensure PowerToys Mouse Without Borders stays running. If it has died mid-session,
  relaunch it. Runs AS the logged-on user in their interactive session (so the
  relaunch lands on the desktop, not session 0). Invoked via run-mwb-keepalive.vbs
  (wscript, window style 0) so no console window ever flashes.

  PC1 already self-heals via the peer-watchdog (Aurora-Repair-MWB-Peers); this covers
  PC2 and PC3, which had no local restart for a mid-session MWB crash.
#>
$ErrorActionPreference = 'SilentlyContinue'
$pt     = Join-Path $env:ProgramFiles 'PowerToys\PowerToys.exe'
$mwb    = Join-Path $env:ProgramFiles 'PowerToys\PowerToys.MouseWithoutBorders.exe'
$logDir = Join-Path $env:ProgramData 'Aurora'
$log    = Join-Path $logDir 'mwb-keepalive.log'
New-Item -ItemType Directory -Force $logDir | Out-Null

# Healthy — nothing to do (and nothing logged, to avoid log churn).
if (Get-Process PowerToys.MouseWithoutBorders -ErrorAction SilentlyContinue) { return }

# MWB is down. Ensure the PowerToys runner first (0.100 won't always start the
# module itself), then launch MWB directly. Both run in this user's session.
if (-not (Get-Process PowerToys -ErrorAction SilentlyContinue)) { Start-Process $pt; Start-Sleep -Seconds 8 }
if (-not (Get-Process PowerToys.MouseWithoutBorders -ErrorAction SilentlyContinue)) { Start-Process $mwb }

Add-Content -LiteralPath $log -Value ("{0:yyyy-MM-dd HH:mm:ss} MWB was down -> relaunched" -f (Get-Date))
