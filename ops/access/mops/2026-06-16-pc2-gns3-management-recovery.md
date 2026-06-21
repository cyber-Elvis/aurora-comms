# MOP: PC2 and GNS3 VM management recovery

Date: 2026-06-16

## Trigger

After restarting the Dell PC2 / GNS3 VM stack, PC1 and Termius could no longer
reach the management plane:

- PC2 Tailscale `100.109.74.61`: ping succeeds, TCP 22/5985 closed.
- GNS3 VM Tailscale `100.118.0.46`: ping succeeds, TCP 22/3080 closed.
- Tailscale SSH probe timed out.

Later testing showed the initial PC1 TCP probes were affected by the Codex
sandbox outbound firewall rule `codex_sandbox_offline_block_outbound`. Use an
elevated / unsandboxed PowerShell when validating host reachability from PC1.

## Live observations from PC1

- PC1 host: `forty3s-PC1`.
- Dell/PC2 Tailscale: `100.109.74.61`, online via DERP Sydney.
- GNS3 VM Tailscale: `100.118.0.46`, online direct via `192.168.137.1`.
- `192.168.137.1` reverse-resolves to `forty3s-PC2.mshome.net`.
- PC1 currently receives `192.168.137.235/24` on the local Ethernet link.

This means the Dell is currently the local `192.168.137.1` gateway from PC1's
perspective. Treat older `.137.1/.137.2` host notes as stale until reconfirmed
on the physical Dell.

## Recovery on Dell PC2

Run from an elevated PowerShell session on the Dell. If the repo has been
cloned or synced onto PC2, run:

```powershell
Set-Location D:\CyberLab\Repos\aurora-comms
.\ops\access\pc2-enable-remote-management.ps1 -EnableWinRM
```

If the repo is only on PC1, either copy
`ops\access\pc2-enable-remote-management.ps1` to PC2 and run it locally as
Administrator, or paste this permanent enforcement block into an elevated PC2
PowerShell session:

```powershell
$AllowedRemoteAddress = @(
    "100.88.225.123",
    "192.168.137.235",
    "100.64.0.0/10",
    "192.168.137.0/24"
)

Set-NetFirewallProfile `
    -Profile Domain,Private,Public `
    -Enabled True `
    -DefaultInboundAction Block `
    -AllowInboundRules True `
    -AllowLocalFirewallRules True

$sshd = Get-Service -Name sshd -ErrorAction SilentlyContinue
if (-not $sshd) {
    Add-WindowsCapability -Online -Name "OpenSSH.Server~~~~0.0.1.0"
}

Set-Service -Name sshd -StartupType Automatic
Start-Service -Name sshd

Enable-PSRemoting -Force -SkipNetworkProfileCheck
Set-Service -Name WinRM -StartupType Automatic
Start-Service -Name WinRM

function Set-AuroraInboundRule {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$DisplayName,
        [Parameter(Mandatory = $true)][int]$Port
    )

    Get-NetFirewallRule -Name $Name -ErrorAction SilentlyContinue |
        Remove-NetFirewallRule

    New-NetFirewallRule `
        -Name $Name `
        -DisplayName $DisplayName `
        -Enabled True `
        -Direction Inbound `
        -Action Allow `
        -Profile Any `
        -Protocol TCP `
        -LocalPort $Port `
        -RemoteAddress $AllowedRemoteAddress | Out-Null
}

Set-AuroraInboundRule `
    -Name "Aurora-OpenSSH-Inbound" `
    -DisplayName "Aurora OpenSSH inbound from Tailscale and lab link" `
    -Port 22

Set-AuroraInboundRule `
    -Name "Aurora-WinRM-HTTP-Inbound" `
    -DisplayName "Aurora WinRM HTTP inbound from Tailscale and lab link" `
    -Port 5985

$managedRules = @()
$managedRules += Get-NetFirewallRule -Name "Aurora-OpenSSH-Inbound","Aurora-WinRM-HTTP-Inbound" -ErrorAction SilentlyContinue
$managedRules += Get-NetFirewallRule -DisplayGroup "OpenSSH Server" -ErrorAction SilentlyContinue
$managedRules += Get-NetFirewallRule -Name "OpenSSH-Server-In-TCP" -ErrorAction SilentlyContinue
$managedRules += Get-NetFirewallRule -DisplayName "OpenSSH SSH Server*" -ErrorAction SilentlyContinue
$managedRules += Get-NetFirewallRule -DisplayGroup "Windows Remote Management" -ErrorAction SilentlyContinue
$managedRules += Get-NetFirewallRule -Name "WINRM-HTTP-In-TCP*" -ErrorAction SilentlyContinue

$managedRules |
    Where-Object { $_ -and $_.Direction -eq "Inbound" } |
    Sort-Object -Property Name -Unique |
    ForEach-Object {
        Set-NetFirewallRule -Name $_.Name -Enabled True -Action Allow -Profile Any
        Get-NetFirewallAddressFilter -AssociatedNetFirewallRule $_ |
            Set-NetFirewallAddressFilter -RemoteAddress $AllowedRemoteAddress
    }

Get-NetFirewallProfile |
    Select-Object Name, Enabled, DefaultInboundAction, AllowInboundRules, AllowLocalFirewallRules |
    Format-Table -AutoSize

Get-NetFirewallRule -Name "Aurora-OpenSSH-Inbound","Aurora-WinRM-HTTP-Inbound" |
    Format-Table Name, Enabled, Direction, Action, Profile -AutoSize

Get-NetFirewallAddressFilter -AssociatedNetFirewallRule (
    Get-NetFirewallRule -Name "Aurora-OpenSSH-Inbound","Aurora-WinRM-HTTP-Inbound"
) | Format-Table RemoteAddress -AutoSize
```

Expected result:

- `sshd` is running and automatic.
- WinRM is running and automatic if `-EnableWinRM` is used.
- Windows Firewall remains enabled with default inbound blocked, and
  `AllowInboundRules` / `AllowLocalFirewallRules` set to `True` so explicit
  Aurora allow rules are honored.
- Windows Firewall permits TCP 22 and TCP 5985 only from Tailscale
  `100.64.0.0/10`, PC1 Tailscale `100.88.225.123`, the local lab link
  `192.168.137.0/24`, and PC1's current local address `192.168.137.235`.
  Do not leave `RemoteAddress Any` on PC2 SSH or WinRM rules.

Verify from PC1:

```powershell
Test-NetConnection 100.109.74.61 -Port 22
Test-NetConnection 192.168.137.1 -Port 22
Test-NetConnection 100.109.74.61 -Port 5985
```

## Recovery on the GNS3 VM

Run from the GNS3 VM console:

```bash
sudo sh /path/to/gns3-vm-recover-management.sh
```

If the repo is mounted on the VM, use:

```bash
sudo sh /mnt/d/CyberLab/Repos/aurora-comms/ops/access/gns3-vm-recover-management.sh
```

Expected result:

- `ssh` or `sshd` is running if installed.
- `gns3server` is running if installed.
- `aurora-mgmt-tap.service` is enabled and active.
- `tap-aurora-mgmt` has `10.255.191.1/24`.

Verify from PC1:

```powershell
Test-NetConnection 100.118.0.46 -Port 22
Test-NetConnection 100.118.0.46 -Port 80
curl.exe http://100.118.0.46/v2/version
```

On the current GNS3 VM build, the API/web listener is port `80`, not `3080`.
`/v2/version` returned GNS3 `2.2.59` during recovery.

Verify from the GNS3 VM:

```bash
ip -br addr show tap-aurora-mgmt
ping -c 2 10.255.191.15
nc -vz -w 3 10.255.191.15 22
```

## Termius routing model

Termius should use the GNS3 VM as the jump host for router management:

```text
Jump host: gns3@100.118.0.46
Target:    10.255.191.x
```

Do not target IOS/IOL nodes directly from the Dell Windows host unless the node
ACLs have been intentionally changed. Region A VTY ACLs are designed to permit
the GNS3 management TAP source `10.255.191.1`.

## Verification: 2026-06-17

PC2 ran `pc2-enable-remote-management.ps1 -EnableWinRM` successfully.

Permanent PC2 state:

- `sshd` running, startup `Automatic`.
- `WinRM` running, startup `Automatic`.
- Domain, Private, and Public firewall profiles enabled with default inbound
  `Block`.
- `AllowInboundRules` and `AllowLocalFirewallRules` both `True`.
- `Aurora-OpenSSH-Inbound` allows TCP 22 only from
  `100.64.0.0/10`, `192.168.137.0/24`, `100.88.225.123`, and
  `192.168.137.235`.
- `Aurora-WinRM-HTTP-Inbound` allows TCP 5985 only from the same source list.

Unsandboxed PC1 verification passed:

```powershell
Test-NetConnection 100.109.74.61 -Port 22      # True
Test-NetConnection 192.168.137.1 -Port 22      # True
Test-NetConnection 100.109.74.61 -Port 5985    # True
Test-WSMan 100.109.74.61                       # Responds
```
