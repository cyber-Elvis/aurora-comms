# Region A IOS-XRv automation

This is the target-side automation scaffold for the rolling migration in:

```text
ops/access/mops/2026-06-21-region-a-iol-to-iosxrv-migration.md
```

It is separate from `ops/automation/`, which remains the working
`cisco.ios` rollback automation for the IOL nodes.

Do not run this inventory against an IP that still belongs to an IOL node.
Use it only after that POP has been cut over to IOS-XRv and SSH access has
been verified manually.

## Connection model

```text
PC1 Ansible
  -> ProxyJump gns3@100.118.0.46
  -> IOS-XRv management IP
```

Collection and transport:

```yaml
ansible_connection: ansible.netcommon.network_cli
ansible_network_os: cisco.iosxr.iosxr
```

IOS-XRv 6.1.3 agent accounts use strong local secrets stored in Ansible Vault.
RSA user-key binding is unavailable on this demo image. The inventory scopes
the required legacy KEX and host-key algorithms to Region A and records learned
host keys in `~/.ssh/aurora_iosxr_known_hosts`.

The current encrypted vault contains the `aurora-claude` secret. Add
`vault_aurora_codex_secret` as a separate value before running automation as
Codex; never reuse an agent credential.

Codex uses a separate inventory and vault identity:

```text
ansible-codex.cfg
inventory-codex.yml
group_vars/region_a_iosxr_codex/
~/.aurora-codex-vault-pass
```

This separation prevents either agent credential from depending on the other
agent's vault password. Run Codex verification with:

```bash
ANSIBLE_CONFIG=./ansible-codex.cfg \
  ansible-playbook playbooks/verify-platform.yml --limit adl-pe1
```

The current custody copy of the Codex vault password is
`C:\Users\Elvis\.aurora-codex-vault-pass` on PC1 with a user-only ACL. Ansible
requires a Linux control environment; when PC1 WSL or its replacement is
restored, provision the same file as `~/.aurora-codex-vault-pass` with mode
`0600`. Do not persist the vault password on the GNS3 VM.

## Verification

```bash
cd ops/automation-iosxrv
ansible-inventory -i inventory.yml --graph
ansible-playbook -i inventory.yml playbooks/verify-platform.yml --limit adl-pe1
ansible-playbook -i inventory.yml playbooks/verify-mel-core.yml
```

`verify-platform.yml` captures platform, interface, commit, and hostname
evidence. `verify-mel-core.yml` captures IS-IS, LDP, and route evidence after
both Melbourne routers have migrated.

The first configuration push is intentionally manual and MOP-driven so the
operator practises IOS-XR candidate configuration, commit review, labelled
commit, and rollback. Idempotent IOS-XR configuration roles follow after the
platform migration is accepted.
