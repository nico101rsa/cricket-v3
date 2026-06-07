# Full-Match Sim Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build `MatchResolver.simulate_match()` — call the existing `InningsResolver.simulate_innings()` twice (Player's team + opposition), run a chase, and decide a cricket-standard result — returning a `MatchResult`.

**Architecture:** Pure domain logic, no scene tree. One new result holder (`MatchResult`), one new resolver (`MatchResolver`), and two small backward-compatible extensions to the existing `InningsResolver.simulate_innings()` (optional statted Player; optional chase target). The result-decision logic is extracted into a pure `_decide_result()` helper so outcomes/margins (including the hard-to-seed tie branch) are unit-testable on constructed innings, with no sim flakiness. Rung 3 of the bottom-up match sim (ball → innings → **match** → Intent/KMs).

**Tech Stack:** Godot 4.6.3, GDScript, GUT 9.6. Spec: `docs/superpowers/specs/2026-06-07-full-match-design.md`.

---

## Project conventions (read before starting)

From project `CLAUDE.md` — these bite every fresh worker:

- **Godot binary is not on PATH.** Use `/Applications/Godot.app/Contents/MacOS/Godot`.
- **After adding any new script, run `--import` once before running tests** (registers `class_name`s):
  `/Applications/Godot.app/Contents/MacOS/Godot --headless --import --path .`
- **Run the suite (headless):**
  `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`
- **The GUT `-gtest=` flag does NOT filter here** — every run executes the whole `tests/unit` suite. So a red→green loop can't lean on per-file runs:
  - **Judge "red"** by a `SCRIPT ERROR: Parse Error: Identifier "X" not declared` for the not-yet-created `class_name` (GUT logs it and skips that file), **not** by a failing assertion.
  - **Judge "green"** by the total test count climbing and the `All tests passed` line.
- **Never run headless Godot while the editor is open** (import deadlock). **Only one Godot process at a time** — chain `--import && <test>` in a single command.
- **Indentation is tabs** in `.gd` files. **Commit `*.gd.uid` files** (Godot writes them next to each script).
- **iCloud `" 2"` conflict files** can break the run — if GUT suddenly fails to load, clean with:
  `find . \( -name "* 2" -o -name "* 2.*" \) -not -path "./.git/*" -delete && rm -rf .godot` then re-import.
- **`null` for a typed `Object` param is allowed** in GDScript — `player_attrs: Attributes` accepts `null` (used for the opposition innings).

**Standard verify command** (used in every "run tests" step below — import then run, gate on the pass line):

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --import --path . \
&& /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit \
| tee /tmp/gut.txt; grep -q "All tests passed" /tmp/gut.txt && echo "GREEN" || echo "NOT GREEN"
```

Branch is already `full-match-build`. Baseline before starting: **115 tests green** (the spec commit added no code).

---

## File Structure

- **Create** `scripts/data/match_result.gd` — `class_name MatchResult`. `RefCounted` result holder: both innings, the `Outcome` enum, margin fields, and `player_won()` / `is_tie()` / `margin_text()` accessors.
- **Create** `scripts/domain/match_resolver.gd` — `class_name MatchResolver`. Static functions: `_decide_result()` (pure result/margin logic) and `simulate_match()` (the two-innings wrapper).
- **Modify** `scripts/domain/innings_resolver.gd` — extend `_build_batters()` (optional Player) and `simulate_innings()` (optional `target` chase param). Backward-compatible.
- **Create** `tests/unit/test_match_result.gd`
- **Create** `tests/unit/test_match_resolver.gd`
- **Modify** `tests/unit/test_innings_resolver.gd` — add the optional-Player + chase tests (reusing existing `_attrs` / `_make_rng` helpers).

Existing files referenced (do not modify): `scripts/data/attributes.gd` (`Attributes`: `power/composure/attack/control` ints), `scripts/data/innings_result.gd` (`InningsResult.new(total, wickets, balls, fall, batters)`, `.player_line()`), `scripts/data/ball_tuning.gd` (`BallTuning`), `scripts/data/innings_tuning.gd` (`InningsTuning.over_limit`).

---

## Task 1: `MatchResult` holder

The result of one match: both innings, the outcome from the Player's perspective, the winning margin, and display accessors. No logic beyond the accessors — the decision logic lives in `MatchResolver` (Task 3).

**Files:**
- Create: `scripts/data/match_result.gd`
- Test: `tests/unit/test_match_result.gd`

- [ ] **Step 1: Write the failing test**

Create `tests/unit/test_match_result.gd`:

```gdscript
extends GutTest

func _result(outcome: int, runs: int, wkts: int, balls_left: int) -> MatchResult:
	var r := MatchResult.new()
	r.innings1 = InningsResult.new(150, 8, 120, [], [])
	r.innings2 = InningsResult.new(140, 6, 120, [], [])
	r.player_bats_first = true
	r.outcome = outcome
	r.margin_runs = runs
	r.margin_wickets = wkts
	r.balls_remaining = balls_left
	return r

func test_holds_fields() -> void:
	var r := _result(MatchResult.Outcome.PLAYER_WIN, 10, 0, 0)
	assert_eq(r.innings1.total, 150, "innings1 stored")
	assert_eq(r.innings2.total, 140, "innings2 stored")
	assert_true(r.player_bats_first, "bats-first flag stored")
	assert_eq(r.outcome, MatchResult.Outcome.PLAYER_WIN, "outcome stored")
	assert_eq(r.margin_runs, 10, "margin_runs stored")

func test_player_won_true_on_player_win() -> void:
	assert_true(_result(MatchResult.Outcome.PLAYER_WIN, 10, 0, 0).player_won(), "PLAYER_WIN -> player_won")
	assert_false(_result(MatchResult.Outcome.OPPONENT_WIN, 10, 0, 0).player_won(), "OPPONENT_WIN -> not player_won")
	assert_false(_result(MatchResult.Outcome.TIE, 0, 0, 0).player_won(), "TIE -> not player_won")

func test_is_tie_true_on_tie() -> void:
	assert_true(_result(MatchResult.Outcome.TIE, 0, 0, 0).is_tie(), "TIE -> is_tie")
	assert_false(_result(MatchResult.Outcome.PLAYER_WIN, 10, 0, 0).is_tie(), "win -> not tie")

func test_margin_text_runs() -> void:
	var r := _result(MatchResult.Outcome.PLAYER_WIN, 14, 0, 0)
	assert_eq(r.margin_text(), "won by 14 runs", "runs-margin text")

func test_margin_text_wickets() -> void:
	var r := _result(MatchResult.Outcome.PLAYER_WIN, 0, 6, 8)
	assert_eq(r.margin_text(), "won by 6 wickets (8 balls left)", "wickets-margin text")

func test_margin_text_tie() -> void:
	var r := _result(MatchResult.Outcome.TIE, 0, 0, 0)
	assert_eq(r.margin_text(), "match tied", "tie text")
```

- [ ] **Step 2: Run tests to verify red**

Run the standard verify command. Expected: `SCRIPT ERROR: Parse Error: Identifier "MatchResult" not declared` for `test_match_result.gd`, output `NOT GREEN`.

- [ ] **Step 3: Write minimal implementation**

Create `scripts/data/match_result.gd` (tabs for indent):

```gdscript
class_name MatchResult
extends RefCounted

# Outcome of one full match, from the Player's perspective. Decision logic lives
# in MatchResolver; this is a plain holder + display accessors. Spec §6.

enum Outcome { PLAYER_WIN, OPPONENT_WIN, TIE }

var innings1: InningsResult        # whoever batted first
var innings2: InningsResult        # whoever batted second (the chase)
var player_bats_first: bool = true
var outcome: int = Outcome.TIE
var margin_runs: int = 0           # set when a side wins batting first
var margin_wickets: int = 0        # set when a side wins chasing
var balls_remaining: int = 0       # set when a side wins chasing

func player_won() -> bool:
	return outcome == Outcome.PLAYER_WIN

func is_tie() -> bool:
	return outcome == Outcome.TIE

# Neutral winning-margin phrasing for the Result screen ("won by ..." / "match tied").
func margin_text() -> String:
	if outcome == Outcome.TIE:
		return "match tied"
	if margin_runs > 0:
		return "won by %d runs" % margin_runs
	return "won by %d wickets (%d balls left)" % [margin_wickets, balls_remaining]
```

- [ ] **Step 4: Run tests to verify green**

Run the standard verify command. Expected: `All tests passed`, output `GREEN`, total count = **121** (115 + 6).

- [ ] **Step 5: Commit**

```bash
git add scripts/data/match_result.gd scripts/data/match_result.gd.uid tests/unit/test_match_result.gd
git commit -m "Add MatchResult holder with outcome + margin_text (full match, task 1)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 2: Extend `simulate_innings()` — optional Player + chase target

Two backward-compatible extensions so the same resolver serves both innings: the opposition innings has **no statted Player** (`player_attrs = null` → all 11 derived), and the chasing innings stops the instant a `target` is reached.

**Files:**
- Modify: `scripts/domain/innings_resolver.gd` (`_build_batters` + `simulate_innings`)
- Modify: `tests/unit/test_innings_resolver.gd` (append tests; reuses existing `_attrs` / `_make_rng`)

- [ ] **Step 1: Write the failing tests**

Append to `tests/unit/test_innings_resolver.gd`:

```gdscript
func test_null_player_builds_all_derived() -> void:
	var r := InningsResolver.simulate_innings(null, 6, 5, 5, tuning, itun, _make_rng(7))
	assert_eq(r.batters.size(), 11, "still an 11-strong order")
	assert_eq(r.player_line(), {}, "no statted Player -> empty player line")
	for b in r.batters:
		assert_false(b["is_player"], "no batter flagged as the Player")
	assert_lte(r.balls, 120, "terminates within 120 balls")
	assert_lte(r.wickets, 10, "never more than 10 wickets")

func test_default_target_matches_explicit_zero() -> void:
	# Backward compat: the new trailing target defaults to 0 (no chase) and must
	# reproduce the rung-2 behaviour exactly.
	var a := _attrs(5, 5, 5, 5)
	var r1 := InningsResolver.simulate_innings(a, 5, 5, 5, tuning, itun, _make_rng(99))
	var r2 := InningsResolver.simulate_innings(a, 5, 5, 5, tuning, itun, _make_rng(99), 0)
	assert_eq(r1.total, r2.total, "total unchanged by explicit target=0")
	assert_eq(r1.wickets, r2.wickets, "wickets unchanged")
	assert_eq(r1.balls, r2.balls, "balls unchanged")

func test_chase_stops_when_target_reached() -> void:
	# A tiny target must be chased down well before 120 balls and without losing
	# all 10 wickets (even contest averages ~141, so target 10 falls quickly).
	var a := _attrs(5, 5, 5, 5)
	var saw_early := false
	for sv in range(1, 40):
		var r := InningsResolver.simulate_innings(a, 5, 5, 5, tuning, itun, _make_rng(sv), 10)
		if r.total >= 10:
			assert_lt(r.balls, 120, "reaching a tiny target stops the chase early (seed %d)" % sv)
			assert_lt(r.wickets, 10, "a chased-down target isn't an all-out (seed %d)" % sv)
			saw_early = true
	assert_true(saw_early, "a tiny target should be chased down in some seeds")
```

- [ ] **Step 2: Run tests to verify red**

Run the standard verify command. The new tests fail at parse/runtime: `simulate_innings` does not yet accept a 0-or-1-arg `null` player path nor an 8th `target` arg. Expected `NOT GREEN` (a too-few/too-many-arguments error or assertion failure on the new tests).

- [ ] **Step 3: Write minimal implementation**

In `scripts/domain/innings_resolver.gd`, **replace** the existing `_build_batters` function with this version (only change: handle `player_attrs == null`):

```gdscript
# Build the 11-strong batting order. With a statted Player (player_attrs != null),
# the Player bats at their build-driven position; every other slot is a derived
# partner scaled by the tail curve. With player_attrs == null (opposition innings),
# all 11 are derived.
static func _build_batters(player_attrs: Attributes, partner_batting: int, itun: InningsTuning) -> Array:
	var ppos := -1
	if player_attrs != null:
		ppos = player_position(player_attrs, itun)
	var batters: Array = []
	for order in range(1, 12):  # positions 1..11
		if order == ppos:
			batters.append({
				"position": order, "is_player": true,
				"power": player_attrs.power, "composure": player_attrs.composure,
				"runs": 0, "balls": 0, "out": false,
			})
		else:
			var p := maxi(1, roundi(partner_batting * partner_factor(order, itun)))
			batters.append({
				"position": order, "is_player": false,
				"power": p, "composure": p,
				"runs": 0, "balls": 0, "out": false,
			})
	return batters
```

Then **replace** the existing `simulate_innings` function with this version (changes: new trailing `target` param; chase stop added to the `while` condition):

```gdscript
# Simulate one innings. Deterministic given rng (resolve_ball owns the draw order).
# player_attrs may be null (opposition innings -> all derived). target > 0 adds a
# chase stop: the innings ends the instant total >= target. target == 0 = no chase.
static func simulate_innings(
		player_attrs: Attributes,
		partner_batting: int,
		opp_attack: int,
		opp_control: int,
		tuning: BallTuning,
		itun: InningsTuning,
		rng: RandomNumberGenerator,
		target: int = 0
) -> InningsResult:
	var batters := _build_batters(player_attrs, partner_batting, itun)
	var max_balls := itun.over_limit * 6
	var striker := 0
	var nonstriker := 1
	var next_in := 2
	var wickets := 0
	var balls := 0
	var total := 0
	var fall: Array = []

	while balls < max_balls and wickets < 10 and (target == 0 or total < target):
		var s: Dictionary = batters[striker]
		var o := BallResolver.resolve_ball(
			s["power"], s["composure"], opp_attack, opp_control,
			BallResolver.Intent.BALANCED, tuning, rng)
		balls += 1
		s["balls"] += 1
		if o.wicket:
			s["out"] = true
			wickets += 1
			fall.append({"wicket": wickets, "score": total, "batter": s["position"], "ball": balls})
			if wickets >= 10:
				break
			striker = next_in
			next_in += 1
		else:
			s["runs"] += o.runs
			total += o.runs
			if o.runs % 2 == 1:
				var tmp := striker
				striker = nonstriker
				nonstriker = tmp
		# end of over: swap strike (skip if the innings just ended)
		if balls % 6 == 0 and wickets < 10:
			var tmp2 := striker
			striker = nonstriker
			nonstriker = tmp2

	return InningsResult.new(total, wickets, balls, fall, batters)
```

- [ ] **Step 4: Run tests to verify green**

Run the standard verify command. Expected: `All tests passed`, `GREEN`, total count = **124** (121 + 3). The existing rung-2 innings tests must remain green (backward compatibility).

- [ ] **Step 5: Commit**

```bash
git add scripts/domain/innings_resolver.gd scripts/domain/innings_resolver.gd.uid tests/unit/test_innings_resolver.gd
git commit -m "Extend simulate_innings: optional Player + chase target (full match, task 2)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 3: `MatchResolver._decide_result()` — pure result/margin logic

The decision rule extracted as a pure function so all three outcomes (including the tie branch, which is hard to produce from a live seed) are testable on constructed innings.

**Files:**
- Create: `scripts/domain/match_resolver.gd`
- Test: `tests/unit/test_match_resolver.gd`

- [ ] **Step 1: Write the failing test**

Create `tests/unit/test_match_resolver.gd`:

```gdscript
extends GutTest

func _innings(total: int, wkts: int, balls: int) -> InningsResult:
	return InningsResult.new(total, wkts, balls, [], [])

func test_decide_win_by_runs() -> void:
	# Player bats first (innings1), defends 150 vs 140 -> Player wins by 10 runs.
	var r := MatchResolver._decide_result(_innings(150, 8, 120), _innings(140, 9, 120), true, 120)
	assert_eq(r.outcome, MatchResult.Outcome.PLAYER_WIN, "first-batting Player defends -> player win")
	assert_eq(r.margin_runs, 10, "won by total1 - total2 runs")
	assert_eq(r.margin_wickets, 0, "no wickets margin on a runs win")

func test_decide_win_by_wickets() -> void:
	# Player bats second (innings2), chases 141 with 4 down in 112 balls -> wins by 6, 8 left.
	var r := MatchResolver._decide_result(_innings(140, 10, 120), _innings(141, 4, 112), false, 120)
	assert_eq(r.outcome, MatchResult.Outcome.PLAYER_WIN, "chasing Player passes target -> player win")
	assert_eq(r.margin_wickets, 6, "won by 10 - wkts2 wickets")
	assert_eq(r.balls_remaining, 8, "balls_remaining = max_balls - balls2")
	assert_eq(r.margin_runs, 0, "no runs margin on a wickets win")

func test_decide_tie() -> void:
	var r := MatchResolver._decide_result(_innings(150, 7, 120), _innings(150, 10, 120), true, 120)
	assert_eq(r.outcome, MatchResult.Outcome.TIE, "equal totals -> tie")
	assert_true(r.is_tie(), "is_tie convenience true")

func test_decide_perspective_opponent_win() -> void:
	# Player bats second; opposition batted first (innings1) and defends 150 vs 140
	# -> the first-batting side is the OPPONENT, so it's an opponent win.
	var r := MatchResolver._decide_result(_innings(150, 8, 120), _innings(140, 9, 120), false, 120)
	assert_eq(r.outcome, MatchResult.Outcome.OPPONENT_WIN, "opponent defended first -> opponent win")
	assert_eq(r.margin_runs, 10, "margin still 10 runs (perspective only changes the winner)")
```

- [ ] **Step 2: Run tests to verify red**

Run the standard verify command. Expected: `Parse Error: Identifier "MatchResolver" not declared` for `test_match_resolver.gd`, `NOT GREEN`.

- [ ] **Step 3: Write minimal implementation**

Create `scripts/domain/match_resolver.gd` (tabs):

```gdscript
class_name MatchResolver
extends RefCounted

# Pure resolution of one T20 match: two innings + a chase + a result.
# See spec 2026-06-07-full-match-design.md and ADR 0004. No member state.

# Decide the match result from the two innings. innings1 = first-batting side,
# innings2 = chasing side. player_bats_first maps the winning side to the Player's
# perspective. max_balls = the innings length (itun.over_limit * 6). Spec §5.
static func _decide_result(
		innings1: InningsResult,
		innings2: InningsResult,
		player_bats_first: bool,
		max_balls: int
) -> MatchResult:
	var r := MatchResult.new()
	r.innings1 = innings1
	r.innings2 = innings2
	r.player_bats_first = player_bats_first

	var t1 := innings1.total
	var t2 := innings2.total

	if t2 > t1:
		# Chasing side (innings2) won by wickets.
		r.margin_wickets = 10 - innings2.wickets
		r.balls_remaining = max_balls - innings2.balls
		var chasing_is_player := not player_bats_first
		r.outcome = MatchResult.Outcome.PLAYER_WIN if chasing_is_player else MatchResult.Outcome.OPPONENT_WIN
	elif t2 == t1:
		r.outcome = MatchResult.Outcome.TIE
	else:
		# Defending side (innings1) won by runs.
		r.margin_runs = t1 - t2
		var defending_is_player := player_bats_first
		r.outcome = MatchResult.Outcome.PLAYER_WIN if defending_is_player else MatchResult.Outcome.OPPONENT_WIN

	return r
```

- [ ] **Step 4: Run tests to verify green**

Run the standard verify command. Expected: `All tests passed`, `GREEN`, total count = **128** (124 + 4).

- [ ] **Step 5: Commit**

```bash
git add scripts/domain/match_resolver.gd scripts/domain/match_resolver.gd.uid tests/unit/test_match_resolver.gd
git commit -m "Add MatchResolver._decide_result pure result/margin logic (full match, task 3)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 4: `MatchResolver.simulate_match()` — the two-innings wrapper

Run both innings (respecting the toss), set the chase target between them, and decide the result. This is the rung's headline function.

**Files:**
- Modify: `scripts/domain/match_resolver.gd` (add `simulate_match`)
- Modify: `tests/unit/test_match_resolver.gd` (append integration tests)

- [ ] **Step 1: Write the failing tests**

Append to `tests/unit/test_match_resolver.gd`:

```gdscript
var tuning: BallTuning
var itun: InningsTuning

func before_each() -> void:
	tuning = BallTuning.new()
	itun = InningsTuning.new()

func _attrs(power: int, comp: int, attack: int, control: int) -> Attributes:
	var a := Attributes.new()
	a.power = power
	a.composure = comp
	a.attack = attack
	a.control = control
	return a

func _make_rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng

# Even contest: Player 5/5/5/5, both teams strength 5, bowling 5/5.
func _even_match(player_bats_first: bool, seed_value: int) -> MatchResult:
	return MatchResolver.simulate_match(
		_attrs(5, 5, 5, 5), 5, 5, 5,   # Player's team: bat + bowling pair
		5, 5, 5,                       # opposition: bat + bowling pair
		player_bats_first, tuning, itun, _make_rng(seed_value))

func test_same_seed_deterministic() -> void:
	var r1 := _even_match(true, 2024)
	var r2 := _even_match(true, 2024)
	assert_eq(r1.outcome, r2.outcome, "outcome deterministic")
	assert_eq(r1.innings1.total, r2.innings1.total, "innings1 total deterministic")
	assert_eq(r1.innings2.total, r2.innings2.total, "innings2 total deterministic")
	assert_eq(r1.margin_runs, r2.margin_runs, "margin deterministic")
	assert_eq(r1.margin_wickets, r2.margin_wickets, "wkts margin deterministic")

func test_player_bats_first_places_player_in_innings1() -> void:
	var r := _even_match(true, 11)
	assert_false(r.innings1.player_line().is_empty(), "Player features in innings1 when batting first")
	assert_true(r.innings2.player_line().is_empty(), "opposition (innings2) has no statted Player")

func test_player_bats_second_places_player_in_innings2() -> void:
	var r := _even_match(false, 11)
	assert_true(r.innings1.player_line().is_empty(), "opposition (innings1) has no statted Player")
	assert_false(r.innings2.player_line().is_empty(), "Player features in innings2 when batting second")

func test_outcome_always_valid_and_consistent() -> void:
	for sv in range(1, 40):
		var r := _even_match(sv % 2 == 0, sv)
		assert_true(
			r.outcome == MatchResult.Outcome.PLAYER_WIN
			or r.outcome == MatchResult.Outcome.OPPONENT_WIN
			or r.outcome == MatchResult.Outcome.TIE,
			"outcome is one of the three (seed %d)" % sv)
		if r.outcome == MatchResult.Outcome.TIE:
			assert_eq(r.innings1.total, r.innings2.total, "tie <-> equal totals (seed %d)" % sv)
		elif r.margin_runs > 0:
			assert_eq(r.margin_wickets, 0, "runs win has no wkts margin (seed %d)" % sv)
		else:
			assert_gt(r.margin_wickets, 0, "non-runs, non-tie win is by wickets (seed %d)" % sv)

func test_even_contest_roughly_balanced() -> void:
	# Alternate the toss per seed to neutralise any first/second positional bias,
	# then assert the Player's win share sits in a loose band (not flaky 50/50).
	var player_wins := 0
	var decided := 0
	for sv in range(1, 81):
		var r := _even_match(sv % 2 == 0, sv)
		if r.is_tie():
			continue
		decided += 1
		if r.player_won():
			player_wins += 1
	var share := float(player_wins) / float(decided)
	assert_between(share, 0.3, 0.7, "even contest -> roughly balanced win share (got %f over %d decided)" % [share, decided])
```

- [ ] **Step 2: Run tests to verify red**

Run the standard verify command. Expected: failures/parse errors referencing `simulate_match` (function not found on `MatchResolver`), `NOT GREEN`.

- [ ] **Step 3: Write minimal implementation**

Append to `scripts/domain/match_resolver.gd`:

```gdscript
# Simulate a full T20 match: first innings, then a chase to target = total1 + 1,
# then decide the result. player_bats_first sets the toss (which side bats first).
# The statted Player features only in the Player's team innings; the opposition
# innings passes null. Flat param list mirrors simulate_innings (spec §2).
static func simulate_match(
		player_attrs: Attributes,
		player_team_batting: int,
		player_team_attack: int,
		player_team_control: int,
		opp_batting: int,
		opp_attack: int,
		opp_control: int,
		player_bats_first: bool,
		tuning: BallTuning,
		itun: InningsTuning,
		rng: RandomNumberGenerator
) -> MatchResult:
	var max_balls := itun.over_limit * 6
	var innings1: InningsResult
	var innings2: InningsResult

	if player_bats_first:
		# Player's team posts, opposition chases.
		innings1 = InningsResolver.simulate_innings(
			player_attrs, player_team_batting, opp_attack, opp_control, tuning, itun, rng, 0)
		innings2 = InningsResolver.simulate_innings(
			null, opp_batting, player_team_attack, player_team_control, tuning, itun, rng, innings1.total + 1)
	else:
		# Opposition posts, Player's team chases.
		innings1 = InningsResolver.simulate_innings(
			null, opp_batting, player_team_attack, player_team_control, tuning, itun, rng, 0)
		innings2 = InningsResolver.simulate_innings(
			player_attrs, player_team_batting, opp_attack, opp_control, tuning, itun, rng, innings1.total + 1)

	return _decide_result(innings1, innings2, player_bats_first, max_balls)
```

- [ ] **Step 4: Run tests to verify green**

Run the standard verify command. Expected: `All tests passed`, `GREEN`, total count = **133** (128 + 5).

> Note: `test_even_contest_roughly_balanced` is the sanity check — the band (0.3–0.7) is deliberately wide. If it lands outside, do **not** retune `BallTuning`/`InningsTuning`; investigate the wrapper (likely a side/perspective mapping bug in `_decide_result` or a swapped innings in `simulate_match`), since both atom and innings are already validated.

- [ ] **Step 5: Commit**

```bash
git add scripts/domain/match_resolver.gd scripts/domain/match_resolver.gd.uid tests/unit/test_match_resolver.gd
git commit -m "Add MatchResolver.simulate_match two-innings wrapper (full match, task 4)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Final verification

- [ ] Run the standard verify command one more time: confirm `All tests passed` and total = **133**.
- [ ] Confirm zero new orphans introduced (compare the GUT summary's orphan count to the known 15 pre-existing HoF orphans — the number must not climb; this rung adds only pure domain logic, which structurally can't add scene orphans).
- [ ] Confirm `git status` is clean and all four task commits are present (`git log --oneline -4`).

---

## Self-review notes (author)

- **Spec coverage:** §2 contract → Task 4 `simulate_match` signature; §3 optional Player + optional target → Task 2; §4 match flow / toss → Task 4; §5 result logic → Task 3 `_decide_result`; §6 `MatchResult` → Task 1. §7 test plan: (1) determinism → T4 `test_same_seed_deterministic`; (2) optional Player → T2 `test_null_player_builds_all_derived`; (3) backward compat → T2 `test_default_target_matches_explicit_zero`; (4) chase stops early → T2 `test_chase_stops_when_target_reached`; (5) win by runs → T3 `test_decide_win_by_runs`; (6) win by wickets → T3 `test_decide_win_by_wickets`; (7) tie → T3 `test_decide_tie`; (8) perspective mapping → T3 `test_decide_perspective_opponent_win` + T4 `test_player_bats_first/second_places_player`; (9) even-contest sanity → T4 `test_even_contest_roughly_balanced`.
- **Type consistency:** `MatchResult` fields (`innings1/innings2/player_bats_first/outcome/margin_runs/margin_wickets/balls_remaining`) + `Outcome` enum used identically in Tasks 1/3/4; `_decide_result(innings1, innings2, player_bats_first, max_balls)` arity matches its Task-3 callers and the Task-4 call; `simulate_innings(..., target)` 8-arg form matches the Task-2 signature; `InningsResult.new(total, wickets, balls, fall, batters)` arity matches the existing holder; `InningsResult.player_line()` / `.is_empty()` used consistently.
- **Deferred (per spec §1):** real bowler rotation, Player-as-bowler, star→numbers pipeline, Team-bundled interface, toss-as-event — none appear as tasks, by design. Constant bowling pairs (`*_attack`/`*_control`) are passed straight through.
- **Test-count ledger:** 115 baseline → 121 (T1 +6) → 124 (T2 +3) → 128 (T3 +4) → 133 (T4 +5).
