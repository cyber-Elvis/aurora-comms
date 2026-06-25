# Aurora Communications

Aurora Communications is a fictional Australian Tier 1 / managed-carrier lab. The current build path is:

```text
Cisco Region A (Dell GNS3, building now)
  -> Juniper/Cisco Region B (DevNet CML)
  -> Cloud Region C (DigitalOcean / containerlab edge)
  -> Secure management + data-plane rings (ADR-004)
  -> Build the network first, then operate it with TechOps discipline
```

The lab is now aligned to the Telstra Protect/Secure TechOps role: Cisco routing and switching, Juniper, Fortinet, Palo Alto, Cisco security, monitoring, change control, incident response, and software/content patching.

## Current Architecture

| Region | Purpose | Main platforms | Status |
| --- | --- | --- | --- |
| Region A | Permanent local ISP/core bench on Dell/PC2 | Cisco IOL-L3 ADL-GEL-MEL-PE1-MEL-P regional line, FortiGate, Aruba CX, local CSR/IOL Transit-A/B, Routinator access | Active build |
| Region B | Multi-site enterprise / Cisco + Juniper extension | PC1 / DevNet CML IOS-XE, IOS-XR, NX-OS, vSRX/vJunos where available; Brisbane/Sydney PEs plus FRR/Docker offload live here | Planned next |
| Region C | Cloud edge / public-facing routing model | cRPD, FRR, Routinator, route-server patterns | Planned |

Region labels are **deployment domains**, not the carrier's geography. The national service-provider topology remains Australia-wide:

| POP | Active lab role |
| --- | --- |
| Melbourne | Core/transit hub: `Aurora-P` + `Aurora-PE-1` (`MEL-PE1` is the Region A↔B inter-region border/ASBR, eBGP 64496↔65002 to Region B `DC-P-R1`), Transit-A, logical Melbourne IXP attachment |
| Sydney | Region B node: `SYD-PE1`, IOS-XR, first ROV enforcer, Region B/C edge; transport to Region B is carried over `MEL-P` |
| Brisbane | Region B enterprise edge: `BNE-PE1`, Helix access/LAN services |
| Geelong | Dell/PC2 Region A regional-line midpoint: `GEL-PE1`, drawn left of `MEL-PE1` |
| Adelaide | Dell/PC2 Region A left-side regional-line endpoint: `ADL-PE1`; local Transit-B backup edge |
| Perth | Western Australia POP; target `PER-PE1`, cloud/interstate latency practice |
| Darwin | Northern Australia remote POP; target `DRW-PE1`, constrained/remote operations practice |
| Tasmania / Hobart | Island POP; target `HBA-PE1` / `TAS-PE1`, submarine/backhaul-failure scenarios |

The local Region A line is intentionally hosted on Dell/PC2 and is drawn geographically as `ADL-PE1 -> GEL-PE1 -> MEL-PE1 -> MEL-P`. `MEL-PE1` is the Region A↔B inter-region border (ASBR), terminating the eBGP 64496↔65002 session to Region B `DC-P-R1`; `MEL-P` is a pure P router that sits on the right as the transport handoff toward PC1 / Region B. Brisbane and Sydney are Region B nodes, not local Region A nodes.

Nokia SR OS/SR Linux is archived, not deleted. The licensed SR OS recipe remains preserved because it is valuable and hard to recreate, but it is no longer the active Region A core.

## Source Of Truth

Read these in order. ADR-003 and ADR-004 are the current architectural decisions; ADR-002 remains only as a stable historical reference for earlier two-region/Nokia/containerlab reasoning and empirical Dell/DevNet findings.

| Document | Purpose |
| --- | --- |
| `docs/adr-003-revendor-cisco-region-a.md` | Current decision: Cisco Region A, Juniper/Cisco Region B, cloud Region C |
| `docs/adr-004-secure-rings-host-isolation.md` | Secure management/data-plane rings, per-agent access, and host-isolation model |
| `docs/region-a-plan.md` | Executable Region A build and operations plan, including the national POP overlay |
| `docs/telstra-ops-practice-plan.md` | Two-week TechOps practice plan layered on top of the built network |
| `docs/aurora-deployment-status.md` | Current environment and validation state |
| `docs/devnet-resource-strategy.md` | Region B / DevNet / cloud resource strategy |
| `docs/runbook.md` | Operational runbook notes and pending split |
| `docs/assets/topology-photos/SOURCES.md` | Downloaded hardware-photo sources and generated node-photo card mapping |
| `ops/access/` | Non-secret SSH helper, inventory, vendor snippets, Tailscale ACL example, and validation runbook |

## Region A Build Shape

Region A is a four-tier service-provider fabric:

- Cisco local P/PE core: ADL -> GEL -> MEL-PE1 -> MEL-P over IS-IS L2, LDP, iBGP VPNv4, MPLS L3VPN, with `MEL-PE1` as the Region A↔B inter-region border (ASBR, eBGP 64496↔65002 to Region B `DC-P-R1`) and `MEL-P` as the right-side transport handoff toward PC1 / Region B.
- Simulated Internet edge: documentation ASNs, local Transit-A/Transit-B in Region A, IXP/FRR offload via Region B/PC1, RPKI/ROV.
- Enterprise/customer edge: FortiGate, Aruba CX, optional IOSv CE.
- Tenant workloads: Helix and Northwind service/workstation containers, preferably hosted from Region B/PC1 Docker rather than Dell/PC2 GNS3 Docker.

The Dell GNS3 VM is resource-constrained but stable for the protocol-light Region A fabric when nodes are brought up in waves. Heavy security/DC nodes such as FTDv, FMC, PA-VM, Cat9kv, and XRv9000 are singleton-on-demand.

## Operating Model

The lab is intentionally build-then-operate:

1. Build a believable ISP-to-enterprise network.
2. Add security overlays and customer edge services.
3. Onboard devices into source-of-truth, config backup, monitoring, and logging.
4. Practise TechOps work against the live network: pre-checks, MOPs, software/content updates, rollback, incident response, RCA, and change closure.

That order matters. Patching and upgrade drills only become meaningful once there is real routing, security policy, monitoring, and customer impact to preserve.

## Secure Access Model

ADR-004 adds the privileged-access and containment layer:

- `admin` is Elvis's break-glass account.
- `aurora-codex` and `aurora-claude` are per-agent automation accounts for lab nodes only.
- Automation uses SSH public keys first; private keys stay on PC1 or another approved operator host.
- PC1, PC2/Dell, DigitalOcean, and Oracle host OSes are never routed lab nodes.
- The management ring is Tailscale-based; the lab data-plane ring is built from virtual edge routers and WireGuard links.
- Lab nodes must not initiate SSH/RDP/SMB/WinRM/hypervisor/admin sessions to PC1, PC2, or cloud host OSes.

Current live slice:

- `MEL-P-CISCO-IOL-RT01` is reachable as `mel-p1` at `10.255.191.11`.
- `MEL-PE1-CISCO-IOL-RT01` is reachable as `mel-pe1` at `10.255.191.12`.
- `GEL-PE1-CISCO-IOL-RT01` and `ADL-PE1-CISCO-IOL-RT01` are started, wired, and reachable over the OOB management network.
- `BNE-PE1-CISCO-IOL-RT01` and `SYD-PE1-CISCO-IOSXR-RT01` have been moved to Region B planning; their DevNet/CML endpoint addresses are still TBD.
- The MEL pair is accessed through the GNS3 VM jump host `gns3@100.118.0.46`.
- Both `aurora-codex` and `aurora-claude` have been verified on the MEL pair with local PC1-held Ed25519 keys.

Use:

```powershell
.\ops\access\aurora-ssh.ps1 mel-p1 -UseCodex -IdentityFile $HOME\.ssh\aurora-codex-local-ed25519
.\ops\access\aurora-ssh.ps1 mel-pe1 -UseCodex -IdentityFile $HOME\.ssh\aurora-codex-local-ed25519
```

## Diagrams

- **Region A:** `docs/region-a-topology.svg` + `.png` are code-generated by `ops/region-a/diagrams/render_topology.py` — the single source. Re-run after plan changes (`python ops/region-a/diagrams/render_topology.py`); SVG and PNG always stay in sync.
- **Region B:** `docs/region-b-topology.svg` + `.png` likewise from `ops/region-b-cml/diagrams/render_topology.py`.
- The legacy hand-authored Region A artifacts (`region-a-topology.drawio`, `_v2.drawio`, `-screenshot.png`) were deleted 2026-06-24 — they drifted from the plan and weren't reproducible; the baked-caption JPGs under `docs/assets/topology-photos/generated/` are no longer referenced.

## Historical Context

Earlier Aurora plans were Nokia-led and containerlab-first. Those records remain at the stable `docs/adr-002-two-region.md` path for traceability, but ADR-003 and ADR-004 supersede the active build and security model. Old Nokia operational detail will be moved into an archive appendix when the historical docs get their cleanup pass.
