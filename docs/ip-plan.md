# Aurora Communications — IP Plan

| Field | Value |
| --- | --- |
| Document version | 1.0 |
| Status | Active |
| Last updated | May 2026 |

## 1. Address allocation summary

| Block | Use | Status |
| --- | --- | --- |
| 10.0.0.0/24 | Loopback /32 per router | In use (4 of 256 used) |
| 10.1.0.0/16 | P2P backbone links (/31 each) | In use (6 links allocated) |
| 10.2.0.0/16 | Customer VPRN space | Reserved (W4+) |
| 10.3.0.0/16 | NMS / management | Reserved (W2) |
| 10.255.0.0/24 | iBGP cluster IDs (RR) | Reserved (W2) |

RFC 1918 is acceptable for the lab. Production Aurora would use the carrier's Provider-Independent (PI) IPv4 allocation.

## 2. Loopback assignments

Convention: `10.0.0.<router_id>/32`. Router-ID equals the host octet.

| Router | Loopback | Router-ID | NET (IS-IS) |
| --- | --- | --- | --- |
| Melbourne | 10.0.0.1/32 | 10.0.0.1 | 49.0001.0010.0000.0001.00 |
| Sydney | 10.0.0.2/32 | 10.0.0.2 | 49.0001.0010.0000.0002.00 |
| Brisbane | 10.0.0.3/32 | 10.0.0.3 | 49.0001.0010.0000.0003.00 |
| Geelong | 10.0.0.4/32 | 10.0.0.4 | 49.0001.0010.0000.0004.00 |

## 3. P2P link assignments

Convention: `10.1.<low_id><high_id>.0/31` per RFC 3021. The router with the lower router-ID gets `.0`; the router with the higher router-ID gets `.1`.

| Link | Subnet | A side | B side |
| --- | --- | --- | --- |
| Melbourne ↔ Sydney | 10.1.12.0/31 | mel = .0 | syd = .1 |
| Melbourne ↔ Brisbane | 10.1.13.0/31 | mel = .0 | bri = .1 |
| Melbourne ↔ Geelong | 10.1.14.0/31 | mel = .0 | gel = .1 |
| Sydney ↔ Brisbane | 10.1.23.0/31 | syd = .0 | bri = .1 |
| Sydney ↔ Geelong | 10.1.24.0/31 | syd = .0 | gel = .1 |
| Brisbane ↔ Geelong | 10.1.34.0/31 | bri = .0 | gel = .1 |

Total addresses consumed: 6 links × 2 = 12 IPs in 10.1.0.0/16.

## 4. Per-router interface IP map

### Melbourne (10.0.0.1)

| Interface | IP | Neighbour |
| --- | --- | --- |
| lo | 10.0.0.1/32 | — |
| eth1 | 10.1.12.0/31 | Sydney |
| eth2 | 10.1.14.0/31 | Geelong |
| eth3 | 10.1.13.0/31 | Brisbane |

### Sydney (10.0.0.2)

| Interface | IP | Neighbour |
| --- | --- | --- |
| lo | 10.0.0.2/32 | — |
| eth1 | 10.1.12.1/31 | Melbourne |
| eth2 | 10.1.23.0/31 | Brisbane |
| eth3 | 10.1.24.0/31 | Geelong |

### Brisbane (10.0.0.3)

| Interface | IP | Neighbour |
| --- | --- | --- |
| lo | 10.0.0.3/32 | — |
| eth1 | 10.1.23.1/31 | Sydney |
| eth2 | 10.1.34.0/31 | Geelong |
| eth3 | 10.1.13.1/31 | Melbourne |

### Geelong (10.0.0.4)

| Interface | IP | Neighbour |
| --- | --- | --- |
| lo | 10.0.0.4/32 | — |
| eth1 | 10.1.34.1/31 | Brisbane |
| eth2 | 10.1.14.1/31 | Melbourne |
| eth3 | 10.1.24.1/31 | Sydney |

## 5. BGP AS plan

| AS | Use |
| --- | --- |
| 65100 | Aurora Communications (private AS for the lab; production would use a public ASN) |
| 65200 | Reserved — first simulated upstream transit (W3+) |
| 65201 | Reserved — second simulated upstream transit (W3+) |
| 65300 | Reserved — IXP peer (W3+) |
| 65400+ | Customer ASes (W4+) |

## 6. IS-IS NET addressing scheme

Format: `49.<area>.<system-id>.<NSEL>`

- AFI `49` — private (RFC 1237).
- Area `0001` — Aurora's single Level-2 area for the W1 baseline.
- System ID `0010.0000.000<router_id>` — encodes router ID in the last byte.
- NSEL `00` — always 00 for routers.

This convention scales: when L1/L2 hierarchy is introduced (post-eight POPs), regional areas use `0010` … `0019`, while the L2 backbone retains `0001`.

## 7. IPv6 plan (W3 — future state)

| Block | Use |
| --- | --- |
| 2001:db8:aurora::/48 | Aurora address space |
| 2001:db8:aurora::1/128, ::2/128, ::3/128, ::4/128 | Loopbacks |
| 2001:db8:aurora:1212::/127 | Melbourne ↔ Sydney |
| (and so on per /127 per link) | |

P2P /127 per RFC 6164. Dual-stack on every interface.

## 8. Customer VPRN reservation (W4)

`10.2.0.0/16` reserved. Per-customer allocation:
- Maple Ridge: `10.2.1.0/24`
- Helix Health: `10.2.2.0/24` (DIA — direct, not VPRN)
- Northwind: `10.2.3.0/24`

Route Distinguisher format: `65100:<customer_id>`. Route Target format: `target:65100:<customer_id>`.
