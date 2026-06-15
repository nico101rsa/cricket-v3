# Play → Match Screen Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tap a played fixture in the Season Hub and watch that match play back ball-by-ball, player-centric, watch-only.

**Architecture:** Mirror the Season Hub: capture per-ball logs during the sim (opt-in), a pure `MatchViewBuilder` folds them into a `MatchView` read-model at a playback cursor, and a `match_view` scene renders + auto-plays it. The scene never calls a resolver.

**Tech Stack:** Godot 4.6.3, GDScript, GUT 9.6. Pure domain logic in `scripts/domain/`, data in `scripts/data/`, scenes in `scenes/`.

**Spec:** `docs/superpowers/specs/2026-06-15-play-match-screen-design.md`

---

## Conventions (read once)

- **Run the suite (headless):** `/Applications/Godot.app/Contents/MacOS/Godot --headless --import --path . && /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`
  Always chain `--import` first (one Godot process at a time). **Quit the Godot editor before any headless run.**
- **Red/green:** GUT's `-gtest` does NOT filter — the whole suite runs every time. Judge **red** by a `SCRIPT ERROR: Parse Error: Identifier "X" not declared` (a missing `class_name`), judge **green** by the total test count climbing past **580** and `All tests passed`.
- **Tabs**, not spaces, in `.gd`. Commit `*.gd.uid` for files under `scripts/`/`tools/` (not `tests/`).
- If a run suddenly can't load GUT, clean iCloud junk: `find . \( -name "* 2" -o -name "* 2.*" \) -not -path "./.git/*" -delete && rm -rf .godot` then re-import.
- Branch is `play-match-screen` (already created, spec committed).

---

## File Structure

- **Create** `scripts/data/match_view.gd` (`MatchView`) — read-model the scene renders at a cursor.
- **Create** `scripts/domain/match_view_builder.gd` (`MatchViewBuilder`) — pure: `build_events()` + `build()`.
- **Create** `scenes/match_view/match_view.gd` + `.tscn` — the screen (render + playback).
- **Create** `tools/preview_match_view.gd` — screenshot harness.
- **Create** tests: `tests/unit/test_match_view_builder.gd`, `tests/unit/test_match_view_scene.gd`, `tests/unit/test_ball_log_capture.gd`.
- **Modify** `scripts/data/match_result.gd` — add `ball_log_innings1`/`ball_log_innings2`.
- **Modify** `scripts/domain/league_resolver.gd` — `capture` param, allocate + attach logs on Player fixtures.
- **Modify** `scripts/domain/season_resolver.gd` — `capture` param, forward.
- **Modify** `scenes/season_hub/season_hub.gd` — `open_match` signal on played rows; boot with capture.
- **Modify** `scenes/main.gd` — `_push_match()` + wire `open_match`/`back`.

---

## Task 1: Capture seam — ball-logs on player matches

`MatchResolver.simulate_match` already accepts `ball_log_1`/`ball_log_2` and threads them into both innings. We add storage fields and an opt-in `capture` flag through the league + season layers.

**Files:**
- Modify: `scripts/data/match_result.gd`
- Modify: `scripts/domain/league_resolver.gd:23` (signature) and `:87-94` (the call) and `:121-122` (attach)
- Modify: `scripts/domain/season_resolver.gd:78` (signature) and `:92-94` (the call)
- Test: `tests/unit/test_ball_log_capture.gd`

- [ ] **Step 1: Write the failing test**

Create `tests/unit/test_ball_log_capture.gd`:

```gdscript
extends GutTest

# Opt-in per-ball capture: a captured Player match carries both innings' ball-logs;
# default-off stays byte-identical (empty logs). Spec §6.

func _itun() -> InningsTuning:
	return InningsTuning.new()

func _attrs() -> Attributes:
	var a := Attributes.new()
	a.power = 40.0; a.composure = 30.0; a.attack = 25.0; a.control = 20.0
	return a

func test_match_result_logs_default_empty() -> void:
	var m := MatchResult.new()
	assert_eq(m.ball_log_innings1, [], "default innings1 log empty")
	assert_eq(m.ball_log_innings2, [], "default innings2 log empty")

func test_simulate_match_capture_fills_both_logs() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var m := MatchResolver.simulate_match(
		_attrs(), 31.25, 31.25, 31.25, 31.25, 31.25, 31.25,
		true, BallTuning.new(), _itun(), rng,
		null, null, [], null, null, null, null, null, null,
		[], [], 1.0, 1.0, null, null, null,
		[], [])  # ball_log_1, ball_log_2 = fresh arrays
	# Both innings produced deliveries (each ball_log entry == one delivery).
	assert_gt(m.innings1.balls, 0, "innings1 had deliveries")

func test_league_capture_true_attaches_logs_off_stays_empty() -> void:
	var career := CareerResolver.start_career(0)
	var team: Team = career.teams[career.current_team_index]
	var rng_on := RandomNumberGenerator.new(); rng_on.seed = 7
	var league_on := LeagueResolver.simulate_league(
		_attrs(), team, career.opponents_of_current(),
		DifficultyLadder.spec_for(career.current_level(), 0).make_tour(),
		BallTuning.new(), _itun(), rng_on,
		null, null, null, [], Callable(), true)
	assert_gt(league_on.player_matches[0].ball_log_innings1.size(), 0, "captured innings1 log")
	assert_gt(league_on.player_matches[0].ball_log_innings2.size(), 0, "captured innings2 log")

	var rng_off := RandomNumberGenerator.new(); rng_off.seed = 7
	var league_off := LeagueResolver.simulate_league(
		_attrs(), team, career.opponents_of_current(),
		DifficultyLadder.spec_for(career.current_level(), 0).make_tour(),
		BallTuning.new(), _itun(), rng_off,
		null, null, null, [], Callable())  # capture defaults false
	assert_eq(league_off.player_matches[0].ball_log_innings1, [], "off → empty innings1 log")
```

- [ ] **Step 2: Run the suite, verify red**

Run the suite (see Conventions). Expected: parse errors / failures on `ball_log_innings1` (field not yet on `MatchResult`), and the `capture` arg arity.

- [ ] **Step 3: Add storage fields to `MatchResult`**

In `scripts/data/match_result.gd`, after the `balls_remaining` line (`:15`):

```gdscript
# Opt-in per-ball replay logs (Play → Match screen, spec §6). Empty unless the
# match was simulated with capture on. innings1/innings2 follow bat order (same as
# the InningsResult fields); each entry is the per-ball dict InningsResolver records.
var ball_log_innings1: Array = []
var ball_log_innings2: Array = []
```

- [ ] **Step 4: Thread `capture` through `LeagueResolver.simulate_league`**

Add the trailing param (after `shop_hook` at `:35`):

```gdscript
		shop_hook: Callable = Callable(),
		capture: bool = false
```

In the fixture loop, before the `MatchResolver.simulate_match` call (`:87`), allocate logs for Player fixtures:

```gdscript
			var bl1 = [] if (capture and i == 0) else null
			var bl2 = [] if (capture and i == 0) else null
```

Append `bl1, bl2` to the `simulate_match(...)` call (it currently ends at `obp`):

```gdscript
				rosters[i], rosters[j], bat[i] / MatchResolver.REF_SCALAR, bat[j] / MatchResolver.REF_SCALAR,
				null, odp, obp, bl1, bl2)
```

Where the Player match is appended (`:121-122`), attach the logs:

```gdscript
			if i == 0:
				if capture:
					m.ball_log_innings1 = bl1
					m.ball_log_innings2 = bl2
				player_matches.append(m)
```

- [ ] **Step 5: Thread `capture` through `SeasonResolver.simulate_season`**

Add the trailing param (after `shop_hook` at `:90`):

```gdscript
		shop_hook: Callable = Callable(),
		capture: bool = false
```

Forward it to the `simulate_league` call (`:92-94`):

```gdscript
	var league := LeagueResolver.simulate_league(
		player_attrs, player_team, opponents, tour, tuning, itun, rng,
		player_intent_plan, player_bowling_plan, opp_spec, jokers, shop_hook, capture)
```

- [ ] **Step 6: Re-import, run the suite, verify green**

Expected: the 3 new tests pass; total count climbs and `All tests passed`. (All existing callers pass `capture=false` by default → byte-identical.)

- [ ] **Step 7: Commit**

```bash
git add scripts/data/match_result.gd scripts/data/match_result.gd.uid \
  scripts/domain/league_resolver.gd scripts/domain/league_resolver.gd.uid \
  scripts/domain/season_resolver.gd scripts/domain/season_resolver.gd.uid \
  tests/unit/test_ball_log_capture.gd
git commit -m "Match screen: opt-in per-ball capture on Player matches"
```

---

## Task 2: `MatchView` read-model

**Files:**
- Create: `scripts/data/match_view.gd`
- Test: covered via Task 4 (the builder produces it); no standalone test needed for a plain holder.

- [ ] **Step 1: Create the data class**

`scripts/data/match_view.gd`:

```gdscript
class_name MatchView
extends RefCounted

# Read-model the match_view scene renders at one playback cursor. Built by
# MatchViewBuilder; pure data, no logic. Spec §3.

var innings_label: String = ""     # "Your innings" / "Bowling — chasing 151"
var batting_score: String = ""     # running "84/3 (10.2)" for the active batting side
var target_text: String = ""       # "Target 151" in the 2nd innings, else ""
var current_line: String = ""      # striker "You 40* (28)" or bowling "You 2/26 (4.0)"
var feed: Array = []               # last ~6 event display strings (newest last)
var finished: bool = false         # cursor reached the end
var result_text: String = ""       # "won by 5 wickets" once finished
var player_won: bool = false
var event_count: int = 0           # total events in the stream (for the scrubber)
```

- [ ] **Step 2: Re-import, run suite, verify still green**

No behaviour change yet; suite stays green (the `class_name` registers).

- [ ] **Step 3: Commit**

```bash
git add scripts/data/match_view.gd scripts/data/match_view.gd.uid
git commit -m "Match screen: MatchView read-model"
```

---

## Task 3: `MatchViewBuilder.build_events` — the player-centric stream

**Files:**
- Create: `scripts/domain/match_view_builder.gd`
- Test: `tests/unit/test_match_view_builder.gd`

- [ ] **Step 1: Write the failing test**

Create `tests/unit/test_match_view_builder.gd`:

```gdscript
extends GutTest

# MatchViewBuilder.build_events — folds two raw ball-logs into one player-centric
# playback list (player balls individual, others collapsed per over). Spec §4.

func _player() -> Player:
	var p := Player.new()
	var n := NamePair.new(); n.first_name = "Bongani"; n.surname = "Kgosi"
	p.name = n
	return p

# Build a hand-made innings log: `specs` is an array of dicts with the keys the
# sim records. Helper keeps tests readable.
func _ball(over: int, bio: int, is_player: bool, p_bat: bool, p_bowl: bool,
		runs: int, wicket: bool, boost: bool, total: int, wkts: int) -> Dictionary:
	return {"over": over, "ball_in_over": bio, "striker_pos": 3, "is_player": is_player,
		"player_batting": p_bat, "player_bowling": p_bowl, "intent": 0,
		"boost_pressed": boost, "wicket": wicket, "runs": runs, "total": total, "wickets": wkts}

func _match_with_logs(log1: Array, log2: Array, player_first: bool) -> MatchResult:
	var m := MatchResult.new()
	m.player_bats_first = player_first
	m.innings1 = InningsResult.new(log1[-1]["total"], log1[-1]["wickets"], log1.size(), [], [])
	m.innings2 = InningsResult.new(log2[-1]["total"], log2[-1]["wickets"], log2.size(), [], [])
	m.outcome = MatchResult.Outcome.PLAYER_WIN
	m.margin_wickets = 5; m.balls_remaining = 6
	m.ball_log_innings1 = log1
	m.ball_log_innings2 = log2
	return m

func test_player_balls_individual_others_collapsed() -> void:
	# Innings 1 (player batting): over 1 — player faces balls 1,2 (non-striker faces 3),
	# Innings 2 (player bowling over 1): all 3 balls are the player bowling.
	var log1 := [
		_ball(1, 1, true,  true, false, 4, false, true,  4, 0),
		_ball(1, 2, true,  true, false, 1, false, false, 5, 0),
		_ball(1, 3, false, true, false, 0, false, false, 5, 0)]  # non-striker, non-player
	var log2 := [
		_ball(1, 1, false, false, true, 1, false, false, 1, 0),
		_ball(1, 2, false, false, true, 0, true,  false, 1, 1),
		_ball(1, 3, false, false, true, 2, false, false, 3, 1)]
	var m := _match_with_logs(log1, log2, true)
	var events := MatchViewBuilder.build_events(m, _player())
	var balls := events.filter(func(e): return e["type"] == "ball")
	# Player faced 2 + bowled 3 = 5 individual ball events.
	assert_eq(balls.size(), 5, "5 player-involved ball events")
	var overs := events.filter(func(e): return e["type"] == "over")
	assert_eq(overs.size(), 1, "one over-summary for the non-player ball")
	assert_eq(events.filter(func(e): return e["type"] == "innings_break").size(), 1, "one innings break")
	assert_eq(events[-1]["type"], "result", "stream ends with a result event")

func test_result_event_carries_outcome() -> void:
	var log1 := [_ball(1, 1, true, true, false, 4, false, false, 4, 0)]
	var log2 := [_ball(1, 1, false, false, true, 0, true, false, 0, 1)]
	var m := _match_with_logs(log1, log2, true)
	var events := MatchViewBuilder.build_events(m, _player())
	var res: Dictionary = events[-1]
	assert_true(res["player_won"], "result marks the player win")
	assert_string_contains(res["text"], "won by", "result text uses margin phrasing")
```

- [ ] **Step 2: Run the suite, verify red**

Expected: `Parse Error: Identifier "MatchViewBuilder" not declared`.

- [ ] **Step 3: Implement `build_events`**

Create `scripts/domain/match_view_builder.gd`:

```gdscript
class_name MatchViewBuilder
extends RefCounted

# Pure builder for the Play → Match screen. build_events() transforms the two raw
# per-ball logs (MatchResult.ball_log_innings1/2) into one ordered, player-centric
# playback list; build() folds that list up to a cursor into a MatchView. No sim
# calls, no RNG — same purity contract as SeasonViewBuilder. Spec §3-§4.

# A ball is "player-involved" if the Player faced it (batting) or bowled it.
static func _involved(b: Dictionary) -> bool:
	return b["is_player"] or b["player_bowling"]

# Transform one innings log into events: player balls individual, the rest of each
# over collapsed into a single "over" summary. `innings_no` is 1 or 2.
static func _innings_events(log: Array, innings_no: int) -> Array:
	var out: Array = []
	var over_no := 0
	var residual_runs := 0
	var residual_wkts := 0
	var residual_total := 0
	var residual_wickets := 0
	var have_residual := false
	for b in log:
		if b["over"] != over_no:
			# flush the previous over's residual non-player balls
			if have_residual:
				out.append({"type": "over", "over": over_no, "runs": residual_runs,
					"wkts": residual_wkts, "total": residual_total, "wickets": residual_wickets,
					"innings": innings_no})
			over_no = b["over"]
			residual_runs = 0; residual_wkts = 0; have_residual = false
		if _involved(b):
			out.append({"type": "ball", "over": b["over"], "ball": b["ball_in_over"],
				"player_batting": b["player_batting"], "player_bowling": b["player_bowling"],
				"runs": b["runs"], "wicket": b["wicket"], "boost": b["boost_pressed"],
				"total": b["total"], "wickets": b["wickets"], "innings": innings_no})
		else:
			residual_runs += b["runs"]
			residual_wkts += (1 if b["wicket"] else 0)
			residual_total = b["total"]; residual_wickets = b["wickets"]
			have_residual = true
	if have_residual:
		out.append({"type": "over", "over": over_no, "runs": residual_runs,
			"wkts": residual_wkts, "total": residual_total, "wickets": residual_wickets,
			"innings": 1 if innings_no == 1 else 2})
	return out

static func build_events(mr: MatchResult, _player: Player) -> Array:
	var events: Array = []
	events.append_array(_innings_events(mr.ball_log_innings1, 1))
	# innings break: 1st-innings final + the target the chase needs.
	var first_total: int = mr.innings1.total
	events.append({"type": "innings_break", "first_total": first_total,
		"first_wkts": mr.innings1.wickets, "target": first_total + 1})
	events.append_array(_innings_events(mr.ball_log_innings2, 2))
	events.append({"type": "result", "text": mr.margin_text(),
		"player_won": mr.player_won()})
	return events
```

- [ ] **Step 4: Re-import, run the suite, verify green**

Expected: the two builder tests pass; count climbs; `All tests passed`.

- [ ] **Step 5: Commit**

```bash
git add scripts/domain/match_view_builder.gd scripts/domain/match_view_builder.gd.uid \
  tests/unit/test_match_view_builder.gd
git commit -m "Match screen: MatchViewBuilder.build_events (player-centric stream)"
```

---

## Task 4: `MatchViewBuilder.build` — fold to a cursor

**Files:**
- Modify: `scripts/domain/match_view_builder.gd`
- Test: `tests/unit/test_match_view_builder.gd` (add cases)

- [ ] **Step 1: Add failing tests**

Append to `tests/unit/test_match_view_builder.gd`:

```gdscript
func test_build_running_score_at_cursor() -> void:
	var log1 := [
		_ball(1, 1, true, true, false, 4, false, false, 4, 0),
		_ball(1, 2, true, true, false, 6, false, false, 10, 0),
		_ball(1, 3, true, true, false, 0, true,  false, 10, 1)]
	var log2 := [_ball(1, 1, false, false, true, 0, true, false, 0, 1)]
	var m := _match_with_logs(log1, log2, true)
	var view := MatchViewBuilder.build(m, _player(), 2)  # after 2 events (2 balls)
	assert_string_contains(view.batting_score, "10/0", "running score reflects 2 balls")
	assert_false(view.finished, "not finished mid-stream")
	assert_gt(view.event_count, 0, "event_count populated")

func test_build_at_end_is_finished_with_result() -> void:
	var log1 := [_ball(1, 1, true, true, false, 4, false, false, 4, 0)]
	var log2 := [_ball(1, 1, false, false, true, 0, true, false, 0, 1)]
	var m := _match_with_logs(log1, log2, true)
	var view := MatchViewBuilder.build(m, _player(), 99)  # past the end → clamps
	assert_true(view.finished, "finished at end of stream")
	assert_string_contains(view.result_text, "won by", "result text present")
	assert_true(view.player_won, "player_won set")
```

- [ ] **Step 2: Run the suite, verify red**

Expected: `build` returns null / arity error → the two new tests fail.

- [ ] **Step 3: Implement `build`**

Append to `scripts/domain/match_view_builder.gd`:

```gdscript
# Fold the event stream up to `cursor` (0..event_count) into the current MatchView.
static func build(mr: MatchResult, player: Player, cursor: int) -> MatchView:
	var events := build_events(mr, player)
	var v := MatchView.new()
	v.event_count = events.size()
	var c: int = clampi(cursor, 0, events.size())

	var bat_total := 0
	var bat_wkts := 0
	var innings_no := 1
	var target := 0
	var feed: Array = []

	for k in range(c):
		var e: Dictionary = events[k]
		match e["type"]:
			"ball":
				innings_no = e["innings"]
				bat_total = e["total"]; bat_wkts = e["wickets"]
				var tag := ""
				if e["boost"]: tag = "BOOST · "
				var what := ("WICKET!" if e["wicket"] else "%d run%s" % [e["runs"], "" if e["runs"] == 1 else "s"])
				feed.append("%d.%d  %s%s" % [e["over"], e["ball"], tag, what])
				v.current_line = _line_for(e, bat_total, bat_wkts)
			"over":
				innings_no = e["innings"]
				bat_total = e["total"]; bat_wkts = e["wickets"]
				feed.append("Over %d: %d run%s%s" % [e["over"], e["runs"],
					"" if e["runs"] == 1 else "s",
					(", %d wkt" % e["wkts"]) if e["wkts"] > 0 else ""])
			"innings_break":
				target = e["target"]
				innings_no = 2
				bat_total = 0; bat_wkts = 0
				feed.append("Innings break — chasing %d" % target)
			"result":
				v.finished = true
				v.result_text = e["text"]
				v.player_won = e["player_won"]
				feed.append("Result: %s" % e["text"])

	# Active innings label + scoreboard.
	var player_bats_this := (innings_no == 1) == mr.player_bats_first
	if innings_no == 2 and target > 0:
		v.innings_label = ("Your chase" if player_bats_this else "Bowling — defending %d" % target)
		v.target_text = "Target %d" % target
	else:
		v.innings_label = ("Your innings" if player_bats_this else "Bowling")
		v.target_text = ""
	var od := _over_dot(events, c)
	var overs := "%d.%d" % [od[0], od[1]]
	v.batting_score = "%d/%d (%s)" % [bat_total, bat_wkts, overs]
	v.feed = feed.slice(maxi(0, feed.size() - 6))
	return v

# The striker/bowler one-liner for the current ball.
static func _line_for(e: Dictionary, total: int, _wkts: int) -> String:
	if e["player_bowling"]:
		return "You bowling — %d.%d" % [e["over"], e["ball"]]
	if e["player_batting"]:
		return "You batting — team %d" % total
	return ""

# Best-effort current over.ball from the last applied event (display only).
static func _over_dot(events: Array, c: int) -> Array:
	for k in range(c - 1, -1, -1):
		var e: Dictionary = events[k]
		if e["type"] == "ball":
			return [e["over"], e["ball"]]
		if e["type"] == "over":
			return [e["over"], 6]
	return [0, 0]
```

- [ ] **Step 4: Re-import, run the suite, verify green**

Expected: all builder tests pass; count climbs; `All tests passed`.

- [ ] **Step 5: Commit**

```bash
git add scripts/domain/match_view_builder.gd tests/unit/test_match_view_builder.gd
git commit -m "Match screen: MatchViewBuilder.build (fold to cursor)"
```

---

## Task 5: `match_view` scene — render + playback

**Files:**
- Create: `scenes/match_view/match_view.tscn`, `scenes/match_view/match_view.gd`
- Test: `tests/unit/test_match_view_scene.gd`

- [ ] **Step 1: Build the scene tree**

Create `scenes/match_view/match_view.tscn` with this node tree (build in the editor or hand-write the `.tscn`; mirror `season_hub.tscn`). Root `Control` named `MatchView` with script `match_view.gd`, a `MarginContainer` → `VBoxContainer` named `Root` containing, in order:
- `Label` `Header`
- `Label` `Scoreboard`
- `Label` `Target`
- `Label` `CurrentLine`
- `VBoxContainer` `FeedBox` with `custom_minimum_size = Vector2(0, 180)` (so it never collapses — the ScrollContainer/zero-min-size lesson)
- `HBoxContainer` `Controls` with buttons `StepBack`, `PlayPause`, `Speed`, `StepFwd`, `Back`
- `Timer` `Tick` (one-shot off; `wait_time = 0.6`)

- [ ] **Step 2: Write the failing scene test**

Create `tests/unit/test_match_view_scene.gd`:

```gdscript
extends GutTest

# match_view scene: boots from an injected match (no sim), renders, steps, and
# the Back signal fires. Spec §5, §8.

const SCENE := preload("res://scenes/match_view/match_view.tscn")

func _player() -> Player:
	var p := Player.new()
	var n := NamePair.new(); n.first_name = "B"; n.surname = "K"
	p.name = n
	return p

func _ball(over, bio, is_p, p_bat, p_bowl, runs, wkt, total, wkts) -> Dictionary:
	return {"over": over, "ball_in_over": bio, "striker_pos": 3, "is_player": is_p,
		"player_batting": p_bat, "player_bowling": p_bowl, "intent": 0,
		"boost_pressed": false, "wicket": wkt, "runs": runs, "total": total, "wickets": wkts}

func _match() -> MatchResult:
	var m := MatchResult.new()
	m.player_bats_first = true
	m.innings1 = InningsResult.new(10, 1, 3, [], [])
	m.innings2 = InningsResult.new(8, 10, 4, [], [])
	m.outcome = MatchResult.Outcome.PLAYER_WIN
	m.margin_wickets = 9; m.balls_remaining = 110
	m.ball_log_innings1 = [
		_ball(1, 1, true, true, false, 4, false, 4, 0),
		_ball(1, 2, true, true, false, 6, false, 10, 0),
		_ball(1, 3, true, true, false, 0, true, 10, 1)]
	m.ball_log_innings2 = [_ball(1, 1, false, false, true, 0, true, 0, 1)]
	return m

func test_boots_and_renders() -> void:
	var s = SCENE.instantiate()
	add_child_autofree(s)
	s.set_match(_match(), _player(), "Karoo Kings", "Dusty Plains")
	s.boot()
	await get_tree().process_frame
	var feed: VBoxContainer = s.get_node("%Root/FeedBox") if s.has_node("%Root/FeedBox") else s.get_node("Root/FeedBox")
	assert_true(s.is_visible_in_tree(), "scene visible")
	assert_gt(s.size.y, 0, "scene has height")

func test_step_advances_cursor() -> void:
	var s = SCENE.instantiate()
	add_child_autofree(s)
	s.set_match(_match(), _player(), "Karoo Kings", "Dusty Plains")
	s.boot()
	await get_tree().process_frame
	var before := s.cursor()
	s.step(1)
	assert_eq(s.cursor(), before + 1, "step(1) advances the cursor")

func test_back_signal_fires() -> void:
	var s = SCENE.instantiate()
	add_child_autofree(s)
	s.set_match(_match(), _player(), "Karoo Kings", "Dusty Plains")
	s.boot()
	watch_signals(s)
	s.get_node("Root/Controls/Back").pressed.emit()
	assert_signal_emitted(s, "back")
```

- [ ] **Step 3: Run the suite, verify red**

Expected: parse/instance failure — `set_match`/`boot`/`cursor`/`back` not defined.

- [ ] **Step 4: Implement `match_view.gd`**

Create `scenes/match_view/match_view.gd`:

```gdscript
extends Control

# Play → Match screen: watch-only, player-centric ball-by-ball replay. Renders a
# MatchView built by MatchViewBuilder at the current cursor; autoplay via a Timer.
# boot() is explicit (not in _ready) so tests inject without a sim. Spec §3, §5.

signal back

const SPEEDS := [1.0, 2.0, 4.0]
const BASE_TICK := 0.6

@onready var _root: VBoxContainer = $Root

var _match: MatchResult
var _player: Player
var _team_name := ""
var _opp_name := ""
var _cursor := 0
var _event_count := 0
var _speed_idx := 0
var _playing := false

func _ready() -> void:
	$Root/Controls/StepBack.pressed.connect(func(): pause(); step(-1))
	$Root/Controls/StepFwd.pressed.connect(func(): pause(); step(1))
	$Root/Controls/PlayPause.pressed.connect(_toggle_play)
	$Root/Controls/Speed.pressed.connect(_cycle_speed)
	$Root/Controls/Back.pressed.connect(func(): back.emit())
	$Tick.timeout.connect(_on_tick)
	$Tick.wait_time = BASE_TICK

func set_match(mr: MatchResult, player: Player, team_name: String, opp_name: String) -> void:
	_match = mr
	_player = player
	_team_name = team_name
	_opp_name = opp_name

func boot() -> void:
	if _match == null:
		return
	_cursor = 0
	_event_count = MatchViewBuilder.build(_match, _player, 0).event_count
	_render()   # boots paused at ball 1 (DM11)

func cursor() -> int:
	return _cursor

func step(delta: int) -> void:
	_cursor = clampi(_cursor + delta, 0, _event_count)
	_render()
	if _cursor >= _event_count:
		pause()

func play() -> void:
	if _cursor >= _event_count:
		return
	_playing = true
	$Tick.start()
	$Root/Controls/PlayPause.text = "Pause"

func pause() -> void:
	_playing = false
	$Tick.stop()
	$Root/Controls/PlayPause.text = "Play"

func set_speed(mult: float) -> void:
	$Tick.wait_time = BASE_TICK / mult

func _toggle_play() -> void:
	if _playing: pause()
	else: play()

func _cycle_speed() -> void:
	_speed_idx = (_speed_idx + 1) % SPEEDS.size()
	set_speed(SPEEDS[_speed_idx])
	$Root/Controls/Speed.text = "%dx" % int(SPEEDS[_speed_idx])

func _on_tick() -> void:
	step(1)

func _render() -> void:
	var v := MatchViewBuilder.build(_match, _player, _cursor)
	$Root/Header.text = "%s  v  %s" % [_team_name, _opp_name]
	$Root/Scoreboard.text = "%s   %s" % [v.innings_label, v.batting_score]
	$Root/Target.text = v.target_text
	$Root/CurrentLine.text = (v.result_text if v.finished else v.current_line)
	var box: VBoxContainer = $Root/FeedBox
	for c in box.get_children():
		c.queue_free()
	for line in v.feed:
		var l := Label.new()
		l.text = line
		box.add_child(l)
```

NOTE for the implementer: ensure `Tick` is a **direct child of the scene root** (per the `.tscn` in Step 1) so `$Tick` resolves. If the editor placed it elsewhere, move it to the root.

- [ ] **Step 5: Re-import, run the suite, verify green**

Expected: the 3 scene tests pass; count climbs; `All tests passed`.

- [ ] **Step 6: Commit**

```bash
git add scenes/match_view/match_view.gd scenes/match_view/match_view.gd.uid \
  scenes/match_view/match_view.tscn tests/unit/test_match_view_scene.gd
git commit -m "Match screen: match_view scene (render + playback)"
```

---

## Task 6: Entry wiring — Season Hub → Match screen

**Files:**
- Modify: `scenes/season_hub/season_hub.gd` (`open_match` signal; played rows open the match; boot with capture)
- Modify: `scenes/main.gd` (`_push_match`; wire `open_match`/`back`)
- Test: extend `tests/unit/test_season_hub_scene.gd` (assert the signal exists/fires) — if that file doesn't exist, add a small focused test file `tests/unit/test_season_hub_open_match.gd`.

- [ ] **Step 1: Write the failing test**

Create `tests/unit/test_season_hub_open_match.gd`:

```gdscript
extends GutTest

# Tapping a PLAYED fixture row emits open_match(index). Spec §7.
const HUB := preload("res://scenes/season_hub/season_hub.tscn")

func _view_with_one_played() -> SeasonView:
	var v := SeasonView.new()
	v.team_name = "Karoo Kings"
	v.country = Country.Code.SA
	v.scrub_index = 1
	v.match_count = 7
	v.fixtures = [{"played": true, "player_won": true, "opponent_name": "Dusty Plains",
		"score_text": "165/2  v  162/1"}]
	v.standings = []
	return v

func test_played_row_emits_open_match() -> void:
	var hub = HUB.instantiate()
	add_child_autofree(hub)
	hub.set_view(_view_with_one_played())
	await get_tree().process_frame
	watch_signals(hub)
	var box: VBoxContainer = hub.get_node("Root/FixturesBox") if hub.has_node("Root/FixturesBox") else hub.get_node("FixturesBox")
	box.get_child(0).pressed.emit()
	assert_signal_emitted_with_parameters(hub, "open_match", [0])
```

(Adjust the `FixturesBox` path to match `season_hub.tscn`.)

- [ ] **Step 2: Run the suite, verify red**

Expected: `open_match` signal not declared → failure.

- [ ] **Step 3: Add the signal + played-row behaviour in `season_hub.gd`**

At the top of `scenes/season_hub/season_hub.gd`, add:

```gdscript
signal open_match(match_index: int)
```

In `_render_fixtures`, change the row's `pressed` connection so a **played** fixture opens the match and an unplayed one keeps scrubbing:

```gdscript
		var idx := i
		if f["played"]:
			row.pressed.connect(func(): open_match.emit(idx))
		else:
			row.pressed.connect(func(): _rebuild(idx))
```

In `boot()`, simulate the season with capture on so the tapped match has logs — change the `SeasonResolver.simulate_season(...)` call to pass `capture = true` as the trailing arg:

```gdscript
	var season := SeasonResolver.simulate_season(
		player.attributes, team, career.opponents_of_current(),
		spec.make_tour(), BallTuning.new(), InningsTuning.new(), rng,
		null, null, null, [], Callable(), true)
```

- [ ] **Step 4: Wire `main.gd`**

In `scenes/main.gd`, add the preload near the others:

```gdscript
const MATCH_VIEW := preload("res://scenes/match_view/match_view.tscn")
```

In `_push_hub()`, connect the new signal after instancing:

```gdscript
func _push_hub() -> void:
	var hub := SEASON_HUB.instantiate()
	hub.open_match.connect(_push_match)
	_push(hub)
	hub.boot()
```

Add `_push_match` (pulls the captured match + names off the hub's season/view and pushes the match scene):

```gdscript
func _push_match(match_index: int) -> void:
	var player := SaveManager.load_player()
	var hub = _slot.get_child(0)   # the live Season Hub
	var season: SeasonResult = hub._season
	var view: SeasonView = hub._view
	var m: MatchResult = season.league.player_matches[match_index]
	var opp: String = view.fixtures[match_index]["opponent_name"]
	var screen := MATCH_VIEW.instantiate()
	screen.back.connect(_push_hub)
	_push(screen)
	screen.set_match(m, player, view.team_name, opp)
	screen.boot()
```

NOTE: reading `hub._season`/`hub._view` couples to the hub's internals. If you prefer, add tiny public getters `func season() -> SeasonResult: return _season` and `func current_view() -> SeasonView: return _view` to `season_hub.gd` and use those. Recommended — add the getters.

- [ ] **Step 5: Re-import, run the suite, verify green**

Expected: the open_match test passes; count climbs; `All tests passed`.

- [ ] **Step 6: Commit**

```bash
git add scenes/season_hub/season_hub.gd scenes/season_hub/season_hub.gd.uid \
  scenes/main.gd scenes/main.gd.uid tests/unit/test_season_hub_open_match.gd
git commit -m "Match screen: Season Hub fixture tap → match view wiring"
```

---

## Task 7: Preview harness + screenshot + findings

**Files:**
- Create: `tools/preview_match_view.gd`
- Modify: spec `§10`, `PROJECT_ROADMAP.md`

- [ ] **Step 1: Write the preview harness**

Create `tools/preview_match_view.gd` (mirror `tools/preview_season_hub.gd`):

```gdscript
extends SceneTree

# Renders the match_view scene for a real captured match to a PNG. Run WITH
# rendering (no --headless): inject after a frame because @onready isn't resolved
# in a -s script's _initialize. Spec §7.
#   /Applications/Godot.app/Contents/MacOS/Godot --path . -s tools/preview_match_view.gd

const OUT := "res://docs/mockups/match-view-built-v1.png"

func _initialize() -> void:
	var a := Attributes.new()
	a.power = 55.0; a.composure = 45.0; a.attack = 35.0; a.control = 30.0
	var career := CareerResolver.start_career(0)
	var team: Team = career.teams[career.current_team_index]
	var rng := RandomNumberGenerator.new(); rng.seed = 20260615
	var season := SeasonResolver.simulate_season(
		a, team, career.opponents_of_current(),
		DifficultyLadder.spec_for(career.current_level(), 0).make_tour(),
		BallTuning.new(), InningsTuning.new(), rng,
		null, null, null, [], Callable(), true)
	var player := Player.new()
	var n := NamePair.new(); n.first_name = "Bongani"; n.surname = "Kgosi"
	player.name = n; player.attributes = a
	var scene: Control = load("res://scenes/match_view/match_view.tscn").instantiate()
	get_root().add_child(scene)
	scene.set_match(season.league.player_matches[0], player, team.name, "Opponent")
	scene.boot()
	# advance the cursor into the match for a representative frame
	for i in range(12):
		scene.step(1)
	_frames = 0

var _frames := 0
func _process(_d: float) -> bool:
	_frames += 1
	if _frames < 3:
		return false
	var img := get_root().get_viewport().get_texture().get_image()
	img.save_png(OUT)
	quit()
	return true
```

- [ ] **Step 2: Run the harness, verify the PNG**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path . -s tools/preview_match_view.gd
```
Expected: `docs/mockups/match-view-built-v1.png` written. Open it; confirm header, scoreboard, current line, and a player-centric feed (player balls individual, others as "Over N: …"). Adjust the speed/step count if the frame is uninformative.

- [ ] **Step 3: Fill spec §10 + roadmap**

Replace the spec `§10` TBD with real findings: the event count on the previewed match (player balls faced + bowled vs collapsed overs), any sim-seam surprises, and the screenshot path. Add a roadmap "Latest" entry per the End-of-Session routine (handoff block) and bump the green test count.

- [ ] **Step 4: Final full suite run, verify green**

Run the suite once more. Expected: `All tests passed`, count well above 580.

- [ ] **Step 5: Commit**

```bash
git add tools/preview_match_view.gd tools/preview_match_view.gd.uid \
  docs/mockups/match-view-built-v1.png \
  docs/superpowers/specs/2026-06-15-play-match-screen-design.md \
  PROJECT_ROADMAP.md
git commit -m "Match screen: preview harness + screenshot + §10 findings"
```

---

## Self-review notes (carried into execution)

- **Spec coverage:** DM1 watch-only (no interactivity — Task 5 plays back only) ✓ · DM2 player-centric (Task 3 `_involved`) ✓ · DM3 fixture tap (Task 6) ✓ · DM4 opt-in capture (Task 1) ✓ · DM5 mirror hub (Tasks 2-5) ✓ · DM6 low-fi (Task 5 flat labels) ✓ · capture seam §6 (Task 1) ✓ · panels §5 (Task 5) ✓ · testing §8 (every task) ✓ · preview §7 (Task 7) ✓.
- **ScrollContainer/zero-min lesson:** `FeedBox` gets `custom_minimum_size` height; scene tests assert `size.y > 0` + `is_visible_in_tree`.
- **Naming consistency:** `ball_log_innings1/2` (MatchResult), `build_events`/`build` (builder), `set_match`/`boot`/`step`/`cursor`/`back` (scene), `open_match` (hub), `_push_match` (main) — used identically across tasks.
- **GDScript gotchas:** `MatchResult.Outcome` is a **nested** enum; in a `-s` SceneTree script `@onready`/child `_ready` defer to a frame (preview injects after frames); don't shadow built-in class names. **`match` is a reserved GDScript keyword** — never use it as a param/var name (it would fail to parse). The builder/scene take `mr: MatchResult`; the `var _match` field (underscore-prefixed) is fine. The `match e["type"]:` in `build()` is the real `match` *statement* and is correct.
- **Playoff matches** are out of scope (only league `player_matches` are tappable); noted in spec §9.
