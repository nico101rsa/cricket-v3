# Jokers in the Sim — Vertical Slice (7c-C) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire a reusable per-ball effect-application seam into the sim and route 5 representative Jokers through it (catalog → sim → sweep → viewer), proving the joker pattern.

**Architecture:** A `JokerEffect` data tuple describes one joker as a conditional roll modifier; a pure static `JokerResolver.roll_mults()` multiplies the active jokers' mults into a `(wicket_mult, runs_mult)` pair; `BallResolver.resolve_ball()` gains two trailing mult params that scale `p_wicket`/`s` (clamped, RNG-count-preserving); `simulate_innings`/`simulate_match` thread an optional joker list with a `player_is_batting` side flag. A new `tools/sweep_jokers.gd` runs a joker on/off sweep through the existing 7c-1 harness.

**Tech Stack:** Godot 4.6.3, GDScript (tabs), GUT 9.6.

**Conventions (project CLAUDE.md):**
- Godot binary: `/Applications/Godot.app/Contents/MacOS/Godot`
- **Quit the Godot editor before any headless run** (`pgrep -x Godot` should be empty).
- After adding/renaming a script, run `--import` once before tests.
- Full test command (the only reliable one — `-gtest` does NOT filter):
  ```sh
  /Applications/Godot.app/Contents/MacOS/Godot --headless --import --path . && \
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit
  ```
- **Red** = `SCRIPT ERROR: Parse Error: Identifier "X" not declared` (GUT skips that file). **Green** = total test count climbs past **197** and `All tests passed`.
- Commit `*.gd.uid` for files under `scripts/` + `tools/` (NOT for `tests/`).

---

### Task 1: `JokerEffect` value object

**Files:**
- Create: `scripts/data/joker_effect.gd`
- Test: `tests/unit/test_joker_effect.gd`

- [ ] **Step 1: Write the failing test**

`tests/unit/test_joker_effect.gd`:
```gdscript
extends GutTest

func _batting_defensive_wicket() -> JokerEffect:
	# Dead Bat shape: batting, Defensive-only, wicket x0.92
	return JokerEffect.make("dead_bat", "Dead Bat", "Common",
		JokerEffect.Side.BATTING, JokerEffect.Target.WICKET, 0.92,
		BallResolver.Intent.DEFENSIVE)

func test_make_sets_fields() -> void:
	var j := _batting_defensive_wicket()
	assert_eq(j.id, "dead_bat")
	assert_eq(j.side, JokerEffect.Side.BATTING)
	assert_eq(j.target, JokerEffect.Target.WICKET)
	assert_almost_eq(j.mult, 0.92, 0.0001)

func test_side_gate() -> void:
	var j := _batting_defensive_wicket()
	# batting joker inert when the owner is bowling
	assert_false(j.matches(false, BallResolver.Intent.DEFENSIVE, 1))
	assert_true(j.matches(true, BallResolver.Intent.DEFENSIVE, 1))

func test_intent_gate() -> void:
	var j := _batting_defensive_wicket()
	assert_false(j.matches(true, BallResolver.Intent.BALANCED, 1), "wrong intent -> off")
	assert_true(j.matches(true, BallResolver.Intent.DEFENSIVE, 1))

func test_ball_window_gate() -> void:
	# Block the Shine shape: any intent, balls 1..18
	var j := JokerEffect.make("bts", "Block the Shine", "Common",
		JokerEffect.Side.BATTING, JokerEffect.Target.WICKET, 0.90, -1, 1, 18)
	assert_true(j.matches(true, BallResolver.Intent.BALANCED, 18))
	assert_false(j.matches(true, BallResolver.Intent.BALANCED, 19), "past window -> off")

func test_intent_any_when_req_negative() -> void:
	var j := JokerEffect.make("any", "Any", "Common",
		JokerEffect.Side.BATTING, JokerEffect.Target.RUNS, 1.1, -1)
	assert_true(j.matches(true, BallResolver.Intent.DEFENSIVE, 1))
	assert_true(j.matches(true, BallResolver.Intent.AGGRESSIVE, 1))
```

- [ ] **Step 2: Run tests to verify they fail**

Run the full test command above.
Expected: `Parse Error: Identifier "JokerEffect" not declared` (red).

- [ ] **Step 3: Write minimal implementation**

`scripts/data/joker_effect.gd`:
```gdscript
class_name JokerEffect
extends RefCounted

# One Joker as a per-ball conditional roll modifier — a pure data tuple.
# See spec 2026-06-08-jokers-in-sim-7cC-slice-design.md §5.1 and ADR 0007.

enum Target { WICKET, RUNS }
enum Side { BATTING, BOWLING }

var id: String = ""
var jname: String = ""        # display name; `name` collides with Godot built-ins
var rarity: String = "Common"
var side: Side = Side.BATTING
var target: Target = Target.WICKET
var mult: float = 1.0
var intent_req: int = -1      # -1 = any; else a BallResolver.Intent value
var ball_min: int = 1         # inclusive innings-ball window
var ball_max: int = 120

# Convenience constructor so the catalog reads as one line per joker.
static func make(p_id: String, p_jname: String, p_rarity: String,
		p_side: Side, p_target: Target, p_mult: float,
		p_intent_req: int = -1, p_ball_min: int = 1, p_ball_max: int = 120) -> JokerEffect:
	var j := JokerEffect.new()
	j.id = p_id
	j.jname = p_jname
	j.rarity = p_rarity
	j.side = p_side
	j.target = p_target
	j.mult = p_mult
	j.intent_req = p_intent_req
	j.ball_min = p_ball_min
	j.ball_max = p_ball_max
	return j

# Does this joker fire on this ball? Side must match the innings, the intent
# requirement (if any) must hold, and the innings ball must be in [ball_min, ball_max].
func matches(player_is_batting: bool, intent: int, ball: int) -> bool:
	var side_ok := (side == Side.BATTING) == player_is_batting
	var intent_ok := intent_req == -1 or intent == intent_req
	var ball_ok := ball >= ball_min and ball <= ball_max
	return side_ok and intent_ok and ball_ok
```

- [ ] **Step 4: Run tests to verify they pass**

Run the full test command.
Expected: count climbs by 5, `All tests passed`.

- [ ] **Step 5: Commit**

```sh
git add scripts/data/joker_effect.gd scripts/data/joker_effect.gd.uid tests/unit/test_joker_effect.gd
git commit -m "Jokers slice task 1: JokerEffect data tuple + matches() gates"
```

---

### Task 2: `JokerResolver.roll_mults`

**Files:**
- Create: `scripts/domain/joker_resolver.gd`
- Test: `tests/unit/test_joker_resolver.gd`

- [ ] **Step 1: Write the failing test**

`tests/unit/test_joker_resolver.gd`:
```gdscript
extends GutTest

func _wicket(mult: float, side: int = JokerEffect.Side.BATTING) -> JokerEffect:
	return JokerEffect.make("w", "W", "Common", side, JokerEffect.Target.WICKET, mult)

func _runs(mult: float, side: int = JokerEffect.Side.BATTING) -> JokerEffect:
	return JokerEffect.make("r", "R", "Common", side, JokerEffect.Target.RUNS, mult)

func test_empty_is_identity() -> void:
	var m := JokerResolver.roll_mults([], true, BallResolver.Intent.BALANCED, 1)
	assert_almost_eq(m.x, 1.0, 0.0001)
	assert_almost_eq(m.y, 1.0, 0.0001)

func test_single_wicket_match() -> void:
	var m := JokerResolver.roll_mults([_wicket(0.9)], true, BallResolver.Intent.BALANCED, 1)
	assert_almost_eq(m.x, 0.9, 0.0001)
	assert_almost_eq(m.y, 1.0, 0.0001)

func test_two_same_target_multiply() -> void:
	var m := JokerResolver.roll_mults([_wicket(0.9), _wicket(0.8)], true, BallResolver.Intent.BALANCED, 1)
	assert_almost_eq(m.x, 0.72, 0.0001)

func test_targets_split() -> void:
	var m := JokerResolver.roll_mults([_wicket(0.9), _runs(1.2)], true, BallResolver.Intent.BALANCED, 1)
	assert_almost_eq(m.x, 0.9, 0.0001)
	assert_almost_eq(m.y, 1.2, 0.0001)

func test_non_matching_excluded() -> void:
	# A bowling joker is inert while the owner is batting.
	var m := JokerResolver.roll_mults([_wicket(0.5, JokerEffect.Side.BOWLING)], true, BallResolver.Intent.BALANCED, 1)
	assert_almost_eq(m.x, 1.0, 0.0001)
```

- [ ] **Step 2: Run tests to verify they fail**

Expected: `Parse Error: Identifier "JokerResolver" not declared` (red).

- [ ] **Step 3: Write minimal implementation**

`scripts/domain/joker_resolver.gd`:
```gdscript
class_name JokerResolver
extends RefCounted

# Per-ball product of active jokers' roll multipliers. Pure, static — the
# model-agnostic seam the balance harness sweeps. See spec §5.2.
# Returns Vector2(wicket_mult, runs_mult); empty / no-match -> (1.0, 1.0).
static func roll_mults(jokers: Array, player_is_batting: bool, intent: int, ball: int) -> Vector2:
	var wm := 1.0
	var rm := 1.0
	for j in jokers:
		if j.matches(player_is_batting, intent, ball):
			if j.target == JokerEffect.Target.WICKET:
				wm *= j.mult
			else:
				rm *= j.mult
	return Vector2(wm, rm)
```

- [ ] **Step 4: Run tests to verify they pass**

Expected: count climbs by 5, `All tests passed`.

- [ ] **Step 5: Commit**

```sh
git add scripts/domain/joker_resolver.gd scripts/domain/joker_resolver.gd.uid tests/unit/test_joker_resolver.gd
git commit -m "Jokers slice task 2: JokerResolver.roll_mults (pure mult stack)"
```

---

### Task 3: `resolve_ball` mult params

**Files:**
- Modify: `scripts/domain/ball_resolver.gd:27-44`
- Test: `tests/unit/test_ball_resolver_mults.gd`

- [ ] **Step 1: Write the failing test**

`tests/unit/test_ball_resolver_mults.gd`:
```gdscript
extends GutTest

func test_default_mults_identical_to_baseline() -> void:
	var tuning := BallTuning.new()
	for i in range(50):
		var r1 := RandomNumberGenerator.new(); r1.seed = i
		var base := BallResolver.resolve_ball(5, 5, 5, 5, BallResolver.Intent.BALANCED, tuning, r1)
		var r2 := RandomNumberGenerator.new(); r2.seed = i
		var same := BallResolver.resolve_ball(5, 5, 5, 5, BallResolver.Intent.BALANCED, tuning, r2, 1.0, 1.0)
		assert_eq(base.wicket, same.wicket)
		assert_eq(base.runs, same.runs)

func test_lower_wicket_mult_reduces_wickets() -> void:
	var tuning := BallTuning.new()
	var base_outs := 0
	var buff_outs := 0
	for i in range(2000):
		var r1 := RandomNumberGenerator.new(); r1.seed = i
		if BallResolver.resolve_ball(5, 5, 5, 5, BallResolver.Intent.BALANCED, tuning, r1).wicket:
			base_outs += 1
		var r2 := RandomNumberGenerator.new(); r2.seed = i
		if BallResolver.resolve_ball(5, 5, 5, 5, BallResolver.Intent.BALANCED, tuning, r2, 0.5, 1.0).wicket:
			buff_outs += 1
	assert_lt(buff_outs, base_outs, "halving wicket_mult should reduce wickets")

func test_higher_runs_mult_raises_runs() -> void:
	var tuning := BallTuning.new()
	var base_runs := 0
	var buff_runs := 0
	for i in range(2000):
		var r1 := RandomNumberGenerator.new(); r1.seed = i
		base_runs += BallResolver.resolve_ball(8, 8, 2, 2, BallResolver.Intent.BALANCED, tuning, r1).runs
		var r2 := RandomNumberGenerator.new(); r2.seed = i
		buff_runs += BallResolver.resolve_ball(8, 8, 2, 2, BallResolver.Intent.BALANCED, tuning, r2, 1.0, 1.5).runs
	assert_gt(buff_runs, base_runs, "higher runs_mult should raise total runs")
```

- [ ] **Step 2: Run tests to verify they fail**

Expected: the new tests error/fail — `resolve_ball()` does not yet accept 8/9 args (red: too-many-arguments parse error).

- [ ] **Step 3: Write minimal implementation**

Replace the body of `resolve_ball` in `scripts/domain/ball_resolver.gd` (lines 27-44). Add the two trailing params and apply+clamp the mults:
```gdscript
static func resolve_ball(
		bat_power: int,
		bat_composure: int,
		bowl_attack: int,
		bowl_control: int,
		intent: Intent,
		tuning: BallTuning,
		rng: RandomNumberGenerator,
		wicket_mult: float = 1.0,
		runs_mult: float = 1.0
) -> BallOutcome:
	# Stage 1 — wicket roll (Composure vs Attack), in log-odds; jokers scale p_wicket.
	var logit_w := tuning.base_w + tuning.k_w * (bowl_attack - bat_composure) + tuning.intent_w[intent]
	var p_wicket := clampf(_sigmoid(logit_w) * wicket_mult, 0.0, 1.0)
	if rng.randf() < p_wicket:
		return BallOutcome.new(true, 0)

	# Stage 2 — runs roll (Power vs Control); jokers scale the scoring strength s.
	var s := clampf(_sigmoid(tuning.base_r + tuning.k_r * (bat_power - bowl_control) + tuning.intent_r[intent]) * runs_mult, 0.0, 1.0)
	return BallOutcome.new(false, _sample_runs(s, tuning, rng))
```

- [ ] **Step 4: Run tests to verify they pass**

Expected: count climbs by 3, `All tests passed`. (The default-mults test confirms every existing caller is unaffected.)

- [ ] **Step 5: Commit**

```sh
git add scripts/domain/ball_resolver.gd tests/unit/test_ball_resolver_mults.gd
git commit -m "Jokers slice task 3: resolve_ball wicket_mult/runs_mult params (clamped, RNG-preserving)"
```

---

### Task 4: Thread jokers through `simulate_innings`

**Files:**
- Modify: `scripts/domain/innings_resolver.gd:65-115`
- Test: `tests/unit/test_innings_jokers.gd`

- [ ] **Step 1: Write the failing test**

`tests/unit/test_innings_jokers.gd`:
```gdscript
extends GutTest

func _attrs() -> Attributes:
	var a := Attributes.new()
	a.power = 5; a.composure = 5; a.attack = 5; a.control = 5
	return a

func _strong_batting_reducer() -> Array:
	# Synthetic always-on batting wicket-reducer — a clean directional signal.
	return [JokerEffect.make("t", "T", "Common", JokerEffect.Side.BATTING, JokerEffect.Target.WICKET, 0.5)]

func test_empty_jokers_equals_baseline() -> void:
	var tuning := BallTuning.new(); var itun := InningsTuning.new()
	var a := _attrs()
	for i in range(20):
		var r1 := RandomNumberGenerator.new(); r1.seed = i
		var base := InningsResolver.simulate_innings(a, 5, 5, 5, tuning, itun, r1)
		var r2 := RandomNumberGenerator.new(); r2.seed = i
		var same := InningsResolver.simulate_innings(a, 5, 5, 5, tuning, itun, r2, 0, null, null, null, 0, 0, 0, [], true)
		assert_eq(base.total, same.total)
		assert_eq(base.wickets, same.wickets)
		assert_eq(base.balls, same.balls)

func test_batting_wicket_reducer_lowers_wickets() -> void:
	var tuning := BallTuning.new(); var itun := InningsTuning.new()
	var a := _attrs()
	var jk := _strong_batting_reducer()
	var base_w := 0; var buff_w := 0
	for i in range(200):
		var r1 := RandomNumberGenerator.new(); r1.seed = i
		base_w += InningsResolver.simulate_innings(a, 5, 5, 5, tuning, itun, r1).wickets
		var r2 := RandomNumberGenerator.new(); r2.seed = i
		buff_w += InningsResolver.simulate_innings(a, 5, 5, 5, tuning, itun, r2, 0, null, null, null, 0, 0, 0, jk, true).wickets
	assert_lt(buff_w, base_w, "a batting wicket-reducer should lower total wickets")

func test_determinism_with_jokers() -> void:
	var tuning := BallTuning.new(); var itun := InningsTuning.new()
	var a := _attrs()
	var jk := _strong_batting_reducer()
	var r1 := RandomNumberGenerator.new(); r1.seed = 42
	var first := InningsResolver.simulate_innings(a, 5, 5, 5, tuning, itun, r1, 0, null, null, null, 0, 0, 0, jk, true)
	var r2 := RandomNumberGenerator.new(); r2.seed = 42
	var second := InningsResolver.simulate_innings(a, 5, 5, 5, tuning, itun, r2, 0, null, null, null, 0, 0, 0, jk, true)
	assert_eq(first.total, second.total)
	assert_eq(first.wickets, second.wickets)
	assert_eq(first.balls, second.balls)
```

- [ ] **Step 2: Run tests to verify they fail**

Expected: the joker-passing tests error — `simulate_innings()` does not yet accept the trailing `jokers`/`player_is_batting` args (red).

- [ ] **Step 3: Write minimal implementation**

In `scripts/domain/innings_resolver.gd`, add two trailing params to the `simulate_innings` signature (after `player_bowler_overs: int = 0`):
```gdscript
		player_bowler_overs: int = 0,
		jokers: Array = [],
		player_is_batting: bool = true
) -> InningsResult:
```

Then inside the ball loop, just before the `resolve_ball` call (currently line ~113), compute the mults and pass them. Replace:
```gdscript
		var o := BallResolver.resolve_ball(
			s["power"], s["composure"], bat_attack, bat_control,
			intent, tuning, rng)
```
with:
```gdscript
		var jm := JokerResolver.roll_mults(jokers, player_is_batting, intent, balls + 1)
		var o := BallResolver.resolve_ball(
			s["power"], s["composure"], bat_attack, bat_control,
			intent, tuning, rng, jm.x, jm.y)
```
(`balls + 1` is the 1-based innings ball number for the delivery about to be bowled, matching the joker ball-window conditions.)

- [ ] **Step 4: Run tests to verify they pass**

Expected: count climbs by 3, `All tests passed`.

- [ ] **Step 5: Commit**

```sh
git add scripts/domain/innings_resolver.gd tests/unit/test_innings_jokers.gd
git commit -m "Jokers slice task 4: thread jokers + player_is_batting through simulate_innings"
```

---

### Task 5: Thread jokers through `simulate_match` + `simulate_match_teams`

**Files:**
- Modify: `scripts/domain/match_resolver.gd:50-134`
- Test: `tests/unit/test_match_jokers.gd`

- [ ] **Step 1: Write the failing test**

`tests/unit/test_match_jokers.gd`:
```gdscript
extends GutTest

func _attrs() -> Attributes:
	var a := Attributes.new()
	a.power = 5; a.composure = 5; a.attack = 5; a.control = 5
	return a

func _tour() -> TourDistribution:
	var t := TourDistribution.new()
	t.mean = 5; t.spread = 1.5; t.noise = 1
	return t

func _team() -> Team:
	var t := Team.new()
	t.stars = 3.0
	return t

func _player_wins(rng_seed: int, jokers: Array) -> bool:
	var m := MatchResolver.simulate_match_teams(
		_attrs(), _team(), _team(), _tour(), BallTuning.new(), InningsTuning.new(),
		_seeded(rng_seed), null, null, jokers)
	return m.outcome == MatchResult.Outcome.PLAYER_WIN

func _seeded(s: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new(); r.seed = s
	return r

func test_synthetic_batting_buff_raises_win_rate() -> void:
	var buff := [JokerEffect.make("b", "B", "Common", JokerEffect.Side.BATTING, JokerEffect.Target.WICKET, 0.7)]
	var base_wins := 0; var buff_wins := 0
	for i in range(300):
		if _player_wins(i, []):
			base_wins += 1
		if _player_wins(i, buff):
			buff_wins += 1
	assert_gt(buff_wins, base_wins, "a batting wicket-reducer should raise player win-rate")

func test_death_over_bowling_joker_raises_win_rate() -> void:
	# Death-Over Stranglehold from the catalog (intent-agnostic, ball >= 90, runs x0.80).
	var dos := [JokerEffect.make("dos", "Death-Over Stranglehold", "Rare",
		JokerEffect.Side.BOWLING, JokerEffect.Target.RUNS, 0.80, -1, 90, 120)]
	var base_wins := 0; var buff_wins := 0
	for i in range(300):
		if _player_wins(i, []):
			base_wins += 1
		if _player_wins(i, dos):
			buff_wins += 1
	assert_gt(buff_wins, base_wins, "a death-over run-suppressor should raise player win-rate")

func test_determinism_with_jokers() -> void:
	var jk := [JokerEffect.make("b", "B", "Common", JokerEffect.Side.BATTING, JokerEffect.Target.WICKET, 0.7)]
	var a := MatchResolver.simulate_match_teams(_attrs(), _team(), _team(), _tour(),
		BallTuning.new(), InningsTuning.new(), _seeded(7), null, null, jk)
	var b := MatchResolver.simulate_match_teams(_attrs(), _team(), _team(), _tour(),
		BallTuning.new(), InningsTuning.new(), _seeded(7), null, null, jk)
	assert_eq(a.outcome, b.outcome)
	assert_eq(a.innings1.total, b.innings1.total)
	assert_eq(a.innings2.total, b.innings2.total)
```

- [ ] **Step 2: Run tests to verify they fail**

Expected: the joker-passing calls error — `simulate_match_teams()` does not yet accept a trailing `jokers` arg (red).

- [ ] **Step 3: Write minimal implementation**

In `scripts/domain/match_resolver.gd`:

(a) Add `jokers: Array = []` to `simulate_match_teams` (after `player_bowling_plan`) and forward it:
```gdscript
		player_intent_plan: IntentPlan = null,
		player_bowling_plan: BowlingPlan = null,
		jokers: Array = []
) -> MatchResult:
	var player_bats_first := _resolve_toss(rng)
	var player_bat := player_team.batting_strength(tour, rng)
	var player_bowl := player_team.bowling_strength(tour, rng)
	var opp_bat := opp_team.batting_strength(tour, rng)
	var opp_bowl := opp_team.bowling_strength(tour, rng)

	return simulate_match(
		player_attrs,
		player_bat, player_bowl, player_bowl,
		opp_bat, opp_bowl, opp_bowl,
		player_bats_first, tuning, itun, rng,
		player_intent_plan, player_bowling_plan, jokers)
```

(b) Add `jokers: Array = []` to `simulate_match` (after `player_bowling_plan`) and pass it to each `simulate_innings` with the correct side flag. Replace the `if player_bats_first:` block (lines ~115-132) with:
```gdscript
	if player_bats_first:
		# Player's team posts (their intent), opposition chases.
		innings1 = InningsResolver.simulate_innings(
			player_attrs, player_team_batting, opp_attack, opp_control,
			tuning, itun, rng, 0, player_intent_plan, opp_bowl, ai_plan,
			0, 0, 0, jokers, true)
		innings2 = InningsResolver.simulate_innings(
			null, opp_batting, player_team_attack, player_team_control,
			tuning, itun, rng, innings1.total + 1, null, player_bowl, player_bowling_plan,
			p_bowl_attack, p_bowl_control, p_bowl_overs, jokers, false)
	else:
		# Opposition posts, Player's team chases (their intent).
		innings1 = InningsResolver.simulate_innings(
			null, opp_batting, player_team_attack, player_team_control,
			tuning, itun, rng, 0, null, player_bowl, player_bowling_plan,
			p_bowl_attack, p_bowl_control, p_bowl_overs, jokers, false)
		innings2 = InningsResolver.simulate_innings(
			player_attrs, player_team_batting, opp_attack, opp_control,
			tuning, itun, rng, innings1.total + 1, player_intent_plan, opp_bowl, ai_plan,
			0, 0, 0, jokers, true)
```
Also update the `simulate_match` signature line to add the trailing param:
```gdscript
		player_intent_plan: IntentPlan = null,
		player_bowling_plan: BowlingPlan = null,
		jokers: Array = []
) -> MatchResult:
```

- [ ] **Step 4: Run tests to verify they pass**

Expected: count climbs by 3, `All tests passed`.

- [ ] **Step 5: Commit**

```sh
git add scripts/domain/match_resolver.gd tests/unit/test_match_jokers.gd
git commit -m "Jokers slice task 5: thread jokers through simulate_match + simulate_match_teams (side-routed)"
```

---

### Task 6: `JokerCatalog.slice_v1` (the 5 authored jokers)

**Files:**
- Create: `scripts/data/joker_catalog.gd`
- Test: `tests/unit/test_joker_catalog.gd`

- [ ] **Step 1: Write the failing test**

`tests/unit/test_joker_catalog.gd`:
```gdscript
extends GutTest

func test_slice_has_five() -> void:
	assert_eq(JokerCatalog.slice_v1().size(), 5)

func _by_id(id: String) -> JokerEffect:
	for j in JokerCatalog.slice_v1():
		if j.id == id:
			return j
	return null

func test_dead_bat_shape() -> void:
	var j := _by_id("dead_bat")
	assert_not_null(j)
	assert_eq(j.side, JokerEffect.Side.BATTING)
	assert_eq(j.target, JokerEffect.Target.WICKET)
	assert_eq(j.intent_req, BallResolver.Intent.DEFENSIVE)
	assert_almost_eq(j.mult, 0.92, 0.0001)

func test_death_over_shape() -> void:
	var j := _by_id("death_over_stranglehold")
	assert_not_null(j)
	assert_eq(j.side, JokerEffect.Side.BOWLING)
	assert_eq(j.target, JokerEffect.Target.RUNS)
	assert_eq(j.ball_min, 90)
	assert_almost_eq(j.mult, 0.80, 0.0001)
	assert_eq(j.rarity, "Rare")
```

- [ ] **Step 2: Run tests to verify they fail**

Expected: `Parse Error: Identifier "JokerCatalog" not declared` (red).

- [ ] **Step 3: Write minimal implementation**

`scripts/data/joker_catalog.gd`:
```gdscript
class_name JokerCatalog
extends RefCounted

# The 5 vertical-slice jokers (spec §4). Magnitudes verbatim from
# docs/joker-pool-v1.md; conditions use only state the sim already tracks.
static func slice_v1() -> Array:
	return [
		JokerEffect.make("dead_bat", "Dead Bat", "Common",
			JokerEffect.Side.BATTING, JokerEffect.Target.WICKET, 0.92,
			BallResolver.Intent.DEFENSIVE),
		JokerEffect.make("powerplay_punch", "Powerplay Punch", "Common",
			JokerEffect.Side.BATTING, JokerEffect.Target.RUNS, 1.10,
			BallResolver.Intent.AGGRESSIVE),
		JokerEffect.make("block_the_shine", "Block the Shine", "Common",
			JokerEffect.Side.BATTING, JokerEffect.Target.WICKET, 0.90,
			-1, 1, 18),
		JokerEffect.make("squeeze_the_middle", "Squeeze the Middle", "Common",
			JokerEffect.Side.BOWLING, JokerEffect.Target.RUNS, 0.92,
			-1, 36, 90),
		JokerEffect.make("death_over_stranglehold", "Death-Over Stranglehold", "Rare",
			JokerEffect.Side.BOWLING, JokerEffect.Target.RUNS, 0.80,
			-1, 90, 120),
	]
```

- [ ] **Step 4: Run tests to verify they pass**

Expected: count climbs by 3, `All tests passed`.

- [ ] **Step 5: Commit**

```sh
git add scripts/data/joker_catalog.gd scripts/data/joker_catalog.gd.uid tests/unit/test_joker_catalog.gd
git commit -m "Jokers slice task 6: JokerCatalog.slice_v1 — the 5 authored slice jokers"
```

---

### Task 7: The joker on/off sweep + viewer refresh (eyeball)

**Files:**
- Create: `tools/sweep_jokers.gd`
- Modify: `docs/mockups/distribution-viewer-v1.html` (swap the inline `DATA`)

No unit test — this is the diagnostic/eyeball deliverable. Verified by running it and confirming a sane JSON read-out.

- [ ] **Step 1: Write the sweep tool**

`tools/sweep_jokers.gd`:
```gdscript
extends SceneTree

# Joker on/off sweep for 7c-C: hold both teams even (★3) and the Player build
# balanced (5/5/5/5) so the jokers are the only lever. Arms = baseline (no jokers)
# + each slice joker individually + the batting stack. Prints JSON of the
# player-runs distribution + win-rate per arm for docs/mockups/distribution-viewer-v1.html.
# Run: /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/sweep_jokers.gd

var _tuning: BallTuning
var _itun: InningsTuning
var _tour: TourDistribution

func _init() -> void:
	_tuning = BallTuning.new()
	_itun = InningsTuning.new()
	_tour = TourDistribution.new()
	_tour.mean = 5
	_tour.spread = 1.5
	_tour.noise = 1

	var catalog := JokerCatalog.slice_v1()
	var batting_stack: Array = []
	for j in catalog:
		if j.side == JokerEffect.Side.BATTING:
			batting_stack.append(j)

	var arms: Array = [{"name": "Baseline (no jokers)", "config": []}]
	for j in catalog:
		arms.append({"name": j.jname, "config": [j]})
	arms.append({"name": "Batting stack (3)", "config": batting_stack})

	var n := 2000
	var swept := Sweep.run(arms, n, _scenario)

	var palette := ["#888888", "#5ac77a", "#4a90d9", "#f2b134", "#e0607e", "#9b59b6", "#1abc9c"]
	var baseline_win := 0.0
	var arms_json: Array = []
	var ai := 0
	for arm in swept:
		var runs := Sweep.values_of(arm["records"], "player_runs")
		var wins := Sweep.values_of(arm["records"], "won")
		var dist := Distribution.new(runs)
		var win_sum := 0
		for w in wins:
			win_sum += w
		var win_rate := float(win_sum) / runs.size()
		if ai == 0:
			baseline_win = win_rate
		var stride: int = maxi(1, runs.size() / 400)
		var sampled: Array = []
		var k := 0
		while k < runs.size():
			sampled.append(runs[k])
			k += stride
		arms_json.append({
			"name": arm["name"],
			"color": palette[ai % palette.size()],
			"values": sampled,
			"stats": dist.to_dict(),
			"win_rate": win_rate,
			"win_delta": win_rate - baseline_win,
		})
		ai += 1

	print(JSON.stringify({"metric": "player_runs", "arms": arms_json}))
	quit()

func _scenario(config, rng: RandomNumberGenerator) -> Dictionary:
	var a := Attributes.new()
	a.power = 5; a.composure = 5; a.attack = 5; a.control = 5
	var pt := Team.new(); pt.stars = 3.0
	var ot := Team.new(); ot.stars = 3.0
	var m := MatchResolver.simulate_match_teams(a, pt, ot, _tour, _tuning, _itun, rng, null, null, config)
	var line := m.innings1.player_line()
	if line.is_empty():
		line = m.innings2.player_line()
	var player_runs := int(line.get("runs", 0))
	var won := 1 if m.outcome == MatchResult.Outcome.PLAYER_WIN else 0
	return {"player_runs": player_runs, "won": won}
```

- [ ] **Step 2: Run the sweep and capture the JSON**

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --import --path . && \
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/sweep_jokers.gd 2>/dev/null | tail -1 > /tmp/jokers_sweep.json
```
Expected: a JSON line with 7 arms; `Baseline` `win_delta` 0, the batting/bowling jokers showing non-trivial `win_delta`. Sanity-check: the batting-stack arm's mean player_runs and win-rate exceed baseline; Squeeze/Death-Over raise win-rate with ~unchanged player_runs (they act on the bowling side). Note any joker whose `win_delta` is ~0 (weak) or large (OP) in the commit message.

- [ ] **Step 3: Swap the viewer's `DATA`**

In `docs/mockups/distribution-viewer-v1.html`, replace the inline `const DATA = {...}` (or equivalent assignment) with the captured JSON from `/tmp/jokers_sweep.json`. Keep the surrounding HTML/JS unchanged. (Open the file, locate the `DATA` literal, replace its value.)

- [ ] **Step 4: Eyeball**

Open `docs/mockups/distribution-viewer-v1.html` in a browser (or via `.claude/launch.json` static server). Confirm the 7 overlaid curves render and the win-rate / win-delta column reads sensibly. This is the Nico-facing "see the distribution shift" artefact.

- [ ] **Step 5: Commit**

```sh
git add tools/sweep_jokers.gd tools/sweep_jokers.gd.uid docs/mockups/distribution-viewer-v1.html
git commit -m "Jokers slice task 7: joker on/off sweep tool + viewer refresh (per-joker win-delta)"
```

---

## Final verification

- [ ] Run the full suite once more; confirm `All tests passed` and the count is ~210+ (was 197).
- [ ] `git ls-files | grep " 2"` is empty (no iCloud conflict-copies tracked).
- [ ] Roadmap update + PR is handled by the wrap-up, not this plan.

---

## Self-review notes

- **Spec coverage:** §5.1 JokerEffect → Task 1; §5.2 JokerResolver → Task 2; §5.4 resolve_ball mults → Task 3; §5.5 simulate_innings → Task 4; §5.6 simulate_match(_teams) → Task 5; §5.3 JokerCatalog → Task 6; §6 sweep + §8 eyeball → Task 7. §7 test list mapped across Tasks 1–6.
- **Type consistency:** `JokerEffect.make(...)` signature is identical everywhere it's called (Tasks 1, 6, 7, and all tests). `roll_mults(jokers, player_is_batting, intent, ball) -> Vector2` consistent. `simulate_innings` trailing params `(..., jokers: Array = [], player_is_batting: bool = true)` and `simulate_match[_teams](..., jokers: Array = [])` consistent across Tasks 4–7.
- **Ordering:** Task 3 (resolve_ball) precedes Task 4 (innings) which precedes Task 5 (match) — each depends only on earlier tasks. Task 6 (catalog) needs Task 1 only. Task 7 needs everything.
- **Determinism:** mults scale probabilities without adding/removing RNG draws → draw order/count unchanged; determinism tests in Tasks 4–5 guard it.
