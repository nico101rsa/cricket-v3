# State-aware policy (7c-E2) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Batting intent that reacts to match state (required-run-rate chase pressure + collapse protection) as opt-in rules on `IntentPlan`, then a self-play search answering whether state-aware play dethrones the static equilibrium B/A/B·P/S/P.

**Architecture:** Three disabled-by-default rule fields + `for_state()` on `IntentPlan`; one call-site change in `InningsResolver`; adaptive-space helpers on `PolicySearch`; a new oracle `tools/sweep_policy_state.gd` reusing the E1 protocol (screen → refine → joint-space iterated best response → gap/hero arms); viz `docs/mockups/policy-state-v1.html`.

**Tech Stack:** Godot 4.6.3 GDScript (tabs), GUT 9.6 headless. Spec: `docs/superpowers/specs/2026-06-11-stateaware-policy-7cE2-design.md`.

**Conventions reminder:** run `--import` after adding `tools/sweep_policy_state.gd`; quit the Godot editor before headless runs (`pgrep -x Godot`); full suite must climb past **411**; commit `.gd.uid` for `scripts/`+`tools/` only. Test command:
`/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`

---

### Task 1: IntentPlan state rules + `for_state`

**Files:**
- Modify: `scripts/data/intent_plan.gd`
- Test: `tests/unit/test_intent_plan.gd` (append)

- [ ] **Step 1: Write the failing tests** — append to `tests/unit/test_intent_plan.gd`:

```gdscript
# --- E2 state rules (spec 2026-06-11-stateaware-policy-7cE2-design.md §3) ---

func test_for_state_disabled_rules_equals_for_over() -> void:
	var plan := IntentPlan.textbook()
	for over in [1, 6, 7, 15, 16, 20]:
		assert_eq(plan.for_state(over, 50, 3, (over - 1) * 6, 160, 120),
			plan.for_over(over), "rules off -> identical to for_over (over %d)" % over)

func test_for_state_chase_up_escalates() -> void:
	var plan := IntentPlan.balanced()
	plan.chase_up_rr = 10.0
	# chasing: need 120 off 60 balls = req RR 12 >= 10 -> B steps up to A
	assert_eq(plan.for_state(11, 40, 2, 60, 160, 120), BallResolver.Intent.AGGRESSIVE)

func test_for_state_chase_up_clamps_at_aggressive() -> void:
	var plan := IntentPlan.textbook()  # death = AGGRESSIVE
	plan.chase_up_rr = 10.0
	assert_eq(plan.for_state(18, 40, 2, 105, 160, 120), BallResolver.Intent.AGGRESSIVE)

func test_for_state_chase_down_deescalates_and_clamps() -> void:
	var plan := IntentPlan.balanced()
	plan.chase_down_rr = 6.0
	# cruising: need 10 off 60 balls = req RR 1 <= 6 -> B steps down to D
	assert_eq(plan.for_state(11, 150, 2, 60, 160, 120), BallResolver.Intent.DEFENSIVE)
	var d := IntentPlan.new()
	d.middle = BallResolver.Intent.DEFENSIVE
	d.chase_down_rr = 6.0
	assert_eq(d.for_state(11, 150, 2, 60, 160, 120), BallResolver.Intent.DEFENSIVE, "clamped at DEFENSIVE")

func test_for_state_collapse_protects_both_innings() -> void:
	var plan := IntentPlan.balanced()
	plan.collapse_wkts = 4
	# setting innings (target 0): 5 down -> B steps down to D
	assert_eq(plan.for_state(11, 80, 5, 60, 0, 120), BallResolver.Intent.DEFENSIVE)
	# chasing innings, no chase rule set: collapse still applies
	assert_eq(plan.for_state(11, 80, 5, 60, 160, 120), BallResolver.Intent.DEFENSIVE)

func test_for_state_chase_up_suppresses_collapse() -> void:
	var plan := IntentPlan.balanced()
	plan.chase_up_rr = 10.0
	plan.collapse_wkts = 4
	# behind AND collapsed: the chase wins (DS2a) -> net +1, not 0/-1
	assert_eq(plan.for_state(11, 40, 5, 60, 160, 120), BallResolver.Intent.AGGRESSIVE)

func test_for_state_chase_rules_inert_without_target() -> void:
	var plan := IntentPlan.balanced()
	plan.chase_up_rr = 0.0  # would always fire if evaluated
	assert_eq(plan.for_state(11, 40, 2, 60, 0, 120), BallResolver.Intent.BALANCED)

func test_for_state_zero_balls_remaining_safe() -> void:
	var plan := IntentPlan.balanced()
	plan.chase_up_rr = 0.0
	# balls == max_balls: no div-by-zero, chase rules skipped
	assert_eq(plan.for_state(20, 40, 2, 120, 160, 120), BallResolver.Intent.BALANCED)
```

- [ ] **Step 2: Run suite, verify the new tests FAIL** (parse error / failing asserts on missing `for_state`; per CLAUDE.md judge red by the error, the whole suite runs regardless)

- [ ] **Step 3: Implement** — append to `scripts/data/intent_plan.gd` (fields near the top with the phase vars, method after `for_over`):

```gdscript
# E2 state rules (spec 2026-06-11-stateaware-policy-7cE2-design.md §3). All
# disabled by default; for_state() == for_over() when off, so static plans and
# every pre-E2 caller are byte-identical. req RR = runs still needed per over.
var chase_up_rr: float = -1.0    # chasing & req RR >= this -> escalate one band
var chase_down_rr: float = -1.0  # chasing & req RR <= this -> de-escalate one band
var collapse_wkts: int = -1      # wickets fallen >= this -> de-escalate one band


# State-aware band for the ball about to be bowled. balls = balls bowled so far
# this innings; target/max_balls as in simulate_innings. No RNG. DS2a: collapse
# protection never overrides a chase escalation (a side chasing 11-an-over keeps
# attacking even 5 down).
func for_state(over: int, total: int, wickets: int, balls: int, target: int, max_balls: int) -> int:
	var band := for_over(over)
	var delta := 0
	if target > 0 and balls < max_balls:
		var req_rr := float(target - total) * 6.0 / float(max_balls - balls)
		if chase_up_rr >= 0.0 and req_rr >= chase_up_rr:
			delta = 1
		elif chase_down_rr >= 0.0 and req_rr <= chase_down_rr:
			delta = -1
	if collapse_wkts >= 0 and wickets >= collapse_wkts and delta <= 0:
		delta -= 1
	return clampi(band + delta, BallResolver.Intent.DEFENSIVE, BallResolver.Intent.AGGRESSIVE)
```

- [ ] **Step 4: Run suite, verify green, count climbs +8 (411 → 419)**

- [ ] **Step 5: Commit** — `git add scripts/data/intent_plan.gd tests/unit/test_intent_plan.gd && git commit -m "E2: IntentPlan state rules (chase req-RR up/down + collapse protection), off by default"`

---

### Task 2: Resolver threading + directional test

**Files:**
- Modify: `scripts/domain/innings_resolver.gd:155` (the single `for_over` batting-intent call)
- Test: `tests/unit/test_innings_resolver.gd` (append)

- [ ] **Step 1: Write the failing tests** — append to `tests/unit/test_innings_resolver.gd`:

```gdscript
# --- E2 state-aware intent threading (spec §4) ---

func _e2_innings(plan: IntentPlan, seed_v: int, target: int) -> InningsResult:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	return InningsResolver.simulate_innings(null, 5, 5.0, 5.0,
		BallTuning.new(), InningsTuning.new(), rng, target, plan)

func test_adaptive_rules_off_byte_identical_to_static() -> void:
	var static_plan := IntentPlan.textbook()
	var off_plan := IntentPlan.textbook()  # rule fields untouched = disabled
	for s in range(5):
		var a := _e2_innings(static_plan, 4200 + s, 150)
		var b := _e2_innings(off_plan, 4200 + s, 150)
		assert_eq(b.total, a.total, "rules-off total identical (seed %d)" % s)
		assert_eq(b.wickets, a.wickets, "rules-off wickets identical (seed %d)" % s)
		assert_eq(b.balls, a.balls, "rules-off balls identical (seed %d)" % s)

func test_adaptive_escalation_changes_a_chase() -> void:
	var static_plan := IntentPlan.balanced()
	var up := IntentPlan.balanced()
	up.chase_up_rr = 0.0  # always escalates while chasing
	var differs := false
	for s in range(10):
		var a := _e2_innings(static_plan, 4300 + s, 220)
		var b := _e2_innings(up, 4300 + s, 220)
		if a.total != b.total or a.wickets != b.wickets or a.balls != b.balls:
			differs = true
			break
	assert_true(differs, "an always-escalating chase plan must change outcomes")

func test_adaptive_innings_deterministic() -> void:
	var up := IntentPlan.balanced()
	up.chase_up_rr = 9.0
	up.collapse_wkts = 4
	var a := _e2_innings(up, 777, 170)
	var b := _e2_innings(up, 777, 170)
	assert_eq(a.total, b.total)
	assert_eq(a.wickets, b.wickets)
	assert_eq(a.balls, b.balls)

func test_chase_up_converts_more_big_chases() -> void:
	# A2 directional: chasing 170 at even strength, escalate-when-behind converts
	# more often than the same static base. Seed-summed, N=300 per arm.
	var static_plan := IntentPlan.balanced()
	var up := IntentPlan.balanced()
	up.chase_up_rr = 8.0
	var won_static := 0
	var won_up := 0
	for s in range(300):
		if _e2_innings(static_plan, 9000 + s, 170).total >= 170:
			won_static += 1
		if _e2_innings(up, 9000 + s, 170).total >= 170:
			won_up += 1
	assert_gt(won_up, won_static, "chase escalation must convert more 170-chases (up %d vs static %d)" % [won_up, won_static])
```

- [ ] **Step 2: Run suite — first two new tests may pass (off-rules path), escalation/directional tests FAIL** (resolver still calls `for_over`, so the adaptive plan changes nothing)

- [ ] **Step 3: Implement** — in `scripts/domain/innings_resolver.gd` replace the batting-intent lookup (line ~155):

```gdscript
		if intent_plan != null:
			intent = intent_plan.for_state(over, total, wickets, balls, target, max_balls)
```

(`bowl_intent_plan`/field/bowling lookups stay `for_over` — spec DS3.)

- [ ] **Step 4: Run suite, verify green, count climbs +4 (419 → 423).** If the directional test is knife-edge, widen N to 600 / raise the chase target to 180 — same mechanic, more signal (project precedent from the Form-window test).

- [ ] **Step 5: Commit** — `git add scripts/domain/innings_resolver.gd tests/unit/test_innings_resolver.gd && git commit -m "E2: batting intent reads match state (for_state at the single call site); chase-escalation directional test"`

---

### Task 3: PolicySearch adaptive-space helpers

**Files:**
- Modify: `scripts/harness/policy_search.gd`
- Test: `tests/unit/test_policy_search.gd` (append)

- [ ] **Step 1: Write the failing tests** — append to `tests/unit/test_policy_search.gd`:

```gdscript
# --- E2 adaptive space (spec §5 DS4) ---

func test_enumerate_adaptive_320_unique() -> void:
	var ps := PolicySearch.enumerate_adaptive()
	assert_eq(ps.size(), 320, "4 bases x 5 up x 4 down x 4 collapse")
	var seen := {}
	for p in ps:
		seen[PolicySearch.label_of(p)] = true
	assert_eq(seen.size(), 320, "labels unique")

func test_adaptive_plan_carries_rules() -> void:
	var p := PolicySearch.static_equilibrium()
	p["up"] = 9.0
	p["down"] = 6.0
	p["collapse"] = 4
	var ip := PolicySearch.intent_plan_of(p)
	assert_eq(ip.chase_up_rr, 9.0)
	assert_eq(ip.chase_down_rr, 6.0)
	assert_eq(ip.collapse_wkts, 4)

func test_static_policy_builds_disabled_rules() -> void:
	var ip := PolicySearch.intent_plan_of(PolicySearch.textbook())
	assert_eq(ip.chase_up_rr, -1.0)
	assert_eq(ip.collapse_wkts, -1)

func test_static_equilibrium_literal() -> void:
	# bowling-balance fixed point: B/A/B·P/S/P
	assert_eq(PolicySearch.label_of(PolicySearch.static_equilibrium()), "B/A/B·P/S/P")

func test_adaptive_label_appends_rules() -> void:
	var p := PolicySearch.static_equilibrium()
	p["up"] = 9.0
	p["down"] = -1.0
	p["collapse"] = 4
	assert_eq(PolicySearch.label_of(p), "B/A/B·P/S/P+u9d-c4")
```

- [ ] **Step 2: Run suite, verify the new tests FAIL** (missing helpers)

- [ ] **Step 3: Implement** — append to `scripts/harness/policy_search.gd` and extend the two existing builders:

```gdscript
# --- E2 adaptive space (spec 2026-06-11-stateaware-policy-7cE2-design.md §5) ---
# An adaptive policy = a static policy dict + optional rule keys "up"/"down"/
# "collapse" (IntentPlan.chase_up_rr / chase_down_rr / collapse_wkts; -1 = off).

const RULE_UP := [-1.0, 8.0, 9.0, 10.0, 11.0]
const RULE_DOWN := [-1.0, 5.0, 6.0, 7.0]
const RULE_COLLAPSE := [-1, 3, 4, 5]


# The bowling-balance static equilibrium: B/A/B·P/S/P.
static func static_equilibrium() -> Dictionary:
	return {
		"pp_intent": BallResolver.Intent.BALANCED,
		"mid_intent": BallResolver.Intent.AGGRESSIVE,
		"death_intent": BallResolver.Intent.BALANCED,
		"pp_bowl": BowlingPlan.Kind.PACE,
		"mid_bowl": BowlingPlan.Kind.SPIN,
		"death_bowl": BowlingPlan.Kind.PACE,
	}


# The 4 intent bases (DS4), all bowling textbook P/S/P.
static func adaptive_bases() -> Array:
	var eq := static_equilibrium()
	var runner_up := static_equilibrium()
	runner_up["death_intent"] = BallResolver.Intent.AGGRESSIVE  # B/A/A
	return [eq, runner_up, textbook(), balanced()]


# 4 bases x 5 up x 4 down x 4 collapse = 320 adaptive candidates.
static func enumerate_adaptive() -> Array:
	var out: Array = []
	for base in adaptive_bases():
		for up in RULE_UP:
			for down in RULE_DOWN:
				for col in RULE_COLLAPSE:
					var p := (base as Dictionary).duplicate()
					p["up"] = up
					p["down"] = down
					p["collapse"] = col
					out.append(p)
	return out
```

Extend `intent_plan_of` (rule keys optional → statics unaffected):

```gdscript
static func intent_plan_of(p: Dictionary) -> IntentPlan:
	var plan := IntentPlan.new()
	plan.powerplay = p["pp_intent"]
	plan.middle = p["mid_intent"]
	plan.death = p["death_intent"]
	plan.chase_up_rr = p.get("up", -1.0)
	plan.chase_down_rr = p.get("down", -1.0)
	plan.collapse_wkts = p.get("collapse", -1)
	return plan
```

Extend `label_of` (append a rule suffix only when rule keys exist; `-` = off, floats printed as ints since the grids are whole numbers):

```gdscript
static func label_of(p: Dictionary) -> String:
	var s := "%s/%s/%s·%s/%s/%s" % [
		INTENT_LETTER[p["pp_intent"]], INTENT_LETTER[p["mid_intent"]], INTENT_LETTER[p["death_intent"]],
		KIND_LETTER[p["pp_bowl"]], KIND_LETTER[p["mid_bowl"]], KIND_LETTER[p["death_bowl"]],
	]
	if p.has("up"):
		var u := "-" if p["up"] < 0.0 else str(int(p["up"]))
		var d := "-" if p["down"] < 0.0 else str(int(p["down"]))
		var c := "-" if p["collapse"] < 0 else str(int(p["collapse"]))
		s += "+u%sd%sc%s" % [u, d, c]
	return s
```

- [ ] **Step 4: Run suite, verify green, count climbs +5 (423 → 428).** Note: `test_enumerate_adaptive_320_unique` relies on the label suffix for uniqueness — rules-off duplicates of the 4 bases differ only in suffix `+u-d-c-`, which is fine (one per base).

- [ ] **Step 5: Commit** — `git add scripts/harness/policy_search.gd tests/unit/test_policy_search.gd && git commit -m "E2: PolicySearch adaptive space (4 bases x 80 rule combos), static_equilibrium literal, rule-aware builders"`

---

### Task 4: The E2 oracle `tools/sweep_policy_state.gd`

**Files:**
- Create: `tools/sweep_policy_state.gd` (+ commit its `.gd.uid` after `--import`)

No unit tests (tools convention); verified by the `E2_QUICK=1` smoke run.

- [ ] **Step 1: Write the oracle** — `tools/sweep_policy_state.gd`, the E1 oracle adapted per spec §5:

```gdscript
extends SceneTree

# E2 oracle (spec 2026-06-11-stateaware-policy-7cE2-design.md §5): does
# state-aware batting intent dethrone the static equilibrium B/A/B·P/S/P?
# Pure team-vs-team (no hero), even ★3, no jokers/Boost/DRS — the E1 frame.
# Phases:
#   1  screen all 320 adaptive candidates vs the fixed static equilibrium
#   2  refine top K + the static-eq incumbent on fresh seeds -> DETHRONE headline
#   3  iterated best response in the JOINT space (216 static + 320 adaptive)
#   4  gap arms: new-eq vs naive / textbook / static-eq / balanced + mirrors
#   5  statted-hero validation (5/5/5/5, adaptive vs static plans)
# Prints DATA JSON for docs/mockups/policy-state-v1.html.
# Quick smoke: E2_QUICK=1. Run:
# /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/sweep_policy_state.gd

const SCREEN_N := 400
const REFINE_N := 4000
const TOP_K := 12
const MAX_ITERS := 4
const GAP_N := 4000
const CONVERGE_EPS := 0.015

var _tuning: BallTuning
var _itun: InningsTuning
var _tour: TourDistribution
var _statics: Array
var _adaptives: Array
var _joint: Array

var _screen_n: int
var _refine_n: int
var _gap_n: int
var _max_iters: int


func _init() -> void:
	_tuning = BallTuning.new()
	_itun = InningsTuning.new()
	_tour = TourDistribution.new()
	_tour.mean = 5
	_tour.spread = 1.5
	_tour.noise = 1
	_statics = PolicySearch.enumerate()
	_adaptives = PolicySearch.enumerate_adaptive()
	_joint = _statics + _adaptives

	var quick := OS.get_environment("E2_QUICK") == "1"
	_screen_n = 60 if quick else SCREEN_N
	_refine_n = 300 if quick else REFINE_N
	_gap_n = 300 if quick else GAP_N
	_max_iters = 2 if quick else MAX_ITERS
	if quick:
		print("[quick mode]")

	var t0 := Time.get_ticks_msec()
	var static_eq := PolicySearch.static_equilibrium()

	# Phase 1+2 — adaptive grid vs the static equilibrium.
	print("== phase 1: screen %d adaptives vs static eq ==" % _adaptives.size())
	var r0 := _best_response_in(_adaptives, static_eq, static_eq, true, 0)
	var landscape: Array = r0["landscape"]
	var best_adaptive: Dictionary = r0["best_policy"]
	var dethrone: float = r0["best_win"]
	var eq_mirror_win: float = r0["cur_win"]  # static eq measured on the same fresh seeds
	print("DETHRONE: best adaptive %s wins %.1f%% vs static eq (static-eq incumbent reads %.1f%%)" % [
		PolicySearch.label_of(best_adaptive), 100.0 * dethrone, 100.0 * eq_mirror_win])

	# Phase 3 — iterated best response in the joint space.
	print("\n== phase 3: joint-space self-play ==")
	var cur_a := best_adaptive
	var cur_b := static_eq
	var trajectory: Array = []
	var converged_streak := 0
	var equilibrium := false
	for iter in range(_max_iters):
		var responder_is_a := iter % 2 == 1  # B responds first (does static counter adaptive?)
		var fixed := cur_b if responder_is_a else cur_a
		var cur := cur_a if responder_is_a else cur_b
		var r := _best_response_in(_joint, cur, fixed, responder_is_a, 1 + iter)
		var gain: float = r["best_win"] - r["cur_win"]
		var kept: bool = r["best_label"] == PolicySearch.label_of(cur) or gain < CONVERGE_EPS
		trajectory.append({
			"iter": iter, "side": "A" if responder_is_a else "B",
			"cur": PolicySearch.label_of(cur), "cur_win": r["cur_win"],
			"best": r["best_label"], "best_win": r["best_win"], "kept": kept,
		})
		print("iter %d side %s: cur %s %.1f%% -> best %s %.1f%% (gain %.1f pts) %s" % [
			iter, "A" if responder_is_a else "B", PolicySearch.label_of(cur),
			100.0 * r["cur_win"], r["best_label"], 100.0 * r["best_win"],
			100.0 * gain, "KEEP" if kept else "ADOPT"])
		if kept:
			converged_streak += 1
			if converged_streak >= 2:
				equilibrium = true
				break
		else:
			converged_streak = 0
			if responder_is_a:
				cur_a = r["best_policy"]
			else:
				cur_b = r["best_policy"]

	print("\n== self-play result: %s ==" % ("EQUILIBRIUM" if equilibrium else "NO fixed point in %d iters" % _max_iters))
	print("A: %s   B: %s" % [PolicySearch.label_of(cur_a), PolicySearch.label_of(cur_b)])

	# Phase 4 — gap arms (E3 ladder anchors).
	var gap_arms := [
		{"name": "neweq vs neweq", "config": {"a": cur_a, "b": cur_b}},
		{"name": "neweq vs static-eq", "config": {"a": cur_a, "b": static_eq}},
		{"name": "neweq vs naive", "config": {"a": cur_a, "b": "random"}},
		{"name": "neweq vs textbook", "config": {"a": cur_a, "b": PolicySearch.textbook()}},
		{"name": "neweq vs balanced", "config": {"a": cur_a, "b": PolicySearch.balanced()}},
		{"name": "adaptive mirror", "config": {"a": cur_a, "b": cur_a}},
		{"name": "static-eq mirror", "config": {"a": static_eq, "b": static_eq}},
	]
	var gap_out := Sweep.run(gap_arms, _gap_n, _scenario, 900001)
	var gaps: Array = []
	print("\narm                      win%   tie%")
	for g in gap_out:
		var w := _rate(g["records"], "a_won")
		var t := _rate(g["records"], "tie")
		gaps.append({"name": g["name"], "win": w, "tie": t})
		print("%-23s %5.1f  %5.1f" % [g["name"], 100.0 * w, 100.0 * t])

	# Phase 5 — statted-hero validation.
	var hero_arms := [
		{"name": "hero+neweq vs static-eq", "config": {"a": cur_a, "b": static_eq, "hero": true}},
		{"name": "hero+static-eq vs static-eq", "config": {"a": static_eq, "b": static_eq, "hero": true}},
	]
	var hero_out := Sweep.run(hero_arms, _gap_n, _scenario, 910001)
	var heroes: Array = []
	print("")
	for h in hero_out:
		var w := _rate(h["records"], "a_won")
		heroes.append({"name": h["name"], "win": w})
		print("%-27s %5.1f" % [h["name"], 100.0 * w])

	print("\nelapsed %.1f min" % ((Time.get_ticks_msec() - t0) / 60000.0))
	print("DATA = " + JSON.stringify({
		"landscape": landscape, "trajectory": trajectory,
		"gaps": gaps, "heroes": heroes,
		"a": PolicySearch.label_of(cur_a), "b": PolicySearch.label_of(cur_b),
		"dethrone": dethrone, "dethrone_label": PolicySearch.label_of(best_adaptive),
		"equilibrium": equilibrium,
		"screen_n": _screen_n, "refine_n": _refine_n, "gap_n": _gap_n,
	}))
	quit()


# Screen `space` for the responder vs the fixed policy; refine TOP_K + the
# incumbent `cur` on fresh seeds. Same shape as E1's _best_response.
func _best_response_in(space: Array, cur: Dictionary, fixed: Dictionary, responder_is_a: bool, iter: int) -> Dictionary:
	var arms: Array = []
	for p in space:
		var cfg := {"a": p, "b": fixed} if responder_is_a else {"a": fixed, "b": p}
		arms.append({"name": PolicySearch.label_of(p), "config": cfg})
	var screened := Sweep.run(arms, _screen_n, _scenario, 1 + iter * 1000)
	var field := "a_won" if responder_is_a else "b_won"
	var rates: Array = []
	for s in screened:
		rates.append(_rate(s["records"], field))
	var landscape: Array = []
	for i in space.size():
		landscape.append({"label": arms[i]["name"], "win": rates[i]})

	var order := range(space.size())
	order.sort_custom(func(x, y): return rates[x] > rates[y])
	var finalists: Array = []
	for k in range(TOP_K):
		finalists.append(space[order[k]])
	finalists.append(cur)

	var ref_arms: Array = []
	for p in finalists:
		var cfg := {"a": p, "b": fixed} if responder_is_a else {"a": fixed, "b": p}
		ref_arms.append({"name": PolicySearch.label_of(p), "config": cfg})
	var refined := Sweep.run(ref_arms, _refine_n, _scenario, 500000 + iter * 1000)
	var ref_rates: Array = []
	for s in refined:
		ref_rates.append(_rate(s["records"], field))
	var cur_win: float = ref_rates[ref_rates.size() - 1]
	var bi := PolicySearch.best_index(ref_rates)
	return {
		"best_policy": finalists[bi], "best_label": ref_arms[bi]["name"],
		"best_win": ref_rates[bi], "cur_win": cur_win, "landscape": landscape,
	}


# One match. config: {a: policy|"random", b: policy|"random", hero?: true}.
# Identical frame to the E1 oracle's _scenario (random = naive static draw).
func _scenario(config, rng: RandomNumberGenerator) -> Dictionary:
	var pol_a = config["a"]
	var pol_b = config["b"]
	if pol_a is String:
		pol_a = PolicySearch.random_policy(_statics, rng)
	if pol_b is String:
		pol_b = PolicySearch.random_policy(_statics, rng)

	var m: MatchResult
	if config.get("hero", false):
		var a := Attributes.new()
		a.power = 5
		a.composure = 5
		a.attack = 5
		a.control = 5
		var pt := Team.new()
		pt.stars = 3.0
		var ot := Team.new()
		ot.stars = 3.0
		m = MatchResolver.simulate_match_teams(
			a, pt, ot, _tour, _tuning, _itun, rng,
			PolicySearch.intent_plan_of(pol_a), PolicySearch.bowling_plan_of(pol_a),
			[], null, null,
			PolicySearch.intent_plan_of(pol_b), null, DRSPolicy.new(), null,
			null, DRSPolicy.new(), -1,
			PolicySearch.bowling_plan_of(pol_b))
	else:
		var a_bats_first := rng.randf() < 0.5
		var pt2 := Team.new()
		pt2.stars = 3.0
		var ot2 := Team.new()
		ot2.stars = 3.0
		var a_bat := pt2.batting_strength(_tour, rng)
		var a_bowl := pt2.bowling_strength(_tour, rng)
		var b_bat := ot2.batting_strength(_tour, rng)
		var b_bowl := ot2.bowling_strength(_tour, rng)
		var ref3 := _tour.percentile(3.0 / 5.0)
		m = MatchResolver.simulate_match(
			null,
			a_bat, a_bowl, a_bowl,
			b_bat, b_bowl, b_bowl,
			a_bats_first, _tuning, _itun, rng,
			PolicySearch.intent_plan_of(pol_a), PolicySearch.bowling_plan_of(pol_a),
			[], null, null,
			PolicySearch.intent_plan_of(pol_b), null, null, null,
			Team.standard_xi(), Team.standard_xi(), a_bat - ref3, b_bat - ref3,
			null, null,
			PolicySearch.bowling_plan_of(pol_b))

	return {
		"a_won": 1 if m.outcome == MatchResult.Outcome.PLAYER_WIN else 0,
		"b_won": 1 if m.outcome == MatchResult.Outcome.OPPONENT_WIN else 0,
		"tie": 1 if m.outcome == MatchResult.Outcome.TIE else 0,
	}


func _rate(records: Array, field: String) -> float:
	var s := 0
	for r in records:
		s += r[field]
	return float(s) / records.size()
```

- [ ] **Step 2: Import + smoke** — quit the editor if open (`pgrep -x Godot`), then:
`/Applications/Godot.app/Contents/MacOS/Godot --headless --import --path . && E2_QUICK=1 /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/sweep_policy_state.gd`
Expected: phases print, a DATA line at the end, no script errors (~3–5 min; the joint screen is 536 arms even in quick mode).

- [ ] **Step 3: Run the full suite once more (still 428, no regressions), then commit** — `git add tools/sweep_policy_state.gd tools/sweep_policy_state.gd.uid && git commit -m "E2 oracle: adaptive-grid screen vs static eq + joint-space self-play + gap/hero arms"`

---

### Task 5: Viz `docs/mockups/policy-state-v1.html`

**Files:**
- Create: `docs/mockups/policy-state-v1.html`

- [ ] **Step 1: Build the viewer** — same pattern as `policy-selfplay-v1.html` (a static HTML file with a `DATA = {...}` constant pasted from the oracle): a **dethrone headline card** (best adaptive vs static eq), **gap/hero bar charts**, the **adaptive landscape** as 4 base-grouped strips (win% per rule combo, rules-off anchor highlighted), and the **trajectory list**. Plain inline JS/CSS, no dependencies, dark theme matching the existing mockups. Seed it with the quick-run DATA; replace with the full run at close-out.

- [ ] **Step 2: Eyeball it in a browser** (open the file; bars/strips render, labels legible).

- [ ] **Step 3: Commit** — `git add docs/mockups/policy-state-v1.html && git commit -m "E2 viz: dethrone headline + adaptive landscape + gap bars"`

---

### Task 6: Full oracle run + findings + close-out

- [ ] **Step 1: Full run, backgrounded** (~25–35 min): `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/sweep_policy_state.gd` (no `E2_QUICK`). NO other Godot process during the run.
- [ ] **Step 2: Env smoke (A5):** `tools/probe_scoring_env.gd` after the oracle finishes (one process at a time) — must still read 153.5 / RR 8.13 / 6.26 wkts band.
- [ ] **Step 3: Write spec §10 findings** — dethrone number, the winning rule combo, joint-space equilibrium, gap-ladder table (E3 anchors), hero transfer, mirrors fairness; honest recording if adaptive ≤ noise (A3's fallback).
- [ ] **Step 4: Paste final DATA into the viz; update PROJECT_ROADMAP.md** (status line, Last closed, Next session handoff → next queued rung = card-rescale per the 2026-06-11 seed).
- [ ] **Step 5: Commit docs, push, open PR, merge once green, sync `main`, delete branch.**

---

## Self-review notes

- Spec coverage: §3→Task 1, §4→Task 2, §5 DS4→Task 3, §5 DS5→Task 4, viz→Task 5, §6/§10→Task 6. A1 is Task 1 test 1 + Task 2 test 1 + the untouched 411; A2 is Task 2's directional; A3/A4/A6 are oracle phases 2/4; A5 is Task 6 step 2.
- Type consistency: `for_state(over, total, wickets, balls, target, max_balls)` used identically in Tasks 1, 2, and the resolver call; rule keys `"up"/"down"/"collapse"` consistent across Tasks 3–4.
- Expected suite trajectory: 411 → 419 → 423 → 428.
