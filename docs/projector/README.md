# Projector assets — lab diagrams

Diagram slides are **3840×2160 (4K UHD, 16:9) PNGs** for viewing the lab diagrams on the lab
mini-projector (VOPLLS Q5, **verified native 1080p** — the 1px test pattern resolves clean at 1:1
over HDMI) in a dim room. The masters are dense single canvases with 9–13px labels — unreadable
when projected whole — so each is split into slides with enlarged text. Legibility measured on the
panel: **18px = perfect, 12px = readable, 10px = too small.** Drive it over **HDMI at exactly
1920×1080, 100% scale, auto-keystone OFF** for the 1:1 path; WiFi cast still softens.

> **About the 4K resolution:** the projector is native 1080p, so it **downscales 4K → 1080p** —
> 4K gives *no* extra detail *on the projector*. The 4K masters are for **4K monitors, digital
> zoom, printing, and future-proofing**. Two notes: (1) the **`00-native-1080p-test.png` stays
> 1080p** on purpose — it's a calibration target that must match the panel's native size to test
> 1px rendering; a 4K version would defeat it. (2) `region-a-automation` is a **PNG-only** source
> (1760px), so its 4K slides are upscaled/soft — only SVG-generated diagrams are crisp at 4K.
> Render at the old size with `--height 1080` if you ever want smaller files.

**Getting a slide onto the projector:** send the PNG to the iPhone via Windows Phone Link
(right-click image → *Send to My Phone* → lands in Photos), then cast with the TV Casting app
+ the projector's FileShare. WiFi cast is lossy (softens text) — **HDMI is crispest**.

## Layout — every diagram gets a `<name>/` subfolder, all SEMANTIC
```
docs/projector/
  00-native-1080p-test.png   test pattern (generic; not a diagram)
  region-a/             00-overview + 01-topology + 02-reference-routing + 03-reference-hardening-build
  region-a-transit-internet/  00-overview + 01-topology + 02-reference-interfaces + 03-reference-operations
  region-b/             00-overview + 01-topology + 02-reference-routing + 03-reference-placement-build
  region-a-automation/  00-overview + 01-flow + 02-reference-accounts
```
- **`00-overview.png`** in each folder = the whole diagram letterboxed — a "where am I" **map
  only; its text is NOT meant to be read**. **Read from the content slides, not the overview.**
- **Content slides (`01-...`, `02-...`, `03-...`) must be enlarged semantic views, not broad
  overview crops.** Start their boxes at the actual topology, flow, or panel content; leave titles,
  footers, legends, and unrelated bands to `00-overview` unless they are required to read that slide.
- **Topology/flow slides** should fill the 4K canvas with the network/flow itself. **Reference
  slides** should split tall sidebars into focused chunks when a single crop would leave the content
  as a skinny column or make text feel no larger than the overview.
- Diagrams use a **semantic split** (topology | focused reference sections), not a grid.

## How INTELLIGENT (semantic) slides work — the convention
The shared tiler (`ops/diagrams/make_projector_slides.py`) checks for a **regions sidecar**
next to the input — `docs/<stem>.regions.json`:
- **sidecar present → SEMANTIC** slides (one per declared region);
- **no sidecar → GRID** fallback (mechanical tiles, fine for ad-hoc images).

A code-generated diagram opts in by emitting the sidecar from its generator. **The boxes are
derived from geometry wherever possible, then split by reading task:** `band()/panel()/zone()/node()`
register their rects into `REG` as they draw, and the sidecar boxes use those groups for tight
content crops. Move a panel and its crop follows; split a tall reference column by assigning panels
to separate groups such as `ref_top` / `ref_bot`. This is a genuine single source of truth. Sidecar
format:
```json
{ "canvas": [W, H],   // MUST equal the diagram's native size (SVG viewBox / PNG pixels)
  "slides": [ { "name": "01-topology.png", "caption": "…", "box": [x0,y0,x1,y1] }, … ] }
```
The tiler **validates** every sidecar before cropping (canvas+slides present, x/y scaled
independently, canvas aspect must match the master, boxes in-bounds and non-inverted, names
unique) and **warns** if any drawn content lands on no content slide — so a bad or stale sidecar
fails loudly instead of silently mis-cropping.

**To make a NEW code-gen diagram semantic:** tag its draw helpers with region groups (as in
`render_topology.py`) and emit a tight sidecar. Do not use the overview crop as a content slide; if
the resulting slide does not make the topic visibly larger, split the group or tighten the box. For
a **PNG-only** diagram (no generator), hand-write `docs/<stem>.regions.json` in pixel units (see
`region-a-automation-architecture.regions.json`) using the same enlarged-view rule.

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
