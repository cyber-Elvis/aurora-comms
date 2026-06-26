# Projector assets — lab diagrams

1920×1080 (16:9) PNGs for viewing the lab diagrams on the lab mini-projector (VOPLLS Q5,
~720p-effective panel) in a dim room. The master diagrams are dense single canvases with
9–13px labels — unreadable when projected whole — so each is split into native-panel slides
with enlarged text (smallest label clears ~18px, the confirmed "perfect" size on this panel:
18px = perfect, 12px = readable, 10px = too small).

**Getting a slide onto the projector:** send the PNG to the iPhone via Windows Phone Link
(right-click image → *Send to My Phone* → lands in Photos), then cast with the TV Casting app
+ the projector's FileShare. (Any PC → iPhone path works; Phone Link is the zero-install one.)

## Layout
- **`*.png` in this folder** = Region A topology, **hand-tuned** content-aligned slides (the
  premium set — `01-internet-edge` … `08-legend-notes`). Built by
  `ops/region-a/diagrams/build_projector_assets.py`.
- **`<name>/` subfolders** = every other diagram, auto-tiled by the generic slicer
  `ops/diagrams/make_projector_slides.py` (overview + a grid of overlapping zoom tiles):
  - `region-b/` — Region B topology
  - `region-a-automation/` — Region A automation architecture

## Generic slicer — make ANY image/topology projector-ready
```
py -3.10 ops/diagrams/make_projector_slides.py docs/region-b-topology.svg
py -3.10 ops/diagrams/make_projector_slides.py path/to/any-image.png --name my-diagram --zoom 2.2
```
SVG inputs render crisp at any zoom; PNG inputs are limited by their own resolution. Output
goes to `docs/projector/<name>/`. `--zoom 2.0` ≈ 18px text on the ~720p panel.

---

## Region A — hand-tuned set (this folder)

Regenerate after editing the diagram (one command re-runs render_topology.py first, then
re-slices — needs the py3.10 interpreter with svglib + reportlab + pillow):

```
py -3.10 ops/region-a/diagrams/build_projector_assets.py             # render + slice
py -3.10 ops/region-a/diagrams/build_projector_assets.py --no-render # slice existing SVG only
```

Slides are tuned so the smallest label clears ~18px on a ~720p-class panel (each zoom crop
is ≤ ~935 diagram-units wide → ≥2× enlargement). Verified readable on a VOPLLS 600 unit
whose panel is effectively sub-1080p: 18px = "perfect", 12px = readable, 10px = too small.

| File | What it shows |
|------|----------------|
| `00-native-1080p-test.png` | Native-resolution / focus / contrast test. **Only valid over HDMI at 1920×1080, 100% scale, 1:1 (NOT WiFi cast — casting compresses + lags and fakes a fail).** 1px line blocks crisp → native; wavy/grey → upscaling panel. Text ramp = your smallest readable size. |
| `01-overview.png` | Whole diagram, letterboxed — big-picture only; fine text not meant to be read here. |
| `02-internet-edge.png` | Transits (A/B) + IXP fabric + FRR route-servers. |
| `03-core.png` | IS-IS/LDP core ADL–GEL–MEL-PE1–MEL-P + iBGP mesh. |
| `04-region-b-handoff.png` | MEL-P → SYD-PE1 logical handoff (Region B). |
| `05-customer-edge.png` | Spare CE / Helix / Northwind + tenant workloads. |
| `06-rpki-mgmt-addressing.png` | PC1 RPKI, mgmt segment, addressing/policy tables. |
| `07-hardening-build.png` | Transit-edge hardening + build-state tables. |
| `08-legend-notes.png` | Legend + archived/guardrail notes. |

Zoom: overview 1×, graph slides ~2–2.6×, reference tables ~3×.
