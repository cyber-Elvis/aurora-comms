# MOP: Region A IOS-XR read/diagnostic account for Codex

## Change record

| Field | Value |
| --- | --- |
| Change ID | `CHG-AURORA-REG-A-CODEX-RBAC-001` |
| Date | 2026-06-22 |
| Operator / commit owner | Elvis |
| Account | `aurora-codex` |
| Scope | Four Region A IOS-XRv 6.1.3 routers |
| Authentication | Dedicated zone-scoped RSA-3072 key |
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
that the taskgroup parser rejects for both `read` and `debug`:

```text
cisco-support
disallowed
root-lr
root-system
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

## Key evidence

Private key, retained only on PC1:

```text
C:\Users\Elvis\.ssh\aurora-codex-local-iosxr-rsa
```

Public key:

```text
C:\Users\Elvis\.ssh\aurora-codex-local-iosxr-rsa.pub
```

Fingerprint:

```text
SHA256:hUJNjjl+Z/b2ZqASEWh/LCl1/nrvcT0Rl6yCjlF6xfM
```

Public key source:

```text
C:\Users\Elvis\.ssh\aurora-codex-local-iosxr-rsa.pub
OpenSSH fingerprint: SHA256:hUJNjjl+Z/b2ZqASEWh/LCl1/nrvcT0Rl6yCjlF6xfM
```

The final key-binding method remains under canary validation for this legacy
IOS-XRv 6.1.3 image.

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
show crypto key authentication rsa
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

Inspect the authentication commands supported beneath the local username on
the ADL canary:

```iosxr
configure
 username aurora-codex
  ?
```

Capture the contextual help before selecting the key-binding method. Review
any eventual candidate with `show configuration`, then commit as Elvis using
a short label.

## ADL attempts - incomplete

The 2026-06-22 ADL transcript established:

- `task read all` and `task debug all` are invalid on IOS-XRv 6.1.3;
- only `task execute basic-services` was committed;
- `commit check` is not accepted by this IOS-XRv 6.1.3 image;
- the crypto import command was pasted into the interactive `copy`
  destination prompt;
- the public key was not imported.

The second ADL transcript established:

- 77 operational task IDs accepted both `read` and `debug`;
- `cisco-support`, `disallowed`, `root-lr`, `root-system`, and `universal`
  were reported by `show aaa task supported` but rejected in the taskgroup;
- candidate configuration contained no `task write` grants;
- commit label `CHG-AURORA-REG-A-CODEX-RBAC-001-FIX` was rejected because it
  exceeded the 30-character label limit;
- the transcript ended after `end`, so no successful correction commit is
  evidenced.

The subsequent ADL key attempt established that this image rejects:

```iosxr
crypto key import authentication rsa username <USER> <FILE>
```

The caret was at `username`, proving the parser expects a different grammar
before it evaluates the file path.

Further controlled tests used the path-only grammar accepted by contextual
help. XR rejected all three transferred representations with `Invalid
argument`: the decoded SSH wire blob, one-line OpenSSH format, and RFC4716
SECSH format. File existence and byte counts were verified.

The subsequently tested `sshkey` command was also rejected in
`config-un` username submode. Neither the EXEC importer nor a username
`sshkey` command may be treated as validated for this image. Continue from
the username submode's complete contextual-help output.

The complete username submode help on ADL contains only `group`, `password`,
and `secret` as authentication-related commands. There is no `sshkey`
configuration command on this IOS-XRv 6.1.3 image.

## ADL crypto subsystem fault

Bounded console troubleshooting on 2026-06-22 established:

- the node is assigned 3072 MB RAM and one vCPU;
- `show memory summary` reports 3071 MB physical memory with 1448 MB
  available;
- the GNS3 VM has approximately 16 GiB memory available;
- `show crypto key authentication rsa` has no installed authentication key;
- both the read-only crypto show and each import attempt log:

```text
%PLATFORM-IOSXRV_LICENSE_UDI-7-ERR_INTERNAL :
Licensing directory not created: 'License Manager' detected the
'resource not available' condition 'Out of memory'
```

This is not ordinary host or guest memory exhaustion. The running XRv
instance's crypto/license subsystem is unhealthy, and additional key-format
experiments are suspended.

### Recovery gate

During an approved maintenance window:

1. capture the running configuration, commit list, IS-IS/LDP state, and memory
   summary;
2. stop only ADL-PE1;
3. increase ADL RAM from 3072 MB to 4096 MB as a diagnostic safety margin;
4. cold-start ADL and allow IOS-XR to settle fully;
5. verify management, interfaces, IS-IS, LDP, and route parity;
6. run `show crypto key authentication rsa`;
7. inspect recent logging and require the license-manager out-of-memory event
   to be absent before another import attempt.

Do not change all four routers until the ADL canary passes this recovery gate.

ADL must be re-entered idempotently using the corrected 77-task block and
committed with `AURORA_CODEX_RBAC`. The key copy/import must then be repeated
one command at a time before account validation.

## Per-node positive validation

Codex verifies from PC1:

```powershell
.\ops\access\aurora-ssh.ps1 mel-p1 -UseCodex
.\ops\access\aurora-ssh.ps1 mel-pe1 -UseCodex
.\ops\access\aurora-ssh.ps1 gel-pe1 -UseCodex
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
delete harddisk:/aurora-codex-local-iosxr-rsa.b64
```

Expected:

- each command is rejected by task authorization or unavailable in the current
  mode;
- no candidate configuration session is created;
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
- RSA key import:
- Key fingerprint:

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
- file delete rejected:

RESULT: PASS / FAIL / ROLLED BACK
Notes:
```

## Rollback

As `labadmin`, remove the authentication key first:

```iosxr
crypto key zeroize authentication rsa username aurora-codex
```

Then:

```iosxr
configure
 no username aurora-codex
 no usergroup AURORA-CODEX-RO-USERS
 no taskgroup AURORA-CODEX-RO
 commit label BACKOUT_CODEX_RBAC
 end
```

Retain the private key on PC1 until the change is closed. Delete the temporary
router-side test files and stop the GNS3 VM TFTP listener after all four nodes
pass.
