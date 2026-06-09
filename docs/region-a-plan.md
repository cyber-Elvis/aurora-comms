# Region A — Build and Operations Plan (v1.1)

| Field | Value |
| --- | --- |
| Status | Draft |
| Version | 1.2 |
| Date | June 2026 |
| Scope | Steady-state Region A fabric on Dell GNS3 — four tiers: **P/core + PE + Customer Edge + Internet Edge** (simulated upstream transit + IXP peering + **lab RPKI/ROV** + **IPv4/IPv6 dual-stack**) + tenant workloads |
| Excludes | Singleton heavyweights (FTDv, Cat9kv, FMC, XRv9000, PA-VM 11), Region B (DevNet CML), inter-region BGP confederation, routing-protocol authentication (TCP-AO/MD5). **NOT excluded but explicitly lab-only:** ASNs are RFC 5398 *documentation* ASNs (not registered), prefixes are RFC 5737/3849 *documentation* space, RPKI uses local SLURM VRPs (not real RIR ROAs) — nothing is ever advertised to the real Internet. |
| Revision | v1.2 actions a pre-implementation review: makes §4 self-canonical for Region A (ip-plan.md superseded + IPv6 bug fixed), adds the C1→C2→C3 ROV phasing + PE-1 enforcement-gap note, documents the Northwind private-AS-64512-default / BYO-AS-64502-optional model, pins the RPKI cache to PC1 `192.168.200.1:3323`, switches test prefixes to exact /28s, fixes "iBGP RR-client"→"full-mesh PE", and adds RS→PE reflection arrows. Records the FRR-rpki (PASS) and SR OS RPKI (12.0R1+) smoke results. v1.1 added the Internet Edge (doc-ASN transit + IXP + RPKI/ROV + dual-stack); v1.0 was backbone + CE/LAN + workloads. |
| Source of truth for design | ADR-002 §3.1 (intent), §3.9 (Dell capability envelope, validated arsenal, operational rules) |
| Owner | Lab architecture (Elvis Ifeanyi Nwosu) |
| Related | `docs/adr-002-two-region.md`, `docs/design.md`, `docs/ip-plan.md`, `docs/runbook.md`, `memory/gns3-nos-boot-quirks.md`, `memory/gns3-vm-ram-budget.md`, `memory/sros-gns3-license-recipe.md` |

## 1. What this doc is

The **executable plan** companion to ADR-002. ADR-002 §3.1 says *what Region A is and why*; this doc says *what to build, in what order, how to verify, and how to operate it*. Lives next to (not inside) ADR-002 so the architecture decision record stays focused on intent and this stays a runbook-shaped reference for execution.

Region A's empirical capacity envelope (§3.9 of ADR-002) is the constraint this plan respects: **7-8 protocol-light nodes run together stably on Dell GNS3 in steady state** (validated at ~8.2 GiB used), with the headroom to add lights and the rule that singleton heavyweights must run **solo** with the fabric stopped. This plan lists ~13 routed/switch nodes, but the constraint is **actual idle RSS, not node count** — the extra Internet-edge nodes are nearly free (IOL ~0.5 GB, IOSv ~0.5 GB, FRR ~0.15 GB each, the IXP fabric switch 0 GB), so the whole four-tier fabric still lands at ~8.5 GiB idle (§2.5) — inside the proven envelope.

## 2. Inventory — four tiers plus tenant containers

Region A is a four-tier SP: **P/core → PE → Customer Edge → Internet Edge**, with tenant workload containers hanging off the customer edges. ~13 infrastructure nodes (1 P + 3 PE + 3 CE/LAN + 2 transit + 1 IXP fabric switch + 3 FRR IXP) plus 8 tenant workload containers. SR Linux (P) and the FRR IXP nodes are docker; the rest are QEMU except the L2 fabric switch.

### 2.1 Backbone (P + PE core)

| Role | Node name | NOS | RAM (declared / idle RSS) | vCPU | Recipe ref |
| --- | --- | --- | --- | --- | --- |
| Aurora-P (IS-IS L2 / LDP transit, no BGP) | `aurora-p` | Nokia SR Linux 24.10.1 (docker) | ~1 GB / ~1 GB | n/a | `memory/gns3-nos-boot-quirks.md` § SR Linux (USER user fix; AUX console for sr_cli) |
| Aurora-PE-1 (Nokia carrier PE; Northwind CE + Transit-A + IXP) | `aurora-pe-1` | Nokia SR OS 13.0 R4 (licensed) | 2 GB / ~0.5 GB | 1 | `memory/sros-gns3-license-recipe.md` (UUID 0…0 + RTC 2015-03-10) |
| Aurora-PE-2 (Nokia carrier PE; Helix LAN VPRN) | `aurora-pe-2` | Nokia SR OS 13.0 R4 (licensed) | 2 GB / ~0.5 GB | 1 | same as PE-1 |
| Aurora-PE-3 (Cisco interop PE; spare CE + Transit-B + IXP + future inter-region eBGP) | `aurora-pe-3` | Cisco IOS-XRv 6.1.3 | 3 GB / ~1 GB | 1 | ide / qemu64 defaults; no special options |

### 2.2 Customer Edge

| Role | Node name | NOS | RAM (declared / idle RSS) | vCPU | Recipe ref |
| --- | --- | --- | --- | --- | --- |
| Northwind CE (consolidated CE + FortiSD-WAN + NGFW) | `northwind-ce` | Fortinet FortiGate-VM 7.0.14 | 1 GB / ~0.6 GB | 1 | ide + 30 GB blank `hdb` data disk |
| Helix LAN switch (customer-owned LAN behind PE-2) | `helix-lan-sw` | HPE Aruba CX 10.16.1040 | 4 GB / ~1.7 GB | 2 | `-nographic`; **30-day trial license unactivated — do not run `license` CLI until ready** |
| Spare / offline-fallback CE (optional, on-demand) | `region-a-ce-spare` | Cisco IOSv 15.7 | ~0.5 GB / ~0.4 GB | 1 | light native-ish; bring up only when a third CE flavour is needed |

### 2.3 Internet Edge (simulated upstream transit + IXP peering + lab RPKI)

ASNs are **RFC 5398 documentation ASNs** (64496–64511); prefixes are **RFC 5737/3849 documentation space**. Aurora itself = **AS 64496** (the carrier; replaces the v1.0 "65100" placeholder). Northwind customer = **AS 64512 (private CE, default model)** or **AS 64502 (optional BYO-AS public customer)** — see §4 for the two models.

| Role | Node name | NOS | AS | RAM (declared / idle RSS) | vCPU | Recipe ref |
| --- | --- | --- | --- | --- | --- | --- |
| Upstream Transit-A (primary) | `transit-a-csr` | Cisco CSR1000v 16.08.01 | 64497 | **3 GB** / ~2.5 GB | 1 | ide / qemu64; **BGP-only role → 3 GB not 4**; RTR/ROV-capable |
| Upstream Transit-B (backup) | `transit-b-iol` | Cisco IOL-XE 17.15 | 64498 | ram=2048, nvram=1024 / ~0.5 GB | 1 | `memory/gns3-nos-boot-quirks.md` § IOL-XE (RAM fix); RTR/ROV-capable |
| IXP fabric (Melbourne IXP peering LAN) | `ixp-fabric` | GNS3 Ethernet switch (L2) | n/a | 0 | n/a | a built-in switch — IXPs are L2 fabrics |
| IXP route server | `ixp-rs1` | FRR (docker, `quay.io/frrouting/frr`) | 64499 | ~0.15 GB / ~0.1 GB | n/a | **needs FRR-in-GNS3-docker smoke test** (§10); RS = next-hop-preserving |
| IXP content/CDN peer | `ixp-content1` | FRR (docker) | 64500 | ~0.15 GB / ~0.1 GB | n/a | originates mock CDN prefixes |
| IXP eyeball/ISP peer | `ixp-eyeball1` | FRR (docker) | 64501 | ~0.15 GB / ~0.1 GB | n/a | originates mock eyeball prefixes |
| RPKI validator / RP (Routinator) | `rpki-rp1` | Routinator (docker) | n/a | **on PC1, off the Dell budget** (~200 MB) | n/a | Phase C; SLURM local VRPs; serves RTR (TCP 3323) — reachability via a GNS3 Cloud node bridged to `192.168.200.x` |

### 2.4 Tenant workloads (Helix + Northwind — Maple Ridge workloads live in Region B)

`helix-orthanc` (DICOM), `helix-emr` (nginx mock), `helix-doctor-wks` (alpine+iperf3), `northwind-saas` (nginx), `northwind-redis`, `northwind-prometheus`, `northwind-grafana`, `northwind-dev-wks` (alpine+iperf3) — docker, ~1.5 GB / ~1 GB total, per ADR-002 §3.7.1.

### 2.5 Footprint

| Tier | Declared | Idle RSS (est.) |
| --- | --- | --- |
| Backbone (P + 3 PEs) | 8 GB | ~3 GB |
| Customer Edge (FortiGate + Aruba CX; spare CE optional) | ~5 GB | ~2.7 GB |
| Internet Edge (CSR 3 + IOL 0.5 + 3× FRR 0.45 + fabric 0) | ~4 GB | ~2 GB |
| Tenant workloads (8 docker) | ~1.5 GB | ~1 GB |
| **Total core running fabric** | **~18.5 GB declared** | **~8.5-9 GB actual idle** |

Comfortably inside the v1.4 envelope (19 GiB GNS3 VM, ~17 GiB usable; qemu overcommit at idle means declared ≠ resident). **~8 GiB headroom** for lights or test nodes. The spare CE (`region-a-ce-spare`) is bring-up-on-demand and not counted in the core total.

### 2.6 Design choices noted explicitly (callable for review)

- **Cisco interop PE = IOS-XRv 6.1.3, not CSR1000v.** (a) XR is the carrier-grade Cisco OS — better SP narrative fit; (b) ADR-002 §3.2 runs IOS-XR 7.x in Region B, so 6.1.3 in Region A mirrors real carriers running multiple XR generations; (c) lighter (3 GB vs 4).
- **CSR1000v repurposed: spare CE → Transit-A** (user decision). CSR has the richest BGP/policy knobs of the light Cisco nodes, which suits a transit role better than a CE-spare role. The spare-CE duty drops to **IOSv** (lighter); IOL covers **Transit-B**. Net effect vs the old "CSR-as-spare-CE" plan: ~same RAM, but a far stronger SP story (upstream transit + IXP peering).
- **Two transits terminate on different PEs** (Transit-A on Nokia PE-1, Transit-B on Cisco PE-3). Realistic SP path diversity *and* a multi-vendor BGP-policy demo (Nokia-side and Cisco-side transit policy in one lab).
- **IXP route server = FRR, not IOS/CSR.** FRR (and BIRD) are what real IXPs run; FRR gives proper route-server semantics (next-hop preservation, multilateral reflection) that an IOS eBGP-with-next-hop-self only approximates.
- **Dual IXP attachment (PE-1 *and* PE-3 → `ixp-fabric`) is deliberate lab pedagogy.** A real carrier uses one IXP port at one edge router and distributes IX routes internally via iBGP. Dual attachment is kept here specifically to demo **IX-uplink-failure → iBGP reconvergence**. Called out so it's not mistaken for a real-world design.
- **iBGP topology = full mesh among 3 PEs** (3 sessions). Below the threshold where route reflection earns its complexity. Aurora-P (SR Linux) does not run BGP — pure IS-IS/LDP transit.
- **Helix LAN connection model is mode-switched** (see §10 follow-up): when Region B is up, the production model is Helix CE in Region B → GRE-over-IPSec → Aurora-PE-2 → Helix LAN switch (per ADR-002 §3.1/§3.2). When Region B is down, the standalone-Region-A model attaches Helix LAN directly to Aurora-PE-2 via a local VPRN so the box is useful. ADR-002 production model is preserved, not contradicted.
- **Maple Ridge workloads are not in Region A v1.0.** Maple Ridge primary CE is Region B (Cat8000v in CML per ADR-002 §3.2). The Region A spare CE can host Maple-Ridge-style traffic if Region B is unavailable, but the canonical Maple Ridge workload nodes live with Region B.
- **Fresh nodes, not validation-project renames.** `transit-a-csr` / `transit-b-iol` / etc. are instantiated fresh in the Region A project. The validation-project instances stay as the known-good baseline.
- **Documentation ASNs (RFC 5398, 64496–64511), not private ASNs (RFC 6996).** Documentation ASNs are reserved precisely for examples/labs; private ASNs are for real private deployments. Aurora = 64496; transits 64497/64498; IXP RS/content/eyeball 64499/64500/64501; customer 64502. (16-ASN ceiling in this range — overflow goes to the 32-bit doc range 65536–65551.)
- **Lab RPKI/ROV via Routinator + SLURM, not real RIR ROAs.** `rpki-rp1` runs Routinator (the validator / Relying Party); SLURM (RFC 8416) `locallyAddedAssertions` mint VRPs for the documentation prefixes (there are no real ROAs for doc space). Routers are the **ROV enforcers** (RTR clients) — terminology kept precise: validator ≠ enforcer. **First ROV enforcer = `aurora-pe-3` (IOS-XRv 6.1.3)** — mature RTR/ROV support. SR OS 13.0R4 RPKI coverage is **to be verified** (origin-validation existed from ~12.0); if incomplete, enforce on the IOS-XR PE and/or an FRR node as the reference enforcer. **FRR's `rpki` module** (rtrlib) may not be in the stock docker image — smoke-test item (§10).
- **IPv4 + IPv6 dual-stack** at the edge (v1.1). IPv6 from `2001:db8::/32` (RFC 3849); no scarcity, carve /48s freely. IPv4 mock prefixes are **sub-allocations of the three RFC 5737 /24s** (only three /24s exist, so distinct "Internet" prefixes are /28 slices — see §3.2 / §4).
- **Routinator on PC1, off the Dell budget.** ~200 MB; reachability to the GNS3 edge routers via a GNS3 Cloud node bridged to `192.168.200.x`, RTR on TCP 3323. Alternative (documented): an in-topology `rpki-rp1` docker node if the cross-host path proves fiddly.

## 3. Topology

### 3.1 Logical topology

```mermaid
graph TB
    classDef nokia_sros fill:#0066b3,color:#fff,stroke:#003d6b
    classDef nokia_srl fill:#42a5f5,color:#fff,stroke:#0066b3
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

    subgraph Backbone["Aurora AS 64496 — P/PE core (IS-IS L2 + LDP, iBGP VPNv4 full mesh)"]
        P["Aurora-P<br/>SR Linux 24.10.1<br/>(IS-IS/LDP transit, no BGP)"]
        PE1["Aurora-PE-1<br/>SR OS 13.0 R4<br/>(licensed)"]
        PE2["Aurora-PE-2<br/>SR OS 13.0 R4<br/>(licensed)"]
        PE3["Aurora-PE-3<br/>IOS-XRv 6.1.3<br/>(Cisco interop)"]
    end

    subgraph CEs["Customer Edge"]
        NW["Northwind CE<br/>FortiGate 7.0.14<br/>(CE + FortiSD-WAN + NGFW)"]
        HLAN["Helix LAN switch<br/>Aruba CX 10.16.1040"]
        SPARE["region-a-ce-spare<br/>IOSv 15.7<br/>(optional, on-demand)"]
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
    PE1 -.->|iBGP| PE2
    PE2 -.->|iBGP| PE3
    PE1 -.->|iBGP| PE3

    %% PE-CE
    NW -->|eBGP CE-PE<br/>+ FortiSD-WAN| PE1
    HLAN ---|VLAN trunk<br/>(local VPRN)| PE2
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

    class P nokia_srl
    class PE1,PE2 nokia_sros
    class PE3,SPARE cisco_xr
    class NW fortinet
    class HLAN aruba
    class HORTH,HEMR,HDOC,NSAAS,NREDIS,NPROM,NGRAF,NDEV workload
    class TA,TB transit
    class RS,CON,EYE,IXF ixp
    class RPKI mgmt
```

### 3.2 Internet Edge (simulated external Internet)

The Internet Edge sits **north of Aurora AS 64496** and is entirely simulated — **documentation ASNs** (RFC 5398), **documentation prefixes** (RFC 5737 IPv4 / RFC 3849 IPv6), and **lab RPKI** (SLURM-minted VRPs, not real ROAs). Nothing is ever advertised to the real Internet. It gives Region A a self-contained "talks to the world" story that does **not** depend on Region B / DevNet being up.

```text
                        Simulated Internet
                               |
            +------------------+------------------+
            |                                     |
     transit-a-csr  AS 64497            transit-b-iol  AS 64498
     (CSR1000v, primary)                 (IOL-XE, backup)
            |                                     |
       Aurora-PE-1 (SR OS)                  Aurora-PE-3 (IOS-XRv)
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

   rpki-rp1 (Routinator on PC1) ── RPKI-RTR :3323 ──► aurora-pe-3 (+ others)
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

- **GNS3 controller**: `http://192.168.200.2:3080/v2` (Dell-Windows host on the gigabit ethernet link).
- **GNS3 VM**: VMware Workstation appliance on Dell, Tailscale `gns3@100.118.0.46`, **2 physical vCPU / 19 GiB RAM** — the empirical constraint envelope per ADR-002 §3.9.
- **All Region A nodes run on `compute_id: "vm"`** (the GNS3 VM compute). Tenant docker containers and the three FRR IXP containers run on the GNS3 VM's docker daemon (same place as SR Linux).
- **Management plane** (Wazuh, MISP, Cowork, openconnect to DevNet) stays on **PC1** per ADR-002 §6 (v1.5).

## 4. IP and AS plan (Region A slice)

> **Canonical source = THIS section** for Region A (Aurora carrier **AS 64496**, documentation ASNs/prefixes). `docs/ip-plan.md` is the older **ADR-001-era single-region** IP plan (AS65100, `10.1.0.0/16`, 4 routers Mel/Syd/Bri/Gel) and is **superseded for Region A** — it carries a banner pointing here and is pending a v2.0 refresh to the two-region model. Do not pull ASNs/RDs/RTs from `ip-plan.md` for Region A.

| Node | Loopback (Lo0) | Mgmt | Role |
| --- | --- | --- | --- |
| Aurora-P (SR Linux) | 10.0.0.1/32 | 192.168.200.11/24 | IS-IS L2 / LDP only (no BGP) |
| Aurora-PE-1 (SR OS) | 10.0.0.2/32 | 192.168.200.12/24 | iBGP full-mesh PE, Northwind CE peering, Transit-A + IXP |
| Aurora-PE-2 (SR OS) | 10.0.0.3/32 | 192.168.200.13/24 | iBGP full-mesh PE, Helix LAN local VPRN |
| Aurora-PE-3 (IOS-XRv) | 10.0.0.4/32 | 192.168.200.14/24 | iBGP full-mesh PE, spare CE peering, Transit-B + IXP, **future inter-region eBGP to Region B** |
| Northwind CE (FortiGate) | 10.0.1.1/32 | DHCP from PE-1 link | eBGP to PE-1, **AS 64512 (private customer AS — default model, see below)** |
| Spare CE (IOSv, optional) | 10.0.1.2/32 | DHCP from PE-3 link | eBGP to PE-3, AS 64513 (or AS 64502 in the BYO-AS customer scenario) |
| Helix LAN switch (Aruba CX) | n/a (L2) | 192.168.200.16/24 | VLAN 100 (Helix data), VLAN 200 (Helix mgmt) |

**Northwind / customer AS model** (resolves the 64502-vs-64512 ambiguity):
- **Default — private customer CE (AS 64512).** Northwind's FortiGate CE peers eBGP to PE-1 as private **AS 64512**; **Aurora (AS 64496) originates/aggregates the customer's public block** (`203.0.113.128/25`) on PE-1 and advertises it outward. The customer has *no public BGP presence* — the common MSP model. Exercises `remove-private-as`, provider-originated PI/PA space, customer route filtering, FortiGate NAT/security, "customer wants Internet, not their own BGP."
- **Optional experiment — BYO-AS public customer (AS 64502).** A customer that brings its own ASN/prefix and originates it, with Aurora as transit. Stand this up on the **spare IOSv CE** (or a second Northwind mode). Exercises customer prefix-lists, max-prefix, **RPKI origin validation of the customer origin**, no-transit-leak, and customer-origin propagation to transit/IXP. Richer policy surface — kept optional, not the default path.

**Internet Edge AS / addressing** — all ASNs **RFC 5398 documentation ASNs** (64496–64511); all prefixes **RFC 5737 (IPv4) / RFC 3849 (IPv6) documentation space**. (Real Tier-1s use registered public 2-byte ASNs like Telstra AS1221 / Vocus AS4826 — explicitly out of scope; we model the *behaviour* with doc ASNs.)

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

Backbone p2p links: `10.255.0.0/24` /31s (IPv4) + `2001:db8:ffff::/64`-derived /127s (IPv6) — `aurora-p ↔ pe-1` = `10.255.0.0/31`, `↔ pe-2` = `10.255.0.2/31`, `↔ pe-3` = `10.255.0.4/31`.

PE-CE links: `10.255.1.0/24` /30s + matching v6 /127s.

Internet-edge links (dual-stack):
- PE-1 ↔ Transit-A: `10.255.2.0/30` + `2001:db8:ffff:2::/127`
- PE-3 ↔ Transit-B: `10.255.2.4/30` + `2001:db8:ffff:2::2/127`
- IXP peering LAN (`ixp-fabric`): `10.255.3.0/24` — PE-1 `.1`, PE-3 `.3`, RS `.10`, content `.20`, eyeball `.30`; v6 `2001:db8:ffff:3::/64` with matching host IDs.

**RPKI-RTR cache endpoint = `192.168.200.1:3323` (PC1), used everywhere.** `rpki-rp1` (Routinator) runs on **PC1 (192.168.200.1)** and serves RTR on **TCP 3323**. The GNS3 edge routers reach it over their management segment via a GNS3 **Cloud node bridged to the Dell `192.168.200.x` interface** (nodes' mgmt = `192.168.200.11-16`, same /24 as PC1 `.1` / Dell `.2`). Every ROV enforcer configures its RPKI cache server as **`192.168.200.1` port `3323`** — do not use a `10.255.x.x` address for the cache.

Aurora mock public/PI block: `203.0.113.0/25` (TEST-NET-3 — never real, safe for sim). Customer block `203.0.113.128/25`.

**VPRN RD/RT convention** (canonical here; supersedes the `65100:<id>` form in `ip-plan.md`): RD = `64496:<customer_id>`, RT = `target:64496:<customer_id>`. Customer IDs: Northwind 3, Helix 2, Maple Ridge 1 (per `ip-plan.md` §8 numbering, re-based to AS 64496).

## 5. Protocols

| Layer | Choice | Notes |
| --- | --- | --- |
| IGP | **IS-IS L2 wide-metrics** | Single area; metric-style wide on all interfaces; loopbacks announced into IS-IS for LDP and BGP next-hop reachability. |
| Label distribution | **LDP** (not SR-MPLS) | Keeps the v1.0 plan simple; SR-MPLS is a later iteration. LDP transport = Lo0. |
| Backbone overlay | **iBGP full mesh** among PE-1, PE-2, PE-3 (3 sessions) | VPNv4 address family. No route reflector at this size; revisit if Region A grows past ~5 PEs. |
| PE-CE | **eBGP** (Northwind, spare CE); **local VPRN VLAN trunk** (Helix LAN) | eBGP keepalive 30 / holdtime 90 (default). |
| Internet edge | **eBGP** to transits (global table) + **eBGP** to IXP route server | Transit + IXP in the global routing table (not a VPRN). Default route from transits; IXP for specific peer prefixes. Policy in §5.1; RPKI/ROV in §5.2. |
| Authentication | **None in v1.0/v1.1** | TCP-AO / MD5 deferred per ADR-002 §9.6. Region A is a closed lab; auth is a later add. |
| Address family | **IPv4 + IPv6 dual-stack** (v1.1) | Both AFI/SAFI on backbone, PE-CE, and Internet edge. Build Phase B layers v6 after the v4 fabric is up (§6). |
| RPKI / ROV | **Routinator (RP) + SLURM lab VRPs + RPKI-RTR; ROV-enforce at the edge** (v1.1) | First enforcer `aurora-pe-3`; full design in §5.2. Build Phase C. |
| Tenant services | **VPRN per tenant** on each PE that hosts the tenant | Northwind VPRN on PE-1; Helix VPRN on PE-2; Maple Ridge VPRN on PE-3 (when Region B is down and the spare CE is hosting Maple Ridge traffic). |

### 5.1 Internet-edge BGP policy

The policy is what makes the Internet Edge a *demonstration* rather than just extra nodes. Applied on Aurora-PE-1 (Transit-A + IXP) and Aurora-PE-3 (Transit-B + IXP):

| Rule | Mechanism | Demonstrates |
| --- | --- | --- |
| **Prefer IXP routes** for content/eyeball prefixes | LOCAL_PREF 300 on IXP-learned (`ixp-content1`, `ixp-eyeball1`) prefixes | "peer where you can, transit where you must" — IXP is cheaper than transit |
| **Transit-A is primary default** | LOCAL_PREF 200 on Transit-A-learned `0.0.0.0/0` | primary/backup transit selection |
| **Transit-B is backup default** | LOCAL_PREF 100 on Transit-B-learned `0.0.0.0/0` | failover: kill Transit-A → Transit-B default wins |
| **Advertise outward only approved prefixes** | outbound prefix-list = Aurora mock PI `203.0.113.0/25` (+ `2001:db8:aaaa::/48`) + customer aggregates ONLY | no accidental transit (Aurora is not a transit provider for its upstreams) |
| **No transit routes to IXP peers** | outbound filter on the IXP session drops anything learned from a transit AS | settlement-free peering hygiene — you don't give IXP peers free transit |
| **Max-prefix cap per transit** | `maximum-prefix` ~200 on each transit session (well above the ~10 mock prefixes, low enough to catch a full-table leak) | real carriers always cap transit to survive a misconfigured upstream |
| **Reject RPKI-invalid** at the edge | drop routes whose ROV state = Invalid (see §5.2); de-preference is the softer alternative | modern edge security — origin hijack rejection |
| **Bogon / martian filter** | inbound prefix-list drops RFC1918, default-from-IXP, and the mock-PI block from peers | basic edge hygiene, complements RPKI |
| **Don't leak IXP→transit** | outbound filter on transit sessions drops IXP-peer-learned routes (except an explicit, labelled route-leak *demo*) | you don't give your transit your peers' routes for free |

LOCAL_PREF hierarchy in one line: **IXP (300) > Transit-A (200) > Transit-B (100)**. Best path for a content prefix = via IXP; best path for everything else = Transit-A default; lose Transit-A = Transit-B default. RPKI-Invalid routes are dropped *before* best-path runs.

### 5.2 RPKI / ROV (lab, via Routinator + SLURM)

Real route-origin-validation workflow without paying an RIR. Build Phase C — layer this only after the IPv4+IPv6 BGP fabric (§6 Phases A/B) is converged.

**Components and roles** (terminology kept precise):

| Component | Role | Node |
| --- | --- | --- |
| **Routinator** (NLnet Labs) | **RPKI validator / Relying Party (RP)** — produces Validated ROA Payloads (VRPs), serves them over RPKI-RTR (RFC 8210, TCP 3323) | `rpki-rp1` (docker on **PC1**) |
| **SLURM** (RFC 8416) | local exceptions file — `locallyAddedAssertions` mint VRPs for the documentation prefixes (no real ROAs exist for doc space); `prefixAssertions` map each doc prefix → its correct origin AS | config on `rpki-rp1` |
| **ROV enforcer** | router as **RTR client** — classifies received routes Valid / Invalid / NotFound vs the VRPs, applies policy | `aurora-pe-3` (IOS-XRv 6.1.3) first; others as support allows |

**SLURM VRP set** (one assertion per legitimate origin, so we can then forge an Invalid):

| Prefix | Correct origin AS | Used to test |
| --- | --- | --- |
| `203.0.113.0/25` + `2001:db8:aaaa::/48` | 64496 (Aurora) | Valid |
| `198.51.100.0/25` + `2001:db8:c0::/48` | 64500 (content) | Valid; **forge from 64501 → Invalid** |
| `198.51.100.128/25` + `2001:db8:e0::/48` | 64501 (eyeball) | Valid |
| `192.0.2.0/24` slices | (intentionally **no** VRP) | NotFound |

**Enforcement is phased; the design target is ROV at *every* eBGP ingress.** Real networks roll ROV out one platform at a time (mixed-vendor capability gaps), so we mirror that:

- **Phase C1 — XR-only.** Enforce ROV on **`aurora-pe-3` (IOS-XR 6.1.3, mature RTR/ROV)** and prove Valid/Invalid/NotFound here first. Fast, certain success.
- **Phase C2 — FRR reference enforcer** for the IXP side (and as the reference implementation). **FRR's `rpki` module is CONFIRMED present** in the official image — `librtr.so.0.8.0` (rtrlib) ships in `frrouting/frr:latest`; §10 smoke test passed.
- **Phase C3 — all eBGP ingress.** Enforce on Transit-A@PE-1, Transit-B@PE-3, IXP@PE-1 and PE-3. **SR OS supports origin-validation** (Nokia feature since release **12.0R1** — RTR `rpki-session` + route-policy `from validation-state {valid|invalid|not-found}`), so 13.0R4 PEs *can* enforce. (Live CLI confirmation on our node is deferred to the **GUI console at build time** — headless telnet was blocked by the single-client serial clog; feature availability is not in doubt.)

> **⚠ Enforcement gap to mind (review finding, HIGH).** Until C3, **PE-1 also ingests Transit-A + IXP without ROV**, so an Invalid route entering via PE-1 would be accepted and propagated internally before PE-3 ever sees it. Keep the C1 demo honest one of two ways: **(a)** introduce the forged-Invalid route **only through a PE-3-facing session**, or **(b)** add PE-1 as an enforcer (or an FRR ROV node in front of it) early. The C3 target closes the gap by enforcing at every ingress.

**Reject vs de-prefer**: v1.1 default is **reject** Invalid at the edge (cleaner demo); de-preference (set low LOCAL_PREF on Invalid, keep as last resort) is the documented softer alternative for a "graceful rollout" scenario.

**Test matrix** (the point of the whole exercise — for C1, introduce the Invalid via PE-3 only):

| State | Setup | Expected on enforcer |
| --- | --- | --- |
| **Valid** | content prefix originated by 64500 (matches VRP) | accepted, normal best-path |
| **Invalid** | re-originate the content prefix from `ixp-eyeball1` (64501) — wrong origin | **rejected** (or de-preferenced) — does not win best-path |
| **NotFound** | `192.0.2.0/28` slice from `192.0.2.0/24` (no VRP minted) | accepted but marked NotFound; policy treats as normal (don't reject NotFound) |

**Guardrail**: documentation prefixes/ASNs and SLURM VRPs are lab-only — they must **never** be advertised toward any real Internet path (there is none in Region A, but the rule is stated so it survives a future Region B / cloud interconnect).

## 6. Bring-up procedure (staggered waves per ADR-002 §3.9.4)

The wave-stagger rule is the operational core of this plan. Cold-starting all ~13 nodes simultaneously is what spikes the GNS3 VM load past safe levels and can crash gns3server. Each wave waits for the previous wave's protocols to converge.

> **Convergence gate between waves**: the next wave starts only when every node in the current wave passes its smoke test (§7). Estimated total cold-start time: **~18 min** (five waves).

> **Build phasing (distinct from cold-start waves).** *Waves* = the order you power nodes on each time. *Phases* = the order you build/configure capability the first time. Build in this order so each layer is debuggable on a stable base:
> - **Phase A — IPv4 BGP fabric**: backbone IS-IS/LDP, iBGP VPNv4, eBGP CE, eBGP transit + IXP, LOCAL_PREF policy. Get the whole IPv4 control plane converged and the §7 IPv4 smoke tests green *before* touching v6 or RPKI.
> - **Phase B — IPv6 dual-stack**: add v6 AFI/SAFI on backbone, PE-CE, transit, IXP; mirror the policy. Re-run smoke with the v6 prefixes.
> - **Phase C — RPKI/ROV**: stand up `rpki-rp1` (Routinator + SLURM) on PC1, wire the Cloud-node reachability, point `aurora-pe-3` at the RTR cache, run the valid/invalid/notfound matrix (§5.2).
>
> Layering RPKI onto a not-yet-converged fabric is miserable to debug — Phase C is last on purpose.

### Wave 1 — Backbone IS-IS/LDP core (~5 min)

Nodes: `aurora-p`, `aurora-pe-1`, `aurora-pe-2`.

```
# From the controller (PowerShell on Dell-Windows or curl from PC1)
POST /v2/projects/{region-a}/nodes/{aurora-p}/start
POST /v2/projects/{region-a}/nodes/{aurora-pe-1}/start
POST /v2/projects/{region-a}/nodes/{aurora-pe-2}/start
```

**Wait until** all three are at a console prompt (~2-3 min for SR OS, ~30 s for SR Linux), then:

- Aurora-PE-1: `show router isis adjacency` → adjacency to `aurora-p` Up; `show router ldp session` → session to P Established.
- Aurora-PE-2: same as PE-1.
- Aurora-P: `show network-instance default protocols isis adjacency` (SR Linux) — both PEs listed.

### Wave 2 — Cisco interop PE (~3 min)

Nodes: `aurora-pe-3` (IOS-XRv 6.1.3). (The optional `region-a-ce-spare` IOSv is bring-up-on-demand — start it here only if a third CE flavour is wanted.)

```
POST /v2/projects/{region-a}/nodes/{aurora-pe-3}/start
```

**Wait until** XRv reaches `RP/0/RP0/CPU0:ios#`, then:

- PE-3: `show isis adjacency` → adjacency to Aurora-P Up; `show mpls ldp neighbor` → P session Operational; `show bgp vpnv4 unicast summary` → both SR OS PEs Established.

### Wave 3 — Customer-facing (~3 min)

Nodes: `northwind-ce` (FortiGate), `helix-lan-sw` (Aruba CX).

```
POST /v2/projects/{region-a}/nodes/{northwind-ce}/start
POST /v2/projects/{region-a}/nodes/{helix-lan-sw}/start
```

**Wait until** FortiGate reaches login (`admin` / `<your-password>`) and Aruba CX reaches `(mgmt)#` (`admin` default), then:

- FortiGate: `get router info bgp summary` → eBGP to PE-1 Established.
- Aruba CX: `show vlan` → VLANs 100/200 present; `show lldp neighbor-info` → uplink to PE-2 seen.
- PE-1: `show router bgp neighbor 10.255.1.1` → Northwind CE Established, prefixes received.
- PE-2: `show service vprn helix interface` → VPRN up, VLAN trunk to Aruba CX live.

### Wave 3.5 — Internet Edge (~3 min)

Nodes: `transit-a-csr` (CSR1000v), `transit-b-iol` (IOL), `ixp-fabric` (switch — instant), `ixp-rs1` / `ixp-content1` / `ixp-eyeball1` (FRR docker). The fabric switch and FRR containers boot in seconds; the two Cisco transits are the pace-setters.

```
POST /v2/projects/{region-a}/nodes/{ixp-fabric}/start
POST /v2/projects/{region-a}/nodes/{transit-a-csr}/start
POST /v2/projects/{region-a}/nodes/{transit-b-iol}/start
POST /v2/projects/{region-a}/nodes/{ixp-rs1}/start
POST /v2/projects/{region-a}/nodes/{ixp-content1}/start
POST /v2/projects/{region-a}/nodes/{ixp-eyeball1}/start
```

**Wait until** both transits reach a prompt and FRR containers are up (`docker ps`), then:

- PE-1: `show router bgp neighbor 10.255.2.1` → Transit-A Established; `show router route-table 0.0.0.0/0` → default present via Transit-A (LOCAL_PREF 200).
- PE-3: `show bgp ipv4 unicast neighbors 10.255.2.5` → Transit-B Established; default present (backup, LOCAL_PREF 100).
- PE-1 / PE-3: BGP session to `ixp-rs1` (`10.255.3.10`) Established; content/eyeball prefixes received via the route server.
- `ixp-rs1` (FRR): `vtysh -c "show bgp summary"` → 4 neighbours Established (PE-1, PE-3, content, eyeball).
- Route preference check: on PE-1, `show router route-table 198.51.100.0/28` (a content /28) → next-hop via `ixp-fabric` (LOCAL_PREF 300), **not** via a transit. This is the "peer-over-transit" proof.

### Wave 4 — Tenant workload containers (~2 min)

Lightest of the four waves; can be parallelised. Bring up Helix and Northwind container sets via docker compose on the GNS3 VM:

```
ssh gns3@100.118.0.46
cd /opt/gns3/projects/{region-a}/docker
docker compose -f region-a-workloads.yml up -d
```

Verify:

- `docker ps` shows all 8 containers Running.
- From `helix-doctor-wks`: `iperf3 -c <helix-emr-ip>` and `curl http://<orthanc-ip>:8042/system` both succeed.
- From `northwind-dev-wks`: `curl http://<grafana-ip>:3000/api/health` returns ok.

### Total fabric verification (end of cold start)

- All four backbone nodes see expected IS-IS adjacencies and LDP sessions.
- iBGP VPNv4 mesh has all 3 sessions Established.
- eBGP CE session(s) Established (Northwind; spare CE if started).
- VPRNs Northwind (PE-1) and Helix (PE-2) show route counts > 0.
- **Both transit sessions Established; default route present (Transit-A primary, Transit-B backup).**
- **IXP route server has 4 sessions; content/eyeball prefixes prefer IXP over transit.**
- An ICMP from `helix-doctor-wks` to a mock Internet /28 (e.g. `192.0.2.0/28`, originated by `transit-a-csr`) succeeds — validates the end-to-end service chain **all the way to simulated Internet egress**.

## 7. Smoke tests (per-node)

Compact reference; expand into Ansible playbooks as the topology stabilises.

| Node | Command | Expected |
| --- | --- | --- |
| Aurora-P (SR Linux) | `sr_cli -c "show network-instance default protocols isis adjacency"` | 3 adjacencies (PE-1, PE-2, PE-3) Up |
| Aurora-PE-1/PE-2 (SR OS) | `show router isis adjacency` | Adj to P Up |
| Aurora-PE-1/PE-2 (SR OS) | `show router ldp session` | Session to P Established, labels exchanged |
| Aurora-PE-1/PE-2 (SR OS) | `show router bgp summary` | 2 iBGP neighbours Established; VPNv4 prefixes > 0 |
| Aurora-PE-3 (IOS-XR) | `show isis adjacency` / `show mpls ldp neighbor` | Both Up |
| Aurora-PE-3 (IOS-XR) | `show bgp vpnv4 unicast summary` | 2 iBGP neighbours Established |
| Northwind CE (FortiGate) | `get router info bgp summary` | eBGP to PE-1 Established |
| Spare CE (IOSv, if up) | `show ip bgp summary` | eBGP to PE-3 Established |
| Helix LAN (Aruba CX) | `show vlan` / `show lldp neighbor-info` | VLAN 100/200 active; uplink LLDP visible |
| Transit-A (PE-1 view) | `show router bgp neighbor 10.255.2.1` | Established; `0.0.0.0/0` received, LOCAL_PREF 200 |
| Transit-B (PE-3 view) | `show bgp ipv4 unicast neighbors 10.255.2.5` | Established; `0.0.0.0/0` received, LOCAL_PREF 100 (backup) |
| IXP route server (`ixp-rs1`) | `vtysh -c "show bgp summary"` | 4 neighbours Established (PE-1, PE-3, content, eyeball) |
| IXP route preference (PE-1) | `show router route-table 198.51.100.0/28` (content /28) | next-hop via `ixp-fabric` (LOCAL_PREF 300), not a transit |
| Transit failover | shut Transit-A session on PE-1 → `show router route-table 0.0.0.0/0` | default reconverges to Transit-B (LOCAL_PREF 100) |
| Egress reachability | from a tenant workload: `ping <mock Internet /28 .1>` | succeeds via Transit-A |
| IPv6 dual-stack (PE-3) | `show bgp ipv6 unicast summary` / `ping6 <2001:db8:a::1>` | v6 sessions Established; v6 egress works |
| Routinator (`rpki-rp1`) | `routinator vrps \| wc -l` | VRP count > 0 (SLURM assertions loaded) |
| RTR session (PE-3) | `show rpki server` (IOS-XR) | cache `192.168.200.1:3323` (PC1) ACTIVE; records loaded |
| ROV Valid | content prefix from 64500 | `show bgp <pfx>` → origin-AS **valid**, installed |
| ROV Invalid | re-originate content prefix from 64501 | origin-AS **invalid** → **rejected** (not best-path) |
| ROV NotFound | a `192.0.2.0/24` slice (no VRP) | origin-AS **not-found** → accepted, normal policy |
| Any tenant workload | `ping <gateway>` then `curl <peer service>` | both succeed |

## 8. Operations

### 8.1 Daily verify (no changes)

```
# From PC1 or Dell-Windows, with controller reachable
curl http://192.168.200.2:3080/v2/projects/{region-a}/nodes | jq '.[] | {name, status}'
# All nodes "started"
```

Run the §7 smoke tests in 5 min. If anything's drifted (CE BGP flap, VPRN missing prefix), escalate to §8.3 or §8.4.

### 8.2 Update a node — no service impact (PE-2 example)

When the change is config-only (no template change, no NOS upgrade):

```
ssh into the node via its mgmt IP → edit config → commit → verify §7 smoke for that node.
```

No restart needed; iBGP and IS-IS absorb the change.

### 8.3 Update a node — with service impact (PE-1 example, template change)

When the change touches the GNS3 template (RAM, vCPU, QEMU options):

1. Drain traffic away (Northwind CE BGP holdtime → 30 s, or shut the CE-PE link).
2. Stop PE-1 via the GNS3 API.
3. Update template; PUT the node properties.
4. Start PE-1.
5. Wait for IS-IS, LDP, iBGP, eBGP to reconverge.
6. Restore traffic (re-enable CE-PE link).
7. §7 smoke on PE-1 and Northwind CE.

Helix traffic continues via PE-2 throughout (the architectural reason PE-1 and PE-2 both exist).

### 8.4 Cold shutdown (reverse-wave order)

Wave 4 → Wave 3.5 → Wave 3 → Wave 2 → Wave 1. Each wave: stop nodes, wait for them to confirm `stopped`, then next wave.

This is important because gns3server can mis-record node status if it's shutting down qemu processes faster than it polls them — close+reopen the project after shutdown if any nodes show stale "started" (per `memory/gns3-vm-ram-budget.md`).

### 8.5 Cold start

Forward-wave order per §6. Do not skip the convergence gates — that's what breaks the box.

### 8.6 Bringing up a singleton heavyweight (FTDv / Cat9kv / FMC / XRv9k / PA-VM 11)

**Region A must be down.** Use §8.4 to shut down the fabric first, then start the singleton. See `memory/gns3-nos-boot-quirks.md` for per-singleton recipes. Restore Region A via §8.5 when done with the singleton demo.

### 8.7 Persistence

- GNS3 saves project + node state to the GNS3 VM's `/opt/gns3/projects/<region-a>/` directory.
- Per-node disks persist across `stop`/`start` (including FortiGate's `hdb` data disk).
- Tenant docker volumes persist if defined in the docker-compose file with named volumes.
- **Backup target**: rsync `/opt/gns3/projects/<region-a>/` to Dell `E:\aurora-backups\` after major changes. Region A's running state should be reconstructible from `clab-region-a.yml` (TODO §10) + per-node config files; the GNS3 project export is the belt-and-braces.

## 9. What's NOT in v1.0 (deferred / out of scope)

- **Singleton heavyweights** (FTDv, Cat9kv, FMC, XRv9000, PA-VM 11). Available on-demand per §8.6; never part of the running Region A.
- **Region B (DevNet CML)** — separate plan. ADR-002 §3.2 + §10 Phase 3 cover the design.
- **Inter-region BGP confederation** (Aurora-PE-3 → Region B PE pair over openconnect-on-PC1). Comes in v2.0 of this plan once Region B is up and the openconnect bridge is configured on PC1 per ADR-002 §6.
- **Authentication** (TCP-AO/MD5 for IS-IS and BGP). Deferred per ADR-002 §9.6.
- **Maple Ridge workload containers**. Live with the Region B Maple Ridge CE; not duplicated in Region A.
- **VyOS optional CE** (mentioned in ADR-002 §3.1). Not validated yet; add as a v1.1 light if/when there's a use case.
- **§3.7 advanced workloads** — Mirth/Synthea HL7 simulators, full Prometheus alert rules. v1.0 uses nginx-mock + Orthanc + alpine+iperf3 only; richer workloads are a §3.7.4 phasing item.
- **ZTP / auto-config**. Region A is small enough that manual per-node config templates are fine for v1.0.
- **Internet-edge advanced policy** — BGP communities for traffic engineering, MED tuning, selective bilateral IXP peering (direct PE↔content session bypassing the RS), and a second diverse transit for full multi-homing/TE. (Transit + IXP + RPKI/ROV + IPv6 are **in v1.1**; these are the next layer.)
- **Real public ASNs / registered RIR ROAs / advertising to the real Internet.** v1.1 uses documentation ASNs (RFC 5398), documentation prefixes (RFC 5737/3849), and SLURM-minted lab VRPs — a faithful *behavioural* model with zero real-world footprint. Going real would require registered resources and is explicitly out of scope.

## 10. Open follow-ups

- **`region-a-nokia/clab-region-a.yml`** — author the GNS3 project export (or a containerlab YAML if we ever want to round-trip Region A to containerlab on PC1 as the failover/portable copy).
- **`region-a-nokia/configs/`** — per-node config templates (one per NOS); Jinja2 with the IP/AS table from §4 as the inventory.
- **`region-a-nokia/ansible/`** — playbook for `make region-a-up` (wraps §6 wave logic), `make smoke` (wraps §7), `make region-a-down` (wraps §8.4). Hook into existing Makefile if present.
- **Helix LAN behaviour when Region B comes up** — when Region B's Helix CE is reachable via GRE, the standalone-mode local VPRN on Aurora-PE-2 should switch to forwarding-only (no local BGP advert) so Region B's CE owns the Helix routing. Document the mode-switch procedure.
- **Workload upgrade path** — Phase 3 of §3.7 in ADR-002 calls for Orthanc + Mirth + Synthea for Helix and full Prometheus alerting for Northwind; phasing.
- **Backup / restore drill** — verify §8.7 rsync + GNS3 project import round-trip.
- ✅ **FRR-in-GNS3-docker + rpki module — DONE (2026-06-08).** `frrouting/frr:latest` (Docker Hub) pulled on the GNS3 VM; **`librtr.so.0.8.0` (rtrlib) ships in the image → RPKI module supported.** quay.io has FRR under version tags (10.2–10.6, `master`), not `:latest` — pin `quay.io/frrouting/frr:10.6.1` or use Docker Hub `:latest`. Still TODO: boot one as an actual GNS3 docker node + a basic eBGP session (the *image* is cleared; the *GNS3 node wiring* is a quick build-time check).
- ✅ **SR OS 13.0R4 RPKI — resolved via Nokia release history.** Origin-validation (RTR `rpki-session` + route-policy `from validation-state`) is a Nokia feature since **12.0R1**, so 13.0R4 supports it. Live CLI confirmation on our node deferred to the **GUI console at build time** (headless telnet was blocked by the single-client serial clog — see `memory/gns3-nos-boot-quirks.md`). Not a blocker for the plan.
- **RPKI/ROV build (Phase C)** — deploy Routinator on **PC1 (192.168.200.1)** as a docker container; author the **SLURM exceptions file** (`locallyAddedAssertions` for the §5.2 VRP set); wire a **GNS3 Cloud node** bridging the topology mgmt segment to `192.168.200.x` so the edge routers reach RTR **`192.168.200.1:3323`**; configure `aurora-pe-3` (C1) then all eBGP ingress (C3) as RTR clients + ROV policy; run the valid/invalid/notfound matrix.
- **`ip-plan.md` v2.0 refresh** — fold the two-region (ADR-002) AS/IP/RD-RT model into `ip-plan.md` so it becomes truly canonical again, or formally retire it in favour of per-region plan §4s. Currently it carries a superseded banner pointing here.
- **Internet-edge v1.2 roadmap** — BGP communities for TE; second diverse transit for true multi-homing; selective bilateral IXP peering; deliberate route-leak demo; routing-protocol authentication.

## 11. References

- `docs/adr-002-two-region.md` — §3.1 Region A intent, §3.9 Dell capability envelope and operational rules, §6 VPN endpoint (PC1).
- `docs/design.md` — protocol-level Aurora design (IS-IS, LDP, BGP VPNv4 conventions).
- `docs/ip-plan.md` — canonical IP and AS plan; cross-referenced in §4.
- `docs/runbook.md` — generic operational runbook; this doc is the Region-A-specific instance.
- `memory/sros-gns3-license-recipe.md` — SR OS RTC-frozen license recipe (UUID 0…0 + 2015-03-10).
- `memory/gns3-nos-boot-quirks.md` — per-NOS boot recipes and gotchas (SR Linux USER fix, FortiGate hdb disk, Aruba CX trial license).
- `memory/gns3-vm-ram-budget.md` — RAM/CPU rules, OOM behaviour, stale-status recovery.
- `memory/aurora-image-version-choices.md` — PA-VM 11.0.0, IOS-XRv 6.1.3, Aruba CX 10.16.1040 — image versions used in this plan.
- `memory/aurora-dell-access-facts.md` — Dell access (Tailscale, ethernet, E:, GNS3 API).

**Standards (Internet Edge / RPKI):**
- **RFC 5398** — documentation ASNs (16-bit `64496-64511`, 32-bit `65536-65551`). Used for all Internet-edge ASNs.
- **RFC 6996** — private-use ASNs (`64512-65534`, `4200000000-4294967294`). Used only for the customer-private ASNs (Northwind 64512 etc.), not the documentation edge.
- **RFC 5737** — IPv4 documentation prefixes (`192.0.2.0/24`, `198.51.100.0/24`, `203.0.113.0/24`). All mock IPv4 carved from these.
- **RFC 3849** — IPv6 documentation prefix (`2001:db8::/32`). All mock IPv6 carved from this.
- **RFC 8210** — RPKI-to-Router (RTR) protocol. The cache→router feed (TCP 3323).
- **RFC 8416** — SLURM (Simplified Local Internet Number Resource Management). Local VRP assertions/filters for lab RPKI.
- **Routinator** (NLnet Labs) — RPKI Relying Party / validator; supports `--exceptions` (SLURM) and built-in RTR server.
