# Aurora Backlog

Active architecture: ADR-003.
Security architecture: ADR-004.

```text
Region A: Cisco core on Dell GNS3
  -> Region B: DevNet CML Cisco + Juniper
  -> Region C: cloud edge
  -> secure management/data-plane rings
  -> TechOps operations on the built network
```

Older ADR-001/ADR-002 Nokia/containerlab items are historical unless explicitly carried forward. Nokia SR OS/SR Linux remains archived, not deleted.

National POP overlay: Melbourne, Sydney, Brisbane, Geelong, Adelaide, Perth, Darwin, and Tasmania/Hobart remain the carrier geography. Region A/B/C are deployment domains, not a replacement for the Australia-wide design.

## Sprint A0 - Secure Access Foundation

- [x] **Record ADR-004** - two rings, host-isolation invariant, per-agent automation identities, and validation model.
- [x] **Create `ops/access/` skeleton** - PowerShell SSH helper, non-secret inventory, vendor snippets, Tailscale ACL example, and validation runbook.
- [x] **Restore Dell/GNS3 management reachability** - GNS3 VM `tap-aurora-mgmt` (`10.255.191.1/24`) is the node-management demarc, reached from PC1 through `gns3@100.118.0.46`.
- [x] **Generate per-agent local keys** - `aurora-codex` and `aurora-claude` local Ed25519 keys generated under `%USERPROFILE%\.ssh`; private keys remain off repo and off lab nodes.
- [x] **Apply `aurora-codex` / `aurora-claude` to MEL pair** - key-first access is live on `mel-p1` and `mel-pe1`; `admin` remains Elvis-owned break-glass.
- [x] **Validate MEL per-agent SSH** - `aurora-codex` and `aurora-claude` both reach `MEL-P-CISCO-IOL-RT01` and `MEL-PE1-CISCO-IOL-RT01` through the GNS3 jump host.
- [ ] **Prove host containment locally** - lab node cannot reach PC1/PC2 SSH/RDP/SMB/WinRM/admin ports; explicit RPKI-RTR exception still works. GNS3 VM guard applied on `tap-aurora-mgmt`; live lab-node denial matrix still pending.
- [x] **Draft cloud Tailscale ACL policy** - `tag:hosts` may manage `tag:lab`; no `tag:lab` -> `tag:hosts` access.
- [ ] **Wire denied-flow logs to Wazuh** - alert on lab-node attempts toward protected host services. Wazuh rules and `wazuh-logtest` samples staged in `ops/access/wazuh/`; manager install/log source wiring still pending.

## Sprint A1 — Region A Cisco Core

- [ ] **Finish Dell/PC2 Region A line bring-up** — `ADL-PE1`, `GEL-PE1`, `MEL-PE1`, `MEL-P` as IOL-L3 with IS-IS L2 + LDP. GEL/ADL are created/wired in `ops-lab`; boot/config smoke still pending.
- [x] **Move Brisbane/Sydney to Region B** — `BNE-PE1` and `SYD-PE1` removed from local Region A staging; keep them as DevNet CML Region B planned nodes.
- [ ] **Apply national POP aliases** — MEL-P/MEL-PE1, GEL-PE1, ADL-PE1 locally; SYD-PE1/BNE-PE1 in Region B configs, diagrams, MOPs, and monitoring labels.
- [x] **Pin Dell/PC2 regional line** — keep the ADL -> GEL -> MEL-PE1 -> MEL-P line in the local `ops-lab` GNS3 design and instantiate GEL-PE1 / ADL-PE1 staging links.
- [x] **Align live topology geographically** — canvas order is now `ADL-PE1 -> GEL-PE1 -> MEL-PE1 -> MEL-P`; `MEL-P` is the right-side logical handoff toward PC1 / Region B `SYD-PE1`.
- [ ] **Validate MPLS L3VPN** — build `CUST-A` VRF (`RD/RT 64496:100`) and prove VPNv4 label exchange + cross-PE reachability.
- [ ] **Create Region A config templates** — `region-a-cisco/configs/` with per-node IOS/IOL/IOS-XR configs.
- [ ] **Export GNS3 project** — canonical reproducible `ops-lab` export after the core smoke passes.

## Sprint A2 — Customer And Internet Edge

- [ ] **Northwind FortiGate CE** — eBGP to PE-1, private AS 64512 default model, NAT/security policy, logging.
- [ ] **Helix Aruba CX LAN** — VLAN 100/200, local access-switching practice and management reachability; Region B `BNE-PE1` owns the Helix PE attachment later.
- [x] **Geelong regional PE placeholder** — `GEL-PE1` is staged on Dell/PC2 as the midpoint of the local regional line.
- [ ] **National POP expansion placeholders** — add PER-PE1, DRW-PE1, and HBA/TAS-PE1 to IPAM/NetBox and topology diagrams before instantiating them in GNS3/CML/cloud.
- [ ] **Transit-A / Transit-B** — Region A local CSR1000v primary transit AS 64497 and IOL-XE backup transit AS 64498; Transit-B hangs off ADL-PE1 for local failover.
- [ ] **IXP route-server fabric** — move FRR RS/content/eyeball peers to Region B/PC1 Docker where practical; enforce peer-over-transit preference once bridged.
- [ ] **IPv6 dual-stack** — use valid RFC 3849 `2001:db8::/32` slices from `docs/region-a-plan.md` / `docs/ip-plan.md`.

## Sprint A3 — Security And RPKI

- [ ] **Routinator + SLURM on PC1** — RTR endpoint `192.168.137.1:3323`.
- [ ] **RPKI/ROV C1** — first enforcer Region B `SYD-PE1` / `Aurora-PE-3`, valid/invalid/not-found matrix.
- [ ] **RPKI/ROV C3** — enforce on all eBGP ingress points: Transit-A, Transit-B, IXP sessions.
- [ ] **Routing authentication** — BGP TCP-MD5/TCP-AO where supported; IS-IS/LDP authentication later.
- [ ] **Fault drills** — transit failover, IXP port failure, invalid-origin route rejection.

## Sprint B — Region B DevNet CML

- [ ] **Reserve and document CML topology** — Cisco IOS-XE / IOS-XR / NX-OS baseline.
- [ ] **Instantiate Brisbane and Sydney PEs** — move `BNE-PE1` and `SYD-PE1` into the Region B CML topology; SYD remains the IOS-XR ROV / Region B-C edge.
- [ ] **Docker offload target** — host FRR IXP peers and tenant workload containers from Region B/PC1 instead of consuming Dell/PC2 GNS3 Docker budget.
- [ ] **Add Juniper presence** — vSRX/vJunos via CML/BYOI where practical; local vSRX remains standalone practice.
- [ ] **Inter-region edge** — eBGP/confed from right-side Region A `MEL-P` into PC1 / Region B `SYD-PE1`.
- [ ] **Maple Ridge enterprise model** — Cat8000v/Cat9kv/NX-OS style enterprise/campus/DC slice in CML.
- [ ] **Export Region B topology** — persist CML YAML/configs so reservations are reproducible.

## Sprint C — Cloud Edge

- [ ] **DigitalOcean containerlab edge** — cRPD + FRR + Routinator / route-server pattern.
- [ ] **Build PC1-PC2-DO-Oracle lab edge ring** - virtual edge routers, per-edge WireGuard keys, and eBGP/IS-IS reconvergence tests per ADR-004.
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

- [ ] **ADR-002 archive cleanup** - keep the file path stable, but move old Nokia operational details into a clear archive appendix so active readers land on ADR-003/ADR-004 first.
- [ ] EVPN/VXLAN fabric in DevNet CML.
- [ ] Segment Routing / SR-MPLS iteration after LDP baseline.
- [ ] BFD and fast-convergence tuning.
- [ ] FlowSpec / DDoS mitigation story.
- [ ] SIEM correlation rules per tenant.
- [ ] FortiManager / Panorama / FMC central-management comparison.
