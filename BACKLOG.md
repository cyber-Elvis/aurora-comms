# Aurora Backlog

Industry-standard items deferred from the W1 baseline. Each item is queued to a sprint with a one-line rationale. Items are checked off as they land.

**Architecture:** workload distribution decisions are recorded in `docs/lab-architecture.md` (ADR-001 — Option C, hybrid).

## Sprint W2 — automation foundation, architecture migration, first customer service

### Architecture and automation
- [ ] **Commit Ansible automation layer** (`lab/automation/`) — inventory, group_vars, host_vars, frr.conf.j2 template, render/deploy/destroy playbooks, Makefile. Replaces the Python generator as canonical config producer.
- [ ] **Update README** to reflect W1 baseline reality (current README is stale v1 scaffolding text).
- [ ] **Document Option C architecture** (`docs/lab-architecture.md`) — workload distribution rationale.
- [ ] **Migrate Wazuh + MISP from Dell to PC1** — CPU-intensive backend services move to Ryzen; ~4.5 hours; see ADR-001 Phase 1–7.
- [ ] **Configure Tailscale overlay** across PC1, Dell, Surface Pro, and the containerlab nodes.
- [ ] **Set up GRE tunnel** PC1 ↔ Dell for Maple Ridge CE → Aurora PE handoff.

### Carrier extensions (protocol — promoted from W4 based on CCIE-SP interview signal)
- [ ] **Route reflectors at Melbourne core (RR pair)** — industry-standard from day one; remove iBGP full-mesh. RFC 4456.
- [ ] **BGP graceful restart** — survive daemon restart without route flapping. RFC 4724.
- [ ] **VPRN service for Maple Ridge (3 sites)** — RD `65100:1`, RT `target:65100:1`, MP-BGP VPNv4. RFC 4364.
- [ ] **MP-BGP VPNv4 address-family** between PEs (and RRs). RFC 4364.
- [ ] **Customer CE routers running OSPF** — Maple Ridge HQ, DC, NSW. OSPF as PE-CE protocol. Demonstrates O / O IA / O E1/E2 route types.
- [ ] **eBGP with simulated upstream AS** — AS 65200, eBGP-multihop loopback peering. Demonstrates eBGP-multihop, update-source, ebgp-vs-iBGP.
- [ ] **BGP path selection demonstration lab** — purpose-built scenarios for Weight, Local-Preference, MED, AS-prepend ordering. Interview gold.

## Sprint W3 — protocol security and sub-second convergence

- [ ] **BFD on all P2P interfaces** — sub-second failure detection (~150 ms). Replaces ~9 s IS-IS hold-down. RFC 5880.
- [ ] **IS-IS HMAC-SHA authentication** on hellos and LSPs. RFC 5304.
- [ ] **LDP TCP-MD5 authentication** — protect LDP sessions. RFC 5036 / RFC 7349.
- [ ] **BGP TCP-MD5 authentication** — protect iBGP sessions. RFC 2385 (migrate to TCP-AO when supported).
- [ ] **Multi-vendor Aurora backbone expansion** — add 1× Cisco IOS XRd RR and 1× Nokia SR Linux RR alongside FRR PEs. Cisco/Nokia syntax practice on real OSes.
- [ ] **Segment Routing (SR-MPLS) alongside LDP** — modern label distribution; LDP retained for compatibility. RFC 8660.
- [ ] **TI-LFA fast reroute** — sub-50 ms IGP convergence using SR. RFC 8855.
- [ ] **IPv6 dual-stack** — `2001:db8:aurora::/48`. /128 per loopback, /127 per P2P. RFC 6164.
- [ ] **IS-IS multi-topology** — separate IPv4 and IPv6 SPF. RFC 5120.
- [ ] **L2 switching + inter-VLAN routing simulation** — Maple Ridge enterprise access (Cumulus VX or IOSv-L2 + IOSv-L3). Addresses VLAN/SVI interview questions.
- [ ] **PHP label stack capture and writeup** — tcpdump showing label stack transition through P → PE. Portfolio artefact.
- [ ] **OpenZiti deployment** as Zscaler ZPA analog for Northwind Robotics.

## Sprint W4 — first customer firewalls + RPKI + Zscaler integration

- [ ] **Palo Alto VM-Series** for Maple Ridge perimeter (MSP-managed via Ansible). Interview portfolio gold.
- [ ] **Fortinet FortiGate-VM** for Helix Health perimeter (MSP-managed). Free FortiGate-VM-Lab license via FortiCare.
- [ ] **Cisco ASAv** for syntax variety (optional).
- [ ] **RPKI Routinator** for route origin validation. RFC 6480.
- [ ] **Zscaler integration architecture documentation** for Northwind Robotics — ZIA + ZPA design doc + GRE tunnel + PAC file simulation. Portfolio doc.
- [ ] **Zscaler Academy ZIA Essentials course completion** — free credential.
- [ ] **VPLS service** — carrier Ethernet multipoint. RFC 4761/4762.
- [ ] **Epipe service** — point-to-point E-Line per MEF.

## Sprint W5+ — operational maturity and advanced services

- [ ] **BGP add-path** — multi-path advertisement for ECMP. RFC 7911.
- [ ] **BGP FlowSpec** — DDoS mitigation rules pushed via BGP. RFC 5575 / 8955.
- [ ] **NETCONF / gRPC management plane** — replaces bind-mount config push.
- [ ] **OpenConfig YANG models** — vendor-neutral configuration.
- [ ] **FortiManager central management** — Fortinet MSP central management plane.
- [ ] **Inter-AS L3VPN Option B** — VPNv4 between Aurora and a simulated peer carrier. Industry-standard advanced topic.
- [ ] **6PE / 6VPE** — IPv6 PE for carrier transport over IPv4 core / IPv6 VPN.
- [ ] **Wazuh + MISP correlation rules per tenant** — Maple Ridge, Helix, Northwind separate detection logic.
- [ ] **Cloud-native NSG / SG configurations** — Azure NSG for Helix tenant, AWS SG for Northwind tenant.
- [ ] **SIEM observability dashboards** — Grafana panels for Wazuh + LibreNMS + tenant-specific drill-downs.

## When the lab moves off WSL2

- [ ] **Jumbo MTU 9000** on backbone P2P — currently using Linux default 1500.
- [ ] **MPLS kernel modules** — required for full LDP / SR-MPLS forwarding plane.

## Long-term / aspirational

- [ ] **SRv6** — IPv6-native segment routing. Greenfield 5G transport context.
- [ ] **EVPN over VXLAN** — data centre interconnect.
- [ ] **Multi-AS scenarios** — Aurora as one of three peering carriers; Inter-AS Option A / B / C variants.
- [ ] **Multicast VPN (MVPN)** — default-MDT, data-MDT, BGP MVPN. CCIE-SP advanced.
- [ ] **QoS in SP environment** — DSCP marking at edge, EXP-bit propagation into MPLS, per-class queueing.
- [ ] **Carrier replacement of Dell** with a modern multi-core mini-PC if workload outgrows current envelope (Sprint W6+ consideration).
