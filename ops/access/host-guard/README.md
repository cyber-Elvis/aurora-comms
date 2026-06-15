# Aurora host guard

This directory contains the local host-containment guard for the GNS3 VM
management demarcation.

Current live local path:

```text
lab node e0/1 -> MGMT-SW01 -> tap-aurora-mgmt 10.255.191.1/24 -> GNS3 VM -> host networks
```

ADR-004 requires lab nodes to be unable to initiate SSH/RDP/SMB/WinRM or host
admin sessions to PC1/PC2. The only local lab-node-to-host exception is
RPKI-RTR to PC1 `192.168.200.1:3323`.

## Apply on the GNS3 VM

Copy `gns3-vm-host-guard.sh` to the GNS3 VM, review the variables, then run:

```bash
sudo sh ./gns3-vm-host-guard.sh apply
sudo sh ./gns3-vm-host-guard.sh status
```

The default protected TCP ports are:

```text
22,135,139,445,2222,3080,3389,5985,5986,8000,8443,9090,10000
```

Override variables only when the lab addressing changes:

```bash
sudo LAB_IF=tap-aurora-mgmt \
  PC1_IP=192.168.200.1 \
  PC2_IP=192.168.200.2 \
  RPKI_RTR_PORT=3323 \
  sh ./gns3-vm-host-guard.sh apply
```

Rollback:

```bash
sudo sh ./gns3-vm-host-guard.sh remove
```

## Local proof matrix

Run from a lab node after applying the guard. For IOS/IOL, use the console or
an SSH session and escape from any successful telnet attempt with
`Ctrl+Shift+6`, then `x`.

```ios
terminal length 0
telnet 192.168.200.1 22
telnet 192.168.200.1 135
telnet 192.168.200.1 139
telnet 192.168.200.1 445
telnet 192.168.200.1 3389
telnet 192.168.200.1 5985
telnet 192.168.200.1 5986
telnet 192.168.200.2 22
telnet 192.168.200.2 2222
telnet 192.168.200.2 3080
telnet 192.168.200.2 445
telnet 192.168.200.2 3389
telnet 192.168.200.2 5985
telnet 192.168.200.2 5986
telnet 192.168.200.1 3323
```

Pass criteria:

- Protected host-admin ports refuse, reset, or time out from the lab node.
- `192.168.200.1:3323` opens when the PC1 RPKI-RTR service is running.
- The guard counters increase for denied protected ports.
- Kernel logs contain `AURORA_HOST_GUARD denied` for denied attempts.

Check counters and logs on the GNS3 VM:

```bash
sudo sh ./gns3-vm-host-guard.sh status
sudo journalctl -k -g AURORA_HOST_GUARD --since -15min
```

## Live observation on 2026-06-15

Read-only checks from Codex confirmed:

- `mel-p1` accepted `aurora-codex` SSH through `gns3@100.118.0.46` and returned
  `show clock`.
- The GNS3 VM has `tap-aurora-mgmt` at `10.255.191.1/24`.
- From the GNS3 VM, `10.255.191.11:22` and `10.255.191.12:22` were reachable.
- Before the guard was applied, `net.ipv4.ip_forward = 1` and the GNS3 VM
  `FORWARD` policy was `ACCEPT`, with Tailscale/Docker/libvirt chains but no
  Aurora host-containment chain.
- The guard was then applied successfully to `FORWARD` for `tap-aurora-mgmt`,
  with an explicit accept for `192.168.200.1:3323` and log/reject rules for
  protected PC1/PC2 ports.

The local containment proof is not complete until the lab-node proof matrix
above is captured and the guard counters/logs show the denied attempts.
