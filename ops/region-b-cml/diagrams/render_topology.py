#!/usr/bin/env python3
"""Render the Aurora Region B plan as docs/region-b-topology.{svg,png}.

Placement-focused: three zones — REGION A (local, Internet edge), PC1/Dell (bridge +
PC1 Docker + local non-Cisco CEs), and REGION B (CML reservation: Cisco native + the one
vJunos BYOI). The PC1 openconnect bridge is the hub everything local uses to reach the
CML Cisco PEs. Self-contained raster via svglib + reportlab/rlPyCairo.

    python ops/region-b-cml/diagrams/render_topology.py
"""
import os
import json
from xml.sax.saxutils import escape

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
OUT_SVG = os.path.join(REPO, "docs", "region-b-topology.svg")
OUT_PNG = os.path.join(REPO, "docs", "region-b-topology.png")
OUT_REGIONS = os.path.join(REPO, "docs", "region-b-topology.regions.json")

W, H = 1760, 1000
INK = "#0d2b4e"
XR = "#1565c0"; XE = "#4f8fe0"; PALO = "#fa582d"; JNX = "#159e74"
GRAY = "#64748b"; BRIDGE = "#6a4ea3"; LINE = "#5b6b7d"; TRANSIT = "#8e44ad"
IXP = "#0e8a7d"; MGMT = "#455a64"; ARUBA = "#ff9800"
PANEL_BG = "#f4f7fb"; PANEL_BR = "#c3d0e0"; ZONE_BR = "#9fb3cd"
FONT = "Helvetica"

svg = []
def el(s): svg.append(s)

def rect(x, y, w, h, fill, stroke="none", rx=10, sw=1.5, dash=None, op=1.0):
    d = f' stroke-dasharray="{dash}"' if dash else ""
    el(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{rx}" ry="{rx}" '
       f'fill="{fill}" fill-opacity="{op}" stroke="{stroke}" stroke-width="{sw}"{d}/>')

def text(x, y, s, size=14, fill=INK, anchor="start", bold=False, italic=False):
    fw = ' font-weight="bold"' if bold else ""
    fs = ' font-style="italic"' if italic else ""
    el(f'<text x="{x}" y="{y}" font-family="{FONT}" font-size="{size}" fill="{fill}" '
       f'text-anchor="{anchor}"{fw}{fs}>{escape(s)}</text>')

def line(x1, y1, x2, y2, color=LINE, sw=2.0, dash=None):
    d = f' stroke-dasharray="{dash}"' if dash else ""
    el(f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="{color}" stroke-width="{sw}"{d}/>')

def poly(pts, color=LINE, sw=2.0, dash=None):
    p = " ".join(f"{x},{y}" for x, y in pts)
    d = f' stroke-dasharray="{dash}"' if dash else ""
    el(f'<polyline points="{p}" fill="none" stroke="{color}" stroke-width="{sw}"{d}/>')

# node registry: name -> (x, y, w, h)
N = {}
REG = {}  # bbox of each projector-region group, accumulated as elements draw (auto-tracks layout)
def reg(group, x, y, w, h):
    box = [x, y, x + w, y + h]
    b = REG.get(group)
    REG[group] = box if b is None else [min(b[0], x), min(b[1], y), max(b[2], x + w), max(b[3], y + h)]
def node(name, x, y, title, sub, fill, fg="#ffffff", w=150, h=56, byoi=False, rr=False):
    N[name] = (x, y, w, h)
    reg("topology", x, y, w, h)
    stroke = "#f0b429" if (byoi or rr) else "#ffffff"
    dash = "5 4" if byoi else None
    rect(x, y, w, h, fill, stroke=stroke, rx=9, sw=(3.0 if (byoi or rr) else 1.0), dash=dash)
    text(x + w/2, y + 23, title, size=13.5, fill=fg, anchor="middle", bold=True)
    text(x + w/2, y + 41, sub, size=10, fill=fg, anchor="middle")

def C(n):  x,y,w,h = N[n]; return (x+w/2, y+h/2)
def Er(n): x,y,w,h = N[n]; return (x+w, y+h/2)
def El(n): x,y,w,h = N[n]; return (x, y+h/2)
def Et(n): x,y,w,h = N[n]; return (x+w/2, y)
def Eb(n): x,y,w,h = N[n]; return (x+w/2, y+h)

# ---- background + title ----------------------------------------------------
rect(0, 0, W, H, "#ffffff", rx=0)
rect(0, 0, W, 74, INK, rx=0)
text(34, 33, "Aurora Region B  ·  placement view  —  what runs in CML vs locally on PC1/Dell",
     size=24, fill="#ffffff", bold=True)
text(34, 59, "CML = Cisco native + ONE BYOI (vJunos).  Non-Cisco CEs + IXP + RPKI run locally and reach "
             "the CML PEs over the PC1 openconnect bridge.  Transits stay in Region A.",
     size=13.5, fill="#9db8d6")

# ---- zone boxes ------------------------------------------------------------
def zone(x, y, w, h, label):
    reg("topology", x, y, w, h)
    rect(x, y, w, h, "#eef4fb", stroke=ZONE_BR, rx=14, sw=1.8, op=0.55)
    text(x + 16, y + 24, label, size=14, fill=INK, bold=True)

zone(40, 92, 452, 196, "REGION A  ·  local Dell GNS3  (Internet edge stays here)")
zone(40, 312, 452, 600, "PC1 / Dell  ·  bridge · PC1 Docker · local non-Cisco CEs")
zone(560, 92, 660, 648, "REGION B  ·  CML reservation  (Cisco native + vJunos BYOI)")

# ---- REGION A nodes --------------------------------------------------------
node("MELP", 56, 150, "MEL-PE1 edge (ASBR)", "AS 64496 · MEL-P = transport handoff", INK, w=200, h=58)
node("TA", 300, 144, "Transit-A · CSR1000v", "AS 64497 · primary", TRANSIT, w=180, h=50)
node("TB", 300, 210, "Transit-B · IOL-XE", "AS 64498 · backup", TRANSIT, w=180, h=50)
line(*El("TA"), *Er("MELP"), color=TRANSIT, sw=1.8)
line(*El("TB"), Er("MELP")[0], Er("MELP")[1]+8, color=TRANSIT, sw=1.8)

# ---- PC1 / local nodes -----------------------------------------------------
node("BR", 56, 360, "openconnect bridge", "+ MASQUERADE (tun0)", BRIDGE, w=200, h=58)
node("RPKI", 56, 440, "Routinator (PC1 Docker)", "RTR :3323 · RPKI/ROV", MGMT, w=200, h=48)
node("IXP", 56, 508, "IXP FRR (PC1 Docker)", "RS/content/eyeball 64499-501", IXP, w=200, h=56)
node("PAVM", 290, 360, "HH-CE · PA-VM 9.0.4", "PC1 vrnetlab · AS 64521", PALO, w=196, h=58)
node("VSRX", 290, 440, "JNX-FW · vSRX", "Dell standalone · AS 64522", JNX, w=196, h=58)
node("ARUBA", 290, 520, "helix-lan-sw · Aruba CX", "local L2 · Helix LAN", ARUBA, w=196, h=58)
text(56, 600, "Local CEs reach Region B PEs over the bridge (PE-CE eBGP) —", size=11.5, fill="#334155")
text(56, 618, "no per-reservation CML upload. Aruba is local L2 behind PA-VM (no GRE).", size=11.5, fill="#334155")
# local attachments
line(*El("PAVM"), *Er("BR"), color=PALO, sw=1.8)
line(El("VSRX")[0], El("VSRX")[1], Er("BR")[0], Er("BR")[1]+6, color=JNX, sw=1.8)
line(*El("ARUBA"), *Eb("PAVM"), color=ARUBA, sw=1.8)          # Aruba behind PA-VM (local)
line(Et("IXP")[0], Et("IXP")[1], Eb("BR")[0], Eb("BR")[1], color=IXP, sw=1.6)
line(Et("RPKI")[0], Et("RPKI")[1], Eb("BR")[0]+6, Eb("BR")[1], color=MGMT, sw=1.6)

# ---- REGION B (CML) nodes --------------------------------------------------
node("DCP1", 720, 140, "DC-P-R1", "IOS XR · RR / ASBR", XR, rr=True)
node("DCP2", 950, 140, "DC-P-R2", "IOS XR · RR", XR, rr=True)
node("JNXP", 575, 235, "JNX-P", "vJunos-router · BYOI", JNX, byoi=True)
node("MRPE1", 700, 335, "MR-PE-R1", "IOS XR · PE", XR)
node("MRPE2", 700, 425, "MR-PE-R2", "Cat8000v XE · PE", XE, fg="#07203a")
node("MRCE", 575, 530, "MR-CE", "Cat8000v · CE+ZBFW", XE, fg="#07203a")
node("HHPE1", 1010, 335, "HH-PE-R1", "IOS XR · PE", XR)
node("HHPE2", 1010, 425, "HH-PE-R2", "IOS XR · PE", XR)
text(575, 690, "8 Cisco nodes (native) + JNX-P (vJunos, the one BYOI). HH-CE / vSRX / Aruba are bridged in.",
     size=11.5, fill="#334155", italic=True)

# CML internal core links (thin; /31 detail is in the ADDRESSING panel)
for a, b in [("DCP1","DCP2"),("DCP1","JNXP"),("DCP2","JNXP"),("DCP1","MRPE1"),
             ("DCP2","MRPE2"),("DCP1","HHPE1"),("DCP2","HHPE2"),("MRPE1","MRPE2"),
             ("HHPE1","HHPE2"),("MRPE1","MRCE"),("MRPE2","MRCE")]:
    line(*C(a), *C(b), color=LINE, sw=1.6)

# ---- inter-zone connectors (the bridge story) ------------------------------
# eBGP Region A <-> Region B, conceptually via the PC1 bridge
poly([Er("MELP"), (520, 179), (660, 168), El("DCP1")], color=BRIDGE, sw=2.6, dash="8 5")
text(548, 150, "eBGP 64496 <-> 65002", size=11.5, fill=BRIDGE, bold=True)
# PE-CE Helix (PA-VM / vSRX) over the bridge to the HH-PE pair
poly([Er("BR"), (520, 389), (700, 470), El("HHPE2")], color=PALO, sw=2.4, dash="8 5")
poly([(Er("BR")[0], Er("BR")[1]-10), (540, 360), (720, 363), El("HHPE1")], color=PALO, sw=2.0, dash="2 5")
text(560, 470, "PE-CE eBGP (Helix) via bridge", size=11.5, fill=PALO, bold=True)
# RPKI-RTR -> first ROV enforcer (SYD = DC-P-R1)
poly([Er("RPKI"), (530, 464), (690, 250), Eb("DCP1")], color=MGMT, sw=2.0, dash="3 5")
text(560, 250, "RPKI-RTR -> ROV (SYD)", size=11, fill=MGMT, bold=True)

# ---- right-hand info panels ------------------------------------------------
def panel(x, y, w, h, header, rows, group="ref_top"):
    reg(group, x, y, w, h)
    rect(x, y, w, h, PANEL_BG, stroke=PANEL_BR, rx=10, sw=1.4)
    rect(x, y, w, 26, INK, rx=10, sw=0)
    rect(x, y + 13, w, 13, INK, rx=0, sw=0)
    text(x + 14, y + 18, header, size=12.5, fill="#ffffff", bold=True)
    yy = y + 46
    for k, v in rows:
        if k:
            text(x + 13, yy, k, size=12, fill="#334155", bold=True)
            text(x + 165, yy, v, size=12, fill=INK)
        else:
            text(x + 13, yy, v, size=12, fill=INK)
        yy += 21

PX, PW = 1240, 484
panel(PX, 92, PW, 186, "ADDRESSING  (disjoint from Region A)", [
    ("Carrier loopbacks", "10.0.20.0/24"),
    ("CE loopbacks", "10.0.21.0/24"),
    ("Backbone /31s", "10.255.20.0/24"),
    ("PE-CE /30s", "10.255.21.0/24"),
    ("IS-IS", "L2-only · area 49.0002 · wide"),
    ("MPLS", "LDP on all core /31s"),
])
panel(PX, 290, PW, 140, "BGP / AS", [
    ("Region B AS", "65002 (confed id 64496)"),
    ("RR cluster", "DC-P-R1 + DC-P-R2"),
    ("Inter-region", "eBGP 64496 <-> 65002"),
    ("Customer AS", "MR 64520 · HH 64521 · SRX 64522"),
])
panel(PX, 442, PW, 96, "VRF / RD-RT  (shared carrier space)", [
    ("Maple Ridge", "id 1 · RD/RT 64496:1"),
    ("Helix Health", "id 2 · RD/RT 64496:2"),
])
panel(PX, 550, PW, 214, "WHERE THINGS RUN  (the holistic answer)", [
    ("CML (Cisco)", "DC-P x2, MR/HH PE pairs, MR-CE"),
    ("CML (BYOI)", "JNX-P vJunos  — the ONLY upload"),
    ("PC1 vrnetlab", "HH-CE PA-VM 9.0.4  (bridged)"),
    ("Dell", "JNX-FW vSRX standalone  (bridged)"),
    ("PC1 local", "Aruba CX Helix LAN"),
    ("Region A", "Transit-A/B  (NOT Region B)"),
    ("PC1 Docker", "IXP FRR peers + Routinator"),
], group="ref_bot")
panel(PX, 776, PW, 140, "BUILD STATE  (2026-06-23)", [
    ("[x]", "config-as-code ops/region-b-cml/"),
    ("[x]", "holistic placement corrected"),
    ("[ ]", "reserve CML + openconnect bridge"),
    ("[ ]", "boot core -> verify -> bridge CEs"),
], group="ref_bot")

# ---- legend + footer -------------------------------------------------------
LY = 770
text(56, LY, "PLATFORM", size=13, fill=INK, bold=True)
legend = [("IOS XR", XR, "#fff"), ("Cat8000v XE", XE, "#07203a"), ("PA-VM", PALO, "#fff"),
          ("Juniper", JNX, "#fff"), ("Aruba", ARUBA, "#fff"), ("transit", TRANSIT, "#fff"),
          ("IXP FRR", IXP, "#fff"), ("bridge", BRIDGE, "#fff")]
lx = 150
for label, fill, fg in legend:
    rect(lx, LY - 13, 22, 15, fill, stroke="#cbd5e1", rx=4, sw=1)
    text(lx + 28, LY, label, size=11.5, fill=INK)
    lx += 44 + len(label) * 7.0
text(56, LY + 26, "Dashed = control-plane over the bridge   ·   gold dashed border = BYOI   ·   gold solid border = route-reflector",
     size=11.5, fill=GRAY)
text(56, LY + 48, "Only vJunos is a per-reservation CML upload (it can't boot on the triple-nested Dell). Everything else non-Cisco runs locally and bridges in.",
     size=11.5, fill="#334155")

text(34, H - 16, "aurora-comms · ops/region-b-cml/ (topology · addressing · MOP) · ADR-002 §3.2/§3.2.4 · ADR-003 §2.3 · PROPOSED — ratify before deploy",
     size=11.5, fill=GRAY)

doc = (f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" '
       f'viewBox="0 0 {W} {H}">\n' + "\n".join(s for s in svg if s) + "\n</svg>\n")
with open(OUT_SVG, "w", encoding="utf-8") as f:
    f.write(doc)
print("wrote", OUT_SVG)

# Semantic projector regions — boxes DERIVED from REG (the bbox each zone()/panel()/node()
# registered as it drew), so they auto-track the layout. Consumed by make_projector_slides.py.
for _g in ("topology", "ref_top", "ref_bot"):
    assert _g in REG, f"region group '{_g}' has no registered content — sidecar would be incomplete"
def _pad(*groups, p=8):  # bbox over one or more region groups, padded, clamped to canvas
    x0 = min(REG[g][0] for g in groups); y0 = min(REG[g][1] for g in groups)
    x1 = max(REG[g][2] for g in groups); y1 = max(REG[g][3] for g in groups)
    return [max(0, x0 - p), max(0, y0 - p), min(W, x1 + p), min(H, y1 + p)]
regions = {
    "canvas": [W, H],
    "slides": [
        {"name": "01-topology.png",
         "caption": "Region B - TOPOLOGY (Region A edge / PC1 bridge / CML reservation)",
         "box": [0, 0, PX - 12, min(H, REG["topology"][3] + 14)]},
        # native 1080p has the headroom to fit the whole reference column on ONE slide
        {"name": "02-reference.png",
         "caption": "Region B - REFERENCE: addressing / BGP-AS / VRF / where-things-run / build",
         "box": _pad("ref_top", "ref_bot")},
    ],
}
with open(OUT_REGIONS, "w", encoding="utf-8") as f:
    json.dump(regions, f, indent=2)
print("wrote", OUT_REGIONS, "(derived from geometry)")

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
d.scale(scale, scale)
d.width *= scale
d.height *= scale
renderPM.drawToFile(d, OUT_PNG, fmt="PNG", bg=0xFFFFFF)
print("wrote", OUT_PNG)
