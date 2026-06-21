# Aurora network automation (`ops/automation/`)

Ansible (`cisco.ios`) config-as-code for the Region A Cisco core. First exercise: **automate the IGP** (IS-IS L2) across the `ADL-GEL-MEL-PE1-MEL-P` line instead of typing it per-node.

## Layout
```
ansible.cfg                 # inventory path, network defaults
region-a.yml                # inventory: 4 nodes + mgmt IPs
group_vars/region_a_core.yml# connection (network_cli/SSH via GNS3-VM jump) + common IS-IS vars
host_vars/<node>.yml        # per-node: loopback0, isis_net, core_links[]
playbooks/igp-isis.yml      # push IS-IS + core interfaces (idempotent)
playbooks/verify-igp.yml    # capture show output + assert all 4 loopbacks learned
```
The model is **data-driven**: edit `host_vars/*.yml` (IPs, NET, interfaces) and the playbook renders the config — no per-device CLI.

## Transport (ADR-004 jump-host model)
Ansible runs on **PC1 (WSL)** and reaches each node's mgmt IP (`10.255.191.x`) **through the GNS3 VM** via SSH `ProxyJump=gns3@100.118.0.46`, authenticating as **`aurora-claude`** with a key. So `cisco_ios` over `network_cli`/SSH, jumped through the VM — no node is on PC1's flat segment.

## Prerequisites (the chain to a real run)
1. **Nodes started** in GNS3 (`ADL-PE1, GEL-PE1, MEL-PE1, MEL-P`).
2. **SSH bootstrapped on each node** — first-time only, via console (the `ops/access/node-snippets/*` config: `ip ssh` + `aurora-claude` pubkey). Chicken-and-egg: you can't SSH to enable SSH, so the console bootstraps it; automation takes over after.
3. **`aurora-claude` key present** on PC1: `ops/access/new-agent-key.ps1 -Agent claude -Zone local` (public key goes onto the nodes in step 2).
4. **Node mgmt (`10.255.191.x`) reachable from the GNS3 VM** (MGMT-SW01 → MGMT-CLOUD-TAP).

## Run
```bash
cd ops/automation
ansible-galaxy collection list | grep cisco.ios      # confirm collection
ansible all -m ios_facts --check                     # connectivity smoke (or: ansible-playbook ... --check)
ansible-playbook playbooks/igp-isis.yml --check --diff   # DRY RUN — show what would change
ansible-playbook playbooks/igp-isis.yml                  # APPLY
ansible-playbook playbooks/verify-igp.yml                # VERIFY (adjacency + 4 loopbacks)
```
`--check --diff` is the MOP pre-check; `verify-igp.yml` output is the post-check evidence.

## Notes
- Idempotent: re-running `igp-isis.yml` only pushes drift (that's the point — desired-state config).
- No secrets in repo: keys live in `~/.ssh`, `aurora-claude` is key-only.
- LDP/MPLS, iBGP-VPNv4, and L3VPN will be added as sibling playbooks once IGP is green.
