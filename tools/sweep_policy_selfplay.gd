extends SceneTree

# E1 oracle (spec 2026-06-10-selfplay-baseline-7cE1-design.md): self-play search
# over the 216 static no-joker policies. Pure team-vs-team (no statted Player,
# spec D2), even ★3, no Boost (D1). DRS is OFF in the team-vs-team arms: the
# 2026-06-10 side-asymmetry probe (spec §10) showed the "symmetric default"
# isn't — the player slot's claim-review is gated on the hero's own overs
# (innings_resolver DRS block) while the opponent claims on all 20, worth ~6.7
# win points to the opponent slot. Fix deferred (it moves the fair-fight
# baseline the joker prices were measured against). The hero-validation arms
# keep DRS both sides: both arms share the bias, so their comparison is fair.
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
	_tour.mean = 31.25
	_tour.spread = 9.375
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
	var landscape: Array = []  # iteration-0 screening of side A, for the viz
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
	print("\narm                     win%   tie%")
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
		a.power = 31.25
		a.composure = 31.25
		a.attack = 31.25
		a.control = 31.25
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
		m = MatchResolver.simulate_match(
			null,
			a_bat, a_bowl, a_bowl,
			b_bat, b_bowl, b_bowl,
			a_bats_first, _tuning, _itun, rng,
			PolicySearch.intent_plan_of(pol_a), PolicySearch.bowling_plan_of(pol_a),
			[], null, null,
			PolicySearch.intent_plan_of(pol_b), null, null, null,
			Team.standard_xi(), Team.standard_xi(), a_bat / MatchResolver.REF_SCALAR, b_bat / MatchResolver.REF_SCALAR,
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
