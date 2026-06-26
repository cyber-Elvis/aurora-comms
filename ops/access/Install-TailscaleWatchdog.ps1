#Requires -Version 5.1
<#
.SYNOPSIS
  Idempotent installer for the Tailscale data-plane watchdog.

.DESCRIPTION
  Deploys repair-tailscale-dataplane.ps1 to C:\ProgramData\Aurora\ and registers
  (or replaces) the SYSTEM scheduled task "Aurora-Tailscale-Health" that runs it
  at boot and every 3 minutes thereafter.

  Root cause this fixes: the task was once registered by hand without copying the
  script to its -File target, so every fire exited 0xFFFD0000 (powershell -File
  <missing>) without running. This installer keeps script + task in lockstep and
  is the repo-tracked source of truth for deployment.

  Per-machine peer selection: the task action invokes the script with a bare
  -File (matching the live task), so the peer this host watches is written to a
  sidecar config C:\ProgramData\Aurora\tailscale-peers.json that the script reads.
  PC1/PC2/PC3 each watch a different always-up peer; defaults are derived from the
  hostname and can be overridden with -TestPeers.

  Safe to re-run: Register-ScheduledTask -Force replaces any existing definition.

.EXAMPLE
  # On PC3 (auto-selects PC1 as the watched peer):
  .\Install-TailscaleWatchdog.ps1

.EXAMPLE
  # Explicit peer(s):
  .\Install-TailscaleWatchdog.ps1 -TestPeers @(
      @{ Name = 'PC1'; TailscaleIP = '100.88.225.123'; TestPort = 22 }
  )
#>
[CmdletBinding()]
param(
    # Peer(s) this host probes to detect a half-up data plane. If omitted, a
    # default is chosen from the hostname (see $defaultPeerMap below).
    [hashtable[]]$TestPeers,

    [string]$TaskName = 'Aurora-Tailscale-Health',

    # Source watchdog script; defaults to the copy beside this installer.
    [string]$SourceScript = (Join-Path $PSScriptRoot 'repair-tailscale-dataplane.ps1'),

    [string]$TargetDir = (Join-Path $env:ProgramData 'Aurora'),

    [int]$IntervalMinutes = 3
)

$ErrorActionPreference = 'Stop'

# --- 0. Sanity ------------------------------------------------------------------
if (-not (Test-Path -LiteralPath $SourceScript)) {
    throw "Source watchdog script not found: $SourceScript"
}
$id = [Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $id.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw "This installer must run elevated (it registers a SYSTEM task and writes to ProgramData)."
}

# --- 1. Resolve the peer this host watches --------------------------------------
# Each box watches a peer it expects to always be up; if its own data plane goes
# half-up, the probe fails and the watchdog restarts tailscaled.
$defaultPeerMap = @{
    'PC1' = @{ Name = 'PC2'; TailscaleIP = '100.92.62.38';   TestPort = 22 }
    'PC2' = @{ Name = 'PC1'; TailscaleIP = '100.88.225.123'; TestPort = 22 }
    'PC3' = @{ Name = 'PC1'; TailscaleIP = '100.88.225.123'; TestPort = 22 }
}
if (-not $TestPeers) {
    $hostKey = switch -Regex ($env:COMPUTERNAME) {
        'PC1' { 'PC1'; break }
        'PC2' { 'PC2'; break }
        'PC3' { 'PC3'; break }
        default { $null }
    }
    if (-not $hostKey) {
        throw "Could not infer a default peer for host '$($env:COMPUTERNAME)'. Pass -TestPeers explicitly."
    }
    $TestPeers = @($defaultPeerMap[$hostKey])
    Write-Host "Host '$($env:COMPUTERNAME)' -> watching $($TestPeers[0].Name) ($($TestPeers[0].TailscaleIP):$($TestPeers[0].TestPort))"
}

# --- 2. Deploy script + peer config (UTF-8) -------------------------------------
New-Item -ItemType Directory -Force -Path $TargetDir | Out-Null
$targetScript = Join-Path $TargetDir 'repair-tailscale-dataplane.ps1'
$peerConfig   = Join-Path $TargetDir 'tailscale-peers.json'

# Copy via read+write so we control the encoding (UTF-8, no BOM dependence).
$scriptBody = Get-Content -Raw -LiteralPath $SourceScript
[IO.File]::WriteAllText($targetScript, $scriptBody, [Text.UTF8Encoding]::new($false))
Write-Host "Deployed watchdog -> $targetScript"

$peerJson = $TestPeers | ForEach-Object {
    [pscustomobject]@{ Name = $_.Name; TailscaleIP = $_.TailscaleIP; TestPort = [int]$_.TestPort }
} | ConvertTo-Json -AsArray -Depth 4
[IO.File]::WriteAllText($peerConfig, $peerJson, [Text.UTF8Encoding]::new($false))
Write-Host "Wrote peer config -> $peerConfig"

# --- 3. Build the task definition (mirrors the live PC3 task) --------------------
$action = New-ScheduledTaskAction -Execute 'powershell.exe' `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$targetScript`""

$bootTrigger = New-ScheduledTaskTrigger -AtStartup
$repeatTrigger = New-ScheduledTaskTrigger -Once -At (Get-Date) `
    -RepetitionInterval (New-TimeSpan -Minutes $IntervalMinutes) `
    -RepetitionDuration (New-TimeSpan -Days 9999)

$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest

$settings = New-ScheduledTaskSettingsSet `
    -StartWhenAvailable `
    -MultipleInstances IgnoreNew `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 2)

$task = New-ScheduledTask -Action $action `
    -Trigger @($bootTrigger, $repeatTrigger) `
    -Principal $principal `
    -Settings $settings `
    -Description 'Aurora: restart tailscaled when the data plane is half-up (disco pong OK but TCP dead).'

# --- 4. Register / replace (idempotent) -----------------------------------------
Register-ScheduledTask -TaskName $TaskName -InputObject $task -Force | Out-Null
Write-Host "Registered scheduled task '$TaskName'."

# --- 5. Run once and assert success ---------------------------------------------
Start-ScheduledTask -TaskName $TaskName
$deadline = (Get-Date).AddSeconds(120)
do {
    Start-Sleep -Seconds 2
    $state = (Get-ScheduledTask -TaskName $TaskName).State
} while ($state -eq 'Running' -and (Get-Date) -lt $deadline)

$info = Get-ScheduledTaskInfo -TaskName $TaskName
if ($state -eq 'Running') {
    throw "Task '$TaskName' is still running after 120s; aborting verification."
}
if ($info.LastTaskResult -ne 0) {
    throw ("Task '{0}' ran but LastTaskResult = 0x{1:X8} ({1}). Expected 0. " -f $TaskName, $info.LastTaskResult) +
          "Check that the -File target exists ($targetScript) and review $TargetDir\tailscale-repair.log."
}
Write-Host ("OK: '{0}' LastTaskResult = 0 (LastRunTime {1})." -f $TaskName, $info.LastRunTime)
