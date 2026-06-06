# Single-Innings Batting Sim Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build `InningsResolver.simulate_innings()` — loop the existing `BallResolver.resolve_ball()` atom into one deterministic T20 innings (11 batters, build-driven position, weakening tail, strike rotation, 10-wicket/120-ball termination) returning an `InningsResult`.

**Architecture:** Pure domain logic, no scene tree. Three new files: a `BallTuning`-style `InningsTuning` resource (all coefficients as data), a lightweight `InningsResult` holder, and the `InningsResolver` with static functions. Determinism is inherited entirely from `resolve_ball`'s fixed RNG draw order — the resolver just calls it in sequence. Rung 2 of the bottom-up match sim (ball → **innings** → match → Intent).

**Tech Stack:** Godot 4.6.3, GDScript, GUT 9.6. Spec: `docs/superpowers/specs/2026-06-07-innings-sim-design.md`.

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

**Standard verify command** (used in every "run tests" step below — import then run, gate on the pass line):

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --import --path . \
&& /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit \
| tee /tmp/gut.txt; grep -q "All tests passed" /tmp/gut.txt && echo "GREEN" || echo "NOT GREEN"
```

Branch is already `innings-sim-build`. Baseline before starting: **97 tests green** (spec commit added no code).

---

## File Structure

- **Create** `scripts/data/innings_tuning.gd` — `class_name InningsTuning`. All innings coefficients as `@export` data (over limit, position map, tail curve).
- **Create** `scripts/data/innings_result.gd` — `class_name InningsResult`. Lightweight `RefCounted` result holder + `player_line()` accessor.
- **Create** `scripts/domain/innings_resolver.gd` — `class_name InningsResolver`. Static functions: `player_position()`, `partner_factor()`, `_build_batters()`, `simulate_innings()`.
- **Create** `tests/unit/test_innings_tuning.gd`
- **Create** `tests/unit/test_innings_result.gd`
- **Create** `tests/unit/test_innings_resolver.gd`

Existing files referenced (do not modify): `scripts/data/attributes.gd` (`Attributes`: `power/composure/attack/control` ints), `scripts/domain/ball_resolver.gd` (`BallResolver.resolve_ball(...)`, `BallResolver.Intent.BALANCED`), `scripts/data/ball_tuning.gd` (`BallTuning`).

---

## Task 1: `InningsTuning` resource

All innings-level coefficients live as data, never hardcoded — same philosophy as `BallTuning` (the balance harness sweeps the data, not the code).

**Files:**
- Create: `scripts/data/innings_tuning.gd`
- Test: `tests/unit/test_innings_tuning.gd`

- [ ] **Step 1: Write the failing test**

Create `tests/unit/test_innings_tuning.gd`:

```gdscript
extends GutTest

func test_strawman_defaults() -> void:
	var t := InningsTuning.new()
	assert_eq(t.over_limit, 20, "T20 over limit")
	assert_eq(t.pos_base, 9.0, "position map base")
	assert_eq(t.pos_span, 8.0, "position map span")
	assert_almost_eq(t.tail_floor, 0.45, 0.0001, "tail floor")
	assert_almost_eq(t.tail_slope, 0.07, 0.0001, "tail slope")

func test_max_balls_is_120() -> void:
	var t := InningsTuning.new()
	assert_eq(t.over_limit * 6, 120, "20 overs -> 120 balls")
```

- [ ] **Step 2: Run tests to verify red**

Run the standard verify command. Expected: `SCRIPT ERROR: Parse Error: Identifier "InningsTuning" not declared` for `test_innings_tuning.gd`, output `NOT GREEN`.

- [ ] **Step 3: Write minimal implementation**

Create `scripts/data/innings_tuning.gd` (tabs for indent):

```gdscript
class_name InningsTuning
extends Resource

# All innings-level coefficients as DATA, never hardcoded in the resolver —
# the balance harness (Theme 7c) sweeps these. Strawman defaults; see spec
# 2026-06-07-innings-sim-design.md §7.

@export var over_limit: int = 20      # -> over_limit * 6 = 120 balls

# build -> batting position map: pos = clamp(round(pos_base - pos_span*share), 1, 9)
@export var pos_base: float = 9.0
@export var pos_span: float = 8.0

# weakening-tail curve: factor(p) = max(tail_floor, 1 - (p-1)*tail_slope)
@export var tail_floor: float = 0.45
@export var tail_slope: float = 0.07
```

- [ ] **Step 4: Run tests to verify green**

Run the standard verify command. Expected: `All tests passed`, output `GREEN`, total count = 99 (97 + 2).

- [ ] **Step 5: Commit**

```bash
git add scripts/data/innings_tuning.gd scripts/data/innings_tuning.gd.uid tests/unit/test_innings_tuning.gd
git commit -m "Add InningsTuning coefficients resource (innings sim, task 1)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 2: `InningsResult` holder

Aggregate result of one innings. No per-ball log (spec §6 — honours the per-ball-allocation perf note).

**Files:**
- Create: `scripts/data/innings_result.gd`
- Test: `tests/unit/test_innings_result.gd`

- [ ] **Step 1: Write the failing test**

Create `tests/unit/test_innings_result.gd`:

```gdscript
extends GutTest

func test_holds_fields() -> void:
	var batters := [
		{"position": 1, "is_player": false, "power": 5, "composure": 5, "runs": 12, "balls": 10, "out": true},
		{"position": 2, "is_player": true, "power": 8, "composure": 7, "runs": 40, "balls": 30, "out": false},
	]
	var fall := [{"wicket": 1, "score": 12, "batter": 1, "ball": 10}]
	var r := InningsResult.new(52, 1, 40, fall, batters)
	assert_eq(r.total, 52)
	assert_eq(r.wickets, 1)
	assert_eq(r.balls, 40)
	assert_eq(r.fall_of_wickets.size(), 1)
	assert_eq(r.batters.size(), 2)

func test_player_line_returns_player_row() -> void:
	var batters := [
		{"position": 1, "is_player": false, "power": 5, "composure": 5, "runs": 12, "balls": 10, "out": true},
		{"position": 2, "is_player": true, "power": 8, "composure": 7, "runs": 40, "balls": 30, "out": false},
	]
	var r := InningsResult.new(52, 1, 40, [], batters)
	var line := r.player_line()
	assert_true(line["is_player"], "player_line returns the player's row")
	assert_eq(line["runs"], 40)
	assert_eq(line["position"], 2)

func test_player_line_empty_when_no_player() -> void:
	var r := InningsResult.new(0, 0, 0, [], [])
	assert_eq(r.player_line(), {}, "no player -> empty dict")
```

- [ ] **Step 2: Run tests to verify red**

Run the standard verify command. Expected: `Parse Error: Identifier "InningsResult" not declared`, output `NOT GREEN`.

- [ ] **Step 3: Write minimal implementation**

Create `scripts/data/innings_result.gd` (tabs):

```gdscript
class_name InningsResult
extends RefCounted

# Aggregate outcome of one innings. No per-ball log (spec §6). batters and
# fall_of_wickets hold plain Dictionaries (see spec §6 for keys).
var total: int
var wickets: int
var balls: int
var fall_of_wickets: Array
var batters: Array

func _init(p_total: int = 0, p_wickets: int = 0, p_balls: int = 0, p_fall: Array = [], p_batters: Array = []) -> void:
	total = p_total
	wickets = p_wickets
	balls = p_balls
	fall_of_wickets = p_fall
	batters = p_batters

# The Player's batting row, or {} if the Player did not feature.
func player_line() -> Dictionary:
	for b in batters:
		if b["is_player"]:
			return b
	return {}
```

- [ ] **Step 4: Run tests to verify green**

Run the standard verify command. Expected: `All tests passed`, `GREEN`, total count = 102 (99 + 3).

- [ ] **Step 5: Commit**

```bash
git add scripts/data/innings_result.gd scripts/data/innings_result.gd.uid tests/unit/test_innings_result.gd
git commit -m "Add InningsResult holder with player_line accessor (innings sim, task 2)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 3: `InningsResolver` pure helpers — position map + tail curve

The two pure mappings the loop depends on. Testing them in isolation keeps the loop test focused.

**Files:**
- Create: `scripts/domain/innings_resolver.gd`
- Test: `tests/unit/test_innings_resolver.gd`

- [ ] **Step 1: Write the failing test**

Create `tests/unit/test_innings_resolver.gd`:

```gdscript
extends GutTest

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

func test_pure_batter_bats_top_order() -> void:
	# 8/8/2/2: batting 16 vs bowling 4 -> share 0.8 -> pos round(9-6.4)=3
	var pos := InningsResolver.player_position(_attrs(8, 8, 2, 2), itun)
	assert_lte(pos, 3, "pure batter opens / top order")

func test_pure_bowler_bats_tail() -> void:
	# 2/2/8/8: share 0.2 -> pos round(9-1.6)=7
	var pos := InningsResolver.player_position(_attrs(2, 2, 8, 8), itun)
	assert_gte(pos, 7, "pure bowler bats the tail")

func test_even_build_bats_middle() -> void:
	var pos := InningsResolver.player_position(_attrs(5, 5, 5, 5), itun)
	assert_eq(pos, 5, "even build -> #5")

func test_position_clamped_to_range() -> void:
	var pos := InningsResolver.player_position(_attrs(8, 8, 1, 1), itun)
	assert_between(pos, 1, 9, "position stays in 1..9")

func test_tail_factor_full_at_top_floors_at_bottom() -> void:
	assert_almost_eq(InningsResolver.partner_factor(1, itun), 1.0, 0.0001, "opener at full strength")
	# pos 11: 1 - 10*0.07 = 0.30, below floor 0.45 -> clamped to floor
	assert_almost_eq(InningsResolver.partner_factor(11, itun), 0.45, 0.0001, "#11 floored")
	assert_gt(InningsResolver.partner_factor(2, itun), InningsResolver.partner_factor(8, itun), "tail weakens down the order")
```

- [ ] **Step 2: Run tests to verify red**

Run the standard verify command. Expected: `Parse Error: Identifier "InningsResolver" not declared`, `NOT GREEN`.

- [ ] **Step 3: Write minimal implementation**

Create `scripts/domain/innings_resolver.gd` (tabs):

```gdscript
class_name InningsResolver
extends RefCounted

# Pure resolution of one T20 innings by looping BallResolver.resolve_ball().
# See spec 2026-06-07-innings-sim-design.md and ADR 0004. No member state.

# Build -> batting position (1..9). Higher batting share bats higher up.
static func player_position(attrs: Attributes, itun: InningsTuning) -> int:
	var batting := attrs.power + attrs.composure
	var bowling := attrs.attack + attrs.control
	var share := float(batting) / float(batting + bowling)
	var pos := roundi(itun.pos_base - itun.pos_span * share)
	return clampi(pos, 1, 9)

# Weakening-tail scale for a partner at 1-based order position `pos`.
static func partner_factor(pos: int, itun: InningsTuning) -> float:
	return maxf(itun.tail_floor, 1.0 - (pos - 1) * itun.tail_slope)
```

- [ ] **Step 4: Run tests to verify green**

Run the standard verify command. Expected: `All tests passed`, `GREEN`, total count = 107 (102 + 5 — this test file has 5 `test_*` functions).

- [ ] **Step 5: Commit**

```bash
git add scripts/domain/innings_resolver.gd scripts/domain/innings_resolver.gd.uid tests/unit/test_innings_resolver.gd
git commit -m "Add InningsResolver position map + tail curve helpers (innings sim, task 3)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 4: `InningsResolver.simulate_innings()` — the innings loop

The core: build 11 batters (Player at build-driven position, partners scaled by the tail curve), then loop `resolve_ball` with strike rotation until 10 wickets or 120 balls.

**Files:**
- Modify: `scripts/domain/innings_resolver.gd` (add `_build_batters` + `simulate_innings`)
- Modify: `tests/unit/test_innings_resolver.gd` (add loop tests, reusing `_attrs`/`before_each`)

- [ ] **Step 1: Write the failing tests**

Append to `tests/unit/test_innings_resolver.gd`:

```gdscript
func _make_rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng

func _sim(attrs: Attributes, partner: int, oa: int, oc: int, seed_value: int) -> InningsResult:
	return InningsResolver.simulate_innings(attrs, partner, oa, oc, tuning, itun, _make_rng(seed_value))

func test_same_seed_gives_identical_innings() -> void:
	var a := _attrs(5, 5, 5, 5)
	var r1 := _sim(a, 5, 5, 5, 4242)
	var r2 := _sim(a, 5, 5, 5, 4242)
	assert_eq(r1.total, r2.total, "total deterministic")
	assert_eq(r1.wickets, r2.wickets, "wickets deterministic")
	assert_eq(r1.balls, r2.balls, "balls deterministic")
	assert_eq(r1.fall_of_wickets.size(), r2.fall_of_wickets.size(), "fall sequence deterministic")

func test_termination_bounds() -> void:
	# run many seeds; never exceed 120 balls or 10 wickets
	for seed_value in range(1, 60):
		var r := _sim(_attrs(5, 5, 5, 5), 5, 5, 5, seed_value)
		assert_lte(r.balls, 120, "<= 120 balls at seed %d" % seed_value)
		assert_lte(r.wickets, 10, "<= 10 wickets at seed %d" % seed_value)
		assert_eq(r.batters.size(), 11, "always 11 batters")

func test_all_out_stops_immediately() -> void:
	# brutal mismatch: weak batting vs huge bowling attack -> bowled out under 120
	var seen_all_out := false
	for seed_value in range(1, 40):
		var r := _sim(_attrs(2, 2, 8, 8), 2, 14, 14, seed_value)
		if r.wickets == 10:
			seen_all_out = true
			assert_lt(r.balls, 120, "all out should end before 120 balls (seed %d)" % seed_value)
	assert_true(seen_all_out, "a brutal mismatch should bowl the side out in some seeds")

func _avg_player_balls(attrs: Attributes, n: int) -> float:
	var total := 0
	for seed_value in range(1, n + 1):
		total += _sim(attrs, 5, 5, 5, seed_value).player_line()["balls"]
	return float(total) / n

func test_participation_responds_to_build() -> void:
	var batter_balls := _avg_player_balls(_attrs(8, 8, 2, 2), 60)   # opens
	var bowler_balls := _avg_player_balls(_attrs(2, 2, 8, 8), 60)   # tail
	assert_gt(batter_balls, bowler_balls, "a batter-build Player faces more balls than a bowler-build Player")

func _avg_total(attrs: Attributes, partner: int, oa: int, oc: int, it: InningsTuning, n: int) -> float:
	var total := 0
	for seed_value in range(1, n + 1):
		total += InningsResolver.simulate_innings(attrs, partner, oa, oc, tuning, it, _make_rng(seed_value)).total
	return float(total) / n

func test_weakening_tail_drags_total_down() -> void:
	var flat := InningsTuning.new()
	flat.tail_floor = 1.0
	flat.tail_slope = 0.0   # all partners at full strength
	var with_tail := _avg_total(_attrs(5, 5, 5, 5), 5, 5, 5, itun, 80)
	var flat_total := _avg_total(_attrs(5, 5, 5, 5), 5, 5, 5, flat, 80)
	assert_lt(with_tail, flat_total, "a weakening tail lowers the average total")

func test_even_contest_total_in_sane_t20_band() -> void:
	var avg := _avg_total(_attrs(5, 5, 5, 5), 5, 5, 5, itun, 200)
	assert_between(avg, 110.0, 175.0, "even-contest T20 total lands in a believable band (got %f)" % avg)

func test_player_line_integrity() -> void:
	var r := _sim(_attrs(8, 8, 2, 2), 5, 5, 5, 77)
	var line := r.player_line()
	assert_lte(line["runs"], r.total, "Player runs <= team total")
	assert_lte(line["balls"], r.balls, "Player balls <= team balls")
```

- [ ] **Step 2: Run tests to verify red**

Run the standard verify command. Expected: `Parse Error` / failures referencing `simulate_innings` (function not found on `InningsResolver`), `NOT GREEN`.

- [ ] **Step 3: Write minimal implementation**

Append to `scripts/domain/innings_resolver.gd`:

```gdscript
# Build the 11-strong batting order: Player (real attrs) at their build-driven
# position; every other slot a derived partner scaled by the tail curve.
static func _build_batters(player_attrs: Attributes, partner_batting: int, itun: InningsTuning) -> Array:
	var ppos := player_position(player_attrs, itun)
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

# Simulate one innings. Deterministic given rng (resolve_ball owns the draw order).
static func simulate_innings(
		player_attrs: Attributes,
		partner_batting: int,
		opp_attack: int,
		opp_control: int,
		tuning: BallTuning,
		itun: InningsTuning,
		rng: RandomNumberGenerator
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

	while balls < max_balls and wickets < 10:
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

Run the standard verify command. Expected: `All tests passed`, `GREEN`, total count = 114 (107 + 7 — this file adds 7 `test_*` functions; `_make_rng`/`_sim`/`_avg_player_balls`/`_avg_total` are helpers, not tests).

> Note: `test_even_contest_total_in_sane_t20_band` is the sanity check — the companion sandbox shows ~141/4 for this contest, comfortably inside 110–175. If it lands outside, do **not** retune; investigate the loop (likely a strike-rotation or termination bug), since the band is wide and the sandbox already validated the math.

- [ ] **Step 5: Commit**

```bash
git add scripts/domain/innings_resolver.gd scripts/domain/innings_resolver.gd.uid tests/unit/test_innings_resolver.gd
git commit -m "Add InningsResolver.simulate_innings T20 innings loop (innings sim, task 4)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Final verification

- [ ] Run the standard verify command one more time: confirm `All tests passed` and total = **114**.
- [ ] Confirm zero new orphans introduced (compare the GUT summary's orphan count to the known 15 pre-existing HoF orphans — the number must not climb).
- [ ] Confirm `git status` is clean and all four commits are present (`git log --oneline -4`).

---

## Self-review notes (author)

- **Spec coverage:** §2 contract → Task 4 signature; §3 position map → Task 3 `player_position`; §4 partners+tail → Task 3 `partner_factor` + Task 4 `_build_batters`; §5 loop/rotation/termination → Task 4 loop; §6 `InningsResult` → Task 2; §7 `InningsTuning` → Task 1; §8 tests → all eight test items mapped across Tasks 1–4.
- **Type consistency:** `Attributes` fields `power/composure/attack/control`; `InningsTuning` fields used identically in Tasks 1/3/4; `InningsResult.new(total, wickets, balls, fall, batters)` matches Task 2 `_init` arity; batter Dictionary keys (`position/is_player/power/composure/runs/balls/out`) identical in Tasks 2 and 4; fall keys (`wicket/score/batter/ball`) identical in Tasks 2 and 4.
- **Deferred (per spec §1):** opponent innings, chase, bowler rotation, Intent UI, Form/Jokers/Boost, extras, stars→attributes pipeline — none appear as tasks, by design.
