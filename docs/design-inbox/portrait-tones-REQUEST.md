# REQUEST: portrait expression set in all four skin tones

**From:** build track · 2026-07-03
**Re:** Player Profile System v1 (your locked canonical portrait system)

## What just landed in the game

Your portrait deliverable is now **live in the build** — it was recovered from the design
project's files (it had never been pasted into the repo) and committed under
`docs/design-drop/portraits/`. The game now runs a 16-face runtime matrix:
**4 appearance buckets × 4 form bands**, wired into Player Creation (live hero-swap +
real face thumbnails on the appearance picker), the Season Hub player card
(face follows live form), and the Hall of Fame.

- Form band → your expressions: **HOT→happy · STEADY→confident · TIRED→disappointed · COLD→angry**
  (your spec's own mapping guidance; skill tier stays on the ring colour).
- Renders to check: `docs/mockups/portraits-grid-v1.png` (the 16 faces) and
  `docs/mockups/portraits-in-engine-v1.png` (in-engine).

## The gap — and the ask

You shipped the expression set in **one skin tone** (plus light/dark feature swatches),
and your spec notes "we'll grow this to 4–5 tones in production". The game needs **four**
(the appearance picker's buckets, lightest → darkest: `white / mixed / indian / black`).
As a stopgap the build generated the missing tones **programmatically**
(`tools/gen_portraits.py` palette-remaps your light-skin tiles toward your own
`player-dark-skin.png` anchor). It reads fine but it's machine-tinted, and the darkest
row loses eye/brow definition at small sizes.

**Please produce:** the four mapped expressions (`happy`, `confident`, `disappointed`,
`angry`) **in all four tones**, i.e. **16 tiles**, as your hand-finished art.

- **Framing:** match your `clean/face-confident.png` crop (collar visible). Note:
  `face-neutral` is framed tighter than the rest of the expression set — that
  inconsistency is why STEADY maps to `confident` for now; a re-framed `neutral` would
  let us switch back if you prefer it for STEADY.
- **Resolution:** 2× (≥ 346px wide) — current tiles are 173px and slightly soft on the
  130px squad-profile frame at retina.
- **Background:** both variants if cheap — the stage background (current look) and
  transparent.
- **Delivery names (drop-in, zero code changes):**
  `<bucket>-<band>.png` → `white-hot.png`, `mixed-steady.png`, `black-cold.png`, …
  (bucket ∈ white/mixed/indian/black · band ∈ hot/steady/tired/cold).

The remaining 5 expressions + the 4 action tiles are landed and reserved for future
key-moment/stinger art — no ask on those yet.
