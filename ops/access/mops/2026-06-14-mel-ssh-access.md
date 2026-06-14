# MOP: MEL-P and MEL-PE1 SSH Access

Date: 2026-06-14 to 2026-06-15

Status: completed for the MEL pair.

Scope:
- `MEL-P-CISCO-IOL-RT01`
- `MEL-PE1-CISCO-IOL-RT01`
- GNS3 management segment via GNS3 VM TAP `tap-aurora-mgmt`

Operator rule:
- Elvis drives router console commands.
- Codex may verify GNS3 API state and SSH reachability.
- Codex does not send router console input unless explicitly permitted.

## Final Topology

GNS3 project: `ops-lab`

Management plumbing:
- `MGMT-CLOUD-TAP` exposes only GNS3 VM TAP `tap-aurora-mgmt` (`10.255.191.1/24`).
- `MGMT-SW01` is the internal management switch on compute `vm`.
- `MEL-P e0/1` connects to `MGMT-SW01 e1`.
- `MEL-PE1 e0/1` connects to `MGMT-SW01 e2`.
- `MGMT-CLOUD-TAP` connects to `MGMT-SW01 e3`.

Management IP plan:
- `mel-p1`: `10.255.191.11/24`
- `mel-pe1`: `10.255.191.12/24`
- SSH jump host: `gns3@100.118.0.46`

## GNS3 VM TAP Service

Run on the GNS3 VM if the TAP must be recreated:

```bash
sudo tee /etc/systemd/system/aurora-mgmt-tap.service >/dev/null <<'EOF'
[Unit]
Description=Aurora GNS3 management TAP
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/bash -lc 'ip link show tap-aurora-mgmt >/dev/null 2>&1 || ip tuntap add dev tap-aurora-mgmt mode tap user gns3; ip addr replace 10.255.191.1/24 dev tap-aurora-mgmt; ip link set tap-aurora-mgmt up'
ExecStop=/bin/bash -lc 'ip link set tap-aurora-mgmt down || true; ip tuntap del dev tap-aurora-mgmt mode tap || true'

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now aurora-mgmt-tap.service
ip -br addr show tap-aurora-mgmt
```

Expected:

```text
tap-aurora-mgmt UNKNOWN 10.255.191.1/24 ...
```

`UNKNOWN` is normal for a TAP device.

## Key Material

Local per-agent keys were generated on PC1:

```powershell
.\ops\access\new-agent-key.ps1 -Agent codex -Zone local
.\ops\access\new-agent-key.ps1 -Agent claude -Zone local
```

Private keys:
- `%USERPROFILE%\.ssh\aurora-codex-local-ed25519`
- `%USERPROFILE%\.ssh\aurora-claude-local-ed25519`

Private keys stay on PC1 or another approved operator host. They are not copied to routers, GNS3 projects, cloud hosts, or git.

Public key bodies were inserted into:
- `ops/access/node-snippets/mel-p1-ios-ssh-access.txt`
- `ops/access/node-snippets/mel-pe1-ios-ssh-access.txt`

## Device Configuration

The authoritative paste blocks are:

```text
ops/access/node-snippets/mel-p1-ios-ssh-access.txt
ops/access/node-snippets/mel-pe1-ios-ssh-access.txt
```

Before pasting, Elvis replaces only:

```text
<YOU_SET_ADMIN_SECRET_ON_BOX>
<YOU_SET_ENABLE_SECRET_ON_BOX>
```

Final IOS syntax note:

```ios
ip domain name lab.aurora
```

Use the spaced IOS form above, not the hyphenated variant.

## Validation

From the GNS3 VM, both management IPs must answer:

```bash
ping -c 2 10.255.191.11
ping -c 2 10.255.191.12
nc -vz -w 3 10.255.191.11 22
nc -vz -w 3 10.255.191.12 22
```

From PC1:

```powershell
.\ops\access\aurora-ssh.ps1 mel-p1  -UseCodex  -IdentityFile $HOME\.ssh\aurora-codex-local-ed25519
.\ops\access\aurora-ssh.ps1 mel-pe1 -UseCodex  -IdentityFile $HOME\.ssh\aurora-codex-local-ed25519
.\ops\access\aurora-ssh.ps1 mel-p1  -UseClaude -IdentityFile $HOME\.ssh\aurora-claude-local-ed25519
.\ops\access\aurora-ssh.ps1 mel-pe1 -UseClaude -IdentityFile $HOME\.ssh\aurora-claude-local-ed25519
```

Observed result:

```text
aurora-codex  -> 10.255.191.11 -> hostname MEL-P-CISCO-IOL-RT01
aurora-codex  -> 10.255.191.12 -> hostname MEL-PE1-CISCO-IOL-RT01
aurora-claude -> 10.255.191.11 -> hostname MEL-P-CISCO-IOL-RT01
aurora-claude -> 10.255.191.12 -> hostname MEL-PE1-CISCO-IOL-RT01
```

## Troubleshooting Notes

### GNS3 VM Tailscale Offline

Symptom:
- `ssh gns3@100.118.0.46` fails.
- GNS3 VM has no internet/default route.

Fix used:

```bash
sudo ip link set eth1 down
sudo ip addr flush dev eth1
sudo ip link set eth1 up
```

The VM then restored its DHCP default route:

```text
default via 192.168.191.2 dev eth1
```

Restart Tailscale:

```bash
sudo systemctl restart tailscaled
tailscale netcheck
tailscale ping --timeout=5s 100.88.225.123
```

### Stale SSH Host Keys

During router key regeneration or duplicate-IP correction, `aurora_known_hosts` can hold stale router keys.

Remove only the affected node:

```powershell
ssh-keygen.exe -R 10.255.191.11 -f $HOME\.ssh\aurora_known_hosts
ssh-keygen.exe -R 10.255.191.12 -f $HOME\.ssh\aurora_known_hosts
```

Then verify the target hostname over SSH before continuing.

### Duplicate IP

Symptom on PE1:

```text
%IP-4-DUPADDR: Duplicate address 10.255.191.12 on Ethernet0/1
```

Cause:
- MEL-P likely had the PE1 management IP during config churn.

Fix on MEL-P:

```ios
conf t
interface Ethernet0/1
 no ip address
 ip address 10.255.191.11 255.255.255.0
 no shutdown
end
clear arp-cache
write memory
```

## Rollback

On each router:

```ios
conf t
no username aurora-codex
no username aurora-claude
line vty 0 4
 no access-class MGMT-SOURCES in
exit
no ip access-list standard MGMT-SOURCES
interface Ethernet0/1
 shutdown
 no ip address
end
write memory
```
