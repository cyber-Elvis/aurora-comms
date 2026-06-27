#!/usr/bin/env python3
"""Render the Region A transit real-internet uplink topology.

Outputs:
  docs/region-a-transit-internet-topology.svg
  docs/region-a-transit-internet-topology.png
  docs/region-a-transit-internet-topology.regions.json

The PNG master is native 4K UHD (3840x2160). The sidecar follows the repo's
semantic projector-slide convention consumed by ops/diagrams/make_projector_slides.py.
"""
import json
import math
import os
import shutil
import subprocess
from xml.sax.saxutils import escape


HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
OUT_SVG = os.path.join(REPO, "docs", "region-a-transit-internet-topology.svg")
OUT_PNG = os.path.join(REPO, "docs", "region-a-transit-internet-topology.png")
OUT_REGIONS = os.path.join(REPO, "docs", "region-a-transit-internet-topology.regions.json")

W, H = 3840, 2160
INK = "#0d2b4e"
MUTED = "#64748b"
LINE = "#51657c"
DATA = "#1d4ed8"
FLOW = "#0f766e"
TRANSIT = "#6a1b9a"
PE = "#1ba0d7"
SWITCH = "#0f766e"
CLOUD = "#475569"
INTERNET = "#2563eb"
HOST = "#334155"
WARN = "#f59e0b"
DANGER = "#be123c"
PANEL_BG = "#f4f7fb"
PANEL_BR = "#c3d0e0"
FONT = "Helvetica"

svg = []
N = {}
REG = {}


def el(s):
    svg.append(s)


def reg(group, x, y, w, h):
    box = [x, y, x + w, y + h]
    b = REG.get(group)
    REG[group] = box if b is None else [
        min(b[0], box[0]),
        min(b[1], box[1]),
        max(b[2], box[2]),
        max(b[3], box[3]),
    ]


def rect(x, y, w, h, fill, stroke="none", rx=18, sw=2, dash=None, op=1.0):
    d = f' stroke-dasharray="{dash}"' if dash else ""
    el(
        f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{rx}" ry="{rx}" '
        f'fill="{fill}" fill-opacity="{op}" stroke="{stroke}" stroke-width="{sw}"{d}/>'
    )


def text(x, y, s, size=28, fill=INK, anchor="start", bold=False, italic=False):
    fw = ' font-weight="bold"' if bold else ""
    fs = ' font-style="italic"' if italic else ""
    el(
        f'<text x="{x}" y="{y}" font-family="{FONT},Arial,sans-serif" '
        f'font-size="{size}" fill="{fill}" text-anchor="{anchor}"{fw}{fs}>'
        f'{escape(s)}</text>'
    )


def line(x1, y1, x2, y2, color=LINE, sw=5, dash=None):
    d = f' stroke-dasharray="{dash}"' if dash else ""
    el(
        f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" '
        f'stroke="{color}" stroke-width="{sw}" stroke-linecap="round"{d}/>'
    )


def poly(points, color=LINE, sw=5, dash=None):
    d = f' stroke-dasharray="{dash}"' if dash else ""
    p = " ".join(f"{x},{y}" for x, y in points)
    el(
        f'<polyline points="{p}" fill="none" stroke="{color}" stroke-width="{sw}" '
        f'stroke-linecap="round" stroke-linejoin="round"{d}/>'
    )


def arrowhead(x1, y1, x2, y2, color=LINE, size=28):
    angle = math.atan2(y2 - y1, x2 - x1)
    a1 = angle + math.radians(155)
    a2 = angle - math.radians(155)
    p1 = (x2, y2)
    p2 = (x2 + size * math.cos(a1), y2 + size * math.sin(a1))
    p3 = (x2 + size * math.cos(a2), y2 + size * math.sin(a2))
    pts = " ".join(f"{round(x, 1)},{round(y, 1)}" for x, y in (p1, p2, p3))
    el(f'<polygon points="{pts}" fill="{color}"/>')


def path(points, color=LINE, sw=5, dash=None, arrow=True):
    poly(points, color=color, sw=sw, dash=dash)
    if arrow and len(points) >= 2:
        (x1, y1), (x2, y2) = points[-2], points[-1]
        arrowhead(x1, y1, x2, y2, color=color, size=max(22, sw * 5))


def label(x, y, s, fill=INK, size=24, bg="#ffffff"):
    pad_x = 16
    pad_y = 12
    # Width is approximate but stable enough for callouts.
    w = max(120, len(s) * size * 0.54 + pad_x * 2)
    h = size + pad_y * 2
    rect(x - w / 2, y - h + 8, w, h, bg, stroke="#d6e0ec", rx=10, sw=1)
    text(x, y, s, size=size, fill=fill, anchor="middle", bold=True)


def badge(x, y, s, fill=FLOW):
    rect(x - 28, y - 28, 56, 56, fill, stroke="#ffffff", rx=28, sw=4)
    text(x, y + 10, s, size=28, fill="#ffffff", anchor="middle", bold=True)


def node(name, x, y, w, h, title, lines, fill, fg="#ffffff", group="topology",
         stroke="#ffffff", dash=None, badge_text=None):
    N[name] = (x, y, w, h)
    reg(group, x, y, w, h)
    rect(x, y, w, h, fill, stroke=stroke, rx=20, sw=4 if badge_text else 2, dash=dash)
    text(x + w / 2, y + 44, title, size=31, fill=fg, anchor="middle", bold=True)
    yy = y + 84
    for ln in lines:
        text(x + w / 2, yy, ln, size=22, fill=fg, anchor="middle")
        yy += 31
    if badge_text:
        rect(x + w - 130, y + 14, 110, 34, WARN, stroke="#ffffff", rx=8, sw=2)
        text(x + w - 75, y + 39, badge_text, size=18, fill="#3a2a00", anchor="middle", bold=True)


def C(n):
    x, y, w, h = N[n]
    return (x + w / 2, y + h / 2)


def Er(n):
    x, y, w, h = N[n]
    return (x + w, y + h / 2)


def El(n):
    x, y, w, h = N[n]
    return (x, y + h / 2)


def Et(n):
    x, y, w, h = N[n]
    return (x + w / 2, y)


def Eb(n):
    x, y, w, h = N[n]
    return (x + w / 2, y + h)


def band(x, y, w, h, title, subtitle, fill, stroke):
    reg("topology", x, y, w, h)
    rect(x, y, w, h, fill, stroke=stroke, rx=26, sw=3, op=0.52)
    text(x + 28, y + 46, title, size=30, fill=stroke, bold=True)
    text(x + 28, y + 82, subtitle, size=22, fill=MUTED)


def panel(x, y, w, h, title, rows, group="reference", header=INK):
    reg(group, x, y, w, h)
    rect(x, y, w, h, PANEL_BG, stroke=PANEL_BR, rx=20, sw=3)
    rect(x, y, w, 62, header, rx=20, sw=0)
    rect(x, y + 34, w, 28, header, rx=0, sw=0)
    text(x + 28, y + 42, title, size=28, fill="#ffffff", bold=True)
    yy = y + 106
    for key, val in rows:
        if key:
            text(x + 28, yy, key, size=23, fill="#334155", bold=True)
            text(x + 280, yy, val, size=23, fill=INK)
        else:
            text(x + 28, yy, val, size=23, fill=INK)
        yy += 42


# Canvas and title.
rect(0, 0, W, H, "#ffffff", rx=0)
rect(0, 0, W, 156, INK, rx=0)
text(64, 62, "Aurora Region A - Transit Real-Internet Uplink", size=50, fill="#ffffff", bold=True)
text(
    64,
    112,
    "Verified 2026-06-27: GNS3 VM eth1 -> INET-SW -> Transit-A/B DHCP outside interfaces -> NAT/PAT",
    size=26,
    fill="#b8d4f2",
)

# Layout bands.
band(70, 220, 610, 1430, "Upstream internet", "VMware/host NAT plus real DNS reachability", "#eff6ff", INTERNET)
band(730, 220, 620, 1430, "GNS3 VM handoff", "Corrected from eth0 to eth1", "#f8fafc", HOST)
band(1400, 220, 560, 1430, "GNS3 project", "Cloud node plus INET-SW L2 segment", "#ecfdf5", SWITCH)
band(2010, 220, 650, 1430, "Transit edge", "IOS-XE NAT boundary and DHCP outside", "#f5f3ff", TRANSIT)

# Nodes.
node("INET", 145, 350, 460, 170, "Public Internet", ["reachable probes", "1.1.1.1 and 8.8.8.8"], INTERNET)
node("GW", 145, 650, 460, 160, "Upstream NAT gateway", ["192.168.191.2", "default next hop for transit"], HOST)
node("ETH1", 790, 575, 500, 165, "GNS3 VM eth1", ["192.168.191.0/24", "actual default path"], HOST, badge_text="ACTIVE")
node("ETH0", 790, 980, 500, 145, "GNS3 VM eth0", ["192.168.20.128/24", "no default route"], "#7f1d1d", dash="12 8", badge_text="NOT USED")
node("CLOUD", 1465, 570, 430, 155, "INET-UPLINK-eth1", ["GNS3 Cloud node", "bound to VM eth1"], CLOUD)
node("SW", 1465, 935, 430, 170, "INET-SW", ["L2 fanout switch", "E0 cloud, E1/E2 transit"], SWITCH)
node("TA", 2075, 465, 515, 230, "transit-a-csr", ["CSR1000v AS 64497", "Gi3 outside: 192.168.191.129 DHCP", "Gi2 inside: 10.255.2.2/30"], TRANSIT)
node("TB", 2075, 1035, 515, 230, "transit-b-iol", ["IOL-XE AS 64498", "E0/2 outside: 192.168.191.130 DHCP", "E0/0 inside: 10.255.2.6/30"], TRANSIT)
node("MEL", 2225, 755, 365, 150, "MEL-PE1", ["Aurora AS 64496", "toward Transit-A"], PE)
node("ADL", 2225, 1325, 365, 150, "ADL-PE1", ["Aurora AS 64496", "toward Transit-B"], PE)

# Flow links: egress direction from Aurora toward the internet.
path([Er("MEL"), (2675, 830), (2675, 580), Er("TA")], color=DATA, sw=6, dash="14 10", arrow=False)
path([El("TA"), (1960, 580), (1960, 1020), Er("SW")], color=FLOW, sw=7)
path([Er("ADL"), (2675, 1400), (2675, 1150), Er("TB")], color=DATA, sw=6, dash="14 10", arrow=False)
path([El("TB"), (1960, 1150), (1960, 1020), Er("SW")], color=FLOW, sw=7)
path([El("SW"), Er("CLOUD")], color=FLOW, sw=7)
path([El("CLOUD"), Er("ETH1")], color=FLOW, sw=7)
path([El("ETH1"), Er("GW")], color=FLOW, sw=7)
path([Et("GW"), Eb("INET")], color=FLOW, sw=7)
line(Et("ETH0")[0], Et("ETH0")[1] - 40, Eb("ETH0")[0], Eb("ETH0")[1] + 40, color=DANGER, sw=10)
line(El("ETH0")[0] - 40, C("ETH0")[1], Er("ETH0")[0] + 40, C("ETH0")[1], color=DANGER, sw=10)

# Link labels and numbered path hints.
badge(2600, 830, "1", DATA)
label(2425, 795, "Transit-A primary egress", fill=DATA, size=19)
badge(2600, 1400, "1", DATA)
label(2425, 1365, "Transit-B backup egress", fill=DATA, size=19)
badge(1980, 885, "2", FLOW)
label(1805, 865, "PAT at transit, then DHCP outside link to INET-SW", fill=FLOW, size=22)
badge(1330, 650, "3", FLOW)
label(1268, 535, "GNS3 Cloud exposes VM eth1 into the project", fill=FLOW, size=22)
badge(650, 730, "4", FLOW)
label(640, 615, "Default route resolves through 192.168.191.2", fill=FLOW, size=22)

# NAT boundary callout.
rect(2045, 355, 580, 1010, "#ffffff", stroke="#c4b5fd", rx=24, sw=3, dash="12 8", op=0.35)
text(2075, 382, "NAT boundary", size=28, fill=TRANSIT, bold=True)
text(2075, 418, "inside: PE-facing /30, outside: DHCP 192.168.191.0/24", size=22, fill=TRANSIT)
rect(2110, 720, 465, 92, "#ffffff", stroke="#ddd6fe", rx=14, sw=2)
text(2342, 754, "AURORA-LAB-NAT ACL", size=22, fill=TRANSIT, anchor="middle", bold=True)
text(2342, 784, "RFC1918 plus lab documentation prefixes", size=19, fill=TRANSIT, anchor="middle")

# BGP caveat near PE side.
rect(2015, 1520, 645, 150, "#fff7ed", stroke=WARN, rx=18, sw=3)
text(2045, 1562, "Current caveat", size=29, fill="#92400e", bold=True)
text(2045, 1602, "Transit-node internet is verified.", size=21, fill="#92400e")
text(2045, 1633, "PE/customer internet still depends on transit eBGP.", size=21, fill="#92400e")
text(2045, 1664, "Latest transit output said BGP not active.", size=21, fill="#92400e")

# Reference panels.
PX, PW = 2730, 1035
panel(PX, 220, PW, 330, "Verified outside interfaces", [
    ("Transit-A", "Gi3 192.168.191.129/24 DHCP up/up"),
    ("Transit-B", "E0/2 192.168.191.130/24 DHCP up/up"),
    ("Gateway", "0.0.0.0/0 via 192.168.191.2"),
    ("DNS probes", "1.1.1.1 and 8.8.8.8 both 5/5"),
    ("NAT stats", "PAT active; translations seen during pings"),
], header=FLOW)
panel(PX, 585, PW, 330, "IOS-XE role mapping", [
    ("Transit-A inside", "Gi2 to MEL-PE1, ip nat inside"),
    ("Transit-A outside", "Gi3 to INET-SW, ip nat outside"),
    ("Transit-B inside", "E0/0 to ADL-PE1, ip nat inside"),
    ("Transit-B outside", "E0/2 to INET-SW, ip nat outside"),
    ("ACL", "AURORA-LAB-NAT: RFC1918 + 192.0.2/198.51.100/203.0.113"),
], header=TRANSIT)
panel(PX, 950, PW, 290, "Automation/control path", [
    ("Control node", "PC1 WSL Ubuntu, user fourty3"),
    ("Repo path", "/mnt/d/CyberLab/Repos/aurora-comms"),
    ("Ansible tree", "ops/automation-iosxe/"),
    ("Jump", "gns3@100.118.0.46 -> 10.255.191.21/.22"),
], header=HOST)
panel(PX, 1275, PW, 290, "Boundaries and next stage", [
    ("IPv4", "Real internet uplink is IPv4-only in this stage"),
    ("IPv6", "Existing mock Null0 default remains unchanged"),
    ("Downstream", "PE/customer tests wait on active transit eBGP"),
    ("Old path", "eth0 was removed from the GNS3 internet cloud"),
], header=WARN)

# Legend.
rect(70, 1725, 2590, 250, "#f8fafc", stroke="#d6e0ec", rx=24, sw=3)
text(105, 1775, "Legend", size=30, fill=INK, bold=True)
legend = [
    ("Aurora/PE data plane", DATA),
    ("Real internet egress path", FLOW),
    ("IOS-XE transit routers", TRANSIT),
    ("GNS3 cloud/switch/host", CLOUD),
    ("Warning or not currently active", WARN),
]
lx = 105
ly = 1832
for name, color in legend:
    rect(lx, ly - 28, 54, 32, color, stroke="#d6e0ec", rx=8, sw=2)
    text(lx + 72, ly, name, size=23, fill=INK)
    lx += 505
line(105, 1898, 185, 1898, color=FLOW, sw=7)
arrowhead(145, 1898, 185, 1898, color=FLOW, size=30)
text(205, 1907, "Arrow direction shows Aurora traffic egress toward the real internet; return traffic follows the reverse NAT path.", size=23, fill=INK)
line(105, 1948, 185, 1948, color=DATA, sw=6, dash="14 10")
text(205, 1957, "Dashed blue links are PE-to-transit eBGP/data-plane dependencies, not re-verified as active in this transit-only closure.", size=23, fill=INK)

# Footer.
text(
    64,
    2115,
    "Generated by ops/region-a/diagrams/render_transit_internet_topology.py - master PNG is 3840x2160 - source: 2026-06-27 real-internet MOP",
    size=20,
    fill="#94a3b8",
)


doc = (
    f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" '
    f'viewBox="0 0 {W} {H}">\n'
    + "\n".join(svg)
    + "\n</svg>\n"
)
with open(OUT_SVG, "w", encoding="utf-8") as f:
    f.write(doc)
print("wrote", OUT_SVG)

for group in ("topology", "reference"):
    assert group in REG, f"region group {group!r} has no registered content"


def pad(*groups, p=22):
    x0 = min(REG[g][0] for g in groups)
    y0 = min(REG[g][1] for g in groups)
    x1 = max(REG[g][2] for g in groups)
    y1 = max(REG[g][3] for g in groups)
    return [max(0, x0 - p), max(0, y0 - p), min(W, x1 + p), min(H, y1 + p)]


regions = {
    "canvas": [W, H],
    "slides": [
        {
            "name": "01-topology.png",
            "caption": "Region A transit internet - topology and egress path",
            "box": [70, 220, 2660, 1670],
        },
        {
            "name": "02-reference-interfaces.png",
            "caption": "Region A transit internet - verified interfaces and IOS-XE role mapping",
            "box": [2708, 198, 3787, 937],
        },
        {
            "name": "03-reference-operations.png",
            "caption": "Region A transit internet - automation path and remaining boundaries",
            "box": [2708, 928, 3787, 1587],
        },
    ],
}
with open(OUT_REGIONS, "w", encoding="utf-8") as f:
    json.dump(regions, f, indent=2)
print("wrote", OUT_REGIONS)

def render_png_with_sharp():
    user_home = os.path.expanduser("~")
    bundled_node_root = os.path.join(
        user_home,
        ".cache",
        "codex-runtimes",
        "codex-primary-runtime",
        "dependencies",
        "node",
    )
    node_candidates = [
        os.environ.get("AURORA_NODE"),
        shutil.which("node"),
        os.path.join(bundled_node_root, "bin", "node.exe"),
    ]
    node_candidates = [p for p in node_candidates if p and os.path.exists(p)]
    node_modules = os.path.join(bundled_node_root, "node_modules")
    pnpm_modules = os.path.join(node_modules, ".pnpm", "node_modules")
    js = """
require('module').Module._initPaths();
const sharp = require('sharp');
const [svg, png] = process.argv.slice(1);
sharp(svg).resize(3840, 2160, { fit: 'fill' }).png().toFile(png)
  .then(() => console.log('wrote ' + png))
  .catch((e) => { console.error(e); process.exit(1); });
"""
    env = os.environ.copy()
    env["NODE_PATH"] = os.pathsep.join(
        p for p in [env.get("NODE_PATH"), node_modules, pnpm_modules] if p
    )
    for node_exe in node_candidates:
        try:
            subprocess.run([node_exe, "-e", js, OUT_SVG, OUT_PNG], check=True, env=env)
            return True
        except (OSError, subprocess.CalledProcessError):
            continue
    return False


try:
    from svglib.svglib import svg2rlg
    from reportlab.graphics import renderPM
except ModuleNotFoundError as e:
    if render_png_with_sharp():
        raise SystemExit(0)
    print(f"SVG and regions written OK. PNG skipped: {e}")
    raise SystemExit(0)

d = svg2rlg(OUT_SVG)
renderPM.drawToFile(d, OUT_PNG, fmt="PNG", bg=0xFFFFFF)
print("wrote", OUT_PNG)
