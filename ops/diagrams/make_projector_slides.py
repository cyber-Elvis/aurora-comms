#!/usr/bin/env python3
"""Make projector-ready 1920x1080 slides from ANY diagram (SVG or PNG).

Generic companion to the hand-tuned ops/region-a/diagrams/build_projector_assets.py: that one
knows Region A's exact layout and cuts content-aligned slides; THIS one auto-tiles any image so
that fine text clears ~18px on a ~720p-class projector panel (the VOPLLS Q5 the lab uses). Use it
for Region B, the automation-architecture diagram, or any ad-hoc screenshot you want on the wall.

    py -3.10 ops/diagrams/make_projector_slides.py docs/region-b-topology.svg
    py -3.10 ops/diagrams/make_projector_slides.py docs/region-a-automation-architecture.png --zoom 2.2

Output: docs/projector/<name>/{00-overview, 01-..., ...}.png   (name defaults to the file stem
minus '-topology'). Send the PNGs to your phone (Phone Link "Send to My Phone") and cast.
Needs the py3.10 interpreter with pillow (plus svglib + reportlab when the input is an SVG).
"""
import os
import sys
import json
import math
import argparse
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
PW, PH = 1920, 1080
WHITE, BLACK, INK = (255, 255, 255), (0, 0, 0), (13, 43, 78)

def font(sz, bold=False):
    p = r"C:\Windows\Fonts\arialbd.ttf" if bold else r"C:\Windows\Fonts\arial.ttf"
    try:
        return ImageFont.truetype(p, sz)
    except OSError:
        return ImageFont.load_default()

def load_master(path, render_scale):
    """Return a high-res RGB master. SVG is rendered at render_scale; PNG is used as-is."""
    if os.path.splitext(path)[1].lower() == ".svg":
        from svglib.svglib import svg2rlg
        from reportlab.graphics import renderPM
        tmp = path + ".master.png"
        d = svg2rlg(path)
        d.scale(render_scale, render_scale); d.width *= render_scale; d.height *= render_scale
        renderPM.drawToFile(d, tmp, fmt="PNG", bg=0xFFFFFF)
        m = Image.open(tmp).convert("RGB")
        os.remove(tmp)
        return m
    return Image.open(path).convert("RGB")

def positions(total, tile, overlap):
    """Even tile start coords covering [0,total] with >= `overlap` fraction overlap."""
    if tile >= total:
        return [0]
    stride = tile * (1 - overlap)
    n = math.ceil((total - tile) / stride) + 1
    step = (total - tile) / (n - 1)
    return [round(i * step) for i in range(n)]

def band(idx, n, two, three):
    if n == 1:
        return ""
    if n == 2:
        return two[idx]
    if n == 3:
        return three[idx]
    return str(idx + 1)

def validate_regions(spec, W, H, path):
    """Validate a regions sidecar against the rendered master; return (scale_x, scale_y).
    Fails LOUDLY (SystemExit) naming the sidecar + offending slide — never silently mis-crops."""
    def die(msg):
        sys.exit(f"ERROR in regions sidecar {path}: {msg}")
    if "canvas" not in spec or len(spec["canvas"]) != 2:
        die("missing required 'canvas': [width, height] in the diagram's native units")
    if not spec.get("slides"):
        die("missing or empty 'slides'")
    cw, ch = spec["canvas"]
    if cw <= 0 or ch <= 0:
        die(f"bad canvas {cw}x{ch}")
    if abs((cw / ch) / (W / H) - 1) > 0.02:    # master must share the declared canvas aspect
        die(f"canvas aspect {cw}x{ch} != rendered master {W}x{H} — set 'canvas' to the diagram's true size")
    seen = set()
    for i, sl in enumerate(spec["slides"]):
        for k in ("name", "caption", "box"):
            if k not in sl:
                die(f"slide #{i} missing '{k}'")
        if sl["name"] in seen:
            die(f"duplicate slide name '{sl['name']}'")
        seen.add(sl["name"])
        b = sl["box"]
        if len(b) != 4:
            die(f"slide '{sl['name']}' box needs 4 numbers [x0,y0,x1,y1], got {b}")
        x0, y0, x1, y1 = b
        if not (0 <= x0 < x1 <= cw and 0 <= y0 < y1 <= ch):
            die(f"slide '{sl['name']}' box {b} is inverted or outside canvas {cw}x{ch}")
    return W / cw, H / ch

def slide(crop, caption, path):
    cap_h = 56
    avail_w, avail_h = PW, PH - cap_h
    r = min(avail_w / crop.width, avail_h / crop.height)
    nw, nh = int(crop.width * r), int(crop.height * r)
    crop = crop.resize((nw, nh), Image.LANCZOS)
    canvas = Image.new("RGB", (PW, PH), WHITE)
    d = ImageDraw.Draw(canvas)
    d.rectangle([0, 0, PW, cap_h], fill=INK)
    d.text((24, 12), caption, font=font(30, True), fill=WHITE)
    canvas.paste(crop, ((PW - nw) // 2, cap_h + (avail_h - nh) // 2))
    canvas.save(path)
    print("wrote", path)

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("input", help="SVG or PNG, repo-relative or absolute")
    ap.add_argument("--name", help="output subfolder name (default: file stem minus -topology)")
    ap.add_argument("--zoom", type=float, default=2.0, help="zoom factor for tiles (2.0 -> ~18px text on a 720p panel)")
    ap.add_argument("--overlap", type=float, default=0.12, help="fractional overlap between tiles")
    ap.add_argument("--render-scale", type=float, default=4.0, help="SVG render scale for the master")
    ap.add_argument("--regions", help="regions JSON for a semantic split (default: <input-stem>.regions.json if present)")
    ap.add_argument("--out", help="output dir (default docs/projector/<name>)")
    a = ap.parse_args()

    inp = a.input if os.path.isabs(a.input) else os.path.join(REPO, a.input)
    if not os.path.exists(inp):
        sys.exit(f"ERROR: input not found: {inp}")
    name = a.name or os.path.splitext(os.path.basename(inp))[0].replace("-topology", "")
    out = a.out or os.path.join(REPO, "docs", "projector", name)
    os.makedirs(out, exist_ok=True)

    m = load_master(inp, a.render_scale)
    W, H = m.size

    # --- SEMANTIC mode: a sidecar <stem>.regions.json (or --regions) declares named crops ---
    regions_path = a.regions or (os.path.splitext(inp)[0] + ".regions.json")
    if os.path.exists(regions_path):
        with open(regions_path, encoding="utf-8") as f:
            spec = json.load(f)
        sx, sy = validate_regions(spec, W, H, regions_path)   # fails LOUDLY on a bad sidecar
        print(f"master {W}x{H}  name={name}  SEMANTIC ({len(spec['slides'])} slides "
              f"from {os.path.basename(regions_path)})")
        slide(m, f"{name} - OVERVIEW (map only - read the content slides)", os.path.join(out, "00-overview.png"))
        for sl in spec["slides"]:
            x0, y0 = int(sl["box"][0] * sx), int(sl["box"][1] * sy)
            x1, y1 = int(sl["box"][2] * sx), int(sl["box"][3] * sy)
            slide(m.crop((min(x0, W), min(y0, H), min(x1, W), min(y1, H))),
                  sl["caption"], os.path.join(out, sl["name"]))
        print(f"\n{len(spec['slides'])} semantic slides + overview in {out}")
        return

    # --- GRID fallback: auto-tile any image that has no declared regions ---
    print(f"master {W}x{H}  name={name}  GRID zoom={a.zoom:g}x")
    slide(m, f"{name} - OVERVIEW (step back)", os.path.join(out, "00-overview.png"))

    tw = int(W / a.zoom); th = int(tw * 9 / 16)
    if th > H:                      # don't let a tile be taller than the image
        th = H; tw = int(th * 16 / 9)
    xs = positions(W, tw, a.overlap)
    ys = positions(H, th, a.overlap)
    i = 1
    for r, y in enumerate(ys):
        rw = band(r, len(ys), ["top", "bottom"], ["top", "mid", "bottom"])
        for c, x in enumerate(xs):
            cw = band(c, len(xs), ["left", "right"], ["left", "center", "right"])
            pos = "-".join([p for p in (rw, cw) if p]) or "full"
            crop = m.crop((x, y, min(x + tw, W), min(y + th, H)))
            slide(crop, f"{name} - zoom {a.zoom:g}x - {pos} (R{r+1}C{c+1})",
                  os.path.join(out, f"{i:02d}-{pos}.png"))
            i += 1
    print(f"\n{i-1} zoom tiles + overview in {out}")

if __name__ == "__main__":
    main()
