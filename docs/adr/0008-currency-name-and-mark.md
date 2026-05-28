# Currency name and mark — Tons (₸), a T struck by a bail

The career currency previously carried the working name *Pay*. This ADR locks the name and the glyph.

## Decision

The currency is **Tons**, marked by **₸** — a capital T crossed by a horizontal bail. The recommended form carries **two bails** at display sizes (≥14px); below that, fall to a **single bail** that survives low-DPI rendering.

The full mark exploration lives in [`docs/mockups/the-t-mark-v1.html`](../mockups/the-t-mark-v1.html). Production-ready SVGs sit in [`docs/brand/`](../brand/) — see that folder's README for usage.

## Why "Tons"

The double meaning carries the brand:

- In cricket, a **ton** is a century (100 runs) — the player's earned milestone.
- In British slang, a **ton** is £100 — the word is already money-native.

Both readings are present without explanation, which is what a good currency name does. Alternatives considered:

- **Caps** — a Test cap is the highest honour. Strong but reads as a count, not a quantity. "Spend 200 Caps" feels like spending titles.
- **Willow** (the bat material). Premium mass-noun (like *gold*), but loses plural rhythm and reads as substance rather than tender.
- **Stumps / Bails** (Player's own suggestions). Stumps carries an "end-of-play" association that fights the wealth-accumulation metaphor. Bails reads small-stakes for a Career-scoped bank.
- **Stumpies** — diminutive undercut the "bit serious" brief.

Tons is the only candidate where the cricket meaning and the money meaning land simultaneously, without forcing.

## Why ₸ (a T struck by a bail)

The mark joins the lineage of $, £, ¥, ₹, ₿: a letter + a horizontal strike. The Kazakh tenge — Unicode ₸ — is the only major currency that already uses a T+strike, so we're not inventing a new shape language, we're joining a small, well-formed one. The cricket reading is the gift on top: the head-on view of a stump with bails resting on it.

**Two bails over one.** The two-bail form is unmistakably a wicket (a head-on broadcast graphic) and echoes the real ₸ glyph's double strike. The single-bail form is the fallback when bails would fuse on low-DPI screens — below 14px, or in OCR exports.

## Display conventions

The glyph leads the value with a single space — matching `$`, `£`, `€` placement. Thousands separator is a comma. The mark is never doubled and never followed by "Tons" in body copy (the glyph *is* the word, like `$50` not `$50 dollars`).

Canonical reads (use these as the source of truth in UI mockups and copy):

| Context | Example |
|---|---|
| Career-total stat | `Career total · ₸ 14,328 across 184 innings` |
| Shop affordability (price · balance · after-buy) | `Need ₸ 1,800 (Joker · Legendary) · Have ₸ 2,540 · After ₸ 740` |
| Match purse breakdown (base × performance multiplier) | `Match purse: ₸ 312 (base ₸ 200 · perf ×1.56)` |

The italic glyph variant (skew −9°) is reserved for projections / in-flight values (e.g. *required* RR, *projected* end-of-Season balance) — never for booked figures.

## Consequences

- All references in the canon (CONTEXT.md, DESIGN_HANDOFF, prior ADRs 0002/0003/0004) updated from *Pay* → *Tons*. Forward-only — no shim period.
- The mark is locked at the two-bail standard for ≥14px contexts, with the single-bail variant as the small-size fallback. Italic version (skew -9°) reserved for projections / in-flight scores (RR, required RR).
- Glyph construction is fixed: 200×240 viewBox, stem-width = 1u, cap height = 10u, bail spacing ≥ 0.5u. Future variants (heavy, slab, compact) must inherit this skeleton — see [`docs/mockups/the-t-mark-v1.html`](../mockups/the-t-mark-v1.html) §08.
- All assets use `fill="currentColor"` so colour is inherited from surrounding text — never recolour inline; set `color:` on the parent.
- The Unicode codepoint **U+20B8 (₸)** can be used directly in copy and as a fallback when an SVG can't be embedded (e.g. plain-text log lines, debug overlays).
