# MOP: Region A — deploy the Internet-edge transits (Transit-A + Transit-B)

## Change record

| Field | Value |
| --- | --- |
| Change ID | `CHG-AURORA-REG-A-TRANSIT-DEPLOY` |
| Date | 2026-06-24 |
| Driver / operator | Elvis (drives device consoles; types config) |
| Coach / verifier | Claude (creates/wires/boots nodes via GNS3 API; gives the config sequence; verifies read-only) |
| Adds | `transit-a-csr` (CSR1000v 16.08.01, AS 64497, → MEL-PE1) and `transit-b-iol` (IOL-XE 17.15, AS 64498, → ADL-PE1) |
| Design refs | `docs/region-a-plan.md` §2.3, §4, §5.1, **§5.1a (failover)**, §5.2 (ROV C1), **§5.4 (hardening)**, §6 Wave 3.5, §7 |
| Blast radius | New eBGP edge + a backbone iBGP AF change (Stage 0). Backbone forwarding unaffected if staged. |

## ⚠ Prerequisites — deployment is GATED on these

> **State re-verified read-only 2026-06-25** (as `aurora-claude`; the 2026-06-21
> `aurora-deployment-status.md` snapshot was STALE). G1/G2 were already MET, and **G3 (iBGP
> mesh) is now built + verified — ALL Stage-0 gates met, Stage 1 unblocked.** Deployed loopbacks differ from the
> plan §4 targets — the migration assigned contiguous addresses; build iBGP on the **deployed**
> values, not the plan's: MEL-P `10.0.0.1`, MEL-PE1 `10.0.0.2`, GEL-PE1 `10.0.0.3`,
> ADL-PE1 `10.0.0.4`. (Plan §4 wanted GEL `.5` / ADL `.6` — doc reconcile pending, NOT a renumber.)

| # | Prerequisite | Current state (verified 2026-06-25) | Verdict |
| --- | --- | --- | --- |
| G1 | IS-IS L2 + LDP on **all four** PEs | Full chain Up: MEL-P↔MEL-PE1↔GEL-PE1↔ADL-PE1, LDP labels exchanged end-to-end | ✅ MET |
| G2 | **ADL-PE1 Loopback0** | `Lo0 = 10.0.0.4/32`, Up, in IS-IS + LDP router-id (≠ plan target `.6`) | ✅ MET |
| G3 | **iBGP full mesh with BOTH `vpnv4 unicast` + `ipv4 unicast` AFs + `next-hop-self`** (§5.1a) | 3-session mesh (10.0.0.2/.3/.4, `AURORA-IBGP` neighbor-group) Established in **both** AFs, `PfxRcd 0`, verified 2026-06-25 | ✅ MET |
| G4 | CSR1000v 16.08.01 + IOL-XE 17.15 **templates present** in the GNS3 controller | unverified (CSR image "Built" on PC1; template TBD) | check at Stage 1 |
| G5 | Free interfaces on MEL-PE1 (toward Transit-A) and ADL-PE1 (toward Transit-B) | MEL-PE1 `Gi0/0/0/2` free; ADL-PE1 `Gi0/0/0/1` free (both Shutdown/unassigned) | ✅ available |

**G3 met 2026-06-25 → Stage 1 unblocked.** (Rationale retained: deploying the transits onto a
backbone with no iBGP would bring up two isolated default routes that can't fail over — the
exact bug §5.1a fixes.)

### Stage 0 step 3 — iBGP full mesh (the only open gate) — operator drives

Per node, in the labadmin session: `configure` → paste that node's block (Win+V; identify by
its `bgp router-id`) → `show configuration` (confirm every line landed — re-paste if short) →
`commit` → `end`. Uses an `AURORA-IBGP` neighbor-group (both AFs + `next-hop-self`), peers on
the **deployed** loopbacks above. Purely additive (new BGP instance) — zero impact on IS-IS/LDP
forwarding. Sessions reach Established only once **both** ends are configured; `PfxRcd 0` is
expected (nothing originated yet). Verify (Claude, read-only): `show bgp ipv4 unicast summary`
+ `show bgp vpnv4 unicast summary` on all 3 → 2 neighbors Established in **each** AF.

## Stage 0 — backbone overlay readiness (operator drives; Claude verifies)
1. Unshut GEL/ADL cores; confirm IS-IS L2 adjacency + LDP Oper across ADL–GEL–MEL-PE1–MEL-P.
2. Assign ADL-PE1 `Loopback0` and announce into IS-IS.
3. Build the iBGP full mesh on MEL-PE1/GEL-PE1/ADL-PE1: `address-family vpnv4 unicast` **and**
   `address-family ipv4 unicast`, per-neighbor `next-hop-self` (§5.1a). Commit (two-stage).
4. Verify: `show bgp ipv4 unicast summary` + `show bgp vpnv4 unicast summary` → all iBGP Established (both AFs).

## Stage 1 — create / wire / boot the transit nodes (Claude, GNS3 API) — ✅ DONE (verified 2026-06-25)

> **Found already built + wired + started** (surveyed the controller before acting — no
> duplicates created). Controller = **Dell `192.168.137.1:3080`** (holds ops-lab + templates;
> the VM `100.118.0.46:80` is only the `vm` compute). ops-lab project_id
> `d8119db0-dd43-4d20-870d-9d62fd6345f1`. G4 templates all present.
> - `transit-a-csr` (CSR1000v-16.08.01, node a08c23d6) `a1`→ **MEL-PE1 Gi0/0/0/2**, `a0`→ MGMT-SW01.
>   On the CSR, **Gi2 = the MEL-PE1 link**, Gi1 = mgmt.
> - `transit-b-iol` (IOL-XE 17.15.1, node 9c51daa2) `e0/0`→ **ADL-PE1 Gi0/0/0/1**, `e0/1`→ MGMT-SW01.
> - **DEFECT FOUND + FIXED:** `transit-a-csr` had `adapter_type=e1000` → CSR1000v 16.08 logs
>   `%VXE_VNIC_IF-4-DRIVER_NOT_SUPPORTED` and **ignores all 4 NICs** (no usable data plane).
>   Switched to **`virtio-net-pci`** via the API (stop → PUT properties → start); clean reboot,
>   zero driver errors. Links survived (adapter/port-based).
> - **Baseline state:** `transit-a-csr` is BLANK (sitting at the initial-config dialog —
>   answer `no` to reach the CLI); `transit-b-iol` loaded a startup-config (check `show run`
>   before adding eBGP).

Original intent (for reference): create from templates, wire `transit-a-csr` ↔ MEL-PE1
(`10.255.2.0/30`) and `transit-b-iol` ↔ ADL-PE1 (`10.255.2.4/30`), boot **staggered** per
ADR-002 §3.9.4 Rule 2.

## Stage 2 — transit + PE-edge config (operator types; Claude verifies)
- **Transit side (IOS-XE):** link IP; originate `0.0.0.0/0` + `::/0` + 8 mock /28s from
  `192.0.2.0/24` + `2001:db8:a::/48`; eBGP to the PE (`conf t` … `end` → `write memory`).
- **PE side (IOS-XR):** transit interface; eBGP neighbor; inbound LOCAL_PREF on the default
  (**Transit-A 200 / Transit-B 100**); outbound prefix-list (mock-PI + customer aggregates only);
  no-leak filters (§5.1). Commit (two-stage).

## Stage 3 — transit-edge hardening (§5.4) (operator types; Claude verifies)
TCP-AO key-chain; single-hop BFD + `fall-over bfd`; GTSM `ttl-security hops 1`; graceful-restart;
`maximum-prefix` v4 1000 / v6 200; **RPKI ROV from C1** (drop invalid); `log neighbor-changes` +
syslog → PC1. Mirror policy for IPv6.

## Stage 4 — verify + failover (Claude read-only)
- Per §6 Wave 3.5 (XR): both transits Established; **`show bgp ipv4 unicast 0.0.0.0/0` on MEL-PE1
  shows BOTH defaults** (A LP 200 + B LP 100 via iBGP) — proves §5.1a.
- Failover: shut Transit-A on MEL-PE1 → `show route 0.0.0.0/0` reconverges to Transit-B via ADL-PE1;
  BFD makes it sub-second.
- ROV matrix (§5.2): Valid accepted, Invalid rejected on a transit session, NotFound accepted.
- Inter-region: the default reaches the Region B ASBR over the 64496↔65002 eBGP.
- Capture evidence → `ops/access/evidence/2026-06-24-region-a-transit-deploy.md`.

## Rollback
- Stage 1+: stop/delete the transit nodes via the GNS3 API; remove the PE eBGP neighbor +
  transit interface config (commit). Backbone unaffected.
- Stage 0 is a backbone build (iBGP), not a transit change — it stands on its own and is the
  prerequisite for the rest of Region A anyway; roll back only if it destabilises the core.
