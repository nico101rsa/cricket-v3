extends SceneTree

# Joker on/off sweep for 7c-C: hold both teams even (★3) and the Player build
# balanced (5/5/5/5) so the jokers are the only lever. Arms = baseline (no jokers)
# + each slice joker individually + the batting stack. Prints JSON of the
# player-runs distribution + win-rate per arm for docs/mockups/distribution-viewer-v1.html.
# Run: /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/sweep_jokers.gd

var _tuning: BallTuning
var _itun: InningsTuning
var _tour: TourDistribution

func _init() -> void:
	_tuning = BallTuning.new()
	_itun = InningsTuning.new()
	_tour = TourDistribution.new()
	_tour.mean = 5
	_tour.spread = 1.5
	_tour.noise = 1

	var catalog := JokerCatalog.slice_v1()
	var batting_stack: Array = []
	for j in catalog:
		if j.side == JokerEffect.Side.BATTING:
			batting_stack.append(j)

	var arms: Array = [{"name": "Baseline (no jokers)", "config": []}]
	for j in catalog:
		arms.append({"name": j.jname, "config": [j]})
	arms.append({"name": "Batting stack (3)", "config": batting_stack})

	var n := 2000
	var swept := Sweep.run(arms, n, _scenario)

	var palette := ["#888888", "#5ac77a", "#4a90d9", "#f2b134", "#e0607e", "#9b59b6", "#1abc9c"]
	var baseline_win := 0.0
	var arms_json: Array = []
	var ai := 0
	for arm in swept:
		var runs := Sweep.values_of(arm["records"], "player_runs")
		var wins := Sweep.values_of(arm["records"], "won")
		var dist := Distribution.new(runs)
		var win_sum := 0
		for w in wins:
			win_sum += w
		var win_rate := float(win_sum) / runs.size()
		if ai == 0:
			baseline_win = win_rate
		var stride: int = maxi(1, runs.size() / 400)
		var sampled: Array = []
		var k := 0
		while k < runs.size():
			sampled.append(runs[k])
			k += stride
		arms_json.append({
			"name": arm["name"],
			"color": palette[ai % palette.size()],
			"values": sampled,
			"stats": dist.to_dict(),
			"win_rate": win_rate,
			"win_delta": win_rate - baseline_win,
		})
		ai += 1

	print(JSON.stringify({"metric": "player_runs", "arms": arms_json}))
	quit()

# A fixed intent plan shared by every arm, chosen to exercise all three bands so
# the intent-gated jokers actually fire: AGGRESSIVE powerplay+death (Powerplay
# Punch) and DEFENSIVE middle (Dead Bat). Same plan across arms -> the win-delta
# is purely the joker's effect, not the intent.
func _intent_plan() -> IntentPlan:
	var p := IntentPlan.new()
	p.powerplay = BallResolver.Intent.AGGRESSIVE
	p.middle = BallResolver.Intent.DEFENSIVE
	p.death = BallResolver.Intent.AGGRESSIVE
	return p

func _scenario(config, rng: RandomNumberGenerator) -> Dictionary:
	var a := Attributes.new()
	a.power = 5; a.composure = 5; a.attack = 5; a.control = 5
	var pt := Team.new(); pt.stars = 3.0
	var ot := Team.new(); ot.stars = 3.0
	var m := MatchResolver.simulate_match_teams(a, pt, ot, _tour, _tuning, _itun, rng, _intent_plan(), null, config)
	var line := m.innings1.player_line()
	if line.is_empty():
		line = m.innings2.player_line()
	var player_runs := int(line.get("runs", 0))
	var won := 1 if m.outcome == MatchResult.Outcome.PLAYER_WIN else 0
	return {"player_runs": player_runs, "won": won}
