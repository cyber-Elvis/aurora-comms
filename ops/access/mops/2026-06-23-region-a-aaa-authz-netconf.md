# MOP: Region A — AAA exec authorization (NETCONF RBAC enforcement, Phase 3 hardening)

| Field | Value |
| --- | --- |
| Change ID | `CHG-AURORA-REGA-AAA-AUTHZ-001` |
| Date | 2026-06-23 |
| Account | **labadmin (root-system)** — aaa is tier-4 |
| Change | `aaa authorization exec default local` |
| Scope | ADL canary first (10.255.191.17) |

## Why

With NO `aaa authorization exec default`, NETCONF/gRPC sessions on IOS-XR ≤7.3
**bypass task-group authorization** (Cisco advisory cisco-sa-iosxr-info-GXp7nVcP) —
a NETCONF user can exceed its task groups. Configuring exec authorization via
`local` makes NETCONF honor the local task-group RBAC (the whole point of the tiering).

## Risk + why it's acceptable here

A bad `aaa authorization` can deny every exec session (lockout). Mitigated:
ALL users are **local with a group** (verified `show aaa userdb`: 5 root-system
admin accounts + the aurora-* service accounts), so the `local` method authorizes
them. No TACACS dependency. Still, follow the lifeline protocol — never trust it
until a NEW session is proven.

## Safety protocol (MANDATORY)

1. **Lifeline:** open a **labadmin** session to ADL and **KEEP IT OPEN** the whole
   time. An already-authorized session is not re-authorized on commit, so it stays
   usable even if the new rule is bad.
2. Apply the config in the lifeline + `commit`. **Do not close the lifeline.**
3. **Ping me.** I test a brand-new session read-only (a fresh login as
   `aurora-automation` must still run a show; a NETCONF session as a limited
   account must now honor its tasks).
4. If my test shows ANY new session is denied → in the lifeline, paste the
   ROLLBACK + commit. (You still have the open session, so you can.)
5. Only once new sessions verify → safe to close the lifeline.

## Apply (in the labadmin lifeline)

```
configure
 aaa authorization exec default local
commit
end
```

## Rollback (if a new session is denied)

```
configure
 no aaa authorization exec default local
commit
end
```

## Verify (coach, read-only)

- Fresh SSH as `aurora-automation` → `show clock` succeeds (exec still authorized).
- NETCONF (ncclient) as a read-only account → `get-config` works but `edit-config`
  of a non-permitted leaf is denied (proves NETCONF now enforces task RBAC).
- Then proceed to Phase 3 step A (edit-config) with a properly-authorized account.
