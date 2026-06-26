# MOP: Region A IOS-XR read/diagnostic account for Codex

## Change record

| Field | Value |
| --- | --- |
| Change ID | `CHG-AURORA-REG-A-CODEX-RBAC-001` |
| Date | 2026-06-22 |
| Operator / commit owner | Elvis |
| Account | `aurora-codex` |
| Scope | Four Region A IOS-XRv 6.1.3 routers |
| Authentication | Strong local secret retained in Ansible Vault |
| Configuration authority | None |

## Objective

Create a named IOS-XR account that allows Codex to:

- read all operational and running configuration state;
- execute only the IOS-XR `basic-services` task set, including ping and
  traceroute;
- run debug commands;
- test unavailable commands and receive authorization failures;
- never write configuration or commit.

This account is for read-only verification and bounded diagnostics. Elvis
remains the only operator who enters configuration and commits changes.

## Permission model

IOS-XRv 6.1.3 does not implement an `all` task ID. Full read/debug visibility
therefore requires one grant for every assignable operational task ID reported
by:

```iosxr
show aaa task supported
```

The command reports 82 names on this image. Five are metadata/reserved names
that the taskgroup parser rejects for both `read` and `debug`. The apparent
`ssh` task seen in some contextual output is also invalid and must be ignored:

```text
cisco-support
disallowed
root-lr
root-system
ssh
universal
```

The generator excludes those five and produces 77 assignable read grants and
77 assignable debug grants. The generated task group contains:

```text
task read <each-supported-task-id>
task execute basic-services
task debug <each-supported-task-id>
```

There is deliberately no `task write` permission and no inheritance from
`root-system`, `root-lr`, or another writable task group.

`debug all` is operationally powerful even though it is not configuration
write access. Debug sessions must be time-bounded, captured in evidence, and
ended with `undebug all`.

## Targets

| Alias | Hostname | Management IP |
| --- | --- | --- |
| `mel-p1` | `MEL-P-CISCO-IOSXR-RT01` | `10.255.191.11` |
| `mel-pe1` | `MEL-PE1-CISCO-IOSXR-RT01` | `10.255.191.12` |
| `gel-pe1` | `GEL-PE1-CISCO-IOSXR-RT01` | `10.255.191.15` |
| `adl-pe1` | `ADL-PE1-CISCO-IOSXR-RT01` | `10.255.191.17` |

## Credential handling

RSA user-key authentication is unavailable on this IOS-XRv 6.1.3 demo image:

- the global importer has no target-username argument;
- username configuration mode has no `sshkey` command;
- tested public-key formats were rejected;
- crypto access emits an internal license-manager resource error.

Do not restart or resize the routers for this issue. Use a strong random
alphanumeric local secret and allow XR to generate its native stored hash.

The cleartext secret:

- is generated separately for `aurora-codex`;
- is never committed to Git or written into evidence;
- is retained off-router in Ansible Vault;
- is passed to the diagnostic helper only through
  `AURORA_XR_PASSWORD`;
- is rotated after bootstrap if it appeared in console scrollback.

Codex uses a separate Ansible Vault identity:

```text
ops/automation-iosxrv/group_vars/region_a_iosxr_codex/vault.yml
Vault ID: codex
Variable: vault_aurora_codex_secret
Password file: ~/.aurora-codex-vault-pass
```

On the current Windows PC1 profile, the custody copy is
`C:\Users\Elvis\.aurora-codex-vault-pass`, restricted to
`FORTY3S-PC1\forty3`. Provision it separately into the approved Linux
automation user's home when that control environment is restored. Do not
store it on the GNS3 VM.

## Operator boundary

- Elvis opens each router as `labadmin`.
- Elvis enters and commits the RBAC configuration.
- Codex does not connect with `labadmin` and does not touch the console.
- After the account is installed, Codex may use only `aurora-codex`.
- Codex may run read commands, ping/traceroute, and bounded debug commands.
- Codex must not attempt to bypass an authorization failure.

## Pre-check on each router

Run as `labadmin`:

```iosxr
show clock
show users
show aaa task supported
show running-config taskgroup
show running-config usergroup
show running-config username aurora-codex
```

Expected:

- `basic-services` is listed as a supported task ID; there is no assignable
  `all` task ID on this image.
- `aurora-codex` does not already exist, or its existing definition is
  reviewed before replacement.
- no account currently grants Codex `root-system`.

Capture the complete supported-task output first:

```iosxr
terminal length 0
show aaa task supported
```

Save that output to a text file and generate the exact XR 6.1.3 task block:

```powershell
.\ops\access\New-IosXrReadDebugTaskBlock.ps1 `
  -InputPath .\show-aaa-task-supported.txt
```

Review the output and replace `<GENERATED_READ_AND_DEBUG_TASK_LINES>` in the
node snippet. Confirm that it contains 77 `task read` lines, 77 `task debug`
lines, one `task execute basic-services` line, and no `task write` lines.

## Implementation

Use the common block:

```text
ops/access/node-snippets/region-a-iosxr-codex-readonly.txt
```

In summary:

```iosxr
configure
 taskgroup AURORA-CODEX-RO
  description Full read plus basic-services and debug with no write
  <GENERATED_READ_AND_DEBUG_TASK_LINES>
 !
 usergroup AURORA-CODEX-RO-USERS
  taskgroup AURORA-CODEX-RO
 !
 username aurora-codex
  group AURORA-CODEX-RO-USERS
  secret <RANDOM_ALPHANUMERIC_SECRET>
 !
 root
 show configuration
 commit label AURORA_CODEX_RBAC
 end
```

IOS-XRv 6.1.3 rejects `commit check` in this lab image. Review the candidate
with `show configuration`, then commit with the short label shown above. XR
commit labels must start with a letter, contain only letters, digits, hyphens,
or underscores, and be no longer than 30 characters.

Enter the cleartext with `secret <value>` and let XR hash it. Do not paste a
precomputed `$1$` value: this image rejected externally generated MD5-crypt
hashes with incompatible salt handling.

## Canary findings

ADL parser testing established:

- `task read all` and `task debug all` are invalid;
- 77 operational task IDs accept `read` and `debug`;
- `cisco-support`, `disallowed`, `root-lr`, `root-system`, `ssh`, and
  `universal` must not be emitted by the generator;
- `commit check` is unavailable;
- commit labels are limited to 30 characters;
- username mode supports `group`, `password`, and `secret`, but no `sshkey`.

GEL then proved the supported access path end to end:

- a cleartext local `secret` is accepted and stored by XR as a native hash;
- password SSH succeeds with the read-only user;
- `show user tasks` displays read/debug grants and
  `execute basic-services`, with no write grant;
- OpenSSH requires `diffie-hellman-group14-sha1` and `ssh-rsa`;
- IOS-XR requires an interactive PTY for command output.

The proposed ADL RAM uplift and cold restart are cancelled. They do not address
the IOS-XRv 6.1.3 user-key limitation.

ADL running-state evidence captured on 2026-06-23 confirms the complete Codex
RBAC role, usergroup binding, username, and a native type-5 secret. ADL's RBAC
configuration passes; credential custody and interactive SSH authorization
tests remain pending.

## Per-node positive validation

IOS-XR swallows output from SSH exec channels, so validation must use an
interactive PTY. The bounded helper runs on the GNS3 VM:

```bash
printf 'show user tasks\nshow interfaces brief\nshow isis adjacency\n' |
  AURORA_XR_PASSWORD='<FROM_SECURE_STORE>' \
  python3 /home/gns3/xr-ssh.py 10.255.191.17 aurora-codex
```

The helper accepts only `show`, `ping`, `traceroute`, `debug`, and `undebug`.
It enables only the two legacy SSH algorithms required by XRv 6.1.3 and keeps
learned host keys in `~/.ssh/aurora_iosxr_known_hosts`.

For a human interactive session from PC1:

```powershell
.\ops\access\aurora-ssh.ps1 adl-pe1 -UseCodex
```

Allowed commands:

```iosxr
show running-config
show interfaces brief
show route ipv4
show isis adjacency
show mpls ldp neighbor
show logging last 50
ping 10.0.0.1
traceroute 10.0.0.1
show debugging
```

For a debug proof, use a low-volume debug agreed with Elvis, run it for no more
than 30 seconds, then:

```iosxr
undebug all
show debugging
```

Do not use broad packet or protocol debugging during convergence.

## Mandatory negative validation

As `aurora-codex`, attempt:

```iosxr
configure
commit
reload
clear isis adjacency *
process restart isis
```

Expected:

- verify the session identity before every negative test with `show users`;
- `configure` may open an empty candidate shell;
- an actual configuration command must be rejected as not authorized;
- `show configuration` must remain empty;
- an empty `commit` may report `No configuration changes to commit` before
  performing a separate commit-authorization check;
- no commit is accepted;
- no route, process, file, or node state changes.

If any write/destructive command succeeds, immediately stop testing and
rollback the role.

## Evidence template

```text
Change ID: CHG-AURORA-REG-A-CODEX-RBAC-001
Node:
Operator:
Date/time:

PRE-CHECK
- Existing aurora-codex account:
- Supported task IDs confirmed:
- Existing writable inheritance absent:

IMPLEMENTATION
- Commit ID:
- Commit label:
- Local secret configured:
- Cleartext retained only in Ansible Vault:
- Stored hash present without exposing it:

POSITIVE TEST
- SSH authentication:
- show running-config:
- show interfaces brief:
- ping:
- traceroute:
- debug proof:
- undebug all confirmed:

NEGATIVE TEST
- configure rejected:
- commit rejected:
- reload rejected:
- clear rejected:
- process restart rejected:

RESULT: PASS / FAIL / ROLLED BACK
Notes:
```

## Rollback

```iosxr
configure
 no username aurora-codex
 no usergroup AURORA-CODEX-RO-USERS
 no taskgroup AURORA-CODEX-RO
 commit label BACKOUT_CODEX_RBAC
 end
```

Remove the corresponding Codex vault variable after all four routers confirm
the username is absent. Delete the temporary router-side key-test files and
stop the obsolete GNS3 VM TFTP listener after the change closes.
