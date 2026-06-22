# MOP — Extend IS-IS L2 + LDP west to GEL-PE1 and ADL-PE1

| Field | Value |
| --- | --- |
| Change ID | `CHG-AURORA-REG-A-ISIS-LDP-002` |
| Date | 2026-06-22 |
| Platform | Cisco IOS-XRv 6.1.3 (Region A, GNS3 `ops-lab` on Dell/PC2) |
| Scope | Bring up the two western core links and run IS-IS L2 + MPLS LDP on GEL-PE1 and ADL-PE1, joining them to the live MEL pair |
| Predecessor | `CHG-AURORA-REG-A-XRV-001` (IOL→IOS-XRv migration; MEL pair IS-IS/LDP already live) |
| Owner | Elvis Ifeanyi Nwosu |
| Driver | Claude drives the XR consoles via `iolcfg.py` over SSH to `gns3@100.118.0.46`; operator coaches/boots/API-verifies and stays off the same console (no two clients on one serial line) |

## 1. Objective

After this change the full Region A line **ADL ↔ GEL ↔ MEL-PE1 ↔ MEL-P** runs a single
IS-IS Level-2 domain (area `49.0001`, `metric-style wide`) with MPLS LDP on every core
link, and every node learns all four loopbacks `10.0.0.1–4` with an end-to-end LSP.

No VPNv4/VRF, no renumber (those remain separate future changes). This is IGP + LDP only.

## 2. Pre-migration state (deployed)

- **MEL-P** `10.0.0.1` / **MEL-PE1** `10.0.0.2` — IS-IS L2 + LDP **up** over `10.255.0.0/31`.
- **GEL-PE1** `10.0.0.3` — Loopback0 only; `Gi0/0/0/0` (→MEL-PE1) and `Gi0/0/0/1` (→ADL) **shut, unaddressed**; no IS-IS/LDP.
- **ADL-PE1** — **no Loopback0**; `Gi0/0/0/0` (→GEL) **shut**; no IS-IS/LDP.
- **MEL-PE1** `Gi0/0/0/1` (→GEL) — **shut, unaddressed**.

## 3. Addressing (extends deployed scheme; NOT the plan's .5/.6 renumber)

| Node | Loopback0 | IS-IS NET | Core interface(s) |
| --- | --- | --- | --- |
| ADL-PE1 | `10.0.0.4/32` *(new)* | `49.0001.0000.0000.0004.00` | `Gi0/0/0/0` → GEL: `10.255.0.5/31` |
| GEL-PE1 | `10.0.0.3/32` *(exists)* | `49.0001.0000.0000.0003.00` | `Gi0/0/0/0` → MEL-PE1: `10.255.0.3/31`; `Gi0/0/0/1` → ADL: `10.255.0.4/31` |
| MEL-PE1 | `10.0.0.2/32` *(exists)* | `49.0001.0000.0000.0002.00` *(exists)* | `Gi0/0/0/1` → GEL: `10.255.0.2/31` *(new end)* |

## 4. Prerequisites / pre-checks (BLOCKING — verify before any config)

1. **GNS3 links wired** between `MEL-PE1 Gi0/0/0/1 ↔ GEL Gi0/0/0/0` and `GEL Gi0/0/0/1 ↔ ADL Gi0/0/0/0`.
   Verify via controller API (`/v2/projects/<pid>/links`); if missing, create them (API or GUI) first.
2. **Nodes powered on**: MEL-PE1 (live), GEL-PE1, ADL-PE1. (MEL-P up too, to validate end-to-end.)
3. **RAM headroom** on the GNS3 VM for 4 running IOS-XRv nodes (check free mem; XRv is moderate, not a "solo" heavyweight, but confirm no OOM risk).
4. **Operator off the consoles** being driven (5008/ADL, GEL, MEL-PE1) — single client per serial line.
5. Capture **baseline** on MEL-PE1/MEL-P: `show isis adjacency`, `show mpls ldp neighbor` (prove the live pair is healthy before touching MEL-PE1).

## 5. Config blocks (apply at the XR console, config mode)

### 5a. ADL-PE1 (new Lo0 + IS-IS + LDP; link stays down until GEL up)
```
configure
 interface Loopback0
  ipv4 address 10.0.0.4 255.255.255.255
 !
 interface GigabitEthernet0/0/0/0
  description CORE-to-GEL-PE1
  ipv4 address 10.255.0.5 255.255.255.254
  no shutdown
 !
 router isis CORE
  net 49.0001.0000.0000.0004.00
  is-type level-2-only
  address-family ipv4 unicast
   metric-style wide
  !
  interface Loopback0
   passive
   address-family ipv4 unicast
   !
  !
  interface GigabitEthernet0/0/0/0
   point-to-point
   address-family ipv4 unicast
   !
  !
 !
 mpls ldp
  router-id 10.0.0.4
  interface GigabitEthernet0/0/0/0
  !
 !
 commit label CHG-AURORA-REG-A-ISIS-LDP-002
 end
```

### 5b. GEL-PE1 (both cores + IS-IS + LDP; Lo0 already present)
```
configure
 interface GigabitEthernet0/0/0/0
  description CORE-to-MEL-PE1
  ipv4 address 10.255.0.3 255.255.255.254
  no shutdown
 !
 interface GigabitEthernet0/0/0/1
  description CORE-to-ADL-PE1
  ipv4 address 10.255.0.4 255.255.255.254
  no shutdown
 !
 router isis CORE
  net 49.0001.0000.0000.0003.00
  is-type level-2-only
  address-family ipv4 unicast
   metric-style wide
  !
  interface Loopback0
   passive
   address-family ipv4 unicast
   !
  !
  interface GigabitEthernet0/0/0/0
   point-to-point
   address-family ipv4 unicast
   !
  !
  interface GigabitEthernet0/0/0/1
   point-to-point
   address-family ipv4 unicast
   !
  !
 !
 mpls ldp
  router-id 10.0.0.3
  interface GigabitEthernet0/0/0/0
  !
  interface GigabitEthernet0/0/0/1
  !
 !
 commit label CHG-AURORA-REG-A-ISIS-LDP-002
 end
```

### 5c. MEL-PE1 (delta — add the GEL link to the existing IS-IS/LDP; non-disruptive to the live MEL-P adjacency)
```
configure
 interface GigabitEthernet0/0/0/1
  description CORE-to-GEL-PE1
  ipv4 address 10.255.0.2 255.255.255.254
  no shutdown
 !
 router isis CORE
  interface GigabitEthernet0/0/0/1
   point-to-point
   address-family ipv4 unicast
   !
  !
 !
 mpls ldp
  interface GigabitEthernet0/0/0/1
  !
 !
 commit label CHG-AURORA-REG-A-ISIS-LDP-002
 end
```

## 6. Sequence

1. **ADL** (5a) — edge node, zero risk to the live pair. Commit; pre-check `show configuration failed`.
2. **GEL** (5b) — after commit, **GEL↔ADL** adjacency should come Up (both ends now addressed/no-shut).
3. **MEL-PE1** (5c) — after commit, **GEL↔MEL-PE1** adjacency comes Up, completing the 4-node L2 domain.

(MEL-PE1's existing `Gi0/0/0/0`↔MEL-P adjacency and LDP session must remain Up throughout — verify after 5c.)

## 7. Verification (evidence — capture per node)

- `show isis adjacency` — expect: MEL-P↔MEL-PE1, MEL-PE1↔GEL, GEL↔ADL all **Up** (L2).
- `show isis neighbors` / `show clns neighbors`.
- `show route isis` — every node has all four loopbacks `10.0.0.1`–`10.0.0.4`.
- `show mpls ldp neighbor` — sessions MEL-P–MEL-PE1, MEL-PE1–GEL, GEL–ADL all **Oper**.
- `show mpls forwarding` / `show mpls ldp bindings 10.0.0.x/32` — labels present for the loopbacks.
- **End-to-end LSP**: from ADL `ping 10.0.0.1 source 10.0.0.4` (ADL→MEL-P over the LSP) succeeds.

## 8. Rollback

Each node committed with label `CHG-AURORA-REG-A-ISIS-LDP-002`. To back out a node:
`show configuration commit list` → `rollback configuration to <prior-label-or-id>` (or
`rollback configuration last 1`). ADL also drops its new Loopback0 on rollback. MEL-PE1
rollback removes only the `Gi0/0/0/1` additions and leaves the live MEL-P adjacency intact.
Worst case: `interface Gi0/0/0/x / shutdown` to re-isolate, restoring the pre-change parity state.

## 9. Post-change

- Update `docs/aurora-deployment-status.md` (GEL/ADL now IS-IS/LDP; ADL Lo0 10.0.0.4), `docs/region-a-plan.md` addressing note, and the topology SVG/`ops/automation-iosxrv` host_vars.
- This realises the data-driven `ops/automation/playbooks/igp-isis.yml` intent on the live XR line — fold GEL/ADL into the `cisco.iosxr` verify playbooks.
- Evidence appended below on completion.
