# MOP: Region A — enable NETCONF-YANG (Phase 3 prerequisite)

## Change record

| Field | Value |
| --- | --- |
| Change ID | `CHG-AURORA-REGA-NETCONF` |
| Date | 2026-06-23 |
| Driver / operator | Elvis (runs the playbook) |
| Coach / verifier | Claude (verifies read-only) |
| Account | **admin / labadmin via console** — `aurora-automation` deliberately lacks crypto (ssh-server) write, so it CANNOT enable the netconf transport (least-privilege as designed) |
| Tool | router console: `configure` → commit (one-time platform enablement) |
| Change | enable `netconf-yang agent ssh` + `ssh server netconf vrf default` (opens TCP/830) |

## Why

Phase 3 moves from CLI-scraping to model-driven config. NETCONF needs the
netconf-yang agent running and the SSH server's netconf subsystem listening on
:830. Confirmed present on 6.1.3 (`show netconf-yang clients` is a valid command).

## Config applied

```
netconf-yang agent ssh
ssh server v2
ssh server netconf vrf default
```

## Finding (2026-06-23): aurora-automation is NOT authorized — by design

Running the enable as `aurora-automation` returns `% This command is not authorized`
on `netconf-yang agent ssh`: AURORA-AUTOMATION-RW excludes `crypto` (ssh server)
and the netconf transport. Correct least-privilege — enabling a management
transport is a platform-admin action, kept OUT of the service account. The Ansible
playbook is reference-only (cannot run under aurora-automation). Going forward
aurora-automation *uses* NETCONF for ordinary config; it just doesn't enable it.

## Enable sequence (admin, typed on the ADL console — operator drives)

```
configure
 netconf-yang agent ssh
 ssh server v2
 ssh server netconf vrf default
commit
end
```

Then **ping me** — I verify `show netconf-yang clients` (agent up),
`show running-config netconf-yang`, TCP/830 reachable from the bastion, and an
`ncclient` NETCONF hello. Repeat on the other three once ADL is confirmed.

## Verification (coach, read-only)

- `show netconf-yang clients` — agent responds (no "% Invalid"/error).
- `show running-config netconf-yang agent` and `... ssh server netconf` — config present.
- TCP/830 reachable from the bastion (`nc -z <mgmt-ip> 830`) and an `ncclient` NETCONF hello succeeds (Phase 3 read step).

## Backout

```
no netconf-yang agent ssh
no ssh server netconf vrf default
```
(Re-run the playbook with these lines, or `iosxr_config` state absent.) Does not
affect existing SSH CLI access (separate from the netconf subsystem).

## Evidence template

```text
Change ID: CHG-AURORA-REGA-NETCONF
Node(s):                       Operator: Elvis   Date/time:
DRY-RUN diff (3 lines only):
APPLY adl-pe1:                 coach: netconf-yang clients OK / :830 listening:
ALL FOUR:                      coach:
RESULT: PASS / FAIL / ROLLED BACK
```
