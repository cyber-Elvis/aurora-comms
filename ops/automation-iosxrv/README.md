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

