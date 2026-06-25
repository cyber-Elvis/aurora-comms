# ADR-003 — Re-vendor Region A to Cisco; Juniper to Region B; three-region model with a cloud edge

| Field | Value |
| --- | --- |
| Status | Accepted |
| Version | 1.5 |
| Date | 2026-06-15 |
| Supersedes (in part) | ADR-002 §3.1 — the Region A *vendor stack* (Nokia SR Linux + SR OS core). The two-region *structure*, VPN boundary, tenant model, and Dell capability envelope in ADR-002 still stand. |
| Relates | ADR-001 (lab-architecture.md), ADR-002 (two-region), ADR-004 (secure rings and host isolation), `region-a-plan.md` v2.5, `telstra-ops-practice-plan.md` |
| Driver | Telstra TechOps contract (Protect & Secure towers) — see `memory/telstra-techops-role.md` |
| Owner | Lab architecture (Elvis Ifeanyi Nwosu) |

## 1. Context

Two things changed after ADR-002:

1. **A real-world driver landed.** A Telstra TechOps Technical Specialist contract (via Infosys) on the **Protect** and **Secure** towers — heavy **Cisco** routing & switching, **Juniper**, and **firewalls** (Fortinet / Palo Alto / Zscaler / Cisco security), with a strong **software-patching/upgrade-as-security** discipline. The lab's job is now to be the **hands-on practice rig** for that role. The focus the user named: **network + security operations**, Cisco- and Juniper-led.

2. **The Dell's nesting ceiling is now empirically mapped.** The Dell GNS3 VM is **triple-nested** (VMware Workstation → GNS3-VM-KVM → guest). Confirmed walls:
   - **Nexus 9300v** won't boot (vCPU spins, kernel never loads) — `memory/nexus9300v-wont-boot-nested.md`.
   - **vJunos-router won't run**: it boots its Wind River Linux host, then the **inner Junos VM can't start** and the orchestrator powers off cleanly (no host KVM error). Same nested-virt class, graceful failure — `memory/gns3-nos-boot-quirks.md`.
   - cEOS / IOL have environment limits already documented in ADR-002 §3.9.

Nokia SR OS was the Region A core (licensed 13.0R4, hard-won via the RTC trick). But (a) it doesn't match the Cisco/Juniper role, and (b) the role is now the priority. The SR OS license is **irreplaceable**, so it is archived, not deleted.

The user also reframed the sequencing explicitly: **build the network first, then operate it** — "are we not going to build a network first before we dig into operational patching?" Telstra *is* a Tier-1 ISP + enterprise + security shop, so the Aurora build **is** the practice network; they are not two separate things.

## 2. Decision

### 2.0 National POP model retained and expanded
The Cisco re-vendor does **not** remove the Australian carrier geography. **Region A/B/C are deployment domains** (where the lab runs); **Melbourne, Sydney, Brisbane, Geelong, Adelaide, Perth, Darwin, and Tasmania/Hobart are the POP topology** (what the carrier represents).

The active build maps the lightweight Cisco core onto the national POP model. **v1.4 placement correction plus Internet-edge correction:** the permanent Dell/PC2 Region A canvas is drawn geographically as `ADL-PE1 -> GEL-PE1 -> MEL-PE1 -> MEL-P`. `MEL-P` sits on the right as the local core and the right-side **transport handoff** toward PC1 / Region B. **The Region A↔B inter-region border/ASBR is `MEL-PE1`** — it terminates the inter-region eBGP `64496 ↔ 65002` to Region B's `DC-P-R1` (global IPv4-unicast, Option A). `MEL-P` is a pure P router (IS-IS L2 + LDP, no BGP) and is the transport handoff only, *not* the border. Brisbane and Sydney move to Region B CML planning; `SYD-PE1` is a Region B node (it keeps the IOS-XRv VPNv4/ROV/Region B-C edge role there) and is **not** the Region A end of the inter-region boundary. Both simulated upstream transits stay in Region A: Transit-A on `MEL-PE1`, Transit-B on `ADL-PE1`. Docker-dependent FRR/tenant workload nodes can be offloaded to Region B/PC1.

| POP | Active / target role |
| --- | --- |
| Melbourne | `Aurora-P` (`MEL-P`) + `Aurora-PE-1` (`MEL-PE1`); `MEL-PE1` is the **Region A↔B inter-region border/ASBR** (terminates eBGP `64496 ↔ 65002` to Region B `DC-P-R1`), while right-side `MEL-P` is the pure-P **transport handoff only** (IS-IS L2 + LDP, no BGP) |
| Sydney | Region B node `Aurora-PE-3` (`SYD-PE1`) on PC1 / DevNet CML; Region B/C interconnect, first RPKI/ROV enforcer — **not** the Region A end of the A↔B border |
| Brisbane | Region B target `Aurora-PE-2` (`BNE-PE1`), Helix/customer regional edge |
| Geelong | Dell/PC2 Region A `GEL-PE1`, midpoint of the ADL-GEL-MEL-PE1-MEL-P line |
| Adelaide | Dell/PC2 Region A `ADL-PE1`, leftmost endpoint of the ADL-GEL-MEL-PE1-MEL-P line and local Transit-B backup edge |
| Perth | planned Western Australia POP; target `PER-PE1` |
| Darwin | planned northern remote POP; target `DRW-PE1` |
| Tasmania / Hobart | planned island POP; target `HBA-PE1` / `TAS-PE1` |

### 2.1 Region A core re-vendored to Cisco
Region A's P/PE backbone moves from Nokia to Cisco:

| Role | Was | Now |
| --- | --- | --- |
| Aurora-P (IS-IS L2 + LDP, no BGP) | SR Linux 24.10 | **IOL-AdvEnterprise-L3** (light, full MPLS) |
| Aurora-PE-1 (L3VPN PE) | SR OS 13.0R4 | **IOL-AdvEnterprise-L3** (full MPLS L3VPN) |
| GEL-PE1 (regional L3VPN PE) | Geelong placeholder concept | **IOL-AdvEnterprise-L3** (full MPLS L3VPN) |
| ADL-PE1 (regional L3VPN PE) | planned POP | **IOL-AdvEnterprise-L3** (full MPLS L3VPN) |
| Aurora-PE-2 / BNE-PE1 | SR OS 13.0R4 / prior PE-2 concept | **Moved to Region B planning** |
| Aurora-PE-3 / SYD-PE1 (interop PE, ROV enforcer) | IOS-XRv 6.1.3 | **Moved to Region B planning** as IOS-XRv |

**Inter-region border:** `MEL-PE1` (Aurora-PE-1) is the designated Region A↔B border router / ASBR — it terminates the inter-region eBGP `64496 ↔ 65002` to Region B's `DC-P-R1` (Option A, global IPv4-unicast). `MEL-P` (Aurora-P) is a pure P router and is the right-side transport handoff toward PC1 / Region B only, not the BGP border. (Re-platforming a MEL node to an XRv9000 on the Dell GNS3 was evaluated and declined — the 19 GiB / 2-core VM cannot sustain a 16 GB singleton alongside the fabric; `MEL-PE1` stays IOS-XRv 6.1.3.)

IOL-AdvEnterprise-L3 is the standard light MPLS-L3VPN lab platform (~0.5 GB each, runs the whole core together with headroom) and is **resolved/working** on this box. The Internet Edge, Customer Edge, IXP, and RPKI tiers keep their logical roles, with the current placement being: Transit-A and Transit-B local to Region A, and Docker-dependent FRR / workload nodes offloadable to Region B/PC1.

**L3VPN is a first-class requirement.** All chosen PE platforms (IOL-L3, IOS-XRv, CSR1000v) support full MPLS L3VPN (VRF + VPNv4 + label imposition). **IOSv is excluded from PE roles** (weak/flaky MPLS) — it stays a CE-only spare.

### 2.2 Nokia archived, not deleted
SR OS 13.0R4 licensed qcow2 + the RTC/UUID recipe are **cold-stored in three places** (md5 recorded — `memory/sros-gns3-license-recipe.md`); SR Linux is stopped. `region-a-plan.md` keeps a short "archived" note. Nokia can return on a non-triple-nested host (bare-metal KVM / DevNet) if a multivendor-local story is wanted later.

### 2.3 Juniper presence moves to Region B + cloud
- **Region B (DevNet CML)** hosts **vSRX + vJunos** via BYOI — CML runs on real (non-nested) infrastructure, so vJunos's inner VM works there.
- **vJunos does NOT run locally** (triple-nested wall, §1).
- **vSRX runs standalone on the Dell** as the local Junos/SRX-firewall practice box (it is a *direct* Junos VM, no inner nesting — validated booting). Same CLI/ops as vJunos for learning, and doubles as the Juniper **firewall** for the Secure tower.
- **cRPD** (containerized Junos routing daemon) is the **cloud** Juniper routing node — no nesting, runs anywhere.

### 2.4 Three-region model
| Region | Host | Vendors | Status |
| --- | --- | --- | --- |
| **A** | Local Dell GNS3 | **Cisco** ADL-GEL-MEL-PE1-MEL-P IOL-L3 core + local Transit-A/Transit-B + Fortinet/Aruba edge | Permanent, free — the foundation |
| **B** | PC1 / DevNet CML | **Cisco + Juniper** (BNE/SYD PEs, IOS-XRv ROV edge, vSRX/vJunos via BYOI) plus FRR/Docker offload where practical | Reservation-gated; ephemeral, export YAML |
| **C** | Cloud (DigitalOcean) | containerlab: **cRPD + FRR + Routinator + public-IP route-server** | Time-boxed (credit), configs-as-code |

Region C is the public-facing RPKI/BGP edge the Dell can't truly simulate, and a second home for Juniper-via-cRPD. ADR-004 constrains how Region C connects back: cloud host OSes join the management ring, while virtual cloud edge routers join the lab data-plane ring. The cloud host OS is not a routed lab node.

### 2.5 Build-then-operate sequencing
Build the full network (Region A Cisco core → Region B → Region C) **first**; then run the Telstra ops practice (MOP-driven changes, software patching/upgrades, monitoring, incident response, evidence capture) **on top of it**. The build is the practice network — not a separate exercise. See `telstra-ops-practice-plan.md`.

### 2.6 Cloud credits and lifecycle
| Credit | Amount | Expires | Use |
| --- | --- | --- | --- |
| Oracle Cloud (free trial) | A$400 | **~2026-07-08** (30-day) | Biggest/soonest → spend first; durable backbone *intent* blocked by always-free ARM capacity |
| DigitalOcean | $200 | **2026-07-30** | Region C cloud edge (cRPD + FRR + Routinator) |
| AWS | $120 / 164 d | ~2026-11-25 | **Earmarked for a macOS dedicated host — out of scope for the network lab** |

Discipline: everything cloud is **built as code** (containerlab YAML / cloud-init / Ansible) committed to the repo; **teardown reminders** exist for Jul 7 and Jul 30 (Claude app + Google Calendar); migrate keepers (monitoring / IPAM / RPKI) to Oracle Always-Free (when securable) or PC1 before each expiry. See `memory/cloud-credits.md`.

## 3. Consequences

**Positive**
- Lab matches the Telstra Cisco/Juniper/security stack; the local build is unblocked (no more nested-virt fights for the core).
- Region A is free and permanent — a stable foundation for ops practice. Juniper gets a working home (B + cloud + local vSRX). The cloud edge adds realism (public RPKI/BGP) the Dell can't.
- L3VPN-capable core proves a real SP service (VRF + VPNv4).

**Negative / trade-offs**
- Loses the *Nokia-in-Region-A-locally* multivendor story (mitigated: Nokia archived + recoverable; Region B/C restore multivendor breadth).
- Two short-fuse cloud credits demand discipline (configs-as-code + teardown reminders, already in place).
- Region B/C depend on external services (DevNet reservation, cloud accounts) — Region A is deliberately self-contained so nothing local blocks on them.

**Documents affected (cascade)**
- `region-a-plan.md` → **v2.5** (Dell/PC2 ADL-GEL-MEL-PE1-MEL-P geographic canvas; BNE/SYD moved to Region B; eight-POP national overlay preserved; Nokia archive note).
- `adr-002-two-region.md` → §3.1 marked superseded-in-part by this ADR.
- `aurora-deployment-status.md`, `telstra-ops-practice-plan.md`, `devnet-resource-strategy.md`, `design.md`, `lab-architecture.md` → re-vendor/placement corrections + cross-refs.
- `docs/region-a-topology.svg`/`.png` → **regenerated 2026-06-24 from `ops/region-a/diagrams/render_topology.py`** (single programmatic source; the legacy `.drawio`/`_v2`/`-screenshot.png` were retired). Reflects the §5.1a iBGP IPv4-unicast failover fix, ROV-C1 at the transit ingress, §5.4 hardening, controller `192.168.137.1:3080`, and the STAGED transits.
- `docs/adr-004-secure-rings-host-isolation.md` + `ops/access/` → secure access, per-agent automation, management/data-plane rings, and host-isolation validation.

## 4. Operating model (how we build/change)
Claude **drives** the device console (types commands); the user **coaches** — sets up devices, provides command sequences + the MOP/operational-evidence template, checks the work, and verifies via the GNS3 REST API (staying off the console to avoid single-client collisions). Changes are **MOP-driven** with operational evidence captured (Change ID, risk/impact, backout, pre-check, implementation log, post-check, rollback, closure). See `memory/lab-coaching-workflow.md` and `telstra-ops-practice-plan.md`.

## 5. Revision history
- **v1.5 (2026-06-25)** - inter-region border designation: `MEL-PE1` is the Region A↔B border/ASBR (terminates eBGP `64496 ↔ 65002` to Region B `DC-P-R1`, Option A); `MEL-P` is the transport handoff only (pure P, no BGP); `SYD-PE1` is a Region B node, not the Region A end of the boundary. Re-platforming a MEL node to an XRv9000 on the Dell GNS3 evaluated and declined (RAM/core ceiling) — MEL-PE1 stays IOS-XRv 6.1.3.
- **v1.4 (2026-06-15)** - geographic canvas alignment: ADL/GEL/MEL-PE1 sit left, MEL-P sits right, and MEL-P is the logical handoff toward PC1 / Region B SYD-PE1.
- **v1.3 (2026-06-15)** - placement correction: Dell/PC2 Region A is the MEL-GEL-ADL line; Brisbane/Sydney move to Region B CML planning, with SYD retaining the IOS-XRv VPNv4/ROV edge role.
- **v1.2 (2026-06-14)** - expands the national POP overlay beyond the first four POPs to include Adelaide, Perth, Darwin, and Tasmania/Hobart as planned POPs.
- **v1.1 (2026-06-14)** - restores the national POP overlay explicitly: Melbourne, Sydney, Brisbane, and Geelong are retained as the carrier geography, while Region A/B/C remain deployment domains.
- **v1.0 (2026-06-14)** — initial. Records the Cisco re-vendor of Region A, Juniper→Region B + cloud cRPD + local vSRX, the vJunos-can't-run-locally finding, the three-region model with a cloud edge, build-then-operate sequencing, and the cloud-credit lifecycle.
