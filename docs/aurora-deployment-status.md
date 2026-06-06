# Aurora Deployment Status (as of Sunday 2026-06-07 00:30 AEST)

Snapshot of where each Aurora component actually lives, the ADR drift discovered, and the planned migration.

## Migration session outcome (2026-06-07 ~03:30 AEST)

The Dell migration ran and **pivoted on a hard hardware limit**. Summary:

- **Images transferred + loaded on Dell.** All 6 vrnetlab images (5.8 GB gzipped) saved on PC1, transferred to Dell over the **direct gigabit ethernet cable** (PC1 `192.168.200.1` ↔ Dell `192.168.200.2`; Tailscale WSL↔WSL was DERP-relayed and unusably slow at ~1-2 MB/s), staged on **Dell E:** (`/mnt/e/aurora-image-transfer/`, per request) and `docker load`-ed into Dell's native dockerd. Patched `launch.py` (3 patches) + SR OS license staged into `~/vrnetlab/nokia/sros/`.
- **❌ KVM on Dell-WSL is impossible.** `wsl: Nested virtualization is not supported on this machine`. Root cause: **Windows 10** (WSL2 nested virt is Win11-only) on a **Skylake i5-6300U** (not Win11-eligible), VBS running. Not fixable. So vrnetlab VM-NOSes (SR OS, FortiGate, PA-VM, CSR, vIOS) **cannot run on Dell-WSL**.
- **✅ SR Linux runs on Dell-WSL** (container-native, no KVM) — smoke-tested OK (7220 IXR-D3L, v24.10.1, all managers up).
- **Pivot (decided):** Region A SR OS PEs + firewalls run in **Dell's GNS3** (QEMU + WHPX host-level acceleration — works on Win10, already license-valid). **Dell-WSL** hosts **SR Linux (Aurora-P)** + container workloads. Loaded vrnetlab VM images on Dell are cold-storage/failover only (the runnable source-of-truth stays on PC1). See ADR-002 v1.2 and `memory/dell-wsl2-no-nested-virt.md`.
- **Dell baseline established:** Ubuntu-22.04, systemd, native docker, tailscale (`100.107.71.87`), openssh-server, qemu-utils. WSL user is **`elvis-pc`**.
- **Temporary plumbing to clean up:** the `netsh portproxy :2222→WSL:22` on Dell-Windows (goes stale on each `wsl --shutdown`); E: tarballs are redundant with PC1 and can be pruned if E: space is needed.

Below is the pre-migration snapshot that prompted the session.

## Current actual deployment

### PC1 (FORTY3S-PC1, Ryzen 7 2700, 32 GB)

Native Docker daemon in WSL2 Ubuntu. systemd active. Tailscale IP `100.116.32.29`.

**Containers:**
- `vrnetlab/vr-fortios:7.0.14` (Fortinet FortiGate-VM 7.0.14)
- `vrnetlab/paloalto_pa-vm:9.0.4` (Palo Alto VM-Series 9.0.4)
- `vrnetlab/nokia_sros:13.0.R4` (Nokia SR OS 13.0.R4 — **license-valid**, 175 days)
- `vrnetlab/cisco_csr1000v:16.08.01` (Cisco CSR1000v)
- `vrnetlab/cisco_vios:L2-15.2` (Cisco vIOS-L2)
- `ghcr.io/nokia/srlinux:24.10.1` (Nokia SR Linux 24.10.1)
- Wazuh (manager, indexer, dashboard, certs-generator)
- MISP (core, db, modules, redis, mail)

**Persistence chain:**
- systemd enables `tailscaled`, `docker`
- All containers have `--restart=unless-stopped`
- Windows Task Scheduler entry `AuroraWSL Startup` triggers WSL at logon
- Patched launch.py in `/home/fourty3/vrnetlab/nokia/sros/docker/`

**Access:**
- Termius via SSH to `100.116.32.29:22025` for licensed SR OS
- All other containers reachable via port mappings on the same Tailscale IP

### Dell PC (i5-6300U, 32 GB)

GNS3 GUI environment.

**Running:**
- GNS3 VM with KVM available
- SR OS 13.0.R4 GNS3 node — **license-valid** (separate flash copy of same license)

**Not yet deployed:**
- Docker / WSL Ubuntu prep for vrnetlab migration
- Tailscale CLI inside WSL
- openconnect VPN endpoint for DevNet bridge

## ADR-002 v1.1 architectural intent (the drift)

ADR-002 v1.1 §3.1 designated **Dell PC** as Region A host:
- Region A backbone (SR Linux P + 2× SR OS PE)
- Northwind CE (FortiGate-VM)
- Helix LAN (Aruba CX, 8 GB)
- Total ~14-16 GB RAM budget

ADR-002 v1.1 §6 designated **Dell PC** as VPN host for DevNet bridge.

### Why the drift happened

Convenience. All vrnetlab builds happened on PC1 because that's where work was active. Tailscale's location-transparent access masked the architectural intent. The drift was caught at 00:30 Sunday June 7 2026 — too late for migration that night.

## Migration plan to Dell (next session)

Detailed in `dell-migration-plan.md`. Seven phases, ~3 hours focused work.

Decisions captured:
- PC1 vrnetlab containers stay running as failover backup until Dell is verified working
- Wazuh + MISP remain on PC1 (correctly placed per ADR §3.1)
- VPN endpoint deployed on Dell as part of migration (per ADR §6)
- ADR-002 v1.2 deferred until migration completes — document actual state, not intent

## Vendor stack accounting

| Vendor | Image | Role per ADR-002 | Status |
| --- | --- | --- | --- |
| Nokia SR Linux | `ghcr.io/nokia/srlinux:24.10.1` | Aurora-P (P router) | Pulled, no license needed |
| Nokia SR OS | `vrnetlab/nokia_sros:13.0.R4` | Aurora-PE-1, PE-2 (Nokia PEs) | **License valid 175 days** |
| Fortinet | `vrnetlab/vr-fortios:7.0.14` | Northwind CE | Built |
| Palo Alto | `vrnetlab/paloalto_pa-vm:9.0.4` | Helix Health CE | Built |
| Cisco CSR1000v | `vrnetlab/cisco_csr1000v:16.08.01` | Region A spare CE | Built |
| Cisco vIOS-L2 | `vrnetlab/cisco_vios:L2-15.2` | Tenant LAN switch | Built |
| HPE Aruba AOS-CX 10.16.1040 | `(not built yet)` | Helix LAN | OVA downloaded, build script staged |
| HPE Aruba EdgeConnect EC-V | `(not built)` | Northwind SD-WAN | Deferred W4+, sales engagement |

Plus identified for download from upw.io (~17 GB tier-1):
- Cisco Nexus 9300v 9.3.4 (DC fabric)
- Cisco ASAv 9.22.1.1 (NGFW)
- Cisco FTDv 7.2.0 + FMC 7.2.0 (modern Cisco NGFW)
- F5 BIG-IP LTM 16.0.1.1 (load balancer)
- Juniper vSRX 22.3R1 (covers Juniper market gap)
- PA-VM 11.0.0 (newer Palo Alto)
- Cisco Cat9kv 17.10 (modern campus)
- Arista vEOS 4.30 (DC alternative)
- Cisco IOL x86_64 (lightweight L2/L3)
- Cisco SD-WAN Viptela 18.4.5 (modern SD-WAN stack)
- Cisco IOS XRv 9000 2022 (newer than current 6.1.3 demo)

## Tonight's wins captured

1. Nokia SR OS 13.0.R4 fully licensed and operational on PC1 vrnetlab (after the multi-line vs single-line license breakthrough)
2. Same license applied to GNS3 SR OS on Dell — proven to work in two independent environments
3. Three launch.py patches documented (date detection, BOF empty guard, idempotent processFiles)
4. Persistence chain verified end-to-end
5. Termius via Tailscale access proven from multiple devices
6. ADR drift discovered and acknowledged before going further

## Architectural lesson

The Tailscale-everywhere access pattern blurs the host-locality question that ADR-002 took seriously. When physical placement is abstracted away by network, it's easy to drift from documented architecture without noticing. ADR refresh discipline must include "verify deployment matches design" not just "design is current."
