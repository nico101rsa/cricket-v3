# Bowling Change (rung 4b) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the constant `(attack, control)` bowling pair with a per-phase pace/spin rotation — a `BowlingPlan` (which type per phase) + `BowlingAttack` (the two tilted profiles) threaded through `simulate_innings()` and `simulate_match()`.

**Architecture:** Two new pure value objects mirroring rung-4a's `IntentPlan`. `BowlingPlan` maps over → bowler type (pace/spin); `BowlingAttack` derives pace/spin `(attack, control)` profiles from a base bowling pair ± a tilt. Both thread as optional trailing params; `null` → the existing constant-pair path → byte-identical to rung 4a, so all 144 existing tests stay green. The Player's plan routes to the innings where the Player's team bowls; the opposition bowls a fixed `textbook()` default. Spec: `docs/superpowers/specs/2026-06-07-bowling-change-design.md`.

**Tech Stack:** Godot 4.6.3, GDScript (tabs), GUT 9.6.

---

## Conventions (read once before starting)

- **Godot binary:** `/Applications/Godot.app/Contents/MacOS/Godot` (not on PATH). **Quit the Godot editor first** — headless runs deadlock against an open editor.
- **After adding/renaming any script, run `--import` ONCE** before the first test run:
  `/Applications/Godot.app/Contents/MacOS/Godot --headless --import --path .`
- **Run the full suite** (the `-gtest` flag does NOT filter here):
  `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`
- **Red vs green:** an undefined `class_name` shows as `Parse Error: Identifier "X" not declared`; GUT skips that file (that is your **red**). **Green** = total count climbs and `All tests passed`.
- **Commit `*.gd.uid`** for files under `scripts/` (`git add` the path so the `.uid` goes too). GUT **test** files do NOT generate `.uid`.
- **Intent enum** (`scripts/domain/ball_resolver.gd`): `DEFENSIVE=0, BALANCED=1, AGGRESSIVE=2`.
- Current test count: **144**.

---

## File Structure

- **Create** `scripts/data/bowling_plan.gd` — `BowlingPlan`: `enum Kind { PACE, SPIN }`, three phase bands, `for_over()`, `textbook()`/`pace_only()`/`spin_only()` factories, phase-boundary constants.
- **Create** `tests/unit/test_bowling_plan.gd`.
- **Create** `scripts/data/bowling_attack.gd` — `BowlingAttack`: derives pace/spin profiles from a base pair ± tilt; `profile(kind) -> Vector2i`.
- **Create** `tests/unit/test_bowling_attack.gd`.
- **Modify** `scripts/domain/innings_resolver.gd` — add trailing `bowling_attack` + `bowling_plan` params; per-over profile selection (scalar fallback when null).
- **Modify** `tests/unit/test_innings_resolver.gd` — backward-compat, determinism, directional tests.
- **Modify** `scripts/domain/match_resolver.gd` — add trailing `player_bowling_plan` param; build `BowlingAttack`s + route (opp uses `textbook()` default).
- **Modify** `tests/unit/test_match_resolver.gd` — backward-compat, routing, determinism tests.

---

## Task 1: `BowlingPlan` value object

**Files:**
- Create: `scripts/data/bowling_plan.gd`
- Test: `tests/unit/test_bowling_plan.gd`

- [ ] **Step 1: Write the failing test**

Create `tests/unit/test_bowling_plan.gd`:

```gdscript
extends GutTest

func test_for_over_maps_phases() -> void:
	var plan := BowlingPlan.new()
	plan.powerplay = BowlingPlan.Kind.PACE
	plan.middle = BowlingPlan.Kind.SPIN
	plan.death = BowlingPlan.Kind.PACE
	assert_eq(plan.for_over(1), BowlingPlan.Kind.PACE, "over 1 -> powerplay")
	assert_eq(plan.for_over(6), BowlingPlan.Kind.PACE, "over 6 -> powerplay (boundary)")
	assert_eq(plan.for_over(7), BowlingPlan.Kind.SPIN, "over 7 -> middle (boundary)")
	assert_eq(plan.for_over(15), BowlingPlan.Kind.SPIN, "over 15 -> middle (boundary)")
	assert_eq(plan.for_over(16), BowlingPlan.Kind.PACE, "over 16 -> death (boundary)")
	assert_eq(plan.for_over(20), BowlingPlan.Kind.PACE, "over 20 -> death (boundary)")

func test_factories_and_default() -> void:
	var t := BowlingPlan.textbook()
	assert_eq(t.powerplay, BowlingPlan.Kind.PACE, "textbook powerplay pace")
	assert_eq(t.middle, BowlingPlan.Kind.SPIN, "textbook middle spin")
	assert_eq(t.death, BowlingPlan.Kind.PACE, "textbook death pace")
	var p := BowlingPlan.pace_only()
	assert_eq(p.powerplay, BowlingPlan.Kind.PACE, "pace_only pp")
	assert_eq(p.middle, BowlingPlan.Kind.PACE, "pace_only mid")
	assert_eq(p.death, BowlingPlan.Kind.PACE, "pace_only death")
	var s := BowlingPlan.spin_only()
	assert_eq(s.powerplay, BowlingPlan.Kind.SPIN, "spin_only pp")
	assert_eq(s.middle, BowlingPlan.Kind.SPIN, "spin_only mid")
	assert_eq(s.death, BowlingPlan.Kind.SPIN, "spin_only death")
	# A bare new() must equal the textbook shape.
	var bare := BowlingPlan.new()
	assert_eq(bare.powerplay, t.powerplay, "new() == textbook powerplay")
	assert_eq(bare.middle, t.middle, "new() == textbook middle")
	assert_eq(bare.death, t.death, "new() == textbook death")
```

- [ ] **Step 2: Run the suite to verify red**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --import --path . && /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`
Expected: `Parse Error: Identifier "BowlingPlan" not declared`; count stays 144.

- [ ] **Step 3: Write minimal implementation**

Create `scripts/data/bowling_plan.gd`:

```gdscript
class_name BowlingPlan
extends RefCounted

# Caller-supplied bowler-type choice, one type per match phase — the bowling
# mirror of IntentPlan and the output of the Bowling Change Key Moment
# (setNextBowler, ADR 0006). See spec 2026-06-07-bowling-change-design.md.

enum Kind { PACE, SPIN }  # named Kind (not Type) to avoid built-in collisions

const POWERPLAY_OVERS := 6     # aligns with IntentPlan / T20 powerplay
const DEATH_START_OVER := 16   # aligns with IntentPlan death overs

var powerplay: int = Kind.PACE  # overs 1..6
var middle: int = Kind.SPIN     # overs 7..15
var death: int = Kind.PACE      # overs 16..20

# 1-based over number -> bowler Kind for that over.
func for_over(over: int) -> int:
	if over <= POWERPLAY_OVERS:
		return powerplay
	if over < DEATH_START_OVER:
		return middle
	return death

# Textbook rotation: pace powerplay, spin middle, pace death (== the defaults).
static func textbook() -> BowlingPlan:
	return BowlingPlan.new()

# All-pace (attack everywhere) — for the directional test / all-out policy.
static func pace_only() -> BowlingPlan:
	var p := BowlingPlan.new()
	p.powerplay = Kind.PACE
	p.middle = Kind.PACE
	p.death = Kind.PACE
	return p

# All-spin (contain everywhere).
static func spin_only() -> BowlingPlan:
	var p := BowlingPlan.new()
	p.powerplay = Kind.SPIN
	p.middle = Kind.SPIN
	p.death = Kind.SPIN
	return p
```

- [ ] **Step 4: Run the suite to verify green**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --import --path . && /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`
Expected: `All tests passed`, count **146** (144 + 2).

- [ ] **Step 5: Commit**

```bash
git add scripts/data/bowling_plan.gd scripts/data/bowling_plan.gd.uid tests/unit/test_bowling_plan.gd
git commit -m "Add BowlingPlan value object (per-phase pace/spin choice, rung 4b task 1)"
```

---

## Task 2: `BowlingAttack` value object

**Files:**
- Create: `scripts/data/bowling_attack.gd`
- Test: `tests/unit/test_bowling_attack.gd`

- [ ] **Step 1: Write the failing test**

Create `tests/unit/test_bowling_attack.gd`:

```gdscript
extends GutTest

func test_pace_attack_tilted_spin_control_tilted() -> void:
	var ba := BowlingAttack.new(5, 5)  # default tilt 2 -> pace (7,3), spin (3,7)
	var pace := ba.profile(BowlingPlan.Kind.PACE)
	var spin := ba.profile(BowlingPlan.Kind.SPIN)
	assert_gt(pace.x, pace.y, "pace: attack > control")
	assert_gt(spin.y, spin.x, "spin: control > attack")
	assert_gt(pace.x, spin.x, "pace attack > spin attack")
	assert_gt(spin.y, pace.y, "spin control > pace control")

func test_profiles_floor_at_one() -> void:
	var ba := BowlingAttack.new(1, 1)  # tilt 2 would push to -1; must clamp to 1
	var pace := ba.profile(BowlingPlan.Kind.PACE)
	var spin := ba.profile(BowlingPlan.Kind.SPIN)
	assert_gte(pace.x, 1, "pace attack >= 1")
	assert_gte(pace.y, 1, "pace control floored at 1")
	assert_gte(spin.x, 1, "spin attack floored at 1")
	assert_gte(spin.y, 1, "spin control >= 1")
```

- [ ] **Step 2: Run the suite to verify red**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --import --path . && /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`
Expected: `Parse Error: Identifier "BowlingAttack" not declared`; count stays 146.

- [ ] **Step 3: Write minimal implementation**

Create `scripts/data/bowling_attack.gd`:

```gdscript
class_name BowlingAttack
extends RefCounted

# Derives the pace and spin (attack, control) profiles from a base bowling pair
# by tilting in opposite directions: pace trades control for attack (more
# wickets, more runs), spin trades attack for control (containment). Transient
# per-match derived data. See spec 2026-06-07-bowling-change-design.md.

const DEFAULT_TILT := 2  # strawman — the balance harness sweeps it later

var pace_attack: int
var pace_control: int
var spin_attack: int
var spin_control: int

func _init(base_attack: int, base_control: int, tilt: int = DEFAULT_TILT) -> void:
	pace_attack = maxi(1, base_attack + tilt)
	pace_control = maxi(1, base_control - tilt)
	spin_attack = maxi(1, base_attack - tilt)
	spin_control = maxi(1, base_control + tilt)

# kind is BowlingPlan.Kind. Returns Vector2i(attack, control).
func profile(kind: int) -> Vector2i:
	if kind == BowlingPlan.Kind.SPIN:
		return Vector2i(spin_attack, spin_control)
	return Vector2i(pace_attack, pace_control)
```

- [ ] **Step 4: Run the suite to verify green**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --import --path . && /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`
Expected: `All tests passed`, count **148** (146 + 2).

- [ ] **Step 5: Commit**

```bash
git add scripts/data/bowling_attack.gd scripts/data/bowling_attack.gd.uid tests/unit/test_bowling_attack.gd
git commit -m "Add BowlingAttack value object (pace/spin profile derivation, rung 4b task 2)"
```

---

## Task 3: Thread bowling rotation through `simulate_innings()`

**Files:**
- Modify: `scripts/domain/innings_resolver.gd` (signature ends `intent_plan: IntentPlan = null` after rung 4a; per-ball block resolves intent + the `resolve_ball` call)
- Test: `tests/unit/test_innings_resolver.gd`

- [ ] **Step 1: Write the failing tests**

Append to `tests/unit/test_innings_resolver.gd` (the file already has `tuning`, `itun`, `_attrs(...)`, and `_rng(...)` from rung 4a):

```gdscript
func test_null_bowling_matches_scalar_baseline() -> void:
	# No bowling_attack/plan must reproduce the constant-pair (rung 4a) result.
	var a := _attrs(5, 5, 5, 5)
	var base := InningsResolver.simulate_innings(a, 5, 5, 5, tuning, itun, _rng(7))
	var explicit := InningsResolver.simulate_innings(
		a, 5, 5, 5, tuning, itun, _rng(7), 0, null, null, null)
	assert_eq(base.total, explicit.total, "null bowling == scalar total")
	assert_eq(base.wickets, explicit.wickets, "null bowling == scalar wickets")
	assert_eq(base.balls, explicit.balls, "null bowling == scalar balls")

func test_innings_deterministic_with_rotation() -> void:
	var a := _attrs(5, 5, 5, 5)
	var ba := BowlingAttack.new(5, 5)
	var r1 := InningsResolver.simulate_innings(
		a, 5, 5, 5, tuning, itun, _rng(99), 0, null, ba, BowlingPlan.textbook())
	var r2 := InningsResolver.simulate_innings(
		a, 5, 5, 5, tuning, itun, _rng(99), 0, null, ba, BowlingPlan.textbook())
	assert_eq(r1.total, r2.total, "same seed + rotation -> same total")
	assert_eq(r1.wickets, r2.wickets, "same seed + rotation -> same wickets")

func test_pace_takes_more_wickets_at_higher_run_rate_than_spin() -> void:
	# Intent held BALANCED (null) to isolate the bowling tilt. Pace = more
	# wickets AND higher run RATE (not total: more wickets can end an innings
	# early and truncate the total).
	var a := _attrs(5, 5, 5, 5)
	var ba := BowlingAttack.new(5, 5)
	var pace := BowlingPlan.pace_only()
	var spin := BowlingPlan.spin_only()
	var pace_runs := 0
	var pace_balls := 0
	var pace_wkts := 0
	var spin_runs := 0
	var spin_balls := 0
	var spin_wkts := 0
	for sv in range(1, 41):
		var rp := InningsResolver.simulate_innings(a, 5, 5, 5, tuning, itun, _rng(sv), 0, null, ba, pace)
		var rs := InningsResolver.simulate_innings(a, 5, 5, 5, tuning, itun, _rng(sv), 0, null, ba, spin)
		pace_runs += rp.total
		pace_balls += rp.balls
		pace_wkts += rp.wickets
		spin_runs += rs.total
		spin_balls += rs.balls
		spin_wkts += rs.wickets
	assert_gt(pace_wkts, spin_wkts, "pace takes more wickets over 40 innings")
	var pace_rate := float(pace_runs) / float(pace_balls)
	var spin_rate := float(spin_runs) / float(spin_balls)
	assert_gt(pace_rate, spin_rate, "pace concedes a higher run rate than spin")
```

- [ ] **Step 2: Run the suite to verify red**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`
Expected: `Parse Error: Too many arguments for "simulate_innings()" call` (the new 10th/11th args don't exist yet) — the innings test file is skipped, count drops.

- [ ] **Step 3: Modify the signature**

In `scripts/domain/innings_resolver.gd`, change the `simulate_innings` signature (currently ending `intent_plan: IntentPlan = null`) to add the two new trailing params:

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
		intent_plan: IntentPlan = null,
		bowling_attack: BowlingAttack = null,
		bowling_plan: BowlingPlan = null
) -> InningsResult:
```

- [ ] **Step 4: Resolve the per-over bowling profile**

In the same file, replace the per-ball block (currently):

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

with:

```gdscript
		var s: Dictionary = batters[striker]
		var over := balls / 6 + 1  # 1-based over of the ball about to be bowled
		var intent := BallResolver.Intent.BALANCED
		if intent_plan != null:
			intent = intent_plan.for_over(over)
		var bat_attack := opp_attack
		var bat_control := opp_control
		if bowling_attack != null and bowling_plan != null:
			var prof := bowling_attack.profile(bowling_plan.for_over(over))
			bat_attack = prof.x
			bat_control = prof.y
		var o := BallResolver.resolve_ball(
			s["power"], s["composure"], bat_attack, bat_control,
			intent, tuning, rng)
```

- [ ] **Step 5: Run the suite to verify green**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`
Expected: `All tests passed`, count **151** (148 + 3). All prior innings/match tests still green (null path unchanged).

- [ ] **Step 6: Commit**

```bash
git add scripts/domain/innings_resolver.gd scripts/domain/innings_resolver.gd.uid tests/unit/test_innings_resolver.gd
git commit -m "Thread optional bowling rotation through simulate_innings (rung 4b task 3)"
```

---

## Task 4: Thread bowling rotation through `simulate_match()`

**Files:**
- Modify: `scripts/domain/match_resolver.gd` (`simulate_match` signature ends `player_intent_plan: IntentPlan = null` after rung 4a; the two innings branches)
- Test: `tests/unit/test_match_resolver.gd`

- [ ] **Step 1: Write the failing tests**

Append to `tests/unit/test_match_resolver.gd` (the file already has `tuning`, `itun`, `_attrs(...)`, `_make_rng(...)`):

```gdscript
func test_null_bowling_plan_matches_rung4a_baseline() -> void:
	# No player_bowling_plan => no rotation either side => identical to rung 4a.
	var a := _attrs(5, 5, 5, 5)
	var base := MatchResolver.simulate_match(
		a, 5, 5, 5, 5, 5, 5, true, tuning, itun, _make_rng(7))
	var explicit := MatchResolver.simulate_match(
		a, 5, 5, 5, 5, 5, 5, true, tuning, itun, _make_rng(7), null, null)
	assert_eq(base.innings1.total, explicit.innings1.total, "innings1 unchanged")
	assert_eq(base.innings2.total, explicit.innings2.total, "innings2 unchanged")
	assert_eq(base.outcome, explicit.outcome, "outcome unchanged")

func test_player_bowling_plan_routes_to_player_team_bowling() -> void:
	# Player bats SECOND => innings1 is the opposition batting against the
	# Player's team bowling, resolved from the seed's initial RNG state. It must
	# equal a standalone opposition innings facing the Player's team BowlingAttack
	# + the supplied plan at the same seed.
	var a := _attrs(5, 5, 5, 5)
	var plan := BowlingPlan.spin_only()
	var m := MatchResolver.simulate_match(
		a, 5, 5, 5, 5, 5, 5, false, tuning, itun, _make_rng(123), null, plan)
	var player_team_bowl := BowlingAttack.new(5, 5)  # from player_team_attack/control
	var standalone := InningsResolver.simulate_innings(
		null, 5, 5, 5, tuning, itun, _make_rng(123), 0, null, player_team_bowl, plan)
	assert_eq(m.innings1.total, standalone.total, "Player team bowling used the plan")
	assert_eq(m.innings1.wickets, standalone.wickets, "opposition wickets match plan run")

func test_match_deterministic_with_bowling_plan() -> void:
	var a := _attrs(5, 5, 5, 5)
	var r1 := MatchResolver.simulate_match(
		a, 5, 5, 5, 5, 5, 5, true, tuning, itun, _make_rng(55), null, BowlingPlan.textbook())
	var r2 := MatchResolver.simulate_match(
		a, 5, 5, 5, 5, 5, 5, true, tuning, itun, _make_rng(55), null, BowlingPlan.textbook())
	assert_eq(r1.outcome, r2.outcome, "same seed + plan -> same outcome")
	assert_eq(r1.innings1.total, r2.innings1.total, "innings1 deterministic")
	assert_eq(r1.innings2.total, r2.innings2.total, "innings2 deterministic")
```

- [ ] **Step 2: Run the suite to verify red**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`
Expected: `Parse Error: Too many arguments for "simulate_match()" call` (the new trailing arg doesn't exist yet) — match test file skipped, count drops.

- [ ] **Step 3: Modify the signature**

In `scripts/domain/match_resolver.gd`, add the trailing param to `simulate_match` (currently ending `player_intent_plan: IntentPlan = null`):

```gdscript
		rng: RandomNumberGenerator,
		player_intent_plan: IntentPlan = null,
		player_bowling_plan: BowlingPlan = null
) -> MatchResult:
```

- [ ] **Step 4: Build the BowlingAttacks and route the plan**

In the same function, immediately after the `var innings2: InningsResult` declaration (before the `if player_bats_first:` block), add the rotation setup:

```gdscript
	# Rotation is opt-in: only when the Player supplies a bowling plan. Then both
	# sides rotate (Player's team via the plan; opposition via a textbook default).
	var rotate := player_bowling_plan != null
	var opp_bowl: BowlingAttack = null
	var player_bowl: BowlingAttack = null
	var ai_plan: BowlingPlan = null
	if rotate:
		opp_bowl = BowlingAttack.new(opp_attack, opp_control)
		player_bowl = BowlingAttack.new(player_team_attack, player_team_control)
		ai_plan = BowlingPlan.textbook()
```

Then replace the `if player_bats_first:` / `else:` block so each innings receives the right `BowlingAttack` + plan (the Player's team bowling — `player_bowl` + `player_bowling_plan` — goes to the innings where the opposition bats; the Player's batting innings faces `opp_bowl` + the AI `ai_plan`):

```gdscript
	if player_bats_first:
		# Player's team posts (their intent), opposition chases.
		innings1 = InningsResolver.simulate_innings(
			player_attrs, player_team_batting, opp_attack, opp_control,
			tuning, itun, rng, 0, player_intent_plan, opp_bowl, ai_plan)
		innings2 = InningsResolver.simulate_innings(
			null, opp_batting, player_team_attack, player_team_control,
			tuning, itun, rng, innings1.total + 1, null, player_bowl, player_bowling_plan)
	else:
		# Opposition posts, Player's team chases (their intent).
		innings1 = InningsResolver.simulate_innings(
			null, opp_batting, player_team_attack, player_team_control,
			tuning, itun, rng, 0, null, player_bowl, player_bowling_plan)
		innings2 = InningsResolver.simulate_innings(
			player_attrs, player_team_batting, opp_attack, opp_control,
			tuning, itun, rng, innings1.total + 1, player_intent_plan, opp_bowl, ai_plan)
```

(When `rotate` is false, `opp_bowl`/`player_bowl`/`ai_plan` and `player_bowling_plan` are all `null`, so every innings takes the scalar path — identical to rung 4a.)

- [ ] **Step 5: Run the suite to verify green**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`
Expected: `All tests passed`, count **154** (151 + 3). All prior match tests still green.

- [ ] **Step 6: Commit**

```bash
git add scripts/domain/match_resolver.gd scripts/domain/match_resolver.gd.uid tests/unit/test_match_resolver.gd
git commit -m "Route optional player bowling plan through simulate_match (rung 4b task 4)"
```

---

## Final verification (after all tasks)

- [ ] Full suite: **154 tests, `All tests passed`, zero new orphans**.
- [ ] No iCloud conflict files: `git ls-files | grep " 2"` is empty.
- [ ] PR (`bowling-change-build` → `main`), merge, sync local `main`, delete branch.
- [ ] Update `PROJECT_ROADMAP.md` (rung 4b done; next = 4c husbanding *or* Season wrapper 7b).

---

## Self-review notes (spec coverage)

- Spec §2 (`BowlingAttack` derivation, tilt, floor, `profile`) → Task 2.
- Spec §3 (`BowlingPlan` enum/bands/`for_over`/factories/defaults) → Task 1.
- Spec §4 (thread through `simulate_innings`, per-over selection, scalar fallback) → Task 3.
- Spec §5 (thread through `simulate_match`, opt-in rotate, route plan, opp `textbook()` default) → Task 4.
- Spec §6 (backward compatibility) → Task 3 `test_null_bowling_matches_scalar_baseline`, Task 4 `test_null_bowling_plan_matches_rung4a_baseline`, plus all 144 existing tests on the default path.
- Spec §7 test plan items 1–10 → covered: tilt direction + floor (T2); phase mapping + factories (T1); innings backward-compat, determinism, directional run-rate (T3); match backward-compat, routing, determinism (T4).
- **Build order note:** `BowlingPlan` (Task 1) precedes `BowlingAttack` (Task 2) because `BowlingAttack.profile()` references `BowlingPlan.Kind`.
