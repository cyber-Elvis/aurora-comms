# Evidence — Region A: aurora-claude read account fleet-wide + AAA exec authorization

**Date:** 2026-06-25
**Scope:** Close two known gaps on all 4 Region A IOS-XRv 6.1.3 nodes.
**Method:** Read-only verification via the `aurora-claude` agent account (no `task
write`) using `ops/access/xr-ssh.py` over the GNS3 bastion (`gns3@100.118.0.46`),
driven by `ops/access/verify-claude-ro.sh`. Vault password fed over STDIN (never argv).

## Gaps closed

1. **`aurora-claude` read account rolled to gel-pe1 / mel-pe1 / mel-p1** — previously
   ADL-only (AUTH FAILED elsewhere). User applied the `AURORA-RO-TASKS` taskgroup +
   `AURORA-RO` usergroup + `username aurora-claude` (config in
   `node-snippets/aurora-claude-ro.cfg`) via the labadmin console on each node.
2. **`aaa authorization exec default local`** added on all 4 nodes — closes the
   NETCONF/gRPC task-RBAC-bypass (Cisco advisory cisco-sa-iosxr-info-GXp7nVcP). On
   IOS-XR <= 7.3 without it, model-driven sessions bypass task/data authorization.

## Result — all 4 nodes PASS (2026-06-24 14:27 UTC run)

| Node | IP | `aaa authorization exec default local` | aurora-claude login | WRITE tasks |
| --- | --- | --- | --- | --- |
| gel-pe1 | 10.255.191.15 | present | OK | none |
| mel-pe1 | 10.255.191.12 | present | OK | none |
| mel-p1  | 10.255.191.11 | present | OK | none |
| adl-pe1 | 10.255.191.17 | present | OK | none |

`show user tasks` on every node returned READ + DEBUG across the protocol/feature
tasks and `EXECUTE` on basic-services only — **no `WRITE` on any task**, confirming
the account is genuinely read-only (least privilege per ADR / industry practice).

## Reproduce

```
bash ops/access/verify-claude-ro.sh
```

Expect, per node: the `aaa authorization exec default local` line under
`show running-config aaa authorization`, and a `show user tasks` block with no WRITE.
