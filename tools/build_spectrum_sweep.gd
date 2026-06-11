extends SceneTree

# Throwaway diagnostic (Nico's Q, 2026-06-08): walk the Player build along the
# batting<->bowling axis and report a FULL scorecard per build, to SEE how each
# stat shifts. Each build keeps power==composure (b), attack==control (w), b+w=10.
# Both teams even ★3, N matches each (paired seeds via Sweep). Not a unit test.
# Run: /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/build_spectrum_sweep.gd

var _tuning: BallTuning
var _itun: InningsTuning
var _tour: TourDistribution
var _rtun: RatingTuning

func _init() -> void:
	_tuning = BallTuning.new()
	_itun = InningsTuning.new()
	_tour = TourDistribution.new()
	_tour.mean = 31.25
	_tour.spread = 9.375
	_tour.noise = 1
	_rtun = RatingTuning.new()

	var arms: Array = []
	for b in range(8, 1, -1):  # legacy 8,7,...,2 -> full-batting ... full-bowling
		var w := 10 - b
		var bs := b * Attributes.SCALE   # card-rescale: builds live on /100
		var ws := w * Attributes.SCALE
		arms.append({
			"name": "%2d/%2d" % [int(bs), int(ws)],
			"config": {"power": bs, "composure": bs, "attack": ws, "control": ws},
		})

	var n := 2000
	var swept := Sweep.run(arms, n, _scenario)

	# header
	print("build      win%   pos   bat-avg  SR     HS   wkts  econ  best   team  opp  rating  r-bat r-bowl")
	for ai in swept.size():
		var recs = swept[ai]["records"]
		var won := _sum(Sweep.values_of(recs, "won"))
		var runs := Sweep.values_of(recs, "runs")
		var outs := _sum(Sweep.values_of(recs, "out"))
		var balls := _sum(Sweep.values_of(recs, "bat_balls"))
		var pos := Sweep.values_of(recs, "pos")
		var bwl_w := Sweep.values_of(recs, "bwl_wkts")
		var bwl_r := Sweep.values_of(recs, "bwl_runs")
		var bwl_b := Sweep.values_of(recs, "bwl_balls")
		var team := Sweep.values_of(recs, "team_score")
		var opp := Sweep.values_of(recs, "opp_score")
		var rating := Sweep.values_of(recs, "rating")
		var rate_bat := Sweep.values_of(recs, "rate_bat")
		var rate_bowl := Sweep.values_of(recs, "rate_bowl")

		var total_runs := _sum(runs)
		var bat_avg := float(total_runs) / outs if outs > 0 else float(total_runs)
		var sr := 100.0 * total_runs / balls if balls > 0 else 0.0
		var hs := _max(runs)
		var wkts_per := float(_sum(bwl_w)) / n
		var total_bb := _sum(bwl_b)
		var econ := 6.0 * _sum(bwl_r) / total_bb if total_bb > 0 else -1.0
		var best := _best_bowling(bwl_w, bwl_r, bwl_b)

		print("%-9s %5.1f %4.1f %7.1f %6.1f %4d %5.2f %5s %6s %5.0f %5.0f %7.1f %6.1f %6.1f" % [
			swept[ai]["name"],
			100.0 * won / n,
			_mean(pos),
			bat_avg, sr, hs,
			wkts_per,
			"%.2f" % econ if econ >= 0 else "—",
			best,
			_mean(team), _mean(opp),
			_mean(rating), _mean(rate_bat), _mean(rate_bowl)])
	quit()

func _scenario(config, rng: RandomNumberGenerator) -> Dictionary:
	var a := Attributes.new()
	a.power = config["power"]; a.composure = config["composure"]
	a.attack = config["attack"]; a.control = config["control"]
	var pt := Team.new(); pt.stars = 3.0
	var ot := Team.new(); ot.stars = 3.0
	var m := MatchResolver.simulate_match_teams(a, pt, ot, _tour, _tuning, _itun, rng)

	# Which innings did the Player bat in (non-empty line) vs bowl in (the other)?
	var bat_inn := m.innings1
	var bowl_inn := m.innings2
	if m.innings1.player_line().is_empty():
		bat_inn = m.innings2
		bowl_inn = m.innings1
	var line := bat_inn.player_line()
	var rated: Dictionary = PlayerRating.rate(
		line, bowl_inn.player_bowl_wickets, bowl_inn.player_bowl_runs, bowl_inn.player_bowl_balls, _rtun)

	return {
		"won": 1 if m.outcome == MatchResult.Outcome.PLAYER_WIN else 0,
		"pos": int(line.get("position", 0)),
		"runs": int(line.get("runs", 0)),
		"bat_balls": int(line.get("balls", 0)),
		"out": 1 if line.get("out", false) else 0,
		"bwl_wkts": bowl_inn.player_bowl_wickets,
		"bwl_runs": bowl_inn.player_bowl_runs,
		"bwl_balls": bowl_inn.player_bowl_balls,
		"team_score": bat_inn.total,
		"opp_score": bowl_inn.total,
		"rating": rated["rating"],
		"rate_bat": rated["batting"],
		"rate_bowl": rated["bowling"],
	}

func _sum(a: Array) -> int:
	var s := 0
	for x in a:
		s += x
	return s

func _max(a: Array) -> int:
	var m := 0
	for x in a:
		if x > m:
			m = x
	return m

func _mean(a: Array) -> float:
	if a.is_empty():
		return 0.0
	return float(_sum(a)) / a.size()

# Best bowling = most wickets, tie-break fewest runs, among matches the Player bowled.
func _best_bowling(wkts: Array, runs: Array, balls: Array) -> String:
	var best_w := -1
	var best_r := 0
	for i in wkts.size():
		if balls[i] == 0:
			continue
		if wkts[i] > best_w or (wkts[i] == best_w and runs[i] < best_r):
			best_w = wkts[i]
			best_r = runs[i]
	if best_w < 0:
		return "—"
	return "%d/%d" % [best_w, best_r]
