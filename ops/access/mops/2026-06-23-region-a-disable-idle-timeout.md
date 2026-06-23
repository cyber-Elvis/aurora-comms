# MOP: Region A — disable idle (exec) timeout on all lines

## Change record

| Field | Value |
| --- | --- |
| Change ID | `CHG-AURORA-REGA-NOIDLE` |
| Date | 2026-06-23 |
| Driver / operator | Elvis (types/runs the commands) |
| Coach / verifier | Claude (provides this MOP, verifies read-only via `aurora-claude`) |
| Account used | `aurora-automation` (scoped RW; `task write tty-access`) |
| Scope | Four Region A IOS-XRv 6.1.3 nodes |
| Tool | Ansible `cisco.iosxr.iosxr_config` (idempotent, per-device commit) |

## Objective

Stop idle-session timeouts on every Region A node by setting `exec-timeout 0 0`
on the `line console` and `line default` (VTY/SSH) classes. Current state: no
explicit `exec-timeout` is configured, so nodes use IOS-XR defaults; this makes
"no idle timeout" explicit.

## Risk / deviation (Protect & Secure)

`exec-timeout 0 0` removes idle-session auto-logout — a hardening regression
(an idle privileged session stays open indefinitely). Accepted as a conscious
TechOps choice for this change. Safer alternatives if revisited: scope to the
console only, or use a finite value (e.g. `exec-timeout 30 0`).

## Backout

Per node, remove the override (reverts to IOS-XR default), or set a finite value:

```iosxr
configure
 line console
  no exec-timeout
 line default
  no exec-timeout
 commit label BACKOUT-NOIDLE
 end
```

(Or via Ansible: same playbook with `lines: ['no exec-timeout']`.)

## Pre-check (dry run — NO change)

```bash
cd /mnt/d/CyberLab/Repos/aurora-comms/ops/automation-iosxrv
export ANSIBLE_CONFIG=$PWD/ansible.cfg
ansible-playbook -i inventory.yml playbooks/region-a-disable-idle-timeout.yml --check --diff
```

Review the diff — it should show `exec-timeout 0 0` being added under
`line console` and `line default` on all four nodes, nothing else.

## Implementation (apply)

```bash
ansible-playbook -i inventory.yml playbooks/region-a-disable-idle-timeout.yml
```

Each node returns `CHANGED` and commits with comment `CHG-AURORA-REGA-NOIDLE`.
The playbook prints post-change evidence (line config + commit list).

## Post-check / verification

- The playbook's evidence task shows `exec-timeout 0 0` under both line classes.
- Coach (Claude) independently verifies read-only via `aurora-claude` on all four
  nodes: `show running-config line console` / `line default` show `exec-timeout 0 0`.

## Evidence template

```text
Change ID: CHG-AURORA-REGA-NOIDLE
Node:
Operator: Elvis
Date/time:

PRE-CHECK
- Dry-run diff (exec-timeout 0 0 added, nothing else):

IMPLEMENTATION
- Playbook result (CHANGED):
- Commit id / comment:

POST-CHECK
- line console exec-timeout:
- line default exec-timeout:
- Coach aurora-claude read confirms 0 0:

RESULT: PASS / FAIL / ROLLED BACK
Notes:
```
