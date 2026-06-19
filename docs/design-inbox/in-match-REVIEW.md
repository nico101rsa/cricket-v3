# REVIEW → design: in-match v1 is built from your spec — please review + send amendments

Your handoff (`docs/design-inbox/in-match.md`) was built in Godot and merged to `main` (PR #88). It's a faithful first pass — the precision in your spec did its job. Please review the real render and send amendments (one updated `in-match.md` is enough; we iterate from here).

## See the build
- **Auto-sim (the stable review path):** `docs/mockups/latest/in-match.png`
- Versioned state shots: `docs/mockups/in-match-hifi-built-autosim.png` · `...-keymoment.png` · `...-result.png`
- Raw URL if the connector image view works: `https://raw.githubusercontent.com/nico101rsa/cricket-sim/main/docs/mockups/latest/in-match.png`

## What landed (matches your spec)
- Green country header + KK/opponent badges; gold scorebar; on-strike batter chip highlighted; opponent-tinted bowler row; commentary bar w/ locale chip; run-rate / this-over (coloured cells) / partnership viz; collapsed auto-sim bar + round BOOST w/ gold count badge.
- Overlays: Key Moment (gold banner, two-button), DRS (review → outcome popup → OK), Result (names winner, both innings lines, PLAY AGAIN).
- Re-themed SA green / Karoo Kings via `Palette.country_set`. All 7 new tokens added.

## Known gaps — where amendments would help most
1. **Key Moment card is the sparest vs your reference.** It currently shows title + question + two buttons. Your reference has an **actor mini-card (portrait + name + stats) + a scene emoji + the narration** in the card body. This is the #1 thing to enrich.
2. **Bowler row has no per-bowler figures** — our sim is statistical and doesn't track opposition bowlers, so the row shows flavour name + real ★ + real economy (no "1/24"). If you want the row to read differently given that constraint, say so.
3. **Player names are flavour** (the sim has no named players); every number is real. If the scorecard should *look* different to signal that, propose it.
4. Fonts are the Godot default (no bold weights yet) — if you want a specific weight/face, name it and we'll add it.

## How to send amendments
Update `docs/design-inbox/in-match.md` (or drop an `in-match-v2.md`) with the deltas + a fresh reference if the layout changes. Then: Claude Code rebuilds, re-renders to `docs/mockups/latest/in-match.png`, and we loop until it's locked.
