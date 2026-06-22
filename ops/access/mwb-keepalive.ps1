#Requires -Version 5.1
<#
  SYSTEM-aware Mouse Without Borders keep-alive.

  "Healthy" = at least one PowerToys.MouseWithoutBorders.exe owned by NT AUTHORITY\SYSTEM
  (the secure-desktop injector spawned by the elevated runner when UseService=true +
  run_elevated=true). If MWB is missing OR only a USER-owned instance is running, MWB is
  DEGRADED: the cursor still moves to the target but clicks/keystrokes don't land (they
  can't reach the locked/secure desktop). This script detects BOTH "down" and "degraded"
  and rebuilds the elevated stack.

  MUST run via the Aurora-MWB-KeepAlive task at RunLevel = Highest as the console user
  (Interactive) — elevation is required both to read SYSTEM process owners and to restart
  the elevated runner so it respawns the SYSTEM injectors. Launched via
  run-mwb-keepalive.vbs (wscript, hidden) so no console flashes.
#>
$ErrorActionPreference = 'SilentlyContinue'
$pt     = Join-Path $env:ProgramFiles 'PowerToys\PowerToys.exe'
$logDir = Join-Path $env:ProgramData 'Aurora'
$log    = Join-Path $logDir 'mwb-keepalive.log'
New-Item -ItemType Directory -Force $logDir | Out-Null

# Is a SYSTEM-owned MWB injector running?
$procs = Get-CimInstance Win32_Process -Filter "Name='PowerToys.MouseWithoutBorders.exe'" -ErrorAction SilentlyContinue
$systemUp = $false
foreach ($p in $procs) {
  $o = Invoke-CimMethod -InputObject $p -MethodName GetOwner -ErrorAction SilentlyContinue
  if ($o -and $o.User -eq 'SYSTEM') { $systemUp = $true; break }
}
if ($systemUp) { return }   # healthy — nothing to do (no log churn)

# Down or degraded -> rebuild the elevated stack. Stop any runner/instances so the fresh
# (elevated, because this task is RunLevel Highest) runner owns MWB and spawns the SYSTEM
# injectors. Never launch PowerToys.MouseWithoutBorders.exe directly — that comes back
# user-only and can't drive a locked screen.
$reason = if ($procs) { 'MWB present but not SYSTEM-owned (degraded)' } else { 'MWB not running' }
Get-Process PowerToys -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 2
Start-Process $pt

Add-Content -LiteralPath $log -Value ("{0:yyyy-MM-dd HH:mm:ss} {1} -> restarted elevated runner" -f (Get-Date), $reason)
