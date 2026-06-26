# ADL aurora-codex RBAC state

Date: 2026-06-23

Node: `ADL-PE1-CISCO-IOSXR-RT01`

## Running state

- `AURORA-CODEX-RO-USERS` exists and references `AURORA-CODEX-RO`.
- `AURORA-CODEX-RO` contains:
  - 77 read grants
  - 77 debug grants
  - one `task execute basic-services`
  - zero write grants
- `aurora-codex` belongs to `AURORA-CODEX-RO-USERS`.
- A native IOS-XR type-5 secret is present.

No cleartext secret or stored hash is retained in this evidence file.

## Result

RBAC configuration: PASS

## Authentication and positive authorization

- Interactive SSH authentication through the GNS3 VM: PASS
- Effective tasks: 77 READ, 77 DEBUG, EXECUTE on `basic-services`, no WRITE
- Secret rotation commit: `1000000012` (unlabelled because `end` confirmation
  committed before the labelled command was entered)
- Commit scope: only the `aurora-codex` secret
- Interfaces: management, Loopback0, and the GEL core link up/up
- IS-IS: GEL Level-2 adjacency up
- LDP: peer `10.0.0.3:0` operational
- Ping to MEL-P `10.0.0.1`: 100 percent, 5/5
- Traceroute to MEL-P: successful three-hop MPLS path

No cleartext secret or stored hash is retained in this evidence file.

## Remaining validation

- The attempted negative tests in Termius were later proven to be running as
  `labadmin`, not `aurora-codex`. Commit `1000000013` records `labadmin` as the
  user and therefore does not demonstrate Codex write access.
- Commit `1000000013` changed only the taskgroup description and requires a
  labelled corrective commit.

Pending:

- none for the ADL canary.

## Negative authorization

The interactive session identity was confirmed by `show users`:

- `vty1`: `aurora-codex`
- source: `10.255.191.1`

Results:

- entering `configure` is permitted;
- `taskgroup AURORA-CODEX-RO` is rejected with
  `% This command is not authorized`;
- the attempted description line is invalid because taskgroup submode was
  never entered;
- `show configuration` contains no candidate changes;
- `commit` reports `No configuration changes to commit`.

The empty-candidate response is not an independent commit-authorization test.
The actual write-command denial, empty candidate, effective task list with no
WRITE grants, and unchanged running configuration provide the required
no-write proof.

Authorization result: PASS

## Credential custody

- Encrypted secret:
  `ops/automation-iosxrv/group_vars/region_a_iosxr_codex/vault.yml`
- Vault format: Ansible Vault 1.2, AES-256, vault ID `codex`
- Vault variable: `vault_aurora_codex_secret`
- Dedicated vault password:
  `C:\Users\Elvis\.aurora-codex-vault-pass`
- Password-file ACL: `FORTY3S-PC1\forty3` full control only
- Claude's vault and credential were not read, modified, or reused
- Temporary DPAPI secret: removed after encrypted-vault round-trip and
  transfer-hash validation
- Temporary Windows and GNS3 VM encryption runtimes: removed

Credential custody result: PASS

## Final result

ADL `aurora-codex`: PASS
