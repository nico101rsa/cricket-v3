# Jokers in the sim — C2e: Manager Boost (design)

**Date:** 2026-06-08 · **Rung:** 7c layer C, sub-slice C2e · **Mode:** AFK
**Prior:** C2d setNextBowler (PR #22, 24 of 45). Reuses the `JokerRuntime` engine. **ADR 0005** (Manager Boost).

## 1. What this rung adds

The **Manager Boost** (ADR 0005): a side-aware buff the Player presses — *"all-Attribute buff for your batters (batting) or your bowler (bowling), strength × meter-fill, for a window."* The only baseline decision is *when* to press; **all Boost depth is Joker territory** (the Boost Stack archetype, #31–#37, *modifies* the press). C2e models the Boost as a base buff and wires the 7 jokers that bend it.

**Boost model (harness):** a `BoostPlan` lists the overs the Player presses. A press fires a **side-aware base buff** — batting → runs ×`base_mult`, bowling → wicket ×`base_mult` — for `base_n` balls (strawman `base_mult 1.15`, `base_n 6`; the fill²/timing nuance of ADR 0005 is a tuning detail deferred). The base Boost is a **baseline mechanic** (fires whenever a `BoostPlan` is set, even with no jokers); the Boost Stack jokers modify or chain off it.

**Pool delta: 24 → 31 of 45.**

## 2. Jokers wired (magnitudes verbatim)

| # | Name | Rarity | Boost-press effect |
|---|---|---|---|
| 31 | Power Up | Common | window `n += 2` |
| 32 | Boost Battery | Common | + a side-aware kicker (runs/wicket ×1.10) for the window |
| 33 | Boost Adrenaline | Common | fire a Player Form event (chains into C2c Form jokers) |
| 34 | Pedal to the Metal | Common | the press counts as Aggressive intent (enables #36) |
| 35 | Power Surge | Rare | `mult ×= 1.20`, `n += 3` |
| 36 | Compounding Pressure | Rare | if Aggressive: + runs ×1.25 & wicket ×0.85 (batting) / mirror (bowling) for the window |
| 37 | The Comeback Press | Legendary | every press fires Form +2; on the **3rd** press `mult ×= 1.50`, `n += 6` |

## 3. Model + engine extensions

- `BoostPlan` (`scripts/data/boost_plan.gd`): `press_overs: Array[int]`, `base_mult := 1.15`, `base_n := 6`, factory `at(overs)`.
- `JokerEffect`: `enum BoostRole { NONE, EXTEND, BATTERY, ADRENALINE, PEDAL, AMPLIFY, COMPOUND, COMEBACK }`, `var boost_role := BoostRole.NONE`. A `boost_role != NONE` joker is a Boost modifier — `matches()` returns false (never per-ball), and it has `trigger == NONE` so the Form/change channels skip it.
- `JokerRuntime`:
  - `var boost_press_count := 0`.
  - `on_boost_press(jokers, player_is_batting, intent, base_mult, base_n, ball)` — computes the modified `(mult, n)`, pushes the side-aware base buff + any chain buffs, fires Form chains for ADRENALINE/COMEBACK. Magnitudes per role are pool-fixed constants in the runtime.
  - Extract `_push_form_buffs(jokers, player_is_batting, ball)` (the Form-window push already used by `on_ball_end`) so ADRENALINE/COMEBACK reuse it.

## 4. Threading

`simulate_innings` gains `boost_plan: BoostPlan = null`. At the first ball of each `press_over` (over start), call `runtime.on_boost_press(...)` before `tick_mults` (so the Boost applies from that over). `simulate_match(_teams)` gains `boost_plan` and passes it to **both** innings (the Player presses while batting *and* while bowling). Off-by-default: no `BoostPlan` → no presses → byte-identical. Determinism: presses on fixed overs, no RNG.

## 5. Decisions (AFK)

- **D1 — base Boost is a baseline mechanic, not a joker.** It fires whenever a `BoostPlan` is set; the 7 jokers modify it. In the sweep all arms share the `BoostPlan`, so the base Boost is in every arm and the win-*delta* is the joker.
- **D2 — side-aware base buff via the roll multipliers** (batting→runs, bowling→wicket), the same currency every joker uses. ADR 0005's fill²/meter-drain shaping is a later tuning dial; a flat `base_mult/base_n` per press suffices for the harness.
- **D3 — #34 Pedal and #33 Adrenaline are enablers** (no solo roll EV): Pedal flips the press to Aggressive (enables #36); Adrenaline only matters with Form jokers. Documented (≈0% solo, like Defensive Captain).
- **D4 — #33/#37 fire the C2c Form channel at the press** (`_push_form_buffs`) — a genuine Boost→Form synergy showcase, reusing existing logic.
- **D5 — press in both innings** (batting and bowling) for harness coverage; a single-Boost-per-match economy (meter recharge, ~6 presses/match) is a Theme-2/economy refinement, not needed to sweep the jokers.

## 6. Catalog + sweep

`implemented_groups()` 24 → 31. Add a shared `BoostPlan` to the sweep (presses in powerplay + death) so the Boost fires; the base Boost shifts the baseline (shared across arms). Add a "Boost-stack stack" arm (#31+#32+#35+#36+#37). Refresh viewer.

## 7. Tests (green past 286)

- `test_boost_plan.gd` (new): `at()` factory; `for_over`/`presses_on` lookup.
- `test_joker_effect.gd`: a `boost_role != NONE` joker returns false from `matches()`.
- `test_joker_runtime.gd`: a bare press pushes a side-aware base buff for `base_n`; Power Up extends n; Power Surge amplifies; Comeback amplifies only on the 3rd press; Boost Battery adds a kicker; Compounding fires only when Aggressive (or Pedal present); Adrenaline chains a Form buff.
- `test_joker_catalog.gd`: 31 groups; the 7 boost_roles present.
- `test_innings_jokers.gd`: a BoostPlan raises Player runs (batting innings); Power Up beats a bare Boost; determinism.
