# Projector assets — lab diagrams

1920×1080 (16:9) PNGs for viewing the lab diagrams on the lab mini-projector (VOPLLS Q5,
~720p-effective panel) in a dim room. The master diagrams are dense single canvases with
9–13px labels — unreadable when projected whole — so each is split into native-panel slides
with enlarged text (smallest label clears ~18px, the confirmed "perfect" size on this panel:
18px = perfect, 12px = readable, 10px = too small).

**Getting a slide onto the projector:** send the PNG to the iPhone via Windows Phone Link
(right-click image → *Send to My Phone* → lands in Photos), then cast with the TV Casting app
+ the projector's FileShare. WiFi cast is lossy (softens text) — **HDMI is crispest**.

## Layout — every diagram gets a `<name>/` subfolder
```
docs/projector/
  00-native-1080p-test.png   test pattern (generic; not a diagram)
  region-a/   00-overview + SEMANTIC slides (topology / reference panels)
  region-b/   00-overview + grid tiles            (generic tiler)
  region-a-automation/  00-overview + grid tiles  (generic tiler)
```
- **`00-overview.png`** in each folder = the whole diagram letterboxed — a "where am I" **map
  only; its text is NOT meant to be read**. **Read from the content slides, not the overview.**
- **Region A is split SEMANTICALLY** (`01-topology` = whole network graph; `02/03-reference-*` =
  description panels enlarged) — the intelligent split, not a grid.
- **Other diagrams** (Region B, automation) currently use the mechanical grid.

## How to get INTELLIGENT (semantic) slides for any diagram — the convention
The shared tiler (`ops/diagrams/make_projector_slides.py`) checks for a **regions sidecar**
next to the input — `docs/<name>-topology.regions.json`:
- **sidecar present → SEMANTIC** slides (one per declared region: topology, reference, …);
- **no sidecar → GRID** fallback (mechanical `top/mid/bottom` × `left/center/right` tiles).

So a code-generated diagram opts into intelligent slides by having its generator **emit the
sidecar once**. Region A's `render_topology.py` does this in its `regions` block (single source
of truth — edit there to re-shape the slides). The sidecar format:
```json
{ "canvas": [1840, 1200],
  "slides": [ { "name": "01-topology.png", "caption": "…", "box": [x0,y0,x1,y1] }, … ] }
```
`box` is in the diagram's own canvas units. To make Region B (or any future diagram) semantic,
add the same `regions` block to its generator — no tiler changes needed.

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
