# Design brief: Joker cards + shop screen

**For:** claude.ai design pass · **Date:** 2026-06-02
**Status:** content + mechanics locked; this brief covers *visual presentation only*.

## What this is

Cricket v2's roguelite layer gives the player **Jokers** — passive modifiers picked
between matches that buff the in-match sim. The 45 Jokers of V1 are already fully
designed (names, effects, rarity, cost, flavour) and architecturally locked. **Do not
re-invent or rebalance them.** This brief asks for the *look*: one reusable card
template + the screen where Jokers are acquired.

## Scope — start minimal

Design a **system**, not 45 bespoke things. One data-driven card template renders all 45.
No per-Joker artwork in this pass — cards are built from a small set of reusable glyphs.
(Expansion path: later we may add an optional per-Joker `art` field; design the template
so it gracefully falls back to glyphs when art is absent, so nothing here is wasted.)

Three deliverables:

1. **One Joker card template** (data-driven).
2. **The shop / draft screen** — where the player picks Jokers between matches.
3. *(Optional)* how an active Joker surfaces in-match — but check the existing in-match
   mockups first (`docs/mockups/in-match-hi-fi-v1.html`, `around-the-match-v1.html`),
   which already reference Jokers; only add if there's a gap.

## Source of truth for content

The full pool lives in [`docs/joker-pool-v1.md`](joker-pool-v1.md). Every Joker has:
**name · rarity · typed effect · plain-English description · flavour line · cost (in Tons)**.
Pull card content straight from there. Rarity tiers: **Common (24) · Rare (15) · Legendary (6)**.

## The card anatomy

Each Joker is a buff on one or more of **six typed effect verbs** (locked by
[`docs/adr/0006-typed-effect-palette.md`](adr/0006-typed-effect-palette.md)). That's the
whole vocabulary — so the minimal icon set is **6 verb glyphs**, and a multi-verb Joker
shows multiple glyphs.

| Verb | Glyph idea | Reads as |
|---|---|---|
| `setIntent` | dial / gauge | team aggression posture |
| `setNextBowler` | swap arrows | bowling change |
| `fieldMode` | fielder-positions grid | field set |
| `buffNextBalls` | upward arrow on a ball | windowed boost |
| `formEvent` | rising spark / star | player form shift |
| `tryReview` | DRS magnifier | review |

A card therefore = **rarity frame + one-or-more verb glyphs + effect text + flavour line + cost**.
Rarity is communicated by **colour + border treatment only** — no separate art required.
(Example multi-verb card: #45 *The Review Master*, Legendary, touches `tryReview` +
`formEvent` → shows two glyphs.)

## Visual system to reuse

Match the existing hi-fi mockups so this drops into the same world:
- Rarity treatments already exist in `docs/mockups/around-the-match-v1.html` (medal cards:
  Common = green ring, Rare = blue glow, Legendary = gold glow). **Reuse these.**
- The Tons currency glyph (`.tons` / `.tmark`) for cost — see the same file and
  [`docs/adr/0008-currency-name-and-mark.md`](adr/0008-currency-name-and-mark.md).
- Per-country theming (`data-country`) and the token system from the existing mockups.

## Deliverable format

An HTML mockup in `docs/mockups/` (same convention as the others) — a design reference,
not production code. Show the card template populated with a few real Jokers across all
three rarities, plus the shop/draft screen in context. The game ships in Godot
(see `docs/PLAYER-CREATION-GODOT-BUILD-NOTES.md`), so treat the
HTML as the source of truth for layout, colour, type, spacing, and rarity states.

## Open question to resolve in the design

How many Jokers does the shop offer at once, and is it a *pick-one-of-N draft* or a
*buy-anything-you-can-afford* shop? Propose what reads best; flag the choice so it can be
reconciled with the roguelite economy.
