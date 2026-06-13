# Aurora Communications

Aurora Communications is a fictional Australian Tier 1 / managed-carrier lab. The current build path is:

```text
Cisco Region A (Dell GNS3, building now)
  -> Juniper/Cisco Region B (DevNet CML)
  -> Cloud Region C (DigitalOcean / containerlab edge)
  -> Build the network first, then operate it with TechOps discipline
```

The lab is now aligned to the Telstra Protect/Secure TechOps role: Cisco routing and switching, Juniper, Fortinet, Palo Alto, Cisco security, monitoring, change control, incident response, and software/content patching.

## Current Architecture

| Region | Purpose | Main platforms | Status |
| --- | --- | --- | --- |
| Region A | Permanent local ISP/core bench | Cisco IOL-L3 P/PE core, IOS-XRv PE, FortiGate, Aruba CX, CSR/IOL transit, FRR IXP, Routinator | Active build |
| Region B | Multi-site enterprise / Cisco + Juniper extension | DevNet CML IOS-XE, IOS-XR, NX-OS, vSRX/vJunos where available | Planned next |
| Region C | Cloud edge / public-facing routing model | cRPD, FRR, Routinator, route-server patterns | Planned |

Region labels are **deployment domains**, not the carrier's geography. The national service-provider topology remains Australia-wide:

| POP | Active lab role |
| --- | --- |
| Melbourne | Core/transit/IXP hub: `Aurora-P` + `Aurora-PE-1`, Transit-A, Melbourne IXP |
| Sydney | Major interconnect and Region B/C handoff: `Aurora-PE-3`, Transit-B, first ROV enforcer |
| Brisbane | Regional enterprise edge: `Aurora-PE-2`, Helix access/LAN services |
| Geelong | Regional access POP placeholder now; target light `Aurora-PE-4` / GEL edge once the Cisco core is stable |

Nokia SR OS/SR Linux is archived, not deleted. The licensed SR OS recipe remains preserved because it is valuable and hard to recreate, but it is no longer the active Region A core.

## Source Of Truth

| Document | Purpose |
| --- | --- |
| `docs/adr-003-revendor-cisco-region-a.md` | Current decision: Cisco Region A, Juniper/Cisco Region B, cloud Region C |
| `docs/region-a-plan.md` | Executable Region A build and operations plan, including the national POP overlay |
| `docs/telstra-ops-practice-plan.md` | Two-week TechOps practice plan layered on top of the built network |
| `docs/aurora-deployment-status.md` | Current environment and validation state |
| `docs/devnet-resource-strategy.md` | Region B / DevNet / cloud resource strategy |
| `docs/runbook.md` | Operational runbook notes and pending split |

## Region A Build Shape

Region A is a four-tier service-provider fabric:

- Cisco P/PE core: IS-IS L2, LDP, iBGP VPNv4 full mesh, MPLS L3VPN.
- Simulated Internet edge: documentation ASNs, transit-A/transit-B, IXP route server, RPKI/ROV.
- Enterprise/customer edge: FortiGate, Aruba CX, optional IOSv CE.
- Tenant workloads: Helix and Northwind service/workstation containers.

The Dell GNS3 VM is resource-constrained but stable for the protocol-light Region A fabric when nodes are brought up in waves. Heavy security/DC nodes such as FTDv, FMC, PA-VM, Cat9kv, and XRv9000 are singleton-on-demand.

## Operating Model

The lab is intentionally build-then-operate:

1. Build a believable ISP-to-enterprise network.
2. Add security overlays and customer edge services.
3. Onboard devices into source-of-truth, config backup, monitoring, and logging.
4. Practise TechOps work against the live network: pre-checks, MOPs, software/content updates, rollback, incident response, RCA, and change closure.

That order matters. Patching and upgrade drills only become meaningful once there is real routing, security policy, monitoring, and customer impact to preserve.

## Diagrams

- `docs/region-a-topology.drawio` is refreshed for the Cisco Region A core.
- `docs/region-a-topology.png` requires a local drawio/diagrams.net renderer before it can be regenerated from the updated source.

## Historical Context

Earlier Aurora plans were Nokia-led and containerlab-first. Those records remain in ADR-002 and the older architecture docs for traceability, but ADR-003 supersedes the active Region A vendor stack.
