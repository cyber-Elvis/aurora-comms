# Dell Laptop — Setup Guide

This folder migrates the Aurora carrier lab from the Desktop to the Dell laptop. After this setup, the Dell becomes the canonical containerlab host. The Desktop frees up for GNS3 + Palo Alto VM-Series.

## What runs on the Dell after this setup

- WSL2 + Docker Engine (native, NOT Docker Desktop) + Containerlab + gh + git
- Containerlab Aurora backbone (4× FRR P/PE routers)
- Hyper-V VMs (added in W2): Wazuh, MISP, FreeRADIUS, Maple Ridge AD, jump box, LibreNMS

## Prereqs — Windows side (manual, one-time)

1. Enable Windows features (requires reboot):
   - Open `optionalfeatures.exe`
   - Tick **Hyper-V** (all sub-features), **Virtual Machine Platform**, **Windows Subsystem for Linux**
   - OK → reboot

2. Install Ubuntu 22.04 LTS in WSL:
   - Microsoft Store → search "Ubuntu 22.04 LTS" → Install
   - Or PowerShell as Admin: `wsl --install -d Ubuntu-22.04`
   - First launch creates UNIX user + password

3. (Optional) `wsl --set-default Ubuntu-22.04`

## Bootstrap (inside WSL Ubuntu)

```bash
cd ~
git clone https://github.com/cyber-Elvis/aurora-comms.git
cd aurora-comms
bash _setup/dell/bootstrap.sh
```

bootstrap.sh installs Docker Engine, Containerlab, gh, git config — idempotent, safe to re-run.

## Authenticate to GitHub + deploy

After bootstrap finishes:

```bash
# Close and reopen WSL once so docker group sticks
exit
# (reopen Ubuntu)
cd ~/aurora-comms
gh auth login              # interactive — pick web flow + HTTPS
bash _setup/dell/deploy.sh # pulls FRR image, deploys Aurora, verifies IS-IS + BGP
```

## Verify

```bash
sudo containerlab inspect -t lab/backbone/topology.clab.yml
sudo docker exec clab-aurora-melbourne vtysh -c "show isis neighbor"
sudo docker exec clab-aurora-melbourne vtysh -c "show ip bgp summary"
```

## Tear down

```bash
cd ~/aurora-comms/lab/backbone
sudo containerlab destroy -t topology.clab.yml --cleanup
```
