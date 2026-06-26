#!/usr/bin/env python3
"""Label the ops-lab GNS3 links with their IP addressing — the STANDARD for the live canvas.

Convention (keep it as the topology expands):
  * point-to-point links  -> the SUBNET at the link midpoint  (e.g. 10.255.0.0/31)
  * management links       -> the node's mgmt /24 host IP      (e.g. 10.255.191.17)

Idempotent: deletes prior IP labels (any drawing whose SVG contains "10.255.") and recreates,
so it is safe to re-run. AS-zone boxes/labels are untouched (they don't contain "10.255.").

TO EXPAND: add the new link to DATA_SUBNET / MGMT_IP below (keep in sync with
docs/region-a-plan.md S4 + ops/access/mops/2026-06-25-region-a-transit-edge-config.md) and re-run:
    python3 ops/access/gns3-label-links.py
"""
import json, urllib.request

B = "http://192.168.137.1:3080/v2"
PROJ = "d8119db0-dd43-4d20-870d-9d62fd6345f1"   # ops-lab

def req(method, p, body=None):
    data = json.dumps(body).encode() if body is not None else None
    r = urllib.request.Request(B + p, data=data, method=method, headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(r, timeout=10) as resp:
        t = resp.read().decode()
        return resp.status, (json.loads(t) if t.strip() else None)

def sid(n):
    if n.startswith('ADL'): return 'ADL'
    if n.startswith('GEL'): return 'GEL'
    if n.startswith('MEL-PE1'): return 'MEL-PE1'
    if n.startswith('MEL-P-'): return 'MEL-P'
    return {'transit-a-csr': 'ta', 'transit-b-iol': 'tb',
            'MGMT-SW01': 'SW', 'MGMT-CLOUD-TAP': 'TAP'}.get(n, n)

DATA_SUBNET = {
    frozenset(('MEL-P', 'MEL-PE1')): '10.255.0.0/31',
    frozenset(('MEL-PE1', 'GEL')):   '10.255.0.2/31',
    frozenset(('GEL', 'ADL')):       '10.255.0.4/31',
    frozenset(('ta', 'MEL-PE1')):    '10.255.2.0/30',
    frozenset(('tb', 'ADL')):        '10.255.2.4/30',
}
MGMT_IP = {'ADL': '10.255.191.17', 'GEL': '10.255.191.15', 'MEL-PE1': '10.255.191.12',
           'MEL-P': '10.255.191.11', 'ta': '10.255.191.21', 'tb': '10.255.191.22',
           'TAP': '10.255.191.1'}

ICON = 30  # half the GNS3 router icon -> approx icon centre from the stored top-left x/y

def ip_svg(text):
    # single <text> element + Verdana — the form GNS3 actually renders (a combined
    # <rect>+<text> SVG persists via the API but does NOT render on the canvas).
    w = len(text) * 8 + 8
    svg = (f'<svg width="{w}" height="22"><text x="2" y="16" font-family="Verdana" '
           f'font-size="12" font-weight="bold" fill="#1a4f8a">{text}</text></svg>')
    return svg, w

nodes = {n['node_id']: n for n in req("GET", f"/projects/{PROJ}/nodes")[1]}

# 1. clear prior IP labels (leave AS zones/labels intact)
for d in req("GET", f"/projects/{PROJ}/drawings")[1]:
    if '10.255.' in (d.get('svg') or ''):
        req("DELETE", f"/projects/{PROJ}/drawings/{d['drawing_id']}")

# 2. (re)create
for l in req("GET", f"/projects/{PROJ}/links")[1]:
    a, b = l['nodes']
    A, Bn = nodes[a['node_id']], nodes[b['node_id']]
    sa, sb = sid(A['name']), sid(Bn['name'])
    if 'SW' in (sa, sb):                                   # management link
        if sa == 'SW':
            rid, (rx, ry), (sx, sy) = sb, (Bn['x'], Bn['y']), (A['x'], A['y'])
        else:
            rid, (rx, ry), (sx, sy) = sa, (A['x'], A['y']), (Bn['x'], Bn['y'])
        text = MGMT_IP.get(rid)
        if not text:
            continue
        cx = rx + 0.30 * (sx - rx) + ICON                 # ~30% from the router, along the link
        cy = ry + 0.30 * (sy - ry) + ICON
    else:                                                 # point-to-point data link
        text = DATA_SUBNET.get(frozenset((sa, sb)))
        if not text:
            continue
        cx = (A['x'] + Bn['x']) / 2 + ICON                # midpoint
        cy = (A['y'] + Bn['y']) / 2 + ICON
    svg, w = ip_svg(text)
    st, _ = req("POST", f"/projects/{PROJ}/drawings",
                {"x": round(cx - w / 2), "y": round(cy - 9), "z": 2, "svg": svg})
    print(f"  {sa}<->{sb}: {text} @({round(cx-w/2)},{round(cy-9)}) [{st}]")
