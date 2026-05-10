# Aurora Communications — Network Design Document

| Field | Value |
| --- | --- |
| Document version | 1.0 |
| Status | Active — W1 baseline complete |
| Owner | Network Architecture (Elvis Ifeanyi Nwosu) |
| Last updated | May 2026 |
| Supersedes | n/a (initial document) |

## 1. Purpose and scope

Aurora Communications is a fictional Australian regional IP carrier operated as the network tier of the Sentinel Ridge MSP teaching/portfolio environment. This document describes the W1 backbone — four POPs, single AS, IS-IS + MPLS-LDP + iBGP. It is the canonical reference for what the network is and why it is that way. Manual configurations, Ansible templates, and verification scripts must reproduce what is described here.

Out of scope for this revision: customer L3VPN service definitions, eBGP peering policy with upstream transit, edge access (PE-CE) configuration. These will be documented separately as they are added.

## 2. Design context

Aurora serves three enterprise tenants in the Sentinel Ridge MSP topology: Maple Ridge Logistics (VPRN L3VPN, three sites), Helix Health Analytics (DIA + DDoS scrubbing), and Northwind Robotics (DIA + SD-WAN headend). The carrier must support IP transit, MPLS L3VPN, Carrier Ethernet (E-Line / E-LAN), and DDoS scrubbing — all layered on the same physical backbone.

Geographic scope: four POPs in Melbourne (HQ + core), Sydney, Brisbane, and Geelong (regional access).

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

### 3.3 iBGP structure — Route Reflectors from W2

**Decision:** Two route reflectors at Melbourne core. All other PEs are RR clients. iBGP is currently full-mesh (W1 baseline) but migrates to RR-based in Sprint W2.

**Rationale:**
- Real carriers deploy RRs from day one regardless of POP count, because retrofitting RRs into an established full-mesh network is more disruptive than building with them in place.
- Two RRs at the same physical site (Melbourne) provide control-plane redundancy without requiring complex multi-RR consistency logic.
- The W1 full-mesh is acceptable as a transitional state — we have four PEs and six iBGP sessions today, manageable, and the migration to RR is a documented change.

**Why not full-mesh long-term:** At the inflection point of ~6 PEs, full-mesh becomes operationally painful (each new PE requires touching every existing PE's config). RRs eliminate that pain.

### 3.4 IP plan — hierarchical RFC 1918, /31 P2P

**Summary:** Loopbacks in `10.0.0.0/24` (one /32 per router), P2P links in `10.1.0.0/16` (each /31 per RFC 3021), customer space reserved at `10.2.0.0/16`, management at `10.3.0.0/16`. Full plan in `ip-plan.md`.

**Rationale:**
- /31 P2P per RFC 3021 conserves address space (50% utilisation improvement vs /30) and is the carrier-grade standard.
- Hierarchical /16 allocations make summarisation possible at future area boundaries.
- RFC 1918 space is acceptable for the lab; production would use the carrier's PI block.

**Future:** IPv6 dual-stack lands in W3 — `2001:db8:aurora::/48` allocated, `/128` per loopback, `/127` per P2P link per RFC 6164.

### 3.5 Platform — FRR for the lab, Nokia SR OS / Cisco IOS-XR for production reference

**Decision:** All four PEs run FRRouting (FRR) latest in Docker containers via Containerlab. Multi-vendor reference configurations (Nokia SR OS, Cisco IOS-XR) are maintained in `lab/manual/` for the same intent.

**Rationale:**
- FRR is production-grade — Facebook, LinkedIn, Equinix run it at scale. Same protocols, same routing decisions, lower lab footprint.
- Nokia SR OS reference configs match the operator's production background.
- Cisco IOS-XR reference configs serve the multi-vendor learning narrative.
- Each new feature lands in all three vendor flavours, with `compare.md` as the side-by-side artifact.

## 4. Topology

Four POPs, fully meshed. Each PE has three P2P interfaces connecting to the other three PEs. Square + two diagonals = K4 (complete graph on four nodes). Six links total.

```
       Melbourne ──── 10.1.12.0/31 ──── Sydney
          │  \                        /   │
          │   \ 10.1.13.0/31  10.1.24.0/31
          │    \                    /     │
      10.1.14.0/31 \              /       │
          │         Brisbane ── 10.1.23.0/31
          │          /     \
          │         /   10.1.34.0/31
          │        /         \
       Geelong ─────────────╯
```

| POP | Role | Loopback | NET |
| --- | --- | --- | --- |
| Melbourne | Core / RR site (W2) | 10.0.0.1 | 49.0001.0010.0000.0001.00 |
| Sydney | PE | 10.0.0.2 | 49.0001.0010.0000.0002.00 |
| Brisbane | PE | 10.0.0.3 | 49.0001.0010.0000.0003.00 |
| Geelong | PE (regional access) | 10.0.0.4 | 49.0001.0010.0000.0004.00 |

**Why fully meshed at four POPs:** Maximum redundancy (three independent paths between any pair of PEs) and trivial ECMP. At sixteen POPs we would migrate to a partial mesh with dedicated P-only core routers and aggregation/access tiers.

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
