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

## PC3 dedicated Termius terminal

`forty3s-PC3` (`100.110.254.10`) is the dedicated human-operated Termius
terminal. It reaches Region A through the GNS3 VM jump host and will reach
Region B through a dedicated PC1 Linux jump host:

```text
PC3 -> gns3@100.118.0.46 -> 10.255.191.0/24 Region A nodes
PC3 -> PC1 Linux jump    -> Region B / DevNet / PC1 lab nodes
```

Use `setup-pc3-operator-terminal.ps1` on PC3 to generate separate
passphrase-protected jump-host and node-admin keys. Full setup, Termius host
definitions, validation, and revocation steps are in
`mops/2026-06-19-pc3-termius-operator-terminal.md`.

PC3 is not a routed lab node and should not run inbound SSH, WinRM, SMB, or RDP
for normal operations.

If Mouse Without Borders on PC3 disconnects intermittently, use
`diagnose-pc3-mouse-without-borders.ps1`. It reports MWB processes/listeners,
firewall scope, Wi-Fi state, power management, Tailscale path, and name
resolution. `-ApplySafeFixes` creates a source-restricted TCP 15100-15101 rule
for PC1/PC2 and sets Wi-Fi to Maximum Performance while connected to AC power.

## Tailscale data-plane watchdog

`repair-tailscale-dataplane.ps1` detects a "half-up" Tailscale state (service
running and disco/DERP pongs return, but actual TCP to a peer's Tailscale IP is
dead after sleep or an endpoint flip) and recovers it with
`Restart-Service Tailscale -Force`. It runs as the SYSTEM scheduled task
`Aurora-Tailscale-Health` (boot trigger + every 3 minutes).

Deploy or repair it with the idempotent installer — run **elevated on the target
box** (PC1/PC2/PC3). It copies the script to `C:\ProgramData\Aurora\`, writes a
per-host `tailscale-peers.json` (each box watches a different always-up peer;
default derived from hostname, override with `-TestPeers`), (re)registers the
task, then runs it once and fails loudly unless `LastTaskResult` is `0`:

```powershell
.\ops\access\Install-TailscaleWatchdog.ps1
# or pick the watched peer explicitly:
.\ops\access\Install-TailscaleWatchdog.ps1 -TestPeers @(
    @{ Name = 'PC1'; TailscaleIP = '100.88.225.123'; TestPort = 22 }
)
```

Re-running is safe (`Register-ScheduledTask -Force` replaces the definition).

**Diagnostic — the failure this installer prevents.** The task was once
registered by hand without copying the script to its `-File` target, so every
fire exited `0xFFFD0000` (`powershell -File <missing>`) without ever running.
When the task "does nothing," check in this order:

```powershell
# 1. Did the last run succeed? 0 = OK; 0xFFFD0000 = -File target missing.
Get-ScheduledTaskInfo -TaskName Aurora-Tailscale-Health | Format-List LastRunTime,LastTaskResult

# 2. Does the -File target actually exist on this box?
Test-Path C:\ProgramData\Aurora\repair-tailscale-dataplane.ps1

# 3. What is the script logging?
Get-Content C:\ProgramData\Aurora\tailscale-repair.log -Tail 20
```

A non-zero `LastTaskResult` with a missing target means the script was never
deployed — re-run the installer.

## Clipboard delivery

Commands and configurations intended for manual paste are delivered directly
to the destination machine's interactive clipboard:

| Content | Default destination |
| --- | --- |
| Router, firewall, or Termius paste | PC3 |
| PC2-specific host command | PC2 |
| PC1-specific host command | PC1 |

Use `push-clip.ps1` from PC1. Each item becomes a separate Win+V history entry:

```powershell
.\ops\access\push-clip.ps1 -Dest pc3 -Items 'show running-config'
.\ops\access\push-clip.ps1 -Dest pc3 -Items @(
    'configure',
    'router isis CORE',
    'commit'
)
```

The receiver is the persistent interactive scheduled task
`Aurora-SetClipboard`, backed by `C:\ProgramData\Aurora\set-clip.ps1`. Only
pasteable text belongs in clipboard items; keystroke instructions remain in
the operator steps. For router consoles, prefer the console driver over paste
when bracketed-paste handling could alter the input.

## PC2 Termius opacity

On the Dell PC2 interactive desktop, use the opacity helper to make Termius
less visually dominant while lab nodes are being deployed:

```powershell
.\set-termius-opacity.ps1 -OpacityPercent 25 -InstallAtLogon
```

The helper uses the Windows layered-window API, so it must run inside the
logged-in PC2 desktop session. `-InstallAtLogon` registers a per-user scheduled
task that keeps Termius at the chosen opacity when the user logs in.

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
lab-node-to-host exception is RPKI-RTR to PC1 `192.168.137.1:3323`.

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

The preceding key examples apply to IOS/IOL. Region A IOS-XRv 6.1.3 uses
separate password-authenticated read-only agent accounts because that image
cannot bind imported user keys. Agent secrets remain in Ansible Vault.

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
