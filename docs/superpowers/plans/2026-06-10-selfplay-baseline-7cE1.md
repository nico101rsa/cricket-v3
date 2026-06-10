# Self-Play Baseline Policy Search (7c-E1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Find the strongest static no-joker game plan by brute-force + iterated best-response self-play, measure the ADR 0003 optimal-vs-naive skill gap, and answer whether the static layer is "solved".

**Architecture:** One additive sim seam (`opp_bowling_plan`) makes both sides fully symmetric in the two intrinsic levers (batting Intent × pace/spin rotation = 216 static policies/side). A pure `PolicySearch` helper enumerates and selects; a SceneTree oracle (`tools/sweep_policy_selfplay.gd`) runs screen → refine → best-response → skill-gap phases on the existing `Sweep` platform; a viz shows the 216-policy landscape. Spec: `docs/superpowers/specs/2026-06-10-selfplay-baseline-7cE1-design.md`.

**Tech Stack:** Godot 4.6.3 GDScript (tabs), GUT 9.6, existing harness (`Sweep`, `MatchResolver`, `Team`, `DRSPolicy`).

**Conventions that bite:** run `--import` once after adding any script; ONE Godot process at a time (quit the editor first; chain `--import && test` in a single command); judge red by parse-error, green by total count climbing past **388** + `All tests passed`; commit `.gd.uid` for `scripts/`+`tools/` but NOT `tests/`.

Test suite command (used in every task):

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --import --path . > /dev/null 2>&1; /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit 2>&1 | tail -5
```

---

### Task 1: `opp_bowling_plan` seam in MatchResolver

The opponent's bowling rotation is hardcoded `BowlingPlan.textbook()`; self-play needs it caller-suppliable. Additive trailing param, byte-identical when null.

**Files:**
- Modify: `scripts/domain/match_resolver.gd` (signatures of `simulate_match` + `simulate_match_teams`, the `rotate` block)
- Test: `tests/unit/test_opp_bowling_plan.gd` (new — no `.uid` for test files)

- [ ] **Step 1: Write the failing tests**

`tests/unit/test_opp_bowling_plan.gd`:

```gdscript
extends GutTest

# E1 seam (spec 2026-06-10-selfplay-baseline-7cE1-design.md D6): opp_bowling_plan
# lets the opponent rotate a caller-supplied pace/spin plan instead of the
# hardcoded textbook default. Null == textbook (when rotating) == today.

var _tuning := BallTuning.new()
var _itun := InningsTuning.new()


func _rng(s: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	return r


func _attrs() -> Attributes:
	var a := Attributes.new()
	a.power = 5
	a.composure = 5
	a.attack = 5
	a.control = 5
	return a


func _match(seed_v: int, bats_first: bool, player_plan: BowlingPlan, opp_plan: BowlingPlan) -> MatchResult:
	return MatchResolver.simulate_match(
		_attrs(), 5, 5.0, 5.0, 5, 5.0, 5.0, bats_first, _tuning, _itun, _rng(seed_v),
		null, player_plan, [], null, null, null, null, null, null,
		[], [], 0, 0, null, null, opp_plan)


# Null opp plan must equal an explicit textbook opp plan — the current behaviour.
func test_null_opp_plan_equals_textbook() -> void:
	for s in range(11, 16):
		var a := _match(s, true, BowlingPlan.textbook(), null)
		var b := _match(s, true, BowlingPlan.textbook(), BowlingPlan.textbook())
		assert_eq(a.innings1.total, b.innings1.total, "innings1 total seed %d" % s)
		assert_eq(a.innings2.total, b.innings2.total, "innings2 total seed %d" % s)
		assert_eq(a.innings1.wickets, b.innings1.wickets, "innings1 wkts seed %d" % s)
		assert_eq(a.innings2.wickets, b.innings2.wickets, "innings2 wkts seed %d" % s)


# Player bats SECOND -> innings1 = Player's team bowling (opp plan irrelevant
# there), innings2 = opponent bowling at the Player's batting. So varying the
# opp plan must leave innings1 byte-identical (isolation) and must move
# innings2 for at least one seed (the lever is real).
func test_opp_plan_routes_to_opponents_bowling_innings_only() -> void:
	var moved := 0
	for s in range(21, 31):
		var pace := _match(s, false, BowlingPlan.textbook(), BowlingPlan.pace_only())
		var spin := _match(s, false, BowlingPlan.textbook(), BowlingPlan.spin_only())
		assert_eq(pace.innings1.total, spin.innings1.total, "innings1 isolated seed %d" % s)
		assert_eq(pace.innings1.wickets, spin.innings1.wickets, "innings1 wkts isolated seed %d" % s)
		if pace.innings2.total != spin.innings2.total or pace.innings2.wickets != spin.innings2.wickets:
			moved += 1
	assert_gt(moved, 0, "opp plan never moved the opponent's bowling innings")


# Opp plan set with NO player plan: rotation still activates (either side's
# plan turns it on), deterministically.
func test_opp_plan_alone_activates_rotation_deterministically() -> void:
	var a := _match(7, true, null, BowlingPlan.spin_only())
	var b := _match(7, true, null, BowlingPlan.spin_only())
	assert_eq(a.innings1.total, b.innings1.total)
	assert_eq(a.innings2.total, b.innings2.total)
	assert_eq(a.outcome, b.outcome)
```

- [ ] **Step 2: Run the suite to verify red**

Run the suite command. Expected: `SCRIPT ERROR: Parse Error` is NOT the signal here (no new class) — the signal is failing assertions / "too many arguments" script errors in the new test file. Total count must NOT yet include passing versions of these 3 tests.

- [ ] **Step 3: Implement the seam**

In `scripts/domain/match_resolver.gd`:

(a) `simulate_match` signature — add trailing param after `opp_drs_policy: DRSPolicy = null`:

```gdscript
		opp_drs_policy: DRSPolicy = null,
		opp_bowling_plan: BowlingPlan = null
```

(b) the rotate block (currently `var rotate := player_bowling_plan != null` … `ai_plan = BowlingPlan.textbook()`) becomes:

```gdscript
	# Rotation activates when EITHER side supplies a plan; a side with a null
	# plan rotates textbook() (the previous hardcoded opponent behaviour, now
	# symmetric — E1 spec D6). Both null -> no rotation, byte-identical to 4b.
	var rotate := player_bowling_plan != null or opp_bowling_plan != null
	var opp_bowl: BowlingAttack = null
	var player_bowl: BowlingAttack = null
	var ai_plan: BowlingPlan = null
	var p_plan: BowlingPlan = null
	if rotate:
		# BowlingAttack works in integer pace/spin profiles; round the (now float) scalars.
		# Rotation is opt-in and not used in the balance sweep, so exact conservation lives
		# in the constant-scalar path below, not here.
		opp_bowl = BowlingAttack.new(roundi(opp_attack), roundi(opp_control))
		player_bowl = BowlingAttack.new(roundi(player_team_attack), roundi(player_team_control))
		ai_plan = opp_bowling_plan if opp_bowling_plan != null else BowlingPlan.textbook()
		p_plan = player_bowling_plan if player_bowling_plan != null else BowlingPlan.textbook()
```

(c) in BOTH innings call sites, replace the bowling-plan argument for the Player's bowling innings: `player_bowling_plan` → `p_plan` (two places — the innings where the opposition bats). The `ai_plan` argument (Player's batting innings) is already correct. Do NOT touch any other argument.

(d) `simulate_match_teams` — add trailing param after `force_player_bats_first: int = -1`:

```gdscript
		force_player_bats_first: int = -1,
		opp_bowling_plan: BowlingPlan = null
```

and extend its delegate call's last line: `opp_boost_plan, opp_drs_policy)` → `opp_boost_plan, opp_drs_policy, opp_bowling_plan)`.

- [ ] **Step 4: Run the suite to verify green**

Run the suite command. Expected: `All tests passed`, total ≥ **391** (388 + 3). The untouched 388 prove byte-compat (null path identical).

- [ ] **Step 5: Commit**

```sh
git add scripts/domain/match_resolver.gd tests/unit/test_opp_bowling_plan.gd
git commit -m "E1 Task 1: opp_bowling_plan seam — symmetric caller-set opponent rotation, null == textbook (byte-identical)"
```

---

### Task 2: `PolicySearch` pure helpers

**Files:**
- Create: `scripts/harness/policy_search.gd` (+ its generated `.gd.uid`)
- Test: `tests/unit/test_policy_search.gd`

- [ ] **Step 1: Write the failing tests**

`tests/unit/test_policy_search.gd`:

```gdscript
extends GutTest

# E1 (spec D7): the 216-policy enumeration + selection helpers are pure and tiny;
# these tests pin the contract the oracle leans on.


func test_enumerate_returns_216_unique_policies() -> void:
	var ps := PolicySearch.enumerate()
	assert_eq(ps.size(), 216)
	var seen := {}
	for p in ps:
		seen[PolicySearch.label_of(p)] = true
	assert_eq(seen.size(), 216, "labels (and so policies) must be unique")


func test_plan_construction_maps_fields() -> void:
	var p := {
		"pp_intent": BallResolver.Intent.AGGRESSIVE,
		"mid_intent": BallResolver.Intent.DEFENSIVE,
		"death_intent": BallResolver.Intent.BALANCED,
		"pp_bowl": BowlingPlan.Kind.SPIN,
		"mid_bowl": BowlingPlan.Kind.PACE,
		"death_bowl": BowlingPlan.Kind.SPIN,
	}
	var ip := PolicySearch.intent_plan_of(p)
	assert_eq(ip.for_over(3), BallResolver.Intent.AGGRESSIVE)
	assert_eq(ip.for_over(10), BallResolver.Intent.DEFENSIVE)
	assert_eq(ip.for_over(18), BallResolver.Intent.BALANCED)
	var bp := PolicySearch.bowling_plan_of(p)
	assert_eq(bp.for_over(3), BowlingPlan.Kind.SPIN)
	assert_eq(bp.for_over(10), BowlingPlan.Kind.PACE)
	assert_eq(bp.for_over(18), BowlingPlan.Kind.SPIN)


func test_textbook_policy_matches_plan_factories() -> void:
	var t := PolicySearch.textbook()
	var ip := PolicySearch.intent_plan_of(t)
	var ref := IntentPlan.textbook()
	assert_eq(ip.powerplay, ref.powerplay)
	assert_eq(ip.middle, ref.middle)
	assert_eq(ip.death, ref.death)
	var bp := PolicySearch.bowling_plan_of(t)
	var bref := BowlingPlan.textbook()
	assert_eq(bp.powerplay, bref.powerplay)
	assert_eq(bp.middle, bref.middle)
	assert_eq(bp.death, bref.death)


func test_best_index_picks_max_first_on_tie() -> void:
	assert_eq(PolicySearch.best_index([0.40, 0.55, 0.31]), 1)
	assert_eq(PolicySearch.best_index([0.50, 0.42, 0.50]), 0)


func test_random_policy_in_range_and_seeded() -> void:
	var ps := PolicySearch.enumerate()
	var r1 := RandomNumberGenerator.new()
	r1.seed = 99
	var r2 := RandomNumberGenerator.new()
	r2.seed = 99
	var a := PolicySearch.random_policy(ps, r1)
	var b := PolicySearch.random_policy(ps, r2)
	assert_eq(PolicySearch.label_of(a), PolicySearch.label_of(b), "same seed -> same draw")
	assert_true(ps.has(a))
```

- [ ] **Step 2: Run the suite to verify red**

Expected red signal: `SCRIPT ERROR: Parse Error: Identifier "PolicySearch" not declared` (GUT logs it and skips the file; total stays at 391).

- [ ] **Step 3: Implement**

`scripts/harness/policy_search.gd`:

```gdscript
class_name PolicySearch
extends RefCounted

# E1 self-play helpers (spec 2026-06-10-selfplay-baseline-7cE1-design.md D7).
# A static no-joker policy = one batting Intent per phase x one bowler Kind per
# phase = 27 x 8 = 216. Pure functions only; the oracle composes them.

const INTENTS := [BallResolver.Intent.DEFENSIVE, BallResolver.Intent.BALANCED, BallResolver.Intent.AGGRESSIVE]
const KINDS := [BowlingPlan.Kind.PACE, BowlingPlan.Kind.SPIN]

const INTENT_LETTER := {
	BallResolver.Intent.DEFENSIVE: "D",
	BallResolver.Intent.BALANCED: "B",
	BallResolver.Intent.AGGRESSIVE: "A",
}
const KIND_LETTER := {
	BowlingPlan.Kind.PACE: "P",
	BowlingPlan.Kind.SPIN: "S",
}


# All 216 policies in a stable order (intent loops outer, bowling inner).
static func enumerate() -> Array:
	var out: Array = []
	for pp_i in INTENTS:
		for mid_i in INTENTS:
			for death_i in INTENTS:
				for pp_b in KINDS:
					for mid_b in KINDS:
						for death_b in KINDS:
							out.append({
								"pp_intent": pp_i, "mid_intent": mid_i, "death_intent": death_i,
								"pp_bowl": pp_b, "mid_bowl": mid_b, "death_bowl": death_b,
							})
	return out


static func intent_plan_of(p: Dictionary) -> IntentPlan:
	var plan := IntentPlan.new()
	plan.powerplay = p["pp_intent"]
	plan.middle = p["mid_intent"]
	plan.death = p["death_intent"]
	return plan


static func bowling_plan_of(p: Dictionary) -> BowlingPlan:
	var plan := BowlingPlan.new()
	plan.powerplay = p["pp_bowl"]
	plan.middle = p["mid_bowl"]
	plan.death = p["death_bowl"]
	return plan


# Compact display label, e.g. "A/B/A·P/S/P" (textbook).
static func label_of(p: Dictionary) -> String:
	return "%s/%s/%s·%s/%s/%s" % [
		INTENT_LETTER[p["pp_intent"]], INTENT_LETTER[p["mid_intent"]], INTENT_LETTER[p["death_intent"]],
		KIND_LETTER[p["pp_bowl"]], KIND_LETTER[p["mid_bowl"]], KIND_LETTER[p["death_bowl"]],
	]


# The textbook start point: attack PP, build middle, slog death; pace/spin/pace.
static func textbook() -> Dictionary:
	return {
		"pp_intent": BallResolver.Intent.AGGRESSIVE,
		"mid_intent": BallResolver.Intent.BALANCED,
		"death_intent": BallResolver.Intent.AGGRESSIVE,
		"pp_bowl": BowlingPlan.Kind.PACE,
		"mid_bowl": BowlingPlan.Kind.SPIN,
		"death_bowl": BowlingPlan.Kind.PACE,
	}


# All-BALANCED intent + textbook rotation (the pre-rung-4a "no plan" player).
static func balanced() -> Dictionary:
	return {
		"pp_intent": BallResolver.Intent.BALANCED,
		"mid_intent": BallResolver.Intent.BALANCED,
		"death_intent": BallResolver.Intent.BALANCED,
		"pp_bowl": BowlingPlan.Kind.PACE,
		"mid_bowl": BowlingPlan.Kind.SPIN,
		"death_bowl": BowlingPlan.Kind.PACE,
	}


# Argmax over win rates; ties go to the LOWER index (stable).
static func best_index(win_rates: Array) -> int:
	var best := 0
	for i in range(1, win_rates.size()):
		if win_rates[i] > win_rates[best]:
			best = i
	return best


# The ADR 0003 "naive" player: one uniform draw from the policy list per match.
static func random_policy(policies: Array, rng: RandomNumberGenerator) -> Dictionary:
	return policies[rng.randi_range(0, policies.size() - 1)]
```

- [ ] **Step 4: Run the suite to verify green**

Expected: `All tests passed`, total ≥ **396** (391 + 5).

- [ ] **Step 5: Commit**

```sh
git add scripts/harness/policy_search.gd scripts/harness/policy_search.gd.uid tests/unit/test_policy_search.gd
git commit -m "E1 Task 2: PolicySearch — 216-policy enumeration, plan builders, argmax, naive draw"
```

---

### Task 3: the self-play oracle

A diagnostic SceneTree tool (no unit tests — verified by a quick-mode smoke run, like every other oracle).

**Files:**
- Create: `tools/sweep_policy_selfplay.gd` (+ `.gd.uid`)

- [ ] **Step 1: Write the oracle**

`tools/sweep_policy_selfplay.gd`:

```gdscript
extends SceneTree

# E1 oracle (spec 2026-06-10-selfplay-baseline-7cE1-design.md): self-play search
# over the 216 static no-joker policies. Pure team-vs-team (no statted Player,
# spec D2), even ★3, fair-fight DRS both sides, no Boost (D1).
# Phases:
#   1  screen all 216 responses vs the fixed opponent (SCREEN_N paired matches)
#   2  refine the top K + the current policy on fresh seeds (REFINE_N)
#   3  adopt the best response; alternate sides until fixed point or MAX_ITERS
#   4  skill-gap arms: equilibrium vs naive / textbook / balanced (GAP_N)
#   5  statted-hero validation (5/5/5/5 hero, equilibrium vs textbook plans)
# Prints progress per phase + a DATA JSON block for docs/mockups/policy-selfplay-v1.html.
# Quick smoke: E1_QUICK=1 (small Ns, 2 iterations, ~1-2 min).
# Run: /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/sweep_policy_selfplay.gd

const SCREEN_N := 400
const REFINE_N := 4000
const TOP_K := 12
const MAX_ITERS := 6
const GAP_N := 4000
const CONVERGE_EPS := 0.015  # refined improvement below this = the side keeps its policy

var _tuning: BallTuning
var _itun: InningsTuning
var _tour: TourDistribution
var _policies: Array

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
	_policies = PolicySearch.enumerate()

	var quick := OS.get_environment("E1_QUICK") == "1"
	_screen_n = 60 if quick else SCREEN_N
	_refine_n = 300 if quick else REFINE_N
	_gap_n = 300 if quick else GAP_N
	_max_iters = 2 if quick else MAX_ITERS
	if quick:
		print("[quick mode]")

	var t0 := Time.get_ticks_msec()
	var cur_a := PolicySearch.textbook()
	var cur_b := PolicySearch.textbook()
	var trajectory: Array = []
	var landscape: Array = []  # iteration-1 screening of side A, for the viz
	var converged_streak := 0
	var equilibrium := false

	for iter in range(_max_iters):
		var responder_is_a := iter % 2 == 0
		var fixed := cur_b if responder_is_a else cur_a
		var cur := cur_a if responder_is_a else cur_b
		var r := _best_response(cur, fixed, responder_is_a, iter)
		if iter == 0:
			landscape = r["landscape"]
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
			if converged_streak >= 2:  # neither side wants to move
				equilibrium = true
				break
		else:
			converged_streak = 0
			if responder_is_a:
				cur_a = r["best_policy"]
			else:
				cur_b = r["best_policy"]

	print("\n== self-play result: %s ==" % ("EQUILIBRIUM" if equilibrium else "NO fixed point in %d iters (cycle?)" % _max_iters))
	print("A: %s   B: %s" % [PolicySearch.label_of(cur_a), PolicySearch.label_of(cur_b)])

	# Phase 4 — skill-gap arms (head-to-head win % of the first-named side).
	var gap_arms := [
		{"name": "eq vs eq", "config": {"a": cur_a, "b": cur_b}},
		{"name": "eq vs naive", "config": {"a": cur_a, "b": "random"}},
		{"name": "eq vs textbook", "config": {"a": cur_a, "b": PolicySearch.textbook()}},
		{"name": "eq vs balanced", "config": {"a": cur_a, "b": PolicySearch.balanced()}},
		{"name": "textbook vs textbook", "config": {"a": PolicySearch.textbook(), "b": PolicySearch.textbook()}},
		{"name": "naive vs naive", "config": {"a": "random", "b": "random"}},
	]
	var gap_out := Sweep.run(gap_arms, _gap_n, _scenario, 900001)
	var gaps: Array = []
	print("\narm                     win%%   tie%%")
	for g in gap_out:
		var w := _rate(g["records"], "a_won")
		var t := _rate(g["records"], "tie")
		gaps.append({"name": g["name"], "win": w, "tie": t})
		print("%-22s %5.1f  %5.1f" % [g["name"], 100.0 * w, 100.0 * t])

	# Phase 5 — statted-hero validation (D2): does the equilibrium hold with a
	# real 5/5/5/5 Player in the XI? Hero side plays eq vs an eq opponent, vs
	# the hero side playing textbook against the same opponent.
	var hero_arms := [
		{"name": "hero+eq vs eq", "config": {"a": cur_a, "b": cur_b, "hero": true}},
		{"name": "hero+textbook vs eq", "config": {"a": PolicySearch.textbook(), "b": cur_b, "hero": true}},
	]
	var hero_out := Sweep.run(hero_arms, _gap_n, _scenario, 910001)
	var heroes: Array = []
	print("")
	for h in hero_out:
		var w := _rate(h["records"], "a_won")
		heroes.append({"name": h["name"], "win": w})
		print("%-22s %5.1f" % [h["name"], 100.0 * w])

	print("\nelapsed %.1f min" % ((Time.get_ticks_msec() - t0) / 60000.0))
	print("DATA = " + JSON.stringify({
		"landscape": landscape, "trajectory": trajectory,
		"gaps": gaps, "heroes": heroes,
		"a": PolicySearch.label_of(cur_a), "b": PolicySearch.label_of(cur_b),
		"equilibrium": equilibrium,
		"screen_n": _screen_n, "refine_n": _refine_n, "gap_n": _gap_n,
	}))
	quit()


# Sweep all 216 candidate policies for the responder against the fixed opponent
# policy; refine TOP_K + the responder's current policy on fresh seeds. Returns
# the refined best. Responder is always measured as its OWN win rate.
func _best_response(cur: Dictionary, fixed: Dictionary, responder_is_a: bool, iter: int) -> Dictionary:
	var arms: Array = []
	for p in _policies:
		var cfg := {"a": p, "b": fixed} if responder_is_a else {"a": fixed, "b": p}
		arms.append({"name": PolicySearch.label_of(p), "config": cfg})
	var screened := Sweep.run(arms, _screen_n, _scenario, 1 + iter * 1000)
	var field := "a_won" if responder_is_a else "b_won"
	var rates: Array = []
	for s in screened:
		rates.append(_rate(s["records"], field))
	var landscape: Array = []
	for i in _policies.size():
		landscape.append({"label": arms[i]["name"], "win": rates[i]})

	# top K indices by screened rate
	var order := range(_policies.size())
	order.sort_custom(func(x, y): return rates[x] > rates[y])
	var finalists: Array = []
	for k in range(TOP_K):
		finalists.append(_policies[order[k]])
	finalists.append(cur)  # measure the incumbent on the same fresh seeds

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
# Side A maps to the sim's "player side" params; no statted Player unless hero.
func _scenario(config, rng: RandomNumberGenerator) -> Dictionary:
	var pol_a = config["a"]
	var pol_b = config["b"]
	if pol_a is String:
		pol_a = PolicySearch.random_policy(_policies, rng)
	if pol_b is String:
		pol_b = PolicySearch.random_policy(_policies, rng)

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
		# Pure team-vs-team: mirror simulate_match_teams' derivation (toss, four
		# strength draws, standard XIs, star offsets) minus every Player bit.
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
			PolicySearch.intent_plan_of(pol_b), null, DRSPolicy.new(), null,
			Team.standard_xi(), Team.standard_xi(), a_bat - ref3, b_bat - ref3,
			null, DRSPolicy.new(),
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

- [ ] **Step 2: Quick-mode smoke run**

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --import --path . > /dev/null 2>&1; E1_QUICK=1 /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/sweep_policy_selfplay.gd
```

Expected: `[quick mode]`, two `iter …` lines, the gap/hero tables, a `DATA = {...}` JSON line, exit cleanly in ~1–3 min. Sanity: `textbook vs textbook` win% ≈ 45–52 (even contest), no crash. **Verify the strength-draw asymmetry check:** `eq vs eq` should also read ≈ even — if it reads far from even, the side-A/side-B param mapping is wrong; stop and debug before the full run.

- [ ] **Step 3: Run the suite (still green — the tool is not a test)**

Expected: total unchanged (≥ 396), `All tests passed`.

- [ ] **Step 4: Commit**

```sh
git add tools/sweep_policy_selfplay.gd tools/sweep_policy_selfplay.gd.uid
git commit -m "E1 Task 3: self-play oracle — screen/refine/best-response/skill-gap/hero phases, E1_QUICK smoke mode"
```

---

### Task 4: full run + viz + findings

**Files:**
- Create: `docs/mockups/policy-selfplay-v1.html`
- Modify: `docs/superpowers/specs/2026-06-10-selfplay-baseline-7cE1-design.md` (§10 findings)

- [ ] **Step 1: Full run, backgrounded** (~30–40 min; ONE Godot process — make sure nothing else runs)

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/sweep_policy_selfplay.gd 2>&1 | tee /tmp/e1_selfplay_run.txt
```

- [ ] **Step 2: Build the viz** — `docs/mockups/policy-selfplay-v1.html`, house mockup style (dark, self-contained, a `DATA` const pasted from the run). Three panels: (1) the 216-policy landscape as a 27×8 heatmap (rows = intent triples D/B/A³ in enumeration order, cols = bowling triples P/S³), cell color = win% vs textbook, equilibrium + textbook cells outlined; (2) the best-response trajectory list (iter, side, adopted policy, win%); (3) skill-gap bars (eq-vs-naive, eq-vs-textbook, eq-vs-balanced, textbook-vs-textbook, naive-vs-naive, hero arms). Eyeball it in a browser (preview server) before committing.

- [ ] **Step 3: Write §10 findings** in the spec. Must answer, with numbers: the equilibrium policy (or the cycle), eq-vs-naive gap (the ADR 0003 metric), eq-vs-textbook, landscape spread (best − worst, vs ~2× refinement SE ≈ 1.6 pts — the §5.6 flatness check), the statted-hero validation, and what E2/E3 inherit (the policy dict literal for the opponent AI, any "levers too weak" flags).

- [ ] **Step 4: Commit**

```sh
git add docs/mockups/policy-selfplay-v1.html docs/superpowers/specs/2026-06-10-selfplay-baseline-7cE1-design.md
git commit -m "E1 Task 4: self-play run findings — equilibrium, skill gap, solvability read + landscape viz"
```

---

### Task 5: PR, merge, roadmap

- [ ] **Step 1: Full suite green** (≥ 396, `All tests passed`); `git ls-files | grep " 2"` empty.
- [ ] **Step 2: Push + PR + merge** (house policy: PR-based, auto-merge when green, sync `main`, delete branch).
- [ ] **Step 3: Update `PROJECT_ROADMAP.md`** — Current status gets the E1 entry (findings headline + test count); Next session block rewritten for the follow-on rung (E2 conditional policy or Nico's call); move 7c-E in the theme list to "E1 ✅ · E2 next".
- [ ] **Step 4: Commit roadmap on a small branch or with the merge per house pattern.**

## Self-Review

- **Spec coverage:** D1/D2 (scope+config) → Task 3 scenario; D3 (best response) → Task 3 loop; D4 (skill gap) → Task 3 phase 4 + Task 4 findings; D5 (screen/refine, fresh seeds) → `_best_response` (screen seed `1+iter*1000`, refine seed `500000+iter*1000`); D6 (seam) → Task 1; D7 (artifacts) → Tasks 2–4. Acceptance §5.1–5.3 → Tasks 1–2 tests; §5.4 → Task 3 smoke; §5.5–5.6 → Task 4 findings.
- **Placeholders:** none — every code step is complete.
- **Type consistency:** `PolicySearch.enumerate/label_of/intent_plan_of/bowling_plan_of/best_index/random_policy/textbook/balanced` used identically across Tasks 2–3; seam param name `opp_bowling_plan` identical in Tasks 1 and 3.
