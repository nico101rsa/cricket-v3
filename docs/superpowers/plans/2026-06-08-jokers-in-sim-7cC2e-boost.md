# Plan — Jokers in the sim · C2e Manager Boost

Spec: `…7cC2e-boost-design.md`. Test-first. Green past **286**. Branch `jokers-c2e-boost`.

## Task 1 — `BoostPlan` (new `scripts/data/boost_plan.gd`)
- `press_overs: Array[int]`, `base_mult := 1.15`, `base_n := 6`; `presses_on(over) -> bool`; `static at(overs) -> BoostPlan`.
- Tests `test_boost_plan.gd`: presses_on; at() factory.

## Task 2 — `JokerEffect`: BoostRole
- `enum BoostRole { NONE, EXTEND, BATTERY, ADRENALINE, PEDAL, AMPLIFY, COMPOUND, COMEBACK }`, `var boost_role := NONE`; `make()` trailing `p_boost_role := NONE`; `matches()` returns false if `boost_role != NONE`.
- Test: boost_role joker never matches per-ball.

## Task 3 — `JokerRuntime.on_boost_press`
- `var boost_press_count := 0`. Extract `_push_form_buffs(jokers, player_is_batting, ball)` from on_ball_end's form push; reuse it.
- `on_boost_press(jokers, player_is_batting, intent, base_mult, base_n, ball)`: eff_intent (PEDAL→AGGRESSIVE); apply EXTEND(+2)/AMPLIFY(×1.2,+3)/COMEBACK(3rd: ×1.5,+6) to mult/n; push side-aware base buff; BATTERY kicker; COMPOUND extra (if Aggressive); ADRENALINE/COMEBACK → _push_form_buffs.
- Tests: base buff; each role; compound gated on Aggressive/Pedal; adrenaline chains form.

## Task 4 — thread `boost_plan` into `simulate_innings` + `simulate_match(_teams)`
- simulate_innings: trailing `boost_plan: BoostPlan = null`; at over-start press, call on_boost_press before tick_mults.
- simulate_match/_teams: trailing `boost_plan` to BOTH innings.
- Tests: BoostPlan raises Player runs; determinism.

## Task 5 — catalog (24 → 31): #31–#37 with boost_role. Tests: 31 groups, roles.

## Task 6 — sweep + viewer: shared BoostPlan (powerplay+death presses); Boost-stack arm; refresh.

## Close: suite green; commit; PR; merge; sync; roadmap.
