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
	# POS_REF env (fresh-build-equality): isolate the competence-gate's pay effect;
	# a tiny value recovers the old share-only position formula (competence==1).
	if OS.get_environment("POS_REF") != "":
		_itun.pos_ref_batting = float(OS.get_environment("POS_REF"))
	_tour = TourDistribution.new()
	_tour.mean = 31.25
	_tour.spread = 9.375
	_etun = EconomyTuning.new()

	var arms: Array = [
		{"name": "batter 50/50/12.5/12.5", "config": {"power": 50.0, "composure": 50.0, "attack": 12.5, "control": 12.5}},
		{"name": "balanced 31.25 x4", "config": {"power": 31.25, "composure": 31.25, "attack": 31.25, "control": 31.25}},
		{"name": "bowler 12.5/12.5/50/50", "config": {"power": 12.5, "composure": 12.5, "attack": 50.0, "control": 50.0}},
		{"name": "+6.25 power", "config": {"power": 37.5, "composure": 31.25, "attack": 31.25, "control": 31.25}},
		{"name": "+6.25 composure", "config": {"power": 31.25, "composure": 37.5, "attack": 31.25, "control": 31.25}},
		{"name": "+6.25 attack", "config": {"power": 31.25, "composure": 31.25, "attack": 37.5, "control": 31.25}},
		{"name": "+6.25 control", "config": {"power": 31.25, "composure": 31.25, "attack": 31.25, "control": 37.5}},
	]

	var n := 2000
	var swept := Sweep.run(arms, n, _scenario)

	var balanced_win := 0.0
	var rows: Array = []
	print("arm                    win%   base   perf   total ₸/match   season(×8)   runs bat-b  50%  100%  wkts  bowl-b bowl-r")
	for ai in swept.size():
		var recs = swept[ai]["records"]
		var win := 100.0 * _sum(Sweep.values_of(recs, "won")) / n
		var base := _mean(Sweep.values_of(recs, "base"))
		var perf := _mean(Sweep.values_of(recs, "perf"))
		var total := _mean(Sweep.values_of(recs, "total"))
		var runs := _mean(Sweep.values_of(recs, "runs"))
		var bat_balls := _mean(Sweep.values_of(recs, "bat_balls"))
		var fifty := 100.0 * _sum(Sweep.values_of(recs, "fifty")) / n
		var hundred := 100.0 * _sum(Sweep.values_of(recs, "hundred")) / n
		var wkts := _mean(Sweep.values_of(recs, "wkts"))
		var bowl_balls := _mean(Sweep.values_of(recs, "bowl_balls"))
		var bowl_runs := _mean(Sweep.values_of(recs, "bowl_runs"))
		if swept[ai]["name"] == "balanced 5/5/5/5":
			balanced_win = win
		rows.append({"name": swept[ai]["name"], "win_rate": win, "base": base, "perf": perf,
			"pay": total, "season": total * 8.0, "runs": runs, "bat_balls": bat_balls,
			"fifty_pct": fifty, "hundred_pct": hundred,
			"wkts": wkts, "bowl_balls": bowl_balls, "bowl_runs": bowl_runs})
		print("%-22s %5.1f %6.1f %6.1f %7.1f       %6.0f   %5.1f %5.1f %4.1f%% %4.1f%% %5.2f %7.1f %6.1f" % [
			swept[ai]["name"], win, base, perf, total, total * 8.0,
			runs, bat_balls, fifty, hundred, wkts, bowl_balls, bowl_runs])

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
	# The Player's stat split, for decomposing perf pay per build.
	var bat_inn := m.innings1
	var bowl_inn := m.innings2
	if m.innings1.player_line().is_empty():
		bat_inn = m.innings2
		bowl_inn = m.innings1
	var line := bat_inn.player_line()
	return {
		"won": 1 if m.outcome == MatchResult.Outcome.PLAYER_WIN else 0,
		"base": pay["base"], "perf": pay["perf"], "total": pay["total"],
		"runs": int(line.get("runs", 0)),
		"bat_balls": int(line.get("balls", 0)),
		"fifty": 1 if int(line.get("runs", 0)) >= 50 else 0,
		"hundred": 1 if int(line.get("runs", 0)) >= 100 else 0,
		"wkts": bowl_inn.player_bowl_wickets,
		"bowl_balls": bowl_inn.player_bowl_balls,
		"bowl_runs": bowl_inn.player_bowl_runs,
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
