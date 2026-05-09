# Aurora Communications

> Tier 1 — fictional Australian regional carrier. POPs in Melbourne (HQ + core), Sydney, Brisbane, and Geelong. AS65100. The Nokia showcase tier.

## Carrier profile

| Attribute | Value |
| --- | --- |
| AS number | 65100 (private — would be a real AS in production) |
| POPs | Melbourne (HQ + core), Sydney, Brisbane, Geelong |
| Backbone IGP | IS-IS L1/L2, with the L1/L2 boundary at Brisbane |
| MPLS | LDP everywhere; one engineered LSP via RSVP-TE (Melbourne→Sydney) |
| BGP | 2× route reflectors at Melbourne core; eBGP to 2× upstream + 1× IXP |
| Security | RPKI Routinator + ROV at the eBGP edge; BGP FlowSpec for DDoS |
| Customer services | VPRN (L3VPN), VPLS (multipoint Ethernet), Epipe (E-Line), DIA, SD-WAN headend |

## Topology

```
                              Internet
                                  │
                ┌─────────────────┼─────────────────┐
                │                 │                 │
            Upstream-1         Upstream-2          IXP
              (eBGP)             (eBGP)          (eBGP)
                │                 │                 │
                └────────┬────────┴────────┬────────┘
                         │                 │
                    ┌────▼─────────────────▼────┐
                    │  Melbourne core (RR1+RR2) │
                    │   Cisco IOS-XRd RR        │
                    └──┬──────┬──────┬──────────┘
                       │      │      │
              ┌────────▼─┐ ┌──▼───┐ ┌▼──────────┐
              │ Sydney   │ │ Bris │ │ Geelong   │
              │  PE/P    │ │ PE/P │ │ regional  │
              │  (FRR)   │ │ (SRL)│ │ (FRR)     │
              └──────────┘ └──────┘ └───────────┘

Customer service edge:
  Maple Ridge HQ ──► Sydney PE     (VPRN export RT 65100:100)
  Maple Ridge DC ──► Melbourne PE  (VPRN)
  Maple Ridge NSW──► Sydney PE     (VPRN)
  Helix Health   ──► Melbourne PE  (DIA + scrubbing)
  Northwind HQ   ──► Melbourne PE  (DIA underlay → SD-WAN spoke)
  Northwind R&D  ──► Geelong PE    (DIA underlay → SD-WAN spoke)
```

## What lives in this repo

| Component | Status | Phase | Path |
| --- | --- | --- | --- |
| Containerlab + WSL2/Docker setup | not started | Sprint W1 | `lab-setup/` |
| Backbone — 4× FRR P-routers + IS-IS L1/L2 | not started | Sprint W1 | `backbone/` |
| MPLS-LDP + RSVP-TE engineered LSP | not started | Sprint W1 | `backbone/mpls.md` |
| BGP route reflectors (2× RR) | not started | Sprint W1 | `bgp/` |
| eBGP peering (2× upstream + 1× IXP) | not started | Sprint W1 | `bgp/peering.md` |
| VPRN (L3VPN) for Maple Ridge — 3 sites | not started | Sprint W2 | `services/vprn-mr/` |
| VPLS multipoint Carrier Ethernet demo | not started | Sprint W2 | `services/vpls/` |
| Epipe (E-Line) demo | not started | Sprint W2 | `services/epipe/` |
| RPKI Routinator + RoV at eBGP edge | not started | Sprint W2 | `security/rpki/` |
| BGP communities + import/export policy | not started | Sprint W3 | `bgp/policy/` |
| BGP FlowSpec rule for DDoS | not started | Sprint W3 | `security/flowspec/` |
| LibreNMS + Grafana NOC monitoring | not started | Sprint W3 | `noc/` |
| SD-WAN headend terminating Northwind spokes | not started | Sprint W4 | `sdwan/` |
| Cisco IOS-XRd RR (multi-vendor credibility) | not started | Sprint W4 | `iosxr/` |

## Multi-vendor strategy

| Node role | Implementation | Why |
| --- | --- | --- |
| P-routers | FRR (FRRouting) | Free, light (~150 MB/container), supports IS-IS+LDP+MPLS |
| 2× PEs | Nokia SR Linux (free) | Keeps Nokia visible in the diagram |
| 1× RR | Cisco IOS XRd (free with login) | Multi-vendor BGP fluency story |
| Customer edge | Cisco IOSv in GNS3 | Doubles as CCNA prep environment |

## JD coverage

| Skill | JDs / context |
| --- | --- |
| Nokia SR OS context (VPRN, VPLS, Epipe) | Telco roles — TasNetworks, Optus, NBN, Efiniti |
| BGP / IS-IS / MPLS-LDP / RSVP-TE | 17 JDs (8%); telco core |
| RPKI + FlowSpec | BGP security; carrier DDoS handling |
| Carrier Ethernet / MEF (E-Line, E-LAN, E-Tree) | Carrier/ISP service portfolio |
| SD-WAN headend | 15 JDs (~7%); growing AU market |
| Cisco IOS-XR exposure | Closes Cisco gap at carrier scale |

## Working notes

- **Containerlab on the desktop:** WSL2 + Docker on Win 11. FRR runs as Docker images; SR Linux and IOS-XRd are also containerized. Total backbone RAM footprint is ~5 GB.
- **NOC ↔ MSP NOC:** syslog from all Aurora nodes ships to the Sentinel Ridge MSP Wazuh manager (Dell laptop). This is intentional — it lets the MSP demonstrate cross-tier monitoring.
- **Why a carrier tier on top:** five years of Nokia SR OS production experience is the rarest and most differentiated thing on the verified resume. The carrier tier puts that experience back at the top of the lab where hiring managers reading TasNetworks, Optus, or NBN job descriptions will see it first.

## Cross-references

- Master plan: `Sentinel_Ridge_Lab_Design.docx`
- Build tracker (hours, status): `Sentinel_Ridge_Lab_Tracker.xlsx`
- Customer service edges live in: `maple-ridge/`, `helix-health/`, `northwind-robotics/`
