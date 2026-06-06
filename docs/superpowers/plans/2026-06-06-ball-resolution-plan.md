# Ball Resolution Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build `BallResolver.resolve_ball()` — one pure function that resolves a single cricket delivery via the two-stage logistic contest of ADR 0004.

**Architecture:** A stateless static function. Stage 1 rolls a wicket (batter Composure vs bowler Attack) in log-odds; if survived, Stage 2 rolls runs (batter Power vs bowler Control) by blending two anchor distributions. Intent couples both stages. All coefficients live in a `BallTuning` data resource, never in code. A seeded `RandomNumberGenerator` is injected so the same seed gives the same outcome.

**Tech Stack:** Godot 4.6.3, GDScript, GUT 9.6 (headless test runner).

**Spec:** `docs/superpowers/specs/2026-06-06-ball-resolution-design.md`

---

## Before you start (project conventions — see `CLAUDE.md`)

- **Godot is not on PATH.** Binary: `/Applications/Godot.app/Contents/MacOS/Godot`
- **Indentation is TABS** in `.gd` files.
- **After creating any new `.gd` script, run `--import` ONCE** before running tests, so the new `class_name` registers in Godot's global cache:
  `/Applications/Godot.app/Contents/MacOS/Godot --headless --import --path .`
- **Never run headless Godot while the Godot editor is open** (⌘Q the editor first) — concurrent imports deadlock/corrupt the cache.
- **Commit the `*.gd.uid` file** Godot generates next to each new script.
- If a GUT run suddenly fails to load with *"class_name … hides a global script class"*, suspect iCloud `" 2"` conflict copies — clean per `CLAUDE.md` then re-import.

**Run a single test file:**
```
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/<file>.gd -gexit
```
**Run the whole unit suite:**
```
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit
```
Pass signal: the summary line `All tests passed`.

---

## File Structure

| File | Responsibility |
|---|---|
| `scripts/data/ball_outcome.gd` | `class_name BallOutcome` — lightweight `RefCounted` holding `wicket: bool`, `runs: int`. |
| `scripts/data/ball_tuning.gd` | `class_name BallTuning` — `Resource` carrying every coefficient + the two anchor distributions, with strawman defaults. |
| `scripts/domain/ball_resolver.gd` | `class_name BallResolver` — the `Intent` enum, the pure `blended_distribution()` helper, and the `resolve_ball()` entry point. |
| `tests/unit/test_ball_outcome.gd` | Holds wicket/runs correctly. |
| `tests/unit/test_ball_tuning.gd` | Default coefficients present & distributions well-formed. |
| `tests/unit/test_ball_resolver.gd` | The full behaviour contract (spec §8). |

---

## Task 1: BallOutcome (the result holder)

**Files:**
- Create: `scripts/data/ball_outcome.gd`
- Test: `tests/unit/test_ball_outcome.gd`

- [ ] **Step 1: Write the failing test**

`tests/unit/test_ball_outcome.gd`:
```gdscript
extends GutTest

func test_defaults_to_no_wicket_no_runs() -> void:
	var o := BallOutcome.new()
	assert_false(o.wicket, "default should be not-out")
	assert_eq(o.runs, 0, "default runs should be 0")

func test_stores_wicket_and_runs() -> void:
	var o := BallOutcome.new(true, 0)
	assert_true(o.wicket)
	assert_eq(o.runs, 0)
	var scored := BallOutcome.new(false, 4)
	assert_false(scored.wicket)
	assert_eq(scored.runs, 4)
```

- [ ] **Step 2: Run it to confirm it fails**

Run (import first — new class):
```
/Applications/Godot.app/Contents/MacOS/Godot --headless --import --path .
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_ball_outcome.gd -gexit
```
Expected: FAIL — `BallOutcome` is not a known class.

- [ ] **Step 3: Write the minimal implementation**

`scripts/data/ball_outcome.gd`:
```gdscript
class_name BallOutcome
extends RefCounted

# Outcome of a single delivery. A wicket always scores 0 runs (V1).
var wicket: bool
var runs: int

func _init(p_wicket: bool = false, p_runs: int = 0) -> void:
	wicket = p_wicket
	runs = p_runs
```

- [ ] **Step 4: Run it to confirm it passes**

Run (re-import so the new class registers):
```
/Applications/Godot.app/Contents/MacOS/Godot --headless --import --path .
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_ball_outcome.gd -gexit
```
Expected: `All tests passed` (2 tests).

- [ ] **Step 5: Commit**
```bash
git add scripts/data/ball_outcome.gd scripts/data/ball_outcome.gd.uid tests/unit/test_ball_outcome.gd
git commit -m "Add BallOutcome result holder (Theme 7a, task 1)"
```

---

## Task 2: BallTuning (coefficients as data)

**Files:**
- Create: `scripts/data/ball_tuning.gd`
- Test: `tests/unit/test_ball_tuning.gd`

- [ ] **Step 1: Write the failing test**

`tests/unit/test_ball_tuning.gd`:
```gdscript
extends GutTest

func test_run_values_are_the_outcome_alphabet() -> void:
	assert_eq(BallTuning.RUN_VALUES, [0, 1, 2, 3, 4, 6])

func test_defaults_are_present_and_aligned() -> void:
	var t := BallTuning.new()
	# Intent arrays are [defensive, balanced, aggressive].
	assert_eq(t.intent_w.size(), 3, "intent_w must have 3 bands")
	assert_eq(t.intent_r.size(), 3, "intent_r must have 3 bands")
	assert_eq(t.intent_w[1], 0.0, "balanced wicket shift is 0")
	assert_eq(t.intent_r[1], 0.0, "balanced runs shift is 0")
	# Distributions align to RUN_VALUES.
	assert_eq(t.def_dist.size(), BallTuning.RUN_VALUES.size())
	assert_eq(t.agg_dist.size(), BallTuning.RUN_VALUES.size())

func test_anchor_distributions_each_sum_to_one() -> void:
	var t := BallTuning.new()
	var dsum := 0.0
	for p in t.def_dist:
		dsum += p
	assert_almost_eq(dsum, 1.0, 0.0001, "def_dist should sum to 1")
	var asum := 0.0
	for p in t.agg_dist:
		asum += p
	assert_almost_eq(asum, 1.0, 0.0001, "agg_dist should sum to 1")

func test_aggressive_band_is_riskier_and_higher_scoring() -> void:
	var t := BallTuning.new()
	assert_gt(t.intent_w[2], t.intent_w[0], "aggressive raises wicket odds vs defensive")
	assert_gt(t.intent_r[2], t.intent_r[0], "aggressive raises scoring vs defensive")
```

- [ ] **Step 2: Run it to confirm it fails**
```
/Applications/Godot.app/Contents/MacOS/Godot --headless --import --path .
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_ball_tuning.gd -gexit
```
Expected: FAIL — `BallTuning` not a known class.

- [ ] **Step 3: Write the minimal implementation**

`scripts/data/ball_tuning.gd`:
```gdscript
class_name BallTuning
extends Resource

# All ball-resolution coefficients live here as DATA, never hardcoded in the
# resolver — the future balance harness (Theme 7c) sweeps these. Values below
# are strawman defaults; see spec §7.

# The run values a single ball can yield. Distributions align to this order.
const RUN_VALUES: Array[int] = [0, 1, 2, 3, 4, 6]

# --- Stage 1: wicket log-odds = base_w + k_w*(attack - composure) + intent_w[intent]
@export var base_w: float = -3.3174  # ln(0.035/0.965): even contest ~3.5%/ball
@export var k_w: float = 0.42        # gain per attribute point of bowler advantage
@export var intent_w: Array[float] = [-0.55, 0.0, 0.60]  # [defensive, balanced, aggressive]

# --- Stage 2: scoring strength s = sigmoid(base_r + k_r*(power - control) + intent_r[intent])
@export var base_r: float = 0.0
@export var k_r: float = 0.34
@export var intent_r: Array[float] = [-0.75, 0.0, 0.80]

# Runs distributions (aligned to RUN_VALUES), blended DEF->AGG by s.
@export var def_dist: Array[float] = [0.68, 0.255, 0.035, 0.004, 0.020, 0.006]
@export var agg_dist: Array[float] = [0.30, 0.300, 0.090, 0.010, 0.200, 0.100]
```

- [ ] **Step 4: Run it to confirm it passes**
```
/Applications/Godot.app/Contents/MacOS/Godot --headless --import --path .
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_ball_tuning.gd -gexit
```
Expected: `All tests passed` (4 tests).

- [ ] **Step 5: Commit**
```bash
git add scripts/data/ball_tuning.gd scripts/data/ball_tuning.gd.uid tests/unit/test_ball_tuning.gd
git commit -m "Add BallTuning coefficients resource with strawman defaults (Theme 7a, task 2)"
```

---

## Task 3: BallResolver — the pure runs distribution

Build the deterministic, RNG-free core first: blend the two anchor distributions by scoring strength `s` and normalise. This is the pure heart of Stage 2.

**Files:**
- Create: `scripts/domain/ball_resolver.gd`
- Test: `tests/unit/test_ball_resolver.gd`

- [ ] **Step 1: Write the failing test**

`tests/unit/test_ball_resolver.gd`:
```gdscript
extends GutTest

var tuning: BallTuning

func before_each() -> void:
	tuning = BallTuning.new()

func test_blended_distribution_sums_to_one() -> void:
	for s in [0.0, 0.25, 0.5, 0.75, 1.0]:
		var probs := BallResolver.blended_distribution(s, tuning)
		var total := 0.0
		for p in probs:
			total += p
		assert_almost_eq(total, 1.0, 0.0001, "distribution at s=%f should sum to 1" % s)

func test_blend_endpoints_match_anchor_shapes() -> void:
	# At s=0 the distribution is the defensive anchor (already normalised), at s=1 the aggressive.
	var defensive := BallResolver.blended_distribution(0.0, tuning)
	var aggressive := BallResolver.blended_distribution(1.0, tuning)
	# index 4 in RUN_VALUES is the value 4 (a boundary): aggressive favours it far more.
	assert_gt(aggressive[4], defensive[4], "aggressive blend has more 4s than defensive")
	# index 0 is a dot: defensive has more dots.
	assert_gt(defensive[0], aggressive[0], "defensive blend has more dots than aggressive")

func test_higher_s_raises_expected_runs() -> void:
	var low := _expected_runs(BallResolver.blended_distribution(0.2, tuning))
	var high := _expected_runs(BallResolver.blended_distribution(0.8, tuning))
	assert_gt(high, low, "higher scoring strength should raise expected runs")

func _expected_runs(probs: Array[float]) -> float:
	var e := 0.0
	for i in BallTuning.RUN_VALUES.size():
		e += BallTuning.RUN_VALUES[i] * probs[i]
	return e
```

- [ ] **Step 2: Run it to confirm it fails**
```
/Applications/Godot.app/Contents/MacOS/Godot --headless --import --path .
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_ball_resolver.gd -gexit
```
Expected: FAIL — `BallResolver` not a known class.

- [ ] **Step 3: Write the minimal implementation**

`scripts/domain/ball_resolver.gd`:
```gdscript
class_name BallResolver
extends RefCounted

# Pure resolution of a single delivery — see spec 2026-06-06-ball-resolution-design.md
# and ADR 0004. No member state; everything is static.

enum Intent { DEFENSIVE, BALANCED, AGGRESSIVE }  # indices align to BallTuning intent arrays

# Stage 2 core: blend the defensive and aggressive anchor distributions by
# scoring strength s in [0,1], then normalise so the result sums to 1.
static func blended_distribution(s: float, tuning: BallTuning) -> Array[float]:
	var weights: Array[float] = []
	var total := 0.0
	for i in BallTuning.RUN_VALUES.size():
		var w := lerpf(tuning.def_dist[i], tuning.agg_dist[i], s)
		weights.append(w)
		total += w
	for i in weights.size():
		weights[i] /= total
	return weights

static func _sigmoid(x: float) -> float:
	return 1.0 / (1.0 + exp(-x))
```

- [ ] **Step 4: Run it to confirm it passes**
```
/Applications/Godot.app/Contents/MacOS/Godot --headless --import --path .
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_ball_resolver.gd -gexit
```
Expected: `All tests passed` (3 tests).

- [ ] **Step 5: Commit**
```bash
git add scripts/domain/ball_resolver.gd scripts/domain/ball_resolver.gd.uid tests/unit/test_ball_resolver.gd
git commit -m "Add BallResolver.blended_distribution pure core (Theme 7a, task 3)"
```

---

## Task 4: BallResolver — resolve_ball (the two-stage contest)

Add the full entry point: Stage 1 wicket roll, then (if survived) sample Stage 2 runs. Inject a seeded RNG, consume it in fixed order (wicket roll always; runs roll only on survival).

**Files:**
- Modify: `scripts/domain/ball_resolver.gd`
- Modify: `tests/unit/test_ball_resolver.gd`

- [ ] **Step 1: Write the failing tests** (append to `tests/unit/test_ball_resolver.gd`)

```gdscript
func _make_rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng

func _wicket_rate(power: int, comp: int, attack: int, control: int, intent: int, seed_value: int, n: int) -> float:
	var rng := _make_rng(seed_value)
	var wickets := 0
	for i in n:
		if BallResolver.resolve_ball(power, comp, attack, control, intent, tuning, rng).wicket:
			wickets += 1
	return float(wickets) / n

func _mean_runs_when_surviving(power: int, comp: int, attack: int, control: int, intent: int, seed_value: int, n: int) -> float:
	var rng := _make_rng(seed_value)
	var total := 0
	var balls := 0
	for i in n:
		var o := BallResolver.resolve_ball(power, comp, attack, control, intent, tuning, rng)
		if not o.wicket:
			total += o.runs
			balls += 1
	return float(total) / balls

func test_same_seed_gives_identical_sequence() -> void:
	var rng_a := _make_rng(12345)
	var rng_b := _make_rng(12345)
	for i in 200:
		var a := BallResolver.resolve_ball(5, 5, 5, 5, BallResolver.Intent.BALANCED, tuning, rng_a)
		var b := BallResolver.resolve_ball(5, 5, 5, 5, BallResolver.Intent.BALANCED, tuning, rng_b)
		assert_eq(a.wicket, b.wicket, "wicket should match at ball %d" % i)
		assert_eq(a.runs, b.runs, "runs should match at ball %d" % i)

func test_runs_in_alphabet_and_wicket_scores_zero() -> void:
	var rng := _make_rng(999)
	for i in 500:
		var o := BallResolver.resolve_ball(6, 6, 6, 6, BallResolver.Intent.BALANCED, tuning, rng)
		assert_true(o.runs in [0, 1, 2, 3, 4, 6], "runs %d not in alphabet" % o.runs)
		if o.wicket:
			assert_eq(o.runs, 0, "a wicket must score 0")

func test_even_contest_wicket_rate_near_baseline() -> void:
	var rate := _wicket_rate(5, 5, 5, 5, BallResolver.Intent.BALANCED, 2024, 20000)
	assert_almost_eq(rate, 0.035, 0.008, "even-contest wicket rate should be ~3.5%")

func test_higher_attack_raises_wicket_rate() -> void:
	var low := _wicket_rate(5, 5, 4, 5, BallResolver.Intent.BALANCED, 77, 20000)
	var high := _wicket_rate(5, 5, 9, 5, BallResolver.Intent.BALANCED, 77, 20000)
	assert_gt(high, low, "more bowler Attack should raise the wicket rate")

func test_higher_power_raises_mean_runs() -> void:
	var low := _mean_runs_when_surviving(4, 5, 5, 5, BallResolver.Intent.BALANCED, 88, 20000)
	var high := _mean_runs_when_surviving(9, 5, 5, 5, BallResolver.Intent.BALANCED, 88, 20000)
	assert_gt(high, low, "more batter Power should raise mean runs")

func test_aggressive_intent_raises_both_wickets_and_runs() -> void:
	var def_w := _wicket_rate(5, 5, 5, 5, BallResolver.Intent.DEFENSIVE, 55, 20000)
	var agg_w := _wicket_rate(5, 5, 5, 5, BallResolver.Intent.AGGRESSIVE, 55, 20000)
	assert_gt(agg_w, def_w, "aggressive should raise the wicket rate")
	var def_r := _mean_runs_when_surviving(5, 5, 5, 5, BallResolver.Intent.DEFENSIVE, 66, 20000)
	var agg_r := _mean_runs_when_surviving(5, 5, 5, 5, BallResolver.Intent.AGGRESSIVE, 66, 20000)
	assert_gt(agg_r, def_r, "aggressive should raise mean runs")

func test_extreme_mismatch_stays_valid() -> void:
	var rng := _make_rng(3)
	for i in 200:
		var o := BallResolver.resolve_ball(99, 99, 1, 1, BallResolver.Intent.AGGRESSIVE, tuning, rng)
		assert_true(o.runs in [0, 1, 2, 3, 4, 6])
	var rng2 := _make_rng(4)
	for i in 200:
		var o := BallResolver.resolve_ball(1, 1, 99, 99, BallResolver.Intent.DEFENSIVE, tuning, rng2)
		assert_true(o.runs in [0, 1, 2, 3, 4, 6])
```

- [ ] **Step 2: Run them to confirm they fail**
```
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_ball_resolver.gd -gexit
```
Expected: FAIL — `resolve_ball` does not exist on `BallResolver`.

- [ ] **Step 3: Write the implementation** (append these two methods to `scripts/domain/ball_resolver.gd`)

```gdscript
# Resolve one delivery. Consumes rng in fixed order: wicket roll always; runs
# roll only if the ball is survived. Same seed + same inputs -> same outcome.
static func resolve_ball(
		bat_power: int,
		bat_composure: int,
		bowl_attack: int,
		bowl_control: int,
		intent: Intent,
		tuning: BallTuning,
		rng: RandomNumberGenerator
) -> BallOutcome:
	# Stage 1 — wicket roll (Composure vs Attack), in log-odds.
	var logit_w := tuning.base_w + tuning.k_w * (bowl_attack - bat_composure) + tuning.intent_w[intent]
	var p_wicket := _sigmoid(logit_w)
	if rng.randf() < p_wicket:
		return BallOutcome.new(true, 0)

	# Stage 2 — runs roll (Power vs Control).
	var s := _sigmoid(tuning.base_r + tuning.k_r * (bat_power - bowl_control) + tuning.intent_r[intent])
	return BallOutcome.new(false, _sample_runs(s, tuning, rng))

static func _sample_runs(s: float, tuning: BallTuning, rng: RandomNumberGenerator) -> int:
	var probs := blended_distribution(s, tuning)
	var roll := rng.randf()
	var acc := 0.0
	for i in probs.size():
		acc += probs[i]
		if roll < acc:
			return BallTuning.RUN_VALUES[i]
	return BallTuning.RUN_VALUES[BallTuning.RUN_VALUES.size() - 1]  # float-rounding safety
```

- [ ] **Step 4: Run them to confirm they pass**
```
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_ball_resolver.gd -gexit
```
Expected: `All tests passed` (10 tests in this file).

- [ ] **Step 5: Commit**
```bash
git add scripts/domain/ball_resolver.gd tests/unit/test_ball_resolver.gd
git commit -m "Add BallResolver.resolve_ball two-stage logistic contest (Theme 7a, task 4)"
```

---

## Task 5: Full-suite regression

Confirm the new code didn't disturb the existing 69 tests and there are no orphan scripts.

- [ ] **Step 1: Run the entire unit suite**
```
/Applications/Godot.app/Contents/MacOS/Godot --headless --import --path .
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit
```
Expected: `All tests passed`, total = **69 prior + 19 new = 88 tests**, 0 failures, 0 orphans (the summary lists no "orphans").

- [ ] **Step 2: Confirm no iCloud conflict copies snuck in**
```
git ls-files | grep " 2" || echo "clean"
```
Expected: `clean`.

- [ ] **Step 3: Commit (only if the import regenerated anything)**
```bash
git add -A
git commit -m "Theme 7a complete: resolve_ball() green across full suite (88 tests)" || echo "nothing to commit"
```

---

## Self-Review (already run by author)

- **Spec coverage:** §2 contract → Tasks 1/2/4 (signature, BallOutcome, BallTuning). §3 wicket roll → Task 4. §4 runs roll → Tasks 3+4. §5 Intent coupling → Task 4 (`test_aggressive_intent_raises_both...`) + Task 2 defaults. §6 determinism → Task 4 (`test_same_seed...`). §7 tuning data → Task 2. §8 test plan → all 8 items mapped to tests across Tasks 1–4. §9 sanity targets → `test_even_contest_wicket_rate_near_baseline`. No gaps.
- **Placeholder scan:** none — every step has full code/commands.
- **Type consistency:** `BallOutcome.new(wicket, runs)`, `BallTuning.RUN_VALUES`, `BallResolver.Intent.*`, `blended_distribution(s, tuning)`, `resolve_ball(...)` used identically across tasks.
