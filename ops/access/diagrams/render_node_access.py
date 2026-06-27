#!/usr/bin/env python3
"""Render the PC3 -> GNS3 node access map as docs/pc3-node-access.{svg,png}.

Code-generated single source of truth, same stack + house style as
ops/region-a/diagrams/render_topology.py: every label is a code string here, so a
change is a one-line edit + re-run, and SVG/PNG can never disagree. Self-contained
raster via svglib + reportlab (Python 3.10). Emits a geometry-derived *.regions.json
sidecar so the projector pipeline can cut slides.

    python ops/access/diagrams/render_node_access.py

OUTPUT TARGET = 4K PRINT. Logical canvas is 1920x1080 (16:9), rasterised at
PRINT_SCALE=2.0 -> 3840x2160 PNG (4K UHD, ~230-330 DPI on A4/A3). Because this map
is sparse (a dozen boxes, not the wall-to-wall topology), fonts are sized for a
printed page, NOT borrowed from the dense topology diagram.

Shows how every lab node is reached from PC3 (Termius): ONE jump host -- the GNS3 VM,
gns3@100.118.0.46 over Tailscale -- with two methods:
  (1) SSH ProxyJump to the node OOB mgmt IP on 10.255.191.0/24 (day-to-day CLI), and
  (2) telnet to a GNS3 VM console port (bootstrap / break-glass on a blank node).
Mgmt IPs are the deployed values (README.md / aurora-deployment-status.md):
MEL-P .11, MEL-PE1 .12, GEL-PE1 .15, ADL-PE1 .17, transit-a .21, transit-b .22.
"""
import os
import json
from xml.sax.saxutils import escape

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
OUT_SVG = os.path.join(REPO, "docs", "pc3-node-access.svg")
OUT_PNG = os.path.join(REPO, "docs", "pc3-node-access.png")
OUT_REGIONS = os.path.join(REPO, "docs", "pc3-node-access.regions.json")

W, H = 1920, 1080
PRINT_SCALE = 2.0   # 1920x1080 logical -> 3840x2160 raster (4K UHD for print)
INK = "#0d2b4e"
XRV = "#1ba0d7"      # Region A IOS-XR P/PE
TRANSIT = "#6a1b9a"  # CSR / IOL-XE transit
JUMP = "#0e7490"     # GNS3 VM jump host
PC3C = "#455a64"     # PC3 terminal box
SSHC = "#1d4ed8"     # SSH ProxyJump path
TELC = "#b45309"     # telnet console path
LINE = "#64748b"
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
REG = {}  # accumulates the bbox of each projector-region group as elements are drawn
def reg(group, x, y, w, h):
    box = [x, y, x + w, y + h]
    b = REG.get(group)
    REG[group] = box if b is None else [min(b[0], x), min(b[1], y), max(b[2], x + w), max(b[3], y + h)]
def node(name, x, y, w, h, title, sub, line3, fill, fg="#ffffff", group="topology"):
    N[name] = (x, y, w, h)
    reg(group, x, y, w, h)
    rect(x, y, w, h, fill, stroke="#ffffff", rx=10, sw=1.4)
    cx = x + w / 2
    text(cx, y + 44, title, size=25, fill=fg, anchor="middle", bold=True)
    text(cx, y + 76, sub, size=16, fill=fg, anchor="middle")
    if line3:
        text(cx, y + 102, line3, size=16, fill=fg, anchor="middle")
def C(n): x,y,w,h=N[n]; return (x+w/2, y+h/2)
def Er(n): x,y,w,h=N[n]; return (x+w, y+h/2)
def El(n): x,y,w,h=N[n]; return (x, y+h/2)
def Et(n): x,y,w,h=N[n]; return (x+w/2, y)
def Eb(n): x,y,w,h=N[n]; return (x+w/2, y+h)
def lbl(x, y, s, color="#475569", size=18, bold=False): text(x, y, s, size=size, fill=color, anchor="middle", bold=bold)

# ---- background + title ----------------------------------------------------
rect(0, 0, W, H, "#ffffff", rx=0)
rect(0, 0, W, 92, INK, rx=0)
text(38, 42, "Aurora Communications - Reaching GNS3 nodes from PC3 (Termius)",
     size=32, fill="#ffffff", bold=True)
text(38, 76, "ONE jump host: GNS3 VM gns3@100.118.0.46 (Tailscale).    "
             "(1) SSH ProxyJump -> node mgmt 10.255.191.0/24 (day-to-day).    "
             "(2) telnet -> GNS3 VM console port (bootstrap / break-glass).",
     size=18, fill="#9db8d6")

# ---- origin + jump ---------------------------------------------------------
node("PC3", 55, 360, 360, 155, "PC3", "Termius - terminal box", "all access starts here", PC3C)
node("JUMP", 560, 345, 440, 185, "GNS3 VM  -  jump host", "gns3@100.118.0.46  -  Tailscale",
     "SSH ProxyJump + console host", JUMP)
text(780, 562, "holds 10.255.191.1 (tap-aurora-mgmt) -> reaches node mgmt directly",
     size=16, fill="#475569", anchor="middle")

# ---- node bands (destinations) ---------------------------------------------
def band(x, y, w, h, label, fill, stroke):
    reg("topology", x, y, w, h)
    rect(x, y, w, h, fill, stroke=stroke, rx=14, sw=1.8, op=0.5)
    text(x + 20, y + 34, label, size=20, fill=stroke, bold=True)
band(1050, 100, 810, 300, "Region A backbone - Cisco IOS-XRv 6.1.3   (mgmt 10.255.191.11-.17)", "#eff6ff", "#1d4ed8")
node("MELP",   1078, 152, 372, 110, "MEL-P",   "IOS-XRv 6.1.3 - P core", "mgmt .11  -  console in GNS3", XRV)
node("MELPE1", 1468, 152, 372, 110, "MEL-PE1", "IOS-XRv 6.1.3 - PE / ASBR", "mgmt .12  -  console in GNS3", XRV)
node("GEL",    1078, 274, 372, 110, "GEL-PE1", "IOS-XRv 6.1.3 - PE", "mgmt .15  -  console in GNS3", XRV)
node("ADL",    1468, 274, 372, 110, "ADL-PE1", "IOS-XRv 6.1.3 - PE", "mgmt .17  -  console in GNS3", XRV)
band(1050, 430, 810, 195, "Transit edge - Cisco IOS-XE   (mgmt 10.255.191.21-.22)", "#f5f3ff", "#7e22ce")
node("TA", 1078, 484, 372, 116, "transit-a-csr", "CSR1000v 16.08 - AS 64497", "mgmt .21  -  console :5009", TRANSIT)
node("TB", 1468, 484, 372, 116, "transit-b-iol", "IOL-XE 17.15 - AS 64498", "mgmt .22  -  console :5013", TRANSIT)

# ---- paths -----------------------------------------------------------------
# PC3 -> jump: (1) ssh solid, (2) telnet dashed
line(418, 420, 556, 420, SSHC, sw=4.5); lbl(487, 408, "(1) ssh -J", SSHC, bold=True)
line(418, 470, 556, 470, TELC, sw=4.5, dash="9 6"); lbl(487, 494, "(2) telnet", TELC, bold=True)
# jump -> node bands (both methods land via the GNS3 VM)
line(1002, 410, 1046, 240, SSHC, sw=3.4)
line(1002, 460, 1046, 300, SSHC, sw=3.4)
line(1002, 485, 1046, 520, TELC, sw=3.4, dash="9 6")
lbl(1024, 392, "10.255.191.x", "#334155", size=18, bold=True)
lbl(1024, 414, ":22 ssh  /  console telnet", "#334155", size=15)

# ---- reference panels ------------------------------------------------------
def panel(x, y, w, h, header, rows, hfill=INK, group="ref"):
    reg(group, x, y, w, h)
    rect(x, y, w, h, PANEL_BG, stroke=PANEL_BR, rx=12, sw=1.6)
    rect(x, y, w, 38, hfill, rx=12, sw=0); rect(x, y+19, w, 19, hfill, rx=0, sw=0)
    text(x + 18, y + 27, header, size=19, fill="#ffffff", bold=True)
    yy = y + 74
    for k, v in rows:
        if k: text(x + 18, yy, k, size=17, fill="#334155", bold=True); text(x + 230, yy, v, size=17, fill=INK)
        else: text(x + 18, yy, v, size=17, fill=INK)
        yy += 33
    return yy

panel(55, 660, 905, 300, "Connect (from a PC3 Termius session)", [
    ("", "(1) SSH - day-to-day, once the node has mgmt SSH:"),
    ("", "       ssh -J gns3@100.118.0.46 labadmin@10.255.191.21"),
    ("", "(2) Console - bootstrap / break-glass, works on a blank node:"),
    ("", "       telnet 100.118.0.46 5009"),
    ("Termius setup", "node Host = mgmt IP; Jump host = gns3@100.118.0.46"),
    ("Auth", "key -> jump    -    password -> node"),
], hfill=JUMP)
panel(980, 660, 460, 300, "Accounts (least-privilege)", [
    ("labadmin", "break-glass admin - every node"),
    ("IOS-XR read", "aurora-claude / aurora-codex"),
    ("IOS-XR write", "aurora-automation (cfg)"),
    ("", "aurora-security (crypto)"),
    ("Transit IOS-XE", "labadmin only (tiers TBD)"),
    ("Never", "reuse a credential"),
], hfill=INK)
panel(1460, 660, 405, 300, "Console ports (telnet GNS3 VM)", [
    ("transit-a-csr", ":5009"),
    ("transit-b-iol", ":5013"),
    ("IOS-XR nodes", "per-node - see GNS3"),
    ("Use when", "no SSH yet / locked out"),
    ("Then", "switch to SSH;"),
    ("", "console = break-glass"),
], hfill=TRANSIT)

# ---- legend ----------------------------------------------------------------
LY = 992
text(55, LY, "Legend", size=20, fill=INK, bold=True)
reg("ref", 55, LY - 16, 1810, 90)
line(170, LY - 6, 220, LY - 6, SSHC, sw=4.5); text(232, LY, "(1) SSH ProxyJump -> node mgmt :22", size=17, fill=INK)
line(640, LY - 6, 690, LY - 6, TELC, sw=4.5, dash="9 6"); text(702, LY, "(2) telnet -> GNS3 VM console port", size=17, fill=INK)
for i,(c,label) in enumerate([(JUMP,"GNS3 VM jump"), (XRV,"IOS-XRv P/PE"),
                              (TRANSIT,"transit IOS-XE"), (PC3C,"PC3 terminal")]):
    bx = 1120 + i*190
    rect(bx, LY - 18, 26, 18, c, stroke="#cbd5e1", rx=3, sw=1); text(bx + 32, LY, label, size=16, fill=INK)

# ---- guardrail footer ------------------------------------------------------
rect(55, LY + 24, 1810, 60, "#fff1f2", stroke="#be123c", rx=10)
reg("ref", 55, LY + 24, 1810, 60)
text(74, LY + 48, "Mgmt is OOB via MGMT-SW01 (10.255.191.0/24, demarc .1 on the GNS3 VM tap). The GNS3 VM "
     "(100.118.0.46) is the ONLY jump - PC3 never reaches a node directly.    "
     "Doc ASNs/IPs (RFC 5398/5737/3849); break-glass passwords live in Ansible Vault, not in this diagram.",
     size=16, fill="#881337", bold=True)

text(38, H - 18, "Generated by ops/access/diagrams/render_node_access.py  (4K print: 3840x2160)  -  "
     "jump gns3@100.118.0.46 (Tailscale)  -  mgmt 10.255.191.0/24 via MGMT-SW01  -  "
     "sources: README.md, docs/aurora-deployment-status.md, docs/adr-004",
     size=14, fill="#94a3b8")

# ---- write SVG -------------------------------------------------------------
doc = (f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">\n'
       + "\n".join(s for s in svg if s) + "\n</svg>\n")
with open(OUT_SVG, "w", encoding="utf-8") as f:
    f.write(doc)
print("wrote", OUT_SVG)

# ---- projector regions (geometry-derived, same contract as render_topology.py) ----
for _g in ("topology", "ref"):
    assert _g in REG, f"region group '{_g}' has no registered content - sidecar would be incomplete"
def _pad(*groups, p=12):
    x0 = min(REG[g][0] for g in groups); y0 = min(REG[g][1] for g in groups)
    x1 = max(REG[g][2] for g in groups); y1 = max(REG[g][3] for g in groups)
    return [max(0, x0 - p), max(0, y0 - p), min(W, x1 + p), min(H, y1 + p)]
regions = {
    "canvas": [W, H],
    "slides": [
        {"name": "01-access-paths.png",
         "caption": "PC3 -> GNS3 nodes - ACCESS PATHS (one jump host; SSH vs telnet console)",
         "box": [0, 0, W, min(H, REG["topology"][3] + 18)]},
        {"name": "02-reference.png",
         "caption": "Node access - REFERENCE: commands / accounts / console ports / legend",
         "box": _pad("ref")},
    ],
}
with open(OUT_REGIONS, "w", encoding="utf-8") as f:
    json.dump(regions, f, indent=2)
print("wrote", OUT_REGIONS, "(derived from geometry)")

# ---- raster to PNG at 4K (Python 3.10 deps) --------------------------------
try:
    from svglib.svglib import svg2rlg
    from reportlab.graphics import renderPM
except ModuleNotFoundError as e:
    print(f"SVG written OK. PNG step skipped - {e}.")
    print(r'The render deps live in Python 3.10. Run with that interpreter:')
    print(r'  "C:\Users\Elvis\AppData\Local\Programs\Python\Python310\python.exe" ' + os.path.basename(__file__))
    print(r'  (or:  python -m pip install --user svglib reportlab pycairo rlPyCairo  into THIS interpreter)')
    raise SystemExit(0)
d = svg2rlg(OUT_SVG)
# svg2rlg converts SVG px -> reportlab pt (x0.75), so d.width is ~0.75*W here. Scale to hit
# the true 4K target width exactly rather than trusting a fixed multiplier.
TARGET_W = int(W * PRINT_SCALE)   # 3840 = 4K UHD
scale = TARGET_W / d.width
d.scale(scale, scale); d.width *= scale; d.height *= scale
renderPM.drawToFile(d, OUT_PNG, fmt="PNG", bg=0xFFFFFF)
print("wrote", OUT_PNG, f"({int(round(d.width))}x{int(round(d.height))})")
