# Brand assets

## Tons (₸) — currency mark

The game's score currency is **Tons**, marked by **₸** — a capital T struck by one or two horizontal bails. The mark reads twice: as a currency glyph in the lineage of $, £, ¥, ₹, ₿, and as a head-on cricket wicket. See ADR 0008 and the full design exploration in [`docs/mockups/the-t-mark-v1.html`](../mockups/the-t-mark-v1.html).

| File | When to use |
|---|---|
| `tons-mark.svg` | Default. Two bails. Use at ≥14px. |
| `tons-mark-single.svg` | Fallback at sub-14px and any rendering surface where two bails fuse (low-DPI, OCR exports). |
| `tons-mark-italic.svg` | For projections, in-flight scores, RR/required-RR contexts — anything not yet final. |

All marks use `fill="currentColor"` so the colour is inherited from the surrounding text. Don't recolour them inline; set `color:` on the parent.

**Construction.** Drawn on a 200×240 viewBox (5:6). Stem centred at x=100, cap at y=22, baseline at y=222. Two-bail variant: bail 1 at y=68, bail 2 at y=92, both 13 tall, separated by an 11-unit gap (the construction note says "0.5u — never less"). Single-bail variant: strike at y=78, 16 tall.
