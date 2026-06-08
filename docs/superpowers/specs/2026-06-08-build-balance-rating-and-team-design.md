# Build Balance — Player Rating + Build-Adaptive Team — Design

**Date:** 2026-06-08
**Theme:** 7c balance (follows layer C; this is the build-balance work Nico opened on re-engagement)
**Status:** Design — awaiting Nico's review before writing-plans.

---

## 1. Problem

At an even ★3-vs-★3 match, the three archetypal builds do **not** win equally:

| Build (power/composure/attack/control) | Win rate |
|---|---|
| Batting (8/8/2/2) | **67%** |
| Bowling (2/2/8/8) | **62%** |
| All-rounder (5/5/5/5) | **~51%** |

The all-rounder is already near the fair 50% line; the **specialists bulge above it** (batting most, because one batter can face 40–60 balls of their own innings while one bowler is capped at 4 overs of the opponent's — batting is simply a bigger lever, and with no risk trade-off in the neutral sweep a high-composure batter is near-immortal, batting average ~141).

Nico's goal: **an all-rounder should be just as good as a batter or a bowler — at two levels:**

1. **Team level** — whatever build the Player picks, their team wins ~50% at even stars. Build choice expresses as *playstyle + joker fit*, never as raw team power.
2. **Individual level** — the Player is equally *valuable* whatever they build. "Valuable" means different things per build (a batter is judged on runs + strike rate; a bowler on economy + wickets), so this needs a **common currency** that puts them on one scale.

### Decisions already taken (Nico's calls)

- **D1 — Target = flat ~50% across all builds** (within ±2%), not "specialists earn a small edge." Build is win-neutral at the base; power comes from the meta layer (jokers/skills).
- **D2 — Rating currency = net runs** (runs added + runs saved, wickets ≈ runs). See §3.
- **D3 — Team model = discrete real roster.** The team is a real XI of individual players with roles, assembled to fill the Player's gap — not a single abstract strength number. The opponent is one **fixed standard XI** for now. See §4.
- **D4 — The balancing is a real game system, not a harness trick.** Both the rating and the team-composition live in the real sim path (`scripts/domain/` + `scripts/data/`); the balance sweep only *reads* them. Nothing here disappears outside the tuning tool.
- **D5 — Balance sweep keeps neutral Intent** (no aggression plan). The immortality artifact therefore stays visible and is deflated via the baseline wicket dial, not via Intent coupling.

---

## 2. The unifying insight: it is all one currency — runs

The two levels are not separate problems. **Net runs is both the individual rating and the team budget.** A team "is worth" some total runs (scored with the bat + saved with the ball); the Player provides a slice of it; the teammates fill the rest. So once a player can be scored in net runs:

- The **individual rating** (§3) is that score for the Player.
- The **team gap-fill** (§4) is "keep the team's total run-worth roughly constant, whoever the Player is" — which makes team win-rate flat *by construction*, not by fudging ball math.

Build the rating first; the team system leans on the same currency.

---

## 3. System 1 — Player Rating (net-runs impact)

A pure calculation over what the sim already produces each match. No change to sim behaviour — purely additive. This is the foundation **and** the yardstick we tune against **and** a real in-game performance stat (display polish deferred — raw net runs for now).

### 3.1 Inputs (already in `InningsResult`)

- Batting line — from `InningsResult.player_line()`: `runs` (R_bat), `balls` (B_bat), `out`.
- Bowling line — `InningsResult.player_bowl_wickets` (W), `player_bowl_runs` (R_conc), `player_bowl_balls` (B_bowl).

### 3.2 The formulas (all in run-equivalents)

```
batting_value = R_bat − (sr_par / 100) * B_bat
             # runs you scored above what a par batter scores off those same balls.
             # Strike rate falls out automatically: more runs off the same balls = more value.

bowling_value = (rr_par / 6) * B_bowl − R_conc + W * wicket_value
             # runs you SAVED below par economy, plus each wicket as run-value.
             # (rr_par/6)*B_bowl = the runs a par bowler concedes over those balls.

rating = batting_value + bowling_value      # net runs contributed this match.
```

An all-rounder is literally `batting_value + bowling_value`. A pure batter has ~0 bowling_value; a pure bowler ~0 batting_value.

### 3.3 Tuning data — `RatingTuning` (new `Resource`, `scripts/data/rating_tuning.gd`)

```
sr_par        # par strike rate (runs per 100 balls)        — DERIVED, not guessed
rr_par        # par economy (runs per over conceded)        — DERIVED, not guessed
wicket_value  # run-worth of one wicket; strawman 10.0      — harness-tunable
```

`sr_par` and `rr_par` are **derived empirically** from a generic (5/5/5/5, ★3) player's neutral-Intent output, so "par" means "what an average player does in this sim," not an external guess. Procedure: run the generic build through the sweep, read its mean SR and mean economy, write those into `RatingTuning` defaults. All three are `@export` so the harness can sweep them.

### 3.4 Component — `PlayerRating` (new, `scripts/domain/player_rating.gd`)

Pure `RefCounted`, no state. One static entry point:

```
static func rate(bat_line: Dictionary, bowl_wickets: int, bowl_runs: int, bowl_balls: int,
                 rtun: RatingTuning) -> Dictionary
# -> { "batting": float, "bowling": float, "rating": float }
```

Reads the Player's two lines out of a `MatchResult` (batting line from whichever innings the Player batted; bowling figures from whichever innings they bowled — the sweep already untangles these, see `build_spectrum_sweep._scenario`).

### 3.5 Fairness target (what we tune toward)

Across the build spectrum at even ★3, the **mean rating per build** should be roughly equal: `rating(pure-batter) ≈ rating(pure-bowler) ≈ rating(all-rounder)`. We adjust `wicket_value` (and, if needed, the par-lines) until they converge. This is the *individual* half of the goal.

---

## 4. System 2 — Build-adaptive discrete team

The big architectural piece. Today a `Team` is two derived ints (`batting_strength`, `bowling_strength`) and `InningsResolver._build_batters` clones all 10 teammates at one `partner_batting` number. We replace that placeholder with a **real roster of individual players**, assembled to fill the Player's gap.

### 4.1 The roster model

A team becomes an **XI of 11 individual players**, each an `Attributes` (the same 4 stats the Player uses) carrying an implied role. Players are drawn from a small set of **archetypes** (data, harness-tunable; numbers below are strawman, scaled to the team's star level):

| Archetype | power | composure | attack | control | role |
|---|---|---|---|---|---|
| BATTER | high | high | low | low | top order |
| BOWLER | low | low | high | high | attack |
| ALLROUNDER | mid | mid | mid | mid | flex |
| TAIL | low | low-mid | low | low-mid | lower order |

### 4.2 The fixed standard XI (the opponent, and the Player's baseline)

A realistic T20 shape, used unchanged by the opponent every match (D3 — "set standard for now"). Strawman template: **6 BATTER · 1 ALLROUNDER · 4 BOWLER**. Its total batting capacity `B*` and bowling capacity `W*` define the targets the Player's team must hit.

### 4.3 Gap-fill assembly (the heart of it)

The Player occupies one slot; the other 10 are chosen so the team's totals land back on `(B*, W*)`:

1. Start from the standard XI.
2. Insert the Player in the slot matching their dominant role (replacing that archetype).
3. **Re-balance by swapping teammate archetypes** until team batting capacity ≈ `B*` and bowling capacity ≈ `W*` (within tolerance): if the Player is a pure batter (adds batting, no bowling), swap a BATTER teammate → BOWLER to restore the bowling the Player isn't providing; if a pure bowler, swap a BOWLER → BATTER; an all-rounder ≈ the displaced ALLROUNDER, so little swapping.

This produces exactly Nico's picture: pick a batter → the team carries an **extra bowler**; pick a bowler → an **extra batter**; pick an all-rounder → the freed flex capacity becomes **one more specialist**. "Capacity" at assembly time uses a cheap proxy (sum of batting attrs / sum of bowling attrs); the net-runs rating (§3) is the accurate *verification* yardstick, not the assembly input.

### 4.4 Wiring into the sim

- `Team` gains a real roster (a `build_xi(...)` that returns 11 `Attributes` + roles) instead of only two scalar strengths. Backwards-compatible: the scalar `batting_strength`/`bowling_strength` can be derived as the roster's aggregate so existing callers/tests keep working during the transition.
- `InningsResolver._build_batters` uses the **real batting order** from the roster (each teammate their own `power`/`composure`) instead of cloning one `partner_batting`. The Player still bats at their build-driven position.
- The bowling side uses the **roster's bowlers** (their attack/control), still including the Player's 0–4 over quota.
- `MatchResolver.simulate_match_teams` assembles the Player's XI via gap-fill around `player_attrs`, and the opponent via the fixed standard template.

### 4.5 Calibration

Set archetype profiles, the `(B*, W*)` targets, and swap tolerance so that **win-rate is flat ~50% (±2%) across the whole build spectrum** at even ★3. The extended sweep (§5) is the oracle: adjust → re-sweep → compare. The 4-over bowling cap stays at 4 (realism anchor, Nico's call); flattening happens via roster composition + the existing `InningsTuning`/`BallTuning` dials, not by lifting the cap.

---

## 5. Verification harness

Extend `tools/build_spectrum_sweep.gd` (already walks 7 points on the batting↔bowling axis, 2000 even-★3 matches each, neutral Intent) to also print, per build:

- **mean rating** + its `batting`/`bowling` split (System 1), and
- **win-rate** (already present).

Two success bars, both checked off this one table:

- **Individual:** mean rating flat across builds (System 1 tuned).
- **Team:** win-rate flat ~50% ±2% across builds (System 2 calibrated).

Keep neutral Intent (D5). Output stays the print-table format the tool already uses.

---

## 6. Decomposition (slices → each its own plan + PR)

- **Slice 1 — Player Rating.** `RatingTuning` + `PlayerRating.rate()` + derive par-lines + unit tests + extend the sweep to print rating. Purely additive; no sim-behaviour change. *Foundation + measurement.*
- **Slice 2 — Discrete roster model.** `Team.build_xi()` + archetypes + the fixed standard XI; wire real individual teammates into `_build_batters` and the bowling side, replacing the clone/scalar placeholder. Behaviour re-grounded but not yet build-adaptive (everyone uses the standard template). *Architecture upgrade.*
- **Slice 3 — Gap-fill + calibration.** Build-adaptive assembly (§4.3) + calibrate archetypes/targets to flat 50%; re-sweep to confirm both bars. *The balance payoff.*

Slices 2 and 3 may merge if Slice 2 turns out small; writing-plans decides.

---

## 7. Key seams (for the implementer)

- `scripts/data/attributes.gd` — `Attributes` (power/composure/attack/control). Teammates reuse this.
- `scripts/data/team.gd` — `Team` (currently `stars` → scalar `batting_strength`/`bowling_strength`). Gains a roster.
- `scripts/data/tour_distribution.gd` — `percentile(frac)` maps stars→strength; archetype scaling hangs off this.
- `scripts/data/innings_result.gd` — `player_line()`, `player_bowl_wickets/runs/balls`. Rating inputs.
- `scripts/data/innings_tuning.gd`, `scripts/data/ball_tuning.gd` — the existing dials (`bowl_overs_*`, `base_w`, etc.).
- `scripts/domain/innings_resolver.gd` — `_build_batters` (clone placeholder to replace), `player_position`, `player_overs`, `partner_factor`.
- `scripts/domain/match_resolver.gd` — `simulate_match_teams` (assembles teams), `simulate_match`.
- `scripts/harness/sweep.gd` — `Sweep.run(arms, n, scenario)`.
- `tools/build_spectrum_sweep.gd` — the build-spectrum sweep to extend.

---

## 8. Defaults recorded (change in review if wrong)

- `wicket_value = 10` runs (strawman); par SR / par economy derived from the generic ★3 player's neutral output.
- Standard XI = 6 BATTER · 1 ALLROUNDER · 4 BOWLER (strawman).
- Archetype stat profiles = strawman, scaled by star level, harness-tunable.
- Assembly capacity proxy = attribute sums; rating (net runs) is verification only.
- Flatness tolerance = ±2% win-rate; rating "equal" within a strawman ±10 net-runs band (refined at calibration).
- 4-over bowling cap unchanged.
- Raw net-runs display only; a 0–100 in-game rating and a visible team sheet are deferred presentation work.

---

## 9. Deferred / out of scope

- Opponent team intelligence (fixed standard XI only; no adaptive opponent build).
- Visible team-sheet UI and a pretty 0–100 rating (presentation layer).
- Per-player careers/identities for teammates (they are archetype instances, not tracked individuals).
- Re-tuning the jokers against the new flat baseline (separate balance pass once this lands).
