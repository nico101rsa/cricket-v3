# REPLY → Player Creation · Build review (PR #94) — 2 ship, 1 amend

> Faithful translation of the locked `player-creation-v2.html` Build band — gradient header, Batting/Bowling
> groups, accent sliders, classifier panel and gold CTA all read right. Rulings on your three deltas below.
> **Only #2 needs a build change.** No new Palette/UIStyle tokens for any of this.

## 1 · CTA emoji → plain `Begin Career`  ✅ SHIP (plain is final)
Correct call dropping the 🏏 — tofu is worse than no flourish, and don't fight the font. Plain **`Begin Career`**
is clean and final. **Do not** swap in a `▶`/dingbat — those are emoji-range glyphs too and risk the same tofu
in Barlow Semi Condensed. If you ever want a flourish it's a *drawn* asset (a small bat-stroke SVG/PNG to the
left of the label), not a font glyph — nice-to-have, not blocking. Ship as-is.

## 2 · Points meter `44 / 44` — AMEND: drop the always-full bar, make it a balance chip
The one real divergence worth fixing. A progress bar that's **full on every valid build** carries no information
and reads slightly *wrong* — "full" normally means maxed/done, but here full = correct. The per-slider accent
fills already tell the "where did my points go" story, so the global bar is redundant **and** mildly misleading.
Reframe it as a **balance status chip**, no big fill bar:

| state | reads | colour |
|---|---|---|
| Balanced (sum == 44) | `44 / 44 ✓` | **GREEN** (success) — calm, not alarming |
| Over (sum > 44) | `46 / 44 · 2 over` | **RED** — the only state that should shout |
| Under (sum < 44) | `41 / 44 · 3 to spend` | **GOLD** — actionable, not an error |

- Keep the `POINTS` microlabel. Kill the long left-to-right progress track.
- If you want *some* geometry, a thin **centered balance tick** (fills left = under / right = over from a center
  zero) communicates "balanced" far better than a fill bar. Optional — the chip text alone is enough.
- Net: same data, but the meter only draws the eye when the build is invalid. Reuses success/red/gold — **no new tokens.**

## 3 · Back button inline (not floating corner)  ✅ SHIP
Inline-left is the better call — it can never collide with the kicker, and in the render it already reads as a
proper circular button. **Don't** float it into the corner; inline is locked. One consistency check: confirm its
diameter + icon weight match the `ⓘ`/`⚙` corner buttons on the other screens so the back affordance feels like the
same family. If it already does, ship it.

## Identity (Screen 1) — noted, no action
Blocked on the portrait pipeline (`hero-front` / `hero-helmet` / `keeper` missing, only `hero-cap.png` exists).
When those land, ping me and I'll spec the Identity band against the same foundation. No design action this round.

---
## Verdict
**Ship 1 & 3. Apply the #2 balance-chip reframe, re-render `docs/mockups/latest/player-creation-build.png`, and we close it.**
