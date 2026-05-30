# Aurora & Sentinel Ridge — Lab Architecture (ADR-001)

| Field | Value |
| --- | --- |
| Status | Accepted |
| Version | 1.2 |
| Date | May 2026 |
| Decision | Hybrid workload distribution — CPU-intensive services on PC1, lightweight services + carrier backbone on Dell |
| Owner | Lab architecture (Elvis Ifeanyi Nwosu) |
| Supersedes | n/a (initial) |
| Related | `docs/design.md`, `docs/ip-plan.md`, `BACKLOG.md` |

## Revision history

| Version | Date | Change |
| --- | --- | --- |
| 1.0 | May 2026 | Initial decision: Option C hybrid workload distribution |
| 1.1 | May 2026 | Added Cowork agent (~3 GB) to PC1 always-on accounting; tightened active-lab pool from 11 GB to 8 GB and revised sprint feasibility; fixed WSL2 memory cap to 12 GB in migration plan |
| 1.2 | May 2026 | Phase 1 audit reconciliation: Docker Desktop (~2 GB) retained on PC1 to host pre-existing personal stacks (job-radar, openwebui, freshrss, rsshub); active-lab pool tightened from 8 GB to 6 GB; Tailscale measured as already deployed across `forty3s-pc1/pc2/pc3` with magic DNS; native Docker in WSL Ubuntu coexists with Docker Desktop, isolated to lab workloads; Docker data-root relocated to D:\ to handle 35 GB C: drive free constraint |

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

## 14. References

- `BACKLOG.md` — sprint-by-sprint task list reflecting this architecture
- `docs/design.md` — protocol-level design decisions for Aurora
- `docs/ip-plan.md` — IP addressing and BGP AS plan
- `docs/runbook.md` — operational diagnostic procedures
- `_setup/dell/README.md` — Dell-side deployment instructions
- Sentinel Ridge MSP repo `_docs/Sentinel_Ridge_Lab_Design.docx` — master design document
