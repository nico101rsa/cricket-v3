extends SceneTree

# Demo sweep for the 7c-1 harness platform: vary the Player's Attribute build,
# hold both teams even (3.0 stars), run N matches per build, and print JSON of the
# player-runs distribution + win-rate per build for docs/mockups/distribution-viewer-v1.html.
# Run: /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/sweep_skills.gd

var _tuning: BallTuning
var _itun: InningsTuning
var _tour: TourDistribution

func _init() -> void:
	_tuning = BallTuning.new()
	_itun = InningsTuning.new()
	_tour = TourDistribution.new()
	_tour.mean = 31.25
	_tour.spread = 9.375
	_tour.noise = 1

	var arms := [
		{"name": "Batting build (8/8/2/2)", "config": {"power": 8, "composure": 8, "attack": 2, "control": 2}},
		{"name": "Balanced (5/5/5/5)", "config": {"power": 5, "composure": 5, "attack": 5, "control": 5}},
		{"name": "Bowling build (2/2/8/8)", "config": {"power": 2, "composure": 2, "attack": 8, "control": 8}},
	]
	var n := 2000
	var swept := Sweep.run(arms, n, _scenario)

	var colors := ["#5ac77a", "#4a90d9", "#f2b134"]
	var arms_json: Array = []
	var ai := 0
	for arm in swept:
		var runs := Sweep.values_of(arm["records"], "player_runs")
		var wins := Sweep.values_of(arm["records"], "won")
		var dist := Distribution.new(runs)
		var win_sum := 0
		for w in wins:
			win_sum += w
		# Stride values to <= 400 points for inlining.
		var stride: int = maxi(1, runs.size() / 400)
		var sampled: Array = []
		var k := 0
		while k < runs.size():
			sampled.append(runs[k])
			k += stride
		arms_json.append({
			"name": arm["name"],
			"color": colors[ai % colors.size()],
			"values": sampled,
			"stats": dist.to_dict(),
			"win_rate": float(win_sum) / runs.size(),
		})
		ai += 1

	print(JSON.stringify({"metric": "player_runs", "arms": arms_json}))
	quit()

func _scenario(config, rng: RandomNumberGenerator) -> Dictionary:
	var a := Attributes.new()
	a.power = config["power"]
	a.composure = config["composure"]
	a.attack = config["attack"]
	a.control = config["control"]
	var pt := Team.new()
	pt.stars = 3.0
	var ot := Team.new()
	ot.stars = 3.0
	var m := MatchResolver.simulate_match_teams(a, pt, ot, _tour, _tuning, _itun, rng)
	var line := m.innings1.player_line()
	if line.is_empty():
		line = m.innings2.player_line()
	var player_runs := int(line.get("runs", 0))
	var won := 1 if m.outcome == MatchResult.Outcome.PLAYER_WIN else 0
	return {"player_runs": player_runs, "won": won}
