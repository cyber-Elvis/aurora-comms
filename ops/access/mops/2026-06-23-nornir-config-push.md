# MOP: Region A — Nornir config-push (Phase 2 write tier)

## Change record

| Field | Value |
| --- | --- |
| Change ID | `CHG-NORNIR-PHASE2` |
| Date | 2026-06-23 |
| Driver / operator | Elvis (runs the commands) |
| Coach / verifier | Claude (this MOP; verifies read-only via `aurora-claude`) |
| Account | `aurora-automation` (scoped RW; `task write interface`) |
| Tool | Nornir + Netmiko (`config_push.py`), IOS-XR candidate → commit |
| Worked example | a `description` on `Loopback0` (apply, then back out) |

## How it works (IOS-XR candidate model)

`config_push.py` enters config mode, loads the change, runs `show configuration`
(the candidate diff), then either **commits** (`--apply`/`--rollback`) or
**aborts** (default dry-run — discards, no change). Edit `APPLY_CFG` /
`ROLLBACK_CFG` in the script for real changes.

## Gated sequence (run from `ops/automation-iosxrv/nornir/`)

1. **Dry-run (no change)** — shows the candidate diff on every node, discards it:
   ```
   bash nr.sh config_push.py
   ```
   Proven non-mutating on adl-pe1. Review the diff = `description NORNIR-PHASE2-CANARY` under `Loopback0`, nothing else.

2. **Apply — canary first (ADL only)**:
   ```
   bash nr.sh config_push.py --apply adl-pe1
   ```
   Expect `APPLIED + committed (CHG-NORNIR-PHASE2)`. **Ping me — I verify** read-only via `aurora-claude` that `Loopback0` shows the description on ADL.

3. **Apply — all four** (after the canary verifies):
   ```
   bash nr.sh config_push.py --apply
   ```
   Ping me — I verify all four.

4. **Rollback** (push the reverse + commit, removes the description):
   ```
   bash nr.sh config_push.py --rollback            # all nodes
   bash nr.sh config_push.py --rollback adl-pe1     # one node
   ```
   Ping me — I verify the description is gone and `Loopback0`'s IP is untouched.

## Verification (coach, read-only)

Via `aurora-claude`: `show running-config interface Loopback0` on each node —
description present after apply, absent after rollback, `ipv4 address` unchanged
throughout. (Same independent-read check used for the Ansible Gate 3.)

## Evidence template

```text
Change ID: CHG-NORNIR-PHASE2
Node(s):
Operator: Elvis      Date/time:

DRY-RUN
- candidate diff (description on Loopback0, nothing else):

APPLY
- adl-pe1 canary: APPLIED + committed:
- coach read-back (description present):
- all four: APPLIED:

ROLLBACK
- result: ROLLED BACK + committed:
- coach read-back (description gone, IP intact):

RESULT: PASS / FAIL / ROLLED BACK
```

## Backout

The `--rollback` mode is the backout (deterministic reverse config). If a node
errors mid-apply, the uncommitted candidate is discarded when the SSH session
closes (IOS-XR candidate is per-session) — re-run the dry-run to confirm clean.
