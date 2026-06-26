# MOP: Region A — AURORA-SECURITY-RW crypto/transport role (carrier separation, tier 3)

## Change record

| Field | Value |
| --- | --- |
| Change ID | `CHG-AURORA-REG-A-SECURITY-RW-001` |
| Date | 2026-06-23 |
| Operator | Elvis — applies as **break-glass admin (labadmin / root-system)** |
| Verifier | Claude (read-only) |
| Why admin | creating roles/users is an `aaa` action → tier 4 gates the creation of tier 3 |
| New account | `aurora-security` (usergroup `AURORA-SECURITY-RW-USERS` → taskgroup `AURORA-SECURITY-RW`) |
| Scope | **write + execute `crypto` only**; read basic-services/system/config-services; execute filesystem. **NO aaa, NO li.** |
| Secret | random 32-char in `group_vars/region_a_iosxr_security/vault.yml` (vault-id `security`); `secret 5` hash in the snippet, cleartext never on console |
| Config | [`node-snippets/region-a-iosxr-security-rw.txt`](../node-snippets/region-a-iosxr-security-rw.txt) |

## Why

Carrier separation of duties. Crypto/transport changes (SSH server, host keys,
PKI, the netconf-yang / gNMI transports) run through a dedicated, audited role —
not `aurora-automation` (which deliberately has no crypto) and not break-glass for
routine work. Identity (`aaa`) and lawful intercept (`li`) stay tier-4
break-glass/human only.

## Apply (as labadmin/admin — ADL canary first)

1. Apply the **taskgroup** block, then `show running-config taskgroup AURORA-SECURITY-RW`
   and confirm **all 9 task lines** are present (console paste can drop lines).
2. Apply the **usergroup + username**, then `commit comment CHG-AURORA-REG-A-SECURITY-RW-001`.
3. **Ping me** — I verify the role and that `aurora-security` logs in.

## Verify (coach, read-only)

- `show running-config taskgroup AURORA-SECURITY-RW` — 9 lines, write only `crypto`.
- `aurora-security` logs in (vault secret) and can `show running-config crypto`.
- **Negative test:** as `aurora-security`, try a non-crypto config (e.g. an interface
  description) → expect `% This command is not authorized` (proves write = crypto-only).

## Then — use aurora-security to enable NETCONF (the point of the exercise)

The Phase 3 transport enable, now done by the *right* role (separated, audited):
- `aurora-security` applies `netconf-yang agent ssh` + `ssh server v2` +
  `ssh server netconf vrf default` on ADL (crypto write succeeds where
  aurora-automation was denied) → ping me → I verify TCP/830 + agent + an
  `ncclient` hello. Then the other three.

## Backout (as admin)

```
no username aurora-security
no usergroup AURORA-SECURITY-RW-USERS
no taskgroup AURORA-SECURITY-RW
```

## Evidence template

```text
Change ID: CHG-AURORA-REG-A-SECURITY-RW-001
Node(s):                         Operator: Elvis (labadmin)   Date/time:
taskgroup applied (9 lines):
aurora-security login OK / show crypto OK:
negative test (non-crypto denied):
netconf enabled by aurora-security / :830 up:
RESULT: PASS / FAIL / ROLLED BACK
```
