# Projector assets — lab diagrams

1920×1080 (16:9) PNGs for viewing the lab diagrams on the lab mini-projector (VOPLLS Q5,
~720p-effective panel) in a dim room. The master diagrams are dense single canvases with
9–13px labels — unreadable when projected whole — so each is split into native-panel slides
with enlarged text (smallest label clears ~18px, the confirmed "perfect" size on this panel:
18px = perfect, 12px = readable, 10px = too small).

**Getting a slide onto the projector:** send the PNG to the iPhone via Windows Phone Link
(right-click image → *Send to My Phone* → lands in Photos), then cast with the TV Casting app
+ the projector's FileShare. WiFi cast is lossy (softens text) — **HDMI is crispest**.

## Layout — every diagram gets a `<name>/` subfolder, identical structure
```
docs/projector/
  00-native-1080p-test.png   test pattern (generic; not a diagram)
  region-a/   00-overview + 01..09 zoom tiles
  region-b/   00-overview + 01..09 zoom tiles
  region-a-automation/  00-overview + zoom tiles
```
- **`00-overview.png`** in each folder = the whole diagram letterboxed — a "where am I" **map
  only; its text is NOT meant to be read** (denser diagrams like Region A look worse here —
  that's inherent, not a bug). **Read from the numbered tiles, not the overview.**
- **`01-…` onward** = overlapping zoom tiles (~2×), text enlarged to clear ~18px. Named by
  grid position (`top/mid/bottom` × `left/center/right`).

Region A and Region B use the **same generic tiler**, so both are laid out identically.

## Regenerate
```
# Region A (re-renders the diagram first, then the test pattern + tiles):
py -3.10 ops/region-a/diagrams/build_projector_assets.py
py -3.10 ops/region-a/diagrams/build_projector_assets.py --no-render   # skip the re-render

# Any other diagram / ad-hoc image (the generic tiler):
py -3.10 ops/diagrams/make_projector_slides.py docs/region-b-topology.svg
py -3.10 ops/diagrams/make_projector_slides.py path/to/any-image.png --name my-diagram --zoom 2.2
```
SVG inputs render crisp at any zoom; PNG inputs are limited by their own resolution. Output
goes to `docs/projector/<name>/`. `--zoom 2.0` ≈ 18px text on the ~720p panel; raise it for
bigger text (more tiles). Needs py3.10 with pillow (+ svglib + reportlab).
