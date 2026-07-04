# T9 — Boost Water-Meter (ADR 0005 alignment)

**Date:** 2026-07-04 · **Rung:** playtest fix T9 (medium) · **Mode:** AFK (defaults recorded, not asked)
**Design authority:** `docs/adr/0005-manager-boost-no-menu.md`

## 1. Problem

ADR 0005 specifies the Manager Boost as a **water-meter**: press locks magnitude from the
meter's current fill % (linear), the meter **drains** during the active boost, the boost ends
when the meter hits 0, then recharge begins (~25 s to full), giving **~6 full presses per
match** and a single "when do I spend it?" decision.

What's built instead is a **per-innings press budget**: `MatchSession.BOOST_BUDGET = 2`
flat presses per innings, each a fixed `×1.15 for 6 balls` buff
(`BoostPlan.base_mult/base_n` → `JokerRuntime.on_boost_press`). No fill, no drain, no
recharge — a real deviation from the design authority, flagged in Nico's playtest triage.

## 2. Core mapping decision — wall-clock → balls

The match is a ball-stepped deterministic re-sim (`MatchSession._resim`): every decision
re-runs the pure resolver from the seed, so the meter **cannot** run on wall-clock seconds
(replay-from-decisions and headless careers have no clock). **The meter ticks per BALL.**

At 1× autoplay one event ≈ 0.6 s (`interactive_match.gd BASE_TICK`), so the chosen
recharge window (34 balls, §4) plays out at roughly 20–25 s of watching at normal speed —
inside the ADR's "~25 s" intent. Recorded as the translation rule, not a new design.

## 3. Approaches considered

- **A (chosen): per-innings ball-ticked meter inside the innings resolver.** A small pure
  `BoostMeter` ticked once per ball in `InningsResolver.simulate_innings`; fill logged per
  ball so the UI reads it back. Meter resets to full each innings. Deterministic, headless
  and live share one implementation, innings resolver stays self-contained.
- **B: match-spanning meter carried across innings.** More literally "per match", but the
  meter state would have to thread through `simulate_match`'s four `simulate_innings`
  call-sites and the innings-order branches. Rejected: complexity for no player-visible
  gain — a full-at-innings-start meter yields the same ~6 full presses per match.
- **C: wall-clock meter in the scene.** The UI drains a real-time gauge and records presses
  at arbitrary balls. Rejected outright: breaks the determinism contract (same seed + same
  decisions must reproduce the match), and the headless career could not share it.

## 4. The meter (decisions DW1–DW6)

- **DW1 — state:** `fill ∈ [0,1]`, **starts full at each innings start** (fresh innings,
  fresh manager energy; also what keeps "~6 full presses/match" while preserving the
  existing per-innings press bookkeeping `[innings_no, over]`).
- **DW2 — lock at press (linear, per ADR):** pressing at fill `F` fires the existing buff
  channel with
  `mult = 1 + F × (base_mult − 1)` and `n = max(1, round(F × base_n))` balls.
  `BoostPlan.base_mult = 1.15`, `base_n = 6` keep their meaning as the **full-fill** press —
  a press at 100% is byte-identical to today's press. Total value ≈ F² (ADR's single-axis
  trade: stronger AND longer).
- **DW3 — drain:** while the boost is active the meter drains linearly from `F` to 0 over
  the `n` locked balls (empty exactly when the buff ends). A press while draining is
  **ignored** (resolver) / **blocked** (UI) — one boost at a time, per ADR.
- **DW4 — recharge:** `+1/34 per ball` after the drain ends, capped at 1.0.
  Full cycle = 6 drain + 34 recharge = **40 balls** → up to **3 full presses per 120-ball
  innings → ~6 per match** (ADR's number). 34 balls ≈ 20–25 s at 1× (§2).
- **DW5 — minimum press:** a press below **25% fill** is ignored/blocked
  (`MIN_PRESS_FILL = 0.25`) — prevents degenerate 1-ball confetti presses; the weakest
  legal press is ×1.04 for 2 balls.
- **DW6 — no press budget:** `BOOST_BUDGET`/`presses_left` are **removed**. The meter IS
  the budget (ADR: the only decision is *when*). The badge shows fill %, not presses left.

## 5. Seams and who changes (DW7–DW10)

- **DW7 — `BoostMeter` (new, `scripts/domain/boost_meter.gd`):** pure per-innings state
  machine — `fill()`, `tick()` (one ball: drain or recharge), `try_press()` → locked
  `{fill, mult, n}` or `{}` (draining / under min). No RNG, no clock. Constants live here
  (`RECHARGE_BALLS = 34`, `MIN_PRESS_FILL = 0.25`).
- **DW8 — `InningsResolver`:** builds one `BoostMeter` per boost plan (player's AND
  opponent's `opp_boost_plan` — DF4 symmetry is preserved by construction), ticks per ball,
  and at a `presses_on(over)` over-start asks `try_press()`; on success calls the
  **unchanged** `JokerRuntime.on_boost_press(jokers, …, locked_mult, locked_n, ball)`.
  Every ball-log row gains `"boost_fill"` (the player's-side fill at ball start, post-press)
  so the UI reads the same number the sim used. Jokers (EXTEND/AMPLIFY/COMEBACK/BATTERY/
  COMPOUND/ADRENALINE/PEDAL) keep operating on `(mult, n)` exactly as today — their windows
  may outlast the drain (the buff glows on past an empty meter); drain follows the
  fill-scaled **base** window only. ADR's "Jokers can buff fill speed/magnitude/window"
  stays future joker territory — no joker re-authoring in this rung.
- **DW9 — `MatchSession`:** `can_boost(innings_no, over)` now consults the log-derived
  meter (fill ≥ 25% and not draining at that over's start); `decide_boost` guards with the
  same check so an ignored press never enters `_presses` (the resolver still defensively
  ignores invalid presses from arbitrary headless plans). New `boost_fill(innings_no, over)`
  → float for the gauge. `presses_left` and `BOOST_BUDGET` deleted; `export_decisions`
  format unchanged (still `[innings, over]` pairs — old saves replay, presses re-validate).
- **DW10 — scene (`interactive_match.gd`):** the round BOOST button becomes the gauge:
  badge shows fill % ("88%"), "ON" while draining; button disabled while draining or under
  25%. Button style unchanged otherwise (`UIStyle.boost_button/boost_badge`) — no new art.

## 5b. Pre-existing bug folded in (DW13)

**Live presses currently double-fire.** `MatchSession._resim` flattens its
`[innings_no, over]` press pairs into `BoostPlan.press_overs` (a flat over list), and
`InningsResolver` checks `presses_on(over)` with **no innings awareness** — so a live press
at over 5 of your batting innings ALSO fires (side-aware) at over 5 of the innings where
you bowl. The in-code comment "resolver checks per innings" is wrong. Invisible today;
under a visible fill gauge it would read as the meter draining with no press. **Fix in this
rung:** `BoostPlan` gains `press_pairs` (innings-aware) + `for_innings(n)` → a filtered
flat plan; when `press_pairs` is empty the plan behaves exactly as before (headless flat
plans like `at([1,10,16])` intentionally fire in both innings — that's how boost jokers
were priced). `MatchResolver`'s four `simulate_innings` call-sites pass
`boost_plan.for_innings(1|2)`; `MatchSession` fills `press_pairs`. Note: the old Boost
lever number (+1.5) was measured WITH the double-fire — another reason §7 re-measures.

## 6. Headless careers + pricing knock-on (DW11)

`ShopResolver.plans_for` keeps pressing at overs `[1, 10, 16]` when a boost-role joker is
owned. Under the meter those land at fill **1.00 / 1.00 / ~0.88** (drain 6 + recharge 34
timeline), so headless boost careers barely move; the **no-joker fair-fight floor carries
no boost plan at all and is untouched by construction**. Boost-role joker prices are NOT
re-derived in this rung; if the lever check (§7) shows the interactive boost moved a lot,
re-pricing the 5 boost-role jokers becomes a flagged follow-up, not scope creep here.

## 7. Balance gate (DW12)

1. **Floor:** `tools/sweep_form_balance.gd` — every build stays in the 48–49% fair-fight
   band (same harness + N as the T8 gate; results table goes in this spec's §9).
2. **Lever:** the Boost arm of `tools/sweep_interactive_levers.gd` re-measured (was
   **+1.5 win-pts**, N=4200 matches/arm, ±0.7pp — 2026-06-17 lever spec). Acceptance band
   for the new Boost lever alone: **+2 to +8 win-pts** — it *should* strengthen (ADR gives
   it more total buff-balls) but must stay well under the Key-Moment lever (±14). Outside
   the band → tune `base_mult` (first) or `RECHARGE_BALLS` (second) and re-run.

## 8. Tests (TDD)

- `test_boost_meter.gd` (new): fill starts full; drain hits 0 exactly at buff end; recharge
  rate; cap at 1.0; press-while-draining ignored; sub-25% ignored; partial-fill lock math
  (F=0.5 → ×1.075 for 3 balls); 40-ball full cycle → 3 full presses in 120 balls.
- `test_match_session.gd`: budget tests replaced — unlimited presses bounded by meter;
  `can_boost` false while draining; `boost_fill` matches the log; a full-fill press
  reproduces the pre-rung buff **within the pressed innings** (per DW13 it no longer
  leaks into the other innings — asserted: the other innings matches the no-press sim).
- `test_boost_plan.gd`: `for_innings` filtering; empty `press_pairs` → flat plan unchanged.
- `test_fair_fight_baseline.gd`: existing over-1 (full-fill) presses stay byte-identical —
  the DF4 tests should pass **unchanged**; that's itself the regression proof.
- Scene test: badge renders a percent; disabled under min fill.

## 9. Results (filled after the gate)

*(sweep table + lever number land here before merge)*
