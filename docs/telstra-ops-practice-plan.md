# Telstra Protect/Secure — TechOps Practice Plan (2-week immersion)

| Field | Value |
| --- | --- |
| Status | Active |
| Owner | Elvis Ifeanyi Nwosu |
| Goal | Hands-on readiness for **TechOps Technical Specialist, Telstra (via Infosys)** — Protect & Secure towers |
| Cadence | ~5+ hrs/day, 10 working days |
| Weighting | Balanced: Cisco R&S · Juniper · firewalls (Forti/PA/FTD/ASA) · process/tooling |
| Upgrade images | DevNet CML (multi-version Cisco) + vendor trial portals (FortiOS/PAN-OS) |
| Context | `memory/telstra-techops-role.md` · `docs/adr-003-revendor-cisco-region-a.md` (build-then-operate) · lab from `region-a-plan.md` v2.5 / `gns3-vm-ram-budget.md` |

## 0. How to use this · what "ready" means

This is an **operations** rig, not a design lab. The role is run/patch/troubleshoot under change control for high-stakes clients (emergency services, health, banking). Every technical task below is wrapped in the **real operational workflow**, because that discipline — not raw config — is what the job rewards.

**You're "ready" when you can, cold, for any platform:** assess a PSIRT advisory → write a MOP with a rollback plan → back up config → take pre-checks → execute the patch in a window → validate with evidence → roll back if needed → close a change record. Plus: read a monitoring alert, triage an incident, and document it. **And — just as important — write it up and hand it over clearly: in this role the written update carries as much weight as the fix** (evidence pack + handover note, §2).

**The through-line (do this every single patch task):**

> **MOP discipline** — 1) Scope & risk · 2) Backout/rollback plan · 3) Config backup + snapshot · 4) Pre-checks (capture `show`/state) · 5) Implementation steps · 6) Post-validation (capture evidence) · 7) Change record (ServiceNow). Save each one — they become your personal ops playbook.

### 0.1 Scope philosophy — competency-led, NOT a product checklist

The named products (Cisco R&S, Juniper, Zscaler/Fortinet/Palo Alto, Cisco security) are *instances*. The role spans **network + security operations** broadly — the actual stack has more products than any single recollection (the two towers literally split this: **Protect** ≈ secure network/edge, **Secure** ≈ security services). So this plan trains **transferable competencies**, not logos:

- **Network ops** — routing/switching config & troubleshooting, interface/transport, change-safe upgrades.
- **Security ops** — firewall/NGFW policy, NAT, VPN, segmentation, content/threat updates, identity.
- **The operating model** — patch/change discipline, monitoring → incident → RCA, automation, ITSM.

A Check Point, Netskope, Citrix ADC, or Arbor you've never seen behaves like the firewall/LB/router you *did* drill, wrapped in the *same* MOP. **Own the operating model; the brand is interchangeable.**

## 1. Foundation (Day 0 — do this first)

> **Build-then-operate (ADR-003).** This practice layers on the **Region A Cisco core** (`region-a-plan.md` v2.5) — IOL-L3 `ADL-PE1 -> GEL-PE1 -> MEL-PE1 -> MEL-P` on Dell/PC2, IS-IS/LDP/iBGP-VPNv4 + MPLS L3VPN, mapped into the national POP overlay. `MEL-P` is the right-side logical handoff toward PC1 / Region B `SYD-PE1`. Brisbane/Sydney PEs live in Region B CML planning, with SYD as the IOS-XRv VPNv4/ROV edge. That backbone *is* the network you run/patch/troubleshoot below: build it first (underway in `ops-lab`), then operate it. Juniper practice = **vSRX standalone-local** now (+ Region B later); firewalls (Forti/PA/FTD) are singleton heavyweights brought up solo.

> **Secure access foundation (ADR-004).** Before expanding Wave 2/cloud operations, privileged access uses per-agent lab-node accounts (`aurora-codex`, `aurora-claude`) and a strict host-isolation model: PC1, PC2/Dell, DO, and Oracle host OSes are management anchors, not routed lab nodes. Validation must prove both allowed access and denied node-to-host pivot paths.

| Task | What | Where |
| --- | --- | --- |
| **Region A Cisco core** | The baseline backbone to operate on — IOL-L3 ADL-PE1/GEL-PE1/MEL-PE1/MEL-P, IS-IS/LDP/iBGP-VPNv4 + L3VPN. Build per `region-a-plan.md` §6 (underway: MEL pair booted; GEL/ADL staged). | Dell GNS3 (`ops-lab`) |
| **Nokia archived** | Done as part of the re-vendor (ADR-003): SR Linux stopped; SR OS qcow2 + recipe cold-stored (do NOT delete — irreplaceable). Recoverable if a multivendor-local story is wanted later. | Dell GNS3 |
| **Ops tooling stack** | **NetBox** (CMDB/source-of-truth), **Oxidized** (config backup/versioning), **LibreNMS** or Grafana+Prometheus+snmp_exporter (monitoring), **Ansible** control node. Reuse the existing **Wazuh + MISP** for SIEM/threat-intel. | PC1 (off the Dell budget); Oracle Always-Free optional |
| **Access/security tooling** | `ops/access/aurora-ssh.ps1`, per-agent SSH keys, Tailscale ACLs, host-isolation validation, denied-flow logging to Wazuh. | PC1 / PC2 / cloud hosts; lab nodes only receive public keys |
| **DevNet CML access** | Free DevNet account + AnyConnect/openconnect; reserve a sandbox with embedded CML (multi-version IOS-XE/XR/NX-OS for real upgrades + Region B Cisco/Juniper). | PC1 openconnect |
| **ServiceNow dev instance** | Free developer instance — practice Change/Incident records (the role is ITSM-driven). | cloud |
| **ITIL refresh** | 1-hr skim: Change / Incident / Problem management, CAB, maintenance windows. | — |

**Done when:** Region A Cisco core up + smoke-passing (`region-a-plan.md` §7); Nokia archived; NetBox+Oxidized+monitoring reachable from PC1 and pulling from the first device; CML reservable; ServiceNow instance live.

## 2. Week 1 — platform fluency + real upgrade mechanics (one platform/day)

Each day: **build & onboard** (config refresh + NetBox/Oxidized/monitoring) → **upgrade drill** (real source→target via CML/trial) → **operational evidence pack** (template below) → **daily handover note** → **PSIRT angle** (real advisory for the platform).

### Operational evidence template — fill ONE per change (this IS the deliverable)

In a managed-ops role the written record *is* the work product — for emergency-services/health/bank clients it has to be auditable. Copy this for every patch/change, all 10 days:

```
CHANGE EVIDENCE PACK
  Change ID            : CHGxxxxxxx (ServiceNow)
  Date / window        : YYYY-MM-DD  HH:MM–HH:MM  (TZ)
  Device / platform    : <hostname> · <vendor/OS> · <current → target version>
  Risk / customer impact: <Low/Med/High> — <who is affected, what service, why>
  Backout plan         : <exact steps + decision point/abort criteria>
  Pre-check commands    : <commands + CAPTURED output: version, interfaces, BGP/HA, sessions>
  Implementation log   : <timestamped steps as executed, incl. hashes verified>
  Post-check evidence   : <same checks re-run + CAPTURED output / screenshots — proves health>
  Rollback result      : <not needed / tested OK / executed — outcome + state restored?>
  Closure notes        : <result, residual risk, follow-ups, ticket closed Y/N>
```

> The pre/post checks must be the **same commands** so the diff is the evidence. "It looks fine" is not evidence; a captured `show` before and after is.

### Daily handover note — write ONE every day (your update matters as much as the fix)

End each session with a 5-line handover, as if passing to the next shift. Practising this builds the muscle that gets noticed:

```
HANDOVER — <date> <your name>
  Current state : <what's done / running / changed today>
  Risk          : <anything fragile, pending reload, watch-items>
  Next action   : <the very next concrete step>
  Owner         : <who holds it next — you / next shift / vendor / customer>
  ETA           : <when next action is due / window booked>
```

**Escalation judgment (1 per day):** for one issue you hit, also note in a line — *"handle myself or escalate? to whom, and why?"* Knowing **when to escalate vs. own it** (and to which queue/vendor TAC) is a core specialist skill; rehearse the decision, not just the fix.

### Day 1 — Cisco IOS-XE (the bread & butter)
- **Build:** CML CSR/Cat8000v (or local Cat9kv/CSR1000v). Interfaces, OSPF+BGP, ACLs, NTP/SNMP/AAA/syslog→Wazuh. Onboard to NetBox + Oxidized.
- **Upgrade drill:** **install mode** — `show version` → `verify /md5` → `install add file flash:… activate commit` → reload → validate → `install rollback`. Contrast with bundle/`boot system`. Note ISSU concept.
- **Artifact:** MOP for an IOS-XE point upgrade + ServiceNow change with pre/post evidence.

### Day 2 — Cisco IOS-XR + NX-OS
- **Build:** CML IOS-XR (XRv9000 / ASR9k vRR) + NX-OS (n9kv). Basic L3 + a VLAN/VPC on NX-OS.
- **Upgrade drill:** XR install model (`install add`/`activate`/`commit`, `show install active`). NX-OS `show install all impact` → `install all nxos …` (+ EPLD awareness, disruptive vs non-disruptive).
- **Artifact:** two MOPs (XR + NX-OS) noting the *different* install models — a real interview/job talking point.

### Day 3 — Juniper Junos (vSRX)
- **Build:** local vSRX 22.3 (or CML vJunos). Zones, security policies, NAT, OSPF/BGP. Master the **candidate/commit** model: `commit confirmed`, `rollback`, `commit comment`.
- **Upgrade drill:** `request system snapshot` → `request system software add /var/tmp/junos… validate` → reboot → `show version` → roll back to snapshot. The `validate` + snapshot safety net is the Junos signature.
- **Artifact:** MOP highlighting Junos `commit confirmed` as the built-in rollback.

### Day 4 — Fortinet FortiGate (FortiOS)
- **Build:** local FortiGate 7.0.14. Firewall policy, NAT/VIP, IPsec site-to-site VPN, logging + FortiView, admin profiles.
- **Upgrade drill:** the **FortiOS upgrade *path*** is mandatory — you must step through versions (e.g., 7.0.x → 7.2.x → 7.4.x, no skipping). Backup config (`execute backup config`), pull a **7.2.x trial image** from the Fortinet support portal, `execute restore image`, watch the upgrade, verify, note downgrade limits.
- **Security-protocol angle:** FortiGuard AV/IPS/App-control **definition updates** (the daily content patching).
- **Artifact:** MOP that includes the upgrade-path lookup step (this trips people up).

### Day 5 — Palo Alto (PAN-OS)
- **Build:** local PA-VM 11.0.0. Security policy, zones, NAT, App-ID, Security Profiles (AV/AS/Vuln/URL), GlobalProtect basics.
- **Upgrade drill:** PAN-OS **upgrade path** (can't skip feature releases; base image + matching content). Download → install → reboot, on a 11.0 → 11.1 trial image.
- **Security-protocol angle:** **dynamic content updates** (App-ID, Threat/IPS, WildFire, Antivirus) + their schedules — the core "security protocol" patching for an NGFW.
- **Artifact:** MOP separating *software* upgrade from *content* update cadence.

## 3. Week 2 — security stack + automation + process depth

### Day 6 — Cisco Firepower (FTDv + FMC) + ASAv
- **Build:** local FTDv 7.2 + FMC 7.2 (the validated pair). Register FTD to FMC; access-control policy, NAT, intrusion policy. ASAv 9.22 alongside (ASDM, basic policy) — many enterprises still run classic ASA.
- **Upgrade drill:** the **FMC-first ordering** (upgrade FMC, *then* managed FTDs), readiness checks, the FMC upgrade wizard, SRU/Snort-rule + VDB (security content) updates. ASA: `boot system` + reload.
- **Artifact:** MOP capturing the manager-first sequencing — a classic real-world gotcha. (One-at-a-time on the Dell: FMC ~8 GB, FTDv 16 GB — run solo per `gns3-vm-ram-budget.md`.)

### Day 7 — Identity/NAC (Secure tower) + automation
- **Identity:** Cisco ISE (heavy — DevNet ISE sandbox, or local solo if RAM allows): 802.1X/MAB, posture, the NAC concept. Conceptual is fine; understand the role in "Secure".
- **Automation (the Infosys multiplier):** Ansible playbooks against the lab —
  1. **Config backup** across all devices (compare to Oxidized).
  2. **Compliance check** (assert NTP/SNMP/AAA/banner/SSH-v2 present).
  3. **Bulk pre-upgrade health-check** (capture `show version`/interfaces/BGP before a window).
- **Artifact:** a small Ansible repo — directly demonstrable to Infosys/Telstra.

### Day 8 — Monitoring + incident-response simulation
- **Wire it up:** LibreNMS/Grafana fully ingesting the lab (SNMP polling, syslog → Wazuh). Dashboards + alert rules (interface down, high CPU, BGP down).
- **Incident sim:** inject a fault (kill an interface / BGP flap / firewall CPU spike / failed daemon) → **detect via alert/Wazuh** → triage → root-cause → resolve → **document an Incident ticket** in ServiceNow. Run the full detect→resolve→document loop twice.
- **Artifact:** 2 incident write-ups (symptom, RCA, fix, prevention).

### Day 9 — End-to-end change dry-run (the job, simulated)
- Pick one platform (FortiGate or FTD). Write a **production-grade MOP** for a security patch: scope, risk rating, customer impact (frame it as emergency-services/health/bank), backout, pre-checks, step-by-step implementation, validation, rollback.
- **Execute it in the lab** with full **evidence capture** (pre/post `show`, screenshots).
- Log it as a **ServiceNow Change** with a CAB-style approval + implementation + closure. This single exercise mirrors ~80% of the actual day-job.

### Day 10 — PSIRT-to-patch drill + cloud security + consolidation
- **PSIRT drill:** pull 2–3 *current real* advisories (Cisco PSIRT, FortiGuard PSIRT, PAN-OS security advisories), assess impact against your lab versions, plan + execute remediation, validate. This is exactly the "patching as a security protocol" loop.
- **Cloud security (can't lab — study):** **Zscaler** is pure SaaS — do the free **Zscaler Academy** ZIA/ZPA admin modules; understand traffic forwarding (GRE/IPsec/PAC/ZCC client) + ZPA app connectors. **Cisco Umbrella** via DevNet sandbox.
- **Consolidate:** compile your MOPs/runbooks/Ansible/incident write-ups into a personal **Ops Playbook** — your reference for week 1 on the job.

## 4. Scope breadth — the "others" you'll likely meet

You only remember part of the stack — that's fine, because the plan is competency-led (§0.1). Here's the realistic map for a telco Protect/Secure managed-ops practice so nothing blindsides you.

**Already in your validated arsenal — stretch slots if a day finishes early:**

| Tech | Domain | Note |
| --- | --- | --- |
| **F5 BIG-IP** (`F5-BIGIP-16.0-LTM`) | ADC / load-balancer / WAF / SSL-offload | Huge in enterprise/telco network+security; you already imported it. Practice: VIP/pool/monitor, SSL, a software upgrade. |
| **Cisco SD-WAN (Viptela)** | Managed WAN overlay | You have the 18.4.5 images. vManage/vBond/vSmart/vEdge — managed-WAN is core telco-enterprise. Heavy (vManage) — run pieces solo. |
| **Cisco DC switching** (Cat9kv / Nexus9300v) | Campus / data-centre | Already validated; fold into the Cisco R&S days. |
| **vSRX** | Juniper *security* (not just routing) | Day 3 already uses it as the Junos box — also your Juniper-firewall instance. |

**Source-able (vendor eval) if you want a specific "other" labbed:**

| Tech | Domain | How |
| --- | --- | --- |
| **Check Point** (Gaia / VSEC) | Firewall (very common in telco/enterprise) | Free eval VM — the most likely big "other" firewall; say the word and I'll source it. |
| **Cisco ISE** | Identity / NAC (Secure tower) | Already Day 7 — local solo or DevNet sandbox. |
| **Aruba ClearPass / Citrix ADC / Fortinet FortiManager** | NAC / ADC / central mgmt | Vendor evals exist; add on demand. |

**Study-only — cloud SaaS / scale (can't lab, but know the model):**

| Item | Why | How to cover |
| --- | --- | --- |
| **Zscaler (ZIA/ZPA)** | Pure cloud SaaS — no on-prem image | Zscaler Academy (free) + conceptual (traffic forwarding GRE/IPsec/PAC/ZCC, ZPA app connectors) |
| **Netskope / Prisma Access** | Cloud SASE | Vendor docs + the Zscaler mental model transfers |
| **Cisco Umbrella / ThousandEyes** | Cloud DNS-security / network observability | DevNet sandboxes + docs |
| **DDoS (Arbor/NETSCOUT, Radware)** | Scrubbing/mitigation | Conceptual; telco-edge pattern |
| **Splunk / QRadar (SIEM)** | Enterprise SIEM | Your **Wazuh** builds the same SIEM muscle; Splunk free tier for UI familiarity |
| **Real Telstra scale / MPLS core** | Obviously | Patterns transfer; CML for multi-node Cisco |
| **ServiceNow (production)** | Licensed | Free developer instance = same workflow muscle |

The point: there's almost nothing on a network+security ops stack whose *operating model* you won't have rehearsed by the end of this plan.

## 5. Resource map

- **Dell GNS3** (2 cores / 19 GB, one heavyweight at a time) — perfect for *ops* practice: focus one platform per session. Firewalls/FTDv/Cat9kv run solo (`gns3-vm-ram-budget.md`).
- **PC1** (Ryzen, 32 GB, KVM) — ops tooling stack (NetBox, Oxidized, LibreNMS/Grafana, Ansible) + Wazuh + MISP, always-on.
- **DevNet CML** — real multi-version Cisco upgrades (IOS-XE/XR/NX-OS) without local image hunting.
- **Vendor trials** — FortiOS + PAN-OS target images for real firewall upgrades.

## 6. Portfolio you'll walk in with (day-1 credibility)

A folder of: **~10 change-evidence packs** (one per patch) + **daily handover notes**, per-platform **upgrade MOPs**, **ServiceNow change + incident records**, an **Ansible ops repo** (backup/compliance/pre-check), **incident RCAs**, a **PSIRT-to-patch** worked example, and a consolidated **Ops Playbook**. The evidence packs + handovers especially signal *managed-ops maturity* — that you don't just fix, you document and hand over auditable changes. That's more operational evidence than most contractors bring on day one — and it's all reusable on the job.
