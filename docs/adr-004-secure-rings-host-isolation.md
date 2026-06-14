# ADR-004 - Secure rings, per-agent access, and host isolation

| Field | Value |
| --- | --- |
| Status | Accepted |
| Version | 1.0 |
| Date | 2026-06-14 |
| Relates | ADR-002, ADR-003, `docs/region-a-plan.md`, `docs/ip-plan.md`, `ops/access/` |
| Driver | Telstra Protect/Secure practice requires privileged access management, segmentation, blast-radius containment, and auditability |
| Owner | Lab architecture (Elvis Ifeanyi Nwosu) |

## 1. Context

Aurora is now a Cisco-led, security-operations practice lab with local, cloud, and future DevNet execution domains. That makes the management model as important as the routing model.

The security requirement is simple:

> A compromised lab node, local or cloud, must not be able to pivot into PC1, PC2/Dell, cloud host OSes, GitHub, or any personal operator system.

Earlier access was practical and direct: user-owned `admin` credentials, console/API driving, Tailscale reachability, and per-device manual access. That works for a small local lab, but it does not scale cleanly into DigitalOcean, Oracle, DevNet, and multi-agent automation. ADR-004 formalises the access and containment model before Wave 2 grows the topology.

## 2. Decision

### 2.1 Two rings, two different jobs

Aurora uses two separate rings:

| Ring | Members | Carries | Security rule |
| --- | --- | --- | --- |
| Management ring | PC1, PC2/Dell, DigitalOcean host, Oracle host | Operator access, automation, GNS3/API, monitoring, secrets handling | Hosts can initiate to lab nodes; lab nodes cannot initiate to host admin surfaces |
| Lab data-plane ring | Virtual site-edge routers for PC1, PC2, DO, and Oracle sites | Lab transport, WireGuard tunnels, eBGP/IS-IS reconvergence practice | Edge routers peer with ring neighbors only; host OSes are not routed lab nodes |

The architectural invariant is:

> Host OSes never appear as routed lab nodes.

PC1, PC2/Dell, DigitalOcean, and Oracle may host tooling or hypervisors, but the lab topology represents them with virtual edge nodes such as `pc1-edge`, `pc2-edge`, `do-edge`, and `oci-edge`. That gives the lab a realistic inter-site ring without making real host operating systems transit routers.

### 2.2 Per-agent automation identities

Automation identities are separate from the user's break-glass account.

| Identity | Scope | Purpose |
| --- | --- | --- |
| `admin` | User only | Break-glass and owner access; secret is set/owned by Elvis |
| `aurora-codex` | Lab network nodes only | Codex automation access |
| `aurora-claude` | Lab network nodes only | Claude automation access |

`aurora-codex` and `aurora-claude` must not exist on PC1, PC2/Dell, DigitalOcean host OS, Oracle host OS, GitHub, or personal machines.

SSH public-key authentication is preferred for automation accounts. Private keys stay on PC1 or another approved operator host. Nodes receive only public keys. Password fallback is allowed only where a platform cannot support SSH public keys cleanly.

Keys are scoped by zone:

| Zone | Key material |
| --- | --- |
| Local lab | Local-only automation keys |
| Cloud lab | Cloud-only automation keys |
| Future DevNet | DevNet-specific automation keys if persistent access is possible |

A cloud node compromise must not yield credentials that work on local nodes, PC1, or PC2. A local node compromise must not yield credentials that work on cloud hosts.

### 2.3 Initial privilege and later AAA

During the build phase, automation accounts may be local full-privilege accounts on lab nodes because configuration work is active and fast iteration matters.

The long-term target is central AAA:

- TACACS+ for command authorization and accounting.
- Local `admin` retained as break-glass fallback.
- Command restrictions for operational phase, especially `reload`, `username`, `crypto`, `boot`, image operations, and destructive storage commands.

Until TACACS+ exists, device-side management ACLs, source restrictions, logging, and per-agent revocation are the primary controls.

### 2.4 Containment and allowed flows

Default posture is deny from lab nodes to hosts.

| Flow | Decision |
| --- | --- |
| Host/automation -> lab node SSH/API/console | Allow from approved sources |
| Lab node -> ring-neighbor lab edge | Allow for routing/control-plane protocols |
| Lab node -> PC1/PC2/cloud host SSH/RDP/SMB/WinRM/hypervisor/admin ports | Deny and log |
| Lab node -> RPKI-RTR on PC1 `192.168.200.1:3323` | Allow as an explicit service exception |
| Lab node -> monitoring/logging collectors | Allow only when documented |
| Lab node -> arbitrary host OS service | Deny |

This must be enforced at multiple layers:

- Tailscale ACLs: tag-based default deny from `tag:lab` to `tag:hosts`.
- Site demarcation ACLs/firewall policy: deny node-to-host management traffic.
- Host firewalls: PC1/PC2/cloud hosts should not accept lab-node initiated admin sessions.
- Device VTY/source ACLs: lab nodes should accept management only from approved sources.

### 2.5 Data-plane ring

The lab data-plane ring is represented by virtual edge nodes:

```text
pc1-edge ---- pc2-edge ---- do-edge ---- oci-edge ---- pc1-edge
```

The PC1 to PC2 physical Ethernet link remains the local high-speed path. Cloud legs use per-edge WireGuard keypairs. The ring runs eBGP or IS-IS so link/site failure and reconvergence can be tested as a real carrier exercise.

Per-edge WireGuard keys are mandatory. A compromise of one site must not allow an attacker to impersonate a different ring edge.

### 2.6 Tooling source of truth

The **management-ring access** tooling lives under `ops/access/`:

| File | Purpose |
| --- | --- |
| `aurora-ssh.ps1` | PowerShell helper for SSH/telnet syntax, aliases, profiles, and safe known-host handling |
| `inventory.yml` | Non-secret endpoint inventory and SSH profile metadata |
| `validation-runbook.md` | Allowed-path and denied-path proof steps |
| `tailscale-acl.example.hujson` | Example tag/ACL model for the management ring |
| `vendor-templates/` | Placeholder-only vendor snippets for local users, SSH keys, and management restrictions (Cisco IOS/IOS-XE/IOL, IOS-XR, NX-OS, Juniper, FortiGate, Palo Alto, Aruba CX) |

The **data-plane ring** (§2.5) tooling lives under `ops/ring/`:

| File | Purpose |
| --- | --- |
| `README.md` | Ring topology, per-edge key model, eBGP-over-ring design, containment-by-tight-`AllowedIPs` |
| `wireguard-edge.conf.example` | Per-edge WireGuard tunnel template (placeholder keys only; `AllowedIPs` excludes host subnets) |
| `ring-ebgp.example.conf` | eBGP-over-ring edge skeleton with a `NO-HOST-SUBNETS` egress guard |

No password, private key, `secret 9` hash, API token, or cloud credential belongs in the repo.

## 3. Consequences

**Positive**

- The lab can scale from local GNS3 to DO/Oracle/DevNet without turning host OSes into transit nodes.
- Per-agent accounts give clean audit and independent revocation.
- Public-key automation reduces password exposure and makes zone isolation practical.
- Validation includes negative testing, which matches real Secure/Protect operations better than only checking reachability.

**Trade-offs**

- Per-agent, per-zone keys require more bookkeeping.
- Some NOSes may force password fallback or legacy SSH algorithms.
- Full command restriction is deferred until TACACS+ exists, so build-phase local accounts remain powerful.
- The data-plane ring adds routing realism, but it must be built carefully so it does not bypass host isolation.

## 4. Required validation

Before the cloud ring is considered production-like:

1. `aurora-codex` and `aurora-claude` can SSH to selected lab nodes.
2. Neither automation account exists on PC1, PC2/Dell, DO host OS, Oracle host OS, GitHub, or personal machines.
3. A lab node cannot reach PC1/PC2 SSH, RDP, SMB, WinRM, hypervisor, or admin ports.
4. Tailscale denies `tag:lab` -> `tag:hosts`.
5. The data-plane ring reconverges when one ring link is removed.
6. No private key, password, `secret 9`, API token, or cloud secret is present in git.
7. Legacy SSH options apply only to explicitly marked legacy devices.
8. Denied node-to-host attempts produce logs visible to Wazuh or the chosen SIEM/log collector.

## 5. Revision history

- **v1.0 (2026-06-14)** - initial. Records the two-ring model, host-isolation invariant, per-agent automation identities, key-first access, containment rules, and `ops/access/` tooling contract.
