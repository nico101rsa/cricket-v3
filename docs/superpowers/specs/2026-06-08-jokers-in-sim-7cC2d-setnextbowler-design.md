# Jokers in the sim — C2d: setNextBowler-fire (design)

**Date:** 2026-06-08 · **Rung:** 7c layer C, sub-slice C2d · **Mode:** AFK
**Prior:** C2c Form & windowed buffs (PR #21, 19 of 45). Reuses the C2c `JokerRuntime` engine.

## 1. What this rung adds

A **bowling change** (the `setNextBowler` Key Moment, ADR 0006) becomes a sim event that fires buff windows — the Wicket Hunter archetype. The engine (`JokerRuntime`) is already built; C2d adds a **second event channel** (bowling-change) alongside C2c's Form-event channel.

**setNextBowler event** = the start of a **new bowling spell at each phase boundary** — overs **1, 7, 16** — in the **opposition's batting innings** (the Player is the bowling captain there), carrying that phase's bowler **Kind** (PACE/SPIN) from the Player's `BowlingPlan`. Requires rotation on (the Player supplies a `BowlingPlan`, already routed to the opp innings since rung 4b). Three spell-starts per innings — a clean, deterministic cadence.

**Pool delta: 19 → 24 of 45.**

## 2. Jokers wired (magnitudes verbatim)

| # | Name | Rarity | Trigger | Payoff |
|---|---|---|---|---|
| 24 | Pace Pack | Common | change → pace | wicket ×1.15 for 6 balls |
| 25 | Spinner's Web | Common | change → spin | wicket ×1.15 for 6 balls |
| 27 | First-Change Specialist | Rare | any change | wicket ×1.20 for 6 balls (catching-field set simplified away) |
| 30 | The Strike Bowler | Legendary | any change **into a catching field** | wicket ×1.35 for 12 balls (Form +1 grant simplified away) |
| 28 | The Trap | Rare | *stateless*: catching field **and** current bowler = spin | wicket ×1.25 per ball |

## 3. Model + engine extensions

- `JokerEffect.Trigger` gains `CHANGE_PACE`, `CHANGE_SPIN`, `CHANGE_ANY`. A change-trigger joker reuses `field_req` as an optional gate (for #30: `field_req = CATCHING` → fires only on a change into a catching field).
- `JokerEffect.bowler_type_req: int = -1` — a **stateless** condition (PACE/SPIN) for #28 (`trigger = NONE`, so it flows through `matches()` like any per-ball joker). `matches()` gains a trailing `bowler_type := -1`.
- `JokerRuntime.on_bowling_change(jokers, bowler_kind, field_mode)` — pushes a buff **immediately** (`balls_left = window_n`, so it covers the change over onward; called *before* `tick_mults` at the spell's first ball). Gates each CHANGE_* joker by kind and by `field_req`.

## 4. Threading

In `simulate_innings`, when rotation is on (`bowling_plan != null`) **and the Player is bowling** (`not player_is_batting`): at the first ball of overs 1/7/16, call `runtime.on_bowling_change(jokers, bowling_plan.for_over(over), field_mode)` before resolving. Also compute the current `bowler_type = bowling_plan.for_over(over)` (else -1) and pass it to `JokerResolver.roll_mults` for #28. No new public params on `simulate_match(_teams)`.

**Determinism:** fires on fixed overs, no RNG. Off-by-default: no `BowlingPlan` → no change events → byte-identical to pre-C2d.

## 5. Decisions (AFK)

- **D1 — spell-start cadence (overs 1/7/16).** A fresh spell per phase is the cleanest controllable cadence that reuses the existing `BowlingPlan` routing; alternating-every-over would trivialise the jokers, phase-change-only (2/innings) is too sparse.
- **D2 — `setNextBowler` only in the opposition's batting innings.** The Player captains the bowling there; in the Player's own batting innings the opposition's (textbook) rotation doesn't fire Player jokers.
- **D3 — #27 field-set + #30 Form-grant simplified away; keep the EV-bearing wicket buffs.** Same precedent as #7/#18 — the secondary state-writes (set catching field / +1 Form) are combinatorial extras with little standalone harness value; noted.
- **D4 — #28 The Trap is stateless** (`bowler_type_req` + `field_req`), read per ball from the current over's bowler Kind — "most-recent setNextBowler = spin" ≈ "current bowler is spin."
- **D5 — reuse `field_req` as the change-trigger gate for #30** rather than a new field.

## 6. Catalog + sweep

`implemented_groups()` 19 → 24. The sweep already passes a `FieldPlan`; add a shared **`BowlingPlan`** (so change events fire) and the catching field in the relevant phase so #30 can fire. New jokers auto-appear; add a "Wicket-Hunter stack" arm (#24+#25+#27+#30). Refresh viewer `DATA`.

## 7. Tests (green past 275)

- `test_joker_runtime.gd`: `on_bowling_change` pushes a buff that applies from the change over for exactly `window_n` balls; CHANGE_PACE fires only on pace; `field_req` gates a change-trigger joker; CHANGE_ANY fires on both kinds.
- `test_joker_effect.gd`: `bowler_type_req` gate on/off/any (#28 shape).
- `test_joker_catalog.gd`: 24 groups; new ids/triggers; The Trap stateless shape.
- `test_innings_jokers.gd`: Pace Pack raises opposition wickets with an all-pace plan; The Trap raises wickets under catching+spin; determinism.
