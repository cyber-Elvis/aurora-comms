# MOP: Region A IOS-XR config-as-code account for Ansible (aurora-automation)

## Change record

| Field | Value |
| --- | --- |
| Change ID | `CHG-AURORA-REG-A-AUTOMATION-RW-001` |
| Date | 2026-06-23 |
| Operator / commit owner | Elvis |
| Account | `aurora-automation` (new, non-human service account) |
| Scope | Four Region A IOS-XRv 6.1.3 routers |
| Authentication | Strong local secret retained in Ansible Vault |
| Configuration authority | Write on network tasks; no `aaa`/`li`/`crypto` write |

## Objective

Create a dedicated **non-human automation service account**, `aurora-automation`,
for Ansible config-as-code (`iosxr_config`, `commit`) over `network_cli`, and
repoint the Region A Ansible `group_vars` from `aurora-claude` to it.

Separation of duties — this change keeps three distinct identity classes:

| Identity | Who/what | Access | Touched here? |
| --- | --- | --- | --- |
| `admin` / `labadmin` | Break-glass, human (Elvis) | `root-system` | no |
| `aurora-codex` | Codex agent | read + debug, no write | no |
| `aurora-claude` | Claude agent | read-only/limited | **no — left as-is** |
| `aurora-automation` | Ansible automation (this MOP) | read + scoped write + execute | **created** |

The agent accounts stay limited; only the dedicated service account holds write.
This is the "dedicated keys, not personal" principle: automation authenticates
as itself, never as an agent or a human.

## Why this is not "full permissions"

`aurora-automation` is deliberately scoped below `root-system` / `root-lr` /
`cisco-support`:

| Capability | Granted? | Reason |
| --- | --- | --- |
| read (all assignable tasks) | yes | diff / gather |
| write (network tasks) | yes | config-as-code is the job |
| write `aaa` | **no** | automation must not alter RBAC / create users (no self-escalation) |
| write `li` | **no** | lawful intercept is never automated |
| write `crypto` | **no** | key/certificate material stays with break-glass |
| execute basic-services / filesystem / system | yes | commit, file ops, the `\| utility` probe |
| debug | **no** | not needed for config-as-code |
| host shell / `run` / disk format / reload | **no** | excluded with root-system / cisco-support |

A strict read-only account is structurally incompatible with `cisco.iosxr`: the
cliconf `get_device_info()` runs `show version | utility head -n 20` on every
connect, and that host-utility pipe cannot be authorized inside a hardened
read-only task group (`aurora-codex` proves `task execute basic-services` alone
is insufficient). The service account carries `task execute filesystem` to clear
that probe.

## Permission model

IOS-XRv 6.1.3 has no `all` task ID, so each assignable operational task ID
reported by `show aaa task supported` needs an explicit grant. On this image:
82 supported, 5 non-assignable (`cisco-support`, `disallowed`, `root-lr`,
`root-system`, `universal`) -> 77 assignable. Generate the exact block:

```powershell
.\ops\access\New-IosXrConfigRwTaskBlock.ps1 `
  -InputPath .\show-aaa-task-supported.txt
```

The generator emits 77 `task read`, 74 `task write` (all except `aaa`/`li`/
`crypto`; override with `-WriteExclude`), and `task execute basic-services`,
`filesystem`, `system`. No `task debug`. Replace `<GENERATED_RW_TASK_LINES>` in
`ops/access/node-snippets/region-a-iosxr-ansible-rw.txt`.

## Targets

| Alias | Hostname | Management IP |
| --- | --- | --- |
| `mel-p` | `MEL-P-CISCO-IOSXR-RT01` | `10.255.191.11` |
| `mel-pe1` | `MEL-PE1-CISCO-IOSXR-RT01` | `10.255.191.12` |
| `gel-pe1` | `GEL-PE1-CISCO-IOSXR-RT01` | `10.255.191.15` |
| `adl-pe1` | `ADL-PE1-CISCO-IOSXR-RT01` | `10.255.191.17` |

## Credential handling

Password auth is the supported path on IOS-XRv 6.1.3 (RSA user-key binding is
unavailable — see the aurora-codex MOP). Generate a strong random alphanumeric
secret distinct from every other account, set it on-box (`secret <value>`, let
XR hash it), and retain the cleartext only in Ansible Vault:

```text
ops/automation-iosxrv/group_vars/region_a_iosxr/vault.yml
Variable: vault_aurora_automation_secret
```

The secret is never committed to Git or written into evidence and is managed
with `ops/access/write-ansible-vault.py`; Claude does not read or reuse the
operator's vault password. Rotate the secret if it appears in console
scrollback.

## Operator boundary

- Elvis opens each router as `labadmin` and enters/commits this RBAC.
- Ansible connects only as `aurora-automation` after the account is installed.
- `aurora-automation` may read, configure network features, and commit.
- `aurora-automation` must not change AAA, touch lawful intercept, hold crypto
  material, reach a host shell, or reload/format — verify in the negative tests.

## Pre-check on each router (as labadmin)

```iosxr
show clock
show users
terminal length 0
show aaa task supported
show running-config taskgroup
show running-config username aurora-automation
```

Expected: `basic-services`, `filesystem`, `system` listed as supported task IDs;
no assignable `all`; `aurora-automation` does not yet exist; no group grants it
`root-system`. Save the supported-task output and generate the block.

## Implementation

1. Apply the role + account (no secret yet) from
   `ops/access/node-snippets/region-a-iosxr-ansible-rw.txt` in chunks of 12-15
   lines, review with `show configuration`, then
   `commit label AURORA_AUTOMATION_RBAC`.
2. Set the secret and commit separately (keeps the cleartext out of the bulk
   paste):

   ```iosxr
   configure
    username aurora-automation secret <RANDOM_ALPHANUMERIC_SECRET>
    commit label AURORA_AUTO_SECRET
    end
   ```

3. Store the same cleartext in `vault_aurora_automation_secret`
   (`ops/access/write-ansible-vault.py`). The repo `group_vars` already point
   `ansible_user: aurora-automation` at this variable.

`commit check` is unavailable; commit labels start with a letter, use only
letters/digits/hyphens/underscores, <= 30 chars. Do not paste a precomputed
`$1$` hash.

## Positive validation

### Gate 1 — the cliconf probe (run AS aurora-automation, interactive PTY)

```iosxr
show version | utility head -n 20
```

The exact command `cisco.iosxr` runs on connect. It must succeed.

- Succeeds: proceed to Gate 2.
- Authorization error: `| utility` needs more than `filesystem` execute on this
  image. Escalate the execute set one task at a time (`ext-access`, then
  `host-services`), re-test, record what unblocked it. Do not jump to
  `cisco-support`/root — if nothing below shell-class works, reconsider NETCONF
  for config push (YANG RBAC, no `| utility`).

### Gate 2 — Ansible reach and facts (also exercises Gate 1)

```bash
cd ops/automation-iosxrv
ansible -i inventory.yml region_a_iosxr -m cisco.iosxr.iosxr_facts \
  -a 'gather_subset=min'
```

### Gate 3 — a real, reversible commit through Ansible

```bash
ansible -i inventory.yml region_a_iosxr -m cisco.iosxr.iosxr_config \
  -a "lines='description AURORA-AUTOMATION-CANARY' parents='interface Loopback0' \
      commit_label=CHG-AURORA-AUTO-CANARY"
# confirm commit id on box, then back out:
ansible -i inventory.yml region_a_iosxr -m cisco.iosxr.iosxr_config \
  -a "lines='no description' parents='interface Loopback0' \
      commit_label=CHG-AURORA-AUTO-CANARY-BACKOUT"
```

## Mandatory negative validation (as aurora-automation)

Confirm session identity with `show users`, then attempt:

```iosxr
configure
 username attacker group root-system
 commit
```
```iosxr
configure
 lawful-intercept ...
 commit
```
```iosxr
run
reload
```

Expected: any `aaa`/`taskgroup`/`usergroup`/`username` write, `li`, and `crypto`
write are rejected (`% This command is not authorized`); `run` (host shell)
rejected; `reload` rejected; `show user tasks` shows write on network tasks but
**no** `aaa`/`li`/`crypto` write, no debug, no root inheritance. If any of those
succeed, stop and roll back.

## Evidence template

```text
Change ID: CHG-AURORA-REG-A-AUTOMATION-RW-001
Node:
Operator:
Date/time:

PRE-CHECK
- aurora-automation absent before change:
- Supported task IDs (basic-services/filesystem/system present):
- No writable root inheritance:

IMPLEMENTATION
- Role commit id / label:
- Secret commit id / label:
- Read / write / write-excluded counts:
- Cleartext only in Vault:

POSITIVE TEST
- Gate 1 `show version | utility head -n 20`:  (grant that unblocked it: )
- Gate 2 iosxr_facts:
- Gate 3 canary commit id / backout commit id:

NEGATIVE TEST
- username->root-system / aaa write rejected:
- li / crypto write rejected:
- run (shell) rejected:
- reload rejected:
- show user tasks: no aaa/li/crypto write, no debug, no root:

RESULT: PASS / FAIL / ROLLED BACK
Notes:
```

## Rollback

```iosxr
configure
 no username aurora-automation
 no usergroup AURORA-AUTOMATION-RW-USERS
 no taskgroup AURORA-AUTOMATION-RW
 commit label BACKOUT_AUTO_RBAC
 end
```

Revert `group_vars/region_a_iosxr/main.yml` to the prior `ansible_user`, and
remove `vault_aurora_automation_secret`, only after all four routers confirm the
username is absent.
