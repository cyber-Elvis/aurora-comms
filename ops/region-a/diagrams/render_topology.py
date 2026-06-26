#!/usr/bin/env python3
"""Render the Aurora Region A topology as docs/region-a-topology.{svg,png}.

Single programmatic source of truth (replaces the hand-authored .svg/.drawio + baked-caption
JPGs that drifted). All captions/labels are code strings here, so a plan change is a one-line
edit + re-run, and SVG/PNG can never disagree. Self-contained raster via svglib + reportlab.

    python ops/region-a/diagrams/render_topology.py

Reflects region-a-plan.md v2.5 + the 2026-06-24 fixes: iBGP VPNv4 + IPv4-unicast (next-hop-self),
ROV from Phase C1 on both transit sessions, GNS3 controller 192.168.137.1:3080, transits STAGED.
"""
import os
import json
from xml.sax.saxutils import escape

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
OUT_SVG = os.path.join(REPO, "docs", "region-a-topology.svg")
OUT_PNG = os.path.join(REPO, "docs", "region-a-topology.png")
OUT_REGIONS = os.path.join(REPO, "docs", "region-a-topology.regions.json")

W, H = 1840, 1200
INK = "#0d2b4e"
XRV = "#1ba0d7"      # Region A IOS-XRv P/PE
SYD = "#1565c0"      # Region B IOS-XRv SYD-PE1
IOSV = "#42a5f5"     # IOSv spare CE
TRANSIT = "#6a1b9a"  # CSR / IOL-XE transit
FRR = "#0d9488"      # FRR IXP
FORTI = "#ee3124"    # FortiGate
ARUBA = "#f97316"    # Aruba CX
WL = "#fde047"       # workload
MGMT = "#455a64"     # mgmt / RPKI
IXPF = "#0f766e"     # IXP fabric
LINE = "#64748b"; IBGP = "#1d4ed8"; ZONE = "#9fb3cd"
PANEL_BG = "#f4f7fb"; PANEL_BR = "#c3d0e0"
FONT = "Helvetica"

svg = []
def el(s): svg.append(s)
def rect(x, y, w, h, fill, stroke="none", rx=10, sw=1.5, dash=None, op=1.0):
    d = f' stroke-dasharray="{dash}"' if dash else ""
    el(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{rx}" ry="{rx}" fill="{fill}" '
       f'fill-opacity="{op}" stroke="{stroke}" stroke-width="{sw}"{d}/>')
def text(x, y, s, size=12, fill=INK, anchor="start", bold=False, italic=False):
    fw = ' font-weight="bold"' if bold else ""
    fs = ' font-style="italic"' if italic else ""
    el(f'<text x="{x}" y="{y}" font-family="{FONT}" font-size="{size}" fill="{fill}" '
       f'text-anchor="{anchor}"{fw}{fs}>{escape(s)}</text>')
def line(x1, y1, x2, y2, color=LINE, sw=2.0, dash=None):
    d = f' stroke-dasharray="{dash}"' if dash else ""
    el(f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="{color}" stroke-width="{sw}"{d}/>')

N = {}
def node(name, x, y, w, h, title, sub, line3, fill, fg="#ffffff", dashed=False, badge=None):
    N[name] = (x, y, w, h)
    stroke = "#f0b429" if badge else "#ffffff"
    dash = "6 4" if dashed else None
    rect(x, y, w, h, fill, stroke=stroke, rx=9, sw=(2.4 if badge else 1.0), dash=dash)
    cx = x + w / 2
    text(cx, y + 20, title, size=13, fill=fg, anchor="middle", bold=True)
    text(cx, y + 36, sub, size=9.5, fill=fg, anchor="middle")
    if line3:
        # upright + 10px (not 9px italic): oblique thin strokes at the smallest size break up
        # worst under projector downscale + lossy WiFi cast — italic carries no semantic load here
        text(cx, y + 51, line3, size=10, fill=fg, anchor="middle")
    if badge:
        rect(x + w - 62, y + 4, 58, 14, "#f0b429", rx=3, sw=0)
        text(x + w - 33, y + 14, badge, size=8.5, fill="#3a2a00", anchor="middle", bold=True)
def C(n): x,y,w,h=N[n]; return (x+w/2, y+h/2)
def Er(n): x,y,w,h=N[n]; return (x+w, y+h/2)
def El(n): x,y,w,h=N[n]; return (x, y+h/2)
def Et(n): x,y,w,h=N[n]; return (x+w/2, y)
def Eb(n): x,y,w,h=N[n]; return (x+w/2, y+h)

# ---- background + title ----------------------------------------------------
rect(0, 0, W, H, "#ffffff", rx=0)
rect(0, 0, W, 72, INK, rx=0)
text(34, 32, "Aurora Communications — Region A (v2.5 · 2026-06-24): ADL–GEL–MEL-PE1–MEL-P",
     size=23, fill="#ffffff", bold=True)
text(34, 58, "IS-IS L2 + MPLS LDP  ·  iBGP full mesh: VPNv4 + IPv4-unicast (next-hop-self)  ·  "
             "MEL-PE1 = inter-region ASBR (eBGP 64496↔65002 → DC-P-R1)  ·  MEL-P = transport handoff to PC1  ·  "
             "doc ASNs/prefixes (RFC 5398/5737/3849)",
     size=13, fill="#9db8d6")

# ---- bands -----------------------------------------------------------------
def band(x, y, w, h, label, fill, stroke):
    rect(x, y, w, h, fill, stroke=stroke, rx=12, sw=1.6, op=0.5)
    text(x + 14, y + 22, label, size=13, fill=stroke, bold=True)
band(30, 86, 900, 268, "Internet Edge — simulated (doc ASNs/prefixes; never advertised to the real Internet)", "#f5f3ff", "#7e22ce")
band(30, 366, 900, 196, "Aurora AS 64496 — Cisco P/PE core (IS-IS L2 + LDP · iBGP VPNv4 + IPv4-unicast full mesh · MPLS L3VPN)", "#eff6ff", "#1d4ed8")
band(30, 574, 900, 150, "Customer Edge", "#fff7ed", "#f97316")
band(30, 736, 900, 110, "Tenant workloads — Region B/PC1 Docker offload", "#fefce8", "#ca8a04")
# Region B handoff container (SYD-PE1 lives OUTSIDE the Region A core band)
rect(948, 86, 264, 476, "#eef2ff", stroke="#1565c0", rx=12, sw=1.8, dash="7 5", op=0.5)
text(962, 108, "REGION B (PC1 / DevNet CML)", size=12, fill="#1e3a8a", bold=True)
text(962, 124, "logical handoff — not Region A", size=10, fill="#475569")

# ---- Internet-edge nodes ---------------------------------------------------
node("TB", 50, 210, 188, 76, "TRANSIT-B", "IOL-XE 17.15 · AS 64498", "backup · default LP100", TRANSIT, badge="STAGED")
node("TA", 470, 210, 188, 76, "TRANSIT-A", "CSR1000v 16.08.01 · AS 64497", "primary · default LP200", TRANSIT, badge="STAGED")
node("IXPF", 690, 214, 190, 60, "ixp-fabric", "Melbourne IXP · L2 LAN", "10.255.3.0/24 · PE1 .1 · SYD .3", IXPF)
node("RS", 300, 122, 168, 58, "ixp-rs1 (FRR)", "route server · AS 64499", "Region B/PC1 Docker", FRR)
node("CON", 478, 122, 168, 58, "ixp-content1 (FRR)", "CDN · AS 64500", "Region B/PC1 Docker", FRR)
node("EYE", 656, 122, 168, 58, "ixp-eyeball1 (FRR)", "eyeball ISP · AS 64501", "Region B/PC1 Docker", FRR)

# ---- core nodes (geographic ADL → GEL → MEL-PE1 → MEL-P) --------------------
node("ADL", 55, 440, 175, 76, "ADL-PE1", "IOS-XRv 6.1.3 · PE", "lo —(TBD) · Transit-B edge", XRV)
node("GEL", 285, 444, 175, 76, "GEL-PE1", "IOS-XRv 6.1.3 · PE", "lo 10.0.0.3 · regional", XRV)
node("MELPE1", 515, 440, 175, 76, "MEL-PE1", "IOS-XRv 6.1.3 · PE / ASBR", "lo 10.0.0.2 · Transit-A + IXP", XRV)
node("MELP", 745, 446, 168, 70, "MEL-P", "IOS-XRv 6.1.3 · P core", "lo 10.0.0.1 · IS-IS/LDP, no BGP", XRV)
node("SYD", 968, 442, 224, 76, "SYD-PE1", "Region B IOS-XRv · ASR 9000-style", "ROV enforcer · Region B/C edge", SYD, dashed=True)

# ---- customer edge ---------------------------------------------------------
node("SPARE", 55, 620, 175, 72, "region-a-ce-spare", "Cisco IOSv 15.7 · optional", "BYO-AS 64502 → ADL", IOSV, fg="#07203a")
node("HELIX", 285, 620, 175, 72, "helix-lan-sw", "Aruba CX 10.16 · VLAN 100/200", "local access · GEL", ARUBA)
node("NW", 515, 620, 175, 72, "Northwind CE", "FortiGate 7.0.14", "eBGP AS 64512 → MEL-PE1", FORTI)

# ---- workloads -------------------------------------------------------------
for i,(nm,lbl) in enumerate([("WLH","helix: orthanc·emr·doctor"),("WLN","northwind: saas·redis·prom·grafana")]):
    bx = 55 + i*430
    rect(bx, 770, 410, 54, WL, stroke="#f57f17", rx=7, sw=1)
    text(bx+205, 792, lbl, size=11, fill="#713f12", anchor="middle", bold=True)
    text(bx+205, 808, "Docker on Region B/PC1 (not on the Dell GNS3 VM)", size=9, fill="#854d0e", anchor="middle")

# ---- edges -----------------------------------------------------------------
def lbl(x, y, s, color="#475569"): text(x, y, s, size=9, fill=color, anchor="middle")
# transit eBGP (purple)
line(*Eb("TB"), *Et("ADL"), color=TRANSIT, sw=2.2); lbl(150, 330, "eBGP 64498→64496 · 10.255.2.4/30 · LP100 · ROV C1 · TCP-AO/BFD", TRANSIT)
line(*Eb("TA"), *Et("MELPE1"), color=TRANSIT, sw=2.2); lbl(560, 330, "eBGP 64497→64496 · 10.255.2.0/30 · LP200 · ROV C1 · TCP-AO/BFD", TRANSIT)
# IXP fabric (teal)
line(*El("IXPF"), *Et("MELPE1"), color=IXPF, sw=2.0); lbl(648, 360, "IXP .1", IXPF)
line(*Eb("RS"), *Et("IXPF"), color=IXPF, sw=1.8)
line(*Eb("CON"), Et("IXPF")[0]-20, Et("IXPF")[1], color=IXPF, sw=1.8)
line(*Eb("EYE"), Et("IXPF")[0]+20, Et("IXPF")[1], color=IXPF, sw=1.8)
# IS-IS/LDP core (solid blue)
line(*Er("ADL"), *El("GEL"), color=IBGP, sw=2.0); lbl(258, 470, "IS-IS/LDP 10.255.0.8/31", IBGP)
line(*Er("GEL"), *El("MELPE1"), color=IBGP, sw=2.0); lbl(488, 470, "10.255.0.6/31", IBGP)
line(*Er("MELPE1"), *El("MELP"), color=IBGP, sw=2.0); lbl(720, 470, "10.255.0.0/31", IBGP)
# iBGP mesh (dashed blue) among the 3 PEs
line(C("ADL")[0], 430, C("MELPE1")[0], 430, color=IBGP, sw=1.6, dash="5 4")
lbl(360, 424, "iBGP full mesh: VPNv4 + IPv4-unicast (next-hop-self) — ADL/GEL/MEL-PE1", IBGP)
# PE-CE
line(*Eb("ADL"), *Et("SPARE"), color=IOSV, sw=1.8, dash="5 4"); lbl(150, 600, "optional BYO-AS 64502", IOSV)
line(*Eb("GEL"), *Et("HELIX"), color=ARUBA, sw=1.8); lbl(372, 600, "VLAN 100/200", ARUBA)
line(*Eb("MELPE1"), *Et("NW"), color=FORTI, sw=1.8); lbl(602, 600, "eBGP CE-PE 64512", FORTI)
# CE -> workloads (dotted)
line(C("HELIX")[0], 692, 260, 770, color="#94a3b8", sw=1.4, dash="2 4")
line(C("NW")[0], 692, 480, 770, color="#94a3b8", sw=1.4, dash="2 4")
# MEL-P -> SYD logical handoff
line(*Er("MELP"), *El("SYD"), color="#64748b", sw=2.0, dash="2 5"); lbl(935, 430, "logical handoff", "#64748b")

# ---- right panel -----------------------------------------------------------
def panel(x, y, w, h, header, rows, hfill=INK):
    rect(x, y, w, h, PANEL_BG, stroke=PANEL_BR, rx=10, sw=1.4)
    rect(x, y, w, 26, hfill, rx=10, sw=0); rect(x, y+13, w, 13, hfill, rx=0, sw=0)
    text(x + 14, y + 18, header, size=12.5, fill="#ffffff", bold=True)
    yy = y + 46
    for k, v in rows:
        if k: text(x + 13, yy, k, size=11.5, fill="#334155", bold=True); text(x + 150, yy, v, size=11.5, fill=INK)
        else: text(x + 13, yy, v, size=11.5, fill=INK)
        yy += 20
PX, PW = 1232, 576
panel(PX, 86, PW, 120, "PC1 — Routinator / RPKI (rpki-rp1)", [
    ("RTR cache", "192.168.137.1:3323 (RFC 8210)"),
    ("VRPs", "SLURM lab assertions (RFC 8416) — no real ROAs"),
    ("ROV (Phase C1)", "Transit-A@MEL-PE1 + Transit-B@ADL-PE1 + SYD-PE1"),
], hfill=MGMT)
panel(PX, 218, PW, 96, "Management segment (OOB via MGMT-SW01)", [
    ("Node mgmt", "10.255.191.11–.22/24 (PEs .11–.17, transits .21–.22)"),
    ("GNS3 controller", "192.168.137.1:3080 (Dell/PC2 host)"),
    ("Compute", "GNS3 VM · 19 GiB / 2 vCPU · Tailscale 100.118.0.46"),
])
panel(PX, 326, PW, 140, "Addressing / policy", [
    ("Backbone /31s", "10.255.0.0/24 (IS-IS/LDP transport)"),
    ("Transit /30s", "A 10.255.2.0/30 · B 10.255.2.4/30"),
    ("LOCAL_PREF", "IXP 300 > Transit-A 200 > Transit-B 100"),
    ("VRF RD/RT", "64496:<id> (Northwind 3, Helix 2, CUST-A 100)"),
    ("Outward", "only PI 203.0.113.0/25 + customer aggregates"),
])
panel(PX, 478, PW, 132, "Transit-edge hardening (§5.4)", [
    ("Auth", "TCP-AO key-chain (the §9 auth exception)"),
    ("Failover", "single-hop BFD + fall-over (sub-second)"),
    ("Spoof / patch", "GTSM ttl-security hops 1 · graceful-restart"),
    ("Safety", "max-prefix v4 1000 / v6 200 · RPKI-invalid drop"),
    ("Visibility", "log neighbor-changes → Wazuh syslog"),
])
panel(PX, 622, PW, 96, "Build state (2026-06-24)", [
    ("[x]", "4× IOS-XRv backbone started; MEL pair IS-IS/LDP"),
    ("[~]", "transit-a-csr / transit-b-iol STAGED (wired, unconfigured)"),
    ("[ ]", "Stage 0 iBGP (vpnv4+ipv4-unicast+NHS) → transit config"),
])

# ---- legend ----------------------------------------------------------------
LY = 736
text(PX, LY, "Legend", size=12.5, fill=INK, bold=True)
leg = [("Cisco IOS-XRv 6.1.3 (Region A P/PE)", XRV), ("Region B IOS-XRv SYD-PE1", SYD),
       ("Cisco IOSv (spare CE)", IOSV), ("Cisco transit — CSR1000v(A) / IOL-XE(B)", TRANSIT),
       ("FRR IXP (Region B/PC1 Docker)", FRR), ("Fortinet FortiGate (Northwind CE)", FORTI),
       ("Aruba CX (Helix LAN)", ARUBA), ("Tenant workload (B/PC1 Docker)", WL),
       ("Management / RPKI (PC1)", MGMT)]
yy = LY + 14
for label, c in leg:
    rect(PX, yy, 20, 13, c, stroke="#cbd5e1", rx=3, sw=1); text(PX + 28, yy + 11, label, size=11, fill=INK); yy += 19
yy += 4
line(PX, yy, PX+30, yy, color=LINE, sw=2); text(PX+38, yy+4, "link (IS-IS/LDP, eBGP)", size=11, fill=INK); yy += 18
line(PX, yy, PX+30, yy, color=IBGP, sw=1.6, dash="5 4"); text(PX+38, yy+4, "iBGP VPNv4 + IPv4-unicast (full mesh)", size=11, fill=INK); yy += 18
line(PX, yy, PX+30, yy, color="#64748b", sw=1.6, dash="2 5"); text(PX+38, yy+4, "logical handoff / optional / RPKI-RTR", size=11, fill=INK)

# ---- archived + guardrail --------------------------------------------------
rect(PX, 1000, PW, 64, "#fef2f2", stroke="#fca5a5", rx=8)
text(PX+12, 1020, "Archived (ADR-003): Nokia core (SR Linux P + SR OS PE1/PE2) cold-stored,", size=10, fill="#7f1d1d")
text(PX+12, 1036, "recoverable. Juniper → Region B (vSRX/vJunos) + cloud cRPD; vSRX standalone-", size=10, fill="#7f1d1d")
text(PX+12, 1052, "local for practice.", size=10, fill="#7f1d1d")
rect(PX, 1074, PW, 56, "#fff1f2", stroke="#be123c", rx=8)
text(PX+12, 1096, "Guardrail: behavioural lab only. ASNs 64496–64502 = RFC 5398 doc ASNs; IPv4 =", size=10, fill="#881337", bold=True)
text(PX+12, 1112, "RFC 5737, IPv6 = RFC 3849 doc space. No public Internet / registered RIR RPKI.", size=10, fill="#881337", bold=True)

text(34, H - 16, "Generated by ops/region-a/diagrams/render_topology.py · source: region-a-plan.md v2.5 (+2026-06-24) · "
     "GNS3 project ops-lab on Dell 192.168.137.1:3080", size=10.5, fill="#94a3b8")

doc = (f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">\n'
       + "\n".join(s for s in svg if s) + "\n</svg>\n")
with open(OUT_SVG, "w", encoding="utf-8") as f:
    f.write(doc)
print("wrote", OUT_SVG)

# Semantic projector regions (in this diagram's WxH units) — consumed by
# ops/diagrams/make_projector_slides.py to cut intelligent slides (topology | reference)
# instead of a mechanical grid. Edit here if the layout moves; it's the single source of truth.
regions = {
    "canvas": [W, H],
    "slides": [
        {"name": "01-topology.png",
         "caption": "Region A - TOPOLOGY (edge - core - customer - workloads - Region B)",
         "box": [18, 78, 1218, 874]},
        {"name": "02-reference-rpki-mgmt-addressing.png",
         "caption": "Region A - REFERENCE: PC1 RPKI / Mgmt / Addressing",
         "box": [1224, 80, 1812, 470]},
        {"name": "03-reference-hardening-build.png",
         "caption": "Region A - REFERENCE: Hardening / Build state / Legend",
         "box": [1224, 470, 1812, 1134]},
    ],
}
with open(OUT_REGIONS, "w", encoding="utf-8") as f:
    json.dump(regions, f, indent=2)
print("wrote", OUT_REGIONS)

try:
    from svglib.svglib import svg2rlg
    from reportlab.graphics import renderPM
except ModuleNotFoundError as e:
    print(f"SVG written OK. PNG step skipped — {e}.")
    print(r'The render deps live in Python 3.10. Run with that interpreter:')
    print(r'  "C:\Users\Elvis\AppData\Local\Programs\Python\Python310\python.exe" ' + os.path.basename(__file__))
    print(r'  (or:  python -m pip install --user svglib reportlab pycairo rlPyCairo  into THIS interpreter)')
    raise SystemExit(0)
d = svg2rlg(OUT_SVG)
scale = 2.0
d.scale(scale, scale); d.width *= scale; d.height *= scale
renderPM.drawToFile(d, OUT_PNG, fmt="PNG", bg=0xFFFFFF)
print("wrote", OUT_PNG)
