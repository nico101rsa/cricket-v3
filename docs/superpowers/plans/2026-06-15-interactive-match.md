# Interactive Match (Boost + batting-side DRS) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the watch-only Match screen interactive — press the Manager Boost and review your own dismissals (DRS), with your calls actually changing the match.

**Architecture:** Deterministic re-simulation (spec DI1). A new pure `MatchSession` holds the match seed + the accumulating decision policy (`press_overs`, `review_balls`); each decision re-runs the existing pure `MatchResolver.simulate_match_teams` with rebuilt `BoostPlan`/`DRSPolicy` + re-captures the ball-logs, producing a fresh event stream the screen replays. The only sim change is one default-off gate in `InningsResolver`'s batting-side DRS branch reading a new `DRSPolicy.review_balls` field — `null` (every sweep/headless call) stays byte-identical.

**Tech Stack:** Godot 4.6.3 / GDScript, GUT 9.6 (vendored at `addons/gut/`).

**Conventions (project CLAUDE.md):** tabs in `.gd`; run `--import` once after adding/renaming scripts before tests; quit the Godot editor before headless runs; ONE Godot process at a time; commit `*.gd.uid` for `scripts/`+`tools/` (not `tests/`); GUT `-gtest` does NOT filter — judge **red** by a `Parse Error: Identifier "X" not declared` for a not-yet-created `class_name`, judge **green** by the total count climbing past **591** and `All tests passed`.

**Test/import commands:**
- Import (after new scripts): `/Applications/Godot.app/Contents/MacOS/Godot --headless --import --path .`
- Full suite: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`
- Chain them: `… --import --path . && … -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`

---

## File Structure

| File | Responsibility |
|---|---|
| `scripts/data/drs_policy.gd` (modify) | add `review_balls` field (default `null` = auto). |
| `scripts/domain/innings_resolver.gd` (modify) | batting-side survive-review honors `drs_policy.review_balls` when set; `null` = byte-identical. |
| `scripts/domain/match_session.gd` (create) | the interactive controller: seed + accumulating policy, re-sim on each decision, offer detection, budgets. |
| `scenes/interactive_match/interactive_match.{gd,tscn}` (create) | interactive scene: watch controls + Boost button + DRS overlay. |
| `tools/preview_interactive_match.gd` (create) | fixed-seed match, scripts a decision, renders the screenshot. |
| `tests/unit/test_drs_review_balls_seam.gd` (create) | the resolver gate (default-off byte-identical + scripted fires). |
| `tests/unit/test_match_session.gd` (create) | start, prefix-stability, boost, review, budgets. |
| `tests/unit/test_interactive_match_scene.gd` (create) | overlay appears on a review offer; boost button; injection. |

---

## Task 1: `DRSPolicy.review_balls` field

**Files:**
- Modify: `scripts/data/drs_policy.gd`
- Test: `tests/unit/test_drs_review_balls_seam.gd` (created here, extended in Task 2)

- [ ] **Step 1: Write the failing test**

Create `tests/unit/test_drs_review_balls_seam.gd`:

```gdscript
extends GutTest

# DI3 seam — DRSPolicy.review_balls scopes the Player's batting-side review.

func test_review_balls_defaults_to_null():
	var d := DRSPolicy.new()
	assert_eq(d.review_balls, null, "auto by default (null) — sweeps untouched")

func test_review_balls_can_be_set():
	var d := DRSPolicy.new()
	d.review_balls = [[9, 3]]
	assert_eq(d.review_balls, [[9, 3]])
```

- [ ] **Step 2: Run to verify it fails**

Run the import+suite chain. Expected: `Parse Error: Identifier "review_balls" not declared` (red) OR an assert failure — the field doesn't exist yet.

- [ ] **Step 3: Add the field**

In `scripts/data/drs_policy.gd`, after `var base_p: float = 0.32` add:

```gdscript

# Interactive (DI3): when non-null, the Player's batting-side survive-review fires
# ONLY on the [over, ball_in_over] pairs in this set (scripted by MatchSession).
# null = auto policy (every sweep / headless call) → byte-identical to pre-rung.
var review_balls = null
```

- [ ] **Step 4: Run to verify it passes**

Run the import+suite chain. Expected: both new tests green, total count climbs, `All tests passed`.

- [ ] **Step 5: Commit**

```bash
git add scripts/data/drs_policy.gd scripts/data/drs_policy.gd.uid tests/unit/test_drs_review_balls_seam.gd
git commit -m "Interactive match: DRSPolicy.review_balls field (default null = auto)"
```

---

## Task 2: `InningsResolver` scripted-review gate

**Files:**
- Modify: `scripts/domain/innings_resolver.gd` (the batting-side survive branch, ~L240–246)
- Test: `tests/unit/test_drs_review_balls_seam.gd` (extend)

The contrast that makes this deterministic: with `base_p = 1.0` a review always succeeds, and a success RETAINS the review (only failures decrement `reviews_left`). So:
- `review_balls = null` (auto) → every Player-batting wicket is auto-reviewed and overturned → **the Player's batting innings ends with 0 wickets**.
- `review_balls = []` (scripted, declined all) → no survive-reviews fire → **wickets stand**.
- `review_balls = [[over, ball]]` of a real dismissal → **only that ball** is overturned.

- [ ] **Step 1: Write the failing test**

Append to `tests/unit/test_drs_review_balls_seam.gd`:

```gdscript
# Helper: run a full match, Player forced to bat first (innings1 = Player batting),
# DRS success guaranteed (base_p=1.0). Returns the MatchResult with captured logs.
func _run(review_balls) -> MatchResult:
	var a := Attributes.new()
	a.power = 55.0; a.composure = 45.0; a.attack = 35.0; a.control = 30.0
	var career := CareerResolver.start_career(0)
	var team: Team = career.teams[career.current_team_index]
	var opp: Team = career.opponents_of_current()[0]
	var tour := DifficultyLadder.spec_for(career.current_level(), 0).make_tour()
	var drs := DRSPolicy.new()
	drs.base_p = 1.0
	drs.review_balls = review_balls
	var rng := RandomNumberGenerator.new(); rng.seed = 20260615
	var log1: Array = []
	var log2: Array = []
	return MatchResolver.simulate_match_teams(
		a, team, opp, tour, BallTuning.new(), InningsTuning.new(), rng,
		null, null, [], null, null, null,
		null, drs, null, null, null, 1, null, log1, log2)

func test_auto_null_overturns_every_player_wicket():
	var mr := _run(null)
	assert_eq(mr.innings1.wickets, 0, "base_p=1.0 auto → all Player wickets overturned")

func test_scripted_empty_lets_wickets_stand():
	var mr := _run([])
	assert_gt(mr.innings1.wickets, 0, "no scripted reviews → wickets stand")

func test_scripted_one_ball_overturns_only_that_ball():
	var stood := _run([])                      # find a real Player-dismissal ball
	var bid := []
	for b in stood.ball_log_innings1:
		if b["wicket"] and b["is_player"]:
			bid = [b["over"], b["ball_in_over"]]
			break
	assert_false(bid.is_empty(), "the seed must produce a Player dismissal")
	var mr := _run([bid])
	# that exact delivery is now NOT a wicket in the log
	for b in mr.ball_log_innings1:
		if b["over"] == bid[0] and b["ball_in_over"] == bid[1]:
			assert_false(b["wicket"], "scripted review overturned the dismissal")
	assert_lt(mr.innings1.wickets, stood.innings1.wickets, "one fewer wicket")
```

- [ ] **Step 2: Run to verify it fails**

Run the import+suite chain. Expected: `test_auto_null_overturns_every_player_wicket` and `test_scripted_*` FAIL — the gate isn't implemented, so `review_balls` is ignored (scripted-empty still auto-reviews → wickets==0, contradicting `assert_gt`).

- [ ] **Step 3: Implement the gate**

In `scripts/domain/innings_resolver.gd`, the batting-side survive branch currently reads:

```gdscript
		if orig_wicket:
			if player_is_batting and drs_policy != null:
				if runtime.try_review(jokers, true, intent, drs_policy.base_p, balls + 1, rng):
					o = BallOutcome.new(false, 0)
```

Replace the inner `if player_is_batting …` block with the gated version:

```gdscript
		if orig_wicket:
			if player_is_batting and drs_policy != null:
				# DI3 — scripted mode (review_balls non-null): only review the listed
				# [over, ball_in_over] deliveries; auto mode (null) = byte-identical.
				var bio := balls % 6 + 1
				var do_review := drs_policy.review_balls == null or drs_policy.review_balls.has([over, bio])
				if do_review and runtime.try_review(jokers, true, intent, drs_policy.base_p, balls + 1, rng):
					o = BallOutcome.new(false, 0)
```

Leave the `elif (not player_is_batting) and opp_drs_policy != null:` branch and the entire `elif orig_dot:` (claim) branch unchanged — bowling-side stays auto (DI3).

- [ ] **Step 4: Run to verify it passes**

Run the import+suite chain. Expected: the three `_run` tests green, total count climbs, `All tests passed`.

- [ ] **Step 5: Ledger gate — prove default-off byte-identical**

Run the scoring-env probe and confirm it matches the pre-rung value:

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/probe_scoring_env.gd`
Expected: the printed env mean/RR/wkts is **unchanged** vs `main` (≈155 / RR ~8.x / ~6 wkts — the `review_balls == null` path consumes RNG identically). If it moved, STOP — the gate is not default-off.

- [ ] **Step 6: Commit**

```bash
git add scripts/domain/innings_resolver.gd scripts/domain/innings_resolver.gd.uid tests/unit/test_drs_review_balls_seam.gd
git commit -m "Interactive match: scripted batting-side DRS review gate (default-off byte-identical)"
```

---

## Task 3: `MatchSession` — start, result, events, re-sim, prefix stability

**Files:**
- Create: `scripts/domain/match_session.gd`
- Test: `tests/unit/test_match_session.gd`

- [ ] **Step 1: Write the failing test**

Create `tests/unit/test_match_session.gd`:

```gdscript
extends GutTest

# MatchSession — the interactive re-simulation controller (spec §3).

func _session() -> MatchSession:
	var a := Attributes.new()
	a.power = 55.0; a.composure = 45.0; a.attack = 35.0; a.control = 30.0
	var career := CareerResolver.start_career(0)
	var team: Team = career.teams[career.current_team_index]
	var opp: Team = career.opponents_of_current()[0]
	var tour := DifficultyLadder.spec_for(career.current_level(), 0).make_tour()
	# force_player_bats_first = 1 → innings1 is the Player batting (deterministic offers)
	return MatchSession.start(a, team, opp, tour, 20260615, 1)

func test_start_produces_result_and_events():
	var s := _session()
	assert_not_null(s.result(), "a baseline match is simulated")
	assert_gt(s.events().size(), 0, "an event stream is built")

func test_player_bats_first_when_forced():
	var s := _session()
	assert_true(s.result().player_bats_first, "forced bats-first")

func test_decide_boost_leaves_prefix_byte_identical():
	var s := _session()
	var before := s.result().ball_log_innings1.duplicate(true)
	# boost a mid innings over K; balls in overs < K must be byte-identical
	var k := 8
	s.decide_boost_over(k)
	var after := s.result().ball_log_innings1
	for i in range(before.size()):
		if before[i]["over"] < k:
			assert_eq(after[i], before[i], "prefix ball %d unchanged" % i)
		else:
			break
```

- [ ] **Step 2: Run to verify it fails**

Run the import+suite chain. Expected: `Parse Error: Identifier "MatchSession" not declared` (red).

- [ ] **Step 3: Implement `MatchSession` (start + re-sim + prefix-stable boost)**

Create `scripts/domain/match_session.gd`:

```gdscript
class_name MatchSession
extends RefCounted

# The interactive Match controller (spec DI1, Approach C). Holds the match seed +
# the accumulating Player decisions (press_overs / review_balls). Every decision
# re-runs the PURE MatchResolver with rebuilt policies + re-captures the ball-logs,
# producing a fresh event stream the interactive_match scene replays. No live loop,
# no member RNG (a fresh seeded RNG per re-sim) → the prefix you've already watched
# is byte-identical; only the future diverges. Spec §3.

const BOOST_BUDGET := 2   # presses per innings (DI5, strawman)
const REVIEW_BUDGET := 2  # batting-side reviews per innings (DI6)

var _attrs: Attributes
var _team: Team
var _opp: Team
var _tour: TourDistribution
var _tuning: BallTuning
var _itun: InningsTuning
var _seed: int
var _force: int          # force_player_bats_first (-1 toss / 1 / 0)

var _press_overs: Array[int] = []
var _review_balls: Array = []      # [over, ball_in_over] pairs (Player batting innings)

var _result: MatchResult
var _events: Array = []
var _player := Player.new()        # carries attributes for the builder

static func start(attrs: Attributes, team: Team, opp: Team, tour: TourDistribution,
		seed: int, force_player_bats_first: int = -1,
		tuning: BallTuning = null, itun: InningsTuning = null) -> MatchSession:
	var s := MatchSession.new()
	s._attrs = attrs
	s._team = team
	s._opp = opp
	s._tour = tour
	s._seed = seed
	s._force = force_player_bats_first
	s._tuning = tuning if tuning != null else BallTuning.new()
	s._itun = itun if itun != null else InningsTuning.new()
	s._player.attributes = attrs
	s._resim()
	return s

func result() -> MatchResult:
	return _result

func events() -> Array:
	return _events

func player() -> Player:
	return _player

# Re-run the resolver from the seed with the current accumulated policy, then
# rebuild the event stream. Called on start and after every decision.
func _resim() -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = _seed
	var boost := BoostPlan.at(_press_overs)
	var drs := DRSPolicy.new()
	drs.review_balls = _review_balls
	var log1: Array = []
	var log2: Array = []
	_result = MatchResolver.simulate_match_teams(
		_attrs, _team, _opp, _tour, _tuning, _itun, rng,
		null, null, [], null, null, null,
		boost, drs, null, null, null, _force, null, log1, log2)
	_events = MatchViewBuilder.build_events(_result, _player)

# Add a Boost press at 1-based over K, re-sim. (Prefix < K stays byte-identical.)
func decide_boost_over(over: int) -> void:
	if not _press_overs.has(over):
		_press_overs.append(over)
		_resim()
```

- [ ] **Step 4: Run to verify it passes**

Run the import+suite chain. Expected: the three Task-3 tests green, count climbs, `All tests passed`.

- [ ] **Step 5: Commit**

```bash
git add scripts/domain/match_session.gd scripts/domain/match_session.gd.uid tests/unit/test_match_session.gd
git commit -m "Interactive match: MatchSession start + re-sim + prefix-stable boost"
```

---

## Task 4: Boost budgets + offer/next-over helpers

**Files:**
- Modify: `scripts/domain/match_session.gd`
- Test: `tests/unit/test_match_session.gd` (extend)

- [ ] **Step 1: Write the failing test**

Append to `tests/unit/test_match_session.gd`:

```gdscript
func test_boost_changes_score():
	var s := _session()
	var base_total := s.result().innings1.total
	# press boosts on several early overs of the Player's batting innings
	s.decide_boost_over(2); s.decide_boost_over(5)
	assert_ne(s.result().innings1.total, base_total, "boost shifted the batting total")

func test_innings1_is_player_batting():
	var s := _session()
	assert_true(s.player_bats_this(1), "innings1 = Player batting when forced bats-first")
	assert_false(s.player_bats_this(2), "innings2 = Player bowling")

func test_presses_left_decrements_and_caps():
	var s := _session()
	assert_eq(s.presses_left(1), MatchSession.BOOST_BUDGET)
	s.decide_boost_over(2)
	assert_eq(s.presses_left(1), MatchSession.BOOST_BUDGET - 1)

func test_can_boost_respects_budget():
	var s := _session()
	s.decide_boost_over(2); s.decide_boost_over(3)
	assert_eq(s.presses_left(1), 0)
	assert_false(s.can_boost(1), "budget exhausted")
```

- [ ] **Step 2: Run to verify it fails**

Run the import+suite chain. Expected: `Identifier "player_bats_this" not declared` / `presses_left` / `can_boost` — FAIL.

- [ ] **Step 3: Implement budgets + helpers**

Append to `scripts/domain/match_session.gd`:

```gdscript

# Is innings_no (1/2) the Player's batting innings?
func player_bats_this(innings_no: int) -> bool:
	return (innings_no == 1) == _result.player_bats_first

# Presses already made in innings_no's over-range.
func _presses_in(innings_no: int) -> int:
	var lo := 1 if innings_no == 1 else _itun.over_limit + 1
	var hi := _itun.over_limit if innings_no == 1 else _itun.over_limit * 2
	var n := 0
	for o in _press_overs:
		if o >= lo and o <= hi:
			n += 1
	return n

func presses_left(innings_no: int) -> int:
	return maxi(0, BOOST_BUDGET - _presses_in(innings_no))

func can_boost(innings_no: int) -> bool:
	return presses_left(innings_no) > 0
```

Note: boost overs are 1-based *within an innings* (over 1–20 each). The Player presses for the *upcoming* over; the scene computes which over and innings from the cursor and calls `decide_boost_over`. Innings-2 over numbers are offset by `over_limit` so `_press_overs` is unambiguous — but `BoostPlan.presses_on(over)` is checked per-innings with 1-based overs, so the scene passes the *within-innings* over for innings 1 and `over` for innings 2 must map back. To keep this slice simple, the demo/tests press innings-1 overs only via the within-innings number; innings-2 boost is wired in the scene (Task 6) by pressing the within-innings over (the resolver's innings-2 call also uses 1-based overs). The `_presses_in` range split above is a budget bookkeeping convenience; `decide_boost_over` stores the within-innings over for innings 1. (Innings-2 boost budget tracking is handled in Task 6's scene by a separate counter; see Task 6.)

Actually, to avoid ambiguity, keep `decide_boost_over` storing the **within-innings 1-based over** and track budgets with an explicit innings tag. Replace `_press_overs` usage by also recording presses per innings. Simpler: store presses as `[innings_no, over]` pairs and build the BoostPlan per innings. Revise `_resim` boost construction and `decide_boost_over`:

Replace `var _press_overs: Array[int] = []` with:

```gdscript
var _presses: Array = []   # [innings_no, within_innings_over] pairs
```

Replace the boost line in `_resim` with:

```gdscript
	var boost := BoostPlan.new()
	for p in _presses:
		boost.press_overs.append(p[1])   # 1-based within-innings; resolver checks per innings
```

Replace `decide_boost_over` (Task 3) with:

```gdscript
# Add a Boost press at 1-based within-innings over in innings_no, re-sim.
func decide_boost(innings_no: int, over: int) -> void:
	if presses_left(innings_no) <= 0:
		return
	_presses.append([innings_no, over])
	_resim()

# Back-compat helper used by Task-3 tests: boost innings 1.
func decide_boost_over(over: int) -> void:
	decide_boost(1, over)
```

Replace `_presses_in`:

```gdscript
func _presses_in(innings_no: int) -> int:
	var n := 0
	for p in _presses:
		if p[0] == innings_no:
			n += 1
	return n
```

(`BoostPlan.press_overs` is a per-innings 1-based list; both innings share the same numbers 1–20, and the resolver applies them within each innings — so an over in `press_overs` boosts that over in BOTH innings. For this slice that's acceptable: the demo presses distinct overs, and Task 6's scene only enables the button for the current innings. A future slice can scope presses per innings in the resolver if needed — recorded in spec §9.)

- [ ] **Step 4: Run to verify it passes**

Run the import+suite chain. Expected: Task-4 tests + the Task-3 boost test green (`decide_boost_over` still works), count climbs, `All tests passed`.

- [ ] **Step 5: Commit**

```bash
git add scripts/domain/match_session.gd scripts/domain/match_session.gd.uid tests/unit/test_match_session.gd
git commit -m "Interactive match: Boost budgets + per-innings press tracking"
```

---

## Task 5: DRS review — offer detection, decide_review, budgets, prefix stability

**Files:**
- Modify: `scripts/domain/match_session.gd`
- Test: `tests/unit/test_match_session.gd` (extend)

- [ ] **Step 1: Write the failing test**

Append to `tests/unit/test_match_session.gd`:

```gdscript
# Find the event cursor of the Player's first dismissal (a "ball" event, wicket+player_batting).
func _first_dismissal_cursor(s: MatchSession) -> int:
	var ev := s.events()
	for i in range(ev.size()):
		var e: Dictionary = ev[i]
		if e["type"] == "ball" and e.get("player_batting", false) and e["wicket"]:
			return i
	return -1

func test_review_offer_fires_on_player_dismissal():
	var s := _session()
	var c := _first_dismissal_cursor(s)
	assert_gt(c, -1, "the seed produces a Player dismissal")
	var offer := s.review_offer(c)
	assert_false(offer.is_empty(), "an offer is returned at the dismissal cursor")
	assert_true(offer.has("ball_id"), "offer carries the ball_id")

func test_decide_review_overturn_or_burn():
	var s := _session()
	var c := _first_dismissal_cursor(s)
	var offer := s.review_offer(c)
	var bid: Array = offer["ball_id"]
	var reviews_before := s.reviews_left()
	s.decide_review(bid)
	# the dismissal is either overturned (survives) or stands with a review burned
	var still_out := false
	for b in s.result().ball_log_innings1:
		if b["over"] == bid[0] and b["ball_in_over"] == bid[1]:
			still_out = b["wicket"]
	if still_out:
		assert_eq(s.reviews_left(), reviews_before - 1, "failed review burned one")
	else:
		assert_eq(s.reviews_left(), reviews_before, "successful review retained")

func test_review_offer_stops_when_no_reviews_left():
	var s := _session()
	# exhaust reviews by scripting two failures is seed-dependent; instead assert the
	# budget read-out gates the offer: force reviews_left to 0 via scripting both.
	# Simpler: when reviews_left()==0 no offer is returned.
	s._reviews_used = MatchSession.REVIEW_BUDGET   # test-only direct set
	assert_eq(s.reviews_left(), 0)
	var c := _first_dismissal_cursor(s)
	if c > -1:
		assert_true(s.review_offer(c).is_empty(), "no offer with 0 reviews left")
```

- [ ] **Step 2: Run to verify it fails**

Run the import+suite chain. Expected: `Identifier "review_offer" / "decide_review" / "reviews_left" / "_reviews_used" not declared` — FAIL.

- [ ] **Step 3: Implement review offer + decide + budget**

Append to `scripts/domain/match_session.gd`:

```gdscript

var _reviews_used := 0   # batting-side reviews the Player has committed this match

func reviews_left() -> int:
	return maxi(0, REVIEW_BUDGET - _reviews_used)

# Given the playback cursor (index of the event about to be shown), is it a Player
# dismissal the Player can review? Returns {ball_id:[over,ball], over, ball} or {}.
func review_offer(cursor: int) -> Dictionary:
	if reviews_left() <= 0:
		return {}
	if cursor < 0 or cursor >= _events.size():
		return {}
	var e: Dictionary = _events[cursor]
	if e["type"] == "ball" and e.get("player_batting", false) and e["wicket"]:
		return {"ball_id": [e["over"], e["ball"]], "over": e["over"], "ball": e["ball"]}
	return {}

# Commit a review of the dismissal at ball_id [over, ball_in_over], re-sim.
func decide_review(ball_id: Array) -> void:
	if reviews_left() <= 0:
		return
	if not _review_balls.has(ball_id):
		_review_balls.append(ball_id)
	_reviews_used += 1
	_resim()
```

Note on `_reviews_used`: it counts *committed* reviews (a review the Player chose to make), capping offers at `REVIEW_BUDGET`. The resolver's own `reviews_left` (success-retains, failure-burns) governs whether the scripted review can fire at all — if the resolver has already exhausted its reviews on earlier scripted balls, a later scripted review simply no-ops in `try_review` (returns false), the wicket stands, and `_reviews_used` having incremented is the conservative UX cap. For this slice that double-cap is acceptable and safe.

- [ ] **Step 4: Run to verify it passes**

Run the import+suite chain. Expected: Task-5 tests green, count climbs, `All tests passed`.

- [ ] **Step 5: Prefix-stability for review**

Append to `tests/unit/test_match_session.gd`:

```gdscript
func test_decide_review_leaves_prefix_byte_identical():
	var s := _session()
	var c := _first_dismissal_cursor(s)
	var offer := s.review_offer(c)
	var bid: Array = offer["ball_id"]
	var before := s.result().ball_log_innings1.duplicate(true)
	s.decide_review(bid)
	var after := s.result().ball_log_innings1
	for i in range(before.size()):
		var b = before[i]
		# balls strictly before the reviewed delivery must be unchanged
		if b["over"] < bid[0] or (b["over"] == bid[0] and b["ball_in_over"] < bid[1]):
			assert_eq(after[i], b, "prefix ball %d unchanged" % i)
		else:
			break
```

Run the import+suite chain. Expected: green.

- [ ] **Step 6: Commit**

```bash
git add scripts/domain/match_session.gd scripts/domain/match_session.gd.uid tests/unit/test_match_session.gd
git commit -m "Interactive match: DRS review offer + decide + budget + prefix stability"
```

---

## Task 6: `interactive_match` scene (controls + Boost button + DRS overlay)

**Files:**
- Create: `scenes/interactive_match/interactive_match.tscn`
- Create: `scenes/interactive_match/interactive_match.gd`
- Test: `tests/unit/test_interactive_match_scene.gd`

The scene mirrors `scenes/match_view/match_view.gd` (header / scoreboard / target / current line / feed + play/pause/step/speed/back), adding (a) a **Boost** button enabled while the current innings has budget, and (b) a **DRS overlay** Panel (hidden by default) shown when `review_offer` fires at the cursor.

- [ ] **Step 1: Write the failing test**

Create `tests/unit/test_interactive_match_scene.gd`:

```gdscript
extends GutTest

# interactive_match scene — overlay appears on a Player-dismissal cursor; Boost button.

var _scene

func _make_session() -> MatchSession:
	var a := Attributes.new()
	a.power = 55.0; a.composure = 45.0; a.attack = 35.0; a.control = 30.0
	var career := CareerResolver.start_career(0)
	var team: Team = career.teams[career.current_team_index]
	var opp: Team = career.opponents_of_current()[0]
	var tour := DifficultyLadder.spec_for(career.current_level(), 0).make_tour()
	return MatchSession.start(a, team, opp, tour, 20260615, 1)

func before_each():
	_scene = load("res://scenes/interactive_match/interactive_match.tscn").instantiate()
	add_child_autofree(_scene)
	await get_tree().process_frame

func test_boots_and_renders():
	var s := _make_session()
	_scene.set_session(s, "Karoo Kings", "Opponent")
	_scene.boot()
	assert_gt(_scene.event_count(), 0, "event stream loaded")

func test_overlay_appears_at_a_dismissal():
	var s := _make_session()
	# find a dismissal cursor
	var ev := s.events()
	var c := -1
	for i in range(ev.size()):
		if ev[i]["type"] == "ball" and ev[i].get("player_batting", false) and ev[i]["wicket"]:
			c = i; break
	assert_gt(c, -1, "dismissal exists")
	_scene.set_session(s, "Karoo Kings", "Opponent")
	_scene.boot()
	_scene.seek_to(c)               # advance cursor to just before the dismissal event
	assert_true(_scene.overlay_visible(), "DRS overlay shown at a dismissal")

func test_boost_button_enabled_with_budget():
	var s := _make_session()
	_scene.set_session(s, "Karoo Kings", "Opponent")
	_scene.boot()
	assert_true(_scene.boost_enabled(), "boost available at start")
```

- [ ] **Step 2: Run to verify it fails**

Run the import+suite chain. Expected: the scene `.tscn` doesn't exist → load fails / `set_session` not declared — FAIL.

- [ ] **Step 3: Create the scene tree**

Create `scenes/interactive_match/interactive_match.tscn` (a `Control` root named `InteractiveMatch` with script `interactive_match.gd`, mirroring `match_view.tscn`). Build it by copying `scenes/match_view/match_view.tscn` structure and adding the Boost button + overlay. Concretely, the node tree:

```
InteractiveMatch (Control, script=interactive_match.gd)
└─ Root (VBoxContainer, anchors full rect)
   ├─ Header (Label)
   ├─ Scoreboard (Label)
   ├─ Target (Label)
   ├─ CurrentLine (Label)
   ├─ FeedBox (VBoxContainer)
   └─ Controls (HBoxContainer)
      ├─ StepBack (Button, text="◀")
      ├─ PlayPause (Button, text="Play")
      ├─ StepFwd (Button, text="▶")
      ├─ Speed (Button, text="1x")
      ├─ Boost (Button, text="BOOST")
      └─ Back (Button, text="Back")
   Tick (Timer)
   Overlay (Panel, visible=false)
   └─ OverlayBox (VBoxContainer)
      ├─ Prompt (Label)
      ├─ ReviewYes (Button, text="Review")
      └─ ReviewNo (Button, text="No")
```

If editing `.tscn` text by hand is error-prone, duplicate `scenes/match_view/match_view.tscn` to the new path, rename the root, point `script` at the new `.gd`, then add the `Boost` button under `Controls` and the `Overlay`/`OverlayBox`/`Prompt`/`ReviewYes`/`ReviewNo` nodes. Verify by loading in the editor (eyeball — per CLAUDE.md, scene visibility can't be unit-tested).

- [ ] **Step 4: Create the scene script**

Create `scenes/interactive_match/interactive_match.gd`:

```gdscript
extends Control

# Interactive Match screen (spec §3). Replays a MatchSession's event stream with
# watch controls, a press-anytime Boost button (DI2), and a forced DRS overlay on
# Player dismissals (DI3). boot() is explicit so tests inject without a sim.

signal back

const SPEEDS := [1.0, 2.0, 4.0]
const BASE_TICK := 0.6

var _session: MatchSession
var _team_name := ""
var _opp_name := ""
var _cursor := 0
var _event_count := 0
var _speed_idx := 0
var _playing := false
var _pending_review := {}   # the offer currently shown in the overlay

func _ready() -> void:
	$Root/Controls/StepBack.pressed.connect(func(): pause(); step(-1))
	$Root/Controls/StepFwd.pressed.connect(func(): pause(); step(1))
	$Root/Controls/PlayPause.pressed.connect(_toggle_play)
	$Root/Controls/Speed.pressed.connect(_cycle_speed)
	$Root/Controls/Boost.pressed.connect(_on_boost)
	$Root/Controls/Back.pressed.connect(func(): back.emit())
	$Overlay/OverlayBox/ReviewYes.pressed.connect(_on_review_yes)
	$Overlay/OverlayBox/ReviewNo.pressed.connect(_on_review_no)
	$Tick.timeout.connect(_on_tick)
	$Tick.wait_time = BASE_TICK
	$Overlay.visible = false

func set_session(s: MatchSession, team_name: String, opp_name: String) -> void:
	_session = s
	_team_name = team_name
	_opp_name = opp_name

func boot() -> void:
	if _session == null:
		return
	_cursor = 0
	_event_count = _session.events().size()
	_render()

func event_count() -> int:
	return _event_count

func overlay_visible() -> bool:
	return $Overlay.visible

func boost_enabled() -> bool:
	return not $Root/Controls/Boost.disabled

# Which innings is at the current cursor (for boost routing / budget).
func _innings_at_cursor() -> int:
	for k in range(_cursor, -1, -1):
		if k < _session.events().size():
			var e: Dictionary = _session.events()[k]
			if e.has("innings"):
				return e["innings"]
	return 1

# 1-based within-innings over at the cursor (best effort; for boosting the NEXT over).
func _over_at_cursor() -> int:
	for k in range(_cursor, -1, -1):
		if k < _session.events().size():
			var e: Dictionary = _session.events()[k]
			if e.has("over"):
				return e["over"]
	return 0

func step(delta: int) -> void:
	_cursor = clampi(_cursor + delta, 0, _event_count)
	# pause for a DRS offer at the cursor (the event about to be shown)
	var offer := _session.review_offer(_cursor)
	if not offer.is_empty() and delta > 0:
		_pending_review = offer
		_show_overlay(offer)
		pause()
		return
	_render()
	if _cursor >= _event_count:
		pause()

func seek_to(cursor: int) -> void:
	_cursor = clampi(cursor, 0, _event_count)
	var offer := _session.review_offer(_cursor)
	if not offer.is_empty():
		_pending_review = offer
		_show_overlay(offer)
	else:
		_render()

func play() -> void:
	if _cursor >= _event_count: return
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

func _on_boost() -> void:
	var inn := _innings_at_cursor()
	if not _session.can_boost(inn): return
	var next_over := mini(_over_at_cursor() + 1, 20)
	_session.decide_boost(inn, next_over)
	_event_count = _session.events().size()
	_render()

func _show_overlay(offer: Dictionary) -> void:
	$Overlay/OverlayBox/Prompt.text = "You're given out — Review? (%d left)" % _session.reviews_left()
	$Overlay.visible = true

func _on_review_yes() -> void:
	$Overlay.visible = false
	if not _pending_review.is_empty():
		_session.decide_review(_pending_review["ball_id"])
		_event_count = _session.events().size()
	_pending_review = {}
	_render()       # re-render the (possibly overturned) cursor event

func _on_review_no() -> void:
	$Overlay.visible = false
	_pending_review = {}
	_render()

func _render() -> void:
	var v := MatchViewBuilder.build(_session.result(), _session.player(), _cursor)
	$Root/Header.text = "%s  v  %s" % [_team_name, _opp_name]
	$Root/Scoreboard.text = "%s   %s" % [v.innings_label, v.batting_score]
	$Root/Target.text = v.target_text
	$Root/CurrentLine.text = (v.result_text if v.finished else v.current_line)
	var inn := _innings_at_cursor()
	$Root/Controls/Boost.disabled = not _session.can_boost(inn)
	var box: VBoxContainer = $Root/FeedBox
	for c in box.get_children():
		c.queue_free()
	for line in v.feed:
		var l := Label.new()
		l.text = line
		box.add_child(l)
```

- [ ] **Step 5: Run to verify it passes**

Run the import+suite chain. Expected: the three scene tests green, count climbs, `All tests passed`. (If `seek_to`/overlay timing needs a frame, the test already awaits `process_frame` in `before_each`.)

- [ ] **Step 6: Eyeball the scene in the editor**

Open `scenes/interactive_match/interactive_match.tscn` in the Godot editor; confirm the Boost button + overlay nodes exist and the layout isn't collapsed (per CLAUDE.md, unit tests can't catch invisibility). Quit the editor (⌘Q) before any further headless run.

- [ ] **Step 7: Commit**

```bash
git add scenes/interactive_match/ tests/unit/test_interactive_match_scene.gd
git commit -m "Interactive match: interactive_match scene (Boost button + DRS overlay)"
```

---

## Task 7: Preview harness + screenshot + spec §10 findings

**Files:**
- Create: `tools/preview_interactive_match.gd`
- Modify: `docs/superpowers/specs/2026-06-15-interactive-match-design.md` (§10)

- [ ] **Step 1: Write the preview harness**

Create `tools/preview_interactive_match.gd` (mirrors `tools/preview_match_view.gd`: render WITH a window, inject in `_process` frame 2 because `@onready` isn't resolved in a `-s` script's `_initialize`):

```gdscript
extends SceneTree

# Renders the interactive_match scene to a PNG, scripting a Boost + a DRS review so
# the shot shows a real consequence. Run WITH rendering (no --headless):
#   /Applications/Godot.app/Contents/MacOS/Godot --path . -s tools/preview_interactive_match.gd

const OUT := "res://docs/mockups/interactive-match-built-v1.png"

var _scene
var _session
var _team_name := ""
var _frames := 0
var _injected := false

func _initialize() -> void:
	var a := Attributes.new()
	a.power = 55.0; a.composure = 45.0; a.attack = 35.0; a.control = 30.0
	var career := CareerResolver.start_career(0)
	var team: Team = career.teams[career.current_team_index]
	var opp: Team = career.opponents_of_current()[0]
	var tour := DifficultyLadder.spec_for(career.current_level(), 0).make_tour()
	_session = MatchSession.start(a, team, opp, tour, 20260615, 1)
	# script a Boost so the shot shows a boosted over in the feed
	_session.decide_boost(1, 5)
	_team_name = team.team_name
	get_root().size = Vector2i(390, 844)
	_scene = load("res://scenes/interactive_match/interactive_match.tscn").instantiate()
	get_root().add_child(_scene)

func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 2 and not _injected:
		_scene.set_session(_session, _team_name, "Opponent")
		_scene.boot()
		# advance to the first Player dismissal so the DRS overlay is on screen
		var ev: Array = _session.events()
		var c := -1
		for i in range(ev.size()):
			if ev[i]["type"] == "ball" and ev[i].get("player_batting", false) and ev[i]["wicket"]:
				c = i; break
		if c > -1:
			_scene.seek_to(c)
		else:
			for i in range(14): _scene.step(1)
		_injected = true
	if _frames >= 8:
		var img := get_root().get_viewport().get_texture().get_image()
		img.save_png(OUT)
		print("PREVIEW_SAVED ", OUT)
		quit()
		return true
	return false
```

- [ ] **Step 2: Render the screenshot**

Quit the Godot editor first. Run:
`/Applications/Godot.app/Contents/MacOS/Godot --path . -s tools/preview_interactive_match.gd`
Expected: `PREVIEW_SAVED res://docs/mockups/interactive-match-built-v1.png`. Open the PNG and confirm the header/scoreboard render and the DRS overlay (or a boosted feed) is visible.

- [ ] **Step 3: Fill spec §10 findings**

Replace the `_TBD during implementation._` in §10 of the spec with concrete numbers from the build: final test count (past 591), the probe env value (unchanged, proving default-off), how many events the demo match produced, and any gotcha hit (e.g. overlay frame timing). Label the screenshot's scripted decisions loudly (Boost @ over 5, the reviewed dismissal) per the showcase-vs-canonical memory.

- [ ] **Step 4: Run the full suite once more (final green)**

Run the import+suite chain. Expected: `All tests passed`, count climbed from 591.

- [ ] **Step 5: Commit**

```bash
git add tools/preview_interactive_match.gd tools/preview_interactive_match.gd.uid docs/mockups/interactive-match-built-v1.png docs/superpowers/specs/2026-06-15-interactive-match-design.md
git commit -m "Interactive match: preview harness + screenshot + spec §10 findings"
```

---

## Self-Review (done at write time)

- **Spec coverage:** DI1 (re-sim) = Tasks 3–5; DI2 (Boost both innings, button) = Tasks 4 + 6; DI3 (batting-side DRS gate, default-off) = Tasks 1–2 + 5; DI4 (opp auto) = unchanged in `_resim` (opp plans null); DI5/DI6 (budgets) = Tasks 4–5; DI7 (prefix stability) = Tasks 3 + 5; DI8 (demo entry) = Task 7. §7 testing = the test files across tasks. §8 deliverable = Task 7.
- **Placeholder scan:** no TBD/TODO left except spec §10 (filled in Task 7, by design).
- **Type consistency:** `MatchSession.start(attrs, team, opp, tour, seed, force, tuning?, itun?)`, `decide_boost(innings, over)`, `decide_boost_over(over)`, `decide_review(ball_id)`, `review_offer(cursor)`, `presses_left/can_boost(innings)`, `reviews_left()`, `player_bats_this(innings)`, `result()/events()/player()` — used consistently across Tasks 3–7. Scene API `set_session/boot/event_count/overlay_visible/boost_enabled/seek_to/step` consistent across Task 6 + 7. `DRSPolicy.review_balls` consistent Tasks 1/2/3.
- **Known wrinkle recorded:** `BoostPlan.press_overs` is per-innings 1-based and shared across both innings (an over in the list boosts that over in both innings). Acceptable this slice (demo presses distinct overs; scene enables the button per current innings); a future slice can scope presses per innings in the resolver — noted for spec §9.
