# Intent Plan (rung 4a) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the caller choose batting Intent per match phase (Powerplay / Middle / Death) via a small `IntentPlan`, threaded through `simulate_innings()` and `simulate_match()`, replacing the hardcoded `BALANCED`.

**Architecture:** A new pure value object `IntentPlan` (over → Intent band map, two factories) plus two backward-compatible optional params (one on each resolver). `null` plan → all-BALANCED → byte-identical to rung 3, so all 133 existing tests stay green. The Player's plan routes to the Player's batting innings only; the opposition stays Balanced. Spec: `docs/superpowers/specs/2026-06-07-intent-plan-design.md`.

**Tech Stack:** Godot 4.6.3, GDScript (tabs), GUT 9.6 test framework.

---

## Conventions (read once before starting)

- **Godot binary:** `/Applications/Godot.app/Contents/MacOS/Godot` (not on PATH).
- **After adding/renaming any script, run `--import` ONCE** before the first test run so `class_name`s register:
  `/Applications/Godot.app/Contents/MacOS/Godot --headless --import --path .`
- **Run the full suite (the `-gtest` flag does NOT filter here):**
  `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`
- **Judging red vs green:** a not-yet-defined `class_name` shows as `SCRIPT ERROR: Parse Error: Identifier "IntentPlan" not declared` and GUT silently skips that file — that is your **red**. **Green** = total test count climbs and `All tests passed`. The suite runs in <1s.
- **Never run headless Godot while the Godot editor is open** (import deadlock — quit editor first).
- **Commit `*.gd.uid` files** (Godot pins script UIDs there; not gitignored). `git add` the whole `scripts/`+`tests/` paths so the `.uid` goes too.
- **Intent enum values** (from `scripts/domain/ball_resolver.gd`): `BallResolver.Intent.DEFENSIVE = 0`, `BALANCED = 1`, `AGGRESSIVE = 2`.
- Current test count: **133**.

---

## File Structure

- **Create** `scripts/data/intent_plan.gd` — the `IntentPlan` value object (3 bands, `for_over`, `balanced()`/`textbook()` factories). Lives in `scripts/data/` (per-match data input, project convention).
- **Create** `tests/unit/test_intent_plan.gd` — pure unit tests for `IntentPlan`.
- **Modify** `scripts/domain/innings_resolver.gd` — add trailing `intent_plan: IntentPlan = null` param to `simulate_innings()`; replace the hardcoded `BALANCED` with a per-ball `for_over` lookup.
- **Modify** `tests/unit/test_innings_resolver.gd` — add backward-compat, determinism-with-plan, and directional-sanity tests.
- **Modify** `scripts/domain/match_resolver.gd` — add trailing `player_intent_plan: IntentPlan = null` param to `simulate_match()`; route it to the Player's innings only.
- **Modify** `tests/unit/test_match_resolver.gd` — add routing (both directions) and determinism-with-plan tests.

---

## Task 1: `IntentPlan` value object

**Files:**
- Create: `scripts/data/intent_plan.gd`
- Test: `tests/unit/test_intent_plan.gd`

- [ ] **Step 1: Write the failing test**

Create `tests/unit/test_intent_plan.gd`:

```gdscript
extends GutTest

# Intent enum values: DEFENSIVE=0, BALANCED=1, AGGRESSIVE=2

func test_for_over_powerplay_phase() -> void:
	var plan := IntentPlan.new()
	plan.powerplay = BallResolver.Intent.AGGRESSIVE
	plan.middle = BallResolver.Intent.BALANCED
	plan.death = BallResolver.Intent.DEFENSIVE
	assert_eq(plan.for_over(1), BallResolver.Intent.AGGRESSIVE, "over 1 -> powerplay band")
	assert_eq(plan.for_over(6), BallResolver.Intent.AGGRESSIVE, "over 6 -> still powerplay (boundary)")

func test_for_over_middle_phase() -> void:
	var plan := IntentPlan.new()
	plan.powerplay = BallResolver.Intent.AGGRESSIVE
	plan.middle = BallResolver.Intent.BALANCED
	plan.death = BallResolver.Intent.DEFENSIVE
	assert_eq(plan.for_over(7), BallResolver.Intent.BALANCED, "over 7 -> middle (boundary)")
	assert_eq(plan.for_over(15), BallResolver.Intent.BALANCED, "over 15 -> still middle (boundary)")

func test_for_over_death_phase() -> void:
	var plan := IntentPlan.new()
	plan.powerplay = BallResolver.Intent.AGGRESSIVE
	plan.middle = BallResolver.Intent.BALANCED
	plan.death = BallResolver.Intent.DEFENSIVE
	assert_eq(plan.for_over(16), BallResolver.Intent.DEFENSIVE, "over 16 -> death (boundary)")
	assert_eq(plan.for_over(20), BallResolver.Intent.DEFENSIVE, "over 20 -> still death (boundary)")

func test_balanced_factory_all_balanced() -> void:
	var plan := IntentPlan.balanced()
	assert_eq(plan.powerplay, BallResolver.Intent.BALANCED, "powerplay balanced")
	assert_eq(plan.middle, BallResolver.Intent.BALANCED, "middle balanced")
	assert_eq(plan.death, BallResolver.Intent.BALANCED, "death balanced")

func test_textbook_factory_attack_build_slog() -> void:
	var plan := IntentPlan.textbook()
	assert_eq(plan.powerplay, BallResolver.Intent.AGGRESSIVE, "textbook powerplay aggressive")
	assert_eq(plan.middle, BallResolver.Intent.BALANCED, "textbook middle balanced")
	assert_eq(plan.death, BallResolver.Intent.AGGRESSIVE, "textbook death aggressive")
```

- [ ] **Step 2: Run the suite to verify red**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --import --path . && /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`
Expected: `Parse Error: Identifier "IntentPlan" not declared` — GUT skips `test_intent_plan.gd`. Test count stays 133.

- [ ] **Step 3: Write minimal implementation**

Create `scripts/data/intent_plan.gd`:

```gdscript
class_name IntentPlan
extends RefCounted

# Caller-supplied batting Intent, one band per match phase. A transient
# per-match decision input (not saved tuning) — see spec
# 2026-06-07-intent-plan-design.md and the setIntent verb of ADR 0006.
# Band values are BallResolver.Intent (DEFENSIVE / BALANCED / AGGRESSIVE).

const POWERPLAY_OVERS := 6     # fixed by T20 law (6-over powerplay)
const DEATH_START_OVER := 16   # tunable default (last 5 overs)

var powerplay: int = BallResolver.Intent.BALANCED  # overs 1..6
var middle: int = BallResolver.Intent.BALANCED     # overs 7..15
var death: int = BallResolver.Intent.BALANCED      # overs 16..20

# 1-based over number -> Intent band for that over.
func for_over(over: int) -> int:
	if over <= POWERPLAY_OVERS:
		return powerplay
	if over < DEATH_START_OVER:
		return middle
	return death

# Neutral baseline: BALANCED in every phase (== the pre-rung-4a hardcode).
static func balanced() -> IntentPlan:
	return IntentPlan.new()

# Textbook plan: attack the powerplay, build the middle, slog the death.
static func textbook() -> IntentPlan:
	var plan := IntentPlan.new()
	plan.powerplay = BallResolver.Intent.AGGRESSIVE
	plan.middle = BallResolver.Intent.BALANCED
	plan.death = BallResolver.Intent.AGGRESSIVE
	return plan
```

- [ ] **Step 4: Run the suite to verify green**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --import --path . && /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`
Expected: `All tests passed`, total count **138** (133 + 5 new).

- [ ] **Step 5: Commit**

```bash
git add scripts/data/intent_plan.gd scripts/data/intent_plan.gd.uid tests/unit/test_intent_plan.gd tests/unit/test_intent_plan.gd.uid
git commit -m "Add IntentPlan value object (per-phase batting Intent, rung 4a task 1)"
```

---

## Task 2: Thread `IntentPlan` through `simulate_innings()`

**Files:**
- Modify: `scripts/domain/innings_resolver.gd` (signature at line 47; hardcoded `BALANCED` at line 71; over loop at lines 67–72)
- Test: `tests/unit/test_innings_resolver.gd`

- [ ] **Step 1: Write the failing tests**

Append to `tests/unit/test_innings_resolver.gd` (the file already has `tuning`, `itun`, and an `_attrs(...)` helper in scope):

```gdscript
func _rng(seed_value: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	return r

func test_null_plan_matches_balanced_baseline() -> void:
	# A null plan must reproduce the pre-rung-4a BALANCED behaviour exactly.
	var a := _attrs(5, 5, 5, 5)
	var base := InningsResolver.simulate_innings(a, 5, 5, 5, tuning, itun, _rng(7), 0, null)
	var balanced := InningsResolver.simulate_innings(
		a, 5, 5, 5, tuning, itun, _rng(7), 0, IntentPlan.balanced())
	assert_eq(base.total, balanced.total, "null plan == balanced() plan total")
	assert_eq(base.wickets, balanced.wickets, "null plan == balanced() plan wickets")
	assert_eq(base.balls, balanced.balls, "null plan == balanced() plan balls")

func test_innings_deterministic_with_plan() -> void:
	var a := _attrs(5, 5, 5, 5)
	var r1 := InningsResolver.simulate_innings(
		a, 5, 5, 5, tuning, itun, _rng(99), 0, IntentPlan.textbook())
	var r2 := InningsResolver.simulate_innings(
		a, 5, 5, 5, tuning, itun, _rng(99), 0, IntentPlan.textbook())
	assert_eq(r1.total, r2.total, "same seed + plan -> same total")
	assert_eq(r1.wickets, r2.wickets, "same seed + plan -> same wickets")

func test_aggressive_outscores_and_outdies_defensive() -> void:
	# Coupling check: aggression scores faster AND loses more wickets.
	var a := _attrs(5, 5, 5, 5)
	var agg := IntentPlan.new()
	agg.powerplay = BallResolver.Intent.AGGRESSIVE
	agg.middle = BallResolver.Intent.AGGRESSIVE
	agg.death = BallResolver.Intent.AGGRESSIVE
	var def := IntentPlan.new()
	def.powerplay = BallResolver.Intent.DEFENSIVE
	def.middle = BallResolver.Intent.DEFENSIVE
	def.death = BallResolver.Intent.DEFENSIVE
	var agg_runs := 0
	var agg_wkts := 0
	var def_runs := 0
	var def_wkts := 0
	for sv in range(1, 41):
		var ra := InningsResolver.simulate_innings(a, 5, 5, 5, tuning, itun, _rng(sv), 0, agg)
		var rd := InningsResolver.simulate_innings(a, 5, 5, 5, tuning, itun, _rng(sv), 0, def)
		agg_runs += ra.total
		agg_wkts += ra.wickets
		def_runs += rd.total
		def_wkts += rd.wickets
	assert_gt(agg_runs, def_runs, "aggressive scores more over 40 innings")
	assert_gt(agg_wkts, def_wkts, "aggressive loses more wickets over 40 innings")
```

- [ ] **Step 2: Run the suite to verify red**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`
Expected: failures — `simulate_innings()` does not yet accept a 9th `intent_plan` arg (argument-count error), and aggressive/defensive produce identical results (hardcode still BALANCED). Count does not reach 141.

- [ ] **Step 3: Modify the signature**

In `scripts/domain/innings_resolver.gd`, change the `simulate_innings` signature (currently ending `target: int = 0`) to add the new trailing param:

```gdscript
static func simulate_innings(
		player_attrs: Attributes,
		partner_batting: int,
		opp_attack: int,
		opp_control: int,
		tuning: BallTuning,
		itun: InningsTuning,
		rng: RandomNumberGenerator,
		target: int = 0,
		intent_plan: IntentPlan = null
) -> InningsResult:
```

- [ ] **Step 4: Replace the hardcoded Intent with a per-ball lookup**

In the same file, replace the `resolve_ball` call block (currently):

```gdscript
		var s: Dictionary = batters[striker]
		var o := BallResolver.resolve_ball(
			s["power"], s["composure"], opp_attack, opp_control,
			BallResolver.Intent.BALANCED, tuning, rng)
```

with:

```gdscript
		var s: Dictionary = batters[striker]
		var over := balls / 6 + 1  # 1-based over of the ball about to be bowled
		var intent := BallResolver.Intent.BALANCED
		if intent_plan != null:
			intent = intent_plan.for_over(over)
		var o := BallResolver.resolve_ball(
			s["power"], s["composure"], opp_attack, opp_control,
			intent, tuning, rng)
```

- [ ] **Step 5: Run the suite to verify green**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`
Expected: `All tests passed`, total count **141** (138 + 3 new). All prior innings/match tests still green (null/default path unchanged).

- [ ] **Step 6: Commit**

```bash
git add scripts/domain/innings_resolver.gd scripts/domain/innings_resolver.gd.uid tests/unit/test_innings_resolver.gd
git commit -m "Thread optional IntentPlan through simulate_innings (rung 4a task 2)"
```

---

## Task 3: Thread `IntentPlan` through `simulate_match()`

**Files:**
- Modify: `scripts/domain/match_resolver.gd` (`simulate_match` signature + the two innings branches)
- Test: `tests/unit/test_match_resolver.gd`

- [ ] **Step 1: Write the failing tests**

Append to `tests/unit/test_match_resolver.gd` (the file already has `tuning`, `itun`, `_attrs(...)`, and `_make_rng(...)` in scope):

```gdscript
func test_plan_routes_to_player_innings_when_batting_first() -> void:
	# Player bats first => innings1 is the Player's, resolved from the seed's
	# initial RNG state, so it must match a standalone Player innings with the
	# same plan and seed.
	var a := _attrs(5, 5, 5, 5)
	var plan := IntentPlan.textbook()
	var m := MatchResolver.simulate_match(
		a, 5, 5, 5, 5, 5, 5, true, tuning, itun, _make_rng(123), plan)
	var standalone := InningsResolver.simulate_innings(
		a, 5, 5, 5, tuning, itun, _make_rng(123), 0, plan)
	assert_eq(m.innings1.total, standalone.total, "Player innings used the supplied plan")
	assert_eq(m.innings1.wickets, standalone.wickets, "Player innings wickets match plan run")

func test_opposition_stays_balanced_not_player_plan() -> void:
	# Player bats second => innings1 is the opposition, resolved from the seed's
	# initial RNG state. It must match a standalone opposition innings on a
	# BALANCED (null) plan, proving the Player's plan did NOT leak to it.
	var a := _attrs(5, 5, 5, 5)
	var m := MatchResolver.simulate_match(
		a, 5, 5, 5, 5, 5, 5, false, tuning, itun, _make_rng(123), IntentPlan.textbook())
	var opp_balanced := InningsResolver.simulate_innings(
		null, 5, 5, 5, tuning, itun, _make_rng(123), 0, null)
	assert_eq(m.innings1.total, opp_balanced.total, "opposition innings ignored the Player plan")
	assert_eq(m.innings1.wickets, opp_balanced.wickets, "opposition stayed balanced")

func test_match_deterministic_with_plan() -> void:
	var a := _attrs(5, 5, 5, 5)
	var r1 := MatchResolver.simulate_match(
		a, 5, 5, 5, 5, 5, 5, true, tuning, itun, _make_rng(55), IntentPlan.textbook())
	var r2 := MatchResolver.simulate_match(
		a, 5, 5, 5, 5, 5, 5, true, tuning, itun, _make_rng(55), IntentPlan.textbook())
	assert_eq(r1.outcome, r2.outcome, "same seed + plan -> same outcome")
	assert_eq(r1.innings1.total, r2.innings1.total, "innings1 deterministic with plan")
	assert_eq(r1.innings2.total, r2.innings2.total, "innings2 deterministic with plan")
```

- [ ] **Step 2: Run the suite to verify red**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`
Expected: failures — `simulate_match()` does not yet accept the trailing `player_intent_plan` arg (argument-count error). Count does not reach 144.

- [ ] **Step 3: Modify the signature**

In `scripts/domain/match_resolver.gd`, add the trailing param to `simulate_match` (currently ending `rng: RandomNumberGenerator`):

```gdscript
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
		rng: RandomNumberGenerator,
		player_intent_plan: IntentPlan = null
) -> MatchResult:
```

- [ ] **Step 4: Route the plan to the Player's innings only**

Replace the `if player_bats_first:` / `else:` block (the two pairs of `simulate_innings` calls) so the Player's innings gets `player_intent_plan` and the opposition innings gets `null`:

```gdscript
	if player_bats_first:
		# Player's team posts, opposition chases.
		innings1 = InningsResolver.simulate_innings(
			player_attrs, player_team_batting, opp_attack, opp_control,
			tuning, itun, rng, 0, player_intent_plan)
		innings2 = InningsResolver.simulate_innings(
			null, opp_batting, player_team_attack, player_team_control,
			tuning, itun, rng, innings1.total + 1, null)
	else:
		# Opposition posts, Player's team chases.
		innings1 = InningsResolver.simulate_innings(
			null, opp_batting, player_team_attack, player_team_control,
			tuning, itun, rng, 0, null)
		innings2 = InningsResolver.simulate_innings(
			player_attrs, player_team_batting, opp_attack, opp_control,
			tuning, itun, rng, innings1.total + 1, player_intent_plan)
```

- [ ] **Step 5: Run the suite to verify green**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`
Expected: `All tests passed`, total count **144** (141 + 3 new). All prior match tests still green (default `null` plan path unchanged).

- [ ] **Step 6: Commit**

```bash
git add scripts/domain/match_resolver.gd scripts/domain/match_resolver.gd.uid tests/unit/test_match_resolver.gd
git commit -m "Route optional IntentPlan to the Player's innings in simulate_match (rung 4a task 3)"
```

---

## Final verification (after all tasks)

- [ ] Run the full suite once more; expect **144 tests, `All tests passed`, zero orphans**.
- [ ] Confirm no `" 2"` iCloud conflict files crept in: `git ls-files | grep " 2"` should be empty.
- [ ] Open a PR (`intent-plan-build` → `main`), merge, sync local `main`, delete branch.
- [ ] Update `PROJECT_ROADMAP.md` (move rung 4a to done, set next = rung 4b Bowling Change).

---

## Self-review notes (spec coverage)

- Spec §2 (IntentPlan type, factories, `for_over`, constants) → Task 1.
- Spec §3 (thread through `simulate_innings`, over = `balls / 6 + 1`, null→BALANCED) → Task 2.
- Spec §4 (thread through `simulate_match`, route to Player innings only) → Task 3.
- Spec §5 (backward compatibility, determinism) → Task 2 (`test_null_plan_matches_balanced_baseline`), Tasks 2 & 3 determinism tests, plus all 133 existing tests staying green on the default path.
- Spec §6 test plan items 1–7 → all covered: phase mapping (T1), factories (T1), backward-compat (T2), determinism-with-plan (T2/T3), directional sanity (T2), routing both directions (T3), match determinism (T3).
