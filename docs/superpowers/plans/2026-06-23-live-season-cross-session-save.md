# Plan — Slice 4: cross-session save (replay-from-decisions)

Spec: `docs/superpowers/specs/2026-06-23-live-season-cross-session-save-design.md`
Built test-first, all green (734 tests / 10088 asserts).

## Task 1 — `MatchSession` export/apply decisions ✅
- `export_decisions() -> {presses, review_balls, km, bowl_km}` (deep-duplicated).
- `apply_decisions(d)` — set the arrays, `_reviews_used = review_balls.size()`,
  rebuild the two KM plans, one `_resim()`.
- Tests: `test_export_apply_reproduces_a_decided_match`,
  `test_apply_empty_decisions_is_a_noop`, `test_apply_then_export_round_trips_all_four_channels`.

## Task 2 — `SeasonPlay` record + replay ✅
- `commit_player_result(result, decisions := {})` appends to `_decisions`.
- `seed()`, `decisions_log()`, `restore_pay_tally(total, wins)`.
- static `replay(...)` — `start` then `make_session` → `apply_decisions` → `commit` per entry.
- `to_state(level, tour_index)` / static `from_state(state, player, career)`.
- Tests: decisions-log recording, replay-equivalence (final_order + pay), no-decision replay.

## Task 3 — `LiveSeasonState` + `SaveManager` I/O ✅
- `scripts/data/live_season_state.gd` (@export seed/level/tour_index/pay_total/wins/decisions).
- `SaveManager.has/save/load/clear_live_season` for `user://live_season.tres`.
- Tests: serialise round-trip (scalars + nested decisions), trio, full disk resume.

## Task 4 — Wire boot resume + commit save/clear ✅
- `season_hub.boot()` resumes via `SeasonPlay.from_state` when a live save exists.
- `main._commit_and_return` commits WITH `session.export_decisions()`, then saves the
  in-progress season (or clears it on `season_done()`).
- Test: `test_boot_resumes_an_in_progress_live_season` (hub boots mid-season at game 3).
