# Cisco DevNet Resource Strategy and Continuity Plan

| Field | Value |
| --- | --- |
| Status | Active reference document |
| Version | 1.0 |
| Date | May 2026 |
| Purpose | Long-term tiered DevNet sandbox strategy for Aurora Communications lab; backup hierarchy for maintenance windows; adoption timeline |
| Related | `docs/adr-002-two-region.md` (canonical Region B hosting decision), `docs/adr-003-revendor-cisco-region-a.md` (Region B = Cisco **+ Juniper**; three-region model), `docs/adr-004-secure-rings-host-isolation.md` (secure rings and host isolation), `docs/lab-architecture.md` (ADR-001 v1.6 §17 DevNet integration), `docs/runbook.md` (operational diagnostics) |
| Owner | Lab architecture (Elvis Ifeanyi Nwosu) |

## 1. Scope and intent

ADR-002 chose Cisco Modeling Labs Reservable as the canonical host for Aurora Region B (Cisco-dominant). **Per ADR-003 (2026-06-14), Region B also hosts the lab's Juniper presence — vSRX + vJunos via CML BYOI** (CML's non-nested infrastructure runs vJunos, which the triple-nested Dell cannot). Non-Cisco *cloud* resources (Oracle / DigitalOcean / AWS, and the Region C cloud edge) are **out of scope here** — see `adr-003-revendor-cisco-region-a.md` §2.4–2.6, `memory/cloud-credits.md`, and `aurora-deployment-status.md`. This document is the **operational reference** that surrounds that decision:

ADR-004 governs access to Region B/C control surfaces: DevNet, cloud hosts, PC1, and PC2 are management anchors, not routed lab nodes. Lab reachability should be represented by virtual edge nodes and per-zone automation keys, with Tailscale/WireGuard controls preventing lab-node pivots into PC1, PC2, or cloud host OSes.

- Which specific DevNet sandboxes form the long-term lab stack
- How to fall back when primary resources are unavailable (maintenance, queue exhaustion, regional outage)
- The order in which to adopt sandboxes as the lab matures
- Per-sandbox notes that don't belong in an architecture decision document

This document is intentionally separate from the ADRs because it changes more frequently than architectural decisions — DevNet adds new sandboxes, deprecates old ones, and adjusts policies on a quarterly cadence. This document is the right place to track that drift.

## 2. Always-On vs Reservable — categorical distinction

| Category | Access model | When state resets | Admin access | VPN | Reservation |
| --- | --- | --- | --- | --- | --- |
| **Always-On** | Public SSH/HTTPS over the internet using sandbox-published credentials | Periodically (varies per sandbox; some daily, some weekly) AND when other DevNet users modify shared state | No (read + non-admin API operations) | Not required | Not required |
| **Reservable** | AnyConnect/Cisco Secure Client OR `openconnect`-in-WSL2 VPN tunnel to a per-reservation environment | Reset at end of reservation slot (typically 4 hours to 5 days) | Yes (full admin / enable mode) | Required | Required (4 hr to 7 day slots depending on sandbox) |

### Duration policy fields — what they actually mean

The DevNet UI shows these fields under "Policies":

| Field | Reservable interpretation | Always-On interpretation |
| --- | --- | --- |
| **Default Duration** | Length of a fresh reservation when "Reserve" is clicked without specifying duration | Session/API-token lifetime before re-authentication required |
| **Max Duration** | Absolute longest a reservation can stretch with extensions | Maximum continuous session lifetime |
| **Permitted Extend** | Per-click "Extend" button increment | Per-extend token-refresh increment |
| **Active environment limit** | System-wide simultaneous reservation cap across all DevNet users | Labeled "Always On" — concept doesn't apply |
| **Currently Active** | Real-time count of in-flight reservations system-wide | Number of users currently authenticated |

**Common confusion**: "Default Duration: 3 hours" on an Always-On sandbox does NOT mean the sandbox rebuilds every 3 hours. It means your **authenticated session** times out and you re-authenticate. The sandbox itself runs 24/7.

**What it DOES mean for state persistence**: Always-On sandboxes are SHARED. Your config changes are visible to other DevNet users in real-time, may be modified by others, and are subject to Cisco's periodic reset jobs. Treat Always-On as "look, demo, automate against — don't depend on persistent state."

## 3. Tiered resource stack for Aurora Communications

### Tier 1 — Core (build the lab around these)

These are the resources Aurora depends on for the canonical demo paths.

| Resource | Type | Use in Aurora | Provisioning time |
| --- | --- | --- | --- |
| **Cisco Modeling Labs** | Reservable, 8h default / 2d max | Host Region B topology — IOS XR P + PE + Cat8000v + multi-vendor CEs per ADR-002 §3.2 | ~9 min |
| **IOS XR Always-on** | Always-On | 24/7 fallback for "demo current IOS XR right now" without reservation | ~35 sec |
| **IOS XE on Cat8kv** | Reservable | Alternative PE platform for Region B; current Cat8000v 17.x with applied license | ~5-8 min |

### Tier 2 — Backbone alternatives (resilience and variety)

These add platform diversity and provide backup when Tier 1 is unavailable.

| Resource | Type | Use | Backup of |
| --- | --- | --- | --- |
| **XRd Sandbox** | Reservable | Containerised IOS XR; demonstrates NETCONF/YANG/gRPC native pipeline | IOS XR Always-on |
| **Nexus 9000 AlwaysOn** | Always-On | NX-OS NETCONF/RESTCONF/gRPC/YANG/gNMI streaming telemetry | None — unique platform |
| **Catalyst 9000 Always-On** | Always-On | Cat9k IOS XE switching current code | IOS XE on Cat8kv |
| **Cisco SD-WAN 20.18 AlwaysOn** | Always-On | Current SD-WAN without reservation overhead | Cisco SD-WAN 20.12 Reservable |
| **Cisco 8000 XR Notebooks** | Reservable | Current XR (7.x+) with Jupyter notebook-style interaction | IOS XR Always-on |

### Tier 3 — Orchestration & control plane (NetDevOps story)

These convert Aurora from "I built a backbone" to "I built a backbone with senior-engineer automation discipline."

| Resource | Type | Demo angle |
| --- | --- | --- |
| **Catalyst Center Always-On v2.3.3.6** | Always-On (API focus) | DNAC REST API automation — intent-based networking, device discovery, policy push |
| **Catalyst Center Sandbox** (Reservable) | Reservable | Same DNAC but with admin access for changes that Always-On won't permit |
| **Network Services Orchestrator Always-On** | Always-On | NSO YANG-driven service automation against the always-on multi-vendor topology |
| **Network Services Orchestrator 6.4.4** | Reservable | NSO with admin access for service-pack development and template authoring |
| **NSOLAB** | Reservable | NSO front-ended by CML topology launcher — bridges NSO automation with topology design |
| **vNexus Dashboard Fabric Controller** | Reservable | VXLAN/EVPN fabric management — DC fabric automation story for Helix Health DC scenario |

### Tier 4 — Security (tenant-specific demonstrations)

These attach to the tenant scenarios in ADR-002 §3 (Maple Ridge, Helix Health, Northwind).

| Resource | Type | Tenant fit |
| --- | --- | --- |
| **Firepower Management Center** | Reservable / hybrid Always-On | Helix Health regulated industry — central NGFW management |
| **Firepower Threat Defense REST API** | Reservable | Customer-managed NGFW per-tenant configurations |
| **Identity Services Engine 3.4** | Reservable | Helix Health LAN access control — 802.1X/dot1x NAC with Aruba CX switches |
| **Cisco Secure Network Analytics** | Reservable | Stealthwatch — SIEM-adjacent traffic analytics that complements local Wazuh |
| **Cisco Security Cloud Control** | Reservable | CDO with FTD onboarding + Multicloud Defense + AI Assistant; modern cloud-managed security |
| **Cisco Umbrella Secure Internet Gateway** | Reservable | Northwind cloud-native tenant — DNS-based security |
| **Cisco ACI Simulator 6.0** | Reservable | Helix Health DC ACI fabric demonstration |
| **ACI Simulator Always-On** | Always-On | ACI API exploration without reservation |
| **Nexus Dashboard** | Reservable | DC fabric management |

### Tier 5 — Specialised (adopt only when matched to a concrete need)

These are valuable in specific contexts but should not be adopted speculatively.

| Resource | When to adopt |
| --- | --- |
| **Cisco 8000 SONiC Notebook** | If targeting hyperscaler / DCN architecture roles or modern multi-NOS demonstrations |
| **CI/CD pipeline for infrastructure automation** | Once Tier 1-3 stable; adds GitLab + Ansible + pyATS + CML pipeline — strong portfolio piece but high time investment |
| **Meraki Sandbox** | If targeting cloud-managed networking customers or Meraki-shop carriers |
| **Cloud-Native SD-WAN** | Bleeding edge; only if explicitly relevant to a customer demo |
| **IE3400 Edge Compute / IOx / Secure Equipment Access** | If targeting industrial / utility / manufacturing customers |

## 4. Continuity hierarchy — when something is down

The discipline of "primary → secondary → tertiary → local" applies to each Tier 1/2 resource. This is documented operational behaviour expected at senior-engineer level.

### Per-resource fallback hierarchy

| Primary | Maintenance fallback | Secondary fallback | Last resort (local-only) |
| --- | --- | --- | --- |
| CML Reservable | SD-WAN 20.12 embedded CML at `10.10.20.161` | XRd Sandbox + manual eBGP cookbook | Local IOS XRv 6.1.3 (on-disk demo image) |
| IOS XR Always-on | Cisco 8000 XR Notebooks (Reservable) | XRd Sandbox | Local IOS XRv 6.1.3 |
| IOS XE on Cat8kv Reservable | Catalyst 9000 Always-On | IOS XR Always-on (different platform but IOS-family CLI) | Local CSR1000v 16.8 (on-disk demo) |
| Catalyst Center Sandbox Reservable | Catalyst Center Always-On v2.3.3.6 | DNAC docs + simulated API responses via mocked endpoints | None — DNAC has no local equivalent |
| Network Services Orchestrator Reservable | NSO Always-On | NSOLAB (NSO + CML) | None — NSO has no useful local equivalent for non-trivial work |
| SD-WAN 20.12 Reservable | SD-WAN 20.18 AlwaysOn | SD-WAN 20.10 Reservable (older version) | None — SD-WAN cannot be meaningfully simulated locally without violating Cisco's licensing |
| Firepower FTD Reservable | Firepower Management Center hybrid Always-On (API only) | Cisco Security Cloud Control with embedded FTD | pfSense locally for "any firewall" demo (vendor-neutral) |
| Nexus 9000 AlwaysOn | Nexus Dashboard Reservable | vNexus Dashboard Fabric Controller | None — NX-OS has no useful local equivalent |
| ACI Simulator Reservable | ACI Simulator Always-On | Cloud-Native SD-WAN (different but related modern paradigm) | None |

### Detection and failover procedure

When a primary becomes unavailable, the operator follows this sequence:

1. **Detect** — symptoms include: maintenance banner in DevNet portal, reservation queue rejection ("Active environment limit reached"), SSH timeout to known endpoint, repeated 5xx responses from API
2. **Verify** — check Cisco DevNet status pages (https://developer.cisco.com/sandbox), and Cisco's regional infrastructure status if applicable
3. **Switch** — update the Ansible inventory variable for the affected service to point at the secondary endpoint; commit the change to a branch so the failover is auditable
4. **Test** — run the Aurora verification playbook against the new endpoint; expect different IPs and possibly different software versions
5. **Document** — append a one-line incident entry to `docs/runbook.md` §13 noting date, primary, secondary used, duration
6. **Revert** — once primary returns, switch back; commit the Ansible inventory change

### Quarterly continuity test

To prevent secondary fallback paths from rotting (image versions changing, API contracts evolving, sandbox decommissioning), Aurora's operational discipline includes a **quarterly continuity test**:

- Pick one Tier 1 resource per quarter
- Simulate its failure by ignoring the primary and proceeding through the fallback chain
- Document what works and what's drifted in `docs/runbook.md`
- If a fallback is broken, update this document with the replacement

This is what real network engineers do for production DR plans. Documenting it here demonstrates that the lab is operated to senior-engineer standards.

## 5. Adoption timeline

### Phase 1 — Foundation (immediate)

For the ADR-002 Region B canonical setup:

| Resource | Action | Justification |
| --- | --- | --- |
| Cisco Modeling Labs | Use Reservable per ADR-002 §3.2 | Region B host |
| IOS XR Always-on | Bookmark + verify SSH access | 24/7 fallback |
| IOS XE on Cat8kv Reservable | Bookmark | Cat8000v alternative PE |

### Phase 2 — Tier 2 backbone resilience (June 2026)

Once Region B is stable, add:

| Resource | Action |
| --- | --- |
| Cisco 8000 XR Notebooks | Bookmark + first reservation to test access |
| SD-WAN 20.18 AlwaysOn | Verify SSH access; document as primary SD-WAN fallback |
| Nexus 9000 AlwaysOn | Verify; this becomes the canonical NX-OS demo target |
| Catalyst 9000 Always-On | Verify; canonical Cat9k demo |

### Phase 3 — Orchestration adoption (July-August 2026)

Add the NetDevOps story:

| Resource | Action |
| --- | --- |
| Catalyst Center Always-On | Verify API access; build a sample Ansible playbook that pulls device inventory |
| NSO Always-On | Verify; build a sample YANG service template |
| NSOLAB | Use as the integration target — NSO calling CML topology for end-to-end demo |

### Phase 4 — Security tenants (September-October 2026)

Attach security resources to tenant scenarios as those scenarios become demonstrable:

| Resource | Tenant binding |
| --- | --- |
| Firepower FTD + FMC | Helix Health W4 perimeter |
| ISE 3.4 | Helix Health LAN dot1x story |
| Cisco Umbrella | Northwind cloud-security demo |
| Cisco Secure Network Analytics | Stealthwatch integration with local Wazuh |

### Phase 5 — Specialised additions (Q4 2026 onward)

Adopt only when matched to a concrete demo need. Don't pre-build infrastructure for stories that haven't been asked for.

## 6. DevNet account and credential management

### Account requirements

| Account | Cost | Used for | Provisioning time |
| --- | --- | --- | --- |
| Cisco CCO (id.cisco.com) | Free | Underlying identity for DevNet, software downloads (with service contract for some), VPN client downloads | ~10 min |
| Cisco DevNet (developer.cisco.com) | Free | Sandbox reservations, API access tokens, learning labs | Linked to CCO at signup |

### Credential handling

Per-reservation credentials (VPN endpoint, username, password) live in version-controlled config:

```
aurora-comms/
├── region-b-cisco-cml/
│   ├── cml-topology.yml              # canonical Region B topology
│   ├── ansible/
│   │   ├── inventory/
│   │   │   ├── devnet-current.yml    # current reservation IPs (gitignored, regenerated per reservation)
│   │   │   └── devnet-template.yml   # template structure committed
│   │   └── deploy.yml
│   └── README.md                     # how to capture credentials from reservation portal
```

The credential template captures the **shape** of the data (variable names, expected fields). The actual values are gitignored and regenerated per reservation.

### Multi-account considerations

A single DevNet account is sufficient for Aurora's purposes for the foreseeable future. The 110-reservation system-wide cap on CML and similar caps on other sandboxes are not per-account limits — they are concurrent-use limits across all DevNet users.

If access patterns expand (e.g., teaching others, multiple parallel demos), a second DevNet account is free and creates reservation independence.

## 7. Cost — explicit zero

All resources in this document are **free** under Cisco DevNet's terms. No paid Cisco accounts, partner agreements, service contracts, or CML Personal licenses are required for any sandbox listed here.

The trade-offs for "free" are:
- Resources are ephemeral (Reservable) or shared (Always-On)
- No persistent state ownership
- Subject to Cisco's reservation queue, maintenance windows, and policy changes
- Latency from Australia to Cisco US-West / EU hosting is 150-250ms

These trade-offs are accepted explicitly per ADR-002 §9.

## 8. References

- `docs/adr-002-two-region.md` — canonical Region B hosting decision (CML Reservable)
- `docs/lab-architecture.md` (ADR-001 v1.6) — §17 DevNet integration architecture and empirical validation
- `docs/runbook.md` — operational runbook (will gain a §X for DevNet continuity incidents)
- `BACKLOG.md` — sprint plan (will reference this document for vendor-account-related W2-W4 tasks)
- Cisco DevNet sandbox catalog: `https://devnetsandbox.cisco.com/`
- Cisco DevNet sandbox documentation: `https://developer.cisco.com/docs/sandbox/`
- Cisco DevNet sandbox info portal: `https://developer.cisco.com/site/sandbox/`

## 9. Maintenance of this document

This document is updated when:

- A new DevNet sandbox is released that's relevant to Aurora (add to appropriate tier)
- A DevNet sandbox is deprecated or removed (remove or mark deprecated)
- Cisco changes the duration/limit policies of a sandbox materially
- Cisco rebrands or restructures DevNet
- A continuity-test failure surfaces a broken fallback path
- Quarterly review (March, June, September, December)

Changes to this document don't require ADR-level governance; they're operational drift tracking.
