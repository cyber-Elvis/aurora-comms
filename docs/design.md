# Aurora Communications — Network Design Document

> **Current scope note (ADR-003 v1.4 / ADR-004 v1.0, 2026-06-15):** this document is now a protocol-design reference, not the executable build plan. The active build is the Cisco Region A core in `docs/region-a-plan.md` v2.5: Dell/PC2 hosts the `ADL-PE1 -> GEL-PE1 -> MEL-PE1 -> MEL-P` line, with `MEL-PE1` as the Region A-side inter-region border/ASBR (inter-region eBGP `64496 <-> 65002` to Region B's `DC-P-R1`) and `MEL-P` a pure-P transport handoff toward PC1 / Region B. Brisbane and Sydney are Region B CML nodes. Transit-A and Transit-B remain local Region A Internet-edge nodes on `MEL-PE1` and `ADL-PE1`; FRR IXP peers and tenant workload containers are Region B/PC1 Docker offload candidates. The **Melbourne/Sydney/Brisbane/Geelong/Adelaide/Perth/Darwin/Tasmania POP geography remains current**. ADR-004 adds the secure management/data-plane ring model: host OSes are protected management anchors, while virtual edge routers carry lab transport. Older FRR/containerlab, AS65100, and Nokia/VPRN wording below is retained for historical rationale unless superseded inline.

| Field | Value |
| --- | --- |
| Document version | 1.3 |
| Status | Reference / protocol design; executable Region A build superseded by ADR-003 |
| Owner | Network Architecture (Elvis Ifeanyi Nwosu) |
| Last updated | 2026-06-15 |
| Supersedes | n/a (initial document) |

## 1. Purpose and scope

Aurora Communications is a fictional Australian regional IP carrier operated as the network tier of the Sentinel Ridge MSP teaching/portfolio environment. This document describes the national POP model — Melbourne, Sydney, Brisbane, Geelong, Adelaide, Perth, Darwin, and Tasmania/Hobart — plus the reference protocol shape: single AS, IS-IS + MPLS-LDP + iBGP. `region-a-plan.md` is canonical for the current Cisco implementation details; this file is canonical for why the carrier geography and protocol choices exist.

Out of scope for this revision: customer L3VPN service definitions, eBGP peering policy with upstream transit, edge access (PE-CE) configuration. These will be documented separately as they are added.

## 2. Design context

Aurora serves three enterprise tenants in the Sentinel Ridge MSP topology: Maple Ridge Logistics (VPRN L3VPN, three sites), Helix Health Analytics (DIA + DDoS scrubbing), and Northwind Robotics (DIA + SD-WAN headend). The carrier must support IP transit, MPLS L3VPN, Carrier Ethernet (E-Line / E-LAN), and DDoS scrubbing — all layered on the same physical backbone.

Geographic scope: eight POPs in Melbourne (HQ + core), Sydney, Brisbane, Geelong (regional access), Adelaide, Perth, Darwin, and Tasmania/Hobart.

## 3. The five design decisions

### 3.1 IGP — IS-IS, single Level 2 area

**Decision:** All Aurora routers run IS-IS in `level-2-only` mode within a single area `49.0001`.

**Rationale:**
- IS-IS scales better than OSPF in flat carrier topologies (fewer LSPs, less periodic flooding).
- IS-IS runs directly on Layer 2 (ISO/CLNS), so the IGP keeps converging through partial IP-plane failures.
- Wide metrics (24-bit per RFC 5305) are native and standard for carrier deployments.
- IS-IS is the de-facto IGP in real carriers globally — Optus, NBN, Telstra IP Core, AT&T, Verizon all run IS-IS in their backbones.

**Why not OSPF:** Enterprise networks favour OSPF because surrounding tooling (DHCP relay, integration with appliance vendors) is OSPF-aware. Carriers do not need that integration; they need scale and operational stability.

**Scaling plan:** At the four-POP scale, single-area is correct. Above eight POPs we will introduce L1/L2 hierarchy with regional L1 areas and a Level-2 backbone. The L1/L2 boundary will sit at the regional aggregation routers.

### 3.2 MPLS label distribution — LDP today, SR-MPLS in W3

**Decision:** LDP for baseline label distribution today; Segment Routing (SR-MPLS) added as a parallel control plane in W3, with LDP retained for compatibility during transition.

**Rationale:**
- LDP is operationally simple — labels follow the IGP shortest-path tree without manual configuration.
- The realistic carrier transition path in 2026 is "SR-MPLS as the strategic direction, LDP retained for legacy services" — we are mirroring that.
- SR-MPLS enables TI-LFA fast reroute (sub-50ms), traffic engineering without RSVP, and a simpler operational model.

**Why not RSVP-TE:** RSVP-TE is heavyweight and operationally noisy; it has been superseded by SR-MPLS in most modern deployments. We will not deploy RSVP-TE.

### 3.3 iBGP structure — full mesh now, route reflectors later

**Decision:** The local Region A PEs use a full-mesh VPNv4 iBGP overlay. Route reflectors are deferred until the POP count and Region B/C attachment make them operationally useful.

**Rationale:**
- Real carriers often deploy RRs early, but the current Dell/PC2 slice has only three BGP-speaking PEs and is easier to reason about as a full mesh while the fabric is still being built.
- When RRs are introduced, place redundant reflectors at major interconnect POPs rather than on the P-only `MEL-P` transport node.
- The current local full-mesh is acceptable as a transitional state — Region A has three local PEs (`MEL-PE1`, `GEL-PE1`, `ADL-PE1`) and three iBGP VPNv4 sessions, manageable, with `SYD-PE1` joining later from Region B.

**Why not full-mesh long-term:** At the inflection point of ~6 PEs, full-mesh becomes operationally painful (each new PE requires touching every existing PE's config). RRs eliminate that pain.

### 3.4 IP plan — hierarchical RFC 1918, /31 P2P

**Summary:** Carrier loopbacks live in `10.0.0.0/24`, local Region A P2P links use `10.255.0.0/24` carved into /31s, PE-CE links use `10.255.1.0/24`, Internet-edge links use `10.255.2.0/24`, and node management uses `10.255.191.0/24`. Full plan in `ip-plan.md`.

**Rationale:**
- /31 P2P per RFC 3021 conserves address space (50% utilisation improvement vs /30) and is the carrier-grade standard.
- Hierarchical /16 allocations make summarisation possible at future area boundaries.
- RFC 1918 space is acceptable for the lab; production would use the carrier's PI block.

**Future:** IPv6 dual-stack lands after the IPv4 fabric is stable, using RFC 3849 documentation space from `2001:db8::/32` with /127s on P2P links per RFC 6164.

### 3.5 Platform — Cisco IOL-L3 for the local core, FRR for IXP roles

> **Superseded for the executable build (ADR-003 v1.4, 2026-06-15).** The W1 baseline used FRR containers for rapid protocol validation. The built **Region A is now a Cisco GNS3 core** — IOL-AdvEnterprise-L3 for `MEL-P`, `MEL-PE1`, `GEL-PE1`, and `ADL-PE1` per `region-a-plan.md` v2.5. IOS-XRv moves to Region B as `SYD-PE1` / `Aurora-PE-3`. FRR is retained for the **IXP route-server / RPKI reference** role, not as the PE platform, and Docker-dependent FRR peers should run from Region B/PC1 when practical; Nokia SR OS is archived. The protocol design below (IS-IS / LDP / BGP-VPNv4) is vendor-agnostic and still applies.

**Decision:** The executable local core runs Cisco IOL-L3 in GNS3. Local Region A keeps both simulated upstream transits; FRR remains in the lab as route-server/content/eyeball peers and as a lightweight reference stack, preferably hosted from Region B/PC1 Docker. Multi-vendor reference configurations (Nokia SR OS, Cisco IOS-XR, FRR) remain in `lab/manual/` for comparison and historical rationale.

**Rationale:**
- Cisco IOL-L3 gives the Dell/PC2 slice a light, working MPLS L3VPN platform with IOS-style operations.
- FRR is production-grade for route-server and peering roles — Facebook, LinkedIn, Equinix run it at scale.
- Nokia SR OS and Cisco IOS-XR reference configs preserve the multi-vendor learning narrative while the executable Region A build stays Cisco-light.
- Each new feature lands in all three vendor flavours, with `compare.md` as the side-by-side artifact.

## 4. Topology

Eight national POPs are modelled as a tiered carrier backbone rather than an 8-node full mesh. The active local lab slice is the Dell/PC2 regional line `ADL-PE1 -> GEL-PE1 -> MEL-PE1 -> MEL-P`; Sydney and Brisbane are Region B CML targets, while PER/DRW/HBA remain reserved expansion POPs. In a real carrier, this avoids the operational mess of every POP connecting to every other POP and makes maintenance/failure domains clearer.

ADR-004 adds a separate secure inter-site ring for the lab execution domains: PC1, PC2/Dell, DigitalOcean, and Oracle are connected by a management ring, while virtual edge routers (`pc1-edge`, `pc2-edge`, `do-edge`, `oci-edge`) form the lab data-plane ring. Do not treat PC1, PC2, or cloud host OSes as routed lab nodes.

```text
                         DRW
                          |
                         BNE
                          |
       PER ---- ADL ---- MEL ==== SYD
                         |        |
                        GEL      HBA/TAS
```

Legend: `====` = high-capacity east-coast core/interconnect path; `----` / `|` = regional transport/backhaul. The lab can instantiate this progressively with light IOL PEs or by moving selected POPs to DevNet CML/cloud.

| POP | Role | Loopback | NET |
| --- | --- | --- | --- |
| Melbourne | Local core / PE site: `MEL-PE1` (Region A-side inter-region border/ASBR — eBGP `64496<->65002` to Region B `DC-P-R1`), `MEL-P` (pure P, transport handoff only), Transit-A and logical IXP attachment | 10.0.0.1 / 10.0.0.2 | 49.0001.0010.0000.0001.00 / 49.0001.0010.0000.0002.00 |
| Sydney | Region B interconnect PE, Region B/C handoff, first ROV enforcer | TBD in CML | TBD |
| Brisbane | Region B regional enterprise PE / Helix service attachment | TBD in CML | TBD |
| Geelong | Local regional-line PE | 10.0.0.5 | 49.0001.0010.0000.0005.00 |
| Adelaide | Local south-central regional-line endpoint and Transit-B backup edge | 10.0.0.6 | 49.0001.0010.0000.0006.00 |
| Perth | Western Australia PE | 10.0.0.7 | 49.0001.0010.0000.0007.00 |
| Darwin | Northern remote PE | 10.0.0.8 | 49.0001.0010.0000.0008.00 |
| Tasmania / Hobart | Island PE | 10.0.0.9 | 49.0001.0010.0000.0009.00 |

**Why tiered at eight POPs:** the four-POP K4 was a good first lab shape, but the national model should look like a carrier backbone. MEL/SYD carry the east-coast core, ADL/PER extend west, BNE/DRW extend north, HBA/TAS captures island/backhaul failure scenarios, and GEL remains the regional access story.

## 5. Protocol matrix

| Protocol | Role | Failure impact |
| --- | --- | --- |
| IS-IS L2 | IGP — distributes loopback and P2P link reachability | Without IS-IS, iBGP TCP sessions cannot establish (loopbacks unreachable). LDP cannot find peers. Full backbone outage. |
| MPLS-LDP | Label distribution for forwarding | Without LDP, MPLS forwarding silently breaks. IS-IS and BGP keep working over the IP plane, but MPLS-encapsulated services (VPRN, VPLS) fail. |
| iBGP (full mesh today, RR in W2) | Routing information exchange between PEs | Without iBGP, customer routes don't propagate between PEs. PE-local services keep working. |
| BGP `update-source lo` | Source iBGP TCP from loopback | Without it, BGP sessions tie to physical interfaces and break on interface flap. |
| BGP `next-hop-self` | iBGP convention for eBGP-learned routes | Without it, internal routers cannot resolve next-hops for eBGP routes. |

## 6. Convergence model

After `containerlab deploy`, protocols converge bottom-up:

1. Interfaces up (instant) — Containerlab creates veth pairs.
2. IS-IS adjacencies form (~5s) — three hellos at default 3s interval.
3. IS-IS LSP exchange + SPF (~5–10s) — every PE learns every other PE's loopback.
4. Loopbacks become reachable via IS-IS — unblocks iBGP and LDP.
5. iBGP TCP sessions establish (~5s) — three-way handshake on TCP/179.
6. iBGP UPDATE exchange (~5s) — each PE advertises its `network 10.0.0.X/32`.
7. LDP UDP discovery (~5s) — neighbours discovered on each LDP-enabled interface.
8. LDP TCP sessions + label binding (~5s) — labels distributed.

Total convergence: 25–40 seconds from deploy. The deploy script waits 45 seconds for safety margin.

## 7. Failure scenarios

| Scenario | Expected behaviour |
| --- | --- |
| One P2P link fails | IS-IS reroutes within ~9s today (IGP-only) or sub-second post-W2 (with BFD). Two or three remaining paths between affected PEs. |
| One PE fails | Direct customers offline. Other PEs converge via remaining paths. iBGP withdraws routes from failed PE. |
| Both Melbourne RRs fail (post-W2) | All iBGP sessions drop. Backbone keeps forwarding existing flows but no new routing information propagates. Highest-severity event. |
| LDP daemon crashes on a P-router | MPLS forwarding breaks for that node. IP forwarding continues. Customer L3VPN traffic fails. |
| WSL2 kernel without MPLS support | LDP shows neighbours but MPLS forwarding plane is non-functional. Known W1 limitation. |

## 8. Forward roadmap

| Sprint | Items |
| --- | --- |
| W2 | Route reflectors, BFD, IS-IS / LDP / BGP authentication, BGP graceful restart |
| W3 | Segment Routing (SR-MPLS), TI-LFA, IPv6 dual-stack |
| W4 | First customer service: Maple Ridge VPRN |
| W5+ | RPKI, FlowSpec, SD-WAN headend |

Detailed backlog in `BACKLOG.md`.

## 9. References

- RFC 1142 — IS-IS for IP networks
- RFC 5305 — IS-IS extensions for traffic engineering (wide metrics)
- RFC 5036 — LDP specification
- RFC 4271 — BGP-4
- RFC 4456 — BGP route reflection
- RFC 3021 — /31 P2P addressing
- RFC 6164 — IPv6 /127 P2P addressing
- RFC 4364 — BGP/MPLS IP VPNs
- Nokia 7750 SR Service Configuration Guide (SR OS R23)
- Cisco IOS-XR Routing Configuration Guide
