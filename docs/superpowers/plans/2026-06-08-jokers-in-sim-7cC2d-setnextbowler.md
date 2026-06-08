# Plan — Jokers in the sim · C2d setNextBowler-fire

Spec: `docs/superpowers/specs/2026-06-08-jokers-in-sim-7cC2d-setnextbowler-design.md`. Test-first, inline. Green past **275**. Branch `jokers-c2d-setnextbowler`.

## Task 1 — `JokerEffect`: CHANGE_* triggers + `bowler_type_req`
- Trigger enum += `CHANGE_PACE, CHANGE_SPIN, CHANGE_ANY`. Add `var bowler_type_req: int = -1`; `make()` trailing `p_bowler_type_req := -1`; `matches()` trailing `bowler_type := -1` with `bowler_type_ok`.
- Tests: bowler_type gate; CHANGE_* joker still returns false from matches().

## Task 2 — `JokerRuntime.on_bowling_change(jokers, bowler_kind, field_mode)`
- Push buff immediately (balls_left = window_n) for each CHANGE_* joker whose kind + field_req match.
- Tests: applies from change over for window_n balls; kind gating; field_req gating; CHANGE_ANY both kinds.

## Task 3 — thread into `simulate_innings`
- Compute `bowler_type` per over (bowling_plan.for_over(over) else -1); pass to roll_mults.
- When `bowling_plan != null and not player_is_batting` and at first ball of overs 1/7/16: `runtime.on_bowling_change(jokers, bowler_type, field_mode)` before resolve.
- Tests: Pace Pack raises opp wickets (all-pace plan); The Trap raises wickets (catching+spin); determinism.

## Task 4 — catalog (19 → 24)
- #24 Pace Pack (CHANGE_PACE wkt 1.15 n6), #25 Spinner's Web (CHANGE_SPIN 1.15 n6), #27 First-Change Specialist (CHANGE_ANY 1.20 n6), #30 The Strike Bowler (CHANGE_ANY field_req CATCHING 1.35 n12), #28 The Trap (stateless bowler_type SPIN + field CATCHING, 1.25).
- Tests: 24 groups; shapes.

## Task 5 — sweep + viewer
- `tools/sweep_jokers.gd`: add a shared `BowlingPlan` (so changes fire) + ensure a catching phase for #30; add "Wicket-Hunter stack" arm. Refresh viewer DATA.

## Close
- Suite green; commit; PR; merge; sync; roadmap.
