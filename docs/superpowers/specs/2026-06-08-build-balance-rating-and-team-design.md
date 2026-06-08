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

### 3.5 Fairness target + wicket-value validation (what we tune toward)

Across the build spectrum at even ★3, the **mean rating per build** should be roughly equal: `rating(pure-batter) ≈ rating(pure-bowler) ≈ rating(all-rounder)`. This is the *individual* half of the goal.

**`wicket_value` is the primary knob here, and it is solved empirically, not assumed** (Nico's flag). A bowler's whole rating rides on `W * wicket_value` while a batter's does not, so the wicket value is exactly what trades batter-vs-bowler parity. Procedure: over a large run (≥2000 matches per build), sweep `wicket_value` and pick the value at which a pure bowler's mean rating equals a pure batter's. The strawman 10 is a starting guess — the sweep may land it lower or higher (a wicket could be worth more or less); **the calibration output records the value we actually found and confirms it's stable across the run, not an artifact of a small sample.** If `wicket_value` alone can't reconcile them, the par-lines (`sr_par`/`rr_par`) are the secondary levers.

---

## 4. System 2 — Build-adaptive discrete team

The big architectural piece. Today a `Team` is two derived ints (`batting_strength`, `bowling_strength`) and `InningsResolver._build_batters` clones all 10 teammates at one `partner_batting` number. We replace that placeholder with a **real roster of individual players**, assembled to fill the Player's gap.

### 4.1 The roster model

A team becomes an **XI of 11 individual players**, each an `Attributes` (the same 4 stats the Player uses) carrying an implied role. **Every player is a 20-point distribution** — the same budget the Player gets (sum 20, each stat [1,8]) — so a whole team is exactly **20 × 11 = 220 points** at the even-★3 test level. (Per-player budget scales with star level for non-★3 teams; deferred — the opponent is a fixed ★3 standard XI for now.) Each player's 20 points split into **batting points** (power + composure) and **bowling points** (attack + control); the team's two totals sum to 220.

Players are drawn from a small set of **archetypes** (data, harness-tunable; each a valid 20-point distribution):

| Archetype | power | composure | attack | control | bat pts / bowl pts | role |
|---|---|---|---|---|---|---|
| BATTER | 8 | 8 | 2 | 2 | 16 / 4 | top order |
| BOWLER | 2 | 2 | 8 | 8 | 4 / 16 | attack (also the "tail" with the bat) |
| ALLROUNDER | 5 | 5 | 5 | 5 | 10 / 10 | flex |

(Strawman distributions, all valid 20-point builds; harness-tunable. In a 20-point world there is no separate "useless tail" — a tail-ender is just a BOWLER whose points went to bowling, so they bat weakly. Intermediate tilts, e.g. 7/6/4/3, are allowed if calibration wants finer steps.)

### 4.2 The fixed standard XI (the opponent, and the Player's baseline)

A realistic T20 shape, used unchanged by the opponent every match (D3 — "set standard for now"). Strawman template: **6 BATTER · 1 ALLROUNDER · 4 BOWLER** = 220 points, splitting ~**(6·16 + 10 + 4·4) = 122 batting / 98 bowling** points (teams bat deeper than they bowl — realistic). That **(122, 98) split** is the target every Player team must hit.

### 4.3 Gap-fill assembly (the heart of it)

The Player occupies one slot; the other 10 (= 200 points) are chosen so the team's split lands back on the standard **(122, 98)** — i.e. the team is always 220 points carved the same way, whatever the Player spent their 20 on:

1. Start from the standard XI.
2. Insert the Player in the slot matching their dominant role (replacing that archetype).
3. **Re-balance by swapping teammate archetypes** until team batting points ≈ 122 and bowling points ≈ 98 (within tolerance): a pure batter (16/4) overshoots batting and starves bowling, so swap a BATTER teammate → BOWLER to put the points back on the bowling side; a pure bowler does the reverse; an all-rounder (10/10) ≈ the displaced ALLROUNDER, so the standard mix already balances.

This produces exactly Nico's picture: pick a batter → the team carries an **extra bowler**; pick a bowler → an **extra batter**; pick an all-rounder → the freed flex points become **one more specialist**. The point-split is the cheap **assembly proxy**; the net-runs rating (§3) and win-rate (§5) are the accurate **verification** — points aren't perfectly linear in runs (a batter at #1 out-leverages the same points in the tail), so calibration adjusts archetype profiles/targets until the sweep actually reads flat.

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

- **Individual:** mean rating flat across builds (System 1 tuned) — reached by solving `wicket_value` (§3.5). The calibration run sweeps `wicket_value` over a range and prints the per-build mean rating at each, so we can read off the value that flattens batter-vs-bowler and confirm 10 was right (or replace it). Validate over ≥2000 matches/build so the result isn't sample noise.
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

- Every player = a 20-point distribution (sum 20, each [1,8]); a team = 220 points at ★3. Per-player budget scales with stars for non-★3 teams (deferred).
- `wicket_value` = 10 runs **as a starting guess only** — solved empirically over ≥2000 matches/build (§3.5); calibration records the value actually found. Par SR / par economy derived from the generic ★3 player's neutral output.
- Standard XI = 6 BATTER · 1 ALLROUNDER · 4 BOWLER → target split (122 batting / 98 bowling) points (strawman).
- Archetype profiles = strawman 20-point builds (BATTER 8/8/2/2, BOWLER 2/2/8/8, ALLROUNDER 5/5/5/5), harness-tunable.
- Assembly proxy = batting/bowling point-split; rating (net runs) + win-rate are verification only.
- Flatness tolerance = ±2% win-rate; rating "equal" within a strawman ±10 net-runs band (refined at calibration).
- 4-over bowling cap unchanged.
- Raw net-runs display only; a 0–100 in-game rating and a visible team sheet are deferred presentation work.

---

## 8.5 Slice 2 implementation decisions (2026-06-08, recorded during writing-plans)

Resolving the one design fork the spec left open — archetypes are star-independent (BATTER is always 8/8/2/2), yet `simulate_match_teams` must keep a 5★ team beating a 0.5★ team (the 7b-1 directional regression in `test_match_resolver`). Decisions, all reversible internal seams:

- **D6 — Star-directionality via a uniform batting offset, NOT by re-scaling archetypes.** `Team.batting_strength`/`bowling_strength` stay **exactly as today** (tour-percentile of stars + RNG noise) — so `LeagueResolver` and `test_team` are untouched. The team's batting scalar is then applied as a uniform **offset** to every roster member: `eff_power = power + (team_bat_scalar − ref3)`, same for composure, floored at 1, where `ref3 = tour.percentile(3.0/5.0)` (the even-★3 no-noise batting scalar). **Consequence:** at even ★3 the offset is ~0 (±noise), so the build-spectrum balance baseline is the *pristine* 20-point archetypes (what Slice 3 calibrates against); a 5★ card shifts up (~+2), a 0.5★ card down (~−1), preserving directionality.
- **D7 — Slice 2 = real individual *batting order* only. The bowling side stays the existing star-derived scalar.** The sim has no per-bowler husbanding (which bowler bowls which over) — that is already deferred to a possible 4c rung. So "wire the bowling side" is satisfied at the aggregate-strength level (the bowling scalar is the team's, consistent with its roster), not per-over. No change to how bowling attack/control flow.
- **D8 — Roster threaded as optional trailing params; null = the old clone path.** Only `simulate_match_teams` builds rosters (via `Team.build_xi()`) and passes them down through `simulate_match` → `simulate_innings` → `_build_batters`. Every existing scalar-path caller/test (all of `test_match_jokers`, the joker sweeps, direct `simulate_match`/`simulate_innings` unit tests) passes no roster → byte-identical old behaviour. Determinism is preserved because the RNG draw order (toss + 4 strength draws) is unchanged — rosters are pure data built from already-drawn scalars.
- **D9 — Player insertion (crude, pre-gap-fill).** `simulate_match_teams` builds the player team's order by taking the 11-archetype standard XI and **replacing the archetype at the Player's build-driven `player_position` with the Player** (10 archetype teammates + the Player). This already gives a crude natural displacement (a batter-build slots high ~#3 replacing a BATTER; a bowler-build slots ~#7 replacing the ALLROUNDER; an even build ~#5 replacing a BATTER). True gap-fill that holds the (122/98) split is **Slice 3**. The opponent is the unmodified 11-archetype standard XI.
- **D10 — When a roster is supplied, `_build_batters` drops the synthetic `partner_factor` tail curve** — the archetype order already encodes the weakening tail (BOWLERs bat last with power 2). The tail curve still applies on the null/clone path.

**Expected test impact:** `test_match_resolver`'s determinism tests stay green (still deterministic); its directional (5★>0.5★) + even-balance assertions should hold (re-verify). `build_spectrum_sweep` / `season_preview` / `sweep_*` print-tables shift their numbers (team batting cards are now real individuals) — diagnostics, not assertions. No assertion in the joker tests changes (scalar path untouched).

---

## 9.5 Slice 1 calibration findings (2026-06-08)

Slice 1 shipped the rating + sweep column. Par-lines derived from the generic 5/5/5/5 neutral build: **`sr_par = 111.6`, `rr_par = 6.4`** (so that build rates ~0). Per-build mean rating at `wicket_value = 10` (2000 matches/build, even ★3, neutral Intent):

| build | win% | rating | r-bat | r-bowl | Player wkts/match |
|---|---|---|---|---|---|
| 8/8/2/2 (batter) | 67.1 | 10.7 | 10.7 | 0.0 | 0.00 |
| 5/5/5/5 (all-r) | 51.7 | 4.9 | ~0 | 4.8 | 0.55 |
| 2/2/8/8 (bowler) | 61.8 | **37.8** | −1.1 | 39.1 | 3.17 |

**Key finding (answers Nico's wicket-value flag):** at `wicket_value = 10` the formula **massively over-rates bowlers** (37.8 vs the batter's 10.7). Two compounding causes, both empirical:

1. **The sim hands a 4-over Player bowler ~3.17 wickets/match** — very high for 24 balls (a wicket every ~7.6 balls). At 10 runs each that is ~32 of the bowler's 38 rating.
2. **Economy alone nearly matches the batter:** strip the wickets out (wicket_value→0) and the bowler still rates ~7.4 from runs-saved vs the batter's 10.7 — so *any* positive wicket value tips bowlers ahead.

**Implication:** individual parity can't be reached by lowering `wicket_value` alone — to equalise it would have to fall to ~1, which is unrealistic. The real lever is the **sim's bowler-wicket rate** (3.17/match is too high — it also inflates the bowler build's 62% win-rate).

### 9.5.1 Slice 1b — wicket-rate fix (2026-06-08)

Tuned `BallTuning.k_w` **0.42 → 0.24** (the attack-vs-composure gain; `base_w`/even-contest baseline untouched, so no tests broke). This is a *twofer* — the same gain governs both extremes:

| build | wkts/match (was → now) | bat-avg (was → now) | win% (was → now) |
|---|---|---|---|
| 8/8/2/2 batter | 0 → 0 | 141 → **86** | 67 → 64 |
| 5/5/5/5 all-r | 0.55 → 0.49 | 29 → 31 | 51.7 → 51.5 |
| 2/2/8/8 bowler | **3.17 → 1.90** | 6 → 10 | 62 → 58 |

The 4-over specialist now takes an elite-realistic ~1.9 wkts (was a fantasy 3.17) and the batter's average falls from immortal 141 to a saner 86 (still high — neutral-Intent has no aggression risk per D5, expected). Win-rates compressed modestly toward 50 but are **not flat yet** — that is the team gap-fill's job (Slice 3), not the wicket dial's. Note: the layer-C joker findings were measured at the old `k_w`; their baseline shifts slightly (re-tuning jokers is already deferred, §9). `wicket_value` is left at 10 pending the Slice-3 re-solve against the real team.

### 9.5.2 Slice 2 re-grounded baseline — real rosters (2026-06-08)

Slice 2 shipped the discrete real roster (both teams are now 11 individual archetype players, not a flat ~5 clone). The build-spectrum sweep (2000 even-★3 matches/build, neutral Intent) re-grounds to:

| build | win% | bat-avg | wkts/match | rating | r-bat | r-bowl | team | opp |
|---|---|---|---|---|---|---|---|---|
| 8/8/2/2 (batter) | 48.7 | 81.4 | 0.00 | 8.1 | 8.1 | 0.0 | 172 | 173 |
| 7/7/3/3 | 46.0 | 59.3 | 0.00 | 5.2 | 5.2 | 0.0 | 170 | 172 |
| 6/6/4/4 | 45.3 | 38.2 | 0.09 | −0.6 | 0.9 | −1.8 | 170 | 172 |
| 5/5/5/5 (all-r) | 46.1 | 28.0 | 0.19 | −3.0 | −0.1 | −3.0 | 170 | 172 |
| 4/4/6/6 | 48.8 | 18.8 | 0.24 | −1.5 | −0.2 | −1.2 | 170 | 171 |
| 3/3/7/7 | 53.4 | 11.2 | 0.52 | 1.1 | −0.1 | 1.3 | 171 | 169 |
| 2/2/8/8 (bowler) | **59.0** | 9.1 | 0.85 | 5.8 | −0.1 | 6.0 | 169 | 166 |

**The shape inverted.** Pre-roster (§9.5.1) the *batter* was the win-rate high (64) and the bowler 58; now the *bowler* is the high (**59.0**) and the batter sits at the fair line (48.7), with a **U-shaped valley** bottoming at the all-rounder/mid-builds (~45–46). Why: every team now carries a genuinely strong top order (six power-8 batters → team scores jumped to ~170), so a batter-Player merely displaces one of six strong batters (marginal) while a bowler-Player adds a real 4-over bowling lever the team doesn't otherwise concentrate. Two honest consequences of real opposition: Player **wickets/match collapsed** (bowler 0.85 vs the old 1.90 — bowling at a real power-8 top order is much harder) and **bat-avg fell** (batter 81 vs 86). The collapsed wicket rate also **defused the wicket_value=10 over-rating** — ratings now sit in a tight [−3, +8] band (was 11 vs 38), though still not flat: the all-rounder/mid-builds rate *worst* (the new dip to solve).

**Neither bar is met yet — as expected; both are Slice 3's job.** Slice 3's gap-fill must (a) flatten the U so all builds land ~50% (the bowler's +9 edge and the mid-build −5 dip are the targets — likely by adjusting how the Player's build displaces teammates so a bowler-Player doesn't get a "free" extra lever), and (b) re-solve `wicket_value` and/or archetype profiles so the rating band flattens too. The honest read: making teams real didn't *flatten* balance, but it **re-grounded it on a realistic foundation** and revealed the true lever (the Player's marginal contribution to an already-strong team), which is exactly what gap-fill needs to target.

---

## 9. Deferred / out of scope

- Opponent team intelligence (fixed standard XI only; no adaptive opponent build).
- Visible team-sheet UI and a pretty 0–100 rating (presentation layer).
- Per-player careers/identities for teammates (they are archetype instances, not tracked individuals).
- Re-tuning the jokers against the new flat baseline (separate balance pass once this lands).
