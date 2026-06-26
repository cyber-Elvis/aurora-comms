#!/usr/bin/env python3
"""Build projector assets for Region A: refresh the topology, emit the native-resolution test
pattern, and slice the diagram into readable 1920x1080 tiles via the shared generic tiler.

    py -3.10 ops/region-a/diagrams/build_projector_assets.py            # render + test + tiles
    py -3.10 ops/region-a/diagrams/build_projector_assets.py --no-render # skip the re-render

Outputs:
  docs/projector/00-native-1080p-test.png   native-resolution / focus / contrast test pattern
  docs/projector/region-a/                   overview + 01..09 readable zoom tiles

Region A and Region B now use the SAME generic tiler (ops/diagrams/make_projector_slides.py),
so both regions are identical in layout: 00-overview (a map) + 01..09 readable tiles. Needs the
py3.10 interpreter with pillow (+ svglib + reportlab for the render and tiler steps).
"""
import os
import sys
import subprocess
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
SVG  = os.path.join(REPO, "docs", "region-a-topology.svg")
OUT  = os.path.join(REPO, "docs", "projector")
RENDER = os.path.join(HERE, "render_topology.py")
TILER  = os.path.join(REPO, "ops", "diagrams", "make_projector_slides.py")
os.makedirs(OUT, exist_ok=True)

PW, PH = 1920, 1080          # projector native panel (16:9)
WHITE, BLACK = (255, 255, 255), (0, 0, 0)

def font(sz, bold=False):
    p = r"C:\Windows\Fonts\arialbd.ttf" if bold else r"C:\Windows\Fonts\arial.ttf"
    try:
        return ImageFont.truetype(p, sz)
    except OSError:
        return ImageFont.load_default()

# ---------------------------------------------------------------------------
# Native 1080p test pattern (the one projector asset that isn't a diagram slice)
# ---------------------------------------------------------------------------
def native_test():
    im = Image.new("RGB", (PW, PH), WHITE)
    d = ImageDraw.Draw(im)

    d.rectangle([0, 0, PW - 1, PH - 1], outline=BLACK, width=1)
    d.rectangle([1, 1, PW - 2, PH - 2], outline=BLACK, width=1)
    for (cx, cy, sx, sy) in [(8, 8, 1, 1), (PW - 9, 8, -1, 1), (8, PH - 9, 1, -1), (PW - 9, PH - 9, -1, -1)]:
        d.line([cx, cy, cx + sx * 60, cy], fill=BLACK, width=3)
        d.line([cx, cy, cx, cy + sy * 60], fill=BLACK, width=3)

    d.text((40, 24), "1920 x 1080  NATIVE-RESOLUTION TEST", font=font(34, True), fill=BLACK)
    d.text((40, 66), "Valid ONLY over HDMI at 1920x1080, 100% scale, actual-size 1:1 (NOT WiFi cast).",
           font=font(20), fill=BLACK)
    d.text((40, 90), "1px line blocks must be CLEAN sharp stripes. Wavy/grey/moire -> panel is upscaling (720p).",
           font=font(20), fill=(180, 0, 0))

    vx0, vy0, vw, vh = 40, 140, 560, 150
    for x in range(vx0, vx0 + vw, 2):
        d.line([x, vy0, x, vy0 + vh], fill=BLACK, width=1)
    d.text((vx0, vy0 + vh + 6), "1px vertical on/off", font=font(18, True), fill=BLACK)

    hx0, hy0, hw, hh = 650, 140, 560, 150
    for y in range(hy0, hy0 + hh, 2):
        d.line([hx0, y, hx0 + hw, y], fill=BLACK, width=1)
    d.text((hx0, hy0 + hh + 6), "1px horizontal on/off", font=font(18, True), fill=BLACK)

    cx0, cy0, cs = 1260, 140, 150
    for yy in range(0, cs):
        for xx in range(0, cs):
            if (xx + yy) % 2 == 0:
                im.putpixel((cx0 + xx, cy0 + yy), BLACK)
    d.text((cx0, cy0 + cs + 6), "1px checkerboard", font=font(18, True), fill=BLACK)

    dx0, dy0, ds = 1480, 140, 380
    for k in range(-ds, ds, 8):
        d.line([dx0 + k, dy0, dx0 + k + ds, dy0 + ds], fill=BLACK, width=1)
    d.text((dx0, dy0 + ds + 6), "1px diagonals (watch for jaggies)", font=font(18, True), fill=BLACK)

    ty = 470
    d.text((40, ty - 30), "TEXT LEGIBILITY RAMP  (smallest line you can read = your usable label size):",
           font=font(20, True), fill=BLACK)
    sample = "ADL-PE1  lo 10.0.0.2  eBGP 64497->64496  10.255.2.0/30  iBGP VPNv4 next-hop-self"
    for sz in (10, 12, 14, 16, 18, 22, 28):
        d.text((40, ty), f"{sz:>2}px  {sample}", font=font(sz), fill=BLACK)
        ty += sz + 12

    gx, gy, gw, gh = 40, ty + 20, 1840, 60
    steps = 16
    for i in range(steps):
        v = int(255 * i / (steps - 1))
        d.rectangle([gx + i * gw // steps, gy, gx + (i + 1) * gw // steps, gy + gh], fill=(v, v, v))
    d.text((gx, gy + gh + 6), "Greyscale: in a dim room you should distinguish the darkest 2-3 steps from black.",
           font=font(18), fill=BLACK)

    cyb = gy + gh + 40
    bars = [("XRv", (27,160,215)), ("SYD", (21,101,192)), ("transit", (106,27,154)),
            ("FRR", (13,148,136)), ("Forti", (238,49,36)), ("Aruba", (249,115,22)),
            ("workload", (253,224,71)), ("mgmt", (69,90,100))]
    bw = 1840 // len(bars)
    for i, (lbl, col) in enumerate(bars):
        x = 40 + i * bw
        d.rectangle([x, cyb, x + bw - 4, cyb + 70], fill=col)
        tcol = (0,0,0) if sum(col) > 450 else (255,255,255)
        d.text((x + 8, cyb + 24), lbl, font=font(20, True), fill=tcol)
    d.text((40, cyb + 76), "Node colors -- should look distinct (not muddy) and white/black text on them should be readable.",
           font=font(18), fill=BLACK)

    d.line([PW//2 - 40, PH//2, PW//2 + 40, PH//2], fill=(180,0,0), width=1)
    d.line([PW//2, PH//2 - 40, PW//2, PH//2 + 40], fill=(180,0,0), width=1)

    path = os.path.join(OUT, "00-native-1080p-test.png")
    im.save(path)
    print("wrote", path, im.size)

def maybe_render_topology():
    """Re-run render_topology.py with this interpreter so the SVG reflects the latest edit."""
    try:
        subprocess.run([sys.executable, RENDER], check=True)
    except (subprocess.CalledProcessError, OSError) as e:
        print(f"WARNING: render_topology.py did not run ({e}); using existing {SVG}.")

if __name__ == "__main__":
    if "--no-render" not in sys.argv:
        maybe_render_topology()
    if not os.path.exists(SVG):
        sys.exit(f"ERROR: {SVG} not found -- run render_topology.py first (needs svglib+reportlab).")
    native_test()
    # Region A slides via the shared generic tiler (zoom 2.0 == identical layout to region-b/)
    subprocess.run([sys.executable, TILER, SVG, "--name", "region-a", "--zoom", "2.0"], check=True)
    print("\nAll Region A projector assets in", OUT)
