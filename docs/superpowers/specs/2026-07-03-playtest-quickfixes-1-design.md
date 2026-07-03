# Playtest quick-fix batch 1 (T12, T2-T5) — Design (2026-07-03)

Design authority: docs/PLAYTEST-NOTES.md triage (Nico's first 2 games). Five surgical
fixes, one rung, inline (tiny-slice batching per CLAUDE.md).

- **T12 (bug, found via T1): save the live season atomically at commit.** Today
  `main._commit_and_return` saves the Player then shows the Result screen; the season
  file only writes in `_after_result` (Continue press). Quit on the Result screen =
  the finished match is lost AND player/season files desync (proven: Nico's match 2
  vanished; his player kept match-2 pay). Fix: `save_live_season` right after
  `save_player` in `_commit_and_return` (skip when `season_done()` — the season-end
  path owns clearing/saving). The `_after_result` save stays (idempotent).
- **T2: star glyphs shared + correct.** `pre_match._stars()` rounds (1.5 -> "★★ · 1.5");
  hub's `_stars_str` is right ("★½"). New `Display.stars_str(stars)` (domain, tested);
  both scenes delegate.
- **T3: no internal shorthand on the KM card.** `interactive_match.gd` actor stats line
  "econ 6.8 · OVR 30" read as "over 30" (Nico, screenshot 19.03.19). "OVR %d" -> "skill %d"
  in both variants.
- **T4: TAP TO START starts the match playing.** `main._start_match` boots the match
  paused (a second ▶▶ press was needed). After `boot()`, call `play()`. `boot()` itself
  unchanged (test semantics preserved).
- **T5: batter chips keep batting-order positions; strike shown by highlight only.**
  `MatchViewBuilder` chips gain a `position` key and order by it (the old code reversed
  to striker-first, so rows flipped every rotation). The chip highlight (`on_strike` ->
  gold panel/name/★) already exists — unchanged.

Verdicts recorded in PLAYTEST-NOTES triage: T1 benchmark says the 41/9 collapse is a
~5% tail of the deliberately-wild Club-Practise env (N=300 same-fixture, opp mean
105.2/7.4, P(wkts>=9)=49.7%) — no sim change.
