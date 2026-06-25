# Region B — Proposed Addressing, AS, and RD/RT Plan

> **STATUS: PROPOSED — ratify before deploy.** Region B addressing is left TBD by
> `docs/ip-plan.md` ("Region B — Planned POP Placeholders"); this file is the build's
> proposal. Once ratified and instantiated, mirror the final values back into
> `docs/ip-plan.md`. Reservation-assigned management addressing is recorded per
> reservation in `ansible/inventory/devnet-current.yml` (gitignored), never here.

Region B is the Cisco-dominant (+ Juniper) region per `docs/adr-002-two-region.md` §3.2
and `docs/adr-003-revendor-cisco-region-a.md` §2.3. It is **ephemeral** — hosted in a
Cisco DevNet CML reservation, rebuilt from `topology/aurora-region-b.yaml` each time.

## 0. The hosting principle (why so little BYOI)

CML is Cisco-native. The design **deliberately minimises per-reservation BYOI** (ADR-002
§3.2.4: the off-CML PA-VM paths "avoid CML BYOI upload effort and keep PA-VM available
across DevNet reservations"; §3.1 hosts Aruba CX locally because per-reservation BYOI is
"operationally painful"). So:

- **In CML (native Cisco):** the P core + PE pairs + the Maple Ridge Cisco CE.
- **CML BYOI — one node only:** `JNX-P` vJunos-router (cannot run on the triple-nested
  Dell, ADR-003 §2.3 — this is the *only* unavoidable BYOI).
- **Local + bridged into Region B** (over openconnect-in-WSL2 + Docker MASQUERADE on PC1):
  PA-VM Helix CE (PC1 vrnetlab 9.0.4), vSRX (Dell standalone), Aruba CX Helix LAN (local).
  Their PE-CE eBGP sessions ride the bridge to the CML HH-PE pair.
- **Region A / PC1 (NOT Region B):** both Internet transits, the IXP FRR peers, and the
  RPKI validator — see §8.

All addressing is disjoint from Region A so a Region B node can never be confused with a
Region A node:

| Space | Region A (in use) | Region B (this proposal) |
| --- | --- | --- |
| Carrier loopbacks | `10.0.0.0/24` | `10.0.20.0/24` |
| CE loopbacks | `10.0.1.0/24` | `10.0.21.0/24` |
| Backbone /31s | `10.255.0.0/24` | `10.255.20.0/24` |
| PE-CE /30s | `10.255.1.0/24` | `10.255.21.0/24` |

## 1. Node inventory

### 1a. In CML (native Cisco + the one BYOI)

| Node | CML node_definition | Role | Loopback0 | AS |
| --- | --- | --- | --- | --- |
| `DC-P-R1` | `iosxrv9000` | Aurora-DC P core (RR + ASBR to Region A, peers `MEL-PE1`) | `10.0.20.1/32` | 65002 |
| `DC-P-R2` | `iosxrv9000` | Aurora-DC P core (RR) | `10.0.20.2/32` | 65002 |
| `MR-PE-R1` | `iosxrv9000` | Maple Ridge PE (XR) | `10.0.20.11/32` | 65002 |
| `MR-PE-R2` | `cat8000v` | Maple Ridge PE (IOS XE 17.x) | `10.0.20.12/32` | 65002 |
| `HH-PE-R1` | `iosxrv9000` | Helix Health PE (XR) | `10.0.20.21/32` | 65002 |
| `HH-PE-R2` | `iosxrv9000` | Helix Health PE (XR) | `10.0.20.22/32` | 65002 |
| `MR-CE` | `cat8000v` | Maple Ridge CE + IOS XE ZBFW | `10.0.21.1/32` | 64520 |
| `JNX-P` | **BYOI** `vjunos-router` | Multivendor core peer (Junos↔XR IS-IS/BGP) | `10.0.20.31/32` | 65002 |

### 1b. Local, bridged into Region B (NOT in CML)

| Node | Where it runs | Reaches Region B via | Loopback0 | AS |
| --- | --- | --- | --- | --- |
| `HH-CE` (PA-VM 9.0.4) | **PC1 vrnetlab** (`vrnetlab/paloalto_pa-vm:9.0.4`) | openconnect+MASQUERADE bridge → PE-CE eBGP to HH-PE pair | `10.0.21.2/32` | 64521 |
| `helix-lan-sw` (Aruba CX 10.16.1040) | **PC1 / local** | local L2 link behind `HH-CE` (co-located → the old GRE-over-VPN collapses to a local link) | n/a (L2) | — |
| `JNX-FW` (vSRX) | **Dell standalone** (ADR-003 §2.3) | bridge → optional security CE eBGP to `HH-PE-R2` | `10.0.21.3/32` | 64522 |

> **Why no GRE for Aruba any more:** the original GRE-over-IPSec pattern existed because the
> Helix CE used to live *in CML* (Cat8000v) and had to reach the Aruba in Region A. With the
> CE now PA-VM **local**, CE and LAN are co-located, so CE↔LAN is a plain local link. Only the
> PA-VM↔HH-PE eBGP crosses the bridge.

National-POP overlay: Aurora-DC site ≈ **Sydney** (`SYD-PE1`, Region B/C handoff, first ROV
enforcer); Maple Ridge / Helix PE sites carry the **Brisbane** (`BNE-PE1`) role.

## 2. Backbone /31s (IS-IS L2 + LDP, `10.255.20.0/24`)

| Link | Subnet | A-end | B-end |
| --- | --- | --- | --- |
| `DC-P-R1` ↔ `DC-P-R2` | `10.255.20.0/31` | `.0` | `.1` |
| `DC-P-R1` ↔ `MR-PE-R1` | `10.255.20.2/31` | `.2` | `.3` |
| `DC-P-R2` ↔ `MR-PE-R2` | `10.255.20.4/31` | `.4` | `.5` |
| `DC-P-R1` ↔ `HH-PE-R1` | `10.255.20.6/31` | `.6` | `.7` |
| `DC-P-R2` ↔ `HH-PE-R2` | `10.255.20.8/31` | `.8` | `.9` |
| `MR-PE-R1` ↔ `MR-PE-R2` | `10.255.20.10/31` | `.10` | `.11` |
| `HH-PE-R1` ↔ `HH-PE-R2` | `10.255.20.12/31` | `.12` | `.13` |
| `DC-P-R1` ↔ `JNX-P` | `10.255.20.14/31` | `.14` | `.15` |
| `DC-P-R2` ↔ `JNX-P` | `10.255.20.16/31` | `.16` | `.17` |

IS-IS: Level-2-only, area `49.0002` (Region A uses `49.0001`), `metric-style wide`. LDP on
all backbone /31s; transport = loopback0.

## 3. PE-CE /30s (`10.255.21.0/24`) — local CEs reached over the bridge

| Link | Subnet | PE-end (CML) | CE-end (local) |
| --- | --- | --- | --- |
| `HH-CE` (PA-VM) ↔ `HH-PE-R1` | `10.255.21.8/30` | `.9` | `.10` |
| `HH-CE` (PA-VM) ↔ `HH-PE-R2` | `10.255.21.12/30` | `.13` | `.14` |
| `JNX-FW` (vSRX) ↔ `HH-PE-R2` | `10.255.21.16/30` | `.17` | `.18` |
| `MR-CE` (Cat8000v, in CML) ↔ `MR-PE-R1` | `10.255.21.0/30` | `.1` | `.2` |
| `MR-CE` (Cat8000v, in CML) ↔ `MR-PE-R2` | `10.255.21.4/30` | `.5` | `.6` |

## 4. AS / BGP model

Region B is the **same Aurora carrier** as Region A (confederation ID `64496`), modelled as
confederation **member-AS `65002`** (Region A target member-AS = `65001`).

- **Intra-Region-B:** iBGP within `65002`. `DC-P-R1` + `DC-P-R2` = route-reflector cluster
  (`cluster-id 0.0.20.1`); all PEs are RR clients. AFs: `vpnv4 unicast` + `ipv4 unicast`.
- **Multivendor:** `JNX-P` (Junos) runs IS-IS L2 + iBGP with the XR core.
- **Inter-region (A↔B):** plain eBGP `64496 ↔ 65002` across the boundary (§7). Migrating
  Region A into member-AS `65001` is a **separate future Region-A change** — not part of
  standing up Region B; until then plain eBGP, forward-compatible to confederation.

| ASN | Owner |
| --- | --- |
| `64496` | Aurora carrier (confederation ID, both regions) |
| `65001` | Region A member-AS (**target only**, not yet applied) |
| `65002` | Region B member-AS |
| `64520` | Maple Ridge CE |
| `64521` | Helix Health CE (PA-VM) |
| `64522` | `JNX-FW` vSRX Junos edge |

## 5. VRF / L3VPN (RD/RT — shared carrier space with Region A)

| Customer | VRF id | RD | RT (import/export) |
| --- | --- | --- | --- |
| Maple Ridge | `1` | `64496:1` | `64496:1` |
| Helix Health | `2` | `64496:2` | `64496:2` |
| L3VPN validation `CUST-A` | `100` | `64496:100` | `64496:100` |

## 6. The bridge (how local CEs reach the CML PEs)

Per ADR-002 §3.3: PC1 WSL runs `openconnect` (tun0, ~`192.168.254.x`) into the DevNet
sandbox `10.10.20.0/24`; Docker MASQUERADE NATs local source addresses onto tun0.

- **PA-VM Helix CE (PC1 vrnetlab)** and **vSRX (Dell)** source their PE-CE eBGP toward the
  CML HH-PE pair through this bridge. From Dell, the path is Dell GNS3 → PC1 WSL (ethernet
  `192.168.200.x`) → openconnect → CML.
- PE-CE neighbor addresses (the `.10/.14/.18` CE ends) are the **bridge-side reachable
  addresses**, recorded per reservation in `devnet-current.yml`.

## 7. Inter-region boundary (A↔B)

- **Region A end:** `MEL-PE1` — Aurora's Region B border router / Region A-side **PE ASBR**
  (already does VPNv4 + Transit-A). **Not `MEL-P`** — it is a pure P router (IS-IS/LDP, no BGP);
  `MEL-P` is only the right-side *transport* handoff toward PC1/Region B. **Not `SYD-PE1`**
  either — `SYD-PE1` is a **Region B** node (ROV enforcer / Region B-C edge), not the Region A
  border.
- **Region B end:** `DC-P-R1` — the Region-B-side ASBR that peers `MEL-PE1`.
- **Protocol:** plain eBGP `64496 ↔ 65002`, global IPv4 unicast, exchanging loopbacks +
  documentation/public-test prefixes. Per-VRF inter-AS Option-A is the L3VPN-extension
  follow-on; MPLS label transfer (Option B/C) is **not viable across the MASQUERADE NAT**.
- **Default route into Region B:** this eBGP MUST carry the **`0.0.0.0/0` default** originated
  by Region A's transits (Transit-A/Transit-B) so Region B has Internet egress. That in turn
  requires Region A's iBGP mesh to carry **IPv4-unicast** (not VPNv4-only) so the default
  actually reaches the Region A ASBR — see `docs/region-a-plan.md` §5.1a. Region B has **no
  transit of its own**; all upstream/Internet reachability is borrowed from Region A.

## 8. Transit, IXP, RPKI — these live in Region A / PC1 (not Region B)

The full picture, so Region B is not mis-scoped (region-a-plan §2.3/§2.6/§3.2, ip-plan):

| Function | Where it runs | Detail |
| --- | --- | --- |
| **Transit-A** (primary) | **Region A local** (Dell GNS3) | `transit-a-csr` CSR1000v, **AS 64497**, on `MEL-PE1` |
| **Transit-B** (backup) | **Region A local** (Dell GNS3) | `transit-b-iol` IOL-XE, **AS 64498**, on `ADL-PE1` |
| **IXP fabric + PE attach** | **Region A logical** | L2 `ixp-fabric`, LAN `10.255.3.0/24` (MEL-PE1 `.1`, future `SYD-PE1 .3`) |
| **IXP route-server / content / eyeball** | **PC1 Docker** | FRR `ixp-rs1`/`ixp-content1`/`ixp-eyeball1`, AS `64499/64500/64501`, bridged in |
| **RPKI validator** | **PC1 Docker** | Routinator + SLURM, RTR `192.168.137.1:3323` |

**Region B's role in this story** = `SYD-PE1` (the Aurora-DC interconnect node, i.e. `DC-P-R1`
in this build) is the **first IOS-XR ROV enforcer** — it consumes the PC1 Routinator RTR feed
over the management ring and applies origin-validation at its eBGP ingress — and it takes the
future IXP `.3` attachment over the bridge. Transit failover and IXP route-server proofs are
**Region A / PC1 exercises**, not Region B nodes.
