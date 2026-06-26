# MOP: Region A — transit-node patching (CSR1000v / IOL-XE, IOS-XE upgrade under failover)

## Change record

| Field | Value |
| --- | --- |
| Change ID | `CHG-AURORA-REG-A-TRANSIT-PATCH` |
| Date | 2026-06-24 |
| Driver / operator | Elvis (drives the console; types the change) |
| Coach / verifier | Claude (sets up/boots, gives the sequence + this MOP, verifies read-only) |
| Targets | `transit-a-csr` (CSR1000v 16.08.01) and `transit-b-iol` (IOL-XE 17.15) — both **IOS-XE** |
| Change type | Software patch/upgrade (the Telstra Day-1 IOS-XE drill) |
| Blast radius | Internet egress, IF failover is broken. **Hard prerequisite: §5.1a failover working.** |
| Reference | `docs/region-a-plan.md` §5.1a (failover), §5.4 (hardening), §8.8; `docs/telstra-ops-practice-plan.md` |

## Why

The two transits are the lab's IOS-XE patch targets. Patching a transit must never blackhole
the Internet default — so patch **one at a time** and prove the other transit carries egress
first. This exercises the real ops discipline: PSIRT check → drain → upgrade → validate → restore.

## Hard prerequisites (verify before starting)

| # | Item | Check |
| --- | --- | --- |
| P1 | **§5.1a failover works** — both transit defaults visible on both edge PEs via IPv4-unicast iBGP | on MEL-PE1 (XR) `show bgp ipv4 unicast 0.0.0.0/0` shows Transit-A (LP 200) **and** Transit-B (LP 100) |
| P2 | Both transits Established + ROV active + BFD up (per §5.4) | `show bgp ipv4 unicast summary`, `show rpki server`, `show bfd session` on the edge PEs |
| P3 | Target image staged + md5 verified; PSIRT/upgrade-path checked | image on the GNS3 VM / node flash |
| P4 | Operational-evidence template ready | `telstra-ops-practice-plan.md` |

## Procedure (repeat per transit; do Transit-B first so the primary stays up during the trial run)

### Pre-checks (Claude, read-only)
- Confirm the *other* transit is healthy and its default is present on both PEs.
- Snapshot: `show ip route 0.0.0.0`, `show ip bgp summary`, prefix counts on the transit being patched.

### Drain (operator types on the edge PE)
1. On the PE facing the target transit, **shut the eBGP session** (or set the neighbor holdtime low / `shutdown`).
2. Verify the default reconverges to the other transit:
   - MEL-PE1/ADL-PE1 (XR): `show route 0.0.0.0/0` → now via the surviving transit.
   - A CE / tenant: `ping <mock Internet /28 .1>` still succeeds.

### Upgrade (operator, on the transit node — IOS-XE)
3. `show version` (record current). Copy/verify the new image.
4. **Install mode** upgrade:
   ```
   install add file flash:<image> activate commit
   ```
   (or `request platform software package install` per platform); reload as prompted.
5. After reload: `show version` = target; `show install summary` = COMMITTED.

### Restore + validate (operator types; Claude verifies read-only)
6. Un-shut the eBGP session on the PE.
7. Verify on the PE (XR): session **Established**; `show bgp ipv4 unicast 0.0.0.0/0` shows this
   transit's default at the **correct LOCAL_PREF** (A=200 / B=100); **ROV active**
   (`show rpki server`); **BFD up** (`show bfd session`).
8. §7 smoke for the transit + the PE; failover test once more (shut the *other* transit → this
   one takes over) to prove symmetry.

### Closure
9. Capture pre/post evidence into `ops/access/evidence/2026-06-24-region-a-transit-patch.md`
   (Change ID, version before/after, drain time, reconverge time, ROV/BFD state, smoke result).
10. Repeat for the second transit only after the first is fully validated.

## Rollback

- If the upgrade fails or the session won't re-establish: `install rollback to committed` (or
  `install deactivate`/`activate` the prior package) and reload; keep the session shut until the
  node is back on the known-good image; the other transit carries egress throughout.
- No change is made to the edge PEs beyond the temporary eBGP shut, which step 6 reverses.

## Evidence template

```
[<UTC>] CHG-AURORA-REG-A-TRANSIT-PATCH  node=<transit-a-csr|transit-b-iol>
  before: <version>   after: <version>
  drain: default moved to <other transit> at <time>  reconverge: <ms/s>
  restore: eBGP Established <y/n>  default LP <200|100>  ROV <active>  BFD <up>
  smoke: PASS|FAIL — <note>
```
