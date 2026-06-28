# Aurora MWB watchdog — keeps Mouse Without Borders paired in the 3-node mesh (PC1/PC2/PC3).
#
# THE FAILURE IT HEALS: a node's MWB periodically re-initialises — it generates a fresh random
# SecurityKey + machine ID and an empty MachinePool, dropping out of the mesh (observed on PC2
# 2026-06-26: key 98B7EA77 -> a fresh 16-char key, pool reduced to self only). This happens when
# MWB starts without a readable settings.json (launcher races / locked file / corruption).
#
# DESIGN: HEALTH-GATED self-heal, NOT a kill-loop (an earlier Aurora-Repair-MWB-Peers WAS a
# kill-loop and made things worse). Each cycle:
#   - healthy  = live SecurityKey hash == golden AND pool has all three nodes AND MWB is running
#                -> exit immediately, touch nothing.
#   - deviated = restore the golden settings.json, then restart MWB ONCE.
#   - MWB down but config OK = just relaunch MWB.
# A cooldown stamp prevents repeated restarts inside a short window. Relaunch goes through the
# interactive launch task so MWB comes up in the user's session, never as SYSTEM.
#
# Golden config lives at C:\ProgramData\Aurora\mwb-golden.json (per host: shared key 98B7EA77 +
# full pool + that host's Name2IP). Deployed every 5 min + at boot via Aurora-MWB-Watchdog.
$ErrorActionPreference = 'SilentlyContinue'
$golden = 'C:\ProgramData\Aurora\mwb-golden.json'
$log    = 'C:\ProgramData\Aurora\mwb-watchdog.log'
$stamp  = 'C:\ProgramData\Aurora\mwb-watchdog.last'
$cooldownMin = 10
function Log($m){ "$([DateTime]::Now.ToString('s'))  $m" | Add-Content -Path $log }
function KeyHead($path){ try{ $c=Get-Content $path -Raw | ConvertFrom-Json; $j=if($c.properties){$c.properties}else{$c}; $k=$j.SecurityKey.value; if($k){ [BitConverter]::ToString([Security.Cryptography.SHA256]::Create().ComputeHash([Text.Encoding]::UTF8.GetBytes($k))).Replace('-','').Substring(0,8) } else { '' } }catch{ '' } }
function PoolOf($path){ try{ $c=Get-Content $path -Raw | ConvertFrom-Json; $j=if($c.properties){$c.properties}else{$c}; [string]$j.MachinePool.value }catch{ '' } }

if(-not (Test-Path $golden)){ exit 0 }   # no baseline -> do nothing
$live = (Get-ChildItem 'C:\Users\*\AppData\Local\Microsoft\PowerToys\MouseWithoutBorders\settings.json' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
if(-not $live){ Log 'no live settings.json found'; exit 0 }

$gKey = KeyHead $golden
$lKey = KeyHead $live
$lPool = PoolOf $live
$poolOK = ($lPool -match 'forty3s-PC1') -and ($lPool -match 'forty3s-PC2') -and ($lPool -match 'forty3s-PC3')
$running = [bool](Get-Process -Name 'PowerToys.MouseWithoutBorders' -ErrorAction SilentlyContinue)
$configOK = ($lKey -eq $gKey) -and $poolOK

if($configOK -and $running){ exit 0 }   # fully healthy -> no-op, no disruption

# cooldown guard so we never thrash MWB
if((Test-Path $stamp) -and (((Get-Date) - (Get-Item $stamp).LastWriteTime).TotalMinutes -lt $cooldownMin)){
    Log "action needed (configOK=$configOK running=$running) but within ${cooldownMin}m cooldown; skip"; exit 0
}

if(-not $configOK){
    Log "MWB config DEVIATED (liveKey=$lKey goldenKey=$gKey poolOK=$poolOK) -> restore golden + restart"
    Copy-Item $live ("$live.reset-" + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.bak') -Force
    Copy-Item $golden $live -Force
    Get-Process -Name 'PowerToys.MouseWithoutBorders','PowerToys.MouseWithoutBordersHelper' -ErrorAction SilentlyContinue | Stop-Process -Force
    Start-Sleep -Seconds 2
} else {
    Log "MWB config OK but process DOWN -> relaunch"
}

if(Get-ScheduledTask -TaskName 'Aurora-Start-PowerToys-MWB-Interactive' -ErrorAction SilentlyContinue){ Start-ScheduledTask 'Aurora-Start-PowerToys-MWB-Interactive' }
elseif(Get-ScheduledTask -TaskName 'Aurora-Start-PowerToys-Interactive' -ErrorAction SilentlyContinue){ Start-ScheduledTask 'Aurora-Start-PowerToys-Interactive' }
[IO.File]::WriteAllText($stamp, (Get-Date).ToString('s'))
Log 'restore/relaunch done'
