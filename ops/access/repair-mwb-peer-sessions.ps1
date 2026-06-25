#Requires -Version 5.1
<#
  Conservative MWB liveness watchdog (PC1).

  Redesigned 2026-06-24 after the previous "hardened" version caused a kill loop
  (it killed MWB every 2 min on "peer reachable but not connected" — which fires
  mid-handshake — and its relaunch task returned 0xFFFFFFFF, so runner stayed at 0).

  This version is deliberately minimal and SAFE:
    - It NEVER kills a running MWB. Killing a live process was the whole problem.
    - It does NOT look at peer connection state at all. MWB manages its own
      reconnects; a peer being momentarily unconnected is normal, not a fault.
    - It acts ONLY when MWB is genuinely down (the runner is absent, OR the
      runner is up but the MouseWithoutBorders module is absent), and only after
      the unhealthy state has persisted for FailThreshold consecutive checks
      (so a manual restart or a brief blip never triggers a relaunch).
    - A cooldown prevents a failed relaunch from hammering.
    - Relaunch is START-only (Start-Process), never a kill:
        * runner absent      -> Start-Process PowerToys.exe (whole stack), then,
          if the module still doesn't come up, start the module exe directly.
        * runner up, module 0 -> Start-Process PowerToys.MouseWithoutBorders.exe
          (the documented PC3 quirk: the runner sometimes won't spawn the module).
      This task runs as the interactive user (principal = <user>, LogonType
      Interactive), so the process lands on the desktop. No service, no
      scheduled-task indirection, no elevation.

  Runs via the Aurora-Repair-MWB-Peers task (AtLogon + every few minutes),
  launched hidden through run-hidden.vbs.

  Tunables (safe defaults): with a ~2-3 min task cadence, FailThreshold=2 means
  PowerToys must be gone for ~4-6 minutes before a single relaunch is attempted.
#>
[CmdletBinding()]
param(
    [int]$FailThreshold   = 2,
    [int]$CooldownMinutes = 15
)

$ErrorActionPreference = "Stop"

$stateDirectory = Join-Path $env:LOCALAPPDATA "Aurora"
$lastRelaunchPath = Join-Path $stateDirectory "mwb-peer-repair.state"   # ISO time of last relaunch
$failCountPath    = Join-Path $stateDirectory "mwb-peer-repair.fails"   # consecutive "runner absent" count
$logPath          = Join-Path $stateDirectory "mwb-peer-repair.log"
$powerToysExe     = Join-Path $env:ProgramFiles "PowerToys\PowerToys.exe"
$mwbModuleExe     = Join-Path $env:ProgramFiles "PowerToys\PowerToys.MouseWithoutBorders.exe"

New-Item -ItemType Directory -Path $stateDirectory -Force | Out-Null

function Write-RepairLog {
    param([Parameter(Mandatory = $true)][string]$Message)
    Add-Content -LiteralPath $logPath -Value ("{0:yyyy-MM-dd HH:mm:ss} {1}" -f (Get-Date), $Message)
}

$runnerCount = @(Get-Process PowerToys -ErrorAction SilentlyContinue).Count
$moduleCount = @(Get-Process PowerToys.MouseWithoutBorders -ErrorAction SilentlyContinue).Count

# --- Healthy: both the runner AND the MWB module are present. ---
if ($runnerCount -ge 1 -and $moduleCount -ge 1) {
    Set-Content -LiteralPath $failCountPath -Value 0 -Encoding ascii
    return
}

# --- Unhealthy (runner gone, or runner up but module gone): count it. ---
$fails = 0
if (Test-Path -LiteralPath $failCountPath) {
    [void][int]::TryParse((Get-Content -LiteralPath $failCountPath -Raw), [ref]$fails)
}
$fails++
Set-Content -LiteralPath $failCountPath -Value $fails -Encoding ascii

$symptom = if ($runnerCount -lt 1) { "PowerToys runner absent" } else { "runner up but MWB module absent" }

if ($fails -lt $FailThreshold) {
    Write-RepairLog "$symptom ($fails/$FailThreshold consecutive) — waiting (likely a manual restart or transient)."
    return
}

# --- Cooldown: don't re-attempt a relaunch too soon. ---
$lastRelaunch = [datetime]::MinValue
if (Test-Path -LiteralPath $lastRelaunchPath) {
    [void][datetime]::TryParse((Get-Content -LiteralPath $lastRelaunchPath -Raw), [ref]$lastRelaunch)
}
if ((Get-Date) -lt $lastRelaunch.AddMinutes($CooldownMinutes)) {
    Write-RepairLog "$symptom ($fails consecutive) but within cooldown ($CooldownMinutes min) since last relaunch — not acting."
    return
}

# --- Recover (start only; never kill). ---
if ($runnerCount -lt 1) {
    if (-not (Test-Path -LiteralPath $powerToysExe)) {
        Write-RepairLog "ERROR: PowerToys.exe not found at '$powerToysExe' — cannot relaunch."
        return
    }
    Write-RepairLog "$symptom for $fails consecutive checks — relaunching '$powerToysExe'."
    Start-Process -FilePath $powerToysExe
    # PC3 quirk: the runner sometimes starts without spawning the MWB module.
    Start-Sleep -Seconds 8
    if (@(Get-Process PowerToys.MouseWithoutBorders -ErrorAction SilentlyContinue).Count -lt 1 -and (Test-Path -LiteralPath $mwbModuleExe)) {
        Write-RepairLog "MWB module did not come up with the runner — starting '$mwbModuleExe' directly."
        Start-Process -FilePath $mwbModuleExe
    }
}
else {
    # Runner is up but the module is missing and the runner hasn't respawned it.
    if (-not (Test-Path -LiteralPath $mwbModuleExe)) {
        Write-RepairLog "ERROR: MouseWithoutBorders.exe not found at '$mwbModuleExe' — cannot start module."
        return
    }
    Write-RepairLog "$symptom for $fails consecutive checks — starting '$mwbModuleExe' directly."
    Start-Process -FilePath $mwbModuleExe
}

(Get-Date).ToString("o") | Set-Content -LiteralPath $lastRelaunchPath -Encoding ascii
Set-Content -LiteralPath $failCountPath -Value 0 -Encoding ascii
