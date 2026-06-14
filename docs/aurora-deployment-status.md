# Aurora Deployment Status

> **Latest state: 2026-06-15** (top). The 2026-06-07 migration snapshot is kept below as the historical record.

## Current state - 2026-06-15: Cisco Region A + secure access foundation (ADR-003 / ADR-004)

**Region A backbone is now Cisco**, not Nokia (decision recorded in `adr-003-revendor-cisco-region-a.md`; executable plan in `region-a-plan.md` v2.2):

| Role / POP alias | Now | Was |
| --- | --- | --- |
| Aurora-P / MEL-P | **IOL-AdvEnterprise-L3** (IS-IS L2 + LDP) | SR Linux 24.10 |
| Aurora-PE-1 / MEL-PE1 | **IOL-AdvEnterprise-L3** (MPLS L3VPN; Transit-A + Melbourne IXP) | SR OS 13.0R4 |
| Aurora-PE-2 / BNE-PE1 | **IOL-AdvEnterprise-L3** (MPLS L3VPN; Helix/Brisbane edge) | SR OS 13.0R4 |
| Aurora-PE-3 / SYD-PE1 | IOS-XRv 6.1.3 (Region B/C edge + first ROV enforcer) | IOS-XRv 6.1.3 |
| Geelong / GEL access | `region-a-ce-spare` placeholder now; target light `Aurora-PE-4` later | historical Geelong POP concept |
| Adelaide / ADL-PE1 | planned POP, not instantiated yet | n/a |
| Perth / PER-PE1 | planned POP, not instantiated yet | n/a |
| Darwin / DRW-PE1 | planned POP, not instantiated yet | n/a |
| Tasmania-Hobart / HBA-PE1 | planned POP, not instantiated yet | n/a |

- **Build in progress (GNS3 project `ops-lab`, `d8119db0-â€¦`):** Aurora-P + Aurora-PE-1 **created, linked (e0/0â†”e0/0), booted** (IOL-L3, at enable prompt), being configured per `region-a-plan.md` Â§6 Wave 1 (IS-IS L2 + LDP â†’ iBGP VPNv4 â†’ L3VPN VRF CUST-A). Console-driven via the `iolcfg.py` socket helper on the GNS3 VM (Python 3.14 â†’ no `telnetlib`, raw-socket telnet instead).
- **Nokia archived, not deleted.** SR OS 13.0R4 licensed qcow2 + RTC recipe cold-stored (md5 recorded, `memory/sros-gns3-license-recipe.md`); SR Linux stopped. Recoverable via git history + cold storage. PC1 vrnetlab SR OS stays as offline failover.
- **vJunos-router does NOT run on the Dell** â€” boots its Wind River host, the inner Junos VM won't start (triple-nested wall), clean poweroff (`memory/gns3-nos-boot-quirks.md`). **Juniper â†’ Region B** (vSRX/vJunos via CML BYOI) + **cloud cRPD**; **vSRX runs standalone-local** for Junos/firewall practice.
- **Three-region model (ADR-003):** A = local Dell GNS3 Cisco (permanent); B = DevNet CML Cisco **+ Juniper**; C = cloud edge (DigitalOcean containerlab: cRPD + FRR + Routinator + public-IP route-server).
- **Secure access model (ADR-004):** two rings are now the target â€” Tailscale management ring for PC1/PC2/DO/Oracle hosts, and a virtual-edge WireGuard data-plane ring for lab transport. `admin` remains Elvis-owned break-glass; `aurora-codex` and `aurora-claude` are lab-node-only automation accounts. Host OSes must not appear as routed lab nodes.
- **Cloud credits / lifecycle:** Oracle A$400 trial (exp ~**Jul 8**, always-free ARM capacity-blocked); DigitalOcean $200 (exp **Jul 30** â†’ Region C); AWS $120 (earmarked **Mac host â€” out of scope**). Teardown reminders set for Jul 7 / Jul 30 (Claude app + Google Calendar). `memory/cloud-credits.md`.
- **Working model:** Elvis drives device console commands for muscle memory; Codex/Claude set up lab plumbing, provide command sequences/MOP evidence templates, and verify state through GNS3 API or SSH unless explicitly permitted to touch a console. `memory/lab-coaching-workflow.md`.

### Secure access / SSH status - 2026-06-15

ADR-004 has moved from design/tooling into the first live device slice for the Melbourne pair:

| Item | Status | Notes |
| --- | --- | --- |
| `docs/adr-004-secure-rings-host-isolation.md` | Done | Accepted design for management ring, lab data-plane ring, per-agent access, and host isolation |
| GNS3 management TAP | Done / live | `tap-aurora-mgmt` on the GNS3 VM owns `10.255.191.1/24`; `MGMT-CLOUD-TAP -> MGMT-SW01 -> node e0/1` is the local node-management path |
| `ops/access/aurora-ssh.ps1` | Done / live-tested | Supports `proxy_jump`; `mel-p1` and `mel-pe1` connect through `gns3@100.118.0.46` to `10.255.191.11/12` |
| `ops/access/inventory.yml` | Done | Non-secret aliases now use `10.255.191.0/24` management addresses plus `proxy_jump: gns3@100.118.0.46` |
| `ops/access/new-agent-key.ps1` | Done / executed | Generates per-agent Ed25519 keys under `%USERPROFILE%\.ssh` non-interactively by default; supports optional `-Passphrase` |
| `ops/access/node-snippets/` | Done / MEL applied | MEL-P and MEL-PE1 snippets include non-secret public key bodies; BNE/SYD remain templates for next waves |
| `aurora-codex` / `aurora-claude` accounts | Done on MEL pair | Both accounts exist on `MEL-P-CISCO-IOL-RT01` and `MEL-PE1-CISCO-IOL-RT01`; they remain lab-node-only identities |
| Live SSH to MEL-P / MEL-PE nodes | Verified | `aurora-codex` and `aurora-claude` both returned the expected hostnames over SSH through the GNS3 jump host |
| Secrets / private keys in repo | Clean | Private keys stay in `%USERPROFILE%\.ssh`; repo contains only public key bodies, placeholders, inventory, and helper logic |
| Local containment negative tests | Pending | Next security proof: show lab nodes cannot initiate SSH/RDP/SMB/WinRM/hypervisor/admin access to PC1/PC2 |

Verified local access:

```powershell
.\ops\access\aurora-ssh.ps1 mel-p1  -UseCodex  -IdentityFile $HOME\.ssh\aurora-codex-local-ed25519
.\ops\access\aurora-ssh.ps1 mel-pe1 -UseCodex  -IdentityFile $HOME\.ssh\aurora-codex-local-ed25519
.\ops\access\aurora-ssh.ps1 mel-p1  -UseClaude -IdentityFile $HOME\.ssh\aurora-claude-local-ed25519
.\ops\access\aurora-ssh.ps1 mel-pe1 -UseClaude -IdentityFile $HOME\.ssh\aurora-claude-local-ed25519
```

Observed hostnames:

```text
10.255.191.11 -> MEL-P-CISCO-IOL-RT01
10.255.191.12 -> MEL-PE1-CISCO-IOL-RT01
```

Immediate next operator action:

1. Use the helper for MEL-P/MEL-PE1 configuration work; avoid mixing PowerShell commands into router SSH sessions.
2. Apply the same SSH pattern to BNE-PE1 when Wave 2 is created.
3. Run the ADR-004 containment validation: lab-node attempts toward PC1/PC2 SSH/RDP/SMB/WinRM/admin ports should fail and be logged.
4. Continue Region A Wave 1 routing bring-up: IS-IS L2, LDP, loopbacks, then iBGP VPNv4 and `CUST-A`.

### Documentation hygiene â€” 2026-06-14

- `docs/adr-002-two-region.md` remains at its stable path for references, but its top banner now marks it as a **historical ADR** superseded by ADR-003 and ADR-004 for active build/security decisions.
- Backlog now carries a later **ADR-002 archive cleanup** task to move old Nokia operational detail into a clearer archive appendix.

---

# Snapshot â€” Sunday 2026-06-07 00:30 AEST

Snapshot of where each Aurora component actually lives, the ADR drift discovered, and the planned migration.

## Migration session outcome (2026-06-07 ~03:30 AEST)

The Dell migration ran and **pivoted on a hard hardware limit**. Summary:

- **Images transferred + loaded on Dell.** All 6 vrnetlab images (5.8 GB gzipped) saved on PC1, transferred to Dell over the **direct gigabit ethernet cable** (PC1 `192.168.200.1` â†” Dell `192.168.200.2`; Tailscale WSLâ†”WSL was DERP-relayed and unusably slow at ~1-2 MB/s), staged on **Dell E:** (`/mnt/e/aurora-image-transfer/`, per request) and `docker load`-ed into Dell's native dockerd. Patched `launch.py` (3 patches) + SR OS license staged into `~/vrnetlab/nokia/sros/`.
- **âŒ KVM on Dell-WSL is impossible.** `wsl: Nested virtualization is not supported on this machine`. Root cause: **Windows 10** (WSL2 nested virt is Win11-only) on a **Skylake i5-6300U** (not Win11-eligible), VBS running. Not fixable. So vrnetlab VM-NOSes (SR OS, FortiGate, PA-VM, CSR, vIOS) **cannot run on Dell-WSL**.
- **âœ… SR Linux runs on Dell-WSL** (container-native, no KVM) â€” smoke-tested OK (7220 IXR-D3L, v24.10.1, all managers up).
- **Pivot (decided):** Region A SR OS PEs + firewalls run in **Dell's GNS3** â€” accelerated via **VMware Workstation nested virt** ("Virtualize Intel VT-x/EPT"), which requires the **Windows hypervisor DISABLED** (`bcdedit /set hypervisorlaunchtype off`). NOT WHPX (corrected 2026-06-07: WHPX feature is Disabled; verified `/dev/kvm` + `vmx` + `-enable-kvm` inside the GNS3 VM). In this mode Dell is a **full second KVM host** for the whole VM-NOS arsenal. âš ï¸ **Mutually exclusive with WSL2** (which needs Hyper-V) â€” so when Dell is in GNS3-KVM mode, Dell-WSL (Tailscale `100.107.71.87`, sshd, SR Linux container) is OFFLINE. Container/SR Linux/NOC roles therefore belong on **PC1 + Oracle**, not Dell-WSL. Loaded vrnetlab VM images on Dell E: are cold-storage/failover. See ADR-002 v1.3 and `memory/dell-wsl2-no-nested-virt.md`.
- **Dell baseline established:** Ubuntu-22.04, systemd, native docker, tailscale (`100.107.71.87`), openssh-server, qemu-utils. WSL user is **`elvis-pc`**.
- **Temporary plumbing to clean up:** the `netsh portproxy :2222â†’WSL:22` on Dell-Windows (goes stale on each `wsl --shutdown`); E: tarballs are redundant with PC1 and can be pruned if E: space is needed.

## GNS3 NOS validation â€” known blockers (2026-06-08, refined)

Full image arsenal boot-tested on **Dell GNS3** (VMware nested-virt KVM, i5-6300U **2 physical cores / 19 GB VM**). After the full sweep, **two NOSes genuinely do not run on the Dell** and have chosen paths forward; a third (IOL) initially looked unresolved but was traced to a RAM default.

| Node | Status | Notes / workaround |
| --- | --- | --- |
| **cEOS (Arista)** | **Won't run** â€” not fixable via template | GNS3's docker `/gns3/init.sh` takes over PID 1, so EOS agents never start â†’ `Cli: Connection refused`. **Decision:** run cEOS via **containerlab on PC1** (containerlab gives the container a proper init so the EOS agents come up). SR Linux 24.10.1 already covers the GNS3 container role in Region A. |
| **Cisco Nexus 9300v 9.3.4** | **Won't run** â€” triple-nested-virt hang | qemu alive, RSS frozen at ~42 MB (kernel never loads), one vCPU pinned 90-100%, 0 bytes ever on the serial. Image valid (md5 match, `qemu-img check` clean); 3 CPU/vCPU combinations all hang identically. Triple-stacked virtualization (VMware â†’ GNS3-VM KVM â†’ NX-OS) is the wall. **Decision:** defer to **Region B via DevNet CML** (the CML "NX-OS 9000" node definition *is* the 9300v, on Cisco's non-triple-nested infra). Build the EVPN-VXLAN fabric in CML and export topology .yaml to persist across ephemeral reservations. Plan in `memory/nexus-9300v-via-devnet-cml-region-b.md`. |
| **Cisco IOL / IOU** | âœ… **Resolved** â€” root cause was RAM, not CPU features | The original "CPU lacks SSSE3/SSE4" theory turned out wrong (the GNS3 VM *does* expose those instructions). Actual cause: default GNS3 IOU template ran with `ram=256 / nvram=128`, so IOS-XE 17.15 exhausts its Processor memory pool at Init â†’ `%SYS-2-MALLOCFAIL` â†’ crashinfo dump. **Fix:** set the template and node to `ram=2048, nvram=1024`. IOL now reaches `IOU1#`, `show version` = IOS-XE 17.15.1. License (`gns3vm = 73635fd3b0a13ad0`) is valid; no keygen attempted (license bypass declined). |

Everything else that was boot-validated, plus the host RAM/CPU limits (steady-state fabric vs singleton heavyweights; FTDv/Cat9kv need `-cpu host`; XRv9k needs `cpu_throttling=80`), is captured in `memory/gns3-nos-boot-quirks.md`, `memory/gns3-vm-ram-budget.md`, and ADR-002 Â§3.9 (added v1.4 â€” the Dell capability envelope, formalising this validation as architecture).

Below is the pre-migration snapshot that prompted the session.

## Current actual deployment

### PC1 (FORTY3S-PC1, Ryzen 7 2700, 32 GB)

Native Docker daemon in WSL2 Ubuntu. systemd active. Tailscale IP `100.116.32.29`.

**Containers:**
- `vrnetlab/vr-fortios:7.0.14` (Fortinet FortiGate-VM 7.0.14)
- `vrnetlab/paloalto_pa-vm:9.0.4` (Palo Alto VM-Series 9.0.4)
- `vrnetlab/nokia_sros:13.0.R4` (Nokia SR OS 13.0.R4 â€” **license-valid**, 175 days)
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
- SR OS 13.0.R4 GNS3 node â€” **license-valid** (separate flash copy of same license)

**Not yet deployed:**
- Docker / WSL Ubuntu prep for vrnetlab migration
- Tailscale CLI inside WSL
- openconnect VPN endpoint for DevNet bridge

## ADR-002 v1.1 architectural intent (the drift)

ADR-002 v1.1 Â§3.1 designated **Dell PC** as Region A host:
- Region A backbone (SR Linux P + 2Ã— SR OS PE)
- Northwind CE (FortiGate-VM)
- Helix LAN (Aruba CX, 8 GB)
- Total ~14-16 GB RAM budget

ADR-002 v1.1 Â§6 designated **Dell PC** as VPN host for DevNet bridge.

### Why the drift happened

Convenience. All vrnetlab builds happened on PC1 because that's where work was active. Tailscale's location-transparent access masked the architectural intent. The drift was caught at 00:30 Sunday June 7 2026 â€” too late for migration that night.

## Migration plan to Dell (next session)

Detailed in `dell-migration-plan.md`. Seven phases, ~3 hours focused work.

Decisions captured:
- PC1 vrnetlab containers stay running as failover backup until Dell is verified working
- Wazuh + MISP remain on PC1 (correctly placed per ADR Â§3.1)
- VPN endpoint deployed on Dell as part of migration (per ADR Â§6)
- ADR-002 v1.2 deferred until migration completes â€” document actual state, not intent

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
2. Same license applied to GNS3 SR OS on Dell â€” proven to work in two independent environments
3. Three launch.py patches documented (date detection, BOF empty guard, idempotent processFiles)
4. Persistence chain verified end-to-end
5. Termius via Tailscale access proven from multiple devices
6. ADR drift discovered and acknowledged before going further

## Architectural lesson

The Tailscale-everywhere access pattern blurs the host-locality question that ADR-002 took seriously. When physical placement is abstracted away by network, it's easy to drift from documented architecture without noticing. ADR refresh discipline must include "verify deployment matches design" not just "design is current."
