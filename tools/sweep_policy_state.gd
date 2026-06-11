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
# incumbent `cur` on fresh seeds. Same shape as the E1 oracle's _best_response.
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
# Identical frame to the E1 oracle's _scenario (random = naive STATIC draw,
# keeping the E3 ladder floor comparable to E1).
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
