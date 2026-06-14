# Aurora Backlog

Active architecture: ADR-003.

```text
Region A: Cisco core on Dell GNS3
  -> Region B: DevNet CML Cisco + Juniper
  -> Region C: cloud edge
  -> TechOps operations on the built network
```

Older ADR-001/ADR-002 Nokia/containerlab items are historical unless explicitly carried forward. Nokia SR OS/SR Linux remains archived, not deleted.

National POP overlay: Melbourne, Sydney, Brisbane, Geelong, Adelaide, Perth, Darwin, and Tasmania/Hobart remain the carrier geography. Region A/B/C are deployment domains, not a replacement for the Australia-wide design.

## Sprint A1 — Region A Cisco Core

- [ ] **Finish Wave 1 core bring-up** — `Aurora-P`, `Aurora-PE-1`, `Aurora-PE-2` as IOL-L3 with IS-IS L2 + LDP.
- [ ] **Add `Aurora-PE-3` IOS-XRv** — IOS-XR PE for VPNv4, ROV, and future Region B edge.
- [ ] **Apply national POP aliases** — MEL-P/MEL-PE1, SYD-PE1, BNE-PE1 in configs, diagrams, MOPs, and monitoring labels.
- [ ] **Validate MPLS L3VPN** — build `CUST-A` VRF (`RD/RT 64496:100`) and prove VPNv4 label exchange + cross-PE reachability.
- [ ] **Create Region A config templates** — `region-a-cisco/configs/` with per-node IOS/IOL/IOS-XR configs.
- [ ] **Export GNS3 project** — canonical reproducible `ops-lab` export after the core smoke passes.

## Sprint A2 — Customer And Internet Edge

- [ ] **Northwind FortiGate CE** — eBGP to PE-1, private AS 64512 default model, NAT/security policy, logging.
- [ ] **Helix Aruba CX LAN** — VLAN 100/200, local VRF trunk to PE-2, management reachability.
- [ ] **Geelong access placeholder** — keep `region-a-ce-spare` as GEL access now; promote to light `Aurora-PE-4` / GEL-PE1 after the base Cisco core is stable if the fourth PE is needed.
- [ ] **National POP expansion placeholders** — add ADL-PE1, PER-PE1, DRW-PE1, and HBA/TAS-PE1 to IPAM/NetBox and topology diagrams before instantiating them in GNS3/CML/cloud.
- [ ] **Transit-A / Transit-B** — CSR1000v primary transit AS 64497 and IOL backup transit AS 64498.
- [ ] **IXP route-server fabric** — GNS3 switch + FRR RS/content/eyeball peers; enforce peer-over-transit preference.
- [ ] **IPv6 dual-stack** — use valid RFC 3849 `2001:db8::/32` slices from `docs/region-a-plan.md` / `docs/ip-plan.md`.

## Sprint A3 — Security And RPKI

- [ ] **Routinator + SLURM on PC1** — RTR endpoint `192.168.200.1:3323`.
- [ ] **RPKI/ROV C1** — first enforcer `Aurora-PE-3`, valid/invalid/not-found matrix.
- [ ] **RPKI/ROV C3** — enforce on all eBGP ingress points: Transit-A, Transit-B, IXP sessions.
- [ ] **Routing authentication** — BGP TCP-MD5/TCP-AO where supported; IS-IS/LDP authentication later.
- [ ] **Fault drills** — transit failover, IXP port failure, invalid-origin route rejection.

## Sprint B — Region B DevNet CML

- [ ] **Reserve and document CML topology** — Cisco IOS-XE / IOS-XR / NX-OS baseline.
- [ ] **Add Juniper presence** — vSRX/vJunos via CML/BYOI where practical; local vSRX remains standalone practice.
- [ ] **Inter-region edge** — eBGP/confed from Region A PE-3 into Region B.
- [ ] **Maple Ridge enterprise model** — Cat8000v/Cat9kv/NX-OS style enterprise/campus/DC slice in CML.
- [ ] **Export Region B topology** — persist CML YAML/configs so reservations are reproducible.

## Sprint C — Cloud Edge

- [ ] **DigitalOcean containerlab edge** — cRPD + FRR + Routinator / route-server pattern.
- [ ] **Public-IP route-server demo** — safe lab-only BGP policy; no real route advertisement.
- [ ] **Teardown discipline** — budget reminders, IaC configs, destroy scripts.
- [ ] **Oracle Free evaluation** — NOC/monitoring candidate only; not KVM.

## Sprint Ops — Telstra Protect/Secure Practice

- [ ] **NetBox source-of-truth** — devices, sites, interfaces, IPs, ASNs, VRFs.
- [ ] **Oxidized config backup** — first Cisco, then FortiGate/vSRX/PA-VM.
- [ ] **LibreNMS/Grafana monitoring** — SNMP, syslog/Wazuh, dashboard alerts.
- [ ] **Ansible ops repo** — config backup, compliance checks, pre-upgrade health checks.
- [ ] **ServiceNow dev workflow** — Change, Incident, Problem/RCA practice.
- [ ] **MOP templates** — scope, risk, backout, pre-checks, implementation, post-checks, rollback, closure.
- [ ] **Patch drills** — IOS-XE, IOS-XR/NX-OS, Junos, FortiOS, PAN-OS, FTD/FMC, ASAv.
- [ ] **PSIRT-to-patch drills** — Cisco PSIRT, FortiGuard, Palo Alto advisories.

## Singleton Heavyweights

Run these one at a time with Region A stopped:

- [ ] FTDv + FMC registration and manager-first upgrade workflow.
- [ ] PA-VM 11.0 policy/content/software update workflow.
- [ ] FortiGate upgrade-path workflow.
- [ ] Cat9kv campus switching / IOS-XE install-mode workflow.
- [ ] XRv9000 / Nexus via DevNet where local Dell cannot run them reliably.

## Long-Term

- [ ] EVPN/VXLAN fabric in DevNet CML.
- [ ] Segment Routing / SR-MPLS iteration after LDP baseline.
- [ ] BFD and fast-convergence tuning.
- [ ] FlowSpec / DDoS mitigation story.
- [ ] SIEM correlation rules per tenant.
- [ ] FortiManager / Panorama / FMC central-management comparison.
