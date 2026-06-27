# Region A IOS-XE Internet-edge transit automation

Target-side automation for the two Region A Internet-edge transit nodes. Separate
from `ops/automation-iosxrv/` (Region A backbone, `cisco.iosxr`) and the legacy
`ops/automation/` (IOL `cisco.ios` rollback).

| Inventory host | GNS3 node | NOS | AS | Role | Mgmt |
| --- | --- | --- | --- | --- | --- |
| `transit-a` | `transit-a-csr` | CSR1000v 16.08.01 | 64497 | primary | `10.255.191.21` |
| `transit-b` | `transit-b-iol` | IOL-XE 17.15 | 64498 | backup | `10.255.191.22` |

Deploy / config MOPs:

```text
ops/access/mops/2026-06-24-region-a-transit-edge-deploy.md
ops/access/mops/2026-06-25-region-a-transit-edge-config.md
ops/access/mops/2026-06-27-region-a-transit-real-internet.md
```

## Connection model

```text
PC1 Ansible (WSL)
  -> ProxyJump gns3@100.118.0.46
  -> transit OOB mgmt IP (10.255.191.21/.22, MGMT-SW01)
```

```yaml
ansible_connection: ansible.netcommon.network_cli
ansible_network_os: cisco.ios.ios
```

CSR 16.8 negotiates group14 KEX and presents an RSA host key; the inventory scopes
those legacy algorithms to this tree and records learned host keys in
`~/.ssh/aurora_iosxe_known_hosts`.

## Credentials

`labadmin` is the dedicated **break-glass** admin: privilege 15, a random password,
stored in Ansible Vault as `vault_transit_labadmin_password` (vault-id `labadmin`,
decrypted with `~/.aurora-vault-pass`). It is not a personal account.

Stored with the repo helper (secret via stdin, never on the command line):

```bash
printf '%s' "$PW" | ~/.local/share/pipx/venvs/ansible-core/bin/python \
  ops/access/write-ansible-vault.py \
  --output ops/automation-iosxe/group_vars/transit/vault.yml \
  --variable vault_transit_labadmin_password \
  --vault-id labadmin --password-file ~/.aurora-vault-pass
```

Scoped non-human automation and read-only agent accounts follow later, mirroring the
Region A IOS-XR RBAC tiers (`aurora-automation` / `aurora-claude` / `aurora-codex` /
`aurora-security`). Each gets its own `vault_<account>_secret`; never reuse a
credential.

> Do not run this inventory against a node until `labadmin` + SSH have been
> configured on it (the config MOP) and SSH verified manually through the jump host.
> The two transit mgmt IPs are unconfigured until then.

## Verification

`/mnt/d` is world-writable under WSL, so Ansible **ignores `ansible.cfg` there**
unless you point at it explicitly. Export `ANSIBLE_CONFIG` first so the inventory
and `vault_password_file` are honoured:

```bash
cd ops/automation-iosxe
export ANSIBLE_CONFIG=$PWD/ansible.cfg
ansible-inventory --graph
ansible-playbook playbooks/verify-platform.yml --limit transit-a
```

`verify-platform.yml` proves the labadmin + jump-host + vault chain works and
captures `show version` / interface / hostname evidence.

## Real IPv4 internet egress

`playbooks/real-internet.yml` configures the transit-node internet uplinks and PAT:

| Node | Inside | Outside |
| --- | --- | --- |
| `transit-a` | `GigabitEthernet2` | `GigabitEthernet3` |
| `transit-b` | `Ethernet0/0` | `Ethernet0/2` |

The playbook removes the old IPv4 Null0 default when present, configures DNS, builds
the `AURORA-LAB-NAT` source ACL, marks inside/outside NAT, DHCPs the uplinks through
the GNS3 `INET-SW` -> VM `eth1` path, waits for DHCP to settle, and verifies pings to
`1.1.1.1` and `8.8.8.8`.

Applied and verified 2026-06-27 from PC1 WSL:

```bash
cd ops/automation-iosxe
export ANSIBLE_CONFIG=$PWD/ansible.cfg
ansible-playbook playbooks/real-internet.yml
```

Final verification was clean and idempotent (`changed=0` on both transit nodes).
Transit-A received `192.168.191.129/24`; Transit-B received `192.168.191.130/24`;
both used default gateway `192.168.191.2` and had 100 percent ping success to
`1.1.1.1` and `8.8.8.8` from their outside interfaces.
