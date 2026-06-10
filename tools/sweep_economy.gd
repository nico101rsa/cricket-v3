extends SceneTree

# Economy oracle (rung 7c-D, spec §5.4). Two questions:
#   1. ₸ income per match for the three canonical builds (pay-fairness ±15%).
#   2. Marginal Δwin% of +1 attribute around the balanced build (skills-vs-
#      jokers ROI input).
# Both teams even ★3, N matches/arm, paired seeds via Sweep. Not a unit test.
# Run: /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/sweep_economy.gd

var _tuning: BallTuning
var _itun: InningsTuning
var _tour: TourDistribution
var _etun: EconomyTuning

func _init() -> void:
	_tuning = BallTuning.new()
	_itun = InningsTuning.new()
	_tour = TourDistribution.new()
	_tour.mean = 5
	_tour.spread = 1.5
	_tour.noise = 1
	_etun = EconomyTuning.new()

	var arms: Array = [
		{"name": "batter 8/8/2/2", "config": {"power": 8, "composure": 8, "attack": 2, "control": 2}},
		{"name": "balanced 5/5/5/5", "config": {"power": 5, "composure": 5, "attack": 5, "control": 5}},
		{"name": "bowler 2/2/8/8", "config": {"power": 2, "composure": 2, "attack": 8, "control": 8}},
		{"name": "+1 power 6/5/5/5", "config": {"power": 6, "composure": 5, "attack": 5, "control": 5}},
		{"name": "+1 composure 5/6/5/5", "config": {"power": 5, "composure": 6, "attack": 5, "control": 5}},
		{"name": "+1 attack 5/5/6/5", "config": {"power": 5, "composure": 5, "attack": 6, "control": 5}},
		{"name": "+1 control 5/5/5/6", "config": {"power": 5, "composure": 5, "attack": 5, "control": 6}},
	]

	var n := 2000
	var swept := Sweep.run(arms, n, _scenario)

	var balanced_win := 0.0
	var rows: Array = []
	print("arm                    win%   base   perf   total ₸/match   season(×8)")
	for ai in swept.size():
		var recs = swept[ai]["records"]
		var win := 100.0 * _sum(Sweep.values_of(recs, "won")) / n
		var base := _mean(Sweep.values_of(recs, "base"))
		var perf := _mean(Sweep.values_of(recs, "perf"))
		var total := _mean(Sweep.values_of(recs, "total"))
		if swept[ai]["name"] == "balanced 5/5/5/5":
			balanced_win = win
		rows.append({"name": swept[ai]["name"], "win_rate": win, "base": base, "perf": perf,
			"pay": total, "season": total * 8.0})
		print("%-22s %5.1f %6.1f %6.1f %7.1f       %6.0f" % [swept[ai]["name"], win, base, perf, total, total * 8.0])

	print("")
	print("marginal Δwin% vs balanced (the +1-attribute value):")
	for r in rows:
		if String(r["name"]).begins_with("+1"):
			r["delta_win"] = r["win_rate"] - balanced_win
			print("  %-22s %+.1f%%" % [r["name"], r["delta_win"]])

	print("")
	print("JSON: %s" % JSON.stringify({"arms": rows}))
	quit()

func _scenario(config, rng: RandomNumberGenerator) -> Dictionary:
	var a := Attributes.new()
	a.power = config["power"]; a.composure = config["composure"]
	a.attack = config["attack"]; a.control = config["control"]
	var pt := Team.new(); pt.stars = 3.0
	var ot := Team.new(); ot.stars = 3.0
	var m := MatchResolver.simulate_match_teams(a, pt, ot, _tour, _tuning, _itun, rng)
	var pay := Economy.match_pay(m, pt.stars, _etun)
	return {
		"won": 1 if m.outcome == MatchResult.Outcome.PLAYER_WIN else 0,
		"base": pay["base"], "perf": pay["perf"], "total": pay["total"],
	}

func _sum(arr: Array) -> float:
	var s := 0.0
	for x in arr:
		s += x
	return s

func _mean(arr: Array) -> float:
	if arr.is_empty():
		return 0.0
	return _sum(arr) / arr.size()
