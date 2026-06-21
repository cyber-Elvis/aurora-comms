# MOP: PC3 dedicated Termius operator terminal

Date: 2026-06-19

## Decision

Use `forty3s-PC3` as a dedicated human-operated Termius terminal.

PC3 is an operator endpoint only:

- It initiates management sessions.
- It does not route lab traffic.
- It does not advertise subnet routes or act as an exit node.
- It does not host `aurora-codex` or `aurora-claude` private keys.
- It does not require inbound SSH, WinRM, SMB, or RDP for normal lab work.

Current live Tailscale identity:

```text
Hostname:      forty3s-pc3
Tailscale IP: 100.110.254.10
State:         active
```

## Access architecture

```text
PC3 / Termius
  |
  | Tailscale + SSH public key
  |
  +-- PC2 GNS3 jump: gns3@100.118.0.46
  |     |
  |     +-- MEL-P1   10.255.191.11
  |     +-- MEL-PE1  10.255.191.12
  |     +-- GEL-PE1  10.255.191.15
  |     +-- ADL-PE1  10.255.191.17
  |
  +-- PC1 Linux jump: aurora-operator@100.116.32.29
        |
        +-- Region B / DevNet nodes
        +-- PC1-hosted lab containers and virtual routers
```

Do not use PC1 Windows or PC2 Windows as the normal router jump host. Keep the
Windows hosts protected management anchors and terminate device access on the
Linux jump hosts.

## Phase 1: harden PC3

Before importing credentials into Termius:

1. Enable BitLocker or device encryption.
2. Enable Windows Hello and a short automatic screen-lock timeout.
3. Keep Windows Defender Firewall and real-time protection enabled.
4. Use a non-administrator Windows account for daily Termius work.
5. Enable MFA on the Termius and Tailscale accounts.
6. Do not enable SSH server, WinRM, SMB sharing, or RDP on PC3 unless a separate
   documented use case requires it.

Termius stores hosts, keys, known hosts, and connection metadata in encrypted
vaults. Use a private vault for Aurora and do not share it.

## Phase 2: generate PC3-specific keys

Copy `setup-pc3-operator-terminal.ps1` to PC3 and run:

```powershell
.\setup-pc3-operator-terminal.ps1
```

The script prompts for passphrases and creates two separate keys outside git:

| Key | Installed on | Purpose |
| --- | --- | --- |
| `aurora-pc3-jump-ed25519` | GNS3 VM and PC1 Linux jump host | Authenticate PC3 to jump hosts |
| `aurora-pc3-node-admin-ed25519` | Lab-node `admin` accounts | Authenticate from Termius to routers/firewalls |

Do not copy PC1 automation private keys to PC3. PC3 gets its own revocable
personal operator keys.

## Phase 3: install public keys

Install only the public jump key on:

```text
gns3@100.118.0.46:/home/gns3/.ssh/authorized_keys
aurora-operator@100.116.32.29:~/.ssh/authorized_keys
```

Install only the public node-admin key on approved router/firewall `admin`
accounts.

The GNS3 VM jump preserves the Region A management ACL design: target nodes see
the connection originating from `10.255.191.1`, not directly from PC3.

## Phase 4: Tailscale policy

Apply the staged roles:

| Device | Required tag |
| --- | --- |
| PC3 | `tag:operator-terminal` |
| GNS3 VM | `tag:jump-host` |
| PC1 WSL/Linux jump | `tag:jump-host` |

Use `ops/access/tailscale-acl.example.hujson` as the policy draft. Its PC3
grants permit:

- Operator terminal to jump hosts: TCP 22.
- Operator terminal to tailnet-attached lab nodes: TCP 22, 23, and 830.

It intentionally denies PC3 direct access to PC1/PC2 Windows SSH, RDP, and
WinRM. Add a separate time-bounded rule only when host maintenance is required.

## Phase 5: Termius structure

Create a private vault named `Aurora`.

Create two Termius identities:

| Identity | Key |
| --- | --- |
| `Aurora PC3 Jump` | `aurora-pc3-jump-ed25519` |
| `Aurora Node Admin` | `aurora-pc3-node-admin-ed25519` |

Create these hosts:

| Termius host | Address | User | Identity | Jump host |
| --- | --- | --- | --- | --- |
| `PC2 GNS3 Jump` | `100.118.0.46` | `gns3` | `Aurora PC3 Jump` | none |
| `MEL-P1` | `10.255.191.11` | `admin` | `Aurora Node Admin` | `PC2 GNS3 Jump` |
| `MEL-PE1` | `10.255.191.12` | `admin` | `Aurora Node Admin` | `PC2 GNS3 Jump` |
| `GEL-PE1` | `10.255.191.15` | `admin` | `Aurora Node Admin` | `PC2 GNS3 Jump` |
| `ADL-PE1` | `10.255.191.17` | `admin` | `Aurora Node Admin` | `PC2 GNS3 Jump` |
| `PC1 Lab Jump` | `100.116.32.29` | `aurora-operator` | `Aurora PC3 Jump` | none |

Use Termius groups:

```text
Aurora
  Region A - PC2 GNS3
  Region B - PC1 / DevNet
  Jump Hosts
```

Do not enable agent forwarding. Proxy/jump forwarding is sufficient.

## Phase 6: PC1 jump-host dependency

The current Tailscale status shows `forty3s-pc1-wsl` (`100.116.32.29`) offline.
Region B access from PC3 is therefore not ready yet.

Bring up a persistent Linux jump on PC1 before creating Region B Termius hosts:

- Preferred: a small always-on Linux VM or persistent WSL instance.
- Enable `sshd` and Tailscale at boot.
- Create a personal `aurora-operator` account.
- Permit key authentication only.
- Route only the documented Region B/DevNet management networks.
- Do not expose PC1 Windows as a general jump host.

FRR containers without `sshd` are managed by opening the PC1 Linux jump in
Termius and running `docker exec ... vtysh`; do not add SSH daemons merely for
convenience.

## Validation

From PC3 PowerShell:

```powershell
Test-NetConnection 100.118.0.46 -Port 22
ssh.exe -F "$HOME\.ssh\aurora_pc3_config" pc2-gns3
ssh.exe -F "$HOME\.ssh\aurora_pc3_config" mel-p1
```

In Termius:

1. Open `PC2 GNS3 Jump`.
2. Open `MEL-P1` through the configured jump host.
3. Confirm the device records the management source as `10.255.191.1`.
4. Confirm PC3 cannot connect directly to PC1/PC2 Windows RDP or WinRM.

## Implementation status: 2026-06-19

PC3 generated its two passphrase-protected keys successfully:

| Key | SHA256 fingerprint |
| --- | --- |
| Jump host | `SHA256:JxlpXXyfVoYtsRCXp1IckqE3Ew/1gHvGkMpjkASYx3A` |
| Node admin | `SHA256:8qDFfGl6aj4NmjOl1voSZAioTpBS2IChGhDkl8e9/bA` |

Completed:

- PC3 jump public key installed on `gns3@100.118.0.46`.
- PC3 node-admin public key installed under IOS `username admin` on
  `MEL-P1` (`10.255.191.11`).
- PC3 node-admin public key installed under IOS `username admin` on
  `MEL-PE1` (`10.255.191.12`).
- MEL running configurations saved with `write memory`.

IOS verification on both MEL nodes:

```text
username admin
 key-hash ssh-ed25519 2B482D02A98ECA90A7457CBC7D00928F
```

Pending:

- PC3 validation through its generated SSH config and Termius.
- GEL-PE1 (`10.255.191.15`) and ADL-PE1 (`10.255.191.17`) are currently
  unreachable; their bootstrap snippets contain the PC3 node-admin key ready
  for application when those nodes are online.
- PC1 Linux jump remains offline and must be restored before Region B access.
- Tailscale tags/grants remain staged, not yet applied in the admin console.

## Revocation

If PC3 is lost or repurposed:

1. Remove `tag:operator-terminal` from PC3 or expire the device in Tailscale.
2. Remove the PC3 jump public key from both Linux jump hosts.
3. Remove the PC3 node-admin public key from all lab nodes.
4. Revoke the Termius device/session and rotate any saved passwords.
5. Keep PC1 automation keys unchanged; they were never copied to PC3.
