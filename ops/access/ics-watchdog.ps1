# Aurora ICS watchdog — keeps PC2's Internet Connection Sharing alive: the wired
# 192.168.137.1 gateway that is PC1's *backup* internet path (PC1's Wi-Fi-failover watchdog
# fails over to this Ethernet/ICS path) and also the address the GNS3 controller binds to.
#
# HEALTH-GATED: re-applies ICS ONLY when the private 192.168.137.1 has dropped. When ICS is
# healthy it exits immediately, so it never needlessly resets the link or NAT. Mirrors the
# proven HNetCfg re-apply from repair-pc2-internet-sharing.ps1, MINUS the PowerToys/MWB restart
# (MWB rides Wi-Fi/Tailscale, not this wired link — resetting it must not touch MWB).
#
# Runs every ~5 min + at boot as SYSTEM via the Aurora-ICS-Watchdog scheduled task. The
# original Aurora-Repair-Internet-Sharing task was BOOT-ONLY, so a mid-session ICS drop never
# self-healed (2026-06-26 incident) — this closes that gap.
$ErrorActionPreference = 'SilentlyContinue'
$pub = 'Wi-Fi'; $priv = 'Ethernet'; $scope = '192.168.137.1'
$log = 'C:\ProgramData\Aurora\ics-watchdog.log'
function Log($m){ "$([DateTime]::Now.ToString('s'))  $m" | Add-Content -Path $log }

# healthy = private adapter already owns the ICS gateway IP -> nothing to do
if (Get-NetIPAddress -InterfaceAlias $priv -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object { $_.IPAddress -eq $scope }) { exit 0 }

# need both adapters Up (public = an internet source to share, private = the wired link)
if ((Get-NetAdapter -Name $pub -ErrorAction SilentlyContinue).Status -ne 'Up' -or
    (Get-NetAdapter -Name $priv -ErrorAction SilentlyContinue).Status -ne 'Up') {
    Log "skip: $pub or $priv not Up"; exit 0
}

Log "ICS DOWN (.137.1 missing on $priv) -> re-applying sharing"
try {
    Set-Service SharedAccess -StartupType Automatic
    function GetConn($mgr, $alias){ foreach ($c in $mgr.EnumEveryConnection()) { if ($mgr.NetConnectionProps($c).Name -eq $alias) { return $c } }; throw "conn not found: $alias" }
    $m = New-Object -ComObject HNetCfg.HNetShare
    $pc = $m.INetSharingConfigurationForINetConnection((GetConn $m $pub))
    $vc = $m.INetSharingConfigurationForINetConnection((GetConn $m $priv))
    if ($pc.SharingEnabled) { $pc.DisableSharing() }
    if ($vc.SharingEnabled) { $vc.DisableSharing() }
    Restart-Service SharedAccess -Force; Start-Sleep -Seconds 2
    $m = New-Object -ComObject HNetCfg.HNetShare
    $pc = $m.INetSharingConfigurationForINetConnection((GetConn $m $pub))
    $vc = $m.INetSharingConfigurationForINetConnection((GetConn $m $priv))
    $pc.EnableSharing(0); Start-Sleep -Seconds 2; $vc.EnableSharing(1)   # 0=public/upstream, 1=private/wired
    Start-Sleep -Seconds 3
    $ok = Get-NetIPAddress -InterfaceAlias $priv -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object { $_.IPAddress -eq $scope }
    Log ("re-apply " + $(if ($ok) { 'OK (.137.1 restored)' } else { 'FAILED (.137.1 still missing)' }))
} catch {
    Log "re-apply error: $($_.Exception.Message)"
}
