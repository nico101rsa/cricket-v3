# Jokers in the sim — C2g: Form sources & intent dynamics (design)

**Date:** 2026-06-08 · **Rung:** 7c layer C, sub-slice C2g · **Mode:** AFK
**Prior:** C2f DRS (PR #24, 39 of 45). Reuses the C2c Form channel.

## 1. What this rung adds

The Form *source* jokers — they **generate** Form events (instead of consuming them) — plus one Form→intent feedback. They were deferred from C2c because they only matter alongside Form consumers; now they complete those archetypes.

- **Intent-switch sources** (#2 Sheet Anchor, #11 Captain's Statement): switching the Player's batting intent **to Balanced / to Aggressive** fires a Form event.
- **Over-survival source** (#5 Building Phase): every 6 consecutive Player balls faced **while Defensive** fires a Form event.
- **Form→intent snap** (#13 Boundary Hunter): a Player Form event (boundary) **snaps the Player's intent to Aggressive** for the rest of the innings.

All four are batting-side, Player-only. The first three fire the C2c Form channel (chaining into Ride the Wave / Hot Streak / Vigil) — so they're **enablers** (≈0% solo, like Defensive Captain). #13 is a state write (intent override).

**Pool delta: 39 → 43 of 45.**

## 2. Model + engine

- `JokerEffect`: `enum FormSource { NONE, ON_BALANCED, ON_AGGRESSIVE, ON_DEFENSIVE_OVER }`, `var form_source := NONE`; `var snaps_intent := -1` (the intent to snap to on a Form event, for #13). Both make the joker runtime/sim-owned → `matches()` returns false.
- `JokerRuntime.fire_form_source(jokers, player_is_batting, source, ball)` — if any joker has `form_source == source`, fire the C2c Form channel (`_fire_form_event`).
- `simulate_innings` (Player batting only):
  - **intent switch:** at each over start, if the over's intent ≠ the previous over's intent, fire `ON_BALANCED` / `ON_AGGRESSIVE` for the new intent.
  - **over-survival:** a counter of consecutive Player balls faced while Defensive; every 6 → fire `ON_DEFENSIVE_OVER`. Reset on a Player non-Defensive ball or dismissal.
  - **intent snap:** after a Form event (boundary), if a `snaps_intent` joker is present, set `intent_override`; subsequent balls use it (over rides the `IntentPlan`).

**Determinism:** all driven by ball index / deterministic outcomes; no new RNG. Off-by-default: none of these jokers present → no source fires, no override → byte-identical.

## 3. Decisions (AFK)

- **D1 — sources are batting-side, Player-only** (CONTEXT.md: per-ball Form is the Player's). They fire only in the Player's batting innings.
- **D2 — #13 snap is a one-way latch to Aggressive** (a Form event sets `intent_override = AGGRESSIVE`; it stays for the innings). Simple and faithful ("one four, one more").
- **D3 — over-survival counts consecutive Player Defensive balls**, reset on a Player non-Defensive ball / wicket; partner balls don't change it. A documented simplification of "faced 6 balls."
- **D4 — these are enablers** (≈0% solo). Their value is combinatorial with Form consumers; demonstrated by combo sweep arms (#2/#11 + Ride the Wave).

## 4. Catalog + sweep

`implemented_groups()` 39 → 43. Add combo arms ("Sheet Anchor + Ride the Wave", "Boundary Hunter + Powerplay Punch") so the enablers show value. Refresh viewer.

## 5. Tests (green past 315)

- `test_joker_effect.gd`: a `form_source != NONE` / `snaps_intent != -1` joker returns false from `matches()`.
- `test_joker_runtime.gd`: `fire_form_source` fires the Form channel only when a matching source is present.
- `test_joker_catalog.gd`: 43 groups; #2/#5/#11 form_source, #13 snaps_intent.
- `test_innings_jokers.gd`: Sheet Anchor + Ride the Wave raises runs vs Ride the Wave alone (the source adds Form events); Boundary Hunter makes the Player score more like Aggressive after a boundary (directional); determinism.
