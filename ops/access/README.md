# Aurora access tooling

This directory contains non-secret operator tooling for Aurora management access.

The core rules come from `docs/adr-004-secure-rings-host-isolation.md`:

- `admin` is the user's break-glass account.
- `aurora-codex` and `aurora-claude` are lab-node-only automation accounts.
- Automation should use SSH public keys first.
- Private keys, passwords, `secret 9` hashes, API tokens, and cloud credentials do not belong in this repo.
- Host OSes are not routed lab nodes.

## SSH helper

Use the PowerShell helper from PC1 or another approved operator host:

```powershell
.\ops\access\aurora-ssh.ps1 -List
.\ops\access\aurora-ssh.ps1 mel-p1
.\ops\access\aurora-ssh.ps1 mel-p1 -UseCodex
.\ops\access\aurora-ssh.ps1 sros-legacy-lab -Profile sros-legacy -User admin
.\ops\access\aurora-ssh.ps1 mel-p1 -PrintOnly
```

The helper prompts through normal SSH. It never accepts a password parameter.
Aliases may include `proxy_jump`, for example `gns3@100.118.0.46`, so PC1 can reach private lab management addresses through the GNS3 VM without routing host OSes through the lab.

## Profiles

| Profile | Purpose |
| --- | --- |
| `modern` | Normal SSH for current NOSes |
| `sros-legacy` | Old SR OS/OpenSSH compatibility profile; weak algorithms are scoped to explicit legacy aliases only |
| `network-console` | Telnet-style console access for GNS3 console ports |

## Host containment

Local host containment is enforced at the GNS3 management demarcation and, where
available, on node/site ACLs and host firewalls.

Key artifacts:

| Path | Purpose |
| --- | --- |
| `host-guard/gns3-vm-host-guard.sh` | GNS3 VM iptables guard for `tap-aurora-mgmt`; permits only the PC1 RPKI-RTR exception and logs/rejects protected host-admin ports |
| `host-guard/README.md` | Local proof matrix and 2026-06-15 live observations |
| `wazuh/aurora-host-containment-rules.xml` | Wazuh custom rules for denied lab-node attempts toward protected host services |
| `wazuh/README.md` | Wazuh install and `wazuh-logtest` samples |

Protected local host services are SSH, RPC/NetBIOS/SMB, RDP, WinRM, GNS3/admin
ports, and common hypervisor/web-admin ports on PC1/PC2. The only local
lab-node-to-host exception is RPKI-RTR to PC1 `192.168.200.1:3323`.

## Identity model

Use one key per agent per zone.

Recommended local key names, kept outside git:

```text
%USERPROFILE%\.ssh\aurora-codex-local-ed25519
%USERPROFILE%\.ssh\aurora-claude-local-ed25519
%USERPROFILE%\.ssh\aurora-codex-cloud-ed25519
%USERPROFILE%\.ssh\aurora-claude-cloud-ed25519
```

Only the public key is copied to lab nodes. The private key never goes onto a router, firewall, GNS3 project, cloud VM image, or this repository.

Generate keys explicitly when ready:

```powershell
.\ops\access\new-agent-key.ps1 -Agent codex -Zone local
.\ops\access\new-agent-key.ps1 -Agent claude -Zone local
```

The helper calls `ssh-keygen.exe` with an empty passphrase by default so automation keys can run non-interactively. Use `-Passphrase` if a protected key is required. It refuses to overwrite an existing key unless `-Force` is supplied.

## Node snippets

Initial SSH snippets for MEL-P and the PE nodes live in `node-snippets/`. MEL-P and MEL-PE1 now include the local `aurora-codex` and `aurora-claude` public key bodies. Secret placeholders for `admin` and `enable` are still replaced manually on-console and must not be committed.

Current verified access:

```powershell
.\ops\access\aurora-ssh.ps1 mel-p1  -UseCodex  -IdentityFile $HOME\.ssh\aurora-codex-local-ed25519
.\ops\access\aurora-ssh.ps1 mel-pe1 -UseCodex  -IdentityFile $HOME\.ssh\aurora-codex-local-ed25519
.\ops\access\aurora-ssh.ps1 mel-p1  -UseClaude -IdentityFile $HOME\.ssh\aurora-claude-local-ed25519
.\ops\access\aurora-ssh.ps1 mel-pe1 -UseClaude -IdentityFile $HOME\.ssh\aurora-claude-local-ed25519
```

## Inventory

`inventory.yml` contains non-secret aliases and profile metadata. Planned nodes may have `host: TBD`; the helper will list them but refuse to connect until a concrete host/address is set.

Local GNS3 node management addresses use the dedicated GNS3 VM TAP subnet `10.255.191.0/24` and jump through `pc2-gns3` / `gns3@100.118.0.46`.

Host endpoints such as the GNS3 VM are marked `credential_scope: host`. The helper blocks `-UseCodex` / `-UseClaude` against those entries because automation node accounts must not exist on host OSes.
