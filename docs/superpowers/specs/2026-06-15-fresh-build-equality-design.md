# Fresh-build-equality — competence-gated batting position

**Date:** 2026-06-15 · **Branch:** `fresh-build-equality` · **Status:** design
**Theme:** 7c balance (the one remaining genuine balance bug; follow-up to world-scale v2 / player-leverage)

---

## 1. The problem

`build_spectrum_sweep` walks the Player's build along the batting↔bowling axis
(`power==composure==bs`, `attack==control==ws`, `bs+ws=SUM/2`) at even ★3 vs ★3
and reports win% per build. At the **fresh** end (`SUM=44`, a brand-new creation)
the win% is a large inverted-U, **not** flat:

| build (bs/ws) | win% | team scores | opp scores |
|---|---|---|---|
| 18/ 4 (batting-lean) | **43.0** | **174** | 177 |
| 15/ 7 | 46.5 | 175 | 177 |
| 13/ 9 | 54.8 | 179 | 177 |
| 11/11 (balanced) | 59.5 | 181 | 177 |
|  9/13 | **62.0** | **183** | 178 |
|  7/15 | 52.4 | 178 | 177 |
|  4/18 (bowling-lean) | 52.1 | 178 | 177 |

Spread ≈ **19 pts** (worst 43.0 → best 62.0; the headline "13.7" was the pure
batting-vs-bowling extreme on an earlier N). By `SUM=125` (maxed) the same sweep
is flat at ~48–49% (spread ~2). **This violates the build-equality hard
requirement at the fresh end only** (see `cricket-build-equality-principle`).

### Root cause (measured, not hypothesised)

The leak is **entirely in the batting innings**. The `opp` column is flat
(177–178) for every build → the bowling-budget conservation
(`MatchResolver._conserved_bowling`) makes bowling investment leverage-neutral.
But the `team` column swings 174→183 → that is the whole win-gap.

The mechanism: batting build sets **where you bat** (`InningsResolver.player_position`:
higher batting share → higher in the order). At the fresh end **every build is
absolutely weak** (max attribute ≈ 17.6 vs the league's 31–50). A batting-lean
fresh build is promoted to **#3**, faces many high-leverage balls, and squanders
them — dragging the team to 174. The batting gap-fill (`Team._apply_batting_gapfill`)
tops up the *teammates* regardless, so a bowling-lean build instead hides its weak
bat at **#7** and lets the topped-up top order score 178+.

So at the fresh end **investing in batting is counter-productive** (it promotes a
player who cannot yet handle the position) while bowling investment is
conserved-neutral. By `SUM=125` the batting-lean player is genuinely strong (50),
batting #3 is *earned*, `team` flattens, and the gap heals. The bug is a missing
symmetry: **bowling has run-conservation; batting has only *point*-conservation
(gap-fill), and point-sum ≠ runs once a weak player sits in a high-leverage slot.**

---

## 2. The fix (Nico's call: "earn your position")

Make batting position track **absolute batting competence**, not just build share,
so a fresh weak batting-lean player bats lower (competence-matched) and **climbs
the order as the build levels up** — a visible career-progression feel.

### D1 — competence-gated position formula

`InningsResolver.player_position` changes from:

```gdscript
var share := float(batting) / float(batting + bowling)
var pos := roundi(itun.pos_base - itun.pos_span * share)   # pos_base 9, pos_span 8
```

to:

```gdscript
var share := float(batting) / float(batting + bowling)
var competence := clampf(float(batting) / itun.pos_ref_batting, 0.0, 1.0)
var pos := roundi(itun.pos_base - itun.pos_span * share * competence)
```

`batting = power + composure`. New dial **`InningsTuning.pos_ref_batting`** = the
batting level (power+composure on the /100 scale) that earns *full* promotion.

**Why this shape (D1a):** at full competence (`batting ≥ pos_ref_batting`) the
formula collapses to the *exact current* `pos_base − pos_span·share` → **already-strong
builds keep their current position**, and the whole calibrated ledger (jokers,
economy, policy — all measured at near-maxed builds) is minimally disturbed. Only
weak/fresh builds get pulled down. This is the cheapest correct fix: it targets the
broken regime and leaves the working one alone.

**Worked examples (illustrative; `pos_ref_batting` strawman 60, tuned in §10):**
- Fresh 18/4 (batting 35.2): competence ≈ 0.59 → bats ≈ **#5–6** (was #3) — stops squandering high-leverage balls.
- Fresh 4/18 (batting 8.8): competence ≈ 0.15 → bats ≈ **#9** (was #7) — barely changed.
- Maxed batter 50/13 (batting 100): competence = 1.0 (clamped) → bats **#3** — **unchanged**.
- Maxed all-rounder 31/31 (batting 62.5): competence = 1.0 (clamped at strawman 60) → bats **#5** — **unchanged**.

### D2 — bowling/overs untouched

`InningsResolver.player_overs` (the 0–4 over quota) stays share-based. Bowling is
already conserved (`opp` flat), so it carries no inequality, and touching it risks
breaking the working path. A matching "bowl-more-as-you-improve" progression is a
possible future feel-polish, **out of scope** for this rung.

### D3 — gap-fill untouched

`Team.build_xi` / `_apply_batting_gapfill` keep conserving team batting *points*.
With the player now at a competence-matched slot, point-conservation also conserves
*runs* (the weak player no longer occupies a high-leverage slot), so the leak closes
without changing the gap-fill itself.

---

## 3. Acceptance

### A1 — build-equality across the whole range

`build_spectrum_sweep` win% spread **≤ ~4 pts** across the full batting↔bowling axis
at **`SUM=44`, `SUM=125`, and `SUM≈200`** (near the 120/120 cap). 4 pts matches the
maxed end's natural ~2-pt floor plus integer-rounding slack; the historical
build-balance target was "every build ~47–49%". Tune the single `pos_ref_batting`
dial to hit this at all three totals simultaneously (the constraint is fresh; 125
is already flat and must *stay* flat).

### A2 — ledger re-check (this is NOT zero-ripple)

The change moves the statted Player's batting position, so any oracle that runs a
statted Player is affected. Re-run and re-peg as needed, reporting before/after in §10:
- **env probe** (`probe_scoring_env.gd`) — likely byte-identical (null-player env), confirm.
- **joker floor + bands** (`sweep_jokers.gd`) — the sweep's reference player shifts position; confirm the 45 bands hold or re-interpolate prices.
- **build spread** (`build_spectrum_sweep.gd SUM=125`) — must stay ≤ ~2.
- **economy pay** (`sweep_economy.gd`) — at strawman `pos_ref_batting` the maxed archetypes sit at full competence (unchanged positions), but a lower tuned value could shift the all-rounder/bowler down a slot; confirm pay spread stays in band (~₸0.3–0.6) or re-peg one dial.
- **policy equilibria** (`sweep_policy_*`) — spot-check the hero-transfer arms; full re-anchor only if the equilibrium literal moves.

### A3 — fresh pay equality (flagged)

Fresh builds bat lower across the board → fewer runs early → lower ₸ pay early, but
**equal across builds**. Confirm fresh-end pay is build-equal (not just maxed),
since the economy was calibrated at archetype builds. If a fresh pay-spread appears,
record it; a fix is a separate economy concern, not this rung.

---

## 4. Scope / non-goals

- **In:** the one-line `player_position` change + `pos_ref_batting` dial + tuning + ledger re-peg.
- **Out:** bowling-overs progression (D2), any gap-fill change (D3), any new economy
  component, the difficulty ladder, the career loop. Pure-domain change; no scene work.

---

## 5. Testing (TDD)

Unit tests on `player_position` (pure):
1. Full-competence build reproduces the *old* position (regression: `batting ≥ pos_ref` ⇒ `pos_base − pos_span·share`).
2. Low-competence build bats lower than the same *share* at full competence (directional: fresh batting-lean bats deeper than maxed batting-lean).
3. Monotonic: rising `batting` (fixed share) moves the player up the order (non-increasing pos).
4. Clamp endpoints hold (1..9).
5. `pos_ref_batting` dial respected (doubling it deepens a sub-ref build).

Then the measure-tune loop (oracle, not unit): `build_spectrum_sweep` at SUM 44/125/200.

Judge red by the parse-error/`Identifier not declared` convention; green by total
count climbing past **562** and `All tests passed`.

---

## 10. Findings (filled during build)

_TBD — tuned `pos_ref_batting`, before/after win% spreads at SUM 44/125/200, ledger
re-peg deltas (env / joker floor+bands / build spread / pay), fresh pay-equality check._
