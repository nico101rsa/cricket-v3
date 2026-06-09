# Fair-fight baseline — symmetric captain tools (Theme 7c) — Design

**Date:** 2026-06-09
**Status:** Design — awaiting Nico's review
**Theme:** 7c balance harness · prerequisite for the joker re-tune (rung 2)
**Prereqs on `main`:** all 45 jokers wired (PRs #18–#26); build-balance LOCKED (PRs #27–#31); 356 tests green.
**Splits from:** `2026-06-09-joker-retune-rarity-bands-design.md` (which becomes rung 2, parked).

---

## 1. Why this is its own rung

The goal was a joker re-tune. Re-sweeping first showed the no-joker baseline wins ~62%, not because
of any joker but because the sweep gives the **Player** a sensible game-plan and captain tools
(intent, boost, DRS) while the **opponent plays passively**. You can't tune jokers honestly against a
dishonest baseline. Fixing the baseline grew (with Nico, 2026-06-09) into giving the opponent its own
base captain tools — at which point it's no longer "tune some numbers," it's "make the sim a fair
fight." That is foundational and reusable by **every** future balance measurement, so it is its own
rung, built and verified first. The joker re-tune (rung 2) then runs against this honest baseline.

## 2. Goal & success criterion

**A no-joker match at even ★3 is a genuine even contest** — both teams run the same base game-plan and
hold the same base captain tools (boost + DRS); the only thing the Player has extra is *jokers* (none,
in the baseline). Concretely:

- **Success = the no-joker sweep baseline returns to ~48–50% win-rate** at even ★3 (matching the
  build-balance oracle `tools/build_spectrum_sweep.gd`, where an even contest is ~48–49% — ties take
  ~1% off the top, so "fair" is win ≈ loss ≈ ~48–49%, not 50%).
- **Determinism preserved** (same seed → same result); snapshot/value tests rebaselined.
- **Full GUT suite green** (currently 356).

This is a **mechanics + measurement** rung — no joker magnitudes change here.

## 3. Scope

**In scope:**
- **Player DRS — team-wide** (review any dismissal, not just the hero) + **2 reviews** (real T20 rule).
- **Opponent DRS** — its own base review-to-survive (no jokers).
- **Opponent boost** — its own base boost, same 3-press schedule, side-aware (mirrors the Player).
- **Opponent batting intent** — same plan as the Player's (already a sweep param).
- **Run-margin readout** in the sweep (non-saturating measuring tool, reused by rung 2).

**Out of scope (deferred, documented):**
- **Opponent reviews-to-*claim* while bowling** (turning a Player not-out into out). Survival is the
  intent-matching slice; claim is a further layer. The Player keeps its claim-review (existing).
- **Water-meter boost fidelity** — fill²-scaling, recharge, the ~6-press budget (ADR 0005). The sim's
  fixed-press strawman (×mult for N balls per press) is adequate; full fidelity is a later job.
- **Opponent jokers / opponent decision-AI** — the opponent runs *fixed* base scripts, no jokers, no
  adaptive choices. Full self-play is 7c layer E.
- **No joker magnitude changes** — that's rung 2.

## 4. Design

### 4.1 The opponent as a base actor (no jokers)
Today an innings is modelled from the **Player's single viewpoint**: one `JokerRuntime` per innings,
side-aware, assuming the Player is the one boosting/reviewing. To give the opponent its own base tools
without entangling the Player's joker logic, add a **second `JokerRuntime` for the opponent**,
constructed with an **empty joker list**, fed the opponent's perspective:

- `opp_runtime = JokerRuntime.new()`; `opp_runtime.init_reviews([], opp_drs.base_reviews)`.
- The opponent's "is batting?" = the opposite of the Player's in that innings.
- **Boost:** at each press over, `opp_runtime.on_boost_press([], opp_is_batting, …, opp_boost.base_mult,
  opp_boost.base_n, …)` pushes the side-aware base buff (runs while the opponent bats / wickets while it
  bowls). With an empty joker list, only the base buff fires (no Boost-Stack modifiers).
- **Per-ball multipliers:** `opp_win = opp_runtime.tick_mults(opp_is_batting)`. Fold the opponent's
  contribution into `resolve_ball`:
  - opponent **batting** (their innings): multiply the **runs** roll by `opp_win.y`.
  - opponent **bowling** (Player's innings): multiply the **wicket** roll by `opp_win.x`.
- **DRS survival:** when the opponent (batting) is dismissed, `opp_runtime.try_review([], true, intent,
  opp_drs.base_p, …)` → on success, overturn to not-out. Empty jokers ⇒ pure base rule, no payoffs.
- **Determinism:** the opponent's boost pushes no RNG draws; each opponent review attempt is one
  `randf`. Draw order changes (rebaseline snapshot/value tests) but reproducibility holds.

The Player's existing runtime, jokers, boost, and DRS paths are **unchanged in behaviour**; the opponent
runtime is purely additive. (Plan decides exact threading; this is the shape.)

### 4.2 Player DRS fixes
- **Team-wide:** in `innings_resolver.gd` (~line 188) drop the `s["is_player"]` gate:
  `if player_is_batting and o.wicket:` — any of the Player's batters can be reviewed-to-survive.
- **2 reviews:** `DRSPolicy.base_reviews` 1 → 2.
- Form-on-success payoffs in the Player's `try_review` fire as before (a teammate's successful review
  firing a Form event = team morale; acceptable). The opponent's `try_review` fires **no** payoffs.

### 4.3 Sweep changes (`tools/sweep_jokers.gd`)
- `opp_intent_plan` = the Player's intent plan (symmetric tempo).
- Give the opponent a `DRSPolicy` and a `BoostPlan` (same `at([1,10,16])` 3-press schedule) so the
  scenario runs both sides with base tools.
- `_scenario` also returns **`margin`** = (Player's team total − opponent's total); the sweep prints
  mean-margin per arm alongside win-rate. (Reused by rung 2; here it confirms the baseline is even —
  mean margin ≈ 0.)

### 4.4 No husbanding AI
Reviews are auto-spent on dismissals as they occur (both teams); boost presses fire on the fixed
schedule. No save-for-later logic — acceptable V1.

## 5. Verification

- **TDD:** teammate-dismissal review (Player); 2-failed-reviews-empties-the-pool; opponent overturns a
  dismissal via its base review; opponent boost buffs the opponent's innings (directional); determinism
  with both runtimes.
- **Re-run the sweep:** assert the no-joker baseline ≈ 48–50% and mean margin ≈ 0 at even ★3.
- **Full GUT suite green** — judge red by parse-error/failing-assert, green by count climbing +
  "All tests passed". Net count rises (new tests) with some snapshot tests rebaselined.

## 6. Key decisions (record)

- **DF1 (Nico):** the opponent gets the **same base captain tools** as the Player (boost + DRS) so the
  no-joker baseline is a fair fight. Built as its own rung, before the joker re-tune.
- **DF2:** opponent modelled as a **second `JokerRuntime` with empty jokers** (additive; the Player's
  paths are untouched).
- **DF3 (Nico):** Player DRS reviews **any team dismissal**; **2 reviews** (real T20 rule).
- **DF4 (Nico):** opponent boost uses the **same 3-press schedule** as the Player, side-aware.
- **DF5:** opponent **reviews-to-claim while bowling** and **boost water-meter fidelity** are deferred.
- **DF6:** success = no-joker even-★3 baseline ≈ **48–50%** (the honest even-contest number).

## 7. Files touched

- `scripts/domain/joker_runtime.gd` — confirm `on_boost_press`/`try_review`/`tick_mults` work with an
  empty joker list (base-only); no new joker logic.
- `scripts/domain/innings_resolver.gd` — team-wide Player review gate; instantiate + drive the opponent
  runtime (boost press, per-ball `opp_win` multipliers, opponent dismissal review).
- `scripts/data/drs_policy.gd` — `base_reviews` 1 → 2.
- `scripts/data/match_resolver.gd` — thread an opponent `DRSPolicy`/`BoostPlan` through
  `simulate_match`/`simulate_match_teams`.
- `tools/sweep_jokers.gd` — symmetric opp intent; opponent DRS + boost; margin readout + print.
- `tests/unit/` — new DRS/boost tests; rebaselined snapshot/value tests.
