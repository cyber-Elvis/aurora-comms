# Aurora Deployment Status

> **Latest state: 2026-06-25** (top). Earlier snapshots are kept below as the historical record.

## Current state - 2026-06-25: Inter-region border (ASBR) designated + XRv9000 re-platform DECLINED

**(a) Region A-side inter-region ASBR / Region B border router = `MEL-PE1`.** `MEL-PE1`
(Aurora-PE-1, IOS-XRv 6.1.3, `Lo0 10.0.0.2`) is the designated ASBR that terminates the
inter-region eBGP `64496 ↔ 65002` to Region B's `DC-P-R1`. It already carries iBGP VPNv4 +
ipv4-unicast, the Transit-A eBGP (64497), the Northwind PE-CE, and the Melbourne IXP attachment.
Inter-AS is plain eBGP (global IPv4 unicast, Option A only — no MPLS label transfer across the
openconnect + MASQUERADE NAT). `MEL-P` (Aurora-P, `Lo0 10.0.0.1`) remains a **pure P router**
(IS-IS L2 + LDP, no BGP) and is only the right-side **transport** handoff toward the PC1/Region B
bridge — it is transport, not the BGP border. `SYD-PE1` is a **Region B node only** (Sydney;
Region B/C edge, first IOS-XR ROV enforcer) and is not the Region A end of the A↔B boundary.

**(b) XRv9000 re-platform of a MEL node — EVALUATED AND DECLINED.** Re-platforming a MEL node to
an XRv9000 on the Dell GNS3 VM was considered and rejected: the 19 GiB / 2-core GNS3 VM cannot
sustain a 16 GB singleton alongside the fabric. Measured 2026-06-24/25, the full fabric plus an
idle XRv9000 at ~9.7 GB RSS left only ~1.85 GB free, with no swap. `MEL-PE1` stays IOS-XRv 6.1.3.

## Current state - 2026-06-24: Region A Internet-edge transit nodes STAGED (unconfigured)

The two Internet-edge transits were **created, wired, and booted** in GNS3 project `ops-lab`
(`d8119db0-…`, controller `http://192.168.137.1:3080`). **No service config yet** — staged per
the operator's "stage the nodes now" decision; config is deferred to the deploy MOP stages.

| Node | Template / NOS | node_id | Data link | OOB | Console |
| --- | --- | --- | --- | --- |
| `transit-a-csr` | CSR1000v-16.08.01 (AS 64497, primary) | `a08c23d6-974b-4189-a43a-67a233f9bdd3` | Gi2 ↔ `MEL-PE1` Gi0/0/0/2 (→ `10.255.2.0/30`) | Gi1 ↔ MGMT-SW01 p6 | `:5009` |
| `transit-b-iol` | IOL-AdvEnterprise-L3 = IOL-XE 17.15 (AS 64498, backup) | `9c51daa2-24ae-4ce7-9d6f-9e57e036edd4` | e0/0 ↔ `ADL-PE1` Gi0/0/0/1 (→ `10.255.2.4/30`) | e0/1 ↔ MGMT-SW01 p7 | `:5013` |

- Booted **staggered** (IOL first, then CSR) per ADR-002 §3.9.4 Rule 2; all backbone XRv nodes
  stayed `started`, no OOM/crash. XRv9000 singleton left `stopped`.
- OOB mgmt cabled to MGMT-SW01 (mgmt IPs TBD at config — e.g. `10.255.191.21/.22`, free in the plan).
- **Config still to do** (operator-driven, per `ops/access/mops/2026-06-24-region-a-transit-edge-deploy.md`):
  Stage 0 = backbone iBGP with **vpnv4 + ipv4-unicast + next-hop-self** (the §5.1a failover fix —
  prerequisite); Stage 2 = transit link IPs + originate `0/0`+mock prefixes + eBGP; Stage 3 =
  §5.4 hardening (TCP-AO/BFD/GTSM/GR/max-prefix/ROV-C1); Stage 4 = failover + ROV verify.

### Transit-plan doc fixes applied 2026-06-24 (pre-deploy)
- **Failover bug fixed** — `region-a-plan.md` §5.1a: iBGP must carry IPv4-unicast + next-hop-self
  so the transit default propagates between PEs (a VPNv4-only mesh could never fail over).
- **IOS-XR refresh** — transit/PE CLI, two-stage commit, `Gi0/0/0/x`, IOL-L3 labels dropped;
  `ip-plan.md` re-dated 2026-06-24 + PE labels → IOS-XRv.
- **RPKI reordered** — ROV enforced on both transit sessions from Phase C1 (HIGH gap closed).
- **Transit-edge hardening** — new §5.4 + transit patching MOP (`…-region-a-transit-patching.md`).
- **Capacity re-cost** — §2.5 + ADR-002 §3.9.5 note: backbone re-priced at 4×IOS-XRv (~10–11 GiB
  total), CPU cold-start soak flagged.

## Current state - 2026-06-21: Region A migrated to IOS-XRv 6.1.3 (COMPLETE)

Change `CHG-AURORA-REG-A-XRV-001` is **done** — all four Region A routers re-platformed
**Cisco IOL 17.15 → IOS-XRv 6.1.3** via a rolling one-for-one migration, deployed-state
parity preserved (addresses, loopbacks, IS-IS L2 + LDP).

| Node | Platform now | Mgmt | Loopback0 | Core |
| --- | --- | --- | --- | --- |
| `ADL-PE1-CISCO-IOSXR-RT01` | IOS-XRv 6.1.3 | 10.255.191.17 | — | shut |
| `GEL-PE1-CISCO-IOSXR-RT01` | IOS-XRv 6.1.3 | 10.255.191.15 | 10.0.0.3 | shut |
| `MEL-PE1-CISCO-IOSXR-RT01` | IOS-XRv 6.1.3 | 10.255.191.12 | 10.0.0.2 | IS-IS L2 + LDP |
| `MEL-P-CISCO-IOSXR-RT01` | IOS-XRv 6.1.3 | 10.255.191.11 | 10.0.0.1 | IS-IS L2 + LDP |

- **MEL pair IS-IS L2 (area 49.0001, metric-style wide) + LDP validated XR↔XR:** adjacency Up, LDP Oper, loopbacks `10.0.0.1`/`10.0.0.2` exchanged. GEL/ADL cores shut (parity). No VPNv4/VRF/renumber (separate future MOP).
- **Access:** break-glass user `labadmin` (`admin` is reserved/locked on XR); per-node **RSA-2048** SSH host key (XRv 6.1.3 has no Ed25519). Reach via PC3 Termius → GNS3 jump → `ssh labadmin@10.255.191.x`. XR two-stage commit (durable, no `write memory`).
- **GNS3 interface mapping** (adapter→XR, offset because XRv inserts MgmtEth as NIC0): adapter0 = `MgmtEth0/0/CPU0/0`, adapter1 = `Gi0/0/0/0`, adapter2 = `Gi0/0/0/1`. Link labels relabeled to real XR names.
- **Rollback retained:** IOL nodes (`*-CISCO-IOL-RT01`) stopped + unlinked + saved (≈1 MB each on disk, 0 RAM) until ~2026-06-28 or two clean sessions.
- **Artifacts:** MOP + per-node evidence `ops/access/mops/2026-06-21-region-a-iol-to-iosxrv-migration.md`; parity configs `ops/migration/region-a-iosxrv/`; **active automation `ops/automation-iosxrv/` (`cisco.iosxr`)** — supersedes `ops/automation/` (`cisco.ios`, IOL/legacy).
- **Pending:** 60-min soak + MEL link-flap reconvergence test; complete separate password-authenticated read-only `aurora-codex`/`aurora-claude` accounts on all XRv nodes (secrets in Ansible Vault; RSA user-key binding is unavailable on XRv 6.1.3); separate MPLS L3VPN / VPNv4 MOP.

---

## Current state - 2026-06-16: Cisco Region A + secure access foundation (ADR-003 / ADR-004)

**Region A backbone is now Cisco**, not Nokia (decision recorded in `adr-003-revendor-cisco-region-a.md`; executable plan in `region-a-plan.md` v2.5):

| Role / POP alias | Now | Was |
| --- | --- | --- |
| Aurora-P / MEL-P | **IOL-AdvEnterprise-L3** (IS-IS L2 + LDP) | SR Linux 24.10 |
| Aurora-PE-1 / MEL-PE1 | **IOL-AdvEnterprise-L3** (MPLS L3VPN; Transit-A + logical Melbourne IXP attachment) | SR OS 13.0R4 |
| GEL-PE1 / Geelong | **IOL-AdvEnterprise-L3** (MPLS L3VPN; Dell/PC2 regional-line midpoint) | historical Geelong POP concept |
| ADL-PE1 / Adelaide | **IOL-AdvEnterprise-L3** (MPLS L3VPN; Dell/PC2 regional-line endpoint; local Transit-B backup edge) | n/a |
| BNE-PE1 / Brisbane | Region B planned node (DevNet CML; Helix/Brisbane edge) | SR OS 13.0R4 / prior PE-2 concept |
| SYD-PE1 / Sydney | Region B planned IOS-XRv node (Region B/C edge + first ROV enforcer) | IOS-XRv 6.1.3 |
| Perth / PER-PE1 | planned POP, not instantiated yet | n/a |
| Darwin / DRW-PE1 | planned POP, not instantiated yet | n/a |
| Tasmania-Hobart / HBA-PE1 | planned POP, not instantiated yet | n/a |

- **Build in progress (GNS3 project `ops-lab`, `d8119db0-â€¦`):** Aurora-P + Aurora-PE-1 **created, linked (e0/0â†”e0/0), booted** (IOL-L3, at enable prompt), being configured per `region-a-plan.md` Â§6 Wave 1 (IS-IS L2 + LDP â†’ iBGP VPNv4 â†’ L3VPN VRF CUST-A). Console-driven via the `iolcfg.py` socket helper on the GNS3 VM (Python 3.14 â†’ no `telnetlib`, raw-socket telnet instead).
- **Placement update (2026-06-21):** the Dell/PC2 regional line remains aligned geographically as `ADL-PE1 -> GEL-PE1 -> MEL-PE1 -> MEL-P`. All four backbone routers are started and OOB-reachable through the GNS3 VM jump host. `MEL-P` sits on the right as the local core and logical handoff toward PC1 / Region B `SYD-PE1`.
- **IOS-XRv migration staged (2026-06-21):** change `CHG-AURORA-REG-A-XRV-001` is prepared to replace the four Region A IOL routers with IOS-XRv 6.1.3 through a rolling one-for-one migration. Four unlinked XR targets now exist above the live line; only the ADL canary is started. The IOL nodes and all eight production links remain unchanged as rollback. MOP: `ops/access/mops/2026-06-21-region-a-iol-to-iosxrv-migration.md`; translated parity configs: `ops/migration/region-a-iosxrv/`; target automation: `ops/automation-iosxrv/`.
- **Region B placement update (2026-06-15):** `BNE-PE1-CISCO-IOL-RT01` / Aurora-PE-2 and `SYD-PE1-CISCO-IOSXR-RT01` / Aurora-PE-3 were removed from local Region A staging. They remain planned Region B CML nodes; SYD keeps the IOS-XRv VPNv4/ROV/Region B-C edge role.
- **Live GNS3 link update (2026-06-15):** local Region A links now include MEL-P e0/0 -> MEL-PE1 e0/0, MEL-PE1 e0/2 -> GEL-PE1 e0/0, GEL-PE1 e0/2 -> ADL-PE1 e0/0, GEL-PE1 e0/1 -> MGMT-SW01 e4, and ADL-PE1 e0/1 -> MGMT-SW01 e5.
- **Internet-edge placement correction (2026-06-15):** keep both simulated upstream transits in Region A: Transit-A on MEL-PE1 and Transit-B on ADL-PE1. Move Docker-dependent FRR IXP peers and tenant workloads toward Region B/PC1 offload instead of making Transit-B depend on SYD/Region B.
- **PC1/PC2 Ethernet update (2026-06-20):** the local internet-carrying segment is `192.168.137.0/24`. PC2/Dell is the ICS gateway at `192.168.137.1`; PC1 currently receives `192.168.137.81` by DHCP and prefers Ethernet over Wi-Fi.
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
| `ops/access/node-snippets/` | Done / MEL applied | MEL-P and MEL-PE1 snippets include non-secret public key bodies; GEL/ADL local snippets are available; BNE/SYD remain Region B templates |
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
2. Start and configure GEL-PE1 first to extend Wave 1, then boot ADL-PE1 in Wave 2 for the Dell/PC2 regional-line endpoint.
3. Run the ADR-004 containment validation: lab-node attempts toward PC1/PC2 SSH/RDP/SMB/WinRM/admin ports should fail and be logged.
4. Continue Region A Wave 1 routing bring-up: IS-IS L2, LDP, loopbacks, then iBGP VPNv4 and `CUST-A`; keep Brisbane/Sydney work in the Region B CML plan.

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
