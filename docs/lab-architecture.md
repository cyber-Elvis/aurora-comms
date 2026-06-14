# Aurora & Sentinel Ridge — Lab Architecture (ADR-001)

> **Current scope note (ADR-003 v1.2, 2026-06-14):** this ADR-001 document is the historical workload-placement record. The active lab is now Cisco Region A on Dell GNS3, Juniper/Cisco Region B in DevNet CML, and Region C cloud edge, followed by TechOps operations practice. The national POP geography remains Melbourne, Sydney, Brisbane, Geelong, Adelaide, Perth, Darwin, and Tasmania/Hobart; Region A/B/C are deployment domains. Use `docs/adr-003-revendor-cisco-region-a.md`, `docs/region-a-plan.md`, `docs/devnet-resource-strategy.md`, and `docs/telstra-ops-practice-plan.md` for current execution.

| Field | Value |
| --- | --- |
| Status | Accepted historically; active placement superseded by ADR-003 where noted |
| Version | 1.7 |
| Date | 2026-06-14 |
| Decision | Historical hybrid workload distribution; active lab = Cisco Region A on Dell GNS3, Region B in DevNet CML, Region C cloud edge |
| Owner | Lab architecture (Elvis Ifeanyi Nwosu) |
| Supersedes | n/a (initial) |
| Related | `docs/adr-003-revendor-cisco-region-a.md`, `docs/region-a-plan.md`, `docs/design.md`, `docs/ip-plan.md`, `BACKLOG.md` |

## Revision history

| Version | Date | Change |
| --- | --- | --- |
| 1.0 | May 2026 | Initial decision: Option C hybrid workload distribution |
| 1.1 | May 2026 | Added Cowork agent (~3 GB) to PC1 always-on accounting; tightened active-lab pool from 11 GB to 8 GB and revised sprint feasibility; fixed WSL2 memory cap to 12 GB in migration plan |
| 1.2 | May 2026 | Phase 1 audit reconciliation: Docker Desktop (~2 GB) retained on PC1 to host pre-existing personal stacks (job-radar, openwebui, freshrss, rsshub); active-lab pool tightened from 8 GB to 6 GB; Tailscale measured as already deployed across `forty3s-pc1/pc2/pc3` with magic DNS; native Docker in WSL Ubuntu coexists with Docker Desktop, isolated to lab workloads; Docker data-root relocated to D:\ to handle 35 GB C: drive free constraint |
| 1.3 | May 2026 | Per-tenant customer-edge and LAN topology committed: §14 multi-vendor matrix (Cisco at Maple Ridge full stack; Cisco edge + HPE Aruba LAN at Helix Health; Juniper cRPD edge + Cisco LAN at Northwind); §15 vendor strategy framing Cisco-first with HPE Aruba and Juniper as multi-vendor demonstrators matching realistic Australian enterprise patterns; §6 RAM allocation updated for one-tenant-at-a-time PC1 cycling; §10 constraint #9 added (vendor account dependencies); §11 Sprint W4 work expanded (vrnetlab wrappers for Cisco/Aruba VM images, Juniper cRPD native pull). GNS3 and EVE-NG explicitly rejected: all CE/LAN/firewall runs as containerlab nodes, including vrnetlab-wrapped vendor VM images |
| 1.4 | May 2026 | Throughput vs. demo path separation pattern committed: §15.4 design pattern for splitting protocol-demo paths (Cisco/Nokia licensed-but-capped images for vendor-CLI credibility) from throughput-test paths (FRR/VyOS substitutes or TRex traffic generator for data-plane validation at WSL2 substrate ceiling); §10 constraint #11 added (throughput-capped images drive demo/perftest topology separation); §10 constraint #12 added (Nokia SR OS 13.0 R4 runs with frozen 2015 RTC for license validity, all SR OS-originated timestamps offset 11 years); §14.4 vrnetlab wrapper inventory annotated for existing on-disk images requiring no vendor account registration (CSR1000v 16.8, IOS XRv 6.1.3, Nokia SR OS 13.0 R4, IOSv 15.7, IOSv-L2 15.2, MikroTik CHR 6.41.4); §15.3 vendor account inventory annotated to mark which vendors are covered by on-disk images vs. requiring registration; new §17 Cisco DevNet Sandbox integration as inter-AS peer carrier for current-IOS-XR demos |
| 1.5 | May 2026 | HPE-Juniper consolidation and verified vendor URLs: §14.5 added explicit acknowledgement that HPE acquired Juniper in 2025, collapsing the "Cisco vs. HPE Aruba vs. Juniper" three-vendor narrative into a "Cisco vs. HPE Networking" two-vendor narrative — the per-tenant *product* matrix (AOS-CX, cRPD, Cat9000v, etc.) remains accurate as distinct technology choices, but the *vendor account* inventory in §15.3 consolidates HPE Aruba and Juniper into a single HPE Networking row; §17 DevNet integration URLs verified from cisco.com fetch (devnetsandbox.cisco.com, developer.cisco.com/site/sandbox/, developer.cisco.com/docs/sandbox/, software.cisco.com/download/home/283000185 for Cisco Secure Client formerly AnyConnect); §15.3 Nokia row URLs verified from nokia.com fetch (SRC program at /networks/training/src/, My SR Learning Labs); HPE Networking URLs verified (devhub.arubanetworks.com developer hub serves both Aruba and Juniper, airheads.hpe.com migrated community, networkingsupport.hpe.com software downloads); §15.5 added honest verification disclaimer noting which vendor portals are login-gated and therefore not deep-link verifiable |
| 1.6 | May 2026 | Empirical DevNet integration validation + correction batch: (a) §15.3 Cisco row corrected — service contract required for Cat8000v/Cat9000v/ASAv qcow2 downloads; CCO alone insufficient. (b) §15.4 added CML pricing reality — there is no CML Free tier; CML Personal $199/yr and CML Personal Plus $349/yr are the only direct CML paths. The only zero-cost current-Cisco access for non-partner non-contract users is DevNet Sandbox hosted (no download) and the CML server embedded inside select Reservation sandboxes (e.g. SD-WAN 20.12) accessible at 10.10.20.161 during the reservation window. (c) §15.3 Fortinet row updated — fortios.qcow2 (~73 MB, virtual 2 GB, FortiOS 7.0.14 placeholder version) on disk in workspace folder; vrnetlab/vr-fortios:7.0.14 wrapper built May 31. (d) §15.3 Nokia row updated — SR Linux 24.10.1 + latest pulled May 31 from `ghcr.io/nokia/srlinux` (~3.1 GB image). (e) §17 patterns empirically validated against Cisco SD-WAN 20.12 sandbox May 31: Patterns A (SSH), B (Ansible inventory inclusion), C-L3 (container reachability), C-L7 (HTTPS API), and D (REST API automation) all CONFIRMED working via `openconnect` inside WSL2 Ubuntu + Docker MASQUERADE through tun0; Pattern C-deep (eBGP peering) NOT viable against this specific sandbox because SD-WAN cEdges run OMP toward vSmart, DC-WAN-Edge01 runs "application" routing (SD-Routing), and SD-Routing branch routers were advertised in tun0 routes but L3 not provisioned — for traditional BGP demos target an IOS XR Reservation sandbox or build controlled topology inside the embedded CML. (f) §17.6 NEW — Full empirical validation methodology and per-pattern verdicts. (g) §17.7 NEW — WSL2 networking architecture details: AnyConnect-on-Windows is NOT the recommended pattern because WSL2 NAT defeats Windows-side VPN routing; the validated pattern is `openconnect` installed inside Ubuntu WSL2 so tun0 lives in the WSL2 routing namespace and Docker containers route to DevNet via host MASQUERADE rules. (h) §10 constraint #13 added — DevNet integration via WSL2+openconnect is empirically the only validated path; Windows-side Cisco Secure Client routing to WSL2 containers is unverified and not part of the canonical architecture. |

## 1. Context

The lab spans three physical hosts to serve the carrier → MSP → enterprise topology of Sentinel Ridge MSP. Workload placement across these hosts is non-trivial because the constraint is asymmetric — one host is RAM-rich but CPU-weak; the other is balanced. A poor placement decision penalises every interview demo and every Sprint W3+ activity.

## 2. Hardware inventory

| Host | CPU | RAM | Storage | OS | Role |
| --- | --- | --- | --- | --- | --- |
| PC1 (Desktop) | Ryzen 7 2700 (8 cores / 16 threads, 3.2 GHz base) | 32 GB | 250 GB NVMe + 2 TB HDD | Windows 11 | CPU-intensive + endpoint tier |
| Dell (Laptop) | Intel i5-6300U (2 cores / 4 threads, 2.4 GHz base, 2015 vintage) | 32 GB | NVMe SSD | Windows 10 Pro | Carrier + lightweight services tier |
| Surface Pro | Intel m3/Atom-class | 8 GB | NVMe SSD | Windows 10 | Intune-managed endpoint test subject |

### Critical observation

The Dell's CPU is the binding constraint of the whole lab, not its RAM. A 2-core 2015-era mobile CPU under sustained load from Wazuh's OpenSearch indexing, MISP's correlation engine, and Cisco IOS XRd's QEMU-in-container emulation will produce visible latency in dashboards and slow protocol convergence.

## 3. Options considered

### Option A — Dell-heavy (everything except endpoints on Dell)

Place all MSP services + carrier on Dell. PC1 only hosts endpoint VMs and firewall VMs.

- **Dell load at Sprint W4:** ~34 GB (over capacity by 2 GB)
- **CPU pressure on Dell:** severe — Wazuh OpenSearch, MISP correlation, IOS XRd, and Hyper-V VMs all compete for 2 cores
- **PC1 utilisation:** moderate; idle most of the time
- **Verdict:** rejected — forces aggressive service degradation at W4 and beyond

### Option B — PC1-heavy (everything except carrier on PC1)

Move all MSP services to PC1 alongside endpoint VMs. Dell only runs the carrier backbone.

- **PC1 load at Sprint W4:** ~47 GB (over capacity by 15 GB)
- **Dell utilisation:** ~14 GB used; ~18 GB wasted
- **Hypervisor conflict on PC1:** Hyper-V (for AD DC) competes with VMware Workstation Pro (for endpoint VMs) for hypervisor platform resources
- **Daily-driver impact:** PC1 cannot be powered down without taking the entire lab offline; 9+ GB committed to background services
- **Verdict:** rejected — catastrophic resource oversubscription on PC1, underutilises Dell

### Option C — Hybrid (CPU-intensive on PC1, lightweight + carrier on Dell)

CPU-intensive backend services (Wazuh manager, OpenSearch, MISP) move to PC1. Lightweight always-on services (FreeRADIUS, AD DC, LibreNMS, Grafana, pfSense, jump box) stay on Dell. Carrier containerlab stays on Dell.

- **Dell load at Sprint W4:** ~25.5 GB (6.5 GB headroom)
- **PC1 load at Sprint W4:** ~24 GB always-on + ~8 GB pool for active labs
- **CPU placement:** heavy workloads run on the fast Ryzen; light workloads on the Dell where they fit comfortably
- **Daily-driver impact:** PC1 becomes always-on, but the always-on services are buffered by the active-lab pool
- **Verdict:** accepted

## 4. Decision

**Option C — Hybrid workload distribution.**

PC1 hosts CPU-intensive backend services, the Cowork development agent, endpoint VMs, on-demand firewall labs, and CCNA-style customer-edge topologies. Dell hosts the containerlab carrier backbone, persistent infrastructure services (identity, monitoring, NAC, fallback firewall), and the lab's central management plane. Surface Pro acts as a single Intune-managed endpoint for Conditional Access policy testing.

## 5. Service placement matrix

| Service | Tier | Host | Allocation | Why this host |
| --- | --- | --- | --- | --- |
| Aurora carrier backbone (containerlab) | Carrier | Dell | 5–8 GB | Container-light, fits Dell's CPU well at steady state |
| Multi-vendor PEs (Nokia SR Linux, Cisco IOS XRd) | Carrier | Dell | 4 GB | Container-native; XRd accepted slower on i5 |
| Maple Ridge CE routers (in containerlab) | Customer edge | Dell | 1 GB | Aligned with PE for direct connectivity |
| **Wazuh manager + OpenSearch + dashboard** | MSP SIEM | **PC1** | **6 GB** | CPU-heavy search/index needs Ryzen |
| **MISP + Redis** | MSP threat intel | **PC1** | **3 GB** | CPU-heavy correlation needs Ryzen |
| **Cowork agent + sandbox VM** | Lab development | **PC1** | **~3 GB** | The development environment used to build, document, and iterate the lab. ~660 MB Claude app + ~1.5 GB Linux sandbox VM (HCS) + ~340 MB Node.js helpers + variable WebView |
| **Docker Desktop + personal stacks** (job-radar, openwebui, freshrss, rsshub) | Personal productivity | **PC1** | **~2 GB** | Pre-existing personal infrastructure. Docker Desktop's `docker-desktop` WSL distro (~1.4 GB vmmem) + Docker Desktop GUI (~300 MB) + container overhead. Job-radar specifically supports active job search and is intentionally retained |
| Maple Ridge AD DC | MSP identity | Dell | 3 GB | Low CPU, persistent service |
| FreeRADIUS NAC | MSP NAC | Dell | 1 GB | Low CPU, lightweight |
| LibreNMS + Grafana | MSP monitoring | Dell | 4 GB | Low CPU, persistent monitoring |
| pfSense MSP fallback firewall | MSP perimeter | Dell | 1 GB | Low CPU, persistent |
| Jump box (Ubuntu) | MSP management | Dell | 1 GB | Very low resources |
| Win 11 endpoint VM | Helix/Maple Ridge endpoint | PC1 | 6 GB | Endpoint testing, on-demand |
| macOS endpoint VM | Helix endpoint | PC1 | 8 GB | Endpoint testing, on-demand |
| Palo Alto VM-Series | Maple Ridge perimeter | PC1 | 8 GB | W4 firewall lab, on-demand |
| FortiGate-VM | Helix perimeter | PC1 | 2 GB | W4 firewall lab, on-demand |
| Cisco ASAv (optional) | Cisco FW syntax | PC1 | 1.5 GB | On-demand |
| GNS3 or alternate visual lab | Visualisation | PC1 | as-needed | On-demand |
| Surface Pro endpoint | Intune leadership testing | Surface Pro | 8 GB host | Intune-enrolled corporate device simulation |

## 6. RAM allocation summary

### PC1 (32 GB)

| Category | Allocation |
| --- | --- |
| Win 11 host + apps | 6 GB |
| Cowork agent (Claude app + sandbox VM + Node.js helpers) | 3 GB |
| Docker Desktop GUI + `docker-desktop` WSL distro (personal stacks) | 2 GB |
| WSL2 Ubuntu + native Docker (hard-capped at 12 GB via `.wslconfig`) | 6 GB |
| Wazuh manager + OpenSearch + dashboard (in WSL Ubuntu) | 6 GB |
| MISP + Redis (in WSL Ubuntu) | 3 GB |
| **Always-on subtotal** | **26 GB** |
| Active lab pool | **6 GB** |

**Observed baseline (May 2026 Phase 1 audit):** 14.7 GB used at idle (before Wazuh + MISP migration), measured via Win32_OperatingSystem CIM. The 26 GB always-on figure above is the post-W2-migration target.

**Docker daemon split:**
- Docker Desktop's daemon (in `docker-desktop` WSL distro) hosts personal stacks only — `job-radar`, `openwebui`, `freshrss`, `rsshub`.
- Native Docker Engine inside `Ubuntu` WSL distro hosts all lab workloads — Wazuh, MISP, Aurora carrier integration, vrnetlab vendor router containers.
- The two daemons are isolated by WSL distro boundary. No cross-daemon dependencies.

**Tenant CE/LAN runs from the PC1 active-lab pool, not Dell.** This matches §8's existing GRE-tunnel-from-PC1-to-Dell topology. Per-tenant RAM cost when active:

| Active tenant | CE | LAN core | Access | Endpoint | **Total** |
| --- | --- | --- | --- | --- | --- |
| Maple Ridge (full Cisco) | Cat8000v 4 GB | Cat9000v 2 GB | Cat9000v 2 GB | Win 11 6 GB | **14 GB** — Cowork + Docker Desktop both closed |
| Helix Health (Cisco edge + Aruba LAN) | Cat8000v 4 GB | Aruba CX 2 GB | Aruba CX 2 GB | macOS 8 GB | **16 GB** — Cowork + Docker Desktop both closed; tight |
| Northwind (Juniper cRPD edge + Cisco LAN) | cRPD 0.5 GB | Cat9000v 2 GB | Cat9000v 2 GB | Linux 4 GB | **8.5 GB** — Cowork closed sufficient |

**Cycling rule for tenant demos:** activate one tenant at a time. Northwind fits comfortably in the active-lab pool with only Cowork closed. Helix and Maple Ridge require both Cowork and Docker Desktop closed during their demo windows. Re-open after.

### Dell (32 GB)

| Category | Allocation |
| --- | --- |
| Win 10 host | 4 GB |
| WSL2 + Docker (capped at 4 GB) | 4 GB |
| Maple Ridge AD DC | 3 GB |
| FreeRADIUS | 1 GB |
| LibreNMS + Grafana | 4 GB |
| pfSense | 1 GB |
| Jump box | 1 GB |
| **Always-on subtotal** | **18 GB** |
| Aurora workload pool | **14 GB** |

### Surface Pro (8 GB)

Fully consumed by Win 10 host + browser + Intune client agents. No VM hosting.

## 7. CPU rationale

The Dell's i5-6300U was released in Q3 2015 and represents the mobile dual-core era. Per-core performance is reasonable for steady-state work but does not scale for concurrent compute. Workloads that struggle on this CPU include:

- **Wazuh OpenSearch** — Java-based search engine. A complex query against 30 days of logs can take 5–30 seconds. Same query on the Ryzen completes sub-second to 3 seconds. The user-experience difference is the difference between "lab feels professional" and "lab feels broken."
- **MISP correlation engine** — database-heavy, sensitive to memory bandwidth and cache. The Ryzen's larger cache and faster memory controller help materially.
- **Cisco IOS XRd** — runs QEMU virtualisation inside a Docker container. The hypervisor overhead alone is significant on a 2-core CPU. Acceptable for static lab demonstrations; painful for interactive troubleshooting.

The Ryzen 7 2700 (8 cores / 16 threads, 3.2 GHz base, 4.1 GHz boost, Zen+) was released 2018 and represents desktop performance several generations ahead. It absorbs Wazuh, MISP, and concurrent VM workloads without producing user-visible latency.

## 8. Networking model

### Inter-host management

Tailscale overlay across PC1, Dell, Surface Pro, and the WSL2 instances on each. Provides:
- Stable hostnames regardless of LAN changes
- Encrypted mesh between machines
- Browser access to PC1 dashboards (Wazuh, MISP, LibreNMS, Grafana) from any device

**Measured tailnet (May 2026 Phase 1 audit):**

| Tailnet hostname | Role | Tailscale IP | Status |
| --- | --- | --- | --- |
| `forty3s-pc1` | PC1 (Desktop, Ryzen) | 100.88.225.123 | Online |
| `forty3s-pc2` | Dell (Laptop, i5-6300U) | 100.109.74.61 | Active, direct |
| `forty3s-pc3` | Surface Pro | 100.110.254.10 | Active, direct |
| `iphone-xs` | Mobile (offline) | 100.111.123.41 | Offline 59d — drop from inventory |

All hostnames resolve via MagicDNS. Inventory files (Ansible `inventory/hosts.yml`, Wazuh agent configs, MISP feed configs) should reference `forty3s-pcN.tailNNN.ts.net` rather than literal IPs.

### Carrier-customer lab integration

GRE tunnel between PC1 (Maple Ridge CE topology in containerlab) and Dell (Aurora's Sydney PE) over the home LAN. Simulates a real customer-edge demarcation: traffic from a Maple Ridge office endpoint traverses the GRE tunnel as if it were the customer's transport circuit, lands on Aurora's PE, then routes via the carrier core.

### Wazuh agent traffic

All containerlab nodes (Aurora PEs, Maple Ridge CEs, customer endpoint VMs) configured to forward syslog to PC1's Wazuh manager via Tailscale IP. Eliminates LAN-vs-VLAN-vs-WAN complexity.

## 9. Sprint-by-sprint feasibility

| Sprint | Dell load | PC1 load | Verdict |
| --- | --- | --- | --- |
| W1 (current baseline) | ~19 GB | Measured 14.7 GB (Phase 1 audit, May 2026) | ✓ Comfortable |
| W2 (Ansible commit + VPRN + Wazuh/MISP migration) | ~20 GB | Migration target ~26 GB always-on + 6 GB pool | ✓ Fits |
| W3 (multi-vendor backbone + RR + BFD + auth + SR) | ~24 GB | ~26 GB always-on + active labs from 6 GB pool | ✓ Tight, demos may need Cowork close |
| W4 (RPKI + Palo Alto + FortiGate + customer services) | ~25.5 GB | ~26 GB always-on + cycling rules per §10 | ⚠ Requires workload cycling AND temporary closures |
| W5+ (FortiManager + advanced services + NETCONF/gNMI) | ~26.5 GB | ~26 GB always-on + 6 GB active pool | ⚠ Combined Cowork + Docker Desktop closure for peak demos |

**Active-lab pool reality at W4 (6 GB nominal):**

| Scenario | RAM | Fits at W4? |
| --- | --- | --- |
| Maple Ridge CE in WSL (FRR) | 1 GB | ✓ Comfortable |
| Win 11 endpoint at 6 GB | 6 GB | ✓ Exactly fits |
| macOS endpoint (8 GB) | 8 GB | ✗ Needs Cowork closed (reclaims 3 GB → 9 GB pool) |
| Palo Alto VM-Series (8 GB) | 8 GB | ✗ Needs Cowork closed |
| Both endpoints concurrently (Win + Mac, 14 GB) | 14 GB | ✗ Needs Cowork **AND** Docker Desktop closed (reclaims ~5 GB → 11 GB pool) |
| PA + Win 11 endpoint (12 GB) | 12 GB | ✗ Needs Cowork **AND** Docker Desktop closed |

**Sprint W4 cycling rule:** at peak, choose ONE of {macOS endpoint, Palo Alto VM-Series, multiple firewall VMs}.

**Cowork closure for demos:** closing the Cowork session reclaims ~3 GB. Demos requiring single 8 GB workloads work with just Cowork closed.

**Docker Desktop closure for big demos:** Quit Docker Desktop via tray icon (Right-click → Quit Docker Desktop). Reclaims ~2 GB additional — required for PA + endpoint or dual-endpoint demos. Personal stacks (job-radar, openwebui, freshrss, rsshub) stop during this window. Re-open Docker Desktop after demo to resume.

## 10. Constraints accepted

These limitations are explicit, documented, and acceptable:

1. **PC1 cannot be powered down** without taking the SIEM stack offline. Power-saving (display off, disks sleep) is permitted; full sleep is not.
2. **Both endpoint VMs cannot run concurrently with Palo Alto VM-Series.** macOS VM must be stopped during PA work windows.
3. **All three NGFWs (PA + FortiGate + ASAv) cannot run simultaneously.** Cycle through them per scenario.
4. **Cisco IOS XRd on Dell runs at reduced performance** compared to the same workload on PC1. Accepted because XRd is one node in a multi-vendor backbone, not the primary lab workhorse.
5. **The lab requires both PCs powered on** for the full topology to be reachable. Either alone is degraded.
6. **Cowork agent consumes ~3 GB of PC1's always-on budget** during active lab development. This is the cost of the development environment used to build and document the lab. For specific demo scenarios that need a 9 GB active-lab pool, close Cowork temporarily and reopen afterwards.
7. **Docker Desktop consumes ~2 GB of PC1's always-on budget** to keep personal stacks (job-radar, openwebui, freshrss, rsshub) running. Retained because these stacks support daily productivity (notably job-radar during active job search). For peak demos requiring an 11 GB active-lab pool (e.g., PA + endpoint or dual-endpoint scenarios), quit Docker Desktop from the tray icon — this stops personal stacks during the demo window. Re-open after.
8. **Dual Docker daemons on PC1.** Docker Desktop (in `docker-desktop` WSL distro) hosts personal stacks. Native Docker Engine (in `Ubuntu` WSL distro) hosts lab workloads. The two daemons cannot directly address each other's containers; cross-daemon connectivity goes via Windows host networking. Acceptable because the lab and personal stacks have no functional overlap.
9. **Vendor account dependencies for tenant CE/LAN.** Cisco Cat8000v, Cisco Cat9000v, and HPE Aruba CX simulator images require free vendor accounts (Cisco CCO + DevNet, HPE Aruba Networking Central). Juniper cRPD requires Juniper engineering-download login. Image downloads occur asynchronously outside demo windows. No live downloads during interview demos or customer presentations. Account registration is a one-time prerequisite before Sprint W4 deployments. Where a vendor changes licensing terms, the affected tenant CE falls back to FRR (open-source) until a replacement vendor account is approved.
10. **No GNS3 or EVE-NG.** All CE/LAN/firewall/wireless devices run as containerlab nodes. Native vendor containers (Juniper cRPD, Cisco IOS XRd, Nokia SR Linux, FRR, Cumulus VX, SONiC) execute directly. VM-only vendor images (Cisco Cat8000v, Cat9000v, ASAv; HPE Aruba CX; Palo Alto VM-Series; FortiGate-VM) execute as `vrnetlab`-wrapped containers — qcow2 packaged inside a Docker container running qemu-kvm internally, orchestrated by containerlab as ordinary nodes. This preserves the "everything as code" deployment story without depending on GNS3/EVE-NG graphical tooling. Containerlab YAML topology files are the canonical source of truth.
11. **Throughput-capped vendor images drive demo-vs-perftest topology separation.** Cisco CSR1000v 16.8 in unlicensed eval mode is capped at ~250 Kbps forwarding throughput. Older IOS XRv 6.1.3 demo build and similar legacy lab images have analogous data-plane caps. The lab accepts this by maintaining two topology variants per tenant: a protocol-demo path that retains vendor-licensed images for CLI credibility (the throughput cap is invisible at <10 Mbps test rates), and an explicit performance-test path that substitutes open-source FRR or VyOS at the high-throughput hop (no cap). For data-plane testing requiring higher rates, the lab uses TRex (Cisco's open-source traffic generator) as a container node injecting traffic directly into Aurora PEs, bypassing capped CE images. See §15.4 for the design pattern.
12. **Nokia SR OS 13.0 R4 runs with frozen 2015 RTC for license validity.** The 2015-issued ALCATEL-LUCENT 7750 SROS-vSIM demo license technically expired August 2015. The well-documented community technique sets the QEMU virtual machine RTC to `base=2015-03-10` and the VM UUID to `00000000-0000-0000-0000-000000000000` at launch, causing the SR OS image to evaluate the license as valid (175 days remaining in its 2015 frame of reference). vrnetlab `vr-sros` launch.py customised at build time to inject these QEMU flags on every container start. **Operational consequence: all SR OS-originated timestamps run 11 years behind wall-clock time.** Wazuh ingestion includes a normalisation decoder rule that source-tags SR OS events and adjusts the timestamp to wall-clock-now before correlation. NTP must remain disabled on the SR OS PE — re-enabling it would break the trick.
13. **DevNet integration uses `openconnect` inside WSL2 Ubuntu, not Cisco Secure Client on Windows.** The canonical VPN architecture for the lab installs `openconnect` directly inside the Ubuntu WSL2 distribution so the `tun0` interface and VPN routes live in the WSL2 routing namespace; Docker containers then route to DevNet IPs via host iptables MASQUERADE rules. Empirically validated May 31 2026 against Cisco SD-WAN 20.12 sandbox — see §17.6 for full methodology and per-pattern verdicts. Cisco Secure Client (formerly AnyConnect) running on the Windows host is NOT part of the canonical architecture because Windows-side VPN routing does not by default propagate into WSL2's network namespace; containerlab containers would bypass the Secure Client tunnel and exit via Windows' default route. Operators may still use Cisco Secure Client for human interactive sessions (browser/SSH from Windows directly), but containerlab-driven automation uses openconnect-in-WSL2 exclusively.

## 11. Migration plan — Sprint W2

The transition from current state (Wazuh + MISP on Dell) to Option C requires a controlled migration in early Sprint W2.

### Phase 1 — Prepare PC1 (1 hour)

1. **Docker is already split correctly.** Docker Desktop (with `docker-desktop` WSL distro) is retained for personal stacks. Native Docker Engine (`docker.io` apt package) is already installed inside the `Ubuntu` WSL distro for lab workloads. Lab containers (Wazuh, MISP, Aurora) target the Ubuntu distro daemon only.
2. Confirm `.wslconfig` is in place at `C:\Users\Elvis\.wslconfig` capping WSL2 at 12 GB and 8 vCPU (verified May 2026 Phase 1 audit).
3. **Relocate Docker data-root to D:\** because C: drive has only 35.6 GB free (Phase 1 audit). Inside Ubuntu WSL: edit `/etc/docker/daemon.json` to set `"data-root": "/mnt/d/docker-data"` and restart docker. This puts Wazuh/MISP/vrnetlab images on the 1.76 TB D: drive.
4. Verify Tailscale connectivity from PC1 to Dell (`forty3s-pc2`) and Surface Pro (`forty3s-pc3`) — already deployed at audit time, only needs verification.
5. Install Tailscale CLI inside WSL Ubuntu (`curl -fsSL https://tailscale.com/install.sh | sh`) so lab containers can resolve tailnet hostnames and the WSL host itself is reachable on the tailnet.

### Phase 2 — Deploy Wazuh on PC1 (1 hour)

1. Pull the Wazuh all-in-one Docker compose from `github.com/wazuh/wazuh-docker`.
2. Configure with the same agent enrollment authentication key as Dell's current Wazuh deployment.
3. Allocate 6 GB to the Wazuh container stack.
4. Bring up Wazuh manager + OpenSearch + dashboard.
5. Verify dashboard responsiveness on browser. Expected: sub-second to 3-second searches.

### Phase 3 — Deploy MISP on PC1 (1 hour)

1. Pull MISP Docker compose from `github.com/MISP/misp-docker`.
2. Configure database initial settings.
3. Configure Wazuh → MISP integration to point at PC1's Tailscale IP.
4. Pull a baseline IoC feed (e.g., CIRCL OSINT feed) to verify operation.

### Phase 4 — Repoint Wazuh agents (30 min)

1. Update Wazuh agent configurations on all containerlab nodes to point at PC1's Tailscale IP rather than Dell's.
2. Restart agents in batches.
3. Verify agent registration in PC1 Wazuh dashboard.

### Phase 5 — Decommission Dell Wazuh + MISP (15 min)

1. Stop Wazuh and MISP Hyper-V VMs on Dell.
2. Archive VM disks (keep for 30 days then delete).
3. Free ~9 GB of Dell RAM for other always-on services.

### Phase 6 — Validate (30 min)

1. Confirm Wazuh receives logs from all expected sources.
2. Confirm MISP feed pull works.
3. Confirm dashboards are accessible via browser from PC1, Dell, and Surface Pro.
4. Run a smoke test alert in Wazuh — trigger a simulated event, confirm alert visible in dashboard within 30 seconds.

### Phase 7 — Document (30 min)

1. Update `sentinel-ridge-msp/wazuh/README.md` with the new host location.
2. Update Tailscale IP references in any onboarding documentation.
3. Mark this ADR as fully implemented.

**Total migration time: ~4.5 hours.** Aligns with the Sprint W2 Ansible commit work as the foundational early-sprint activity.

## 12. Power and operational considerations

### Power consumption

- PC1 always-on at ~60–80 W (idle, Wazuh + MISP + Cowork background): ~$5–7/month at AU residential rates.
- Dell always-on at ~25–40 W (idle, lightweight services): ~$2–4/month.
- Surface Pro on-demand: trivial.

Total ~$7–11/month in electricity. Tolerable.

### Failure scenarios

| Failure | Impact | Mitigation |
| --- | --- | --- |
| PC1 reboots unexpectedly | Wazuh + MISP + Cowork offline ~5 min during boot | Restart on auto-power; alerts ride out gap |
| Dell reboots unexpectedly | Aurora + identity + monitoring offline | Aurora deploy in ~60 sec via `make redeploy`; AD DC + LibreNMS auto-restart |
| Both PCs offline | Lab fully offline | Surface Pro endpoint remains for offline Conditional Access testing |
| Tailscale outage | Inter-host management degraded | LAN-direct fallback works for most cross-host traffic |
| Cowork session ends | Cowork agent and sandbox VM stop | ~3 GB returned to PC1 active pool; no impact on Wazuh/MISP services |
| Docker Desktop quit (manual or crash) | Personal stacks (job-radar, openwebui, freshrss, rsshub) stop | ~2 GB returned to PC1 active pool; lab Wazuh/MISP unaffected because they run on Ubuntu WSL native Docker, not Docker Desktop. Re-open Docker Desktop to restore personal stacks (containers with `restart: unless-stopped` come back automatically) |
| Native Docker daemon crash in WSL Ubuntu | Lab containers (Wazuh, MISP, vrnetlab) stop | Personal stacks unaffected (different daemon). Restart with `sudo service docker start` or `sudo systemctl restart docker` |

### Maintenance windows

- PC1 updates: schedule during weekend mornings; Wazuh tolerates 5-minute outages without data loss.
- Dell updates: same; Aurora redeploys quickly.

## 13. Alternative considered post-decision

If at Sprint W6+ the lab's workload genuinely outgrows the 64 GB / 10-core combined envelope of these two PCs, the upgrade path is to replace the Dell with a modern multi-core mini-PC (e.g., Beelink SER7 with Ryzen 7 7840HS, 64 GB option) and migrate the always-on services to it. This is **not required for Sprint W1–W5 work** and is out of scope for ADR-001.

## 14. Customer-edge and LAN topology per tenant

### 14.1 Per-tenant matrix

The three Sentinel Ridge MSP tenants are deliberately heterogeneous to reflect realistic Australian enterprise patterns. Each pairing matches a customer archetype an interviewer or audit partner would recognise.

| Tenant | Customer archetype | CE router | LAN core / dist | Access switch | Endpoint |
| --- | --- | --- | --- | --- | --- |
| **Maple Ridge Logistics** | General SME, Cisco-everywhere shop. Sentinel Ridge MSP's bread-and-butter customer base. | Cisco **Cat8000v** | Cisco **Cat9000v** | Cisco **Cat9000v** (L2 mode) | Win 11 VM |
| **Helix Health Analytics** | Regulated industry (healthcare, Privacy Act / My Health Records). Cisco at the carrier demarc, HPE Aruba inside the LAN — a common pattern because Aruba's dot1x + ClearPass NAC story sells well in healthcare and education. | Cisco **Cat8000v** | HPE **Aruba CX** | HPE **Aruba CX** | macOS VM |
| **Northwind Robotics** | Modern, cloud-native, born-in-DevOps. Juniper at the edge because the ops team is comfortable with Junos and YAML-based config management. Cisco LAN inherited from an older site or acquisition. | Juniper **cRPD** | Cisco **Cat9000v** | Cisco **Cat9000v** | Linux dev VM |

### 14.2 What each pairing demonstrates

- **Cisco fluency.** Cat8000v at Maple Ridge + Helix Health edge, Cat9000v across both Maple Ridge and Northwind LAN. IOS XE CLI exposure at both routing and switching layers — directly relevant for Cisco-shop Australian enterprises.
- **Multi-vendor LAN competence.** Aruba CX (AOS-CX) at Helix Health LAN. ArubaOS-CX command structure differs from Cisco IOS XE — demonstrates ability to operate non-Cisco LAN environments without retraining.
- **Carrier-grade routing in the customer edge.** Juniper cRPD at Northwind. cRPD runs the same routing protocols (BGP, IS-IS, OSPF, MPLS) as Juniper's carrier gear (vMX, MX series) — the lightest of the routing containers (~500 MB) and the closest in-container approximation of real Junos behaviour. **(Superseded — ADR-003, 2026-06-14: in the built lab, Northwind CE in Region A is FortiGate; the Juniper presence — vSRX + vJunos — lives in Region B (CML), and cRPD is the Region C cloud-edge routing node. The "Junos in a container" intent is preserved, relocated off the Region A customer edge.)**
- **Realistic Australian patterns.** Pure Cisco, mixed Cisco+Aruba, mixed Juniper+Cisco — the three pairings cover the dominant enterprise configurations observable in AU customer environments today.

### 14.3 PE-CE protocol per tenant

Tenants share the carrier PE-CE protocol choice from `BACKLOG.md` Sprint W2 (OSPF) but vary by their internal LAN routing:

| Tenant | PE-CE protocol | LAN protocol |
| --- | --- | --- |
| Maple Ridge | OSPF area 0 from CE to Aurora PE; redistribute connected LANs | EIGRP between Cat8000v and Cat9000v (Cisco-only stack supports it) |
| Helix Health | OSPF area 0 from CE to Aurora PE | OSPF on Aruba CX LAN; redistribute mutually with Cisco CE at the demarcation |
| Northwind | eBGP from Juniper cRPD CE to Aurora PE (demonstrates eBGP-CE pattern alongside Maple Ridge/Helix OSPF-CE pattern) | OSPF area 0 between cRPD and Cisco Cat9000v |

This variety means a single interview demo can showcase OSPF/E1/E2 redistribution, EIGRP, OSPF-to-BGP redistribution, and eBGP CE-PE — without contriving the use cases.

### 14.4 vrnetlab wrappers required (Sprint W4)

| Image | Container source | Wrapper needed? | Build time |
| --- | --- | --- | --- |
| Juniper cRPD | `crpd:latest` from HPE Juniper Networking registry (post-acquisition; see §14.5) | No — native container | n/a |
| Cisco IOS XRd | `ios-xr/xrd-control-plane`, `ios-xr/xrd-vrouter` from Cisco software download (CCO required) | No — native container | n/a |
| Cisco Cat8000v | qcow2 from Cisco Software Download (`https://software.cisco.com/download/home`, CCO required) | Yes — `vrnetlab/cat8000v` | ~30 min |
| Cisco Cat9000v | qcow2 from Cisco Software Download | Yes — `vrnetlab/cat9000v` | ~30 min |
| HPE Aruba CX | qcow2 from HPE Networking Software Downloads (`https://networkingsupport.hpe.com`, HPE Passport login required) | Yes — `vrnetlab/aoscx` | ~30 min |

### 14.5 HPE-Juniper consolidation — May 2026 industry context

**HPE acquired Juniper Networks in early 2025.** The two product lines have since been consolidated under HPE Networking:

- **HPE Aruba Networking** — formerly Aruba Networks (independent vendor, then HPE business unit, now HPE Networking division). Owns AOS-CX switching, AOS 8 wireless, ClearPass Policy Manager, Central cloud management.
- **HPE Juniper Networking** — formerly Juniper Networks (independent vendor). Owns Junos OS, MX/PTX/EX/QFX/SRX platforms, cRPD, Apstra fabric automation, Mist AI for wireless.

**Documentation evidence verified May 2026:**
- Single developer hub at `https://devhub.arubanetworks.com/` serves both HPE Aruba Networking and HPE Juniper Networking products.
- Get-started page lists AOS-CX, AOS 8, **and Junos** under "Switching Platforms".
- Airheads Community migrated from `community.arubanetworks.com` to `https://airheads.hpe.com/` — both vendor communities now reachable through HPE-branded portal.
- Code Exchange filters by `?product=aruba` and `?product=juniper` from the same hub.
- Separate legacy `https://community.juniper.net/home` still exists during the transition.

**Implication for §14 per-tenant matrix:**

The product matrix in §14.1 remains valid — Cisco Cat8000v, HPE Aruba CX (AOS-CX), and Juniper cRPD (Junos) are still architecturally distinct technologies with different CLI, different config models (model-driven vs hierarchical), different routing daemon stacks. **They are NOT interchangeable from an operator-skill perspective.** A lab demo featuring Cat8000v at Maple Ridge, AOS-CX at Helix Health LAN, and cRPD at Northwind still demonstrates three distinct technology stacks.

**What changes:**

1. **Vendor account inventory consolidates.** Both HPE Aruba and Juniper now sit behind the same HPE Networking authentication. §15.3 consolidates these two rows into a single "HPE Networking" entry.
2. **The "three-vendor multi-vendor lab" narrative becomes "two-vendor (Cisco + HPE) multi-product lab."** The vendor count drops from three to two; the technology count stays at four (Cisco IOS XE, Cisco IOS XR, Junos, AOS-CX).
3. **Interview-narrative framing.** A Monday Cisco SP interviewer or Tuesday IT Ops interviewer in mid-2026 will recognise the HPE-Juniper consolidation as recent industry context. The defensible line is: "I structured the lab with Cisco against HPE — since HPE acquired Juniper in 2025, the realistic Australian enterprise vendor mix has consolidated."

**No topology changes required.** The per-tenant CE/LAN matrix in §14.1 is technology-accurate. Only the vendor-account inventory in §15.3 and the vendor-strategy framing in §15.1 are updated.

## 15. Vendor strategy

### 15.1 Cisco-first with HPE Networking as the second-vendor demonstrator

Sentinel Ridge MSP's primary customer base is Cisco-credentialed Australian enterprises. Cisco is therefore the default vendor at three points in the lab:

- The carrier PE (Cisco IOS XRd) — already in W3 backlog
- The dominant tenant CE (Cisco Cat8000v at Maple Ridge and Helix Health)
- The dominant LAN switching (Cisco Cat9000v at Maple Ridge and Northwind)

**Second-vendor demonstrator: HPE Networking.** Following the 2025 HPE-Juniper acquisition (see §14.5), HPE Aruba Networking and HPE Juniper Networking are now both divisions of HPE Networking. Two HPE products appear in specific tenants where the pairing matches a realistic Australian customer profile:

- **HPE Aruba CX (AOS-CX)** at Helix Health LAN — healthcare and education in AU often run Aruba LAN behind a Cisco WAN edge. The dot1x + ClearPass NAC integration story is strong in regulated industries.
- **HPE Juniper cRPD (Junos)** at Northwind edge — modern tech companies prefer Junos for its YANG/JSON-friendly config model and Apstra intent-based fabric automation. cRPD is the lightest of the routing containers.

Although these two products are now under a single vendor, they remain architecturally distinct technologies with different CLI, config models, and operator skill requirements. The lab's multi-vendor narrative shifts from "three independent vendors" to "two vendors (Cisco + HPE) representing four distinct technology stacks (Cisco IOS XE, Cisco IOS XR, Junos, AOS-CX)."

Nokia SR Linux is retained at one Aurora PE per the existing `BACKLOG.md` W3 plan — for SP-side multi-vendor interop, not customer-side. Nokia remains an independent vendor (no consolidation event).

### 15.2 Rejected — GNS3 and EVE-NG

GNS3 and EVE-NG provide graphical lab orchestration with broader image support (including legacy Cisco IOSv that has no container form). This ADR explicitly rejects both for the following reasons:

| Concern | GNS3 / EVE-NG | containerlab |
| --- | --- | --- |
| Deployment model | Graphical, point-and-click | YAML topology file, `containerlab deploy` |
| Source of truth | UI state stored in `.gns3project` files | Git-tracked YAML |
| CI / automation | Limited | Native — same `containerlab deploy` runs in CI |
| Reproducibility | Requires manual screenshot or `.gns3` file commit | Git diff is the entire change set |
| Vendor image support | Broader (includes IOSv, IOL) | Equivalent for modern vendor images via `vrnetlab` |
| Resource overhead | GNS3 server process + GUI | None beyond Docker |
| Interview alignment with "everything as code" | Weaker | Stronger |

The trade-off is that Cisco IOSv (the historical default for Cisco lab demonstrations) is unavailable as a containerlab node. The architecture accepts this loss because IOSv is a 2015-era image that does not represent current Cisco SP gear; Cat8000v and IOS XRd are more relevant to actual present-day Cisco environments.

### 15.3 Vendor account inventory

| Vendor | Account type | Portal | Cost | Approval time | Used for | On-disk image already available? |
| --- | --- | --- | --- | --- | --- | --- |
| Cisco | CCO + DevNet (free); **separate service contract required for current product downloads** | `id.cisco.com` (CCO), `developer.cisco.com/site/sandbox/` (DevNet), `software.cisco.com/download/home` (image downloads — contract-gated for current products) | Free for CCO + DevNet Sandbox; **service contract required for Cat8000v/Cat9000v/ASAv qcow2 downloads (paid)** | Immediate for CCO/DevNet; contract acquisition via Cisco direct purchase or partner reseller | DevNet Sandbox hosted access (free, no contract); current Cat8000v/Cat9000v/ASAv qcow2 downloads (paid contract) | **Partial — CSR1000v 16.8, IOS XRv 6.1.3, IOSv 15.7, IOSv-L2 15.2 already on disk and sufficient for protocol demos. Current version (Cat8000v 17.x, XRd 7.x, current ASAv) downloads blocked by service contract gate for non-partner users. Workaround: DevNet Sandbox hosted access (no download, free) or embedded CML inside reservation sandboxes — see §15.4.** |
| HPE Networking (post-Juniper acquisition; covers BOTH AOS-CX and Junos cRPD) | HPE Passport | Developer hub: `devhub.arubanetworks.com`; Community: `airheads.hpe.com`; Software downloads: `networkingsupport.hpe.com`; Training/cert: `arubanetworks.com/support-services/training-services/` | Free | Immediate after email verification | Aruba CX simulator, Junos cRPD container, Apstra documentation, Mist documentation, ClearPass | No — must download from HPE Networking Software Downloads after authentication |
| Fortinet | FortiCare | `support.fortinet.com`; Free Trials at `fortinet.com/support/product-downloads?tab=trials` (verified May 2026 fetch) | Free (15-day eval) | Immediate | FortiGate-VM for Helix Health perimeter NGFW (Sprint W4 deployment); KVM hypervisor officially supported | **Yes — `fortios.qcow2` (~73 MB compressed, 2 GB virtual, FortiOS 7.0.14 placeholder pending first boot version verification) already on disk in workspace folder. `vrnetlab/vr-fortios:7.0.14` Docker image built May 31 2026 via `cd ~/vrnetlab/fortinet/fortigate && sudo make`. Runs in eval mode without external license file (~1 Mbps throughput cap; control plane and security features fully functional for lab demos)** |
| Palo Alto Networks | Live community | `live.paloaltonetworks.com` | Free trial | 1-3 days approval | PA VM-Series (Maple Ridge W4 deployment) | No |
| Nokia | Lab access via SRC program | Learning hub: `nokia.com/learning/`; SRC: `nokia.com/networks/training/src/`; My SR Learning Labs: `nokia.com/networks/training/src/mysrlab`; Learning Store: `learningstore.nokia.com` | Paid (~$1,500-3,000 USD per course track with My SR Learning Labs included); $125 USD NRS I exam alone | Variable per program | Current SR OS access; SR Linux is publicly free (no Nokia account needed, see §15.5) | **Yes — SR OS 13.0 R4 already on disk with 2015 demo license (see §10 constraint #12); SR Linux pulled May 31 2026 via `docker pull ghcr.io/nokia/srlinux:24.10.1` and `:latest` (~3.1 GB image, ~1-1.5 GB RAM at runtime, native container — no vrnetlab wrapper needed, kind `nokia_srlinux` in containerlab YAML)** |
| MikroTik | n/a | `mikrotik.com/download` | Free | n/a | RouterOS CHR | **Yes — CHR 6.41.4 already on disk; free up to 1 Mbps per interface, no registration needed** |

**Effective Sunday-morning registration burden after on-disk image inventory and the HPE consolidation:** HPE Passport (10 min, instant) provides access to both AOS-CX and Junos cRPD. Cisco CCO + DevNet (10 min, instant) for current-version Cisco images and Sandbox access. Total: two vendor accounts, ~20 minutes of registration work. Fortinet and Palo Alto remain Sprint W4 prerequisites, not blocking immediate lab work.

### 15.4 Throughput-test topology separation pattern

Several of the on-disk and legacy lab images carry throughput caps as part of their unlicensed-eval operating mode:

| Image | Eval throughput cap | Control-plane functional? |
| --- | --- | --- |
| Cisco CSR1000v 16.8 | ~250 Kbps forwarding | Yes — BGP, OSPF, IS-IS, MPLS, L3VPN all work at full feature level |
| Cisco IOS XRv 6.1.3 (demo) | No data-plane cap but 60-day timer (resets on redeploy) | Yes |
| Cisco IOSv 15.7 / IOSv-L2 | No hard cap (lightweight emulation, naturally rate-limited) | Yes |
| Nokia SR OS 13.0 R4 (RTC-frozen license) | No cap when license is valid via RTC trick | Yes |
| MikroTik CHR 6.41.4 (free tier) | 1 Mbps per interface | Yes |
| FRR / VyOS / Cumulus VX | Uncapped (open source) | Yes |

The caps do not impede protocol-demo work — control-plane operations consume <10 Kbps per session and demonstrating IS-IS, BGP, MPLS, L3VPN, OSPF redistribution can all complete without exceeding 250 Kbps. **The architectural problem only emerges for explicit data-plane validation: iperf3 at production rates, TRex traffic generation for SLA testing, MPLS forwarding-plane throughput characterization.**

The lab addresses this by maintaining **two topology variants per tenant** where data-plane validation matters:

#### Demo path topology

Uses vendor-licensed images at the customer edge and LAN for CLI credibility. Throughput cap is invisible because demo traffic is control-plane and low-rate verification only.

| Tenant | Demo path |
| --- | --- |
| Maple Ridge | CSR1000v CE + IOSv-L2 LAN core/access + Win 11 VM |
| Helix Health | CSR1000v CE + HPE Aruba CX LAN core/access + macOS VM |
| Northwind | Juniper cRPD CE + IOSv-L2 LAN + Linux VM |

Topology file: `tenants/<tenant>/clab-<tenant>-demo.yml`

#### Performance-test path topology

Substitutes uncapped open-source routers at the throughput-critical hops. Same protocols, same Aurora PE attachment, same Ansible templates (kind-aware Jinja2 renders FRR or VyOS syntax instead of IOS XE).

| Tenant | Performance-test path |
| --- | --- |
| Maple Ridge | FRR CE + SONiC LAN + Win 11 VM (or TRex traffic generator container) |
| Helix Health | FRR CE + SONiC LAN + Linux iperf3 client |
| Northwind | FRR CE + Cumulus VX LAN + Linux iperf3 client |

Topology file: `tenants/<tenant>/clab-<tenant>-perftest.yml`

#### TRex as the SP-credible traffic generator

Cisco's TRex (Stateful and Stateless Traffic Generator, https://trex-tgn.cisco.com) is the canonical open-source SP test tool. It runs as a containerlab node and injects traffic directly into Aurora PE interfaces, bypassing any CE-side throughput cap. Capabilities relevant to the lab:

| TRex capability | Lab use |
| --- | --- |
| Stateless mode up to 200 Gbps per port (NIC-dependent) | Capped by WSL2 substrate ceiling rather than TRex itself |
| BFD timer validation | Confirm BFD sub-second detection at scale |
| MPLS label-stack tests | Validate PHP behavior, label push/swap/pop under load |
| TCP session emulation at scale | L7 simulation when needed |

TRex's inclusion strengthens the interview narrative: "I use Cisco's TRex for data-plane validation, separating it from the vendor-licensed devices used in protocol-demo paths." This is unambiguously Cisco-credible.

#### Physical substrate ceiling

Even with all caps removed, the WSL2 + home-hardware substrate limits realistic throughput:

| Path | Realistic max throughput |
| --- | --- |
| Single-host containerlab on PC1 Ryzen 7 2700, two FRR containers, single hop | 5-10 Gbps |
| Cross-host containerlab over PC1↔Dell home gigabit LAN with GRE | ~700 Mbps |
| Containerlab through 3+ hops in WSL2 | 1-3 Gbps |
| Dell i5-6300U as transit | ~1-2 Gbps before CPU saturation |

**The lab's effective ceiling for any throughput test is ~5 Gbps single-host, ~700 Mbps cross-host.** This is the constraint to plan against. Anything beyond requires Cisco DevNet Sandbox (which runs in Cisco-hosted infrastructure with no equivalent ceiling) — see §17.

#### Control-plane scale testing

For BGP table scale, OSPF LSDB scale, VPNv4 route count — none of which require data-plane throughput — the lab uses dedicated tooling that injects via control-plane sessions:

| Tool | Use case | Throughput needed |
| --- | --- | --- |
| ExaBGP (container) | Inject up to 1M BGP routes into an Aurora PE | <1 Mbps |
| GoBGP scale-out | Same | <1 Mbps |
| BGPerf | Benchmark BGP convergence time at scale | <1 Mbps |

These run inside the existing demo topology — no perftest substitution needed — because they target the control plane only. The CSR1000v 250 Kbps cap is irrelevant.

### 15.5 Nokia SR Linux — publicly free, no account required

Nokia distributes the SR Linux container image publicly on GitHub Container Registry under a free-to-use license for non-production purposes:

```
docker pull ghcr.io/nokia/srlinux:latest
```

No Nokia account, no login, no license file, no time limit. SR Linux is **not** behind the SRC training paywall — that paywall applies only to current SR OS classic (TiMOS) lab access via My SR Learning Labs (§15.3 Nokia row).

The architectural implication: a Nokia presence in the lab is essentially free. The §14 carrier multi-vendor backbone using SR Linux for one PE costs no vendor-account effort.

### 15.6 URL and access verification disclaimer

The URLs in §15.3, §17, and §18 were verified May 2026 by direct HTTPS fetch against vendor portals. The verification effort confirmed:

- **Top-level portal entry points are real and reachable.** Nokia learning hub, Cisco DevNet sandbox launcher, HPE Aruba Networking developer hub, Airheads community migration to `airheads.hpe.com` all returned valid responses.
- **Deep links beyond authentication are NOT independently verifiable.** Specifically: the exact AOS-CX simulator download URL inside `networkingsupport.hpe.com`, the exact Junos cRPD trial URL inside the HPE developer hub, the exact Cisco XRd container path inside `software.cisco.com`, and the exact ASAv qcow2 path are all behind login walls. The portal entry points are listed; the post-authentication paths will surface dynamically when the operator navigates with valid credentials.
- **Vendor portals change.** The HPE-Juniper consolidation (§14.5) is itself an example: pre-2025 documentation that referenced `juniper.net/dm/crpd-trial.html` is now outdated as HPE migrates URLs. URLs in this ADR were correct at May 2026 and may drift over the lab's operational lifetime; cross-reference vendor documentation at access time rather than relying on this ADR alone for deep download paths.

The verification record itself is preserved in commit history of this file — each ADR version's URL set represents the verified state at commit date.

## 17. Cisco DevNet Sandbox as external inter-AS peer carrier

The local containerlab Aurora carrier represents the AS65100 hosted MSP infrastructure. For demonstrations and validation that benefit from "real currently-licensed Cisco gear under production-rate load," the lab integrates with Cisco DevNet Sandbox (devnetsandbox.cisco.com) as a hosted external network.

### 17.1 What DevNet provides

Cisco hosts a pool of cloud-virtualised current-version Cisco devices accessible via AnyConnect VPN (reservation sandboxes) or public SSH (always-on sandboxes). DevNet is **complementary** to the local lab — it does not replace any local node, but extends the reach of demonstrations.

| Sandbox | Access model | Use in this architecture |
| --- | --- | --- |
| IOS XR (XRv9k or XRd 7.x) | Reservable, 1-4 hour slots | Peer carrier IOS XR at AS65200, eBGP with Aurora over GRE/IPsec |
| IOS XE on Catalyst 8000v 17.x | Always-on | Current Cat8000v CLI demos when on-disk CSR1000v 16.8 isn't current enough |
| NX-OS on Nexus 9000v 10.x | Reservable | Datacenter switch demos for Helix Health |
| SD-WAN (vManage + vSmart + vBond + cEdge) | Reservable | Modern WAN architecture contrast with classic L3VPN |
| Meraki Dashboard | Always-on, API-only | Cloud-managed networking API automation |
| Catalyst Center | Reservable | Intent-based networking demonstrations |

### 17.2 Integration patterns

| Pattern | Description | Effort |
| --- | --- | --- |
| **A — Plain SSH access** | VPN in, SSH to provided IPs, treat as separate environment | Lowest |
| **B — Ansible inventory inclusion** | Add `devnet` group to `automation/inventory/hosts.yml`, run existing playbooks against DevNet devices once VPN is up | Medium — extends existing NetDevOps story |
| **C — Inter-AS eBGP via GRE tunnel** | Establish GRE/IPsec tunnel from PC1 WSL containerlab to DevNet IOS XR, eBGP across the tunnel between Aurora AS65100 and DevNet "peer carrier" AS65200 | Highest — but produces the strongest interview demo |
| **D — API automation showcase** | Meraki / Catalyst Center API integration from Wazuh playbooks or Ansible | Independent track, complements but doesn't depend on the carrier topology |

Pattern C is the interview-credible "carrier peering with real current Cisco production code" demonstration. It demonstrates eBGP-multihop, GRE-over-IP, IPsec optionality, BGP attribute propagation across an AS boundary — all things a Cisco SP Pre-Sales engineer is expected to discuss fluently.

### 17.3 Operational constraints

| Constraint | Mitigation |
| --- | --- |
| AnyConnect VPN single-device concurrency (one device per sandbox session) | Cannot VPN from both PC1 and Dell simultaneously; choose one as the integration point |
| Reservation slot expiry wipes device state | Save running-config to a git-tracked file before slot ends; reload on next reservation |
| Always-on sandboxes are shared with other DevNet users | Defensive `show running-config` at start of session, treat state as untrusted |
| Latency from Australia to Cisco US-West/EU hosting | 150-250 ms — fine for CLI, slow for GUI screen-share demos |
| Sandbox availability | High-demand sandboxes (IOS XR) may have busy periods; reserve ahead |

### 17.4 Throughput beyond the local substrate ceiling

§15.4 noted the WSL2 + home-hardware ceiling of ~5 Gbps single-host and ~700 Mbps cross-host. **For data-plane tests beyond that ceiling, DevNet sandbox devices have Cisco-hosting-grade bandwidth** — they're not constrained by the operator's home network. Running TRex against DevNet IOS XR over the eBGP-over-GRE link from Pattern C demonstrates SP-grade forwarding at rates impossible to achieve locally, while still tying back into the operator's own automation tooling.

### 17.5 Sunday prerequisites

| Task | URL | Time |
| --- | --- | --- |
| Register CCO account | `https://id.cisco.com` | 10 min |
| Register at DevNet Sandbox | `https://developer.cisco.com/site/sandbox/` (entry portal) → launcher at `https://devnetsandbox.cisco.com/` | 5 min |
| Install **Cisco Secure Client** (Windows) — formerly known as AnyConnect, version 5+; OR `openconnect` (WSL Ubuntu) for the OSS path | Cisco Secure Client at `https://software.cisco.com/download/home/283000185` | 10 min |
| SSH-test an Always-On sandbox (Catalyst 8000v or IOS XE) to verify account access | Sandbox catalog at `https://developer.cisco.com/sandbox` | 15 min |
| Reserve an IOS XR sandbox slot for Monday 3-7 PM (before EIL Global interview) | From the sandbox catalog | 5 min |
| Read DevNet Sandbox technical documentation for sandbox usage patterns | `https://developer.cisco.com/docs/sandbox/` | 10 min |
| Document VPN connection workflow in `docs/runbook.md` §13 | n/a | 10 min |

**Naming note: AnyConnect → Cisco Secure Client.** Cisco renamed the AnyConnect Secure Mobility Client to Cisco Secure Client (CSC) with version 5 in 2023. The functionality is identical for sandbox VPN connectivity; the name change is the relevant operator-facing difference. Some documentation still references AnyConnect; both names point to the same product.

DevNet integration is treated as a Sprint W4-equivalent enhancement: not required for the W1-W3 carrier core but high-value once the carrier is otherwise stable.

### 17.6 Empirical validation — May 31 2026

The patterns described in §17.2 were validated against the actual Cisco SD-WAN 20.12 Reservation sandbox. Methodology and results below; this section is the canonical reference for the architecture's DevNet integration claims rather than the aspirational pattern descriptions in earlier versions of this ADR.

**Test environment:**

- Local lab: WSL2 Ubuntu on PC1 (Ryzen 7 2700), `openconnect 9.x` package, containerlab `0.x`, Docker 29.4.3 with default bridge networking and `iptables -t nat MASQUERADE` rules in effect for the Docker bridge subnet
- Target: Cisco SD-WAN 20.12 Reservation sandbox at `devnetsandbox-usw1-reservation.cisco.com:20134`
- VPN tunnel: `openconnect` established `tun0` inside WSL2 with VPN-assigned address `192.168.254.11/32` and 8 advertised subnets (`10.10.20.0/24`, `10.10.21.0/24`, `10.10.22.0/24`, `10.10.23.0/24`, `10.10.24.0/24`, `10.17.248.0/24`, `172.16.30.0/24`, `192.168.254.0/24`)
- Probe container: `nicolaka/netshoot:latest` in containerlab kind `linux`, bridged on `clab-devnet-reach-test` Docker network (`172.20.20.0/24`)

**Phase verdicts:**

| Phase | Test | Result |
| --- | --- | --- |
| 3 — VPN | `openconnect` from WSL2 Ubuntu | ✓ `tun0` interface up, 8 subnets routed |
| 4 — Host-to-DevNet ping | WSL2 host → `{devbox, CML, vManage, vSmart, vBond}` | ✓ All 5 control plane devices reachable |
| 5 — SSH | `ssh developer@10.10.20.50` | ✓ Connected, `hostname` returned `devbox` |
| 6a — Container-to-DevNet ping | clab probe (172.20.20.2) → `{10.10.20.50, .161, .90}` | ✓ All reachable via host MASQUERADE through `tun0` |
| 6b — Container HTTPS API | clab probe → `https://10.10.20.161/` (CML web) | ✓ `HTTP 200` |
| 7 — eBGP peering | Attempted against multiple device classes | ✗ Not viable against SD-WAN sandbox — see below |

**Pattern verdicts** (from §17.2, now empirically grounded):

| Pattern | Description | Verdict | Evidence |
| --- | --- | --- | --- |
| A | SSH to sandbox devices from WSL2 | **VERIFIED** | Phase 5 |
| B | Ansible inventory targeting both local + DevNet | **VERIFIED IN PRINCIPLE** (works identically to Pattern A from SSH perspective) | Phase 5 |
| C-L3 | Containerlab containers reach DevNet IPs | **VERIFIED** | Phase 6a |
| C-L7 | Containerlab containers reach DevNet HTTPS APIs | **VERIFIED** | Phase 6b |
| C-BGP | Containerlab FRR establishes eBGP with DevNet device | **NOT VIABLE against SD-WAN sandbox**; viable in principle against IOS XR Reservation sandbox or embedded CML | Phase 7 finding |
| D | REST API automation from local Python/Ansible against DevNet APIs | **VERIFIED** (curl 200 in Phase 6b is the same transport class) | Phase 6b |

**Phase 7 architectural finding — SD-WAN sandbox is BGP-free by design:**

| Device class | Routing protocol observed | Implication |
| --- | --- | --- |
| SD-WAN cEdge (e.g., Site1-cEdge01 at 10.10.20.174) | `router omp` — OMP toward vSmart Controller; no `router bgp` | Cannot accept arbitrary external BGP peers without breaking SD-WAN |
| DC-WAN-Edge01 (10.10.20.173, telnet, IOS XE 17.3.6) | `Routing Protocol is "application"` (Cisco SD-Routing); `% BGP not active` | Cisco SD-Routing model — no traditional BGP for external peering |
| SD-Routing branches (Site11/12 at 10.10.23.54/.58) | Untested — `10.10.23.0/24` advertised in tun0 routes but L3 not provisioned during reservation | Cisco selectively provisions topology slots per reservation; this subnet was inactive |

**Architecturally**, the Cisco SD-WAN 20.12 sandbox is a purposeful demonstration of Cisco's overlay management model. OMP and Application Routing replace traditional BGP/MPLS for SD-WAN customer demos. **For traditional eBGP/L3VPN demonstrations, this sandbox is the wrong target**; the right targets are:

- Cisco IOS XR Reservation sandbox (traditional IOS XR routing — `router bgp`, IS-IS, OSPF, MPLS, L3VPN)
- The CML server embedded inside the SD-WAN sandbox at `https://10.10.20.161` — build a controlled topology with IOS XR or Cat8000v nodes and configure BGP as needed

This is not a deficiency of the sandbox — it is correctly scoped to its purpose. The architecture documents this so future operators don't repeat the test against the wrong target.

### 17.7 WSL2 networking architecture for DevNet VPN

The validated VPN pattern is `openconnect` installed inside Ubuntu WSL2, NOT Cisco Secure Client running on the Windows host. Both patterns are technically possible but the routing implications differ materially.

**Validated pattern — openconnect inside WSL2:**

```
PC1 Windows host
  └── WSL2 Ubuntu (network namespace)
        ├── eth0 (NAT to host, default for outbound)
        ├── tun0 (openconnect VPN, 192.168.254.11/32 + 8 DevNet subnets)
        └── containerlab Docker bridges (172.20.x.x/24)
              └── containers route via WSL2 default + iptables NAT MASQUERADE
                    → source IP rewritten to host's tun0 address before VPN encap
```

In this pattern, `tun0` lives in WSL2's routing namespace, and Docker's default outbound NAT translates container source addresses to the WSL2 host's tun0 IP. DevNet devices see traffic originating from the tunnel-assigned IP and reply normally.

**Not-validated pattern — Cisco Secure Client on Windows host:**

```
PC1 Windows host
  ├── Cisco Secure Client (AnyConnect v5+) virtual adapter
  │     └── routes only Windows-host applications by default
  └── WSL2 Ubuntu
        └── containers route via WSL2 NAT to Hyper-V virtual switch
              → traffic exits via Windows default route, NOT through Secure Client tunnel
```

In this pattern, the Windows VPN client does not by default advertise its routes to WSL2's routing table. WSL2 + Docker traffic egresses via the Hyper-V virtual switch through Windows' default internet route, bypassing the VPN. Without additional configuration (Windows mirrored networking mode, manual route additions, or Windows-side port-proxying), Pattern C-L3 fails because the container's outbound packets never enter the Secure Client tunnel.

**Operational implication for ADR-001:**

The validated WSL2+openconnect pattern is the canonical DevNet integration architecture. Cisco Secure Client on Windows remains an option for human-operator interactive sessions (where the operator's browser/SSH client runs on Windows directly), but is not part of the automation-bridge architecture for containerlab Aurora.

## 18. References

### Internal repo references

- `BACKLOG.md` — sprint-by-sprint task list reflecting this architecture
- `docs/design.md` — protocol-level design decisions for Aurora
- `docs/ip-plan.md` — IP addressing and BGP AS plan
- `docs/runbook.md` — operational diagnostic procedures
- `_setup/dell/README.md` — Dell-side deployment instructions
- Sentinel Ridge MSP repo `_docs/Sentinel_Ridge_Lab_Design.docx` — master design document

### External tooling

- `hellt/vrnetlab` (GitHub) — wraps vendor qcow2 images as containerlab nodes
- Cisco TRex (`https://trex-tgn.cisco.com`) — open-source SP traffic generator used for data-plane validation in performance-test topologies (§15.4)

### Vendor portal entry points (verified May 2026)

| Vendor | Portal | Purpose |
| --- | --- | --- |
| Cisco DevNet | `https://developer.cisco.com/site/sandbox/` | Sandbox info |
| Cisco DevNet | `https://devnetsandbox.cisco.com/` | Sandbox launcher (Torque) |
| Cisco DevNet | `https://developer.cisco.com/docs/sandbox/` | Sandbox technical documentation |
| Cisco DevNet | `https://developer.cisco.com/sandbox` | Sandbox catalog browser |
| Cisco | `https://software.cisco.com/download/home` | Software download portal (CCO login required) |
| Cisco Secure Client | `https://software.cisco.com/download/home/283000185` | VPN client (formerly AnyConnect, see §17.5) |
| HPE Aruba Networking | `https://devhub.arubanetworks.com/` | Developer hub — serves both HPE Aruba AND HPE Juniper post-2025 acquisition (§14.5) |
| HPE Aruba Networking | `https://devhub.arubanetworks.com/get-started/home` | API guides for AOS-CX, AOS 8, Junos, Mist, Apstra, Paragon, ClearPass, EdgeConnect |
| HPE Aruba Networking | `https://airheads.hpe.com/` | Airheads community (migrated from community.arubanetworks.com) |
| HPE Networking | `https://networkingsupport.hpe.com` | Software downloads (HPE Passport login required) |
| HPE Aruba Networking | `https://www.arubanetworks.com/support-services/training-services/` | Training and certification |
| Nokia | `https://www.nokia.com/learning/` | Learning hub |
| Nokia | `https://www.nokia.com/networks/training/src/` | Service Routing Certification Program |
| Nokia | `https://www.nokia.com/networks/training/src/mysrlab` | My SR Learning Labs (24/7 SR OS lab access) |
| Nokia | `https://learningstore.nokia.com/` | Course and exam purchase |
| Nokia | `ghcr.io/nokia/srlinux:latest` | SR Linux container (free, no account; see §15.5) |
| MikroTik | `https://mikrotik.com/download` | RouterOS CHR (free tier capped at 1 Mbps) |
| Fortinet | `https://support.fortinet.com` | FortiCare (W4 prerequisite) |
| Palo Alto Networks | `https://live.paloaltonetworks.com` | Live community trial (W4 prerequisite) |

### Industry context references

- HPE-Juniper acquisition (2025) — see §14.5 for impact on vendor strategy
