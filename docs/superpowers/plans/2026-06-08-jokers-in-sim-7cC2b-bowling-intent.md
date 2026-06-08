# Plan — Jokers in the sim · C2b bowling-side intent

Spec: `docs/superpowers/specs/2026-06-08-jokers-in-sim-7cC2b-bowling-intent-design.md`. Test-first, inline (small pure-domain tasks). Judge **red** by parse-error, **green** by total count climbing past **240**. Branch `jokers-c2b-bowling-intent`.

## Task 1 — `JokerEffect`: `bowl_intent_req` + `sets_field` + `matches(..., bowl_intent)`
- Add `var bowl_intent_req: int = -1` and `var sets_field: int = -1`.
- Extend `make()` with trailing `p_bowl_intent_req := -1, p_sets_field := -1`.
- Extend `matches(...)` with trailing `bowl_intent := -1`; add `bowl_intent_ok := bowl_intent_req == -1 or bowl_intent == bowl_intent_req`.
- Tests in `test_joker_effect.gd`: bowl_intent gate on/off/any; sets_field stored; old 4-arg matches still works.

## Task 2 — `JokerResolver.roll_mults(..., bowl_intent)` + sets_field pre-pass
- Add trailing `bowl_intent := -1`.
- Pre-pass: `var eff_field := field_mode`; for each `j` with `j.sets_field != -1` that matches → `eff_field = j.sets_field`.
- Multiplier loop uses `eff_field`; `continue` on `sets_field` jokers (mult is 1.0, skip for clarity).
- Tests in `test_joker_resolver.gd`: bowl_intent-gated contributes only on match; sets_field upgrades eff_field so a field-gated joker fires (combo); sets_field joker adds no multiplier.

## Task 3 — Catalog: 4 new groups (11 → 15)
- Add to `implemented_groups()`: Attack the Stumps (#26), Pressure Cooker (#19), Choke Hold (#22, two rows), Defensive Captain (#18, `sets_field = DEFENSIVE`, mult 1.0).
- Tests in `test_joker_catalog.gd`: 15 groups; ids present; Choke Hold 2 rows; Defensive Captain sets_field.

## Task 4 — Thread `bowl_intent_plan` through `simulate_innings`
- Add `bowl_intent_plan: IntentPlan = null` (after `field_plan`). Per over: `bowl_intent = bowl_intent_plan.for_over(over) if set else -1`. Pass to `roll_mults`.
- Tests in `test_innings_jokers.gd`: #26 fires under Aggressive bowl_intent in the opposition innings (more wickets); determinism with plan set.

## Task 5 — Thread through `simulate_match` / `simulate_match_teams`
- Add `player_bowl_intent_plan: IntentPlan = null, opp_intent_plan: IntentPlan = null`.
- Opposition batting innings: `intent_plan = opp_intent_plan`, `bowl_intent_plan = player_bowl_intent_plan`. Player innings unchanged.
- Tests in `test_match_jokers.gd`: null params → byte-identical baseline; #19 directional under Defensive opp_intent_plan; determinism.

## Task 6 — Sweep + viewer refresh
- `tools/sweep_jokers.gd`: add shared `_bowl_intent_plan()` + `_opp_intent_plan()` (constant across arms), pass to `simulate_match_teams`; add "Bowling-intent stack" arm. Run headless, capture JSON, refresh `docs/mockups/distribution-viewer-v1.html` `DATA`.

## Close
- Full suite green (`--import` once, then GUT). Commit per logical group, push, PR, merge, sync main, delete branch. Update `PROJECT_ROADMAP.md` (status, Next session, decisions log).
