# Slice 4 — Cross-session save for the live season loop

**Date:** 2026-06-23 · **Rung:** live-season-loop, final slice (Slice 4) · **Mode:** AFK
**Parent spec:** `docs/superpowers/specs/2026-06-22-live-season-loop-finish-design.md` (§Slice 4)

## Plain-English goal

Right now you can play a whole live season — league → playoffs → ₸ pay → outcome —
but if you **quit mid-season, it's gone**: the next launch boots a fresh season from
the constant `BOOT_SEED`. This slice makes an in-progress live season **survive app
restarts**: quit after match 3, relaunch, and you're back on match 4 with the same
table, the same banked ₸, the same everything.

## Why "replay-from-decisions", not "save the results"

A match's `MatchResult` / `InningsResult` are `RefCounted` with **no `@export`** → Godot
can't serialise them. We could add `@export` everywhere, but that's a large, fragile
data contract to freeze (every ball-log entry, every sub-result).

We don't have to. **The sim is deterministic** (the prefix-stable contract `MatchSession`
already relies on): the same seed + the same player decisions ⇒ **byte-identical**
results. So we persist only the *tiny* interactive **decisions** the player made
(boost presses, DRS reviews, key-moment calls) plus the season's seed + cell context.
On resume we rebuild the `SeasonPlay` from the (separately-persisted) `Player` +
`CareerState` and **replay** each fixture's decisions, reconstructing identical state.

Lossless, and the only new serialised data is a handful of `[int,int]` pairs per match.

## The five pieces

### 1. `MatchSession` — export / apply the decisions it already holds

`MatchSession` already accumulates everything a replay needs (`_presses`,
`_review_balls`, `_km_plan.overrides`, `_bowl_km_plan.overrides`). Add:

- `export_decisions() -> Dictionary` → `{ "presses": …, "review_balls": …, "km": …, "bowl_km": … }`
  (deep-duplicated plain arrays of ints/dicts — safe to serialise & re-apply).
- `apply_decisions(d: Dictionary) -> void` → set `_presses`, `_review_balls`,
  `_reviews_used = _review_balls.size()`, rebuild the two override arrays, **one `_resim()`**.

Contract: `start(same seed)` + `apply_decisions(export_decisions())` ⇒ identical `result()`.

### 2. `SeasonPlay` — record decisions, replay, expose state

- `commit_player_result(result, decisions := {})` — append `decisions` to a new
  `_decisions: Array` (one entry per committed player match, league **and** playoff).
  The default `{}` keeps every existing caller/test byte-identical.
- `seed() -> int`, `decisions_log() -> Array` — accessors.
- `restore_pay_tally(total, wins)` — set `_pay_total` / `_wins` after a replay
  (replay runs with pay **off**, see "Pay" below).
- `to_state(level, tour_index) -> LiveSeasonState` — pack seed + decisions + cell +
  pay tally into the serialisable resource.
- static `from_state(state, player, career) -> SeasonPlay` — rebuild the cell
  (`DifficultyLadder.spec_for`), `start(...)` on `state.seed`, replay every saved
  decision entry, then `restore_pay_tally`. Returns the driver at the **same phase /
  progress** as when it was saved.

### 3. `LiveSeasonState` (`scripts/data/live_season_state.gd`) — the save payload

`extends Resource`, all `@export`: `version` (=1), `seed`, `level`, `tour_index`,
`decisions: Array` (of the per-match dicts), `pay_total`, `wins`. Small, flat, all
ints / arrays-of-ints — serialises cleanly to `.tres`.

### 4. `SaveManager` — I/O for `user://live_season.tres`

Mirror the existing player/career trio: `has_live_season()`, `save_live_season(s)`,
`load_live_season()` (CACHE_MODE_IGNORE fresh read), `clear_live_season()`.

### 5. Wiring (minimal, mechanical)

- `season_hub.boot()` — if a live-season save exists, resume from it
  (`SeasonPlay.from_state`) instead of starting fresh.
- `main._commit_and_return` — pass the session's decisions into `commit_player_result`,
  then **save** the live season if it's still going, or **clear** it once
  `season_done()` (a finished season must not resume).

## Pay: avoiding the double-bank (the one subtlety)

The Player's lifetime ₸ (`Player.tons_balance`) is **persisted on the Player resource**
already (`main` saves the player after every match). The replay must NOT re-bank it.
It doesn't: `SeasonPlay.replay` never calls `enable_pay`, so `_settle`'s `_etun == null`
guard short-circuits — zero banking, `_pay_total`/`_wins` stay 0. We then set them from
the *saved* values via `restore_pay_tally`. After resume, the hub's `set_play` re-binds
`enable_pay` for **future** matches, which add on top of the already-correct persisted
balance. No double count, season tally intact for the outcome screen.

## Determinism notes (why replay is exact)

- AI fixtures + held strengths are pure functions of `_seed` (`_seed` / `_seed+1`) —
  rebuilt identically by `start()`.
- Per-fixture match seeds are derived (`_seed+100+i` league, `_seed+200+offset` playoff)
  — same on replay.
- Playoff stage progression depends only on prior results, which are identical on
  replay, so the per-match seeds and the `_decisions` alignment hold.
- Out-of-top-4 ⇒ the 7th league commit auto-finishes the bracket; replay's 7th commit
  does the same. A finished season is cleared, never resumed.

## Scope / out of scope

- **In:** the five pieces above + the minimal boot/commit wiring. Cross-session save
  actually functions end to end.
- **Out (unchanged, deferred):** career advancement on Continue (live path still doesn't
  mutate `CareerState` — open item c); hi-fi outcome; any sim/tuning/ledger file (this is
  scheduling + persistence, **zero cricket touched**).

## Tests (headless)

1. **`MatchSession` round-trip** — make boost + DRS + KM (+ bowling-KM) decisions on a
   session; `export` → fresh same-seed session → `apply` ⇒ identical `result()` (outcome,
   both innings totals, player batting line) and identical `events().size()`.
2. **`apply_decisions` on empty `{}`** is a no-op (byte-identical to a bare session).
3. **`SeasonPlay` replay-equivalence (integration)** — build a real cell (`start_career(0)`
   + `DifficultyLadder.spec_for`), drive a full season with varied per-match decisions,
   `to_state` → `SaveManager` save → load → `from_state` ⇒ identical `season_result().final_order`,
   `pay_so_far()`, `season_wins()`.
4. **`LiveSeasonState` survives serialisation** — a save→load preserves nested `decisions`
   (presses/review/km entries) and the scalar fields.
5. **`SaveManager` trio** — `has` false initially; `save` → `has` true; `load` returns the
   fields; `clear` → `has` false.
6. **Regression** — existing `SeasonPlay` / `MatchSession` / `SaveManager` suites unchanged.

## Decisions log (AFK defaults)

- **SL1** Replay-from-decisions over `@export`-ing results — smaller contract, lossless,
  leans on the determinism we already depend on. (Supersedes the parent spec's
  "serialise committed results" sketch, which assumed serialisable results.)
- **SL2** `LiveSeasonState` stores `level`/`tour_index` explicitly (derivable from
  `CareerState` today, but pins the cell so the save is self-describing and robust to the
  seed/cell-selection logic changing later).
- **SL3** Player + CareerState are **not** duplicated into `LiveSeasonState` — they have
  their own save files; `from_state` takes them as args. Keeps one source of truth each.
- **SL4** Replay runs pay-off + `restore_pay_tally`, rather than re-banking, to avoid
  double-counting the already-persisted `Player.tons_balance` (see Pay).
- **SL5** A finished season clears its save on `season_done()` — never resume a season
  that's already at the outcome screen.
