extends SceneTree

# Joker on/off sweep for 7c-C/C2a: hold both teams even (★3) and the Player build
# balanced (5/5/5/5) so the jokers are the only lever. Arms = baseline (no jokers)
# + each implemented joker group individually + a batting stack + a field-defensive
# stack. Prints JSON of the player-runs distribution + win-rate per arm for
# docs/mockups/distribution-viewer-v1.html.
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

	var groups := JokerCatalog.implemented_groups()
	var batting_stack: Array = []
	var field_def_stack: Array = []
	for g in groups:
		for e in g["effects"]:
			if e.side == JokerEffect.Side.BATTING:
				batting_stack.append(e)
			elif e.field_req == FieldPlan.Mode.DEFENSIVE:
				field_def_stack.append(e)

	var arms: Array = [{"name": "Baseline (no jokers)", "config": []}]
	for g in groups:
		arms.append({"name": g["jname"], "config": g["effects"]})
	arms.append({"name": "Batting stack", "config": batting_stack})
	arms.append({"name": "Field-defensive stack", "config": field_def_stack})

	var n := 2000
	var swept := Sweep.run(arms, n, _scenario)

	var palette := ["#888888", "#5ac77a", "#4a90d9", "#f2b134", "#e0607e", "#9b59b6",
		"#1abc9c", "#e67e22", "#3498db", "#2ecc71", "#e74c3c", "#f39c12", "#16a085", "#c0392b"]
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
# Punch, Slog Over Specialist) and DEFENSIVE middle (Dead Bat, Carry Your Bat).
func _intent_plan() -> IntentPlan:
	var p := IntentPlan.new()
	p.powerplay = BallResolver.Intent.AGGRESSIVE
	p.middle = BallResolver.Intent.DEFENSIVE
	p.death = BallResolver.Intent.AGGRESSIVE
	return p

# A fixed field plan shared by every arm (constant across arms -> win-delta is the
# joker's effect, not the field). Exercises both field modes: CATCHING powerplay+
# death (Cordon Killer fires) and DEFENSIVE middle (Tight Lines, Dot Ball Pressure).
func _field_plan() -> FieldPlan:
	var f := FieldPlan.new()
	f.powerplay = FieldPlan.Mode.CATCHING
	f.middle = FieldPlan.Mode.DEFENSIVE
	f.death = FieldPlan.Mode.CATCHING
	return f

func _scenario(config, rng: RandomNumberGenerator) -> Dictionary:
	var a := Attributes.new()
	a.power = 5; a.composure = 5; a.attack = 5; a.control = 5
	var pt := Team.new(); pt.stars = 3.0
	var ot := Team.new(); ot.stars = 3.0
	var m := MatchResolver.simulate_match_teams(a, pt, ot, _tour, _tuning, _itun, rng, _intent_plan(), null, config, _field_plan())
	var line := m.innings1.player_line()
	if line.is_empty():
		line = m.innings2.player_line()
	var player_runs := int(line.get("runs", 0))
	var won := 1 if m.outcome == MatchResult.Outcome.PLAYER_WIN else 0
	return {"player_runs": player_runs, "won": won}
