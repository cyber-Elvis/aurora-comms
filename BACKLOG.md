# Aurora Backlog

Industry-standard items deferred from the W1 baseline. Each item is queued to a sprint with a one-line rationale. Items are checked off as they land.

## Sprint W2 — protocol security and sub-second convergence

- [ ] **Route reflectors at Melbourne core (RR pair)** — industry-standard from day one; remove iBGP full-mesh. RFC 4456.
- [ ] **BFD on all P2P interfaces** — sub-second failure detection (~150ms). Replaces ~9s IS-IS hold-down. RFC 5880.
- [ ] **IS-IS HMAC-SHA authentication on hellos and LSPs** — backbone integrity. RFC 5304.
- [ ] **LDP TCP-MD5 authentication** — protect LDP sessions. RFC 5036 / RFC 7349.
- [ ] **BGP TCP-MD5 authentication** — protect iBGP sessions. RFC 2385 (migrate to TCP-AO when widely supported).
- [ ] **BGP graceful restart** — survive daemon restart without route flapping. RFC 4724.

## Sprint W3 — modern protocols

- [ ] **Segment Routing (SR-MPLS) alongside LDP** — modern label distribution; LDP retained for compatibility. RFC 8660.
- [ ] **TI-LFA fast reroute** — sub-50ms IGP convergence using SR. RFC 8855.
- [ ] **IPv6 dual-stack** — `2001:db8:aurora::/48`. /128 per loopback, /127 per P2P link. RFC 6164.
- [ ] **IS-IS multi-topology** — separate IPv4 and IPv6 SPF computations. RFC 5120.

## Sprint W4 — first customer services

- [ ] **VPNv4 / VPNv6 BGP address-families** — for L3VPN customer routes. RFC 4364.
- [ ] **VPRN service for Maple Ridge (3 sites)**. RFC 4364.
- [ ] **eBGP peering with simulated upstream transit ASes**.
- [ ] **RPKI Routinator** for route origin validation. RFC 6480.

## Sprint W5+ — operational maturity

- [ ] **BGP add-path** — multi-path advertisement for ECMP. RFC 7911.
- [ ] **BGP FlowSpec** — DDoS mitigation rules pushed via BGP. RFC 5575 / 8955.
- [ ] **NETCONF / gRPC management plane** — replaces bind-mount config push.
- [ ] **OpenConfig YANG models** — vendor-neutral configuration.
- [ ] **LibreNMS + Grafana** — monitoring and dashboards.

## When the lab moves off WSL2

- [ ] **Jumbo MTU 9000 on backbone P2P** — currently using Linux default 1500.
- [ ] **MPLS kernel modules** — required for full LDP / SR-MPLS forwarding.

## Long-term / aspirational

- [ ] **SRv6** — IPv6-native segment routing. Mostly relevant for greenfield 5G transport.
- [ ] **EVPN over VXLAN** — for data-centre interconnect.
- [ ] **Multi-AS scenarios** — Aurora as one of three peering carriers.
