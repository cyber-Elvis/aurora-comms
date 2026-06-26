# Projector assets — lab diagrams

1920×1080 (16:9) PNGs for viewing the lab diagrams on the lab mini-projector (VOPLLS Q5,
**verified native 1080p** — the 1px test pattern resolves clean at 1:1 over HDMI) in a dim room.
The master diagrams are dense single canvases with 9–13px labels — unreadable when projected
whole — so each is split into native-panel slides with enlarged text. Legibility measured on the
panel itself: **18px = perfect, 12px = readable, 10px = too small.** (Slides were originally tuned
for a ~720p worst case, so they're conservative — on the real native-1080p panel everything is
sharper than designed.) Drive it over **HDMI at exactly 1920×1080, 100% scale, auto-keystone OFF**
for the 1:1 path; WiFi cast still softens.

**Getting a slide onto the projector:** send the PNG to the iPhone via Windows Phone Link
(right-click image → *Send to My Phone* → lands in Photos), then cast with the TV Casting app
+ the projector's FileShare. WiFi cast is lossy (softens text) — **HDMI is crispest**.

## Layout — every diagram gets a `<name>/` subfolder, all SEMANTIC
```
docs/projector/
  00-native-1080p-test.png   test pattern (generic; not a diagram)
  region-a/             00-overview + 01-topology + 02-reference
  region-b/             00-overview + 01-topology + 02-reference
  region-a-automation/  00-overview + 01-flow + 02-reference-accounts
```
- **`00-overview.png`** in each folder = the whole diagram letterboxed — a "where am I" **map
  only; its text is NOT meant to be read**. **Read from the content slides, not the overview.**
- **`01-…`** = the whole topology/flow on one slide. **`02-reference`** = the whole right-hand
  description column on one slide (relaxed to one slide now that the panel is native 1080p — if a
  diagram's reference column is too tall to stay comfortably readable, split it into two boxes).
- All three diagrams use the **same semantic split** (topology | reference), not a grid.

## How INTELLIGENT (semantic) slides work — the convention
The shared tiler (`ops/diagrams/make_projector_slides.py`) checks for a **regions sidecar**
next to the input — `docs/<stem>.regions.json`:
- **sidecar present → SEMANTIC** slides (one per declared region);
- **no sidecar → GRID** fallback (mechanical tiles, fine for ad-hoc images).

A code-generated diagram opts in by emitting the sidecar from its generator. **The boxes are
DERIVED from geometry, not hand-typed:** `band()/panel()/zone()/node()` register their rects into
`REG` as they draw, and the sidecar boxes are the bbox of each region group — so they auto-track
the layout (move a panel, its box follows). This is a genuine single source of truth. Sidecar
format:
```json
{ "canvas": [W, H],   // MUST equal the diagram's native size (SVG viewBox / PNG pixels)
  "slides": [ { "name": "01-topology.png", "caption": "…", "box": [x0,y0,x1,y1] }, … ] }
```
The tiler **validates** every sidecar before cropping (canvas+slides present, x/y scaled
independently, canvas aspect must match the master, boxes in-bounds and non-inverted, names
unique) and **warns** if any drawn content lands on no content slide — so a bad or stale sidecar
fails loudly instead of silently mis-cropping.

**To make a NEW code-gen diagram semantic:** tag its draw helpers with a region group (as in
`render_topology.py`) and emit the derived sidecar. For a **PNG-only** diagram (no generator),
hand-write `docs/<stem>.regions.json` in pixel units (see
`region-a-automation-architecture.regions.json`).

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
goes to `docs/projector/<name>/`. `--zoom 1.6` (the relaxed default for native 1080p) ≈ 12px text
and fewer/larger tiles; raise it for bigger text + more tiles. Needs py3.10 with pillow (+ svglib
+ reportlab).
