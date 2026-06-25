# Aurora Communications — IP, AS, And RD/RT Plan

| Field | Value |
| --- | --- |
| Document version | 2.5 |
| Status | Active index; Region A summary mirrors `region-a-plan.md` §4 |
| Last updated | 2026-06-24 |

This file is the cross-region addressing index. The **canonical executable source for Region A** remains `docs/region-a-plan.md` §4. If this summary and Region A disagree, fix this summary or follow `region-a-plan.md`.

Earlier ADR-001 numbering (`AS65100`, `10.1.0.0/16`) is retired for the active lab. The **Australia-wide POP names are not retired**: Melbourne, Sydney, Brisbane, Geelong, Adelaide, Perth, Darwin, and Tasmania/Hobart remain the carrier geography that the lab represents.

## Region Map

| Region | Role | Addressing status |
| --- | --- | --- |
| Region A | Local Dell GNS3 Cisco ISP/core fabric: ADL -> GEL -> MEL-PE1 -> MEL-P | Active; values below |
| Region B | PC1 / DevNet CML Cisco + Juniper extension, including Brisbane and Sydney PEs | **Proposed plan** in `ops/region-b-cml/addressing.md` (2026-06-23) — `10.0.20.0/24` loopbacks, `10.255.20.0/24` core, member-AS `65002`; reservation-assigned mgmt recorded per reservation. Ratify before deploy |
| Region C | Cloud edge with cRPD/FRR/Routinator | Planned; cloud public/private addressing to be recorded when provisioned |

## Secure Ring Addressing Model

ADR-004 splits host management from lab transport:

| Ring | Addressing owner | Notes |
| --- | --- | --- |
| Management ring | Tailscale plus existing host LANs | PC1, PC2/Dell, DigitalOcean host, and Oracle host. Hosts can manage lab nodes; lab nodes must not initiate host-admin sessions. |
| Lab data-plane ring | Virtual edge-router interfaces and WireGuard tunnel /31s or /127s | `pc1-edge`, `pc2-edge`, `do-edge`, and `oci-edge`. Runs eBGP or IS-IS for reconvergence practice. |

The PC1/PC2/cloud host OS addresses are protected endpoints, not routed lab loopbacks. Cloud host addresses must be recorded separately from the virtual edge-router addresses when Region C is built.

### Lab data-plane ring — edge reservations

Allocated for the virtual site-edge routers (`ops/ring/`). Deliberately **separate** from the carrier POP loopbacks (`10.0.0.1–10.0.0.9`) and CE loopbacks (`10.0.1.x`), so a ring-edge can never be confused with a carrier PE.

| Edge node | ASN | Loopback | Ring neighbours |
| --- | --- | --- | --- |
| `pc1-edge` | `64503` | `10.0.2.1/32` | pc2-edge, oci-edge |
| `pc2-edge` | `64504` | `10.0.2.2/32` | pc1-edge, do-edge |
| `do-edge` | `64505` | `10.0.2.3/32` | pc2-edge, oci-edge |
| `oci-edge` | `64506` | `10.0.2.4/32` | do-edge, pc1-edge |

Ring transport `/31`s (separate from the carrier backbone `10.255.0.0/24`):

| Ring leg | Transport | Carrier |
| --- | --- | --- |
| `pc1-edge` ↔ `pc2-edge` | ethernet `192.168.137.x` (no tunnel) | existing internet-carrying local link |
| `pc2-edge` ↔ `do-edge` | `10.255.255.0/31` (WireGuard) | per-edge WG keypair |
| `do-edge` ↔ `oci-edge` | `10.255.255.4/31` (WireGuard, cloud-to-cloud) | per-edge WG keypair |
| `oci-edge` ↔ `pc1-edge` | `10.255.255.2/31` (WireGuard) | per-edge WG keypair |

ASNs `64503–64506` are unused entries in the RFC 5398 documentation range (`64496–64511`). The ring runs eBGP between these edge ASNs for reconvergence practice; **no host/management subnet is ever advertised into the ring** (`NO-HOST-SUBNETS` egress guard, `ops/ring/ring-ebgp.example.conf`). Concrete loopback/transport values are placeholders until Region C is provisioned.

## National POP Overlay

Region A/B/C are deployment domains. POP names are the national carrier topology.

| POP | Active / target node | Function |
| --- | --- | --- |
| Melbourne | `Aurora-P` (`MEL-P`), `Aurora-PE-1` (`MEL-PE1`) | National core, primary transit, Melbourne IXP, Northwind edge |
| Sydney | PC1 / Region B target `SYD-PE1` / `Aurora-PE-3` | Transport reached via right-side `MEL-P` (the inter-region eBGP border is `MEL-PE1`, not SYD-PE1); major interconnect, Region B/C handoff, first IOS-XR ROV enforcer |
| Brisbane | Region B target `BNE-PE1` / `Aurora-PE-2` | Regional enterprise edge and Helix services |
| Geelong | `GEL-PE1` | Dell/PC2 regional-line midpoint, drawn left of `MEL-PE1` |
| Adelaide | `ADL-PE1` | Dell/PC2 left-side regional-line endpoint and south-central aggregation POP |
| Perth | planned `PER-PE1` | Western Australia POP |
| Darwin | planned `DRW-PE1` | Northern remote POP |
| Tasmania / Hobart | planned `HBA-PE1` / `TAS-PE1` | Island POP |

Placement rule: the local line is hosted on Dell/PC2 in the Region A GNS3 project and is drawn geographically west-to-east as `ADL-PE1 -> GEL-PE1 -> MEL-PE1 -> MEL-P`. `MEL-P` sits on the right and is the logical handoff toward PC1 / Region B `SYD-PE1`. Sydney and Brisbane are Region B nodes, not local Region A nodes.

## Region A — Loopbacks And Management

| Node | Loopback | Management | Role |
| --- | --- | --- | --- |
| `Aurora-P` (`MEL-P`) | `10.0.0.1/32` | `10.255.191.11/24` | Cisco IOS-XRv 6.1.3 P router; IS-IS L2 + LDP only |
| `Aurora-PE-1` (`MEL-PE1`) | `10.0.0.2/32` | `10.255.191.12/24` | Cisco IOS-XRv 6.1.3 PE; Northwind, Transit-A, logical Melbourne IXP attachment |
| `GEL-PE1` | `10.0.0.5/32` | `10.255.191.15/24` | Cisco IOS-XRv 6.1.3 PE; Dell/PC2 regional-line midpoint |
| `ADL-PE1` | `10.0.0.6/32` | `10.255.191.17/24` | Cisco IOS-XRv 6.1.3 PE; Dell/PC2 regional-line endpoint and Transit-B backup edge |
| `northwind-ce` | `10.0.1.1/32` | PE-CE link / DHCP | FortiGate CE, default private AS model |
| `region-a-ce-spare` | `10.0.1.2/32` | PE-CE link / DHCP | Optional IOSv CE |
| `helix-lan-sw` | n/a | `10.255.191.16/24` | Aruba CX L2/L3 access practice switch |

## Reserved POP Loopbacks

These are reserved for future expansion and should be added to configs only when the POP is instantiated.

| Planned POP node | Loopback | Management reservation | Role |
| --- | --- | --- | --- |
| `PER-PE1` | `10.0.0.7/32` | `10.255.191.18/24` | Perth / WA PE |
| `DRW-PE1` | `10.0.0.8/32` | `10.255.191.19/24` | Darwin / northern remote PE |
| `HBA-PE1` (`TAS-PE1`) | `10.0.0.9/32` | `10.255.191.20/24` | Hobart / Tasmania PE |

## Region B — Planned POP Placeholders

Region B CML management addressing is TBD until the DevNet reservation topology is created. The national POP aliases are reserved here so they are not reintroduced into Region A by mistake.

> **PROPOSED (2026-06-23, ratify before deploy):** the full Region B build plan lives in
> `ops/region-b-cml/addressing.md`. Headline allocations, kept disjoint from Region A:
> carrier loopbacks `10.0.20.0/24`, CE loopbacks `10.0.21.0/24`, backbone /31s
> `10.255.20.0/24`, PE-CE /30s `10.255.21.0/24`; IS-IS area `49.0002`; member-AS `65002`
> under confederation `64496` (inter-region eBGP to Region A `64496` until Region A is
> later migrated to member-AS `65001`). Tenants reuse carrier RD/RT `64496:1`
> (Maple Ridge) / `64496:2` (Helix). When instantiated, replace this note with the
> ratified values mirrored from `addressing.md`.

> **Inter-region border (canonical):** the Region A-side inter-region border / ASBR is
> `MEL-PE1` (`Aurora-PE-1`, Lo0 `10.0.0.2`). It terminates the inter-region eBGP
> `64496 ↔ 65002` to Region B's `DC-P-R1` (Option A only — global IPv4 unicast, no MPLS
> label transfer across the openconnect + MASQUERADE NAT). `MEL-P` is a pure P router and
> serves only as the right-side transport handoff toward PC1 / Region B; it is not the
> BGP border. `SYD-PE1` is a Region B node (Sydney edge, first IOS-XR ROV enforcer) and is
> not the Region A end of the A↔B boundary.

| Planned Region B node | Carrier loopback reservation | Management | Role |
| --- | --- | --- | --- |
| `BNE-PE1` / `Aurora-PE-2` | TBD in Region B build | TBD | Brisbane / Helix enterprise edge |
| `SYD-PE1` / `Aurora-PE-3` | TBD in Region B build | TBD on PC1 / CML | Sydney interconnect logically reached from `MEL-P`, Region B/C handoff, first IOS-XR ROV enforcer |

Management reachability is via the PC1/Dell internet-carrying Ethernet segment:

| Endpoint | Address |
| --- | --- |
| PC1 Ethernet / gateway / Routinator host | `192.168.137.1` |
| Dell GNS3 controller | `192.168.137.1:3080` |
| GNS3 VM Tailscale | `100.118.0.46` |
| GNS3 management TAP | `10.255.191.1/24` |

## Region A — ASNs

Region A uses RFC 5398 documentation ASNs for lab safety. Nothing is advertised to the real Internet.

| ASN | Owner / purpose |
| --- | --- |
| `64496` | Aurora carrier AS |
| `64497` | Transit-A (`transit-a-csr`) |
| `64498` | Transit-B (`transit-b-iol`) |
| `64499` | IXP route server (`ixp-rs1`) |
| `64500` | IXP content/CDN peer |
| `64501` | IXP eyeball/ISP peer |
| `64502` | Optional BYO-AS customer model |
| `64512` | Default private Northwind CE AS |

## Region A — Infrastructure Links

| Link group | IPv4 | IPv6 | Notes |
| --- | --- | --- | --- |
| P/PE backbone | `10.255.0.0/24` carved as /31s | `2001:db8:ffff::/64` carved as /127s | IS-IS/LDP transport |
| `Aurora-P` ↔ `Aurora-PE-1` | `10.255.0.0/31` | `2001:db8:ffff::/127` | Backbone link |
| `Aurora-PE-1` (`MEL-PE1`) ↔ `GEL-PE1` | `10.255.0.6/31` | next /127 | Dell/PC2 regional-line link |
| `GEL-PE1` ↔ `ADL-PE1` | `10.255.0.8/31` | next /127 | Dell/PC2 regional-line link |
| `MEL-P` ↔ PC1 / Region B | TBD in Region B build | TBD | Transport handoff only; not a local Dell/PC2 node link yet. The inter-region eBGP border itself is `MEL-PE1` (`64496 ↔ 65002` to Region B `DC-P-R1`) — `MEL-P` is pure transport, not the ASBR |
| PE-CE links | `10.255.1.0/24` carved as /30s | matching /127s | Customer/enterprise edge |
| PE-1 ↔ Transit-A | `10.255.2.0/30` | `2001:db8:ffff:2::/127` | Primary default |
| ADL-PE1 ↔ Transit-B | `10.255.2.4/30` | `2001:db8:ffff:2::2/127` | Region A local backup default |
| IXP LAN | `10.255.3.0/24` | `2001:db8:ffff:3::/64` | PE-1 `.1`, future SYD-PE1 `.3`, RS `.10`, content `.20`, eyeball `.30`; FRR peers can be Region B/PC1 Docker offload |

## Region A — Public/Test Prefixes

All public-looking space is documentation-only.

| Prefix | Origin / purpose |
| --- | --- |
| `203.0.113.0/25` | Aurora mock PI block |
| `203.0.113.128/25` | Customer block; originated by Aurora in the default private-AS model |
| `192.0.2.0/24` slices | Mock Internet prefixes from transits |
| `198.51.100.0/25` | IXP content/CDN prefixes |
| `198.51.100.128/25` | IXP eyeball/ISP prefixes |
| `2001:db8:aaaa::/48` | Aurora IPv6 mock PI |
| `2001:db8:bbbb::/48` | Customer IPv6 block |
| `2001:db8:a::/48` | Transit-A sample IPv6 Internet |
| `2001:db8:c0::/48` | IXP content/CDN IPv6 |
| `2001:db8:e0::/48` | IXP eyeball/ISP IPv6 |

## Region A — VRF / L3VPN Conventions

Cisco Region A uses VRF/L3VPN terminology. The old Nokia `VPRN` wording is archived with ADR-002 and the Nokia recipe.

| Customer / test | ID | RD | RT |
| --- | --- | --- | --- |
| Maple Ridge | `1` | `64496:1` | `64496:1` |
| Helix Health | `2` | `64496:2` | `64496:2` |
| Northwind | `3` | `64496:3` | `64496:3` |
| L3VPN validation VRF `CUST-A` | `100` | `64496:100` | `64496:100` |

## RPKI / ROV

| Item | Value |
| --- | --- |
| Validator / RP | Routinator on PC1 |
| RTR endpoint | `192.168.137.1:3323` |
| VRP source | SLURM local assertions for documentation prefixes |
| First enforcer | Region B `SYD-PE1` / `Aurora-PE-3` |
| Final target | All eBGP ingress points: Transit-A, Transit-B, IXP sessions |

## Region B And Region C Placeholders

Region B and Region C are intentionally not allocated in detail yet:

- Region B depends on DevNet CML reservation topology and available node images.
- Region C depends on DigitalOcean public/private addressing at provisioning time.

When those regions are built, add them here as separate sections and keep each region's executable build plan as the canonical source.
