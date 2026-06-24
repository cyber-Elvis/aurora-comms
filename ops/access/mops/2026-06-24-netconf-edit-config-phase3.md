# MOP: Region A — NETCONF edit-config (Phase 3 write tier)

| Field | Value |
| --- | --- |
| Change ID | `CHG-NETCONF-PHASE3-LOOPBACK111` |
| Date | 2026-06-24 |
| Driver / operator | Elvis (runs the commands) |
| Coach / verifier | Claude (verifies read-only via NETCONF get-config) |
| Account | `aurora-automation` (has `interface` write) |
| Tool | ncclient `edit-config` → candidate → commit (`netconf/nc_edit.py` via `nc.sh`) |
| Worked example | create `Loopback111` (10.111.111.111/32), then delete it |

## How it works

`nc_edit.py` opens a NETCONF session to ADL:830 (via the bastion forward that
`nc.sh` sets up), `edit-config`s into the **candidate** datastore, then either
**commits** (`--apply`/`--rollback`) or **discards** (default dry-run). A dedicated
canary interface — nothing existing is touched, fully revertible by deletion.

## Gated sequence (WSL, from `ops/automation-iosxrv/netconf/`)

1. **Dry-run (no change)** — `bash nc.sh nc_edit.py`. Stages `Loopback111` in the
   candidate, prints it, discards. Confirms the model-driven edit is well-formed.
2. **Apply** — `bash nc.sh nc_edit.py --apply` → `Loopback111 CREATED + committed`.
   **Ping me** — I verify via NETCONF `get-config` (and CLI) that `Loopback111` /
   `10.111.111.111` exists and nothing else changed.
3. **Rollback** — `bash nc.sh nc_edit.py --rollback` → `Loopback111 DELETED + committed`.
   **Ping me** — I verify it's gone.

## Notes

- **Rate-limit:** IOS-XRv has `ssh server rate-limit 60` — pace the runs (a few
  seconds apart). Rapid back-to-back NETCONF/SSH sessions get the banner throttled
  ("Error reading SSH protocol banner"); a single paced run is fine.
- ncclient needs **paramiko 4.0.0** (handled in `~/netconf-lab/venv`).
- This is the model-driven (YANG/XML) equivalent of the Nornir config-push — same
  dry-run → apply → verify → rollback gating, structured data instead of CLI lines.

## Verify (coach, read-only)

NETCONF `get-config` of the `Cisco-IOS-XR-ifmgr-cfg` `Loopback111` subtree:
present with `10.111.111.111/32` after apply, absent after rollback.

## Evidence template

```text
Change ID: CHG-NETCONF-PHASE3-LOOPBACK111
Node: adl-pe1     Operator: Elvis     Date/time:
DRY-RUN candidate (Loopback111 staged):
APPLY: Loopback111 CREATED + committed      coach get-config:
ROLLBACK: Loopback111 DELETED + committed   coach get-config (gone):
RESULT: PASS / FAIL / ROLLED BACK
```
