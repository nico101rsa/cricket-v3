# Live League Loop — Design

**Date:** 2026-06-16 · **Theme:** 2 (Presentation) · **Rung:** FOURTH presentation rung
**Status:** spec → plan → build (AFK)
**Prior rungs:** Season Hub scrub-replay (PR #64/65) · Match screen watch-only (PR #66) · Interactive Match Boost+DRS (PR #67) · interactive polish (PR #68–70)

---

## 1. What this is (plain English)

The first three presentation rungs each made *one* screen. This rung joins them into a **playable loop**: from the Season Hub you see a **running** league table, tap your **next** fixture, **play it interactively** (Boost + DRS, the PR #67 screen), and your result **counts** — the table and your stat card update, and you advance to your next fixture. You play your way through the whole 7-match league phase.

Today the hub *pre-simulates the entire season at once* and lets you scrub a finished result (the table is honestly labelled "FINAL" because there is no real mid-season ladder). This rung makes the season play **forward**, so a genuine running ladder exists.

## 2. Decisions (locked)

- **D1 — A separate presentation driver, not a change to the resolvers.** A new `SeasonPlay` (`scripts/domain/`) drives the league stepwise. `LeagueResolver`/`SeasonResolver` stay **byte-identical** — the balance harness (`simulate_season`) is never touched, so **zero ledger risk by construction**.
  - *Why:* the player's interactive Boost/DRS changes results the pre-simmed season's single RNG stream assumed; you cannot splice an interactive match into that stream. The live season is a different object from the balance season.
- **D2 — Scope = live LEAGUE phase only.** Play your 7 league fixtures interactively + a running table, ending at the **final league table + your league finish**. Playoffs, outcome (beat/won_final), ₸ pay, shop visits, and cross-session save/resume are a **named follow-up rung** (§9). (Nico's ruling, 2026-06-16.)
- **D3 — One sim entry for the whole live league: `simulate_match_teams`.** AI fixtures auto-resolve via `MatchResolver.simulate_match_teams` (derived path, `player_attrs = null`); your fixture is the same entry, driven interactively through `MatchSession`. This keeps the live league internally consistent and is the **ledger-faithful roster path** (CF1: real XIs + conserved bowling). Consequence: the live league draws each team's strength **per fixture** (not held-all-season like ADR 0009's balance path) — acceptable and slightly more dynamic for a presentation league; recorded, not a bug.
- **D4 — Difficulty by strength this rung; opponent *brain* deferred.** The cell's card-gap difficulty IS applied (via `spec.make_tour()`, the same tour the hub boots with). The opponent *tactics* brain (`OpponentBrain` intent/bowling plans) is **not** threaded into the live match this rung — `MatchSession` does not yet accept it. The live league is therefore at the right strength but naive opponent tactics; brain-threading is a small follow-up (§9). Does not affect build-equality (brain affects win-vs-AI, not build symmetry).
- **D5 — The running table is a genuine mid-season ladder.** `SeasonPlay` grows a `LeagueResult` (standings + your match record) as fixtures commit. This supersedes the "FINAL only" honesty caveat — we now have a real running table to show, labelled by progress ("after N of 7").
- **D6 — Forward-play hub, replay preserved.** The scrub-the-pre-simmed-season hub is replaced (on the live path) by a forward-play hub. Completed fixtures still tap → the watch-only replay (PR #66) unchanged; your **next** fixture is a PLAY button → interactive scene (PR #67). Future fixtures show as "to play" (no fabricated scrub of unplayed matches).
- **D7 — In-memory progress this rung.** `SeasonPlay` lives for the session; closing the app loses mid-season progress. Cross-session save/resume is deferred with playoffs (§9). The driver is built so persistence can serialise its state later without redesign (held strengths + committed results + cursor).

## 3. Architecture

```
main.gd (router)
  └─ Season Hub (forward-play)
       ├─ renders SeasonPlay.live_league()  → running standings + your record + folded card
       ├─ "PLAY v <opp>"  → main pushes Interactive Match (PR #67) with SeasonPlay.make_session()
       │                      back → SeasonPlay.commit_player_result(session.result()); re-render
       └─ tap a PLAYED fixture → watch-only Match screen (PR #66), unchanged

SeasonPlay (NEW, scripts/domain/) — pure stepwise driver, deterministic from a seed
  start(player_attrs, player_team, opponents, tour, tuning, itun, seed)
    draws nothing yet; schedules fixtures in PLAYER-FIXTURE order (your 7 games, AI games between)
  next_player_opponent()  → { name, team_index } or {} when the league is done
  make_session()          → MatchSession for the current player fixture (held seed slice)
  commit_player_result(MatchResult)  → fold into the growing LeagueResult; auto-resolve the AI
                                       fixtures up to your next game; advance the cursor
  live_league()           → LeagueResult (standings sorted, player_matches so far)
  played_count() / total_player_fixtures() (= 7)
  league_done()           → bool
```

`SeasonPlay` owns: the team list (`[player_team] + opponents`), a master `RandomNumberGenerator` (seeded), the per-fixture schedule, the growing `StandingsRow[]`, the committed `player_matches: Array[MatchResult]`, and a cursor. It does **not** touch the scene tree, `SaveManager`, or any tuning literal.

## 4. The schedule (fixture ordering)

`LeagueResolver.round_robin(8)` yields 28 `(i,j)` pairs, `i<j`, so the Player (index 0) is always `i` in their 7 fixtures (`(0,1)…(0,7)`). The live driver plays in this order:

1. Auto-resolve the AI-only fixtures that fall *before* your next player fixture in the round-robin order (there are none before `(0,1)`; the 21 AI fixtures `(i,j)` with `i≥1` are interleaved after your games for table purposes — order chosen so each "step" = play your game, then the AI games settle).
2. Pause at the player fixture; expose it via `make_session()`.
3. On `commit_player_result`, fold your result + auto-resolve a batch of AI fixtures, advance.

**Implementation note (resolved in plan):** the simplest correct schedule is — on each `commit`, after folding your match, auto-resolve **all** AI fixtures whose turn it is so the table is always complete-to-date through the games that "would have happened." For a 7-step league this is fine to resolve all 21 AI games up front at `start` (they don't depend on your results) and only interleave the table *display* by how many of your games you've played. **Decision DS1 (plan-time):** resolve the 21 AI fixtures once at `start` (deterministic, independent of you); reveal your 7 one at a time. This keeps the AI table stable and the running ladder = (fixed AI results) + (your games so far).

## 5. Determinism

`SeasonPlay` is deterministic given its start seed: AI fixtures use the master RNG in a fixed order; each player fixture's `MatchSession` uses a derived fixed seed (`base_seed + fixture_index`) so your decisions only diverge *that* match. Re-committing the same result yields the same table. Unit-tested.

## 6. Components touched / created

- **NEW** `scripts/domain/season_play.gd` (`SeasonPlay`) — the driver.
- **NEW** `tests/unit/test_season_play.gd` — schedule, running standings, determinism, league_done, fold-your-result.
- **CHANGED** `scenes/season_hub/season_hub.gd` — forward-play render path: running table + PLAY button for the next fixture + played-fixture replay; reuse the card-fold from the growing `player_matches`. `boot()` constructs a `SeasonPlay` (mirrors the current real-season boot). Keep the existing injected-view path for tests.
- **CHANGED** `scenes/main.gd` — `_push_match` already opens watch-only replay; add `_play_next(opp)` (or reuse a signal) that pushes the Interactive Match scene with `SeasonPlay.make_session()` and, on `back`, commits the result + returns to the hub.
- **REUSED, untouched** `scenes/interactive_match/*` (PR #67), `scenes/match_view/*` (PR #66), `MatchSession`, `MatchViewBuilder`, `SeasonViewBuilder` (card fold), `LeagueResolver.round_robin`/`build_rosters`, `MatchResolver.simulate_match_teams`.

## 7. Testing (TDD)

Pure-logic first (`SeasonPlay`), then scene wiring (inject, no sim):
1. `start` schedules 7 player fixtures; `total_player_fixtures()==7`, `played_count()==0`, `league_done()==false`.
2. `next_player_opponent()` returns a real opponent name/index; `{}` after the 7th commit.
3. `commit_player_result` grows `player_matches` by 1 and `played_count()` by 1.
4. Running standings: after committing a PLAYER_WIN, your row has +2 points; the table is sorted (points→NRR→index) and totals 8 rows.
5. Determinism: two `SeasonPlay`s with the same seed + same committed results → identical `live_league()` standings.
6. `league_done()` true after 7 commits.
7. Scene: inject a `SeasonPlay` into the hub, assert the running table renders 8 rows, the next-fixture PLAY control is visible+enabled, a played fixture row is tappable. (Eyeball the real window — unit tests can't catch invisibility per CLAUDE.md.)

Judge red by the parse-error on the not-yet-declared `SeasonPlay`; green by the total count climbing + `All tests passed`. Run the whole suite each step (`-gdir=res://tests/unit`).

## 8. Deliverable (Nico-facing)

- A **screenshot** `docs/mockups/live-league-loop-built-v1.png` — the forward-play hub mid-league (e.g. after 3 of 7: running table with your real W/L record, next fixture PLAY button, folded card).
- A short **plain-English wrap-up**: the loop now plays forward; here is the one screenshot to look at.
- `tools/preview_live_league.gd` — a visual harness that boots a `SeasonPlay`, plays a couple of fixtures, screenshots the hub (mirrors `tools/preview_season_hub.gd`).

## 9. Explicitly deferred (named follow-up rungs, not this one)

- **Live playoffs + outcome + ₸ pay** — knockouts interactive/auto, beat/won_final, match pay banked. (The next presentation rung.)
- **Cross-session save/resume** — persist `SeasonPlay` state so a half-played league survives an app close. (`SeasonPlay` is built serialisable-ready.)
- **Opponent brain in the live match** — thread `OpponentBrain` plans through `MatchSession` so live opponents play the cell's tactics, not just its strength.
- **Shop visits in the live loop** — the Kit Room cadence (V1/V2 after matches 3/5) currently lives only in the headless balance path.
- **Hi-fi presentation** — portraits, gradient art, around-the-match parity (its own hi-fi rung).

## 9a. Open defaults (chosen, recorded — not blocking)

- **DS1** (see §4): resolve the 21 AI fixtures once at `start`; reveal your 7 one at a time.
- **Boot seed:** reuse the hub's `BOOT_SEED = 20260615` for a stable demo.
- **Next-fixture control:** a single PLAY button on the next unplayed fixture row (not a separate panel) — minimal, mirrors the existing tappable rows.

## 10. Findings (build) — filled in at build time

(to be completed during/after the build: schedule sanity, a sample running-table trace, test count delta, screenshot path, any gotchas)
