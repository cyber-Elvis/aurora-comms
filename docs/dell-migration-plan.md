# Dell Migration Plan — Closed Outcome And Current Placement

| Field | Value |
| --- | --- |
| Status | Closed / historical |
| Original target | Move Region A vrnetlab workloads from PC1 WSL2 to Dell WSL2 |
| Actual outcome | WSL2 KVM blocked; Region A moved to Dell GNS3 instead |
| Current active Region A | Cisco core in Dell GNS3 (`ops-lab`) per ADR-003 and `region-a-plan.md` v2.5 |
| Last updated | 2026-06-16 |

This file is retained so the migration decision trail does not disappear. It is **not an executable runbook anymore**.

The original June 2026 plan was to run Aurora Region A inside Dell WSL2 using vrnetlab containers. That plan was executed through the prep and transfer phases, then permanently pivoted when Dell WSL2 could not expose KVM:

```text
wsl: Nested virtualization is not supported on this machine
```

Root cause: Dell is Windows 10 on an Intel i5-6300U platform. WSL2 nested virtualization is not available here. VM-based NOSes such as SR OS, FortiGate, PA-VM, CSR, vIOS, ASAv, FTDv, and FMC therefore cannot run under Dell WSL2.

## Current Placement

| Component | Current home | Notes |
| --- | --- | --- |
| Region A core | Dell GNS3 VM | Cisco IOL-L3 P/PE core + IOS-XRv PE-3, built in `ops-lab` |
| Region A firewalls / heavy NOS tests | Dell GNS3 VM | Singleton-on-demand; stop Region A fabric before FTDv/FMC/PA-VM/Cat9kv/XRv9000 |
| Region B | Cisco DevNet CML | Cisco + Juniper extension; external reservation-dependent |
| Region C | Cloud edge | DigitalOcean/containerlab edge planned for cRPD + FRR + Routinator |
| Always-on tooling | PC1 / future Oracle Free | NetBox, Oxidized, LibreNMS/Grafana, Wazuh/MISP, Ansible |
| Nokia SR OS/SR Linux | Archived | License recipe and images preserved; not active Region A core |

The active design is:

```text
Region A: Dell GNS3 Cisco core
  -> Region B: DevNet CML Cisco + Juniper
  -> Region C: cloud edge
  -> TechOps operations layered on top
```

## Valid Migration Facts Preserved

These facts from the original migration remain useful:

| Item | Value |
| --- | --- |
| Dell host | `forty3s-PC2` |
| PC1 internet-sharing Ethernet | `192.168.137.1` |
| Dell internet-carrying Ethernet | `192.168.137.2` |
| GNS3 controller | `http://192.168.137.2:3080/v2` |
| GNS3 VM Tailscale | `100.118.0.46` |
| Dell Windows Tailscale | `100.109.74.61` |
| Dell E: share from GNS3 VM | `//192.168.137.2/e`, SMB username `forty3` |
| Dell GNS3 mode | VMware Workstation nested virtualization, Hyper-V disabled |

## What Was Superseded

Do not use the old plan to:

- enable WSL2 nested virtualization on Dell;
- run vrnetlab VM-NOS containers on Dell WSL2;
- use Dell WSL2 as the Region A service host;
- place the DevNet VPN bridge on Dell WSL2;
- treat Nokia SR OS/SR Linux as the active Region A core.

Those choices were superseded by:

- ADR-002 v1.3/v1.4/v1.5 for the VMware nested-virt reality and Dell capability envelope;
- ADR-003 for the Cisco Region A re-vendor and three-region model;
- `region-a-plan.md` v2.5 for the current executable Region A build;
- `telstra-ops-practice-plan.md` for build-then-operate TechOps practice.

## Current Next Steps

1. Build Region A Cisco core in `ops-lab` using `region-a-plan.md` §6.
2. Validate Region A smoke tests from `region-a-plan.md` §7.
3. Onboard the built network to config backup, monitoring, logging, and NetBox.
4. Add Region B through DevNet CML.
5. Add Region C cloud edge.
6. Run TechOps patching, incident, MOP, rollback, and evidence drills on top of the live network.

## Why This File Stays

The failed Dell-WSL path explains why the lab is shaped the way it is:

- Dell is excellent as a **GNS3 KVM host** via VMware nested virt.
- Dell is not usable as a **WSL2 KVM host**.
- Hyper-V/WSL2 and VMware nested virt are mutually exclusive on this Dell.
- PC1 and cloud services carry the always-on tooling while Dell carries the VM-NOS bench.

That constraint is architectural, not incidental, so the migration record stays in the repo.
