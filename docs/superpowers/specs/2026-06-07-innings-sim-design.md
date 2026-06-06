# Single-innings batting sim — design spec

**Date:** 2026-06-07
**Theme:** 7a (Tech foundation → match sim core), rung 2 of 4 (ball → **innings** → match → Intent/KMs)
**Status:** Approved (design shape) — ready for `writing-plans`
**Builds on:** `BallResolver.resolve_ball()` (spec `2026-06-06-ball-resolution-design.md`)
**Implements:** ADR 0004 (auto-sim architecture — headless, deterministic-seedable, only-Player-statted)
**Companion visual:** `docs/mockups/innings-sim-v1.html`

---

## 1. Scope

One pure domain class that simulates **one team's T20 innings** by looping the existing single-ball atom, returning a deterministic `InningsResult`. This is rung 2 of the bottom-up match sim: it turns a single ball into a full batting card.

**In scope:**
- 11 batters: the Player (statted) + 10 derived from team batting strength.
- Build-driven batting position (a batter-shaped Player opens; a bowler-shaped Player bats the tail).
- A weakening lower order (the tail bats worse).
- Real strike rotation (odd runs swap strike; ends of overs swap strike).
- Innings termination at **10 wickets or 120 balls** (T20 — fixes the ball spec §9 "no clock → defence over-rewarded" gap with a finite over limit).
- A `fall_of_wickets` line and the Player's individual batting line.

**Out of scope (deferred to later rungs, do not build here):**
- Opponent innings, chase logic, match result (rung 3 — calls this resolver twice and compares).
- Bowler-rotation policy — here a **single constant** opposition bowling profile bowls all 120 balls.
- Intent-setting UI / Key Moments — Intent is fixed **Balanced** every ball.
- Form, Jokers, Manager Boost, conditions — the modulation layers stay off; this is the bare loop on raw attributes.
- Extras (wides/no-balls/byes), run-outs, dismissal types, runs on a wicket ball.
- The `stars → battingStrength/bowlingStrength → attributes` derivation pipeline. This resolver takes the **derived numbers as inputs** (the same way `resolve_ball` takes the bowler's two numbers raw); the pipeline is a rung-3 / match-setup seam.

## 2. The contract

A pure function — no scene tree, no member state, no I/O. Lives at `scripts/domain/innings_resolver.gd` (project convention for pure domain logic).

```
InningsResolver.simulate_innings(
    player_attrs: Attributes,        # the statted batter (Power/Composure bat; all four set position)
    partner_batting: int,            # derived team batting strength -> partners' base Power & Composure
    opp_attack: int,                 # constant opposition bowling Attack (all 120 balls)
    opp_control: int,                # constant opposition bowling Control
    tuning: BallTuning,              # existing ball coefficients
    innings_tuning: InningsTuning,   # new: position map + tail curve + over limit (data, not code)
    rng: RandomNumberGenerator
) -> InningsResult
```

**Determinism:** the innings is deterministic-seedable (ADR 0004). It consumes `rng` only through `resolve_ball`, which has a fixed draw order (wicket roll always; runs roll only if survived). Same inputs + same seed → identical `InningsResult`, every time. This is what lets the future balance harness re-run thousands of innings.

## 3. Build → batting position

The Player's batting position is derived from their build, so a batter-shaped build faces more balls and a bowler-shaped build faces fewer — participation responds to the build automatically.

```
batting = player.power + player.composure
bowling = player.attack + player.control
share   = batting / (batting + bowling)          # in (0, 1)
position = clamp(round(pos_base - pos_span * share), 1, 9)
```

With strawman `pos_base = 9`, `pos_span = 8`: a pure batter lands ~#1–2, an all-rounder ~#5, a pure bowler #9. The constants live in `InningsTuning` (harness-swept later).

## 4. Derived partners + weakening tail

- **Base partner:** Power = Composure = `partner_batting` (a single derived team batting strength; role differentiation beyond the tail curve is out of scope).
- **Weakening tail:** a partner batting at order position `p` (1-based) is scaled by
  `factor(p) = max(tail_floor, 1 - (p - 1) * tail_slope)`
  so openers sit near full strength and #11 sits near the floor. Strawman `tail_floor = 0.45`, `tail_slope = 0.07`.
- The **Player is exempt** from the tail curve — they always bat at their real attributes, wherever the build places them.
- **Opposition bowling** is the constant `(opp_attack, opp_control)` for all 120 balls (rotation deferred).

## 5. Strike rotation & the innings loop

- Two batters at the crease. Start: order #1 on strike, #2 at the non-striker's end; next batter in is #3.
- Each ball: `resolve_ball(striker.power, striker.composure, opp_attack, opp_control, BALANCED, tuning, rng)`.
  - **Wicket:** the striker is out → record the fall (wicket #, score, batter, ball #) → `wickets += 1`. If `wickets == 10` the innings ends; otherwise the next batter in comes to the crease **on strike**.
  - **Runs:** add to the striker's tally and the team total. If the runs are **odd**, swap striker / non-striker.
- **End of over** (every 6 balls bowled): swap striker / non-striker.
- **Terminate** when `wickets == 10` **or** `balls == 120`. The not-out batter(s) carry `*`.

## 6. `InningsResult`

A lightweight result holder (`RefCounted` or small `Resource`), `scripts/data/innings_result.gd`:

- `total: int`
- `wickets: int` (0–10)
- `balls: int` (overs derivable as `balls / 6`)
- `fall_of_wickets: Array` — per fall: wicket number, score at fall, batter index, ball number.
- `batters: Array` — per batter: order position, `is_player: bool`, `runs`, `balls`, `out: bool`.
- `player_line` — convenience accessor returning the Player's row from `batters` (runs / balls / out / position).

**No per-ball log by default.** The ball spec's perf note flags `BallOutcome` as a per-ball `RefCounted` allocation; storing a full ball-by-ball trace for every harness innings would multiply that. Rung 2 stores aggregates only; an opt-in trace can be added later if the harness needs ball-level data.

## 7. Tuning data — `InningsTuning` (new resource)

All innings-level coefficients live in **data, never hardcoded** — same philosophy as `BallTuning` (ADR 0004; the harness sweeps the data). `scripts/data/innings_tuning.gd`:

```
over_limit: int  = 20        # -> 120 balls
pos_base:   float = 9.0      # build -> position map
pos_span:   float = 8.0
tail_floor: float = 0.45     # weakening-tail curve
tail_slope: float = 0.07
```

Strawman defaults — the companion visual encodes them; Theme 7c replaces them with swept, measured values.

## 8. Test plan (TDD, red → green)

Pure function with an injected RNG → unit-testable in isolation. Tests assert **shape and relationships**, not exact tuned numbers; statistical tests use fixed seeds + generous tolerances so they are deterministic, not flaky.

1. **Determinism** — same seed + inputs → identical `InningsResult` (total, wickets, fall sequence) across repeated calls.
2. **Termination** — `balls` never exceeds 120; `wickets` never exceeds 10; the loop stops the instant the 10th wicket falls.
3. **Build → position monotonic** — a pure-batter build yields a position ≤ 3; a pure-bowler build yields a position ≥ 7.
4. **Participation responds to build** — averaged over seeds, a batter-build Player faces more balls than a bowler-build Player (same opposition).
5. **Weakening tail** — averaged team total with the tail curve is lower than with flat partners; tail batters score/face less down the order.
6. **Sane total band** — even contest (Player 5/5/5/5, `partner_batting` 5, opp 5/5), averaged over N seeds, lands in a believable T20 band (~110–175). (Validated live in the companion visual at ~141/4.)
7. **Strike-rotation parity** — odd runs swap strike; ends of overs swap strike (observed via participation / a deterministic check).
8. **Player line integrity** — the Player's runs ≤ team total and balls ≤ team balls; `player_line` matches the Player's row in `batters`.

## 9. What this de-risks / sets up

- Confirms the **existing** `BallTuning`, looped, produces sane T20 totals (no retuning needed for the atom — validated in the sandbox).
- Rung 3 (opponent innings + chase + result) becomes "call this resolver twice and compare," with bowler-rotation and the two open auto-sim questions handled at that level.
- Bowler rotation, Intent/Key Moments, Form, and the stars→attributes pipeline all stay cleanly deferred behind the input seam.

## 10. Open questions

None blocking. The build→position map, tail curve, and over limit are all strawman tuning data — exactly what Theme 7c exists to measure and tune.
