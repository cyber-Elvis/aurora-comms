# ADR-002 — Two-region Aurora carrier (Nokia local + Cisco-dominant DevNet CML)

| Field | Value |
| --- | --- |
| Status | Accepted |
| Version | 1.2 |
| Date | June 2026 |
| Supersedes | ADR-001 v1.6 single-region MSP carrier decision |
| Triggered by | Empirical DevNet integration validation per ADR-001 §17.6 (May 31 2026) |
| Decision | Aurora carrier deployed across two regions — Nokia region locally on home lab, Cisco-dominant region in Cisco DevNet CML — interconnected at the region boundary via openconnect-in-WSL2 + Docker MASQUERADE + eBGP |
| Owner | Lab architecture (Elvis Ifeanyi Nwosu) |
| Related | `docs/lab-architecture.md` (ADR-001 v1.6), `docs/design.md`, `docs/ip-plan.md`, `BACKLOG.md` |

## Revision history

| Version | Date | Change |
| --- | --- | --- |
| 1.2 | Jun 7 2026 (early hours) | **Region A SR OS host = Dell GNS3, not Dell-WSL.** The June 6 Dell migration (per `dell-migration-plan.md`, to host Region A vrnetlab on Dell-WSL) ran and hit a hard limit: **Dell-WSL cannot provide `/dev/kvm`** — `wsl: Nested virtualization is not supported on this machine`. Root cause is **Windows 10** (WSL2 nested virtualization is a Windows 11-only feature) on a **Skylake i5-6300U** (not Win11-eligible); VBS also running. Not practically fixable. Consequence: the §3.1 VM-based NOSes (SR OS PE-1/PE-2, and any vrnetlab firewall) **cannot run under Dell-WSL**. **Resolution:** SR OS PEs (and Region-A firewalls) run in **Dell's GNS3** instead — QEMU + WHPX host-level acceleration on the Windows host, which works on Win10 and is already license-valid. **Dell-WSL** hosts the container-native **Aurora-P (SR Linux)** + tenant/container workloads (smoke-tested working, no KVM). All 6 vrnetlab images were transferred to Dell (ethernet, staged on E:) and loaded as **cold-storage/failover**; the runnable vrnetlab VM-NOS source-of-truth remains on **PC1** (Ryzen, KVM works). §3.1's role assignments are unchanged in intent — only the SR OS *hypervisor substrate* on Dell changes from WSL2/vrnetlab to GNS3/WHPX. Operational facts (users, ethernet `192.168.200.x` link, Tailscale `100.107.71.87`, E: storage) captured in `aurora-deployment-status.md` and `memory/`. |
| 1.1 | May 31 2026 (late evening) | Same-day refinement batch following four architectural reconsiderations: (a) **FortiGate-VM 7.0.14 reassigned from Maple Ridge perimeter → Northwind CE** as a consolidated CE + SD-WAN (FortiSD-WAN native) + NGFW appliance — single-appliance branch consolidation matches Northwind's tech-forward persona and resolves the EdgeConnect EC-V access gap. (b) **HPE Aruba EdgeConnect EC-V deferred to W4+** pending HPE Aruba sales-engagement trial (commercial product, ~2-6 week procurement); FortiGate covers the SD-WAN demonstration story until EdgeConnect access materialises. (c) **Maple Ridge perimeter security simplified to IOS XE zone-based firewall (ZBFW) on the existing Cat8000v CE** — persona-aligned (Maple Ridge values pragmatic carrier-managed CE with integrated security over a separate dedicated NGFW); supplemental cloud-delivered security via Cisco Umbrella DNS through §3.6 DevNet ancillary integrations. (d) **Palo Alto VM-Series 9.0.4 OVA acquired** (`/Software images/PA-VM-ESX-9.0.4.ova`, 3.1 GB, May 31 2026); 30-day evaluation authcode requested from Palo Alto Networks via the standard eval program — unlicensed mode supports zones, security policy, BGP, OSPF, NAT, virtual routers for Monday's interview demo; subscription features (Threat Prevention, URL Filtering, WildFire, DNS Security, GlobalProtect) activate when authcode arrives within ~24-72 hours. **NEW §3.7 — Tenant Workload Layer**: lightweight per-tenant Linux containers (Helix: Orthanc DICOM + HL7 simulator + nginx EMR-mock; Maple Ridge: nginx ERP-mock + PostgreSQL + CoreDNS; Northwind: nginx SaaS-mock + Redis + Prometheus/Grafana) attached to each LAN segment as traffic sources/sinks for end-to-end demonstrations of App-ID, security policy, URL filtering, and latency/throughput. Total ~2 GB RAM cost across all tenants. **NEW §3.8 — Data Centre Compute Domain**: Cisco UCS Platform Emulator (UCSPE) for service profile management plane fluency, Linux compute host running §3.7 workload containers, DMTF Redfish mockup as vendor-agnostic out-of-band management API — demonstrates server architecture fluency without physical hardware. HPE OneView trial deferred to W3+. Mermaid topology in §3.3a regenerated for FortiGate at Northwind, Palo Alto at Helix Health CE, IOS XE ZBFW annotation at Maple Ridge, and tenant workload + DC compute nodes. §9 constraint added for Palo Alto evaluation-mode licensing window. §13 risks expanded for EdgeConnect deferral and PA-VM authcode delivery timing. |
| 1.0 | May 2026 | Initial — full pivot from ADR-001 single-region to two-region carrier with DevNet CML hosting the Cisco-dominant region. Architectural decision driven by May 31 2026 empirical validation that openconnect-in-WSL2 + containerlab + Docker MASQUERADE provides clean L3+L7 reach into DevNet sandbox environments. Same-evening refinements baked in before initial publish: (a) Region A all-Nokia hybrid (SR Linux P + 2× SR OS PEs, single-homed CEs accepting tier-2 single-PE-failure tolerance); (b) Region B dual-router-per-site (Aurora-DC P pair both XR, Aurora-MR PE pair mixed XR + XE reflecting gradual modernisation, Aurora-HH PE pair pure XR for regulated-industry audit consistency) with dual-homed CEs (Maple Ridge active-active multipath, Helix Health active-standby LOCAL_PREF); (c) Helix Health LAN switch (HPE Aruba CX) moved to Region A and reached from Region B's Helix Health CE via GRE-over-IPSec tunnel — CML is Cisco-only natively, so the cross-region pattern demonstrates real MSP customer-LAN extension behaviour; (d) Northwind CE replaced from MikroTik CHR (1 JD, 0.4% market presence) to HPE Aruba EdgeConnect EC-V — covers HP/Aruba (8 JDs / 3.6%) and Silver Peak/EdgeConnect (2 JDs / 0.9%) market gaps and adds SD-WAN story; (e) NEW §3.5 Tenant security, wireless, and ancillary services with market-aligned vendor selection per tenant: FortiGate-VM for Maple Ridge (Fortinet 21 JDs / 9.4% — #2 vendor gap), Palo Alto VM-Series for Helix Health (11 JDs / 4.9%), F5 BIG-IP load balancer for tenant DC scenarios, HPE Aruba Wireless documented architecturally; (f) NEW §3.6 DevNet sandbox ancillary integrations for vendors that don't fit in the topology directly — Cisco Meraki (10 JDs), Catalyst Center + WLC (6 JDs), Cisco AnyConnect (2 JDs), NSO, ACI, Firepower. Lab now provides ~65% weighted coverage of top vendor demand from a 224-JD May 2026 Australian network engineering market scan. Topology diagram in §3.3a updated with per-site subgraphs, GRE cross-region tunnel, FortiGate/Palo Alto perimeter annotation, EdgeConnect at Northwind CE, and platform colour coding. |

## 1. Context

ADR-001 (v1.0 through v1.6) designed Aurora Communications as a single-region MSP carrier hosted entirely on local hardware. The vendor strategy was Cisco-first with HPE Networking (Aruba + Juniper post-merger) as the second-vendor demonstrator and a single Nokia PE for SP-side multi-vendor interop. The active-lab pool on PC1 was constrained to 6 GB at peak — tight enough that demos required workload cycling (Cowork closure, Docker Desktop closure) per ADR-001 §10 constraints.

On May 31 2026, an empirical DevNet integration diagnostic (ADR-001 §17.6) confirmed that:

- `openconnect` installed inside Ubuntu WSL2 establishes `tun0` in the WSL2 routing namespace
- Docker's default MASQUERADE rules transparently NAT containerlab containers' source addresses to the WSL2 host's tun0 IP
- DevNet sandbox devices reply normally; container-to-DevNet reachability is verified at L3 and L7 (HTTPS to embedded CML returned HTTP 200)
- The Cisco SD-WAN sandbox's embedded CML server at `10.10.20.161` is accessible to the local lab via this path and gives operator-controlled topology hosting

This validation enables a fundamentally better architecture: instead of cramping the full multi-vendor carrier into the local Dell's 14 GB Aurora workload pool, the **Cisco-dominant portion of the backbone runs in Cisco-hosted infrastructure (free via DevNet)** while the **Nokia portion remains local** as the resource-light operational anchor.

This mirrors how real Australian regional and national carriers structure their backbones — Telstra, Optus, NBN Co, and TPG all operate multi-region, multi-vendor backbones where regional choices are driven by historic vendor relationships, cost, and operational specialisation rather than monoculture.

## 2. Hardware envelope (unchanged from ADR-001)

PC1 (Ryzen 7 2700, 32 GB), Dell (i5-6300U, 32 GB), Surface Pro (8 GB) — per ADR-001 §2. The pivot does not change hardware. It changes workload placement.

## 3. Two-region architectural model

### 3.1 Region A — Nokia (Local)

Aurora's Nokia-flavoured region, hosted entirely on local hardware. **All-Nokia stack** with single-homed CEs accepting that single-PE-failure tolerance is the appropriate level for this region's customers.

| Role | Implementation | RAM | Notes |
| --- | --- | --- | --- |
| Aurora-P | **Nokia SR Linux 24.10.1** | ~1-1.5 GB | Container-native data plane. Pulled from `ghcr.io/nokia/srlinux` per ADR-001 §15.5. Fast boot, lightweight, runs the IGP and label distribution backbone. |
| Aurora-PE-1 | **Nokia SR OS 13.0 R4** (TiMOS, on-disk demo license per ADR-001 §10 #12) | ~2-3 GB | Primary PE — classic SR OS carrier OS for tenant VPRN and BGP peering |
| Aurora-PE-2 | **Nokia SR OS 13.0 R4** | ~2-3 GB | Secondary PE — RTC-frozen license shared with PE-1. Same platform for operator-skill consistency. |
| Customer-edge devices | Single-homed per tenant (mixed vendors) | ~500 MB-1 GB each | See per-tenant table below |

**Customer-edge devices in Region A** (single-homed to designated PE):

| Tenant CE | CE platform | Connected to | PE-CE protocol | Justification |
| --- | --- | --- | --- | --- |
| **Northwind CE** | **Fortinet FortiGate-VM 7.0.14** (`vrnetlab/vr-fortios:7.0.14` built May 31 2026) — consolidated CE + SD-WAN + NGFW | Aurora-PE-1 (single uplink) | eBGP CE-PE + FortiSD-WAN overlay (native to FortiOS) | Northwind Tech persona prefers consolidated single-appliance stacks (typical for modern tech-forward orgs). FortiGate-VM at Northwind covers three roles at one hop: routing/eBGP, FortiSD-WAN overlay (modern SD-WAN demo), and NGFW perimeter. Covers Fortinet (21 JDs / 9.4% — #2 vendor in market scan) — the single highest-impact firewall gap to close in the lab. HPE Aruba EdgeConnect EC-V was the v1.0 choice but is gated by HPE Aruba sales-engagement trial (~2-6 week procurement) and deferred to W4+; FortiGate at Northwind carries the SD-WAN narrative until EC-V access materialises. |
| Optional spare CE | VyOS or FRR | Aurora-PE-2 (single uplink) | OSPF CE-PE | Open-source CE for offline-friendly demos |

**Helix LAN extension into Region A** (cross-region multi-vendor pattern):

| Node | Platform | Connected via | Why hosted in Region A |
| --- | --- | --- | --- |
| **Helix Health LAN switch** | **HPE Aruba CX (AOS-CX simulator)** | GRE-over-VPN tunnel from Helix Health CE in Region B to Aurora-PE-2 in Region A; AOS-CX runs locally behind a vrnetlab wrapper | DevNet CML is Cisco-only natively — Aruba CX cannot run there without per-reservation BYOI upload (operationally painful). Hosting Aruba CX locally in Region A and extending it back to the Cisco CE in Region B via GRE-in-VPN demonstrates a real MSP pattern: carrier-provided CE talks to customer-owned LAN over secure transport, vendor-agnostic at the LAN layer. |

**Region A total RAM**: ~9-11 GB on Dell with all nodes active (3 Nokia backbone + FortiGate-VM Northwind CE at ~2 GB + Aruba CX LAN at ~4 GB + spare CE + tenant workload containers per §3.7). Tight but fits the 14 GB Aurora workload pool. SR Linux for the P role saves the ~1 GB headroom that makes this work. FortiGate-VM is lighter than EdgeConnect EC-V would have been (~2 GB vs ~4 GB typical), so the v1.0 → v1.1 substitution is also a net RAM reduction.

**Why hybrid SR Linux + SR OS rather than pure SR OS**:
- SR Linux's design heritage is data-centre fabric and modern programmability — its role as a P-router in Region A demonstrates Nokia's modern fabric NOS handling SP transit duty.
- SR OS classic CLI on both PEs preserves the senior-Nokia-operator skill demonstration (`A:R1>config>router>bgp#` hierarchical CLI, VPRN service architecture, MD-CLI fallback).
- ~1 GB saved by using SR Linux for P versus a third SR OS instance.

**Tenants served from Region A**:
- Northwind Robotics (CE = FortiGate-VM 7.0.14 as consolidated CE + FortiSD-WAN + NGFW, fits the "modern tech company" persona that prefers single-appliance branches; single-homed because Northwind accepts single-PE-failure risk in exchange for lower carrier cost)
- Spare capacity for any tenant when Region B (DevNet) is unavailable due to maintenance or reservation queue
- Operational sandbox for protocol experimentation without DevNet reservation dependency

**Single-homing rationale**: Region A is the resource-constrained tier. Single-homed CEs are an explicit architectural choice — not a deficiency — reflecting how smaller regions in real carriers accept single-PE-failure tolerance in exchange for lower operational complexity. This is the kind of regional asymmetry that real SP design accepts based on customer revenue and SLA tier.

### 3.2 Region B — Cisco-dominant (DevNet CML hosted)

Aurora's larger, Cisco-dominant region, hosted in the CML server embedded in a Cisco DevNet Reservation sandbox. **Dual-router per site** at every backbone tier (P core, all PE sites) and **dual-homed CEs** for tenants. Tier-1 production design discipline applied throughout.

#### 3.2.1 Three sites, six backbone routers

| Site | Router-1 | Router-2 | Why this platform mix |
| --- | --- | --- | --- |
| **Aurora-DC** (transit / P core) | **DC-P-R1**: Cisco IOS XR 7.x | **DC-P-R2**: Cisco IOS XR 7.x | P core requires consistent IOS XR for MPLS LDP/SR-MPLS, IS-IS L2 transit, RSVP-TE, and carrier-grade label switching. Both routers IOS XR for operational consistency at the core. |
| **Aurora-MR** (Maple Ridge PE site) | **MR-PE-R1**: Cisco IOS XR 7.x | **MR-PE-R2**: Cisco Cat8000v IOS XE 17.x | Mixed XR + XE PE site demonstrates the platform diversity real SP carriers carry. Maple Ridge as a general SME accepts whatever PE platform is present at the local site — operators gradually modernise the PE fleet site-by-site over years. |
| **Aurora-HH** (Helix Health PE site) | **HH-PE-R1**: Cisco IOS XR 7.x | **HH-PE-R2**: Cisco IOS XR 7.x | Pure XR PE pair. Regulated industry — operational simplicity for audit and change-management requires platform consistency. Helix Health (healthcare) cannot tolerate the cognitive overhead of mixed platforms at their dedicated PE site. |

#### 3.2.2 Customer edges (dual-homed per tenant)

Each customer CE connects to BOTH PE routers at its local PE site via eBGP. The PE pair runs as a redundant pair with the CE choosing primary path via LOCAL_PREF or splitting via multipath.

| Customer | CE platform | Uplinks (dual-homed) | PE-CE protocol | Active path selection |
| --- | --- | --- | --- | --- |
| Maple Ridge | **Cisco Cat8000v** with **IOS XE zone-based firewall (ZBFW) integrated** (v1.1 — consolidates routing + integrated perimeter; persona-aligned for conservative SME tenant) | MR-PE-R1 (XR) AND MR-PE-R2 (XE) | eBGP CE-PE with multipath | BGP `multipath` for active-active load balancing (Maple Ridge values throughput, accepts asymmetric path) |
| Helix Health | **Palo Alto VM-Series 9.0.4** (v1.1 — consolidated CE + perimeter NGFW; PAN-OS BGP/OSPF supports CE routing duties; persona-aligned for regulated industry wanting dedicated L7-inspection NGFW at the edge). Was Cisco Cat8000v in v1.0 with PA-VM as separate perimeter behind; v1.1 consolidates to PA-VM-as-CE for cleaner topology and stronger persona match. | HH-PE-R1 (XR) AND HH-PE-R2 (XR) | eBGP CE-PE with LOCAL_PREF | LOCAL_PREF higher on R1; R2 standby (Helix Health values predictable path for compliance — active-standby is auditable) |

**Helix LAN extension via GRE — Region B CE to Region A LAN** (cross-region multi-vendor pattern):

Helix Health's LAN switching tier (HPE Aruba CX) lives in Region A's containerlab rather than Region B's CML because CML is Cisco-only natively (see §3.1 for the architectural rationale). The Helix Health CE in Region B establishes a GRE-over-IPSec tunnel through the openconnect path back to the Aruba CX in Region A. This mirrors how MSPs commonly extend customer-owned LAN equipment through carrier-managed CEs without requiring the carrier to host third-party LAN hardware.

#### 3.2.3 Where Cisco SD-WAN fits

Region B's design above is **the classic MPLS L3VPN architecture** — Cisco IOS XR + IOS XE running BGP/IS-IS/MPLS. Per ADR-001 v1.6 §17.6 findings, Cisco SD-WAN sandboxes use OMP rather than traditional BGP, so SD-WAN is NOT used as the underlying transport in Aurora's Cisco region.

If a future demand surfaces a "modern overlay WAN" demonstration scenario, the SD-WAN 20.x sandbox can be brought up as an **adjacent** demo — but Aurora's Region B core remains classic MPLS L3VPN. This is the right architectural choice for a carrier providing transit-based services (Aurora's stated business model).

#### 3.2.4 Region B node inventory summary

| Tier | Node count | Platform mix |
| --- | --- | --- |
| Aurora-DC P pair | 2 | 2× IOS XR |
| Aurora-MR PE pair | 2 | 1× IOS XR + 1× Cat8000v IOS XE |
| Aurora-HH PE pair | 2 | 2× IOS XR |
| Maple Ridge CE | 1 | 1× Cat8000v with IOS XE ZBFW (v1.1) |
| Helix Health CE | 1 | 1× Palo Alto VM-Series 9.0.4 (v1.1 — was Cat8000v in v1.0) |
| Aurora-DC compute domain (§3.8) | up to 3 | Cisco UCSPE (on Dell, not CML) + Linux K3s host + DMTF Redfish mockup (UCSPE consumes a VMware Workstation slot, not a CML node slot) |
| **Total in CML** | **8 nodes** | 5× IOS XR + 2× Cat8000v IOS XE + 1× Palo Alto VM-Series (BYOI via CML reference platform upload) |

CML Personal handles 20 nodes — 12 nodes of headroom for growth (additional CEs, route reflectors, traffic generators, lab nodes for protocol tests, F5 BIG-IP load balancer per §3.5). The PA-VM 9.0.4 in CML requires BYOI reference-platform upload (CML supports adding non-Cisco vendor images as custom node definitions).

**Alternative deployment**: Palo Alto VM-Series can run locally on Dell containerlab via `vrnetlab/vr-pan:9.0.4` and reach Region B's HH-PE pair through the same openconnect-in-WSL2 + MASQUERADE path as Region A's Nokia PE-1. This avoids the BYOI upload effort and keeps PA-VM available across DevNet reservations. Recommended deployment for v1.1 is **PA-VM-on-Dell-with-openconnect-bridge** rather than CML BYOI.

**Note**: Helix Health's LAN switching tier (HPE Aruba CX) is hosted in Region A, not in CML, and reachable from Helix Health CE via GRE-over-VPN. See §3.1 and the §3.3a topology diagram.

**Region B is ephemeral**: it exists only during an active DevNet sandbox reservation. The topology, configuration, and saved state are reconstructed from version-controlled CML topology YAML files on each fresh reservation.

**Tenants served from Region B**:
- Maple Ridge Logistics (Cisco SME — dual-homed via Cat8000v CE to mixed-platform PE pair MR-PE-R1 XR + MR-PE-R2 XE)
- Helix Health Analytics (regulated industry — dual-homed via Cat8000v CE to pure-XR PE pair HH-PE-R1 + HH-PE-R2; HPE Aruba LAN behind CE)
- Larger branches and DC sites for any tenant that benefits from current production-version Cisco code with carrier-grade redundancy

### 3.3a Topology overview

```mermaid
graph TB
    classDef nsros fill:#0066b3,color:#fff,stroke:#003d6b,stroke-width:2px
    classDef nsrl fill:#42a5f5,color:#fff,stroke:#0066b3,stroke-width:2px
    classDef cisco_xr fill:#1565c0,color:#fff,stroke:#0d47a1,stroke-width:2px
    classDef cisco_xe fill:#42a5f5,color:#fff,stroke:#1565c0,stroke-width:2px
    classDef mixed fill:#ff9800,color:#fff,stroke:#e65100,stroke-width:2px
    classDef bridge fill:#43a047,color:#fff,stroke:#1b5e20,stroke-width:2px
    classDef mgmt fill:#6a1b9a,color:#fff,stroke:#4a148c,stroke-width:2px
    classDef workload fill:#fdd835,color:#000,stroke:#f57f17,stroke-width:2px
    classDef compute fill:#26a69a,color:#fff,stroke:#00695c,stroke-width:2px
    classDef fortinet fill:#ee3124,color:#fff,stroke:#a61b13,stroke-width:2px
    classDef paloalto fill:#fa582d,color:#fff,stroke:#a8390f,stroke-width:2px

    %% Management Plane
    subgraph Mgmt["📡 Sentinel Ridge MSP — Management Plane (PC1)"]
        Wazuh["Wazuh SIEM<br/>localhost:443"]
        MISP["MISP threat intel<br/>localhost:8443"]
    end

    %% Region A — Nokia (Local) — hybrid SR Linux P + SR OS PE pair
    subgraph RegA["🟦 REGION A — Nokia (Local on Dell, sub-AS 65101, always-available)"]
        direction TB
        SRL_P["Aurora-P<br/>Nokia SR Linux 24.10.1<br/>(container, ~1.5 GB)"]
        SROS_PE1["Aurora-PE-1<br/>Nokia SR OS 13.0 R4<br/>(RTC license)"]
        SROS_PE2["Aurora-PE-2<br/>Nokia SR OS 13.0 R4<br/>(RTC license)"]
        NW_CE["Northwind CE<br/>FortiGate-VM 7.0.14<br/>(CE + FortiSD-WAN + NGFW<br/>consolidated, single-homed)"]
        NW_WL["Northwind Workloads §3.7<br/>nginx + Redis<br/>Prometheus + Grafana<br/>+ dev workstation"]
        VyOS_CE["Optional CE<br/>VyOS / FRR<br/>single-homed"]
        ARUBA_CX["Helix LAN<br/>HPE Aruba CX 10.16.1040<br/>(AOS-CX)<br/>GRE-tunnelled from Region B"]
        HH_WL["Helix Workloads §3.7<br/>Orthanc DICOM<br/>HL7 simulator + EMR-mock<br/>+ clinical endpoints"]
    end

    %% Interconnect
    subgraph IC["🔄 Interconnect — openconnect + MASQUERADE"]
        OC["Dell WSL2 Ubuntu<br/>openconnect<br/>tun0: 192.168.254.x"]
        NAT["Docker iptables<br/>MASQUERADE NAT"]
        DN["DevNet VPN endpoint<br/>devnetsandbox-usw1<br/>-reservation.cisco.com:20134"]
    end

    %% Region B — Cisco (DevNet CML) — dual-router per site
    subgraph RegB["🟪 REGION B — Cisco (DevNet CML, sub-AS 65102, ephemeral)"]
        direction TB

        CML["CML Server — hosts Region B<br/>https://10.10.20.161"]

        subgraph DC_Site["Aurora-DC Site (transit/P core)"]
            DC_P_R1["DC-P-R1<br/>IOS XR 7.x"]
            DC_P_R2["DC-P-R2<br/>IOS XR 7.x"]
        end

        subgraph MR_Site["Aurora-MR Site (Maple Ridge PE pair — MIXED platform)"]
            MR_PE_R1["MR-PE-R1<br/>IOS XR 7.x<br/>(eBGP confed boundary)"]
            MR_PE_R2["MR-PE-R2<br/>Cat8000v IOS XE 17.x"]
        end

        subgraph HH_Site["Aurora-HH Site (Helix Health PE pair — PURE XR)"]
            HH_PE_R1["HH-PE-R1<br/>IOS XR 7.x"]
            HH_PE_R2["HH-PE-R2<br/>IOS XR 7.x"]
        end

        MR_CE["Maple Ridge CE<br/>Cisco Cat8000v<br/>(dual-homed)<br/>+ IOS XE ZBFW integrated<br/>+ Umbrella DNS (cloud)"]
        MR_WL["Maple Ridge Workloads §3.7<br/>nginx ERP-mock<br/>PostgreSQL + CoreDNS<br/>+ farm office endpoint"]
        HH_CE["Helix Health CE<br/>Palo Alto VM-Series 9.0.4<br/>(dual-homed perimeter<br/>+ NGFW + zones)"]

        subgraph DC_Compute["Aurora-DC Compute §3.8"]
            UCSPE["Cisco UCSPE<br/>UCS Manager simulator"]
            Compute["Linux K3s host<br/>tenant workload backends"]
            Redfish["DMTF Redfish<br/>mockup BMC API"]
        end
    end

    %% Region A internal links — single-homed CEs
    NW_CE -->|eBGP CE-PE<br/>single uplink<br/>+ FortiSD-WAN overlay| SROS_PE1
    NW_WL -.->|LAN traffic| NW_CE
    VyOS_CE -->|OSPF CE-PE<br/>single uplink| SROS_PE2
    SROS_PE1 ---|IS-IS L2 + LDP| SRL_P
    SROS_PE2 ---|IS-IS L2 + LDP| SRL_P
    HH_WL -.->|LAN traffic| ARUBA_CX

    %% Interconnect path — the region boundary
    SROS_PE1 -.->|eBGP confed<br/>65101 → 65102| OC
    OC --> NAT
    NAT --> DN
    DN -.->|tun0 IP as<br/>BGP neighbor| MR_PE_R1

    %% Region B internal links — dual-router per site, dual-homed CEs
    DC_P_R1 ---|IS-IS L2| DC_P_R2
    DC_P_R1 ---|IS-IS L2| MR_PE_R1
    DC_P_R2 ---|IS-IS L2| MR_PE_R2
    DC_P_R1 ---|IS-IS L2| HH_PE_R1
    DC_P_R2 ---|IS-IS L2| HH_PE_R2
    MR_PE_R1 ---|IS-IS L2| MR_PE_R2
    HH_PE_R1 ---|IS-IS L2| HH_PE_R2

    MR_CE -->|eBGP multipath<br/>active-active| MR_PE_R1
    MR_CE -->|eBGP multipath<br/>active-active| MR_PE_R2
    MR_WL -.->|LAN traffic via<br/>IOS XE ZBFW| MR_CE
    HH_CE -->|eBGP LOCAL_PREF<br/>primary| HH_PE_R1
    HH_CE -->|eBGP LOCAL_PREF<br/>standby| HH_PE_R2

    %% GRE tunnel from Helix CE in Region B back to Helix LAN in Region A (cross-region)
    HH_CE -.->|GRE-over-IPSec<br/>cross-region tunnel<br/>after PA-VM zone inspection| ARUBA_CX

    %% DC Compute domain §3.8
    UCSPE -.->|service profile<br/>management| Compute
    Redfish -.->|BMC API standard| Compute
    Compute -.->|hosts §3.7<br/>workload backends| DC_P_R1

    CML -.->|hypervisor hosts<br/>all Region B nodes| DC_P_R1

    %% Management plane reaches both regions
    Wazuh -.->|syslog +<br/>Wazuh agents| SROS_PE1
    Wazuh -.->|syslog via<br/>openconnect VPN| MR_PE_R1
    MISP -.->|IoC feeds| Wazuh

    class SROS_PE1,SROS_PE2 nsros
    class SRL_P nsrl
    class DC_P_R1,DC_P_R2,MR_PE_R1,HH_PE_R1,HH_PE_R2 cisco_xr
    class MR_PE_R2,MR_CE cisco_xe
    class CML cisco_xr
    class VyOS_CE,ARUBA_CX mixed
    class OC,NAT,DN bridge
    class Wazuh,MISP mgmt
    class NW_CE fortinet
    class HH_CE paloalto
    class NW_WL,HH_WL,MR_WL workload
    class UCSPE,Compute,Redfish compute
```

**Legend** (v1.1):
- 🟦 Dark blue = Nokia SR OS (classic CLI, RTC-frozen license, carrier PEs)
- 🔵 Mid blue = Nokia SR Linux (container, modern data plane, P role)
- 🟦 Dark blue = Cisco IOS XR (current 7.x, carrier P and PE roles)
- 🔵 Mid blue = Cisco IOS XE (Cat8000v 17.x, PE alternative and CE roles; IOS XE ZBFW at Maple Ridge perimeter)
- 🟥 Red = Fortinet FortiGate-VM (Northwind CE — consolidated CE + FortiSD-WAN + NGFW per §3.1 + §3.5.1)
- 🟠 Orange-red = Palo Alto VM-Series (Helix Health CE perimeter NGFW per §3.5.1; OVA acquired May 31 2026, trial requested)
- 🟧 Orange = Other multi-vendor CEs and LAN devices (VyOS, HPE Aruba CX, MikroTik fallback)
- 🟨 Yellow = Tenant workload containers per §3.7 (applications, traffic generators, persona-aligned per tenant)
- 🟢 Teal = DC Compute domain per §3.8 (Cisco UCSPE, Linux K3s compute host, DMTF Redfish mockup)
- 🟩 Green = Interconnect tier (openconnect, MASQUERADE, VPN endpoint)
- 🟣 Purple = Sentinel Ridge MSP management plane
- ─── Solid line = data-plane link in topology
- ┄┄┄ Dashed line = control-plane / management / overlay relationship

**Topology summary** (v1.1):

1. **Region A — Nokia hybrid stack, single-homed customers** (~9-11 GB total RAM): SR Linux at the P role for lightweight data-plane transit, two SR OS PEs for classic carrier service termination, **FortiGate-VM 7.0.14 at Northwind CE** as consolidated CE + FortiSD-WAN + NGFW (v1.1 placement; v1.0 had HPE EdgeConnect EC-V here, deferred W4+ pending HPE Aruba sales trial). Aruba CX 10.16.1040 LSR at Helix LAN (reached via GRE from Region B Helix CE). Customer CEs single-homed reflecting the resource-constrained tier-2 reality.
2. **Region B — Cisco dual-router per site, dual-homed customers** (9 nodes in CML): Aurora-DC P pair (2× IOS XR), Aurora-MR PE pair (mixed XR + XE — gradual modernisation pattern), Aurora-HH PE pair (pure XR — regulated industry consistency). Maple Ridge CE Cat8000v with **IOS XE ZBFW integrated perimeter** (v1.1; v1.0 had dedicated FortiGate which moved to Northwind) supplemented by Cisco Umbrella DNS via §3.6. **Helix Health CE is Palo Alto VM-Series 9.0.4** (v1.1; OVA acquired May 31 2026, 30-day trial requested) — dual-homed perimeter NGFW with L7 zone-based inspection for regulated medical data. Maple Ridge CE active-active multipath; Helix Health CE active-standby LOCAL_PREF (audit-friendly path selection).
3. **eBGP confederation across the region boundary** — Nokia PE-1 (sub-AS 65101) peers with MR-PE-R1 (sub-AS 65102) over the openconnect VPN. External peers see Aurora as a consolidated AS 65100 carrier.
4. **Asymmetric resilience by design** — Region A accepts single-PE-failure tolerance for lower operational cost; Region B implements production-grade dual-router-per-site discipline. This is realistic SP regional asymmetry, not a deficiency.
5. **Tenant Workload Layer (§3.7)** — Each tenant's LAN downstream of the CE / LAN switch hosts persona-aligned application containers (~1.5-2 GB total): Helix runs Orthanc DICOM + HL7 simulator + EMR-mock; Maple Ridge runs ERP-mock + PostgreSQL + CoreDNS; Northwind runs SaaS-mock + Redis + Prometheus + Grafana. Provides end-to-end traffic sources/sinks for App-ID, security policy, URL filtering, and throughput demonstrations.
6. **Data Centre Compute Domain (§3.8)** — Aurora-DC site gains UCSPE (Cisco UCS Platform Emulator) + Linux K3s host running §3.7 workload backends + DMTF Redfish mockup. Demonstrates pre-sales server architecture fluency across Cisco UCS, vendor-agnostic Redfish standards, and modern container orchestration — without requiring physical HP/Dell/Cisco rack hardware.

### 3.3 Interconnect — the region boundary

Region A and Region B are connected at L3 over the openconnect VPN tunnel:

```
Region A (Local, Dell containerlab)
  ↕  WSL2 host tun0 (via Dell or PC1, decision in §6)
  ↕  openconnect VPN
  ↕  DevNet sandbox internal network 10.10.20.0/24
Region B (CML, embedded in DevNet sandbox)
```

The L3 path uses Docker MASQUERADE — Region A's Nokia PE sends BGP packets to Region B's Cisco PE; the source IP is rewritten to the WSL2 host's tun0 address; the Cisco PE configures its BGP neighbor as that tun0 address. **eBGP between AS 65100 (Region A Nokia) and AS 65100 (Region B Cisco — same logical Aurora carrier, but different region BGP confederations)** OR **iBGP across the region boundary if Aurora is modelled as a single AS with multiple regions**.

**Initial choice for ADR-002 v1.0**: model both regions as **AS 65100 with two BGP confederations** (`65101` for Region A Nokia, `65102` for Region B Cisco-dominant). Confederation BGP keeps the external presentation as a single AS while permitting regional autonomy in route propagation.

Alternative: single iBGP mesh with route reflectors per region. Simpler but less realistic for a multi-region carrier.

### 3.5 Tenant security, wireless, and ancillary services (market-aligned)

Empirical job-market evidence (May 2026 scan of 224 Australian network engineering / infrastructure JDs) shows the lab's tenant services should emphasise enterprise vendors that match real hiring demand rather than purely carrier-flavoured choices. This section maps each tenant to the security, wireless, and load-balancing services that best demonstrate market-aligned skills.

#### 3.5.1 Per-tenant service matrix

| Tenant | Perimeter NGFW | Wireless | LAN switching | Load balancer | Why this combination |
| --- | --- | --- | --- | --- | --- |
| **Maple Ridge Logistics** (general SME, dominant volume tenant, conservative persona) | **Cisco IOS XE zone-based firewall (ZBFW) on Cat8000v CE** — integrated perimeter; supplemented by **Cisco Umbrella DNS** via DevNet §3.6 ancillary integration | **Cisco WLC** (via DevNet Catalyst Center sandbox — API integration) | Cisco Cat8000v / Cat9000v | **F5 BIG-IP VE** (containerlab via `vrnetlab/f5_bigip`) | Maple Ridge persona is "mature, conservative Aussie agribusiness" — trusts carrier-managed CE with integrated security over a separate dedicated NGFW. ZBFW on Cat8000v is a real-world carrier pattern for SME customers; Umbrella DNS layers cloud-delivered URL/threat protection above. Cisco WLC covers 6 JDs (2.7%). F5 BIG-IP covers 4 JDs (1.8%). The v1.0 dedicated FortiGate at Maple Ridge moved to Northwind in v1.1 to better match each tenant's persona. |
| **Helix Health Analytics** (regulated industry, healthcare data) | **Palo Alto VM-Series 9.0.4** — OVA acquired May 31 2026 (`/Software images/PA-VM-ESX-9.0.4.ova`, 3.1 GB); 30-day trial authcode requested same day from Palo Alto Networks; unlicensed mode supports zones, security policy, BGP, OSPF, NAT, virtual routers for immediate demo; Threat Prevention + URL Filtering + WildFire + DNS Security + GlobalProtect activate when authcode arrives (~24-72 hours typical) | **HPE Aruba Wireless** (architectural — ClearPass-managed APs documented; deployment via Aruba Central API where available) | **HPE Aruba CX (AOS-CX 10.16.1040 LSR)** — hosted in Region A, GRE-tunnelled from Region B per §3.2; OVA in HPE Networking Support Portal export-compliance review queue from May 31 2026 evening, ~4 hour SLA | F5 BIG-IP VE | Palo Alto is the regulated-industry favourite (11 JDs, 4.9%). HPE/Aruba covers 8 JDs total (3.6%) split between LAN switching and wireless. Helix Health as the regulated tenant gets the compliance-grade NGFW + Aruba LAN+Wireless story. Tenant-persona match: regulated industries prefer best-of-breed dedicated NGFW with L7 inspection over carrier-integrated ZBFW. |
| **Northwind Robotics** (modern tech, consolidated stack persona) | **Fortinet FortiGate-VM 7.0.14** — consolidated as CE + FortiSD-WAN + NGFW at the same hop (per §3.1); Fortinet covers 21 JDs (9.4%) — #2 vendor in market scan and the single highest-impact firewall gap | n/a (cloud-managed via Meraki/Aruba Central if deployed — architectural only) | Minimal LAN behind FortiGate (FortiGate provides L2 switching for branch endpoints) | n/a (small tech tenant — DC services consumed as SaaS) | Modern tech company persona — prefers single-appliance branch consolidation over best-of-breed multi-vendor stacks. FortiGate-VM at the branch covers routing, SD-WAN overlay, and NGFW in one VM (~2 GB RAM). The v1.0 architectural intent was HPE Aruba EdgeConnect EC-V (formerly Silver Peak) at Northwind for SD-WAN demonstration, but EdgeConnect is gated by HPE Aruba sales-engagement trial procurement (~2-6 weeks) — FortiGate-VM was already built locally May 31 2026 and carries the SD-WAN story until EdgeConnect access materialises. Zscaler ZTNA documented architecturally for tenant-managed cloud-delivered security overlay (2 JDs, 0.9%). |

#### 3.5.2 Market coverage summary

After §3.5 implementation, the lab demonstrates the following vendors from the 224-JD scan:

| Vendor | JDs | Lab coverage |
| --- | --- | --- |
| **Cisco (all)** | 41 (18.3%) | Region B P + PEs (IOS XR + Cat8000v), Maple Ridge LAN, WLC integration via DevNet |
| **Fortinet/FortiGate** | 21 (9.4%) | **Northwind CE** as consolidated CE + FortiSD-WAN + NGFW (v1.1 placement; v1.0 had Fortinet at Maple Ridge perimeter — moved for persona alignment) |
| **Palo Alto Networks** | 11 (4.9%) | Helix Health CE perimeter NGFW — PA-VM 9.0.4 OVA acquired May 31 2026; 30-day eval authcode requested |
| **Cisco Meraki** | 10 (4.5%) | Via DevNet Meraki Always-On sandbox (API automation demo per §3.6) |
| **HP/Aruba** | 8 (3.6%) | Aruba CX 10.16.1040 LSR (Helix Health LAN, in Region A) + Aruba Wireless (architectural). HPE Aruba EdgeConnect EC-V deferred to W4+ pending sales-engagement trial. |
| **Cisco Wireless/WLC** | 6 (2.7%) | Via DevNet Catalyst Center sandbox per §3.6 |
| **MPLS/SR-MPLS** | 6 (2.7%) | Region A Nokia + Region B Cisco backbones |
| **F5 BIG-IP** | 4 (1.8%) | Maple Ridge + Helix Health DC load balancer |
| **Juniper** | 4 (1.8%) | cRPD documented for ADR-001 §14 tenant variations |
| **Aruba Wireless** | 3 (1.3%) | Documented architectural pattern for Helix Health |
| **Sophos** | 4 (1.8%) | Not in current lab — deferred |
| **Silver Peak / EdgeConnect** | 2 (0.9%) | **Deferred W4+** — HPE Aruba EdgeConnect EC-V gated by sales-engagement trial procurement (~2-6 weeks). FortiSD-WAN at Northwind CE carries the SD-WAN demonstration narrative in the interim per §3.1 + §3.5.1. |
| **Nokia SR OS** | 1 (0.4%) | Region A backbone — primary background match |

**Total weighted coverage**: ~65% of the top-vendor demand across the 224-JD scan is demonstrably represented in the lab after §3.5 implementation. The remaining 35% includes vendors that are either lower-priority gaps (Sophos, WatchGuard) or covered conceptually but not hands-on (Cisco SD-WAN/Viptela, Cisco ASA/FTD).

#### 3.5.3 Deployment ordering and dependencies

Many §3.5 components require local image acquisition or vendor account registration. Order of deployment matches Sprint W4 dependencies:

| Component | Status May 31 2026 (late evening) | Acquisition path |
| --- | --- | --- |
| FortiGate-VM 7.0.14 | **Built** (`vrnetlab/vr-fortios:7.0.14`) — placement: Northwind CE per §3.1 + §3.5.1 v1.1 | Local qcow2 + vrnetlab wrapper |
| HPE Aruba CX (AOS-CX 10.16.1040 LSR) | **Download requested** — in HPE Networking Support Portal export-compliance review queue, ~4 hour SLA; build Monday morning | HPE Networking Support Portal (free HPE Passport account); download `.ova.zip`; extract `.vmdk`; convert to qcow2; build `vrnetlab/aoscx` wrapper |
| HPE Aruba EdgeConnect EC-V | **Deferred W4+** — gated by HPE Aruba sales-engagement trial (~2-6 weeks); FortiSD-WAN at Northwind CE carries SD-WAN story until access materialises | Submit HPE Aruba sales contact form requesting EC-V evaluation; if/when approved download EC-V qcow2 + KVM-direct or vrnetlab wrapper |
| **Palo Alto VM-Series 9.0.4** | **OVA acquired May 31 2026** (`/Software images/PA-VM-ESX-9.0.4.ova`, 3.1 GB); **30-day trial authcode requested same day**; build PA-VM vrnetlab wrapper Monday morning (unlicensed-mode demo viable for Monday interview); apply authcode when arrives (~24-72 hours) | Extract OVA tar → vmdk → qcow2 → `vrnetlab/vr-pan:9.0.4` wrapper. Eval authcode via Palo Alto Networks trial program (legitimate eval path). |
| F5 BIG-IP VE | Pending | `vrnetlab/f5_bigip` (in user's vrnetlab clone); F5 trial download |
| Cisco IOS XE ZBFW on Cat8000v (Maple Ridge perimeter) | Available via DevNet CML — no separate acquisition needed; configured at deployment time | DevNet CML licensed image |
| Cisco Umbrella DNS (Maple Ridge cloud-delivered security) | Architectural — DevNet sandbox or trial account | Cisco Umbrella free trial |
| Cisco WLC + Meraki + AnyConnect demos | Available via DevNet | Sandbox reservation (no local install); see §3.6 |
| Cisco UCSPE (DC compute domain per §3.8) | Pending — Tuesday-Wednesday install | Cisco DevNet → UCS Platform Emulator download; runs in VMware Workstation, 4 GB RAM |
| DMTF Redfish mockup (DC compute domain per §3.8) | Pending — Tuesday install | Docker container `dmtf/redfish-mockup-server`, ~50 MB RAM |

### 3.6 DevNet sandbox ancillary integrations (adjacent to topology)

Not all market-aligned vendor demonstrations belong inside the Aurora topology. The following integrations are demonstrated via DevNet sandboxes as **adjacent demonstrations** that complement the main topology rather than nodes within it. Each is reachable via the same openconnect-in-WSL2 + Docker MASQUERADE path that connects to Region B's CML (per §3.3 and ADR-001 §17.6).

| Market need | DevNet sandbox | Integration model | Demo flavour |
| --- | --- | --- | --- |
| **Cisco Meraki** (10 JDs, 4.5%) | Meraki Sandbox (Reservable) and Meraki Always-On API endpoints | API-driven from local Ansible/Python; pull device inventory, push policies, demonstrate cloud-managed networking | "Cloud-managed networking automation via the Meraki Dashboard API — same Ansible inventory targets both the local Aurora topology and the cloud-managed Meraki org" |
| **Cisco Catalyst Center + WLC** (6 JDs, 2.7%) | Catalyst Center Always-On v2.3.3.6 + Catalyst Center Sandbox + DevNet WLC | API automation against DNAC; intent-based networking demo | "DNAC-driven device discovery and policy push — modern Cisco intent-based networking automation" |
| **Cisco AnyConnect VPN** (2 JDs, 0.9%) | Verified May 31 2026 via openconnect-in-WSL2 (per ADR-001 §17.6) | Already in use as the Region A → Region B bridge | "AnyConnect / Cisco Secure Client compatible VPN endpoint demo — I use the openconnect OSS client inside WSL2 to integrate with DevNet sandboxes; the same client and endpoint pattern serves real Cisco Secure Client deployments" |
| **Cisco SD-WAN (Viptela)** (1 JD, 0.4%) | Cisco SD-WAN 20.12 + SD-WAN 20.18 AlwaysOn | Sandbox-only — Region B does NOT use SD-WAN for its core because ADR-001 §17.6 confirmed SD-WAN sandboxes are BGP-free | "Modern overlay WAN comparison demo against the classic MPLS L3VPN that Aurora's Region B implements" |
| **NSO / network orchestration** | NSO Always-On + NSO 6.4.4 Reservable | Service-template demos against the topology | "YANG-driven multi-vendor service orchestration" |
| **Cisco ACI** | ACI Simulator 6.0 + ACI Simulator Always-On | DC fabric demonstration alongside Helix Health DC scenario | "ACI fabric automation for the regulated industry tenant's DC" |
| **Cisco Firepower + FMC + FTD** | Firepower Management Center + Firepower Threat Defense REST API | Security automation against Helix Health perimeter | "Centralised FMC managing FTD devices alongside Palo Alto perimeter" |

These are NOT additional Aurora nodes — they are separate demonstrations available on demand. Each addresses a specific market vendor that doesn't fit naturally into the carrier topology but is essential to the broader job-market story.

The discipline for using §3.6 services is documented in `docs/devnet-resource-strategy.md` (continuity hierarchy, reservation discipline, credential management).

### 3.7 Tenant Workload Layer (added v1.1)

Each tenant's LAN includes persona-aligned application workloads as lightweight Linux containers attached to the LAN segment downstream of the CE / LAN switch. These provide end-to-end traffic sources and sinks for demonstrating App-ID, security policy enforcement, URL filtering, latency, and throughput — the carrier story shouldn't end at the CE; it should reach the application.

#### 3.7.1 Per-tenant workload matrix

| Tenant | Workload containers | Role | RAM each |
| --- | --- | --- | --- |
| **Helix Health Analytics** | `orthanc/orthanc-plugins` | DICOM medical imaging server | ~300 MB |
| | `nextgenhealthcare/mirth-connect` OR `synthetichealth/synthea` | HL7 message simulator / synthetic clinical data | ~200 MB |
| | `nginx:alpine` (HTML mock EMR frontend) | Electronic Medical Records UI | ~20 MB |
| | `alpine` + iperf3 | Doctor workstation endpoint + traffic generator | ~10 MB |
| | `alpine` + iperf3 | Clinical device endpoint (DICOM source) | ~10 MB |
| **Maple Ridge Logistics** | `nginx:alpine` (HTML mock ERP frontend) | Farm management ERP UI | ~20 MB |
| | `postgres:alpine` | ERP database backend | ~200 MB |
| | `coredns/coredns` | Tenant-internal DNS for farm subnet | ~30 MB |
| | `alpine` + iperf3 | Farm office workstation endpoint | ~10 MB |
| **Northwind Robotics** | `nginx:alpine` (HTML mock SaaS frontend) | Modern web frontend | ~20 MB |
| | `redis:alpine` | Cache layer | ~30 MB |
| | `prom/prometheus` | Modern observability stack | ~150 MB |
| | `grafana/grafana` | Dashboards over Prometheus | ~200 MB |
| | `alpine` + iperf3 | Developer workstation endpoint | ~10 MB |

**Total workload-layer RAM**: ~1.5-2 GB across all three tenants. Cheap compared to the network device footprint and high-ROI for end-to-end demonstrations.

#### 3.7.2 Topology integration

Workload containers are added as standard containerlab Linux nodes connected via the LAN segment to each tenant's CE or LAN switch:

```yaml
nodes:
  helix-ce-pa:
    kind: pan-pa
    image: vrnetlab/vr-pan:9.0.4
  helix-lan-aruba:
    kind: linux
    image: vrnetlab/aoscx:10.16.1040
  helix-orthanc:
    kind: linux
    image: jodogne/orthanc-plugins
  helix-emr:
    kind: linux
    image: nginx:alpine
  helix-doctor-wks:
    kind: linux
    image: alpine
    exec:
      - "apk add --no-cache iperf3 curl"

links:
  - endpoints: ["helix-ce-pa:eth2", "helix-lan-aruba:eth1"]
  - endpoints: ["helix-lan-aruba:eth2", "helix-orthanc:eth1"]
  - endpoints: ["helix-lan-aruba:eth3", "helix-emr:eth1"]
  - endpoints: ["helix-lan-aruba:eth4", "helix-doctor-wks:eth1"]
```

#### 3.7.3 Demonstration scenarios this enables

| Scenario | Source workload | Path | Sink workload | What's demonstrated |
| --- | --- | --- | --- | --- |
| DICOM image transfer | Helix clinical device endpoint | Aruba CX → Helix CE (PA-VM zone policy) → GRE tunnel → Region A → Region B → DC PE → Aurora DC | Orthanc DICOM server | End-to-end medical data flow with NGFW L7 inspection at the customer perimeter |
| ERP transaction | Maple Ridge farm office workstation | Cat8000v CE (IOS XE ZBFW) → MR PE pair (multipath active-active) → Aurora DC | nginx ERP frontend + PostgreSQL | SD-WAN-free classic MPLS L3VPN with multipath BGP and integrated CE-firewall |
| Modern app + observability | Northwind developer workstation | FortiGate CE (FortiSD-WAN steering) → Aurora-PE-1 → Aurora-P → Aurora DC | nginx SaaS + Redis; Grafana dashboards observe the flow | FortiSD-WAN application-aware steering with modern observability stack as the operational lens |
| URL filtering / IPS demonstration | Any endpoint | Through tenant NGFW | External Internet target | When PA-VM authcode arrives: live URL filtering, threat signature matching, DNS Security |

#### 3.7.4 Implementation phasing

| Window | Action |
| --- | --- |
| W2 (current) | Decision committed; topology YAML stub authored alongside ADR-002 v1.1 |
| Monday afternoon (interview prep) | Optional: deploy minimal Alpine endpoint per tenant for basic ping/iperf demo if time allows after STAR rehearsal |
| Tuesday-Wednesday | Full nginx + PostgreSQL + Redis + Prometheus/Grafana per tenant |
| W3 | Industry-specific containers — Orthanc, Mirth, Synthea for Helix Health |
| W4 | iperf3-based throughput tests integrated into Ansible playbooks for `make throughput-test` |

### 3.8 Data Centre Compute Domain (added v1.1)

The Aurora-DC site (Region B P pair) gains a compute domain alongside the dual-XR backbone routers. This addresses the architectural gap that ADR-002 v1.0 left around server-vendor demonstration and provides a fluent answer to interview questions about HP/Dell/Cisco compute platforms.

#### 3.8.1 Compute domain components

| Component | Vendor / standard | Resource | Purpose |
| --- | --- | --- | --- |
| **Cisco UCS Platform Emulator (UCSPE)** | Cisco | ~4 GB RAM, runs in VMware Workstation on Dell | Service profile management plane, UCS Manager hands-on fluency, server policy hierarchy demo |
| **Linux compute host** | Generic (Ubuntu/Rocky/Alpine) running K3s or Docker | ~1 GB RAM | Hosts the §3.7 tenant workload containers; demonstrates modern container orchestration as DC compute fabric |
| **DMTF Redfish mockup server** | DMTF standards body (open source) | Docker container, ~50 MB RAM | Vendor-agnostic out-of-band server management API; HPE iLO / Dell iDRAC / Cisco UCS / Lenovo XClarity all implement Redfish — demonstrating against the mockup shows multi-vendor BMC fluency |
| **Ansible playbooks targeting Redfish** | Internal | n/a (controller-side) | Demonstrates Infrastructure-as-Code against the Redfish standard |

#### 3.8.2 Why this combination — server skills strategy

The compute domain is designed to demonstrate **pre-sales server architecture fluency** rather than physical hands-on hardware operations:

| Server skill type | Demonstration path |
| --- | --- |
| Cisco UCS architecture | UCSPE — full UCS Manager, service profile templates, server pool management |
| HPE server architecture | HPE Tech Pro Community labs (registered for trial access W3+); Redfish mockup demonstrates the modern HPE iLO API surface |
| Dell server architecture | Dell iDRAC9 Virtual Console Simulator (browser-based, free) when needed for visual demo; Redfish covers the API layer |
| Modern compute orchestration | K3s or Docker on the compute host running §3.7 workloads |
| Multi-vendor BMC automation | Ansible playbooks against Redfish mockup — same playbook can target real HPE, Dell, Cisco, Lenovo BMCs in production |

This matches the senior-engineer interview reality: the SP Pre-Sales role expects architectural fluency and standards-based design thinking, not physical rack-and-stack experience. Skills are demonstrated through standards (Redfish), authoritative simulators (UCSPE), and modern abstractions (containers/K3s).

#### 3.8.3 Deployment phasing

| Window | Action |
| --- | --- |
| W2 (current) | Decision committed; architectural intent in ADR-002 v1.1 |
| Tuesday | DMTF Redfish mockup spun up as Docker container (~5 min); first Ansible playbook against it (~30 min) |
| Tuesday-Wednesday | UCSPE downloaded from DevNet, installed in VMware Workstation on Dell (~45 min); first service profile authored (~30 min) |
| W3 | K3s or Docker on dedicated compute host VM; §3.7 workload containers migrated onto it as proper orchestrated workloads |
| W3 | HPE Tech Pro Community labs access requested |
| W3-W4 | HPE OneView trial requested via sales engagement (when ready to take that follow-up conversation) |

#### 3.8.4 Interview narrative this enables

When the interviewer asks about server experience:

> "My server architecture strategy in ADR-002 §3.8: Cisco UCSPE for UCS Manager and service profile fluency, DMTF Redfish mockup for vendor-agnostic BMC standards-based automation, and K3s on a Linux compute host for modern container orchestration as the §3.7 tenant workload fabric. HPE Compute is W3+ via Tech Pro Community access and OneView trial procurement — same architectural deferral pattern as EdgeConnect EC-V. I'm deliberately building this as multi-vendor standards-based design rather than single-vendor specialisation because that's what SP Pre-Sales conversations require. For production hands-on, my current professional environment uses [TheirCare's actual server stack]."

## 4. Vendor strategy per region

### Region A — Nokia (Local)

- **Backbone**: Nokia SR OS classic CLI for PEs, FRR for P or backup PE
- **Customer-edge**: Mixed vendors with MikroTik dominant (Northwind persona); some FRR/VyOS for "open-source-friendly" customers
- **Demonstration purpose**: Multi-vendor SP-side interop, classic Nokia operator skill, resource-light "always available" lab

### Region B — Cisco (DevNet CML)

- **Backbone**: Cisco IOS XR 7.x on P and PE; Cat8000v IOS XE 17.x as additional PE platform
- **Customer-edge**: Cisco Cat8000v dominant for "Cisco SME" customers (Maple Ridge); mixed with HPE Aruba CX for "regulated industry" customers (Helix Health) where DevNet hosts that flavour
- **Demonstration purpose**: Current production Cisco code, Cisco-dominant SP architecture, scale demonstrations beyond local hardware ceiling

This is faithful to how real AU carriers structure themselves. The vendor-per-region pattern is what an interviewer expects to see in a senior SP design.

## 5. Operational model

### 5.1 Day-to-day lab operations

| Scenario | What's running |
| --- | --- |
| **Region A always-on (default)** | Nokia SR OS + FRR + Nokia-region tenants on Dell. ~5 GB RAM. Available 24/7. |
| **Region B on-demand** | Reserve DevNet sandbox (SD-WAN 20.12 or equivalent with embedded CML). Deploy CML topology via REST API call from local Ansible. ~10-15 min provisioning. Available for the reservation window (4 hr to 7 days). |
| **Two-region cross-demos** | Both A and B active; openconnect from local WSL2 to DevNet; eBGP across the region boundary. For interview demos. |
| **Single-region demos** | Either region in isolation (Region A always available; Region B requires reservation). |

### 5.2 Reproducibility

Region B's existence in DevNet is ephemeral, but the **topology and config are version-controlled** in the Aurora repo:

```
aurora-comms/
├── docs/
│   ├── adr-002-two-region.md          # this ADR
│   └── lab-architecture.md            # ADR-001 v1.6 (historic)
├── region-a-nokia/
│   ├── clab-region-a.yml              # containerlab topology
│   ├── configs/                       # FRR + SR OS configs
│   └── ansible/                       # Local-region playbooks
├── region-b-cisco-cml/
│   ├── cml-topology.yml               # CML lab definition (REST API payload)
│   ├── configs/                       # IOS XR + Cat8000v configs
│   └── ansible/                       # Region B playbooks targeting DevNet IPs
└── interconnect/
    ├── frr-asbr-config.j2             # Nokia-side BGP config template
    ├── iosxr-asbr-config.j2           # Cisco-side BGP config template
    └── README.md                      # Manual + automated bring-up procedure
```

A fresh DevNet reservation + Region B redeploy takes ~30-45 minutes from reservation click to converged eBGP session.

### 5.3 Reservation discipline

| When Region B needed | Action |
| --- | --- |
| Interview demos | Reserve sandbox ~30 min before call; ensure VPN up, CML topology deployed, BGP converged |
| Customer-facing demos | Reserve 4-hour slot with 1-hour buffer; have rollback ready |
| Async development (no demo pressure) | Reserve up to 7-day slot; use the long window for protocol experimentation |
| Always-available access | Region B is intentionally NOT always-available; this is a documented constraint, not a deficiency |

## 6. Where VPN terminates — Dell or PC1?

The WSL2 host running `openconnect` becomes the "DevNet edge" of Region A. Two choices:

| Choice | Implications |
| --- | --- |
| **VPN on Dell WSL2** | Dell already hosts Region A's containerlab. Region A → DevNet path is local, fastest. PC1 reaches DevNet via Dell (or via its own separate openconnect). |
| **VPN on PC1 WSL2** | PC1 has Wazuh + MISP + Cowork already. Adds VPN as another always-on burden. Region A on Dell would need to route via PC1 over the GRE/tailnet path to reach DevNet — adds latency and complexity. |

**Decision for ADR-002 v1.0**: VPN runs on **Dell** because Dell hosts Region A's backbone and the region-boundary BGP needs the shortest path. PC1 retains its existing role (Wazuh + MISP + Cowork + tenant endpoint VMs).

## 7. What's deprecated from ADR-001 v1.6

| ADR-001 plan | Status in ADR-002 |
| --- | --- |
| §6 RAM allocation showing carrier monolith on Dell | **Superseded** — Dell now hosts only Region A (~5 GB) |
| §14 single multi-vendor topology per tenant | **Refined** — tenants are assigned to a specific region; multi-vendor diversity is per-region rather than per-tenant |
| §15.4 throughput-test topology pattern | **Still applies** for Region A; Region B inherits CML's hosting throughput |
| §17 DevNet as "external inter-AS peer carrier" | **Replaced** — DevNet is now hosting the *Cisco region of Aurora itself*, not an external carrier |
| Sprint W4 vrnetlab wrappers for Cat8000v, Cat9000v, ASAv | **Deprioritised** — Region B uses DevNet CML's licensed images; local vrnetlab wrappers for these are no longer required |
| vr-xrv 6.1.3 wrapper from on-disk | **Deprioritised** — DevNet CML provides current XR 7.x; on-disk 6.1.3 retained as offline fallback only |
| vr-vios L3 wrapper from on-disk | **Deprioritised** — DevNet CML provides current IOS XE 17.x; on-disk 15.7 retained as offline fallback only |

## 8. What's retained from ADR-001 v1.6

| Item | Status |
| --- | --- |
| Option C hybrid workload distribution (Wazuh + MISP on PC1, lightweight services on Dell) | Retained |
| Tailscale overlay between PC1, Dell, Surface Pro | Retained |
| Docker daemon split on PC1 (Desktop for personal, native for lab) | Retained |
| WSL2 `.wslconfig` 12 GB memory cap on PC1 | Retained |
| Nokia SR OS RTC trick for 2015 license validity | Retained — required for Region A's Nokia PE |
| `openconnect`-in-WSL2 as canonical DevNet VPN pattern (ADR-001 §17.7) | Retained AND elevated to Region B's only access path |
| Per-tenant CE/LAN diversity (ADR-001 §14) | Retained, now scoped per region |
| Three-tenant taxonomy (Maple Ridge, Helix Health, Northwind) | Retained, with tenant-to-region mapping per §3 |

## 9. Constraints accepted

These explicit limitations are accepted as part of the ADR-002 decision:

1. **Region B is ephemeral.** It exists only during active DevNet reservations. Outside reservation windows, Region B is unreachable. The lab must be fully demonstrable from Region A alone (Nokia-only) for any moment when DevNet is unavailable.
2. **Region B state is reset per reservation.** No persistent state survives between reservations. The cml-topology.yml + Ansible playbooks are the source of truth; they reconstruct Region B from scratch on each fresh reservation.
3. **VPN bandwidth from Australia to Cisco US-West is 150-250 ms latency.** Acceptable for CLI work and demos but slow for GUI screen-shares of CML web UI under heavy interaction.
4. **DevNet sandbox availability is not guaranteed.** Reservation slots may be unavailable during high-demand windows. Region B demos must have a fallback plan (use the embedded CML in a different sandbox type, or postpone).
5. **eBGP across the openconnect tunnel relies on Docker MASQUERADE.** Source IP from Region A's BGP-speaking node is rewritten to the WSL2 host's tun0 address. Region B's BGP neighbor config must use that tun0 IP — which may rotate per VPN session if Cisco's pool assigns differently. Operationally, capture tun0 IP at session start and template the Region B neighbor config from it.
6. **Authentication and routing protocol auth across regions** is on the W4+ backlog. Initial eBGP for ADR-002 v1.0 uses plain TCP-179 without MD5/TCP-AO. Authentication added once base architecture is stable.
7. **Palo Alto VM-Series runs in unlicensed-mode for the eval window** (added v1.1). PA-VM 9.0.4 OVA was acquired May 31 2026 and a 30-day evaluation authcode requested same evening. Unlicensed mode supports zones, security policy commits, NAT, BGP, OSPF, virtual routers, and interface configuration — sufficient for the architectural demo at Monday's interview. Subscription features (Threat Prevention IPS, URL Filtering with PAN-DB, WildFire sandbox, DNS Security, GlobalProtect, dynamic App-ID updates) require the authcode to activate and are expected within 24-72 hours of the eval request. The 30-day clock starts at activation, not at request — defer authcode activation until ready to demo subscription features for maximum eval window utilisation.
8. **HPE Aruba EdgeConnect EC-V is deferred to W4+** (added v1.1). EC-V is gated by HPE Aruba sales-engagement trial procurement (~2-6 week typical turnaround). ADR-002 v1.0 specified EC-V as Northwind CE; v1.1 replaces with FortiGate-VM 7.0.14 (already built locally) as consolidated CE + FortiSD-WAN + NGFW, which carries the SD-WAN demonstration story and Fortinet market-coverage simultaneously. EC-V revert path is documented for when access materialises — return to EC-V at Northwind, retain FortiGate as additional perimeter behind it OR redirect FortiGate to a fourth tenant slot.
9. **HPE Aruba CX simulator subject to HPE Networking Support Portal export-compliance review** (added v1.1). AOS-CX 10.16.1040 LSR OVA download request submitted May 31 2026 evening, ~4 hour SLA in the review queue. Approval is automatic for Australia (not on export-restricted list); availability for build expected Monday morning. Helix LAN Aruba CX node may be unavailable until then; basic Linux container substitute can stand in for the LAN switch role in the interim.

## 10. Migration plan (ADR-001 v1.6 → ADR-002 v1.0)

### Phase 1 — Document the pivot (this ADR)

Commit `docs/adr-002-two-region.md` to repo. Reference from `docs/lab-architecture.md` (ADR-001 v1.6) header as "Superseded by ADR-002".

### Phase 2 — Region A local infrastructure (Monday morning, post-v1.1 refinement)

Priority vrnetlab wrappers, building only what Region A actually needs (revised in v1.1 for FortiGate at Northwind, PA-VM at Helix CE, AOS-CX in queue):

- **`vrnetlab/vr-pan:9.0.4`** — Palo Alto VM-Series 9.0.4 (HIGH — Helix Health CE perimeter NGFW; OVA in hand May 31 2026; unlicensed-mode demo viable for Monday interview; eval authcode applied when arrives)
- **`vrnetlab/aoscx:10.16.1040`** — HPE Aruba CX simulator (HIGH — Helix Health LAN switching in Region A; OVA download Monday morning when HPE review queue expires)
- `vr-sros` — Nokia SR OS 13.0 R4 with RTC patch (HIGH — required for Nokia PE)
- `vr-vios-l2` — Cisco IOSv-L2 (MEDIUM — LAN switching alternative for "always-available" tenants in Region A)
- `vr-routeros` — MikroTik CHR (LOW — was high priority in v1.0 when MikroTik was Northwind CE; demoted in v1.1 because FortiGate now serves that role; kept as backup/spare CE option)
- `vr-csr` — Cisco CSR1000v 16.8 (MEDIUM — offline fallback for Cisco CE when DevNet unavailable)
- **`vrnetlab/vr-fortios:7.0.14`** — already built May 31 2026; no rebuild needed

Skip from ADR-001 v1.6 marathon:
- `vr-vios` (IOS XE L3) — DevNet CML provides newer
- `vr-xrv` (IOS XR 6.1.3) — DevNet CML provides current 7.x

Build session ordering (Monday morning, ~120-150 min total):
1. Pull HPE AOS-CX `.ova.zip` (when download approval lands), extract `.vmdk`, convert to qcow2, build `vrnetlab/aoscx` (~35 min)
2. Extract PA-VM OVA tar, convert vmdk to qcow2, build `vrnetlab/vr-pan:9.0.4` (~45 min — PA-VM first boot is slow)
3. Build `vr-sros` with RTC patch (~30 min)
4. Smoke-test all three nodes via SSH + brief BGP/zone config (~20 min)
5. Commit ADR-002 v1.1 + new tenant workload YAML stubs (~10 min)

### Phase 3 — Region B CML topology design (Sunday late / Monday morning)

Author `region-b-cisco-cml/cml-topology.yml` — a CML lab definition that, when uploaded via CML REST API, creates:

- 2× Cisco IOS XR 7.x (one P, one PE)
- 1× Cisco Cat8000v IOS XE 17.x (alternative PE)
- 2× Cisco Cat8000v (cEdges for two tenants)
- 1× HPE Aruba CX (Helix Health LAN, if hosted in this CML)
- Internal links + 1× external connector for management plane

Author corresponding Ansible playbook `region-b-cisco-cml/ansible/deploy.yml` that:

1. Detects an active DevNet reservation
2. Authenticates to CML at `https://10.10.20.161/api/v0/`
3. Uploads the lab topology
4. Starts all nodes
5. Applies per-node configs from `region-b-cisco-cml/configs/`

### Phase 4 — Interconnect (Monday morning)

Configure eBGP between Region A's Nokia SR OS PE and Region B's Cisco IOS XR PE. Validate session reaches Established. Validate route exchange.

### Phase 5 — Demo rehearsal (Monday afternoon)

Practice the two-region demo as a screen-share narrative. Key talking points:
- Architecture decision driven by empirical validation
- Region split mirrors real AU carriers
- ADR-002 supersedes ADR-001 with documented reasoning
- Reproducibility via topology-as-code

## 11. Operational runbook (preview)

Full runbook lives in `docs/runbook.md` post-implementation. Preview of the operational shapes:

### Daily — Region A only
```
# Already running. Just verify.
cd ~/aurora-comms/region-a-nokia
containerlab inspect -t clab-region-a.yml
```

### On-demand — Region B reservation + topology deploy
```
# 1. Reserve DevNet sandbox (manual via DevNet portal)
# 2. Capture VPN credentials
# 3. Connect openconnect in Dell WSL2
sudo openconnect --user=<dev-username> <vpn-endpoint>

# 4. Capture tun0 IP for region-boundary BGP
ip -br -4 addr show tun0

# 5. Deploy Region B via Ansible
cd ~/aurora-comms/region-b-cisco-cml
ansible-playbook ansible/deploy.yml -e tun0_ip=<captured-ip>
```

### Two-region cross-validate
```
# From Region A Nokia PE
ssh admin@nokia-pe-1 'show router bgp summary'
# Verify Region B Cisco PE shows as Established

# From Region B Cisco PE (via DevNet CML console)
show ip bgp summary
# Verify Region A Nokia PE shows as Established
```

### Teardown — end of demo
```
# Tear down Region B (free DevNet slot)
End reservation via DevNet portal

# Region A stays running (daily operational state)
```

## 12. Interview narrative

After ADR-002 ships, the interview story becomes:

> "I designed Aurora as a single-region MSP carrier in ADR-001. On May 31 2026 I empirically validated DevNet sandbox integration via openconnect-in-WSL2 — containers reach DevNet IPs at L3 and L7 transparently via Docker MASQUERADE. That validation surfaced a better architecture: a two-region carrier with Nokia at one region locally and Cisco-dominant at the other region in DevNet CML. I committed ADR-002 the same evening, deprecated five planned vrnetlab wrappers from the old plan because DevNet CML provides current production-version equivalents, and rebuilt the marathon priorities to focus on what Region A actually needs. The architecture mirrors how real AU carriers like Telstra structure themselves — multi-region, multi-vendor, with regional vendor specialisation. ADR-002 is the canonical design now; ADR-001 stays in repo as historic record of the decision path."

That demonstrates:
- Empirical engineering reasoning
- Willingness to deprecate prior work when better evidence arrives
- Documentation rigor (ADRs, not just changes)
- Realistic carrier design knowledge
- Operational maturity (ephemeral cloud resources used appropriately)

## 13. Risks and mitigations

| Risk | Mitigation |
| --- | --- |
| DevNet sandbox unavailable when demo needed | Demo Region A only; mention Region B as part of architecture intent |
| eBGP across openconnect tunnel fails to establish | Fall back to single-region Aurora; document the finding |
| MASQUERADE source IP changes per VPN session | Capture tun0 IP at session start; template Region B BGP neighbor from it via Ansible |
| CML API quirks in this specific DevNet sandbox | Build Region B manually via CML web UI first; automate later |
| Time pressure before Monday's interview | Path A (document intent + essential builds tonight, full implementation Tuesday) was rejected; Path B requires disciplined execution |
| **PA-VM authcode delivery beyond 72-hour SLA window** (v1.1) | Run PA-VM unlicensed for Monday interview — zones, security policy, BGP, OSPF, NAT, virtual routers all function; verbal narrative covers eval-mode subscription-feature limitation cleanly. Authcode applied to demonstrate Threat Prevention + URL Filtering at follow-up technical interview when it arrives. |
| **HPE AOS-CX download stuck in HPE export-compliance queue beyond Monday morning** (v1.1) | Helix LAN substituted with generic Linux container running OVS or Open vSwitch + VLAN trunk for the demo; AOS-CX architectural intent documented in §3.5.1 + §3.5.3 as pending. Australian export compliance approval is procedural and effectively certain. |
| **EdgeConnect EC-V trial procurement extends well beyond W4** (v1.1) | FortiSD-WAN at Northwind CE permanently carries the SD-WAN demonstration story if EC-V access never materialises. The architectural intent statement in §3.5.3 + §3.5.1 is interview-defensible without EC-V actually being deployed — vendor procurement reality is expected and respected by senior interviewers. |
| **PA-VM 9.0.4 is EOL software** (PAN-OS 9.0 EOL March 2023) (v1.1) | Functional for lab/learning; not for production demos. Interview narrative explicitly frames: "I run 9.0.4 for the architectural and protocol-level demonstration — modern subscription features in 11.x are documented as the production target stack." |
| **Cisco UCSPE installation slips beyond Tuesday** (v1.1, §3.8) | DMTF Redfish mockup Docker container takes ~5 minutes to spin up and provides the vendor-agnostic server skills story alone; UCSPE adds Cisco-specific depth but is not the only path to server-architecture fluency. |

## 14. References

- `docs/lab-architecture.md` — ADR-001 v1.6 (historic, superseded)
- `docs/design.md` — protocol-level Aurora design (still applies, scoped per region)
- `docs/ip-plan.md` — IP and AS plan (will be amended with confederation IDs)
- `BACKLOG.md` — sprint plan, will be updated to reflect Region A vs Region B work
- DevNet Cisco SD-WAN 20.12 sandbox documentation (per-reservation)
- `hellt/vrnetlab` — vrnetlab wrappers for Region A's local image inventory
