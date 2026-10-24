# HomePad icon silhouettes · 2026-10-17

This independent design round compares the original Dwell reference with three new overall silhouettes. It is a review package, not an app integration or a final brand decision.

- **A**: a wrapping window / sheltered inner pane. Recommended for further discussion in this round: the rounded square silhouette is distinct from the previous gabled house, while the three full planes and warm center survive at 60 px.
- **B**: two folded walls and a warm floor. Clean spatial reading, though it can also read as a room or cube.
- **C**: open architectural masses with a warm middle plane. Deliberately tests the H relationship; it reads more like a letter than A and is less preferred.

The unnumbered original remains the aesthetic reference. New proposals extend that authorized HomePad concept; none is the formal VILHIL logo. Formal brand sources were confirmed in the earlier study, including `VilHil 视觉识别系统_8.16.pdf` and `vilhil-mark-vi-20261013.svg`; no wordmark or unrelated Ronsys mark was imported here.

## Deliverables

- `comparison.png`: original / A / B / C, large artwork and actual 60 px previews, minimal labels.
- `desktop-comparison.png`: light and dark desktop contexts, actual 120 / 60 px previews. The desktop gradients are illustrative review backgrounds.
- `concepts/a.svg`, `b.svg`, `c.svg`: three native editable Bezier paths per proposal, with gradients and a restrained shadow; no embedded raster.
- `exports/`: opaque square 1024 px PNG masters and 120 / 60 px PNG previews for all three proposals and the original reference.
- `exploration/`: imagegen visual sketches and exact prompts. Two initial gabled variants were rejected rather than included on the final comparison.
- `index.html`, `build.py`, `render.mjs`: editable presentation and reproducible local rendering.

Built-in `image_gen.imagegen` was used for visual exploration. Selected raster sketches were interpreted by hand into simpler editable SVG paths; gradients were brought back to the original Dwell palette to compare shape fairly. The SVGs are designed redraws, not exact automatic bitmap traces.

## Review and scope

Rendered and visually inspected with Chromium 135.0.7049.17 on macOS arm64 using Node 22.22.3, device scale 1. Checked large silhouettes, spacing, curves, full opacity and the 60 / 120 px reading on both backgrounds. The preview tile mask is illustrative, not a claim of system rendering on an iPad.

Application AppIcon PNG and `Contents.json` were checked against the existing pre-design SHA-256 baseline. The original Dwell SVG is copied byte for byte. Details are in `review.json`.

No Swift, app configuration, AppIcon binding, tests, deployment or installation was changed by this round. No Git commit or push was made. Application XCTest / XCUITest and physical iPad appearance were not tested for this independent design package. Existing work elsewhere in the repository belongs to parallel tasks and was preserved.
