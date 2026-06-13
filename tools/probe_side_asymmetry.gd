extends SceneTree

# Throwaway probe (E1): mirror-policy team-vs-team matches read ~43-45% for the
# side-A slot, not the ~48-49% fair benchmark. Decompose which ingredient
# (intent plans / rotation / DRS) injects the asymmetry. Not a test.
# Run: /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/probe_side_asymmetry.gd

var _tuning := BallTuning.new()
var _itun := InningsTuning.new()
var _tour: TourDistribution


func _init() -> void:
	_tour = TourDistribution.new()
	_tour.mean = 31.25
	_tour.spread = 9.375

	var arms := [
		{"name": "all null (scalar, no DRS)", "config": {"intent": false, "rot": false, "drs": false}},
		{"name": "DRS both only", "config": {"intent": false, "rot": false, "drs": true}},
		{"name": "intent textbook both only", "config": {"intent": true, "rot": false, "drs": false}},
		{"name": "rotation textbook both only", "config": {"intent": false, "rot": true, "drs": false}},
		{"name": "full textbook config", "config": {"intent": true, "rot": true, "drs": true}},
	]
	var out := Sweep.run(arms, 4000, _scenario, 12345)
	print("arm                              A-win%  B-win%  tie%")
	for o in out:
		var a := _rate(o["records"], "a_won")
		var b := _rate(o["records"], "b_won")
		var t := _rate(o["records"], "tie")
		print("%-32s %5.1f  %5.1f  %5.1f" % [o["name"], 100.0 * a, 100.0 * b, 100.0 * t])
	quit()


func _scenario(config, rng: RandomNumberGenerator) -> Dictionary:
	var ip_a: IntentPlan = IntentPlan.textbook() if config["intent"] else null
	var ip_b: IntentPlan = IntentPlan.textbook() if config["intent"] else null
	var bp_a: BowlingPlan = BowlingPlan.textbook() if config["rot"] else null
	var bp_b: BowlingPlan = BowlingPlan.textbook() if config["rot"] else null
	var drs_a: DRSPolicy = DRSPolicy.new() if config["drs"] else null
	var drs_b: DRSPolicy = DRSPolicy.new() if config["drs"] else null

	var a_bats_first := rng.randf() < 0.5
	var pt := Team.new()
	pt.stars = 3.0
	var ot := Team.new()
	ot.stars = 3.0
	var a_bat := pt.batting_strength(_tour, rng)
	var a_bowl := pt.bowling_strength(_tour, rng)
	var b_bat := ot.batting_strength(_tour, rng)
	var b_bowl := ot.bowling_strength(_tour, rng)
	var m := MatchResolver.simulate_match(
		null,
		a_bat, a_bowl, a_bowl,
		b_bat, b_bowl, b_bowl,
		a_bats_first, _tuning, _itun, rng,
		ip_a, bp_a, [], null, null,
		ip_b, null, drs_a, null,
		Team.standard_xi(), Team.standard_xi(), a_bat / MatchResolver.REF_SCALAR, b_bat / MatchResolver.REF_SCALAR,
		null, drs_b, bp_b)
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
