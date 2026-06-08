# Plan — Jokers in the sim · C2c Form & windowed-trigger buffs

Spec: `docs/superpowers/specs/2026-06-08-jokers-in-sim-7cC2c-form-windowed-design.md`. Test-first, inline. Green by count climbing past **258**. Branch `jokers-c2c-form`.

## Task 1 — `JokerEffect`: trigger shape
- Add `enum Trigger { NONE, FORM_BAT, FORM_BOWL, FORM_DOUBLE_BAT }`, `var trigger: int = Trigger.NONE`, `var window_n: int = 0`. Extend `make()` trailing `p_trigger := Trigger.NONE, p_window_n := 0`.
- `matches()`: return false immediately if `trigger != Trigger.NONE` (stateless seam ignores trigger jokers).
- Tests: trigger joker never matches per-ball.

## Task 2 — `JokerRuntime` engine (new `scripts/domain/joker_runtime.gd`)
- `active: Array` of `{side, target, mult, balls_left}`; `form_event_balls: Array[int]`.
- `tick_mults(player_is_batting) -> Vector2`: product of active buffs whose side matches.
- `on_ball_end(jokers, player_is_batting, ball, formed)`: decay first (balls_left-=1, drop ≤0); if `formed`, record ball, then for each trigger joker on the matching side push a buff (FORM_BAT/FORM_BOWL on any event; FORM_DOUBLE_BAT only if a prior event within 5 balls back).
- Tests in `test_joker_runtime.gd`: 3-ball decay; side gating; double-trigger timing; empty identity.

## Task 3 — thread `JokerRuntime` into `simulate_innings`
- Build a runtime at top. Per ball: `windowed = runtime.tick_mults(player_is_batting)`; multiply into the stateless `jm` before resolve_ball. After resolve: `formed` = (player on strike & boundary) while batting, or (player_bowling & wicket); `runtime.on_ball_end(jokers, player_is_batting, balls, formed)`.
- Tests in `test_innings_jokers.gd`: Ride the Wave raises Player runs; Wicket Maiden raises opp wickets; determinism.

## Task 4 — catalog: 4 new groups (15 → 19)
- Ride the Wave (#10, FORM_BAT runs 1.20 n=3), Wicket Maiden (#29, FORM_BOWL wicket 1.30 n=6), Hot Streak (#14, two FORM_DOUBLE_BAT rows: runs 1.30 + wicket 0.85 n=6), Match-Winner's Vigil (#7, FORM_BAT wicket 0.80 n=24).
- Tests in `test_joker_catalog.gd`: 19 groups; ids/trigger/window shapes; Hot Streak 2 rows.

## Task 5 — match-level determinism + byte-identical
- Tests in `test_match_jokers.gd`: trigger jokers deterministic; stateless-only list == pre-C2c.

## Task 6 — sweep + viewer
- `tools/sweep_jokers.gd`: new jokers auto-appear; add "Form-window stack" arm. Run headless, refresh viewer `DATA`.

## Close
- Full suite green; commit per group; PR; merge; sync main; roadmap (status, decisions log, deferred-jokers note).
