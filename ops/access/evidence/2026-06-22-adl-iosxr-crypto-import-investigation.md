# ADL IOS-XRv crypto import investigation

Date: 2026-06-22

Node: `ADL-PE1-CISCO-IOSXR-RT01`

Scope: EXEC-only console discovery and public-key import tests. No
configuration, commit, reload, or service-impacting command was performed.

## Confirmed behavior

- GNS3 node RAM: 3072 MB
- GNS3 node vCPU: 1
- XR physical memory: 3071 MB total, 1448 MB available
- GNS3 VM memory: approximately 16 GiB available
- `show crypto key authentication rsa`: no installed key
- `crypto key import authentication rsa ?`: accepts only a public-key file
  path
- Username submode offers `group`, `password`, and `secret`; no `sshkey`

## Formats rejected

- decoded SSH wire blob
- OpenSSH one-line public key
- RFC4716/SECSH public key
- RFC4716 with `Comment: "aurora-codex"`

Files existed on `harddisk:` with their expected byte counts before the
applicable tests.

## Root-cause evidence

The following event occurs on the crypto show command and on import attempts:

```text
%PLATFORM-IOSXRV_LICENSE_UDI-7-ERR_INTERNAL :
Licensing directory not created: 'License Manager' detected the
'resource not available' condition 'Out of memory'
```

Because both XR and its host have substantial available memory, treat this as
an unhealthy IOS-XRv crypto/license subsystem rather than a key-format result.

## Final decision

RSA user-key authentication is retired for IOS-XRv 6.1.3. A GEL canary proved
that a local `secret` on an explicitly read-only taskgroup authenticates
successfully through an interactive SSH PTY. The license-manager memory event
is an image defect and is not remediated by a RAM uplift.

Do not cold-restart or resize ADL for this issue. Use a strong random
alphanumeric local secret, allow XR to generate its native type-5 hash, and
retain the cleartext only in Ansible Vault.
