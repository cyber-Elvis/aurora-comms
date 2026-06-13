# Region A — Build and Operations Plan (v2.1)

| Field | Value |
| --- | --- |
| Status | Active (build in progress) |
| Version | 2.1 |
| Date | June 2026 |
| Scope | Steady-state Region A fabric on Dell GNS3 — four tiers: **P/core + PE + Customer Edge + Internet Edge** (simulated upstream transit + IXP peering + **lab RPKI/ROV** + **IPv4/IPv6 dual-stack**) + tenant workloads. Core is **MPLS L3VPN-capable** (VRF + VPNv4). Region A/B/C are deployment domains; the represented national POPs are **Melbourne, Sydney, Brisbane, and Geelong**. |
| Excludes | Singleton heavyweights (FTDv, Cat9kv, FMC, XRv9000, PA-VM 11), Region B (DevNet CML), Region C (cloud edge), inter-region BGP confederation, routing-protocol authentication (TCP-AO/MD5). **NOT excluded but explicitly lab-only:** ASNs are RFC 5398 *documentation* ASNs (not registered), prefixes are RFC 5737/3849 *documentation* space, RPKI uses local SLURM VRPs (not real RIR ROAs) — nothing is ever advertised to the real Internet. |
| Revision | **v2.1 restores the Australia-wide POP overlay** on top of the Cisco re-vendor: Melbourne, Sydney, Brisbane, and Geelong remain the carrier geography; Region A/B/C describe where the lab runs. v2.0 re-vendored the backbone from Nokia to Cisco per ADR-003 (Aurora-P + PE-1 + PE-2 = IOL-AdvEnterprise-L3; PE-3 = IOS-XRv 6.1.3 unchanged). The entire Internet-edge / IXP / RPKI-ROV / IP-AS / policy design is preserved — only the P/PE platform and its CLI changed. Nokia SR OS/SR Linux are **archived** (recipe + license cold-stored, recoverable via git history). VPRN → VRF terminology; SR OS `show router …` → IOS `show …`. Added the explicit **L3VPN validation (VRF CUST-A)** path. |
| Source of truth for design | **ADR-003** (Region A vendor stack — Cisco), ADR-002 §3.2–§3.9 (two-region structure, Dell capability envelope, operational rules) |
| Owner | Lab architecture (Elvis Ifeanyi Nwosu) |
| Related | `docs/adr-003-revendor-cisco-region-a.md`, `docs/adr-002-two-region.md`, `docs/design.md`, `docs/ip-plan.md`, `docs/runbook.md`, `memory/gns3-nos-boot-quirks.md`, `memory/gns3-vm-ram-budget.md`, `memory/lab-coaching-workflow.md` |

## 1. What this doc is

The **executable plan** companion to the ADRs. ADR-003 says *what the Region A vendor stack is and why* (Cisco); ADR-002 §3 says *what the two-region structure is*; this doc says *what to build, in what order, how to verify, and how to operate it*.

Region A's empirical capacity envelope (ADR-002 §3.9) is the constraint this plan respects: **7–8 protocol-light nodes run together stably on Dell GNS3 in steady state**, with headroom to add lights, and the rule that singleton heavyweights run **solo** with the fabric stopped. The Cisco re-vendor makes the backbone *lighter*, not heavier: **IOL-AdvEnterprise-L3 is ~0.5 GB idle each** (vs SR OS ~0.5 GB + SR Linux ~1 GB), so the whole four-tier fabric lands at **~7.5–8 GiB idle** — comfortably inside the proven envelope.

> **Build state (2026-06-14):** GNS3 project `ops-lab` (`d8119db0-…`). **Aurora-P + Aurora-PE-1 created, linked, booted** (IOL-L3, blank config, at enable prompt) and being configured now per §6 Wave 1. Console-driven config via the `iolcfg.py` socket helper on the GNS3 VM (see `memory/lab-coaching-workflow.md`).

### 1.1 National POP overlay

The old Melbourne/Sydney/Brisbane/Geelong concept is still the design. What changed is the vendor/platform underneath it. Treat **Region A/B/C as execution domains** and **MEL/SYD/BNE/GEL as carrier POPs**.

| POP | Active lab node(s) | Role in the carrier story |
| --- | --- | --- |
| Melbourne | `Aurora-P` (`MEL-P`) + `Aurora-PE-1` (`MEL-PE1`) | Core/transport hub, primary transit, Melbourne IXP, Northwind edge |
| Sydney | `Aurora-PE-3` (`SYD-PE1`) | Major interconnect, Region B/C handoff, Transit-B, first ROV enforcer |
| Brisbane | `Aurora-PE-2` (`BNE-PE1`) | Regional enterprise edge and Helix local services |
| Geelong | `region-a-ce-spare` now; target `Aurora-PE-4` (`GEL-PE1`) after the base core is stable | Regional access POP / smaller-enterprise edge / branch-failover scenarios |

Do **not** read Region A as "Melbourne only." Region A is the local Dell-hosted slice of the national carrier. The POP aliases are the topology story operators should use in tickets, diagrams, MOPs, and incident notes.

## 2. Inventory — four tiers plus tenant containers

Region A is a four-tier SP: **P/core → PE → Customer Edge → Internet Edge**, with tenant workload containers hanging off the customer edges. ~13 infrastructure nodes (1 P + 3 PE + 3 CE/LAN + 2 transit + 1 IXP fabric switch + 3 FRR IXP) plus 8 tenant workload containers. The FRR IXP nodes and tenant workloads are docker; the rest are QEMU/IOL except the L2 fabric switch.

### 2.1 Backbone (P + PE core) — Cisco (ADR-003)

| Role | POP alias | Node name | NOS | RAM (declared / idle RSS) | vCPU | Recipe ref |
| --- | --- | --- | --- | --- | --- | --- |
| Aurora-P (IS-IS L2 / LDP transit, no BGP) | `MEL-P` | `Aurora-P` | **Cisco IOL-AdvEnterprise-L3** | ram=1024 / ~0.5 GB | n/a | `memory/gns3-nos-boot-quirks.md` § IOL (IOU resolved); console via `iolcfg.py` |
| Aurora-PE-1 (L3VPN PE; Northwind CE + Transit-A + Melbourne IXP) | `MEL-PE1` | `Aurora-PE-1` | **Cisco IOL-AdvEnterprise-L3** | ram=1024 / ~0.5 GB | n/a | same; full MPLS L3VPN (VRF + VPNv4) |
| Aurora-PE-2 (L3VPN PE; Helix LAN VRF) | `BNE-PE1` | `Aurora-PE-2` | **Cisco IOL-AdvEnterprise-L3** | ram=1024 / ~0.5 GB | n/a | same |
| Aurora-PE-3 (interop PE; spare CE + Transit-B + IXP + future inter-region eBGP; ROV enforcer) | `SYD-PE1` | `Aurora-PE-3` | Cisco IOS-XRv 6.1.3 | 3 GB / ~1 GB | 1 | ide / qemu64 defaults; no special options |

> **Nokia archived (ADR-003 §2.2).** The previous core — Aurora-P on SR Linux 24.10 and Aurora-PE-1/PE-2 on licensed SR OS 13.0R4 — is **cold-stored, not deleted**. SR OS license qcow2 + RTC/UUID recipe live in three places (md5 recorded, `memory/sros-gns3-license-recipe.md`); the prior v1.2 of this plan is in git history. Nokia can return on a non-triple-nested host. **Why re-vendored:** the Telstra role is Cisco/Juniper-led; IOL-L3 is lighter, runs the full core together, supports full L3VPN, and is already working on this box.

### 2.2 Customer Edge

| Role | Node name | NOS | RAM (declared / idle RSS) | vCPU | Recipe ref |
| --- | --- | --- | --- | --- | --- |
| Northwind CE (consolidated CE + FortiSD-WAN + NGFW) | `northwind-ce` | Fortinet FortiGate-VM 7.0.14 | 1 GB / ~0.6 GB | 1 | ide + 30 GB blank `hdb` data disk |
| Helix LAN switch (customer-owned LAN behind PE-2) | `helix-lan-sw` | HPE Aruba CX 10.16.1040 | 4 GB / ~1.7 GB | 2 | `-nographic`; **30-day trial license unactivated — do not run `license` CLI until ready** |
| Geelong access / offline-fallback CE (optional, on-demand) | `region-a-ce-spare` | Cisco IOSv 15.7 | ~0.5 GB / ~0.4 GB | 1 | GEL placeholder; CE-only (IOSv is **not** used as a PE — weak MPLS). Promote to light `Aurora-PE-4` / `GEL-PE1` after the base core is stable if a full fourth PE is needed |

### 2.3 Internet Edge (simulated upstream transit + IXP peering + lab RPKI)

ASNs are **RFC 5398 documentation ASNs** (64496–64511); prefixes are **RFC 5737/3849 documentation space**. Aurora itself = **AS 64496** (the carrier). Northwind customer = **AS 64512 (private CE, default model)** or **AS 64502 (optional BYO-AS public customer)** — see §4.

| Role | Node name | NOS | AS | RAM (declared / idle RSS) | vCPU | Recipe ref |
| --- | --- | --- | --- | --- | --- | --- |
| Upstream Transit-A (primary) | `transit-a-csr` | Cisco CSR1000v 16.08.01 | 64497 | **3 GB** / ~2.5 GB | 1 | ide / qemu64; BGP-only role → 3 GB; RTR/ROV-capable |
| Upstream Transit-B (backup) | `transit-b-iol` | Cisco IOL-XE 17.15 | 64498 | ram=2048, nvram=1024 / ~0.5 GB | 1 | `memory/gns3-nos-boot-quirks.md` § IOL-XE (RAM fix); RTR/ROV-capable |
| IXP fabric (Melbourne IXP peering LAN) | `ixp-fabric` | GNS3 Ethernet switch (L2) | n/a | 0 | n/a | a built-in switch — IXPs are L2 fabrics |
| IXP route server | `ixp-rs1` | FRR (docker, `frrouting/frr:latest`) | 64499 | ~0.15 GB / ~0.1 GB | n/a | RS = next-hop-preserving; rpki module present (`librtr.so` — §10) |
| IXP content/CDN peer | `ixp-content1` | FRR (docker) | 64500 | ~0.15 GB / ~0.1 GB | n/a | originates mock CDN prefixes |
| IXP eyeball/ISP peer | `ixp-eyeball1` | FRR (docker) | 64501 | ~0.15 GB / ~0.1 GB | n/a | originates mock eyeball prefixes |
| RPKI validator / RP (Routinator) | `rpki-rp1` | Routinator (docker) | n/a | **on PC1, off the Dell budget** (~200 MB) | n/a | Phase C; SLURM local VRPs; serves RTR (TCP 3323) via a GNS3 Cloud node bridged to `192.168.200.x` |

### 2.4 Tenant workloads (Helix + Northwind — Maple Ridge workloads live in Region B)

`helix-orthanc` (DICOM), `helix-emr` (nginx mock), `helix-doctor-wks` (alpine+iperf3), `northwind-saas` (nginx), `northwind-redis`, `northwind-prometheus`, `northwind-grafana`, `northwind-dev-wks` (alpine+iperf3) — docker, ~1.5 GB / ~1 GB total, per ADR-002 §3.7.1.

### 2.5 Footprint

| Tier | Declared | Idle RSS (est.) |
| --- | --- | --- |
| Backbone (3× IOL-L3 + 1 IOS-XRv) | ~6 GB | ~2.5 GB |
| Customer Edge (FortiGate + Aruba CX; spare CE optional) | ~5 GB | ~2.7 GB |
| Internet Edge (CSR 3 + IOL 0.5 + 3× FRR 0.45 + fabric 0) | ~4 GB | ~2 GB |
| Tenant workloads (8 docker) | ~1.5 GB | ~1 GB |
| **Total core running fabric** | **~16.5 GB declared** | **~7.5–8 GiB actual idle** |

Comfortably inside the envelope (19 GiB GNS3 VM, ~17 GiB usable; qemu overcommit at idle means declared ≠ resident). **The all-IOL backbone freed ~1 GiB** vs the old SR Linux+SR OS core. The spare CE (`region-a-ce-spare`) is bring-up-on-demand and not counted in the core total.

### 2.6 Design choices noted explicitly (callable for review)

- **Backbone re-vendored to Cisco (ADR-003).** IOL-AdvEnterprise-L3 for P + PE-1 + PE-2: light (~0.5 GB), full MPLS **L3VPN** (VRF + VPNv4 + LDP labels), and IOU is resolved on this box. **All three PEs are L3VPN-capable** (IOL-L3 and IOS-XRv both do VRF/VPNv4); **IOSv is CE-only** (weak MPLS).
- **Aurora-PE-3 = IOS-XRv 6.1.3 (kept).** (a) XR is the carrier-grade Cisco OS — best SP narrative; (b) ADR-002 §3.2 runs IOS-XR 7.x in Region B, so 6.1.3 in Region A mirrors carriers running multiple XR generations; (c) it is the **first ROV enforcer** (mature RTR/ROV). The mixed IOS/IOS-XR backbone is also a deliberate **multi-OS Cisco** ops story (two CLIs, two upgrade workflows — directly relevant to the Telstra patching practice).
- **Why not the "9k" platforms for the P/PE core.** The binding constraint is that **P + 3 PEs run simultaneously** as a fabric on the 19 GB / 2-physical-core / no-swap GNS3 VM — which forces light nodes. The 9k-class boxes each fail on weight, role, or boot: **Catalyst 9000v** is a campus *switch* (~16–18 GB each → one nearly fills the VM, 4 impossible; wrong role for an SP PE; singleton-only with `-cpu host`); **Nexus 9300v** is a DC *switch* and **won't boot** on this triple-nested host (same wall as vJunos — deferred to Region B/CML); **XRv9000** is the *correct* role (carrier IOS-XR PE) but ~16 GB and **singleton-only** (`cpu_throttling=80`), so 4-at-once ≈ 64 GB is impossible. IOL-AdvEnterprise-L3 is the only option that is a full MPLS-L3VPN router (real IOS CLI/behaviour), **~0.5 GB each** (whole core runs at once with headroom), and already working here. **Carrier XR realism is still present** via the lighter **IOS-XRv 6.1.3** PE-3. The heavy 9k boxes are **on-demand singletons** (§8.6) for platform-specific drills and live in **Region B (CML, real non-nested infra)** for DC-fabric / newer-XR work — not in the always-on Region A fabric.
- **L3VPN validation VRF = `CUST-A` (rd/rt `64496:100`).** Before wiring the tenant VRFs, the first MPLS-L3VPN proof is a minimal `CUST-A` VRF on two PEs with test interfaces — confirms VPNv4 exchange + label imposition + cross-PE VRF ping end to end (§5.3, §7). The real tenant services then follow the per-tenant VRF convention (Northwind `64496:3`, Helix `64496:2`).
- **CSR1000v = Transit-A; IOL-XE = Transit-B.** CSR has the richest BGP/policy knobs of the light Cisco nodes (suits transit); IOL-XE covers backup transit. Spare-CE duty drops to **IOSv** (lighter, CE-only).
- **Two transits terminate on different PEs** (Transit-A on PE-1, Transit-B on PE-3). Realistic SP path diversity + an IOS-vs-IOS-XR BGP-policy demo in one lab.
- **IXP route server = FRR, not IOS/CSR.** FRR (and BIRD) are what real IXPs run; FRR gives proper route-server semantics (next-hop preservation, multilateral reflection) an IOS eBGP-with-next-hop-self only approximates.
- **Dual IXP attachment (PE-1 *and* PE-3 → `ixp-fabric`) is deliberate lab pedagogy** — kept to demo IX-uplink-failure → iBGP reconvergence. Called out so it's not mistaken for a real-world design.
- **iBGP topology = full mesh among 3 PEs** (3 sessions). Below the threshold where route reflection earns its complexity. Aurora-P (IOL-L3) does **not** run BGP — pure IS-IS/LDP transit.
- **Helix LAN connection model is mode-switched** (see §10): when Region B is up, Helix CE in Region B → GRE-over-IPSec → Aurora-PE-2 → Helix LAN switch (ADR-002 §3.1/§3.2). When Region B is down, the standalone model attaches Helix LAN directly to PE-2 via a local VRF so the box is useful.
- **Maple Ridge workloads are not in Region A.** Maple Ridge primary CE is Region B (Cat8000v in CML, ADR-002 §3.2).
- **Documentation ASNs (RFC 5398, 64496–64511), not private ASNs (RFC 6996).** Aurora = 64496; transits 64497/64498; IXP RS/content/eyeball 64499/64500/64501; customer 64502. (Private ASN 64512 is used only for the private-customer CE model.)
- **Lab RPKI/ROV via Routinator + SLURM, not real RIR ROAs.** `rpki-rp1` runs Routinator (validator / RP); SLURM (RFC 8416) `locallyAddedAssertions` mint VRPs for the documentation prefixes. Routers are the **ROV enforcers** (RTR clients) — validator ≠ enforcer. **First ROV enforcer = `Aurora-PE-3` (IOS-XRv 6.1.3)**; IOS (IOL-L3) and IOS-XR both support BGP origin-validation (RTR + route-map/route-policy `match rpki valid|invalid|not-found`), so the all-Cisco backbone makes ROV **uniform** across enforcers.
- **IPv4 + IPv6 dual-stack** at the edge. IPv6 from `2001:db8::/32` (RFC 3849); IPv4 mock prefixes are **sub-allocations of the three RFC 5737 /24s** (distinct "Internet" prefixes are /28 slices).
- **Routinator on PC1, off the Dell budget.** ~200 MB; reachability via a GNS3 Cloud node bridged to `192.168.200.x`, RTR on TCP 3323.

## 3. Topology

### 3.1 Logical topology

```mermaid
graph TB
    classDef cisco_iol fill:#1ba0d7,color:#fff,stroke:#0d6986
    classDef cisco_xr fill:#1565c0,color:#fff,stroke:#0d47a1
    classDef cisco_xe fill:#42a5f5,color:#fff,stroke:#1565c0
    classDef fortinet fill:#ee3124,color:#fff,stroke:#a61b13
    classDef aruba fill:#ff9800,color:#fff,stroke:#e65100
    classDef workload fill:#fdd835,color:#000,stroke:#f57f17
    classDef transit fill:#6a1b9a,color:#fff,stroke:#4a148c
    classDef ixp fill:#00897b,color:#fff,stroke:#00695c
    classDef mgmt fill:#455a64,color:#fff,stroke:#263238

    subgraph INet["🌐 Internet Edge (simulated, doc ASNs/prefixes)"]
        TA["transit-a-csr<br/>CSR1000v · AS 64497<br/>(primary transit)"]
        TB["transit-b-iol<br/>IOL-XE · AS 64498<br/>(backup transit)"]
        IXF(["ixp-fabric<br/>Melbourne IXP L2 LAN"])
        RS["ixp-rs1<br/>FRR · AS 64499<br/>(route server)"]
        CON["ixp-content1<br/>FRR · AS 64500<br/>(CDN/content)"]
        EYE["ixp-eyeball1<br/>FRR · AS 64501<br/>(eyeball ISP)"]
        RPKI["rpki-rp1 · Routinator<br/>(on PC1) → RTR :3323<br/>SLURM lab VRPs"]
    end

    subgraph Backbone["Aurora AS 64496 — Cisco P/PE core (IS-IS L2 + LDP, iBGP VPNv4 full mesh)"]
        P["Aurora-P / MEL-P<br/>IOL-AdvEnterprise-L3<br/>(IS-IS/LDP transit, no BGP)"]
        PE1["Aurora-PE-1 / MEL-PE1<br/>IOL-AdvEnterprise-L3<br/>(L3VPN PE)"]
        PE2["Aurora-PE-2 / BNE-PE1<br/>IOL-AdvEnterprise-L3<br/>(L3VPN PE)"]
        PE3["Aurora-PE-3 / SYD-PE1<br/>IOS-XRv 6.1.3<br/>(interop PE + ROV)"]
    end

    subgraph CEs["Customer Edge"]
        NW["Northwind CE<br/>FortiGate 7.0.14<br/>(CE + FortiSD-WAN + NGFW)"]
        HLAN["Helix LAN switch<br/>Aruba CX 10.16.1040"]
        SPARE["region-a-ce-spare / GEL access<br/>IOSv 15.7<br/>(optional, on-demand)"]
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
    TB -->|eBGP transit<br/>backup default| PE3
    PE1 ---|IXP port| IXF
    PE3 ---|IXP port<br/>(dual-attach = lab pedagogy)| IXF
    RS --- IXF
    CON --- IXF
    EYE --- IXF
    CON -.->|advertise| RS
    EYE -.->|advertise| RS
    RS -.->|RS-reflected<br/>peer routes| PE1
    RS -.->|RS-reflected<br/>peer routes| PE3
    RPKI -.->|RPKI-RTR VRPs<br/>(ROV enforce)| PE3

    %% IS-IS / LDP backbone
    PE1 ---|IS-IS L2 + LDP| P
    PE2 ---|IS-IS L2 + LDP| P
    PE3 ---|IS-IS L2 + LDP| P

    %% iBGP full mesh (overlay)
    PE1 -.->|iBGP VPNv4| PE2
    PE2 -.->|iBGP VPNv4| PE3
    PE1 -.->|iBGP VPNv4| PE3

    %% PE-CE
    NW -->|eBGP CE-PE<br/>+ FortiSD-WAN| PE1
    HLAN ---|VLAN trunk<br/>(local VRF)| PE2
    SPARE -->|eBGP CE-PE| PE3

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
    class PE1,PE2 cisco_iol
    class PE3 cisco_xr
    class SPARE cisco_xe
    class NW fortinet
    class HLAN aruba
    class HORTH,HEMR,HDOC,NSAAS,NREDIS,NPROM,NGRAF,NDEV workload
    class TA,TB transit
    class RS,CON,EYE,IXF ixp
    class RPKI mgmt
```

### 3.2 Internet Edge (simulated external Internet)

The Internet Edge sits **north of Aurora AS 64496** and is entirely simulated — **documentation ASNs** (RFC 5398), **documentation prefixes** (RFC 5737 IPv4 / RFC 3849 IPv6), and **lab RPKI** (SLURM-minted VRPs, not real ROAs). Nothing is ever advertised to the real Internet. It gives Region A a self-contained "talks to the world" story that does **not** depend on Region B / DevNet or Region C / cloud being up.

```text
                        Simulated Internet
                               |
            +------------------+------------------+
            |                                     |
     transit-a-csr  AS 64497            transit-b-iol  AS 64498
     (CSR1000v, primary)                 (IOL-XE, backup)
            |                                     |
       Aurora-PE-1 (IOL-L3)                 Aurora-PE-3 (IOS-XRv)
            \                                     /   ← first ROV enforcer
             \           eBGP transit            /       (RTR from rpki-rp1)
              +--------- Aurora AS 64496 --------+
              |                                  |
            (IXP port)                       (IXP port)
              \                                  /
               +--------- ixp-fabric ----------+        (L2 IXP LAN, AS-less)
                   |          |          |
                ixp-rs1   ixp-content1  ixp-eyeball1
                AS 64499    AS 64500     AS 64501
                (route      (CDN)        (eyeball ISP)
                 server)

   rpki-rp1 (Routinator on PC1) ── RPKI-RTR :3323 ──► Aurora-PE-3 (+ others)
```

**Originated prefixes** — IPv4 strictly carved from the three RFC 5737 /24s (so distinct "Internet" prefixes are /28 slices); IPv6 from `2001:db8::/32` (RFC 3849, no scarcity):

| Originator | IPv4 (RFC 5737) | IPv6 (RFC 3849) | Represents |
| --- | --- | --- | --- |
| `transit-a-csr` (AS 64497) | `0.0.0.0/0` default + 8 mock Internet /28s from `192.0.2.0/24` | `::/0` default + `2001:db8:a::/48` sample | global default + "the Internet" sample |
| `transit-b-iol` (AS 64498) | `0.0.0.0/0` default (**lower LOCAL_PREF on Aurora**) + same `192.0.2.0/24` /28s | `::/0` default (backup) + same | backup default + same sample (failover testable) |
| `ixp-content1` (AS 64500) | 3 CDN /28s from `198.51.100.0/25` | `2001:db8:c0::/48` | Cloudflare/Netflix-style content |
| `ixp-eyeball1` (AS 64501) | 5 eyeball /28s from `198.51.100.128/25` | `2001:db8:e0::/48` | TPG/Aussie-Broadband-style access ISP |
| Aurora (AS 64496) | mock PI `203.0.113.0/25` + customer aggregates | `2001:db8:aaaa::/48` | what Aurora advertises outward |
| Northwind/customer (AS 64502) | customer block from `203.0.113.128/25` | `2001:db8:bbbb::/48` | customer-originated prefix |

**Policy intent** (full config in §5.1; RPKI/ROV in §5.2): IXP content/eyeball preferred over transit; Transit-A default, Transit-B backup; Aurora advertises only its mock PI + approved customer prefixes outward; **no transit routes leak to IXP** (settlement-free peering hygiene); **RPKI-invalid routes rejected** at the edge; **max-prefix cap** per transit; **dual-stack** (v4 + v6 AFI/SAFI).

### 3.3 Physical mapping

- **GNS3 controller**: `http://192.168.200.2:3080/v2` (Dell-Windows host on the gigabit ethernet link). Project = `ops-lab` (`d8119db0-dd43-4d20-870d-9d62fd6345f1`).
- **GNS3 VM**: VMware Workstation appliance on Dell, Tailscale `gns3@100.118.0.46`, **2 physical vCPU / 19 GiB RAM** — the empirical constraint envelope per ADR-002 §3.9.
- **All Region A nodes run on `compute_id: "vm"`** (the GNS3 VM compute). Tenant docker containers and the three FRR IXP containers run on the GNS3 VM's docker daemon.
- **Console-driven config**: the `iolcfg.py` socket helper on the GNS3 VM drives IOL/IOS-XR consoles (raw socket + telnet IAC; the VM's Python 3.14 has no `telnetlib`). Claude drives; the user verifies via the REST API (`memory/lab-coaching-workflow.md`).
- **Management plane** (Wazuh, MISP, Cowork, openconnect to DevNet) stays on **PC1** per ADR-002 §6.

## 4. IP and AS plan (Region A slice)

> **Canonical source = THIS section** for Region A (Aurora carrier **AS 64496**, documentation ASNs/prefixes). `docs/ip-plan.md` is now the cross-region addressing index and mirrors this section at summary level.

| Node | Loopback (Lo0) | Mgmt | Role |
| --- | --- | --- | --- |
| Aurora-P / MEL-P (IOL-L3) | 10.0.0.1/32 | 192.168.200.11/24 | IS-IS L2 / LDP only (no BGP) |
| Aurora-PE-1 / MEL-PE1 (IOL-L3) | 10.0.0.2/32 | 192.168.200.12/24 | iBGP full-mesh VPNv4 PE; Northwind CE; Transit-A + Melbourne IXP |
| Aurora-PE-2 / BNE-PE1 (IOL-L3) | 10.0.0.3/32 | 192.168.200.13/24 | iBGP full-mesh VPNv4 PE; Helix LAN local VRF / Brisbane edge |
| Aurora-PE-3 / SYD-PE1 (IOS-XRv) | 10.0.0.4/32 | 192.168.200.14/24 | iBGP full-mesh VPNv4 PE; spare CE; Transit-B + IXP; **future inter-region eBGP to Region B**; ROV enforcer |
| Northwind CE (FortiGate) | 10.0.1.1/32 | DHCP from PE-1 link | eBGP to PE-1, **AS 64512 (private customer AS — default model)** |
| Geelong access / spare CE (IOSv, optional) | 10.0.1.2/32 | DHCP from PE-3 link | GEL access placeholder; eBGP to PE-3, AS 64513 (or AS 64502 in the BYO-AS scenario) |
| Helix LAN switch (Aruba CX) | n/a (L2) | 192.168.200.16/24 | VLAN 100 (Helix data), VLAN 200 (Helix mgmt) |

**Northwind / customer AS model:**
- **Default — private customer CE (AS 64512).** Northwind's FortiGate CE peers eBGP to PE-1 as private **AS 64512**; **Aurora (AS 64496) originates/aggregates the customer's public block** (`203.0.113.128/25`) on PE-1. The customer has *no public BGP presence* — the common MSP model. Exercises `remove-private-as`, provider-originated PI/PA space, customer route filtering, FortiGate NAT/security.
- **Optional — BYO-AS public customer (AS 64502).** A customer that brings its own ASN/prefix and originates it, with Aurora as transit. Stand up on the spare IOSv CE. Exercises customer prefix-lists, max-prefix, **RPKI origin validation of the customer origin**, no-transit-leak.

**Internet Edge AS / addressing** — all ASNs **RFC 5398 documentation ASNs** (64496–64511); all prefixes **RFC 5737 / RFC 3849 documentation space**.

| Node | AS | Originated prefixes | Peering |
| --- | --- | --- | --- |
| Aurora (carrier) | **64496** | PI `203.0.113.0/25` + `2001:db8:aaaa::/48` + customer aggregates | originates outward to both transits + IXP |
| `transit-a-csr` | **64497** | `0.0.0.0/0` + `::/0` + 8 mock Internet /28s (`192.0.2.0/24`) + `2001:db8:a::/48` | eBGP to Aurora-PE-1 |
| `transit-b-iol` | **64498** | `0.0.0.0/0` + `::/0` (backup) + same mock Internet prefixes | eBGP to Aurora-PE-3 |
| `ixp-rs1` (route server) | **64499** | none (RS reflects only, next-hop preserved) | multilateral eBGP to PE-1, PE-3, content, eyeball |
| `ixp-content1` | **64500** | 3 CDN /28s (`198.51.100.0/25`) + `2001:db8:c0::/48` | eBGP to RS |
| `ixp-eyeball1` | **64501** | 5 eyeball /28s (`198.51.100.128/25`) + `2001:db8:e0::/48` | eBGP to RS |
| Northwind/customer (**optional** BYO-AS) | **64502** | customer block (`203.0.113.128/25`) + `2001:db8:bbbb::/48`, **self-originated** | eBGP (BYO-AS scenario only) |
| Northwind CE (**default**) | 64512 (private) | — (Aurora originates `203.0.113.128/25` on its behalf) | eBGP to PE-1; `remove-private-as` outbound |

Backbone p2p links: `10.255.0.0/24` /31s (IPv4) + `2001:db8:ffff::/64`-derived /127s (IPv6) — `Aurora-P ↔ PE-1` = `10.255.0.0/31`, `↔ PE-2` = `10.255.0.2/31`, `↔ PE-3` = `10.255.0.4/31`.

> **Build reconcile (2026-06-14):** the initial bring-up sketch used `10.1.1.0/30` for P↔PE-1 — **superseded by this canonical `10.255.0.0/31`**. The running config is aligned to §4, not the sketch.

PE-CE links: `10.255.1.0/24` /30s + matching v6 /127s.

Internet-edge links (dual-stack):
- PE-1 ↔ Transit-A: `10.255.2.0/30` + `2001:db8:ffff:2::/127`
- PE-3 ↔ Transit-B: `10.255.2.4/30` + `2001:db8:ffff:2::2/127`
- IXP peering LAN (`ixp-fabric`): `10.255.3.0/24` — PE-1 `.1`, PE-3 `.3`, RS `.10`, content `.20`, eyeball `.30`; v6 `2001:db8:ffff:3::/64`.

**RPKI-RTR cache endpoint = `192.168.200.1:3323` (PC1), used everywhere.**

Aurora mock public/PI block: `203.0.113.0/25` (TEST-NET-3). Customer block `203.0.113.128/25`.

**VRF RD/RT convention** (Cisco term; replaces the Nokia "VPRN"): RD = `64496:<customer_id>`, RT = `64496:<customer_id>`. Customer IDs: Northwind 3, Helix 2, Maple Ridge 1. **L3VPN validation VRF `CUST-A` = `64496:100`** (a reserved test id, not a tenant).

## 5. Protocols

| Layer | Choice | Notes |
| --- | --- | --- |
| IGP | **IS-IS L2 wide-metrics** | Single area; `metric-style wide`; loopbacks announced into IS-IS for LDP and BGP next-hop reachability. |
| Label distribution | **LDP** (not SR-MPLS) | LDP transport = Lo0 (`mpls ldp router-id Loopback0 force`). SR-MPLS is a later iteration. |
| Backbone overlay | **iBGP full mesh** among PE-1, PE-2, PE-3 (3 sessions) | **VPNv4 address family** (`no bgp default ipv4-unicast`; `address-family vpnv4`). No RR at this size. |
| PE-CE | **eBGP** (Northwind, spare CE); **local VRF VLAN trunk** (Helix LAN) | eBGP keepalive 30 / holdtime 90 (default). |
| Internet edge | **eBGP** to transits (global table) + **eBGP** to IXP route server | Default route from transits; IXP for specific peer prefixes. Policy §5.1; RPKI/ROV §5.2. |
| L3VPN | **VRF + MP-BGP VPNv4** | Validation VRF `CUST-A` (§5.3); tenant VRFs Northwind (PE-1) / Helix (PE-2). |
| Authentication | **None in v2.1** | TCP-AO / MD5 deferred per ADR-002 §9.6. |
| Address family | **IPv4 + IPv6 dual-stack** | Both AFI/SAFI on backbone, PE-CE, Internet edge. Build Phase B layers v6 after v4. |
| RPKI / ROV | **Routinator (RP) + SLURM lab VRPs + RPKI-RTR; ROV-enforce at the edge** | First enforcer `Aurora-PE-3`; design §5.2. Build Phase C. |
| Tenant services | **VRF per tenant** on each PE that hosts the tenant | Northwind VRF on PE-1; Helix VRF on PE-2. |

### 5.1 Internet-edge BGP policy

Applied on Aurora-PE-1 (Transit-A + IXP) and Aurora-PE-3 (Transit-B + IXP):

| Rule | Mechanism | Demonstrates |
| --- | --- | --- |
| **Prefer IXP routes** for content/eyeball prefixes | LOCAL_PREF 300 on IXP-learned prefixes | "peer where you can, transit where you must" |
| **Transit-A is primary default** | LOCAL_PREF 200 on Transit-A `0.0.0.0/0` | primary/backup transit selection |
| **Transit-B is backup default** | LOCAL_PREF 100 on Transit-B `0.0.0.0/0` | failover: kill Transit-A → Transit-B wins |
| **Advertise outward only approved prefixes** | outbound prefix-list = Aurora mock PI + customer aggregates ONLY | no accidental transit |
| **No transit routes to IXP peers** | outbound filter on the IXP session drops transit-AS routes | settlement-free peering hygiene |
| **Max-prefix cap per transit** | `maximum-prefix` ~200 on each transit session | survive a misconfigured upstream |
| **Reject RPKI-invalid** at the edge | drop routes whose ROV state = Invalid (§5.2) | origin-hijack rejection |
| **Bogon / martian filter** | inbound prefix-list drops RFC1918, default-from-IXP, mock-PI from peers | edge hygiene |
| **Don't leak IXP→transit** | outbound filter on transit sessions drops IXP-peer routes | don't give transit your peers for free |

LOCAL_PREF hierarchy: **IXP (300) > Transit-A (200) > Transit-B (100)**. RPKI-Invalid routes are dropped *before* best-path runs.

### 5.2 RPKI / ROV (lab, via Routinator + SLURM)

Real route-origin-validation without paying an RIR. Build Phase C — after the IPv4+IPv6 BGP fabric (§6 Phases A/B) is converged.

| Component | Role | Node |
| --- | --- | --- |
| **Routinator** (NLnet Labs) | RPKI validator / Relying Party — produces VRPs, serves RPKI-RTR (RFC 8210, TCP 3323) | `rpki-rp1` (docker on **PC1**) |
| **SLURM** (RFC 8416) | local exceptions — `locallyAddedAssertions` mint VRPs for doc prefixes (no real ROAs exist) | config on `rpki-rp1` |
| **ROV enforcer** | router as RTR client — classifies Valid/Invalid/NotFound, applies policy | `Aurora-PE-3` (IOS-XRv) first; others as support allows |

**SLURM VRP set:**

| Prefix | Correct origin AS | Used to test |
| --- | --- | --- |
| `203.0.113.0/25` + `2001:db8:aaaa::/48` | 64496 (Aurora) | Valid |
| `198.51.100.0/25` + `2001:db8:c0::/48` | 64500 (content) | Valid; **forge from 64501 → Invalid** |
| `198.51.100.128/25` + `2001:db8:e0::/48` | 64501 (eyeball) | Valid |
| `192.0.2.0/24` slices | (intentionally **no** VRP) | NotFound |

**Enforcement is phased; design target = ROV at *every* eBGP ingress:**
- **Phase C1 — XR-only.** Enforce on `Aurora-PE-3` (IOS-XR, mature RTR/ROV); prove Valid/Invalid/NotFound first.
- **Phase C2 — FRR reference enforcer** for the IXP side. FRR's `rpki` module is **confirmed present** (`librtr.so` in `frrouting/frr:latest`).
- **Phase C3 — all eBGP ingress.** Enforce on Transit-A@PE-1, Transit-B@PE-3, IXP@PE-1/PE-3. **IOL-L3 (IOS) supports BGP origin-validation** (RTR + route-map `match rpki`), so PE-1/PE-2 can enforce — the all-Cisco backbone makes this uniform (no mixed-vendor gap to work around, unlike the prior SR OS plan).

> **⚠ Enforcement gap to mind (HIGH).** Until C3, PE-1 also ingests Transit-A + IXP without ROV. Keep the C1 demo honest by **(a)** introducing the forged-Invalid only via a PE-3-facing session, or **(b)** enforcing on PE-1 early.

**Test matrix** (for C1, introduce the Invalid via PE-3 only):

| State | Setup | Expected on enforcer |
| --- | --- | --- |
| **Valid** | content prefix originated by 64500 | accepted, normal best-path |
| **Invalid** | re-originate content prefix from `ixp-eyeball1` (64501) | **rejected** — does not win best-path |
| **NotFound** | `192.0.2.0/28` slice (no VRP) | accepted, marked NotFound, normal policy |

### 5.3 L3VPN validation (VRF CUST-A) — the first MPLS service proof

Before tenant VRFs, prove the MPLS-L3VPN data path end to end with a minimal test VRF on **two** PEs (needs ≥2 PEs, so this runs once PE-2 is up):

- **VRF** `CUST-A`, `rd 64496:100`, `route-target import/export 64496:100`, on PE-1 and PE-2.
- A test interface (or `Loopback100`) in `CUST-A` on each: PE-1 `172.16.100.1/32`, PE-2 `172.16.100.2/32`; `redistribute connected` into `address-family ipv4 vrf CUST-A`.
- **Proof:** `show bgp vpnv4 unicast all` on each PE shows the *other* PE's VRF prefix with a VPN label; `ping vrf CUST-A 172.16.100.2 source 172.16.100.1` from PE-1 succeeds — traffic rides LDP transport + the VPNv4 service label across Aurora-P. This is the canonical "L3VPN works" gate (§7) before any tenant service is wired.

## 6. Bring-up procedure (staggered waves per ADR-002 §3.9.4)

Cold-starting all ~13 nodes simultaneously spikes the GNS3 VM load. Each wave waits for the previous wave's protocols to converge.

> **Build phasing (distinct from cold-start waves).** *Waves* = power order each time. *Phases* = capability build order the first time:
> - **Phase A — IPv4 fabric**: backbone IS-IS/LDP, iBGP VPNv4, **L3VPN VRF CUST-A proof (§5.3)**, eBGP CE, eBGP transit + IXP, LOCAL_PREF policy.
> - **Phase B — IPv6 dual-stack**: add v6 AFI/SAFI everywhere; mirror policy.
> - **Phase C — RPKI/ROV**: Routinator + SLURM on PC1; point `Aurora-PE-3` at RTR; run the matrix (§5.2).

### Wave 1 — Backbone IS-IS/LDP core (~3 min)  ← in progress

Nodes: `Aurora-P`, `Aurora-PE-1`, `Aurora-PE-2`.

```
POST /v2/projects/{ops-lab}/nodes/{Aurora-P}/start
POST /v2/projects/{ops-lab}/nodes/{Aurora-PE-1}/start
POST /v2/projects/{ops-lab}/nodes/{Aurora-PE-2}/start
```

**Wait until** all three reach the IOL enable prompt (~20–30 s), then configure (IS-IS L2 + LDP) and verify:

- Aurora-PE-1: `show isis neighbors` → adjacency to `Aurora-P` Up; `show mpls ldp neighbor` → session to P Operational; `show mpls ldp bindings` → labels exchanged.
- Aurora-PE-2: same.
- Aurora-P: `show isis neighbors` → both PEs listed; `show mpls ldp neighbor` → 2 sessions.

### Wave 2 — Cisco interop PE (~3 min)

Nodes: `Aurora-PE-3` (IOS-XRv 6.1.3). (Optional `region-a-ce-spare` IOSv is on-demand.)

```
POST /v2/projects/{ops-lab}/nodes/{Aurora-PE-3}/start
```

**Wait until** XRv reaches `RP/0/RP0/CPU0:ios#`, then:

- PE-3: `show isis adjacency` → adjacency to Aurora-P Up; `show mpls ldp neighbor` → P session Operational; `show bgp vpnv4 unicast summary` → both IOL PEs Established.

### Wave 3 — Customer-facing (~3 min)

Nodes: `northwind-ce` (FortiGate), `helix-lan-sw` (Aruba CX).

```
POST /v2/projects/{ops-lab}/nodes/{northwind-ce}/start
POST /v2/projects/{ops-lab}/nodes/{helix-lan-sw}/start
```

**Verify:**
- FortiGate: `get router info bgp summary` → eBGP to PE-1 Established.
- Aruba CX: `show vlan` → VLANs 100/200 present; `show lldp neighbor-info` → uplink to PE-2.
- PE-1: `show bgp vpnv4 unicast vrf NORTHWIND summary` → Northwind CE Established, prefixes received.
- PE-2: `show ip vrf interfaces` → Helix VRF interfaces up.

### Wave 3.5 — Internet Edge (~3 min)

Nodes: `transit-a-csr`, `transit-b-iol`, `ixp-fabric` (switch — instant), `ixp-rs1` / `ixp-content1` / `ixp-eyeball1` (FRR docker).

```
POST /v2/projects/{ops-lab}/nodes/{ixp-fabric}/start
POST /v2/projects/{ops-lab}/nodes/{transit-a-csr}/start
POST /v2/projects/{ops-lab}/nodes/{transit-b-iol}/start
POST /v2/projects/{ops-lab}/nodes/{ixp-rs1}/start
POST /v2/projects/{ops-lab}/nodes/{ixp-content1}/start
POST /v2/projects/{ops-lab}/nodes/{ixp-eyeball1}/start
```

**Verify:**
- PE-1: `show bgp ipv4 unicast neighbors 10.255.2.1` → Transit-A Established; `show ip route 0.0.0.0` → default via Transit-A (LOCAL_PREF 200).
- PE-3: `show bgp ipv4 unicast neighbors 10.255.2.5` → Transit-B Established; default present (backup, LOCAL_PREF 100).
- PE-1/PE-3: BGP to `ixp-rs1` (`10.255.3.10`) Established; content/eyeball prefixes via RS.
- `ixp-rs1`: `vtysh -c "show bgp summary"` → 4 neighbours Established.
- Route preference (PE-1): `show ip route 198.51.100.0` → next-hop via `ixp-fabric` (LOCAL_PREF 300), **not** a transit. The "peer-over-transit" proof.

### Wave 4 — Tenant workload containers (~2 min)

```
ssh gns3@100.118.0.46
cd /opt/gns3/projects/{ops-lab}/docker
docker compose -f region-a-workloads.yml up -d
```

Verify `docker ps` → 8 Running; `iperf3`/`curl` between workloads succeed.

### Total fabric verification (end of cold start)

- All backbone nodes: expected IS-IS adjacencies + LDP sessions.
- iBGP VPNv4 mesh: 3 sessions Established.
- **L3VPN VRF CUST-A proof passes (§5.3).**
- eBGP CE Established (Northwind; spare if started).
- Tenant VRFs (Northwind@PE-1, Helix@PE-2) show route counts > 0.
- Both transit sessions Established; default present (A primary, B backup).
- IXP route server 4 sessions; content/eyeball prefer IXP over transit.
- ICMP from `helix-doctor-wks` to a mock Internet /28 succeeds — end-to-end to simulated Internet egress.

## 7. Smoke tests (per-node)

| Node | Command | Expected |
| --- | --- | --- |
| Aurora-P (IOL) | `show isis neighbors` | 3 adjacencies (PE-1, PE-2, PE-3) Up |
| Aurora-P (IOL) | `show mpls ldp neighbor` | 3 LDP sessions Operational |
| Aurora-PE-1/PE-2 (IOL) | `show isis neighbors` / `show mpls ldp neighbor` | Adj + LDP to P Up |
| Aurora-PE-1/PE-2 (IOL) | `show bgp vpnv4 unicast all summary` | 2 iBGP neighbours Established; VPNv4 prefixes > 0 |
| **L3VPN proof (PE-1)** | `ping vrf CUST-A 172.16.100.2 source 172.16.100.1` | success — VPNv4 + LDP label path across P |
| Aurora-PE-3 (IOS-XR) | `show isis adjacency` / `show mpls ldp neighbor` | Both Up |
| Aurora-PE-3 (IOS-XR) | `show bgp vpnv4 unicast summary` | 2 iBGP neighbours Established |
| Northwind CE (FortiGate) | `get router info bgp summary` | eBGP to PE-1 Established |
| Spare CE (IOSv, if up) | `show ip bgp summary` | eBGP to PE-3 Established |
| Helix LAN (Aruba CX) | `show vlan` / `show lldp neighbor-info` | VLAN 100/200 active; uplink LLDP visible |
| Transit-A (PE-1 view) | `show bgp ipv4 unicast neighbors 10.255.2.1` | Established; `0.0.0.0/0` received, LOCAL_PREF 200 |
| Transit-B (PE-3 view) | `show bgp ipv4 unicast neighbors 10.255.2.5` | Established; `0.0.0.0/0` received, LOCAL_PREF 100 |
| IXP route server (`ixp-rs1`) | `vtysh -c "show bgp summary"` | 4 neighbours Established |
| IXP route preference (PE-1) | `show ip route 198.51.100.0` | next-hop via `ixp-fabric` (LOCAL_PREF 300) |
| Transit failover | shut Transit-A on PE-1 → `show ip route 0.0.0.0` | default reconverges to Transit-B |
| Egress reachability | from a tenant workload: `ping <mock Internet /28 .1>` | succeeds via Transit-A |
| IPv6 dual-stack (PE-3) | `show bgp ipv6 unicast summary` / `ping6 2001:db8:a::1` | v6 sessions Established; v6 egress works |
| Routinator (`rpki-rp1`) | `routinator vrps \| wc -l` | VRP count > 0 |
| RTR session (PE-3) | `show rpki server` (IOS-XR) | cache `192.168.200.1:3323` ACTIVE; records loaded |
| ROV Valid / Invalid / NotFound | per §5.2 matrix | valid installed; invalid rejected; not-found accepted |

## 8. Operations

### 8.1 Daily verify (no changes)

```
curl http://192.168.200.2:3080/v2/projects/{ops-lab}/nodes | jq '.[] | {name, status}'
# All nodes "started"; then run §7 smoke (~5 min)
```

### 8.2 Update a node — no service impact (PE-2 example)

Config-only change (no template change, no NOS upgrade): console/SSH to the node → `conf t` → edit → `end` → `write memory` → §7 smoke for that node. iBGP and IS-IS absorb the change; no restart.

### 8.3 Update a node — with service impact (PE-1 example, template/NOS change)

1. Drain traffic (Northwind CE BGP holdtime → 30 s, or shut the CE-PE link).
2. Stop PE-1 via the GNS3 API.
3. Update template / image; PUT node properties.
4. Start PE-1; wait for IS-IS, LDP, iBGP, eBGP to reconverge.
5. Restore traffic; §7 smoke on PE-1 + Northwind CE.

Helix traffic continues via PE-2 throughout. **This is the MOP shape for the Telstra patching practice** — wrap each such change in the operational-evidence template (`telstra-ops-practice-plan.md`).

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

## 9. What's NOT in v2.1 (deferred / out of scope)

- **Singleton heavyweights** (FTDv, Cat9kv, FMC, XRv9000, PA-VM 11). On-demand per §8.6; never in the running fabric.
- **Region B (DevNet CML)** — Cisco **+ Juniper** (vSRX/vJunos via BYOI). ADR-002 §3.2 + ADR-003 §2.3–2.4.
- **Region C (cloud edge)** — DigitalOcean containerlab (cRPD + FRR + Routinator + public-IP route-server). ADR-003 §2.4.
- **Inter-region BGP confederation** (Aurora-PE-3 → Region B over openconnect-on-PC1). v2.2 once Region B is up.
- **Authentication** (TCP-AO/MD5). Deferred per ADR-002 §9.6.
- **Maple Ridge workload containers** — live with the Region B Maple Ridge CE.
- **Local Nokia / Juniper PEs** — Nokia archived (ADR-003 §2.2); Juniper (vSRX/vJunos) is Region B + cloud, with **vSRX standalone-local** for practice only (not a Region A core node).
- **Real public ASNs / registered ROAs / advertising to the real Internet** — doc ASNs + SLURM lab VRPs only.

## 10. Open follow-ups

- **`region-a-cisco/clab-region-a.yml`** — author the GNS3 project export (canonical reproducible topology).
- **`region-a-cisco/configs/`** — per-node IOL/IOS-XR config templates; Jinja2 with the §4 inventory.
- **`region-a-cisco/ansible/`** — `make region-a-up` (wraps §6 waves), `make smoke` (§7), `make region-a-down` (§8.4).
- **Helix LAN mode-switch** when Region B comes up (local VRF on PE-2 → forwarding-only).
- **Backup / restore drill** — verify §8.7 rsync + GNS3 project import round-trip.
- ✅ **`region-a-topology.drawio` regen — DONE** (Cisco Region A core). PNG export is deferred until a drawio renderer is available.
- ✅ **IOL (IOU) on the Dell GNS3 VM — resolved** (`memory/gns3-nos-boot-quirks.md`); console via `iolcfg.py` socket helper.
- ✅ **FRR-in-GNS3-docker + rpki module — DONE** (`librtr.so` in `frrouting/frr:latest`); still TODO: wire one as a GNS3 docker node + an eBGP session.
- **RPKI/ROV build (Phase C)** — Routinator + SLURM on PC1; GNS3 Cloud node to `192.168.200.x`; RTR `192.168.200.1:3323`; C1 (PE-3) → C3 (all ingress).
- ✅ **`ip-plan.md` v2.1 refresh — DONE** (cross-region index; Region A summary mirrors this §4 and retains the national POP overlay).

## 11. References

- `docs/adr-003-revendor-cisco-region-a.md` — Region A vendor stack (Cisco), Juniper→B, three-region model, build-then-operate.
- `docs/adr-002-two-region.md` — §3.2 Region B, §3.9 Dell capability envelope + operational rules, §6 VPN endpoint (PC1).
- `docs/design.md` — protocol-level Aurora design (IS-IS, LDP, BGP VPNv4 conventions).
- `docs/ip-plan.md` — cross-region IP/AS/RD-RT index; Region A summary mirrors §4.
- `docs/telstra-ops-practice-plan.md` — the ops practice that layers on this build.
- `memory/gns3-nos-boot-quirks.md` — per-NOS boot recipes (IOL, FortiGate, Aruba CX; vJunos-can't-run-locally).
- `memory/gns3-vm-ram-budget.md` — RAM/CPU rules, OOM behaviour, stale-status recovery.
- `memory/lab-coaching-workflow.md` — Claude-drives / user-coaches console workflow.
- `memory/sros-gns3-license-recipe.md` — **archived** Nokia SR OS RTC-frozen license recipe (recoverable).

**Standards (Internet Edge / RPKI):** RFC 5398 (doc ASNs), RFC 6996 (private ASNs — customer only), RFC 5737 (IPv4 doc prefixes), RFC 3849 (IPv6 doc prefix), RFC 8210 (RPKI-RTR), RFC 8416 (SLURM). Routinator (NLnet Labs) — RPKI RP / validator with SLURM + built-in RTR.
