# Play → Match Screen (watch-only, player-centric) — Design

**Date:** 2026-06-15
**Status:** Approved (brainstorm), pre-plan
**Theme:** 2 (playable career) — presentation track, second rung after the Season Hub.
**Companion artefacts:** visual target `docs/mockups/match-screen-final.html`; reference feeds `docs/mockups/one-match-v1.md`, `in-match-hi-fi-v1.html`, `playable-prototype.html`.

---

## 1. What this is (plain English)

The Season Hub lets you scrub a finished season fixture-by-fixture. This rung makes a **single match watchable**: tap a played (WON/LOST) fixture in the Season Hub and a **Match screen** plays that match back **ball-by-ball**, player-centric — every ball of *your* batting innings and *your* bowling overs shown live, the rest collapsed to quick over-summaries. Autoplay + pause + speed + manual step, exactly like the hub's scrubber.

It is **watch-only**: the match is already simulated; you watch a faithful replay. You *see* the Boost/DRS moments happen but don't press them. Making those decisions interactive (pausing the sim to ask the UI) is a **deliberately deferred next rung** — see §9.

This rung stays **low-fi** (flat text panels, same fidelity as the Season Hub today). Hi-fi/art parity and the cosmetic cleanups (incl. the bare standings table Nico flagged) live in the separate Option-3 polish rung.

---

## 2. Decisions (locked in brainstorm)

- **DM1 — Watch-only.** No interactive Boost/DRS this rung; the replay shows what the sim already decided. Interactivity is the next rung (§9).
- **DM2 — Player-centric content.** Individual ball events only for deliveries the Player is involved in (batting, or bowling one of their overs). All other deliveries collapse to a per-over summary event. Keeps the spotlight on the Player and the runtime near the ~2:45 match-feel target rather than 240 individual balls.
- **DM3 — Entry = tap a played fixture in the Season Hub.** A WON/LOST fixture row opens that match. (Un-played fixtures keep their current scrub behaviour or are inert — see DM9.)
- **DM4 — Capture during the sim, opt-in.** A match cannot be cleanly re-simulated in isolation (the season threads one shared RNG through all matches), so ball-logs are captured **as the season runs**, behind an opt-in `capture` flag. Default off → zero overhead, oracles/balance runs untouched.
- **DM5 — Mirror the Season Hub architecture.** Pure read-model + pure builder + a scene that never calls a resolver. Same contract shape as `SeasonView` / `SeasonViewBuilder` / `season_hub`.
- **DM6 — Low-fi this rung.** Functional flat-text panels; hi-fi/art deferred. Do not blur the polish rung into this one.

---

## 3. Architecture

Three layers, mirroring the Season Hub:

```
MatchResult (+ captured ball-logs)   ──►  MatchViewBuilder.build(match, player, cursor)  ──►  MatchView  ──►  match_view scene
        (data, from the sim)                       (pure domain fold)                        (read-model)     (renders + plays back)
```

- **`scripts/data/match_view.gd` (`MatchView`)** — a plain read-model holding everything the screen draws at the current cursor: header (team names, innings label, both running scores), the playback **event list** (or the slice up to the cursor), current batter/bowler line, the live "this ball" text, and flags (boost pressed, wicket). Pure data, no logic.
- **`scripts/domain/match_view_builder.gd` (`MatchViewBuilder`)** — pure, static. `build(match: MatchResult, player: Player, cursor: int) -> MatchView`. Internally:
  1. `build_events(match, player) -> Array` — transforms the two raw ball-logs into one ordered **playback event list** (the player-centric stream, §4).
  2. Folds that list up to `cursor` into the current `MatchView` (running scores, recent feed, current striker/bowler).
  No RNG, no sim calls — same purity contract as `SeasonViewBuilder`.
- **`scenes/match_view/match_view.{gd,tscn}`** — `set_match(match, player)` / `boot()` / `play()` / `pause()` / `step(delta)` / `set_speed(mult)` / `cursor()`. Autoplay via a `Timer`; each tick advances the cursor and re-renders. Explicit `boot()` (not auto in `_ready`) so tests inject without a sim, matching the hub.

---

## 4. The player-centric event stream (the heart of the builder)

Input: `match.ball_log_innings1` and `match.ball_log_innings2` (captured arrays; each entry has the keys the sim already records — `over, ball_in_over, striker_pos, is_player, player_batting, player_bowling, intent, boost_pressed, wicket, runs, total, wickets`).

`build_events` walks both innings in order and emits an ordered list of typed events:

- **`ball`** — emitted for every delivery where `is_player` (Player batting that ball) **or** `player_bowling` (Player bowling that over). Carries: over.ball, runs, wicket, intent, boost_pressed, and whether it's the Player batting vs bowling. This is the "live" delivery the viewer watches.
- **`over_summary`** — for a contiguous run of *non-player* deliveries, collapse per over into one event: `{over, runs_in_over, wkts_in_over, end_total, end_wickets}`. (A boundary case: an over that mixes player/non-player balls — e.g. the Player gets out mid-over — emits the player balls individually and summarises the remainder; simplest rule: summarise per over over the *non-player* balls only, player balls always individual.)
- **`innings_break`** — one event between innings 1 and 2 (carries the 1st-innings final + the target).
- **`result`** — terminal event carrying `match.margin_text()` and who won.

The scene steps a `cursor` (0..events.size()) through this list. `MatchView` at a cursor reflects cumulative state after applying events `[0, cursor)`.

**Event count sanity:** a Player batting ~No.4–6 faces maybe 20–40 balls, bowling 0–4 overs (0–24 balls); the rest of ~240 deliveries collapse to ~30–35 over-summaries. So the playback list is on the order of ~60–100 events — watchable on autoplay with a speed control.

---

## 5. Panels (low-fi)

Single screen, top-to-bottom (flat `Label`s in `VBox`/`HBox`, accent colour by country as the hub does):

1. **Header** — your team v opponent, level/tour context, the match result chip (revealed at the end / shown muted).
2. **Scoreboard** — current innings label ("Your innings" / "Bowling — chasing 166"), running `score/wkts (overs)` for the batting side, target if 2nd innings.
3. **Current line** — striker (you, highlighted, with your live runs/balls) or, when bowling, your figures so far this spell.
4. **Ball feed** — the last ~6 events rendered as text lines (e.g. `12.3  •  BOOST  4 runs`, `Over 9: 6 runs`, `WICKET! 41/3`). The newest at the bottom.
5. **Controls** — `‹ Step` · `Play/Pause` · speed toggle (e.g. 1×/2×/4×) · `Step ›` · a `Back to season` button.

Mirror the hub's `ScrollContainer` lesson: any scrolling panel gets an explicit `custom_minimum_size` height, and scene tests assert `size.y > 0` + `is_visible_in_tree()`.

---

## 6. Capture seam (opt-in ball-logs)

`simulate_innings` already takes a `ball_log` param (default `null` → off, zero overhead) and appends per-ball dicts when given an array (`innings_resolver.gd:304`). This rung threads an opt-in **`capture: bool = false`** down the call chain so a season can turn it on for **the Player's matches only**:

- **`MatchResult`** gains `ball_log_innings1: Array = []` and `ball_log_innings2: Array = []` (empty unless captured).
- **`MatchResolver.simulate_match(...)`** gains `capture := false`. When true, it allocates two arrays, passes them as `ball_log` into the two `simulate_innings` calls, and stores them on the returned `MatchResult`.
- **`LeagueResolver.simulate_league(...)`** gains `capture := false`, passed through **only on Player-facing fixtures** (the games appended to `player_matches`) — NPC-vs-NPC games never capture.
- **`SeasonResolver` / `CareerResolver.play_season(...)`** gain `capture := false`, forwarded down.

Default `false` everywhere → byte-identical to today for every existing caller, oracle, and test. The Season Hub's boot/preview path passes `capture = true`.

**Cost when on:** ~240 small dicts per Player match × ~7 matches ≈ negligible per season; only paid for the season you're actually viewing.

---

## 7. Entry wiring

- **`season_hub.gd`** — a **played** fixture row (the hub already builds clickable rows) emits a new signal `open_match(match_index: int)` instead of (or in addition to) the current scrub-on-tap. The hub holds `_season` (`SeasonResult`), whose `player_matches[match_index]` is the captured `MatchResult`. Un-played fixtures keep current behaviour (DM9).
- **`main.gd`** — in `_push_hub()`, connect `hub.open_match` to a new `_push_match(match_index)` that pulls `player_matches[match_index]` + the current `Player`, instantiates `scenes/match_view/match_view.tscn`, `_push`es it, calls `set_match(...)` then `boot()`. The match scene exposes a `back` signal → `main` re-pushes the hub (re-boots, cheap).
- **`tools/preview_match_view.gd`** — sims a demo season with `capture = true`, picks a played match, renders the match scene to `docs/mockups/match-view-built-v1.png` (run **with** rendering; defer injection a frame, per the Season Hub harness lesson).

---

## 8. Testing (TDD)

Red via parse-error (missing `class_name`), green by total count climbing past the current baseline (**580**); full suite each step.

**Pure `MatchViewBuilder`:**
- `build_events`: a Player ball emits an individual `ball` event; a run of non-player balls collapses to one `over_summary` per over; mixed-over rule (player balls individual, remainder summarised).
- innings_break event present once, with the right target; result event carries the correct winner + margin.
- `build(...cursor)`: running batting score correct at a mid-innings cursor; current striker is the Player during the batting innings; boost_pressed + wicket flags surface on the right events.
- Player-centric guarantee: the count of `ball` events == (Player balls faced + Player balls bowled); no non-player delivery appears as an individual `ball`.

**Scene (`match_view`):**
- boots from an injected match without a sim; renders non-empty (`size.y > 0`, `is_visible_in_tree()`).
- `step(+1)` advances the cursor and changes the feed; `play()`/`pause()` toggle the timer; `set_speed` changes tick interval.
- `back` signal fires.

**Capture seam:**
- `simulate_match(capture=true)` → both ball-logs non-empty and lengths == innings balls; `capture=false` (default) → both empty.
- A `play_season(capture=true)` Player match carries logs; an NPC-vs-NPC game never does.
- Default-off regression: an existing season-sim assertion stays byte-identical (no signature drift).

---

## 9. Explicitly deferred (next rungs, not this one)

- **Interactive Boost/DRS** — pausing the sim at decision points to take the Player's input and branch the outcome. Requires reworking the synchronous innings loop into a pausable/resumable machine. Biggest follow-up; the watch-only screen + event stream built here is its scaffold.
- **Hi-fi / art parity** — portraits, rarity-glow, gradient chrome, a score-worm, and the cosmetic cleanups including the bare standings table. The Option-3 polish rung.
- **Live mid-season** — round-by-round standings + resumable in-season state (Option-2 rung).
- Watching a *non-player* match (other fixtures) ball-by-ball; full opposition innings ball-by-ball (collapsed here by DM2).

## 9a. Open defaults (chosen, recorded — not blocking)

- **DM9 — un-played fixtures:** tapping a not-yet-played fixture is **inert** this rung (no match to show). Existing scrub-to-fixture behaviour is preserved for played rows only if it doesn't conflict with `open_match`; simplest is played → open match, un-played → no-op.
- **DM10 — speed steps:** 1× / 2× / 4× with a sensible base tick (≈ the hub's feel); tune at build.
- **DM11 — autoplay default:** the screen **boots paused** at ball 1 (you press Play), so opening a match doesn't immediately run away. Revisit if it feels wrong on screen.

---

## 10. Findings (filled during build)

**Screenshot:** `docs/mockups/match-view-built-v1.png` (390×844 portrait), rendered by `tools/preview_match_view.gd` from a real captured season (seed `20260615`, attrs P55/C45/A35/Co30, team "Karoo Kings", `player_matches[0]`, cursor stepped 12 events in). It shows the header, "Your innings  69/2 (6.6)" scoreboard, "You batting — team 69" current line, a feed mixing individual player balls (6.1–6.6) with a collapsed "Over 5: 8 runs, 1 wkt" summary, and the control row (‹ Play 1x › Back). Confirms both event kinds render and the watch-only controls are present.

**Event counts (previewed match, `player_matches[0]`):**
- Raw ball-logs: **120 deliveries** in each innings (`ball_log_innings1` = 120, `ball_log_innings2` = 120) — a full 20-over-a-side T20.
- `build_events()` produced **76 events** total: **37 `ball`** (individual player-involved deliveries) + **37 `over`** (collapsed non-player residual summaries, ~one per over per innings) + **1 `innings_break`** + **1 `result`**.
- Of the 37 player balls: **19 the player batted**, **18 the player bowled** — i.e. the player faced 19 deliveries across the chase/innings and bowled 18 (≈3 overs). The ~240 raw deliveries fold to 76 events because non-player balls collapse per over: this is the player-centric compression working as designed (DM2).

**Tests:** full suite green at **591 / 591** (`All tests passed`, 9524 asserts). Task 7 adds no tests.

**Wire-vocabulary reconcile (reviewer-flagged):** the builder code emits event type `"over"` with fields `runs` / `total` (see `match_view_builder.gd._innings_events`), whereas §4's prose illustrates it as `"over_summary"` with `runs_in_over` / `end_total`. **The code is canonical; §4's names are illustrative shorthand.** They are reconciled — no code change. Likewise the `build()` `match` statement keys (`"ball"`, `"over"`, `"innings_break"`, `"result"`) are the real contract.

**Surprises / harness notes:**
- `Team` has no `name` property — its field is `team_name` (corrected in the harness; the header now reads "Karoo Kings v Opponent").
- In a `-s SceneTree` script, `_ready` (and thus signal wiring / `@onready` / `$Tick`) defers to the first rendered frame, so `set_match`/`boot`/`step` must run from `_process` after a frame, not in `_initialize` (mirrors `preview_season_hub.gd`). Stepping in `_initialize` left the scene showing its `.tscn` placeholder text. Fixed by deferred injection at frame 2, screenshot at frame 8.
