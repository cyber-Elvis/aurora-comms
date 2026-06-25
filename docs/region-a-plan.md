# Region A — Build and Operations Plan (v2.5)

> **Platform update (2026-06-21):** the live Region A core has been **re-platformed from Cisco IOL to IOS-XRv 6.1.3** (MOP `CHG-AURORA-REG-A-XRV-001`; all 4 nodes cut over with deployed parity, MEL pair IS-IS L2 + LDP validated XR↔XR). The platform names and node IDs in the body below (`*-CISCO-IOL-RT01`, "IOL-AdvEnterprise-L3") describe the **pre-migration design**; the *deployed* state is now IOS-XRv (break-glass user `labadmin`, RSA-only, `Gi0/0/0/x` interface naming). Some addressing here (e.g. GEL `10.0.0.5`, ADL `10.0.0.6`) is the **planned** target — the migration deliberately preserved the deployed loopbacks (GEL `10.0.0.3`, ADL none) with no VPNv4/renumber. Authoritative current state: [`docs/aurora-deployment-status.md`](aurora-deployment-status.md), the MOP above, and `memory/region-a-iosxrv-platform.md`.

| Field | Value |
| --- | --- |
| Status | Active (build in progress) |
| Version | 2.5 |
| Date | June 2026 |
| Scope | Steady-state Region A fabric on Dell/PC2 GNS3 — the local regional line drawn geographically as **ADL -> GEL -> MEL-PE1 -> MEL-P**. `MEL-P` sits on the right as the local core/handoff toward PC1-hosted `SYD-PE1` in Region B. Core is **MPLS L3VPN-capable** (VRF + VPNv4). Region A/B/C are deployment domains; the represented national POPs are **Melbourne, Sydney, Brisbane, Geelong, Adelaide, Perth, Darwin, and Tasmania/Hobart**. Brisbane and Sydney are Region B nodes, not local Region A nodes. |
| Excludes | Singleton heavyweights (FTDv, Cat9kv, FMC, XRv9000, PA-VM 11), Region B (DevNet CML), Region C (cloud edge), inter-region BGP confederation, routing-protocol authentication (TCP-AO/MD5). **NOT excluded but explicitly lab-only:** ASNs are RFC 5398 *documentation* ASNs (not registered), prefixes are RFC 5737/3849 *documentation* space, RPKI uses local SLURM VRPs (not real RIR ROAs) — nothing is ever advertised to the real Internet. |
| Revision | **v2.5 aligns the live and documented topology geographically:** `ADL-PE1`, `GEL-PE1`, and `MEL-PE1` sit to the left, while `MEL-P` sits to the right and is the logical handoff toward PC1/Region B `SYD-PE1`. v2.4 moved Brisbane/Sydney to Region B and made GEL/ADL local Dell/PC2 nodes. v2.3 pinned the MEL -> GEL -> ADL regional line to Dell/PC2. v2.2 expanded the national POP overlay to include Adelaide, Perth, Darwin, and Tasmania/Hobart as planned POPs. v2.1 restored the Australia-wide POP overlay on top of the Cisco re-vendor. v2.0 re-vendored the backbone from Nokia to Cisco per ADR-003. Nokia SR OS/SR Linux are **archived** (recipe + license cold-stored, recoverable via git history). VPRN → VRF terminology; SR OS `show router …` → IOS `show …`. Added the explicit **L3VPN validation (VRF CUST-A)** path. |
| Source of truth for design | **ADR-003** (Region A vendor stack — Cisco), **ADR-004** (secure rings and host isolation), ADR-002 §3.2–§3.9 (two-region structure, Dell capability envelope, operational rules) |
| Owner | Lab architecture (Elvis Ifeanyi Nwosu) |
| Related | `docs/adr-003-revendor-cisco-region-a.md`, `docs/adr-004-secure-rings-host-isolation.md`, `docs/adr-002-two-region.md`, `docs/design.md`, `docs/ip-plan.md`, `docs/runbook.md`, `docs/assets/topology-photos/SOURCES.md`, `memory/gns3-nos-boot-quirks.md`, `memory/gns3-vm-ram-budget.md`, `memory/lab-coaching-workflow.md` |

## 1. What this doc is

The **executable plan** companion to the ADRs. ADR-003 says *what the Region A vendor stack is and why* (Cisco); ADR-002 §3 says *what the two-region structure is*; this doc says *what to build, in what order, how to verify, and how to operate it*.

Region A's empirical capacity envelope (ADR-002 §3.9) is the constraint this plan respects: **7–8 protocol-light nodes run together stably on Dell GNS3 in steady state**, with headroom to add lights, and the rule that singleton heavyweights run **solo** with the fabric stopped. The Cisco re-vendor makes the backbone *lighter*, not heavier: **IOL-AdvEnterprise-L3 is ~0.5 GB idle each** (vs SR OS ~0.5 GB + SR Linux ~1 GB), so the whole four-tier fabric lands at **~7.5–8 GiB idle** — comfortably inside the proven envelope.

> **Build state (2026-06-14):** GNS3 project `ops-lab` (`d8119db0-…`). **Aurora-P + Aurora-PE-1 created, linked, booted** (IOL-L3, blank config, at enable prompt) and being configured now per §6 Wave 1. Console-driven config via the `iolcfg.py` socket helper on the GNS3 VM (see `memory/lab-coaching-workflow.md`).

> **Build update (2026-06-15):** `GEL-PE1-CISCO-IOL-RT01` and `ADL-PE1-CISCO-IOL-RT01` are created and wired in `ops-lab`, both left stopped for wave-controlled bring-up. The local Region A line is wired as `MEL-P <-> MEL-PE1 <-> GEL-PE1 <-> ADL-PE1`, but the live canvas is aligned geographically left-to-right as `ADL-PE1 -> GEL-PE1 -> MEL-PE1 -> MEL-P`. `MEL-P` is the right-side local core and the logical handoff toward PC1-hosted `SYD-PE1` in Region B. `BNE-PE1-CISCO-IOL-RT01` and `SYD-PE1-CISCO-IOSXR-RT01` were removed from local Region A staging and moved to Region B planning.

> **Access update (2026-06-16):** the PC1/PC2 local Ethernet segment now carries internet and uses `192.168.137.0/24`. Current plan values are PC1/gateway/Routinator `192.168.137.1` and PC2/Dell/GNS3 controller `192.168.137.1:3080`.

### 1.1 National POP overlay

The national model still spans Melbourne, Sydney, Brisbane, Geelong, Adelaide, Perth, Darwin, and Tasmania/Hobart. What changed is placement and canvas orientation. Treat **Region A/B/C as execution domains** and **MEL/SYD/BNE/GEL/ADL/PER/DRW/HBA as carrier POPs**. The **ADL -> GEL -> MEL-PE1 -> MEL-P** view is hosted on Dell/PC2 as the local Region A regional chain. **Brisbane and Sydney are Region B POPs** and should be built in DevNet CML / PC1-hosted workflows rather than the Dell/PC2 Region A project.

| POP | Active lab node(s) | Role in the carrier story |
| --- | --- | --- |
| Melbourne | `Aurora-P` (`MEL-P`) + `Aurora-PE-1` (`MEL-PE1`) | `MEL-PE1` sits with the left-side regional line and is the **inter-region eBGP border / ASBR** (terminates `64496 ↔ 65002` to Region B's `DC-P-R1`); `MEL-P` sits on the right as the local core / **transport** handoff toward PC1/Region B |
| Sydney | Region B target `SYD-PE1` / `Aurora-PE-3` | PC1-hosted Region B node; major interconnect, Region B/C edge, first IOS-XR ROV enforcer. (The inter-region eBGP border is `MEL-PE1` ↔ Region B's `DC-P-R1`, **not** SYD-PE1.) |
| Brisbane | Region B target `BNE-PE1` / `Aurora-PE-2` | Regional enterprise edge and Helix services |
| Geelong | `GEL-PE1` | Dell/PC2 regional-line midpoint between ADL and MEL-PE1; smaller-enterprise edge / branch-failover scenarios |
| Adelaide | `ADL-PE1` | Dell/PC2 regional-line endpoint; south-central aggregation POP useful for east-west path policy and maintenance-window drills |
| Perth | planned `PER-PE1` | Western Australia POP; useful for long-haul latency, cloud-edge, and route-policy drills |
| Darwin | planned `DRW-PE1` | Northern remote POP; useful for constrained remote operations and degraded-backhaul scenarios |
| Tasmania / Hobart | planned `HBA-PE1` / `TAS-PE1` | Island POP; useful for submarine/backhaul-failure and regulated-services continuity drills |

Do **not** read Region A as "Melbourne only." Region A is the local Dell-hosted slice of the national carrier: ADL/GEL/MEL-PE1 plus the right-side MEL-P core. The POP aliases are the topology story operators should use in tickets, diagrams, MOPs, monitoring labels, and incident notes. Draw diagrams and the live GNS3 canvas with `ADL-PE1`, `GEL-PE1`, and `MEL-PE1` grouped to the left, `MEL-P` to the right, and a logical `MEL-P -> PC1/SYD-PE1` handoff. The planned POPs do not all need to run simultaneously on the Dell; Brisbane/Sydney specifically belong in Region B, while Perth/Darwin/Hobart can be simulated later by light IOL nodes, DevNet CML, or cloud/containerlab edges.

## 2. Inventory — four tiers plus tenant containers

Region A is a four-tier SP: **P/core → PE → Customer Edge → Internet Edge**. The local Dell/PC2 slice keeps both simulated upstream transits in Region A for immediate primary/backup policy work: Transit-A on `MEL-PE1` and Transit-B on `ADL-PE1`. Docker-dependent pieces such as FRR IXP peers and tenant workload containers are Region B/PC1 offload candidates so the local GNS3 VM can stay focused on router/firewall nodes.

### 2.1 Backbone (P + PE core) — Cisco (ADR-003)

| Role | POP alias | Node name | NOS | RAM (declared / idle RSS) | vCPU | Recipe ref |
| --- | --- | --- | --- | --- | --- | --- |
| Aurora-P (IS-IS L2 / LDP transit, no BGP) | `MEL-P` | `MEL-P-CISCO-IOL-RT01` | **Cisco IOL-AdvEnterprise-L3** | ram=2048, nvram=1024 / ~0.5 GB | n/a | Active in `ops-lab`; OOB `10.255.191.11`; pure P role |
| Aurora-PE-1 (L3VPN PE; Northwind CE + Transit-A) | `MEL-PE1` | `MEL-PE1-CISCO-IOL-RT01` | **Cisco IOL-AdvEnterprise-L3** | ram=2048, nvram=1024 / ~0.5 GB | n/a | Active in `ops-lab`; OOB `10.255.191.12`; full MPLS L3VPN |
| Geelong regional PE | `GEL-PE1` | `GEL-PE1-CISCO-IOL-RT01` | **Cisco IOL-AdvEnterprise-L3** | ram=2048, nvram=1024 / ~0.5 GB | n/a | Active in `ops-lab`; OOB `10.255.191.15`; regional-line midpoint |
| Adelaide regional PE (Transit-B backup edge) | `ADL-PE1` | `ADL-PE1-CISCO-IOL-RT01` | **Cisco IOL-AdvEnterprise-L3** | ram=2048, nvram=1024 / ~0.5 GB | n/a | Active in `ops-lab`; OOB `10.255.191.17`; regional endpoint |

> **Live access state (2026-06-21):** all four backbone routers are started,
> wired to `MGMT-SW01`, and reachable from PC3 Termius through the GNS3 VM
> jump host. The operator enters device CLI; Codex prepares MOPs and verifies
> state through API and read-only checks unless console access is explicitly
> permitted.

> **Nokia archived (ADR-003 §2.2).** The previous core — Aurora-P on SR Linux 24.10 and Aurora-PE-1/PE-2 on licensed SR OS 13.0R4 — is **cold-stored, not deleted**. SR OS license qcow2 + RTC/UUID recipe live in three places (md5 recorded, `memory/sros-gns3-license-recipe.md`); the prior v1.2 of this plan is in git history. Nokia can return on a non-triple-nested host. **Why re-vendored:** the Telstra role is Cisco/Juniper-led; IOL-L3 is lighter, runs the full core together, supports full L3VPN, and is already working on this box.

### 2.2 Customer Edge

| Role | Node name | NOS | RAM (declared / idle RSS) | vCPU | Recipe ref |
| --- | --- | --- | --- | --- | --- |
| Northwind CE (consolidated CE + FortiSD-WAN + NGFW) | `northwind-ce` | Fortinet FortiGate-VM 7.0.14 | 1 GB / ~0.6 GB | 1 | ide + 30 GB blank `hdb` data disk |
| Helix LAN switch (customer-owned LAN practice) | `helix-lan-sw` | HPE Aruba CX 10.16.1040 | 4 GB / ~1.7 GB | 2 | `-nographic`; **30-day trial license unactivated — do not run `license` CLI until ready**. Region B owns the Brisbane PE/CE attachment when built |
| Offline-fallback CE (optional, on-demand) | `region-a-ce-spare` | Cisco IOSv 15.7 | ~0.5 GB / ~0.4 GB | 1 | CE-only spare; IOSv is **not** used as a PE — weak MPLS |

### 2.3 Internet Edge (simulated upstream transit + IXP peering + lab RPKI)

ASNs are **RFC 5398 documentation ASNs** (64496–64511); prefixes are **RFC 5737/3849 documentation space**. Aurora itself = **AS 64496** (the carrier). Northwind customer = **AS 64512 (private CE, default model)** or **AS 64502 (optional BYO-AS public customer)** — see §4.

| Role | Node name | NOS | AS | RAM (declared / idle RSS) | vCPU | Recipe ref |
| --- | --- | --- | --- | --- | --- | --- |
| Upstream Transit-A (primary) | `transit-a-csr` | Cisco CSR1000v 16.08.01 | 64497 | **3 GB** / ~2.5 GB | 1 | ide / qemu64; BGP-only role → 3 GB; RTR/ROV-capable |
| Upstream Transit-B (backup) | `transit-b-iol` | Cisco IOL-XE 17.15 | 64498 | ram=2048, nvram=1024 / ~0.5 GB | 1 | Local Region A backup transit on `ADL-PE1`; RTR/ROV-capable |
| IXP fabric (Melbourne IXP peering LAN) | `ixp-fabric` | GNS3 Ethernet switch (L2) | n/a | 0 | n/a | a built-in switch — IXPs are L2 fabrics |
| IXP route server | `ixp-rs1` | FRR (docker, `frrouting/frr:latest`) | 64499 | Region B/PC1 offload | n/a | RS = next-hop-preserving; rpki module present (`librtr.so` — §10) |
| IXP content/CDN peer | `ixp-content1` | FRR (docker) | 64500 | Region B/PC1 offload | n/a | originates mock CDN prefixes |
| IXP eyeball/ISP peer | `ixp-eyeball1` | FRR (docker) | 64501 | Region B/PC1 offload | n/a | originates mock eyeball prefixes |
| RPKI validator / RP (Routinator) | `rpki-rp1` | Routinator (docker) | n/a | **on PC1, off the Dell budget** (~200 MB) | n/a | Phase C; SLURM local VRPs; serves RTR (TCP 3323) via a GNS3 Cloud node bridged to `192.168.137.x` |

### 2.4 Tenant workloads (Docker offload — Region B/PC1)

`helix-orthanc` (DICOM), `helix-emr` (nginx mock), `helix-doctor-wks` (alpine+iperf3), `northwind-saas` (nginx), `northwind-redis`, `northwind-prometheus`, `northwind-grafana`, `northwind-dev-wks` (alpine+iperf3) remain part of the service story, but they should run in Region B/PC1 Docker rather than on the Dell/PC2 GNS3 VM. Maple Ridge workloads also live in Region B.

### 2.5 Footprint

| Tier | Declared | Idle RSS (est.) |
| --- | --- | --- |
| Backbone (4× **IOS-XRv 6.1.3**) | ~12 GB | ~4 GB |
| Customer Edge (FortiGate + Aruba CX; spare CE optional) | ~5 GB | ~2.7 GB |
| Internet Edge local slice (Transit-A CSR 3 + Transit-B IOL 2 + fabric 0; FRR IXP offloaded) | ~5 GB | ~3 GB |
| Docker offload (IXP FRR + tenant workloads) | Region B/PC1 | off Dell/PC2 budget |
| **Total local core running fabric** | **~22 GB declared** | **~10–11 GiB actual idle** |

**Re-costed for the 2026-06-21 IOL→IOS-XRv migration (2026-06-24):** each IOS-XRv 6.1.3 node is ~3 GB declared / ~1 GB idle (ADR-002 §3.9.5), ~2× the ~0.5 GB IOL it replaced, so the backbone rose from ~4 GB→~12 GB declared and ~2 GB→~4 GB idle. Still inside the envelope on **RAM** (19 GiB GNS3 VM, ~17 GiB usable; qemu overcommit means declared ≠ resident — ~10–11 GiB resident leaves ~6 GiB headroom, so both transits still stay local). The pre-migration "all-IOL backbone freed ~1 GiB, so the transits fit" rationale **no longer holds** — they fit on remaining headroom, not on a light backbone. **The binding risk is now CPU on cold-start**, not RAM: XRv boots heavier than IOL and the 2-core VM already hit load ~9 at 7 nodes (ADR-002 §3.9.3). Therefore bring the 4×XRv backbone + 2 transits up **strictly staggered (waves of 2–3, let each converge)** and run a **30–60 min soak with `clear bgp *`** before declaring the edge stable (ADR-002 §3.9.4 Rules 2 & 4). The spare CE (`region-a-ce-spare`) is bring-up-on-demand and not counted in the core total.

### 2.6 Design choices noted explicitly (callable for review)

- **Backbone re-vendored to Cisco (ADR-003).** IOL-AdvEnterprise-L3 for the Dell/PC2 ADL -> GEL -> MEL-PE1 -> MEL-P line: light (~0.5 GB), full MPLS **L3VPN** (VRF + VPNv4 + LDP labels), and IOU is resolved on this box. **The local Region A PEs are L3VPN-capable**; **IOSv is CE-only** (weak MPLS).
- **Aurora-PE-3 / SYD-PE1 = IOS-XRv 6.1.3, now Region B.** XR remains the carrier-grade Cisco OS for VPNv4, ROV, and the future Region B/C edge. It is no longer a Dell/PC2 Region A node.
- **Why not the "9k" platforms for the P/PE core.** The binding constraint is that the local fabric runs simultaneously on the 19 GB / 2-physical-core / no-swap GNS3 VM — which forces light nodes. The 9k-class boxes each fail on weight, role, or boot: **Catalyst 9000v** is a campus *switch* (~16–18 GB each → one nearly fills the VM; wrong role for an SP PE; singleton-only with `-cpu host`); **Nexus 9300v** is a DC *switch* and **won't boot** on this triple-nested host (same wall as vJunos — deferred to Region B/CML); **XRv9000** is the *correct* role (carrier IOS-XR PE) but ~16 GB and **singleton-only** (`cpu_throttling=80`). IOL-AdvEnterprise-L3 is the only option that is a full MPLS-L3VPN router (real IOS CLI/behaviour), **~0.5 GB each** (whole core runs at once with headroom), and already working here. Carrier XR realism is provided by **SYD-PE1 in Region B**. The heavy 9k boxes are **on-demand singletons** (§8.6) for platform-specific drills and live in **Region B (CML, real non-nested infra)** for DC-fabric / newer-XR work — not in the always-on Region A fabric.
- **L3VPN validation VRF = `CUST-A` (rd/rt `64496:100`).** Before wiring the tenant VRFs, the first MPLS-L3VPN proof is a minimal `CUST-A` VRF on two PEs with test interfaces — confirms VPNv4 exchange + label imposition + cross-PE VRF ping end to end (§5.3, §7). The real tenant services then follow the per-tenant VRF convention (Northwind `64496:3`, Helix `64496:2`).
- **CSR1000v = Transit-A; IOL-XE = Transit-B, both local Region A.** CSR has the richest BGP/policy knobs of the light Cisco nodes and remains the primary transit. IOL-XE covers backup transit on `ADL-PE1`, giving the local line a real failover test without waiting for Region B. Spare-CE duty drops to **IOSv** (lighter, CE-only).
- **Two transits terminate on different local PEs** (Transit-A on `MEL-PE1`, Transit-B on `ADL-PE1`). This keeps the original Region A Internet-edge design and exercises the whole ADL-GEL-MEL path during backup-default failover.
- **IXP route server = FRR, not IOS/CSR, but FRR can move to Region B/PC1.** FRR (and BIRD) are what real IXPs run; FRR gives proper route-server semantics (next-hop preservation, multilateral reflection) an IOS eBGP-with-next-hop-self only approximates. Because these are Docker-dependent nodes, host them in Region B/PC1 when the local Dell/PC2 budget is better spent on router and firewall NOSes.
- **Dual IXP attachment is a later lab pedagogy target** — kept to demo IX-uplink-failure and iBGP reconvergence once a second eligible edge is active.
- **iBGP topology = full mesh among local Region A PEs**. Below the threshold where route reflection earns its complexity. Aurora-P (IOS-XRv) does **not** run BGP — pure IS-IS/LDP transit.
- **Helix LAN connection model is mode-switched** (see §10): when Region B is up, Helix CE/PE lives with BNE-PE1 in Region B. When Region B is down, the standalone local Aruba CX remains useful for access-switching and segmentation practice without making Brisbane a Region A PE.
- **Maple Ridge workloads are not in Region A.** Maple Ridge primary CE is Region B (Cat8000v in CML, ADR-002 §3.2).
- **Documentation ASNs (RFC 5398, 64496–64511), not private ASNs (RFC 6996).** Aurora = 64496; transits 64497/64498; IXP RS/content/eyeball 64499/64500/64501; customer 64502. (Private ASN 64512 is used only for the private-customer CE model.)
- **Lab RPKI/ROV via Routinator + SLURM, not real RIR ROAs.** `rpki-rp1` runs Routinator (validator / RP); SLURM (RFC 8416) `locallyAddedAssertions` mint VRPs for the documentation prefixes. Routers are the **ROV enforcers** (RTR clients) — validator ≠ enforcer. **First IOS-XR ROV enforcer = Region B `SYD-PE1` / Aurora-PE-3**; local Region A IOL-L3 can still test IOS origin-validation on its eBGP ingress when the Internet Edge is wired.
- **IPv4 + IPv6 dual-stack** at the edge. IPv6 from `2001:db8::/32` (RFC 3849); IPv4 mock prefixes are **sub-allocations of the three RFC 5737 /24s** (distinct "Internet" prefixes are /28 slices).
- **Routinator on PC1, off the Dell budget.** ~200 MB; reachability via a GNS3 Cloud node bridged to the internet-carrying `192.168.137.x` PC1/PC2 segment, RTR on TCP 3323.

## 3. Topology

### 3.1 Logical topology

```mermaid
graph LR
    classDef cisco_iol fill:#1ba0d7,color:#fff,stroke:#0d6986
    classDef cisco_xr fill:#1565c0,color:#fff,stroke:#0d47a1
    classDef cisco_xe fill:#42a5f5,color:#fff,stroke:#1565c0
    classDef fortinet fill:#ee3124,color:#fff,stroke:#a61b13
    classDef aruba fill:#ff9800,color:#fff,stroke:#e65100
    classDef workload fill:#fdd835,color:#000,stroke:#f57f17
    classDef transit fill:#6a1b9a,color:#fff,stroke:#4a148c
    classDef ixp fill:#00897b,color:#fff,stroke:#00695c
    classDef mgmt fill:#455a64,color:#fff,stroke:#263238
    classDef planned fill:#ffffff,color:#334155,stroke:#94a3b8,stroke-dasharray: 5 5

    subgraph INet["🌐 Internet Edge (simulated, doc ASNs/prefixes)"]
        TA["transit-a-csr<br/>CSR1000v · AS 64497<br/>(primary transit)"]
        TB["transit-b-iol<br/>IOL-XE · AS 64498<br/>(backup transit)"]
        IXF(["ixp-fabric<br/>Melbourne IXP L2 LAN"])
        RS["ixp-rs1<br/>FRR · AS 64499<br/>(Region B/PC1 docker offload)"]
        CON["ixp-content1<br/>FRR · AS 64500<br/>(Region B/PC1 docker offload)"]
        EYE["ixp-eyeball1<br/>FRR · AS 64501<br/>(Region B/PC1 docker offload)"]
        RPKI["rpki-rp1 · Routinator<br/>(on PC1) → RTR :3323<br/>SLURM lab VRPs"]
    end

    subgraph Backbone["Aurora AS 64496 — Cisco P/PE core (drawn west-to-east: ADL, GEL, MEL-PE1, MEL-P)"]
        ADL["ADL-PE1<br/>IOS-XRv 6.1.3<br/>(regional L3VPN PE)"]
        GEL["GEL-PE1<br/>IOS-XRv 6.1.3<br/>(regional L3VPN PE)"]
        PE1["Aurora-PE-1 / MEL-PE1<br/>IOS-XRv 6.1.3<br/>(L3VPN PE)"]
        P["Aurora-P / MEL-P<br/>IOS-XRv 6.1.3<br/>(right-side core handoff)"]
    end

    subgraph CEs["Customer Edge"]
        NW["Northwind CE<br/>FortiGate 7.0.14<br/>(CE + FortiSD-WAN + NGFW)"]
        HLAN["Helix LAN switch<br/>Aruba CX 10.16.1040<br/>(local access practice)"]
        SPARE["region-a-ce-spare<br/>IOSv 15.7<br/>(optional, on-demand)"]
    end

    subgraph RegionBPOPs["Region B POPs (PC1 / DevNet CML planned)"]
        BNE["BNE-PE1 / Aurora-PE-2<br/>IOL/IOS-XE target<br/>(Brisbane edge)"]
        SYD["SYD-PE1 / Aurora-PE-3<br/>IOS-XRv<br/>(ROV + Region B/C edge)"]
    end

    subgraph PlannedPOPs["Planned national POP expansion"]
        PER["PER-PE1<br/>Perth / WA POP<br/>(reserved)"]
        DRW["DRW-PE1<br/>Darwin remote POP<br/>(reserved)"]
        HBA["HBA-PE1 / TAS-PE1<br/>Tasmania / Hobart POP<br/>(reserved)"]
    end

    subgraph WL["Tenant workloads"]
        HORTH["helix-orthanc · DICOM"]
        HEMR["helix-emr · nginx"]
        HDOC["helix-doctor-wks"]
        NSAAS["northwind-saas · nginx"]
        NREDIS["northwind-redis"]
        NPROM["northwind-prometheus"]
        NGRAF["northwind-grafana"]
        NDEV["northwind-dev-wks"]
    end

    %% Internet edge sessions
    TA -->|eBGP transit<br/>default + Internet prefixes| PE1
    TB -->|local backup transit<br/>10.255.2.4/30| ADL
    PE1 ---|IXP port| IXF
    SYD -.->|IXP/FRR docker offload later| IXF
    RS --- IXF
    CON --- IXF
    EYE --- IXF
    CON -.->|advertise| RS
    EYE -.->|advertise| RS
    RS -.->|RS-reflected<br/>peer routes| PE1
    RS -.->|RS-reflected<br/>peer routes| SYD
    RPKI -.->|RPKI-RTR VRPs<br/>(ROV enforce)| SYD

    %% IS-IS / LDP backbone, drawn west-to-east
    ADL ---|Dell/PC2 regional line| GEL
    GEL ---|Dell/PC2 regional line| PE1
    PE1 ---|IS-IS L2 + LDP| P
    P -.->|logical PC1 / Region B transport handoff| SYD
    PE1 -.->|inter-region eBGP 64496↔65002<br/>ASBR border → Region B DC-P-R1| SYD

    %% iBGP full mesh (overlay)
    PE1 -.->|iBGP VPNv4| GEL
    GEL -.->|iBGP VPNv4| ADL
    PE1 -.->|iBGP VPNv4| ADL
    ADL -.->|planned west path| PER
    BNE -.->|planned north path| DRW
    SYD -.->|planned island path| HBA

    %% PE-CE
    NW -->|eBGP CE-PE<br/>+ FortiSD-WAN| PE1
    HLAN ---|local access lab| GEL
    SPARE -->|optional eBGP CE-PE| ADL

    %% Workloads
    NSAAS -.-> NW
    NREDIS -.-> NW
    NPROM -.-> NW
    NGRAF -.-> NW
    NDEV -.-> NW
    HORTH -.-> HLAN
    HEMR -.-> HLAN
    HDOC -.-> HLAN

    class P cisco_iol
    class PE1,GEL,ADL cisco_iol
    class SYD cisco_xr
    class BNE cisco_iol
    class SPARE cisco_xe
    class NW fortinet
    class HLAN aruba
    class HORTH,HEMR,HDOC,NSAAS,NREDIS,NPROM,NGRAF,NDEV workload
    class TA,TB transit
    class RS,CON,EYE,IXF ixp
    class RPKI mgmt
    class PER,DRW,HBA planned
```

### 3.2 Internet Edge (simulated external Internet)

The Internet Edge sits **north of Aurora AS 64496** and is entirely simulated — **documentation ASNs** (RFC 5398), **documentation prefixes** (RFC 5737 IPv4 / RFC 3849 IPv6), and **lab RPKI** (SLURM-minted VRPs, not real ROAs). Nothing is ever advertised to the real Internet. The local dual-transit edge gives Region A a self-contained "talks to the world" story that does **not** depend on Region B / DevNet or Region C / cloud being up; the FRR IXP and tenant workload proof can be added later from the Region B/PC1 Docker offload.

```text
                        Simulated Internet
                               |
            +------------------+------------------+
            |                                     |
     transit-a-csr  AS 64497            transit-b-iol  AS 64498
     (CSR1000v, primary)                 (IOL-XE, backup)
            |                                     |
       Aurora-PE-1 (IOS-XRv)              ADL-PE1 (IOS-XRv)
            \                              local backup edge
             \           eBGP transit      (RTR from rpki-rp1)
              +--------- Aurora AS 64496 --------+
              |                                  |
            (IXP port)                  (Transit-B backup)
              \                                  /
               +--------- ixp-fabric ----------+        (L2 IXP LAN, AS-less)
                   |          |          |
                ixp-rs1   ixp-content1  ixp-eyeball1
                AS 64499    AS 64500     AS 64501
                (route      (CDN)        (eyeball ISP)
                 server)

   rpki-rp1 (Routinator on PC1) -> RPKI-RTR :3323 -> SYD-PE1 in Region B (+ local IOL ingress later)
```

**Originated prefixes** — IPv4 strictly carved from the three RFC 5737 /24s (so distinct "Internet" prefixes are /28 slices); IPv6 from `2001:db8::/32` (RFC 3849, no scarcity):

| Originator | IPv4 (RFC 5737) | IPv6 (RFC 3849) | Represents |
| --- | --- | --- | --- |
| `transit-a-csr` (AS 64497) | `0.0.0.0/0` default + 8 mock Internet /28s from `192.0.2.0/24` | `::/0` default + `2001:db8:a::/48` sample | global default + "the Internet" sample |
| `transit-b-iol` (AS 64498) | `0.0.0.0/0` default (**lower LOCAL_PREF on Aurora**) + same `192.0.2.0/24` /28s | `::/0` default (backup) + same | local backup default on `ADL-PE1`; failover testable inside Region A |
| `ixp-content1` (AS 64500) | 3 CDN /28s from `198.51.100.0/25` | `2001:db8:c0::/48` | Cloudflare/Netflix-style content; Region B/PC1 Docker offload |
| `ixp-eyeball1` (AS 64501) | 5 eyeball /28s from `198.51.100.128/25` | `2001:db8:e0::/48` | TPG/Aussie-Broadband-style access ISP; Region B/PC1 Docker offload |
| Aurora (AS 64496) | mock PI `203.0.113.0/25` + customer aggregates | `2001:db8:aaaa::/48` | what Aurora advertises outward |
| Northwind/customer (AS 64502) | customer block from `203.0.113.128/25` | `2001:db8:bbbb::/48` | customer-originated prefix |

**Policy intent** (full config in §5.1; RPKI/ROV in §5.2): IXP content/eyeball preferred over transit; Transit-A default, Transit-B backup; Aurora advertises only its mock PI + approved customer prefixes outward; **no transit routes leak to IXP** (settlement-free peering hygiene); **RPKI-invalid routes rejected** at the edge; **max-prefix cap** per transit; **dual-stack** (v4 + v6 AFI/SAFI).

### 3.3 Physical mapping

- **GNS3 controller**: `http://192.168.137.1:3080/v2` (Dell-Windows host on the internet-carrying PC1/PC2 ethernet link). Project = `ops-lab` (`d8119db0-dd43-4d20-870d-9d62fd6345f1`).
- **GNS3 VM**: VMware Workstation appliance on Dell, Tailscale `gns3@100.118.0.46`, **2 physical vCPU / 19 GiB RAM** — the empirical constraint envelope per ADR-002 §3.9.
- **All local Region A router/firewall nodes run on `compute_id: "vm"`** (the GNS3 VM compute). Docker-dependent FRR IXP peers and tenant workload containers are Region B/PC1 offload candidates rather than Dell/PC2 GNS3 docker dependencies.
- **Dell/PC2 regional line**: the local link graph is `MEL-P <-> MEL-PE1 <-> GEL-PE1 <-> ADL-PE1`, and the live canvas is aligned geographically west-to-east as `ADL-PE1 -> GEL-PE1 -> MEL-PE1 -> MEL-P`. `MEL-P` deliberately sits to the right as the local core / **transport** handoff toward the PC1/Region B bridge. The **inter-region eBGP border / ASBR is `MEL-PE1`** (it terminates `64496 ↔ 65002` to Region B's `DC-P-R1`), not `MEL-P` and not `SYD-PE1`. `SYD-PE1` remains the IOS-XRv interop / ROV / Region B edge; `BNE-PE1` remains the Helix / Brisbane Region B PE.
- **Console-driven config**: the `iolcfg.py` socket helper on the GNS3 VM drives IOL/IOS-XR consoles (raw socket + telnet IAC; the VM's Python 3.14 has no `telnetlib`). Claude drives; the user verifies via the REST API (`memory/lab-coaching-workflow.md`).
- **Management plane** (Wazuh, MISP, Cowork, openconnect to DevNet) stays on **PC1** per ADR-002 §6.
- **Secure access model** follows ADR-004: `admin` is Elvis-owned break-glass; `aurora-codex` and `aurora-claude` are per-agent lab-node-only automation identities; PC1, PC2/Dell, DO, and Oracle host OSes are not routed lab nodes.
- **Ring model** is split: Tailscale carries the management ring between hosts, while virtual edge routers carry the lab data-plane ring over WireGuard and eBGP/IS-IS. Host OSes never become transit routers for lab traffic.
- **Containment rule**: lab nodes may reach documented services such as PC1 Routinator `192.168.137.1:3323`, but must not initiate SSH/RDP/SMB/WinRM/hypervisor/admin sessions to PC1, PC2, DO host, or Oracle host.

## 4. IP and AS plan (Region A slice)

> **Canonical source = THIS section** for Region A (Aurora carrier **AS 64496**, documentation ASNs/prefixes). `docs/ip-plan.md` is now the cross-region addressing index and mirrors this section at summary level.

| Node | Loopback (Lo0) | Mgmt | Role |
| --- | --- | --- | --- |
| Aurora-P / MEL-P (IOS-XRv) | 10.0.0.1/32 | 10.255.191.11/24 | IS-IS L2 / LDP only (no BGP) |
| Aurora-PE-1 / MEL-PE1 (IOS-XRv) | 10.0.0.2/32 | 10.255.191.12/24 | iBGP full-mesh VPNv4 PE; Northwind CE; Transit-A + logical Melbourne IXP attachment |
| GEL-PE1 (IOS-XRv) | 10.0.0.5/32 | 10.255.191.15/24 | Dell/PC2 regional-line midpoint between ADL and MEL-PE1 |
| ADL-PE1 (IOS-XRv) | 10.0.0.6/32 | 10.255.191.17/24 | Dell/PC2 regional-line endpoint |
| Northwind CE (FortiGate) | 10.0.1.1/32 | DHCP from PE-1 link | eBGP to PE-1, **AS 64512 (private customer AS — default model)** |
| Spare CE (IOSv, optional) | 10.0.1.2/32 | DHCP from ADL link | optional eBGP to ADL-PE1, AS 64513 (or AS 64502 in the BYO-AS scenario) |
| Helix LAN switch (Aruba CX) | n/a (L2) | 10.255.191.16/24 | Local access-switching practice; Region B owns the Brisbane PE attachment |

**Northwind / customer AS model:**
- **Default — private customer CE (AS 64512).** Northwind's FortiGate CE peers eBGP to PE-1 as private **AS 64512**; **Aurora (AS 64496) originates/aggregates the customer's public block** (`203.0.113.128/25`) on PE-1. The customer has *no public BGP presence* — the common MSP model. Exercises `remove-private-as`, provider-originated PI/PA space, customer route filtering, FortiGate NAT/security.
- **Optional — BYO-AS public customer (AS 64502).** A customer that brings its own ASN/prefix and originates it, with Aurora as transit. Stand up on the spare IOSv CE. Exercises customer prefix-lists, max-prefix, **RPKI origin validation of the customer origin**, no-transit-leak.

**Internet Edge AS / addressing** — all ASNs **RFC 5398 documentation ASNs** (64496–64511); all prefixes **RFC 5737 / RFC 3849 documentation space**.

| Node | AS | Originated prefixes | Peering |
| --- | --- | --- | --- |
| Aurora (carrier) | **64496** | PI `203.0.113.0/25` + `2001:db8:aaaa::/48` + customer aggregates | originates outward to both transits + IXP |
| `transit-a-csr` | **64497** | `0.0.0.0/0` + `::/0` + 8 mock Internet /28s (`192.0.2.0/24`) + `2001:db8:a::/48` | eBGP to Aurora-PE-1 |
| `transit-b-iol` | **64498** | `0.0.0.0/0` + `::/0` (backup) + same mock Internet prefixes | local Region A eBGP to `ADL-PE1` |
| `ixp-rs1` (route server) | **64499** | none (RS reflects only, next-hop preserved) | Region B/PC1 Docker offload; multilateral eBGP to PE-1/content/eyeball when bridged |
| `ixp-content1` | **64500** | 3 CDN /28s (`198.51.100.0/25`) + `2001:db8:c0::/48` | Region B/PC1 Docker offload; eBGP to RS |
| `ixp-eyeball1` | **64501** | 5 eyeball /28s (`198.51.100.128/25`) + `2001:db8:e0::/48` | Region B/PC1 Docker offload; eBGP to RS |
| Northwind/customer (**optional** BYO-AS) | **64502** | customer block (`203.0.113.128/25`) + `2001:db8:bbbb::/48`, **self-originated** | eBGP (BYO-AS scenario only) |
| Northwind CE (**default**) | 64512 (private) | — (Aurora originates `203.0.113.128/25` on its behalf) | eBGP to PE-1; `remove-private-as` outbound |

Backbone p2p links: `10.255.0.0/24` /31s (IPv4) + `2001:db8:ffff::/64`-derived /127s (IPv6) — `MEL-P ↔ MEL-PE1` = `10.255.0.0/31`, `MEL-PE1 ↔ GEL-PE1` = `10.255.0.6/31`, `GEL-PE1 ↔ ADL-PE1` = `10.255.0.8/31`. Draw and label the line west-to-east as `ADL -> GEL -> MEL-PE1 -> MEL-P`; `MEL-P` is the right-side logical handoff toward PC1/Region B `SYD-PE1`. `10.255.0.2/31` and `10.255.0.4/31` are no longer local BNE/SYD links; reserve or reassign them during the Region B CML build.

> **Build reconcile (2026-06-14):** the initial bring-up sketch used `10.1.1.0/30` for P↔PE-1 — **superseded by this canonical `10.255.0.0/31`**. The running config is aligned to §4, not the sketch.

PE-CE links: `10.255.1.0/24` /30s + matching v6 /127s.

Internet-edge links (dual-stack):
- PE-1 ↔ Transit-A: `10.255.2.0/30` + `2001:db8:ffff:2::/127`
- ADL-PE1 ↔ Transit-B: `10.255.2.4/30` + `2001:db8:ffff:2::2/127`
- IXP peering LAN (`ixp-fabric`): `10.255.3.0/24` — PE-1 `.1`, future SYD-PE1 `.3`, RS `.10`, content `.20`, eyeball `.30`; FRR peers can be hosted in Region B/PC1 Docker; v6 `2001:db8:ffff:3::/64`.

**RPKI-RTR cache endpoint = `192.168.137.1:3323` (PC1), used everywhere.**

Aurora mock public/PI block: `203.0.113.0/25` (TEST-NET-3). Customer block `203.0.113.128/25`.

**VRF RD/RT convention** (Cisco term; replaces the Nokia "VPRN"): RD = `64496:<customer_id>`, RT = `64496:<customer_id>`. Customer IDs: Northwind 3, Helix 2, Maple Ridge 1. **L3VPN validation VRF `CUST-A` = `64496:100`** (a reserved test id, not a tenant).

## 5. Protocols

| Layer | Choice | Notes |
| --- | --- | --- |
| IGP | **IS-IS L2 wide-metrics** | Single area; `metric-style wide`; loopbacks announced into IS-IS for LDP and BGP next-hop reachability. |
| Label distribution | **LDP** (not SR-MPLS) | LDP transport = Lo0 (`mpls ldp router-id Loopback0 force`). SR-MPLS is a later iteration. |
| Backbone overlay | **iBGP full mesh** among MEL-PE1, GEL-PE1, and ADL-PE1 (3 sessions) | **Two address-families: `vpnv4 unicast` (L3VPN) + `ipv4 unicast` (global Internet table), with `next-hop-self` on the edge PEs.** The `ipv4 unicast` AF is **required** so the transit default propagates between PEs (§5.1a). No RR at this size. On IOS-XR each AF is enabled explicitly per neighbor (there is no `no bgp default ipv4-unicast`). |
| PE-CE | **eBGP** (Northwind, optional spare CE); **local access VLAN practice** (Helix LAN) | eBGP keepalive 30 / holdtime 90 (default). |
| Internet edge | **eBGP** to transits (global table) + **eBGP** to IXP route server | Default route from transits; IXP for specific peer prefixes. Policy §5.1; RPKI/ROV §5.2. |
| L3VPN | **VRF + MP-BGP VPNv4** | Validation VRF `CUST-A` (§5.3); tenant VRFs Northwind (MEL-PE1) and later Region B Helix/BNE. |
| Authentication | **None in v2.5** | TCP-AO / MD5 deferred per ADR-002 §9.6. |
| Address family | **IPv4 + IPv6 dual-stack** | Both AFI/SAFI on backbone, PE-CE, Internet edge. Build Phase B layers v6 after v4. |
| RPKI / ROV | **Routinator (RP) + SLURM lab VRPs + RPKI-RTR; ROV-enforce at the edge** | Enforced from **C1 on both transit sessions (Transit-A@MEL-PE1, Transit-B@ADL-PE1)** + Region B `SYD-PE1` — all IOS-XRv. §5.2. |
| Tenant services | **VRF per tenant** on each PE that hosts the tenant | Northwind VRF on MEL-PE1; Helix moves with BNE-PE1 in Region B. |

### 5.1 Internet-edge BGP policy

Applied on MEL-PE1 (Transit-A + logical IXP attachment) and ADL-PE1 (Transit-B); IOS-XR ROV still starts later on Region B SYD-PE1:

| Rule | Mechanism | Demonstrates |
| --- | --- | --- |
| **Prefer IXP routes** for content/eyeball prefixes | LOCAL_PREF 300 on IXP-learned prefixes | "peer where you can, transit where you must" |
| **Transit-A is primary default** | LOCAL_PREF 200 on Transit-A `0.0.0.0/0` | primary/backup transit selection |
| **Transit-B is backup default** | LOCAL_PREF 100 on Transit-B `0.0.0.0/0` | failover: kill Transit-A → Transit-B wins through ADL-PE1 |
| **Advertise outward only approved prefixes** | outbound prefix-list = Aurora mock PI + customer aggregates ONLY | no accidental transit |
| **No transit routes to IXP peers** | outbound filter on the IXP session drops transit-AS routes | settlement-free peering hygiene |
| **Max-prefix cap per transit** | `maximum-prefix` ~200 on each transit session | survive a misconfigured upstream |
| **Reject RPKI-invalid** at the edge | drop routes whose ROV state = Invalid (§5.2) | origin-hijack rejection |
| **Bogon / martian filter** | inbound prefix-list drops RFC1918, default-from-IXP, mock-PI from peers | edge hygiene |
| **Don't leak IXP→transit** | outbound filter on transit sessions drops IXP-peer routes | don't give transit your peers for free |

LOCAL_PREF hierarchy: **IXP (300) > Transit-A (200) > Transit-B (100)**. RPKI-Invalid routes are dropped *before* best-path runs.

#### 5.1a Transit default propagation (failover correctness — fixed 2026-06-24)

The primary/backup failover only works if **both** transit defaults can be compared in one
BGP RIB. The transit `0.0.0.0/0` is learned via eBGP into the **global IPv4-unicast** table,
but the backup (Transit-B) terminates on a *different* PE (ADL-PE1) than the primary
(Transit-A on MEL-PE1). A **VPNv4-only iBGP mesh therefore never carries the default between
PEs**, so LOCAL_PREF can never arbitrate and killing Transit-A leaves MEL-PE1 (and Northwind
behind it) with no default. Fix:

- Activate **`address-family ipv4 unicast` on every iBGP session** (in addition to `vpnv4
  unicast`), with **`next-hop-self`** on the transit-edge PEs (MEL-PE1, ADL-PE1) so the
  default's next-hop is a reachable loopback.
- Then MEL-PE1 also learns ADL-PE1's Transit-B default (LP 100) and vice-versa; on Transit-A
  shut, LOCAL_PREF elects Transit-B and the default reconverges via ADL-PE1.
- **Region B depends on this too:** the inter-region eBGP (64496↔65002) — terminated on the
  Region A ASBR / border `MEL-PE1` and the Region B ASBR (`DC-P-R1`) — re-advertises this
  global default to Region B, so Region B's Internet egress also requires
  the IPv4-unicast activation (mirrored in `ops/region-b-cml/addressing.md` §7).
- Keep tenant routes in `vpnv4`; the `ipv4 unicast` mesh carries **only** the default +
  Internet/mock-PI prefixes (outbound policy), not the full customer VRF tables.

> **IOS-XR (deployed PEs):** under `router bgp 64496` add `address-family ipv4 unicast` and,
> per iBGP neighbor, `address-family ipv4 unicast` + `next-hop-self`; **commit** (two-stage).
> XR has no `no bgp default ipv4-unicast` — address-families are explicit per neighbor.

### 5.2 RPKI / ROV (lab, via Routinator + SLURM)

Real route-origin-validation without paying an RIR. Build Phase C — after the IPv4+IPv6 BGP fabric (§6 Phases A/B) is converged.

| Component | Role | Node |
| --- | --- | --- |
| **Routinator** (NLnet Labs) | RPKI validator / Relying Party — produces VRPs, serves RPKI-RTR (RFC 8210, TCP 3323) | `rpki-rp1` (docker on **PC1**) |
| **SLURM** (RFC 8416) | local exceptions — `locallyAddedAssertions` mint VRPs for doc prefixes (no real ROAs exist) | config on `rpki-rp1` |
| **ROV enforcer** | router as RTR client — classifies Valid/Invalid/NotFound, applies policy | **Transit-A@MEL-PE1, Transit-B@ADL-PE1, and `SYD-PE1` (all IOS-XRv) — enforced together from Phase C1** |

**SLURM VRP set:**

| Prefix | Correct origin AS | Used to test |
| --- | --- | --- |
| `203.0.113.0/25` + `2001:db8:aaaa::/48` | 64496 (Aurora) | Valid |
| `198.51.100.0/25` + `2001:db8:c0::/48` | 64500 (content) | Valid; **forge from 64501 → Invalid** |
| `198.51.100.128/25` + `2001:db8:e0::/48` | 64501 (eyeball) | Valid |
| `192.0.2.0/24` slices | (intentionally **no** VRP) | NotFound |

**Enforcement is phased; design target = ROV at *every* eBGP ingress. Reordered 2026-06-24 so the real upstreams are validated from day one (the transit ingress is the point that matters most, not the last to be done):**
- **Phase C1 — transit ingress first.** Enforce ROV on **Transit-A@MEL-PE1 and Transit-B@ADL-PE1** alongside Region B `SYD-PE1`. All three PEs are IOS-XRv, which has mature RPKI-RTR + origin-validation (`router bgp` → `rpki server <addr>` + a `route-policy` matching `validation-state is invalid` → drop). Prove Valid/Invalid/NotFound **on the transit sessions**, not only on SYD-PE1.
- **Phase C2 — IXP ingress.** FRR reference enforcer for the IXP route-server side; FRR's `rpki` module is **confirmed present** (`librtr.so` in `frrouting/frr:latest`).
- **Phase C3 — sweep.** Confirm ROV on any remaining eBGP ingress — the optional BYO-AS customer (AS 64502) and the IXP content/eyeball sessions once the Docker offload is bridged.

> **Gap CLOSED (was HIGH).** The earlier ordering deferred local transit ingress to a final C3, leaving Transit-A@MEL-PE1 and Transit-B@ADL-PE1 accepting routes with no origin validation — directly contradicting the §5.1 "reject RPKI-invalid at the edge" rule. With C1 now enforcing on **both transit sessions from the start**, the production upstream ingress points validate origins from day one.

**Test matrix** (C1 — introduce the forged-Invalid on a **transit session** or SYD-PE1; it must be rejected at every enforcing ingress):

| State | Setup | Expected on enforcer |
| --- | --- | --- |
| **Valid** | content prefix originated by 64500 | accepted, normal best-path |
| **Invalid** | re-originate content prefix from `ixp-eyeball1` (64501) | **rejected** — does not win best-path |
| **NotFound** | `192.0.2.0/28` slice (no VRP) | accepted, marked NotFound, normal policy |

### 5.3 L3VPN validation (VRF CUST-A) — the first MPLS service proof

Before tenant VRFs, prove the MPLS-L3VPN data path end to end with a minimal test VRF on **two** PEs (needs >=2 PEs, so this runs once GEL-PE1 is up):

- **VRF** `CUST-A`, `rd 64496:100`, `route-target import/export 64496:100`, on MEL-PE1 and GEL-PE1.
- A test interface (or `Loopback100`) in `CUST-A` on each: MEL-PE1 `172.16.100.1/32`, GEL-PE1 `172.16.100.2/32`; `redistribute connected` into `address-family ipv4 vrf CUST-A`.
- **Proof:** `show bgp vpnv4 unicast all` on each PE shows the *other* PE's VRF prefix with a VPN label; `ping vrf CUST-A 172.16.100.2 source 172.16.100.1` from MEL-PE1 succeeds — traffic rides LDP transport + the VPNv4 service label across the local line. This is the canonical "L3VPN works" gate (§7) before any tenant service is wired.

### 5.4 Transit-edge hardening (per Transit-A / Transit-B session)

Transit-scoped requirements — **not** the blanket "auth deferred" of §9. Apply to both eBGP
sessions (to transit-a-csr AS 64497 and transit-b-iol AS 64498):

| Control | Setting | Why |
| --- | --- | --- |
| **Session auth** | **TCP-AO** key-chain (MD5 only if a peer lacks AO) | resist TCP-RST injection / session hijack at the upstream border |
| **Fast failover** | **single-hop BFD** (~300 ms × 3) + BGP `fall-over bfd` | detect a dead transit in <1 s vs the 90 s holdtime — §5.1a failover is only as fast as detection |
| **Spoof protection** | **GTSM** `ttl-security hops 1` | drop spoofed multi-hop packets at the eBGP border |
| **Patch resilience** | **BGP graceful-restart** | forwarding continues while a transit restarts during a patch window (§8.8) |
| **Prefix safety** | **`maximum-prefix`** IPv4 **1000** (warn 75%, restart 5 min), IPv6 **200** (warn 75%); IXP sessions warning-only | survive a misconfigured/leaking upstream without a hard drop |
| **Origin validation** | RPKI ROV from Phase **C1** (drop `invalid`) — §5.2 | reject origin hijacks at the real upstream ingress |
| **Inbound sanitation** | full bogon/martian (**separate v4 and v6 lists**), RFC 8212 **default-deny** policy, AS-path sanity (drop private ASN in path, length cap), reject default/mock-PI from peers | edge hygiene; no implicit accept |
| **Visibility** | **`log neighbor-changes`** + syslog → PC1 (Wazuh); prefix-count + max-prefix-threshold alarms | every failover/leak yields operational evidence (the ops-plan deliverable) |
| **Dual-stack parity** | mirror **all** of the above + the §5.1 LOCAL_PREF / no-leak policy for `::/0` and the v6 doc prefixes | v6 must not be a soft underbelly |

IOS-XR (deployed PEs): TCP-AO via `key chain` + neighbor `ao`; BFD via `bfd
minimum-interval`/`multiplier` + neighbor `bfd fast-detect`; GTSM via `ttl-security`; GR via
`bgp graceful-restart`; ROV via `rpki server` + `route-policy … validation-state is invalid →
drop`. The transit nodes themselves (IOS-XE CSR1000v / IOL-XE) use the IOS-XE equivalents.

## 6. Bring-up procedure (staggered waves per ADR-002 §3.9.4)

Cold-starting all ~13 nodes simultaneously spikes the GNS3 VM load. Each wave waits for the previous wave's protocols to converge.

> **Build phasing (distinct from cold-start waves).** *Waves* = power order each time. *Phases* = capability build order the first time:
> - **Phase A — IPv4 fabric**: backbone IS-IS/LDP, iBGP VPNv4, **L3VPN VRF CUST-A proof (§5.3)**, eBGP CE, eBGP transit + IXP, LOCAL_PREF policy.
> - **Phase B — IPv6 dual-stack**: add v6 AFI/SAFI everywhere; mirror policy.
> - **Phase C — RPKI/ROV**: Routinator + SLURM on PC1; point Region B `SYD-PE1` / `Aurora-PE-3` at RTR; run the matrix (§5.2).

### Wave 1 — Backbone IS-IS/LDP core (~3 min)  ← in progress

Nodes: `Aurora-P`, `Aurora-PE-1`, `GEL-PE1`.

```
POST /v2/projects/{ops-lab}/nodes/{Aurora-P}/start
POST /v2/projects/{ops-lab}/nodes/{Aurora-PE-1}/start
POST /v2/projects/{ops-lab}/nodes/{GEL-PE1}/start
```

**Wait until** all three reach the IOL enable prompt (~20–30 s), then configure (IS-IS L2 + LDP) and verify:

- Aurora-PE-1: `show isis neighbors` → adjacency to `Aurora-P` and `GEL-PE1` Up; `show mpls ldp neighbor` → sessions Operational; `show mpls ldp bindings` → labels exchanged.
- GEL-PE1: adjacency to `MEL-PE1` Up; LDP session Operational.
- Aurora-P: `show isis neighbors` → MEL-PE1 listed; `show mpls ldp neighbor` → session Operational.

### Wave 2 — Adelaide regional PE (~3 min)

Nodes: `ADL-PE1` (IOS-XRv). (Optional `region-a-ce-spare` IOSv is on-demand.)

```
POST /v2/projects/{ops-lab}/nodes/{ADL-PE1}/start
```

**Wait until** IOL reaches the enable prompt, then:

- ADL-PE1: `show isis neighbors` → adjacency to GEL-PE1 Up; `show mpls ldp neighbor` → GEL session Operational; `show bgp vpnv4 unicast all summary` → local IOL PEs Established.

### Wave 3 — Customer-facing (~3 min)

Nodes: `northwind-ce` (FortiGate), `helix-lan-sw` (Aruba CX).

```
POST /v2/projects/{ops-lab}/nodes/{northwind-ce}/start
POST /v2/projects/{ops-lab}/nodes/{helix-lan-sw}/start
```

**Verify:**
- FortiGate: `get router info bgp summary` → eBGP to PE-1 Established.
- Aruba CX: `show vlan` → VLANs 100/200 present; `show lldp neighbor-info` → uplink visible.
- PE-1: `show bgp vpnv4 unicast vrf NORTHWIND summary` → Northwind CE Established, prefixes received.
- Region B BNE-PE1: owns Helix PE service when built; local Aruba remains an access-switching practice node.

### Wave 3.5 — Local Transit Edge (~3 min)

Nodes: `transit-a-csr`, `transit-b-iol`, and optionally `ixp-fabric` (switch — instant). FRR IXP peers (`ixp-rs1`, `ixp-content1`, `ixp-eyeball1`) are Region B/PC1 Docker offload nodes and should not be required for the local Region A transit failover gate.

```
POST /v2/projects/{ops-lab}/nodes/{ixp-fabric}/start
POST /v2/projects/{ops-lab}/nodes/{transit-a-csr}/start
POST /v2/projects/{ops-lab}/nodes/{transit-b-iol}/start
```

**Verify:**
  (PE side = **IOS-XR** `show route`/`show bgp`; transit side = IOS-XE on the CSR/IOL-XE)
- MEL-PE1 (XR): `show bgp ipv4 unicast neighbors 10.255.2.1` → Transit-A Established; `show route 0.0.0.0/0` → default via Transit-A (LP 200).
- ADL-PE1 (XR): `show bgp ipv4 unicast neighbors 10.255.2.5` → Transit-B Established; `show route 0.0.0.0/0` → its Transit-B default (LP 100).
- **iBGP propagation (the §5.1a fix):** on MEL-PE1 `show bgp ipv4 unicast 0.0.0.0/0` shows **both** the local Transit-A default (LP 200) **and** ADL-PE1's Transit-B default (LP 100, learned via iBGP, next-hop = ADL Lo0). If only one appears, the `ipv4 unicast` AF / `next-hop-self` is missing.
- **Transit failover:** shut Transit-A on MEL-PE1 → `show route 0.0.0.0/0` on MEL-PE1 reconverges to Transit-B via ADL-PE1 (and the Region B ASBR still holds a default over the inter-region eBGP).
- IXP route-server proof waits for the Region B/PC1 Docker offload (`ixp-rs1`, `ixp-content1`, `ixp-eyeball1`).

### Wave 4 — Tenant workload containers (Region B/PC1 offload)

```
# Run from the Region B/PC1 Docker host once that offload target exists.
docker compose -f region-a-workloads.yml up -d
```

Verify `docker ps` → 8 Running on the Region B/PC1 Docker host; `iperf3`/`curl` between workloads succeed once the Region B attachment is bridged into the lab.

### Total fabric verification (end of cold start)

- All backbone nodes: expected IS-IS adjacencies + LDP sessions.
- iBGP VPNv4 mesh: 3 sessions Established.
- **L3VPN VRF CUST-A proof passes (§5.3).**
- eBGP CE Established (Northwind; spare if started).
- Tenant VRFs (Northwind@MEL-PE1; Helix later in Region B) show route counts > 0 when built.
- Transit-A and Transit-B Established locally; default present (A primary, B backup).
- IXP route-server sessions and tenant workload reachability wait for Region B/PC1 Docker offload.
- ICMP from a tenant workload to a mock Internet /28 succeeds once Region B/PC1 workloads are attached; local transit egress is proven first from PE/CE nodes.

## 7. Smoke tests (per-node)

| Node | Command | Expected |
| --- | --- | --- |
| Aurora-P (IOS-XR) | `show isis adjacency` | MEL-PE1 adjacency Up |
| Aurora-P (IOS-XR) | `show mpls ldp neighbor` | MEL-PE1 LDP session Operational |
| MEL-PE1/GEL-PE1/ADL-PE1 (IOS-XR) | `show isis adjacency` / `show mpls ldp neighbor` | Local line adjacencies + LDP Up |
| MEL-PE1/GEL-PE1/ADL-PE1 (IOS-XR) | `show bgp vpnv4 unicast summary` + `show bgp ipv4 unicast summary` | iBGP neighbours Established (both AFs); VPNv4 prefixes > 0 and the default present in ipv4-unicast |
| **L3VPN proof (PE-1)** | `ping vrf CUST-A 172.16.100.2 source 172.16.100.1` | success — VPNv4 + LDP label path across P |
| Region B SYD-PE1 (IOS-XR) | `show isis adjacency` / `show bgp vpnv4 unicast summary` | Region B edge Up once CML topology is built |
| Northwind CE (FortiGate) | `get router info bgp summary` | eBGP to PE-1 Established |
| Spare CE (IOSv, if up) | `show ip bgp summary` | eBGP to ADL-PE1 Established |
| Helix LAN (Aruba CX) | `show vlan` / `show lldp neighbor-info` | VLAN 100/200 active; uplink LLDP visible |
| Transit-A (PE-1 view) | `show bgp ipv4 unicast neighbors 10.255.2.1` | Established; `0.0.0.0/0` received, LOCAL_PREF 200 |
| Transit-B (ADL-PE1 view) | `show bgp ipv4 unicast neighbors 10.255.2.5` | Established; `0.0.0.0/0` received, LOCAL_PREF 100 |
| IXP route server (`ixp-rs1`) | `vtysh -c "show bgp summary"` on Region B/PC1 Docker host | 4 neighbours Established once offload is built |
| IXP route preference (PE-1) | `show route 198.51.100.0` | next-hop via `ixp-fabric` / RS once offload is built (LOCAL_PREF 300) |
| Transit failover | shut Transit-A on PE-1 → `show route 0.0.0.0/0` | default reconverges to Transit-B via ADL-PE1 (needs §5.1a ipv4-unicast iBGP) |
| Egress reachability | from a CE or attached tenant workload: `ping <mock Internet /28 .1>` | succeeds via Transit-A, then via Transit-B during failover |
| IPv6 dual-stack (SYD-PE1 in Region B) | `show bgp ipv6 unicast summary` / `ping6 2001:db8:a::1` | v6 sessions Established; v6 egress works |
| Routinator (`rpki-rp1`) | `routinator vrps \| wc -l` | VRP count > 0 |
| RTR session (SYD-PE1) | `show rpki server` (IOS-XR) | cache `192.168.137.1:3323` ACTIVE; records loaded |
| ROV Valid / Invalid / NotFound | per §5.2 matrix | valid installed; invalid rejected; not-found accepted |

## 8. Operations

### 8.1 Daily verify (no changes)

```
curl http://192.168.137.1:3080/v2/projects/{ops-lab}/nodes | jq '.[] | {name, status}'
# All nodes "started"; then run §7 smoke (~5 min)
```

### 8.2 Update a node — no service impact (GEL-PE1 example)

Config-only change (no template/image change): SSH to the node. **IOS-XR PEs** (MEL-P, MEL-PE1, GEL-PE1, ADL-PE1): `configure` → edit → `commit` (two-stage, durable — **no `write memory`** on XR). **IOS-XE transits** (transit-a-csr, transit-b-iol): `conf t` → edit → `end` → `write memory`. Then §7 smoke for that node. iBGP and IS-IS absorb the change; no restart.

### 8.3 Update a node — with service impact (PE-1 example, template/NOS change)

1. Drain traffic (Northwind CE BGP holdtime → 30 s, or shut the CE-PE link).
2. Stop PE-1 via the GNS3 API.
3. Update template / image; PUT node properties.
4. Start PE-1; wait for IS-IS, LDP, iBGP, eBGP to reconverge.
5. Restore traffic; §7 smoke on PE-1 + Northwind CE.

Regional traffic continues over the remaining staged links where available. **This is the MOP shape for the Telstra patching practice** — wrap each such change in the operational-evidence template (`telstra-ops-practice-plan.md`).

### 8.4 Cold shutdown (reverse-wave order)

Wave 4 → 3.5 → 3 → 2 → 1. Stop nodes, wait for `stopped`, then next wave. If any node shows stale "started", close+reopen the project (`memory/gns3-vm-ram-budget.md`).

### 8.5 Cold start

Forward-wave order per §6. Do not skip the convergence gates.

### 8.6 Bringing up a singleton heavyweight (FTDv / Cat9kv / FMC / XRv9k / PA-VM 11)

**Region A must be down.** §8.4 first, then start the singleton solo. See `memory/gns3-nos-boot-quirks.md`.

### 8.7 Persistence

- GNS3 saves project + node state to `/opt/gns3/projects/<ops-lab>/`.
- IOL nodes persist startup-config in their NVRAM file; QEMU disks persist across stop/start.
- **Backup target**: rsync `/opt/gns3/projects/<ops-lab>/` to Dell `E:\aurora-backups\` after major changes; per-node config files (§10) are the source of truth.

### 8.8 Transit-node patching (CSR1000v / IOL-XE — IOS-XE upgrade under failover)

The transit nodes are the lab's IOS-XE patch targets (`telstra-ops-practice-plan.md` Day-1).
Patch **one transit at a time** under the primary/backup design so Internet egress never drops.
Full MOP: `ops/access/mops/2026-06-24-region-a-transit-patching.md`. Shape:

1. PSIRT / upgrade-path check for the target version; stage the image; verify md5.
2. **Drain** the transit being patched (shut its eBGP or raise holdtime) → confirm the default
   moves to the other transit (**requires §5.1a failover working first**).
3. Upgrade in **install mode**; reload; verify version.
4. Restore the session; confirm eBGP Established, default at the correct LOCAL_PREF, ROV active, BFD up.
5. §7 smoke; capture operational evidence; then repeat for the other transit.

## 9. What's NOT in v2.5 (deferred / out of scope)

- **Singleton heavyweights** (FTDv, Cat9kv, FMC, XRv9000, PA-VM 11). On-demand per §8.6; never in the running fabric.
- **Region B (DevNet CML)** — Cisco **+ Juniper** (vSRX/vJunos via BYOI). ADR-002 §3.2 + ADR-003 §2.3–2.4.
- **Region C (cloud edge)** — DigitalOcean containerlab (cRPD + FRR + Routinator + public-IP route-server). ADR-003 §2.4.
- **Inter-region BGP** (Region A ADL/GEL/MEL-PE1/MEL-P line -> Region B over openconnect-on-PC1; **`MEL-PE1` is the inter-region eBGP border / ASBR** — plain eBGP `64496↔65002`, global IPv4 unicast, Option A — terminating to Region B's `DC-P-R1`, with `MEL-P` as the local **transport** handoff). Later phase once Region B is up.
- **Authentication** (TCP-AO/MD5) on the **backbone/iBGP** sessions remains deferred per ADR-002 §9.6. **Exception: the transit eBGP sessions (Transit-A/Transit-B) get TCP-AO from the start** — see §5.4.
- **Maple Ridge workload containers** — live with the Region B Maple Ridge CE.
- **Local Nokia / Juniper PEs** — Nokia archived (ADR-003 §2.2); Juniper (vSRX/vJunos) is Region B + cloud, with **vSRX standalone-local** for practice only (not a Region A core node).
- **Real public ASNs / registered ROAs / advertising to the real Internet** — doc ASNs + SLURM lab VRPs only.

## 10. Open follow-ups

- **`region-a-cisco/clab-region-a.yml`** — author the GNS3 project export (canonical reproducible topology).
- **`region-a-cisco/configs/`** — per-node IOL/IOS-XR config templates; Jinja2 with the §4 inventory.
- **`region-a-cisco/ansible/`** — `make region-a-up` (wraps §6 waves), `make smoke` (§7), `make region-a-down` (§8.4).
- **Helix LAN mode-switch** when Region B comes up (local access-switching practice -> Region B BNE-PE1 service attachment).
- **Backup / restore drill** — verify §8.7 rsync + GNS3 project import round-trip.
- ✅ **Region A topology — code-generated** by `ops/region-a/diagrams/render_topology.py` → `docs/region-a-topology.svg` + `.png` (single programmatic source; legacy `.drawio`/`_v2.drawio`/`-screenshot.png` retired 2026-06-24; re-run after plan changes so SVG+PNG never drift).
- ✅ **IOL (IOU) on the Dell GNS3 VM — resolved** (`memory/gns3-nos-boot-quirks.md`); console via `iolcfg.py` socket helper.
- ✅ **FRR rpki module check — DONE** (`librtr.so` in `frrouting/frr:latest`); deployment target is now Region B/PC1 Docker offload instead of Dell/PC2 GNS3 docker.
- **RPKI/ROV build (Phase C)** — Routinator + SLURM on PC1; GNS3 Cloud node to `192.168.137.x`; RTR `192.168.137.1:3323`; C1 (Region B SYD-PE1) -> C3 (all ingress).
- ✅ **`ip-plan.md` v2.5 refresh — DONE** (cross-region index; Region A summary mirrors this §4 and retains the eight-POP national overlay).

## 11. References

- `docs/adr-003-revendor-cisco-region-a.md` — Region A vendor stack (Cisco), Juniper→B, three-region model, build-then-operate.
- `docs/adr-004-secure-rings-host-isolation.md` — management/data-plane rings, per-agent automation access, and host-isolation validation.
- `docs/adr-002-two-region.md` — §3.2 Region B, §3.9 Dell capability envelope + operational rules, §6 VPN endpoint (PC1).
- `docs/design.md` — protocol-level Aurora design (IS-IS, LDP, BGP VPNv4 conventions).
- `docs/ip-plan.md` — cross-region IP/AS/RD-RT index; Region A summary mirrors §4.
- `docs/telstra-ops-practice-plan.md` — the ops practice that layers on this build.
- `memory/gns3-nos-boot-quirks.md` — per-NOS boot recipes (IOL, FortiGate, Aruba CX; vJunos-can't-run-locally).
- `memory/gns3-vm-ram-budget.md` — RAM/CPU rules, OOM behaviour, stale-status recovery.
- `memory/lab-coaching-workflow.md` — Claude-drives / user-coaches console workflow.
- `memory/sros-gns3-license-recipe.md` — **archived** Nokia SR OS RTC-frozen license recipe (recoverable).

**Standards (Internet Edge / RPKI):** RFC 5398 (doc ASNs), RFC 6996 (private ASNs — customer only), RFC 5737 (IPv4 doc prefixes), RFC 3849 (IPv6 doc prefix), RFC 8210 (RPKI-RTR), RFC 8416 (SLURM). Routinator (NLnet Labs) — RPKI RP / validator with SLURM + built-in RTR.
