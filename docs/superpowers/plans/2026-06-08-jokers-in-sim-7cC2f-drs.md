# Plan — Jokers in the sim · C2f DRS

Spec: `…7cC2f-drs-design.md`. Test-first. Green past **301**. Branch `jokers-c2f-drs`.

## Task 1 — `DRSPolicy` (new `scripts/data/drs_policy.gd`)
- `base_reviews := 1`, `base_p := 0.4`. Test `test_drs_policy.gd`: defaults.

## Task 2 — `JokerEffect`: DRSRole
- `enum DRSRole { NONE, ACCURACY, EXTRA_REVIEW, RETAIN, FORM_ON_SUCCESS, BOWLING_BUFF, MASTER }`, `var drs_role := NONE`, `var drs_p_bonus := 0.0`; `make()` trailing params; `matches()` returns false if `drs_role != NONE`.
- Test: drs joker never matches per-ball.

## Task 3 — `JokerRuntime`: reviews + try_review
- `var reviews_left := 0`. `init_reviews(jokers, base_reviews)` (+1 per EXTRA_REVIEW/MASTER).
- `try_review(jokers, player_is_batting, intent, base_p, ball, rng) -> bool`: sum ACCURACY (intent_req-gated) + MASTER p; clamp; one randf; success → fire Form (FORM_ON_SUCCESS/MASTER) + #44 bowling buff, retain; fail → consume unless RETAIN/MASTER.
- Tests: init grants; consume/retain; accuracy raises success (seeded loop); bowling buff on success.

## Task 4 — thread `drs_policy` into `simulate_innings` + `simulate_match(_teams)`
- simulate_innings trailing `drs_policy: DRSPolicy = null`; init_reviews at start; after resolve_ball, DRS block mutates `o` on overturn (batting dismissal → survive; bowling dot → claim).
- simulate_match/_teams trailing `drs_policy` to both innings.
- Tests: DRS lowers Player dismissals; determinism; no-policy byte-identical.

## Task 5 — catalog (31 → 39): #38–#45 with drs_role. Tests: 39 groups, roles.

## Task 6 — sweep + viewer: shared DRSPolicy; Reviewer stack arm; refresh.

## Close: suite green; commit; PR; merge; sync; roadmap.
