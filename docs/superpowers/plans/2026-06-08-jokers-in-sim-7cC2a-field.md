# Plan — jokers in sim C2a: field-mode condition + state-gated jokers

Spec: `docs/superpowers/specs/2026-06-08-jokers-in-sim-7cC2a-field-design.md`. Inline test-first (pure domain; mirrors the slice). Judge red by parse-error, green by total count climbing past **219** + `All tests passed`. Run after each task:
`/Applications/Godot.app/Contents/MacOS/Godot --headless --import --path . && /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`
(Quit the Godot editor first — already confirmed not running.)

## Task 1 — `FieldPlan` value object
- Test `tests/unit/test_field_plan.gd`: `for_over` phase boundaries (6→pp, 7→middle, 15→middle, 16→death); `neutral()`/`catching()`/`defensive()` factory contents.
- Impl `scripts/data/field_plan.gd` mirroring `IntentPlan` (enum `Mode { NEUTRAL, CATCHING, DEFENSIVE }`, three per-phase int bands default NEUTRAL, `for_over`, three factories).

## Task 2 — `JokerEffect.field_req` + `matches()` + `JokerResolver` field param
- Extend `tests/unit/test_joker_effect.gd`: field gate (field_req set → fires only on matching field_mode; -1 → ignores field; field+side combined).
- Extend `tests/unit/test_joker_resolver.gd`: field-gated joker contributes only when field_mode matches; default-NEUTRAL inert; old-signature call (no field arg) still identity. Add a **multi-buff** test (two same-id rows → both wicket & runs mults).
- Impl: add `var field_req: int = -1`; `make()` trailing `p_field_req := -1`; `matches()` trailing `field_mode := FieldPlan.Mode.NEUTRAL` + `field_ok` gate; `JokerResolver.roll_mults()` trailing `field_mode := FieldPlan.Mode.NEUTRAL` passed to `matches()`.

## Task 3 — thread `field_plan` through innings + match
- Extend `tests/unit/test_innings_jokers.gd`: null field_plan == today (determinism on same seed); a catching-field bowling wicket-booster (Cordon-Killer shape) raises wickets with `field_plan=catching` vs neutral on the same seed (run with `player_is_batting=false`); determinism with a field_plan.
- Extend `tests/unit/test_match_jokers.gd`: a bowling field joker shifts win-rate vs baseline over N seeds; determinism with field_plan.
- Impl: `simulate_innings` trailing `field_plan: FieldPlan = null` → compute `field_mode` per over → pass to `roll_mults`. `simulate_match`/`simulate_match_teams` trailing `field_plan: FieldPlan = null` → route to the `player_is_batting=false` (opposition batting) innings calls in both toss branches; null to the Player's batting innings.

## Task 4 — `JokerCatalog` implemented pool + 6 new jokers
- Extend `tests/unit/test_joker_catalog.gd`: `implemented_groups()` size 11; a multi-buff group (carry_your_bat / dot_ball_pressure) has 2 effects; spot-check a field joker's `field_req` (cordon_killer = CATCHING) + a stateless leftover (rotate_the_strike); `implemented()` flat size 13.
- Impl: add `implemented_groups()` (all 11 as `{id,jname,rarity,effects}`) + `implemented()` flat helper; author #4/#6/#12/#16/#20/#23 (magnitudes verbatim from `docs/joker-pool-v1.md`). Keep `slice_v1()` unchanged.

## Task 5 — sweep tool + viewer (eyeball)
- Rewrite `tools/sweep_jokers.gd` to iterate `implemented_groups()` (one arm per group) + baseline + batting-stack + field-defensive-stack; add a shared `FieldPlan` (CATCHING pp/death, DEFENSIVE middle) passed to `simulate_match_teams`. Run it, capture JSON.
- Refresh `docs/mockups/distribution-viewer-v1.html` `DATA` with the output. Eyeball the win-rate column.

## Wrap
- Commit per task is overkill for inline pure-domain; commit Tasks 1–4 together once green, Task 5 (tool+viewer) after. Branch `jokers-c2a-field`. PR → merge → sync main → delete branch. Update `PROJECT_ROADMAP.md` (status, handoff, decisions log: C2 split + C2a done; next = C2b). Note any new gotcha in `CLAUDE.md` if one surfaces.
