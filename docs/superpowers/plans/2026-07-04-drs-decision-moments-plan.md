# DRS Decision Moments — implementation plan

Spec: `docs/superpowers/specs/2026-07-04-drs-decision-moments-design.md` (DT1–DT12).
Branch `playtest-t8-drs-moments`. TDD throughout (red via parse error / failing assert → green by count climbing). Full suite each step.

## Task 1 — `DRSMoments` pure helper (DT1/DT2/DT3)
- RED: `tests/unit/test_drs_moments.gd` — determinism, flavour weights over N=6000 (±2pp), reviewable set, p range/mean, gate table.
- GREEN: `scripts/domain/drs_moments.gd` — hash-based `flavour_of`/`moment_p`/`is_reviewable`/`is_moment` + consts.

## Task 2 — resolver survive channel (DT4 auto policy / DT5 / DT6)
- RED: update `test_drs_review_balls_seam.gd` to the new contract (override seam; qualifying vs non-qualifying wickets); adapt `test_fair_fight_baseline.gd`; `DRSPolicy.moment_p_override` default test in `test_drs_policy.gd`.
- GREEN: `DRSPolicy.moment_p_override`; `InningsResolver` survive block gates on `DRSMoments.is_moment` + `AI_BURN_P` (auto) and rolls moment p (both modes). Claim channel untouched.

## Task 3 — MatchSession moments + live symmetry (DT4/DT7)
- RED: `test_match_session.gd` — offer at moment cursor carries `p_shown`/`flavour`/batter fields; non-moment hero dismissal gives no offer; prefix byte-identity keeps; opp DRS policy present in live re-sim (observable: results differ from a null-opp-DRS control at same seed).
- GREEN: `_compute_drs_moments()`, `review_offer` rewrite, opp `DRSPolicy` in `_resim`.

## Task 4 — the card (DT8)
- RED: scene test — card text contains the shown % and flavour.
- GREEN: `_build_drs_body()` consumes the enriched offer. Render proof via `tools/preview_key_moment.gd`-style harness (reuse/extend the DRS state in `tools/preview_interactive_match.gd`).

## Task 5 — balance gate + docs (DT10)
- Run `tools/sweep_form_balance.gd`; compare to v3 reference; fill spec §6 Results.
- PLAYTEST-NOTES T8 ✅; roadmap Next-session block; PR + merge.
