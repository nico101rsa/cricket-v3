extends GutTest

func _attrs() -> Attributes:
	var a := Attributes.new()
	a.power = 5; a.composure = 5; a.attack = 5; a.control = 5
	return a

func _tour() -> TourDistribution:
	var t := TourDistribution.new()
	t.mean = 5; t.spread = 1.5; t.noise = 1
	return t

func _team() -> Team:
	var t := Team.new()
	t.stars = 3.0
	return t

func _seeded(s: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new(); r.seed = s
	return r

func _player_wins(rng_seed: int, jokers: Array) -> bool:
	var m := MatchResolver.simulate_match_teams(
		_attrs(), _team(), _team(), _tour(), BallTuning.new(), InningsTuning.new(),
		_seeded(rng_seed), null, null, jokers)
	return m.outcome == MatchResult.Outcome.PLAYER_WIN

func test_synthetic_batting_buff_raises_win_rate() -> void:
	var buff := [JokerEffect.make("b", "B", "Common", JokerEffect.Side.BATTING, JokerEffect.Target.WICKET, 0.7)]
	var base_wins := 0; var buff_wins := 0
	for i in range(300):
		if _player_wins(i, []):
			base_wins += 1
		if _player_wins(i, buff):
			buff_wins += 1
	assert_gt(buff_wins, base_wins, "a batting wicket-reducer should raise player win-rate")

func test_death_over_bowling_joker_raises_win_rate() -> void:
	# Death-Over Stranglehold from the catalog (intent-agnostic, ball >= 90, runs x0.80).
	var dos := [JokerEffect.make("dos", "Death-Over Stranglehold", "Rare",
		JokerEffect.Side.BOWLING, JokerEffect.Target.RUNS, 0.80, -1, 90, 120)]
	var base_wins := 0; var buff_wins := 0
	for i in range(300):
		if _player_wins(i, []):
			base_wins += 1
		if _player_wins(i, dos):
			buff_wins += 1
	assert_gt(buff_wins, base_wins, "a death-over run-suppressor should raise player win-rate")

func test_determinism_with_jokers() -> void:
	var jk := [JokerEffect.make("b", "B", "Common", JokerEffect.Side.BATTING, JokerEffect.Target.WICKET, 0.7)]
	var a := MatchResolver.simulate_match_teams(_attrs(), _team(), _team(), _tour(),
		BallTuning.new(), InningsTuning.new(), _seeded(7), null, null, jk)
	var b := MatchResolver.simulate_match_teams(_attrs(), _team(), _team(), _tour(),
		BallTuning.new(), InningsTuning.new(), _seeded(7), null, null, jk)
	assert_eq(a.outcome, b.outcome)
	assert_eq(a.innings1.total, b.innings1.total)
	assert_eq(a.innings2.total, b.innings2.total)

func _player_wins_field(rng_seed: int, jokers: Array, field: FieldPlan) -> bool:
	var m := MatchResolver.simulate_match_teams(
		_attrs(), _team(), _team(), _tour(), BallTuning.new(), InningsTuning.new(),
		_seeded(rng_seed), null, null, jokers, field)
	return m.outcome == MatchResult.Outcome.PLAYER_WIN

func test_catching_field_bowling_joker_raises_win_rate() -> void:
	# Cordon Killer shape (bowling, catching field, wicket booster) only fires when a
	# catching FieldPlan is supplied -> the field routes to the opposition's batting innings.
	var ck := [JokerEffect.make("ck", "Cordon Killer", "Common",
		JokerEffect.Side.BOWLING, JokerEffect.Target.WICKET, 1.5, -1, 1, 120, FieldPlan.Mode.CATCHING)]
	var base_wins := 0; var field_wins := 0
	for i in range(300):
		if _player_wins(i, []):
			base_wins += 1
		if _player_wins_field(i, ck, FieldPlan.catching()):
			field_wins += 1
	assert_gt(field_wins, base_wins, "a catching-field wicket booster should raise win-rate when the field is catching")

func test_determinism_with_field_plan() -> void:
	var ck := [JokerEffect.make("ck", "Cordon Killer", "Common",
		JokerEffect.Side.BOWLING, JokerEffect.Target.WICKET, 1.5, -1, 1, 120, FieldPlan.Mode.CATCHING)]
	var a := MatchResolver.simulate_match_teams(_attrs(), _team(), _team(), _tour(),
		BallTuning.new(), InningsTuning.new(), _seeded(11), null, null, ck, FieldPlan.catching())
	var b := MatchResolver.simulate_match_teams(_attrs(), _team(), _team(), _tour(),
		BallTuning.new(), InningsTuning.new(), _seeded(11), null, null, ck, FieldPlan.catching())
	assert_eq(a.outcome, b.outcome)
	assert_eq(a.innings1.total, b.innings1.total)
	assert_eq(a.innings2.total, b.innings2.total)

# --- C2b: bowling-side intent routing ---

func _all_intent(band: int) -> IntentPlan:
	var p := IntentPlan.new()
	p.powerplay = band; p.middle = band; p.death = band
	return p

func test_null_bowl_intent_params_match_baseline() -> void:
	# Explicitly passing null for the two new params == omitting them (byte-identical).
	for i in range(20):
		var a := MatchResolver.simulate_match_teams(_attrs(), _team(), _team(), _tour(),
			BallTuning.new(), InningsTuning.new(), _seeded(i), null, null, [])
		var b := MatchResolver.simulate_match_teams(_attrs(), _team(), _team(), _tour(),
			BallTuning.new(), InningsTuning.new(), _seeded(i), null, null, [], null, null, null)
		assert_eq(a.innings1.total, b.innings1.total)
		assert_eq(a.innings2.total, b.innings2.total)
		assert_eq(a.outcome, b.outcome)

func test_pressure_cooker_fires_on_defensive_opposition() -> void:
	# Pressure Cooker shape (bowling, reads batsman intent = Defensive, wicket booster).
	# Both arms set the opposition Defensive; only the joker differs -> isolates its effect.
	var pc := [JokerEffect.make("pc", "Pressure Cooker", "Common",
		JokerEffect.Side.BOWLING, JokerEffect.Target.WICKET, 1.5, BallResolver.Intent.DEFENSIVE)]
	var opp_def := _all_intent(BallResolver.Intent.DEFENSIVE)
	var base_wins := 0; var pc_wins := 0
	for i in range(300):
		var m0 := MatchResolver.simulate_match_teams(_attrs(), _team(), _team(), _tour(),
			BallTuning.new(), InningsTuning.new(), _seeded(i), null, null, [], null, null, opp_def)
		if m0.outcome == MatchResult.Outcome.PLAYER_WIN:
			base_wins += 1
		var m1 := MatchResolver.simulate_match_teams(_attrs(), _team(), _team(), _tour(),
			BallTuning.new(), InningsTuning.new(), _seeded(i), null, null, pc, null, null, opp_def)
		if m1.outcome == MatchResult.Outcome.PLAYER_WIN:
			pc_wins += 1
	assert_gt(pc_wins, base_wins, "Pressure Cooker should raise win-rate against a Defensive opposition")

func test_attack_the_stumps_fires_on_aggressive_captaincy() -> void:
	# Attack the Stumps shape (bowling, gated on the Player's bowl_intent = Aggressive).
	# Both arms set the bowling captain Aggressive; only the joker differs.
	var ats := [JokerEffect.make("ats", "Attack the Stumps", "Common",
		JokerEffect.Side.BOWLING, JokerEffect.Target.WICKET, 1.5, -1, 1, 120, -1, BallResolver.Intent.AGGRESSIVE)]
	var bowl_agg := _all_intent(BallResolver.Intent.AGGRESSIVE)
	var base_wins := 0; var ats_wins := 0
	for i in range(300):
		var m0 := MatchResolver.simulate_match_teams(_attrs(), _team(), _team(), _tour(),
			BallTuning.new(), InningsTuning.new(), _seeded(i), null, null, [], null, bowl_agg)
		if m0.outcome == MatchResult.Outcome.PLAYER_WIN:
			base_wins += 1
		var m1 := MatchResolver.simulate_match_teams(_attrs(), _team(), _team(), _tour(),
			BallTuning.new(), InningsTuning.new(), _seeded(i), null, null, ats, null, bowl_agg)
		if m1.outcome == MatchResult.Outcome.PLAYER_WIN:
			ats_wins += 1
	assert_gt(ats_wins, base_wins, "Attack the Stumps should raise win-rate under Aggressive bowling captaincy")

# --- C2c: Form-event windowed buffs at match level ---

func test_form_trigger_joker_is_deterministic() -> void:
	var rtw := [JokerEffect.make("rtw", "Ride the Wave", "Common",
		JokerEffect.Side.BATTING, JokerEffect.Target.RUNS, 1.20,
		-1, 1, 120, -1, -1, -1, JokerEffect.Trigger.FORM_BAT, 3)]
	var a := MatchResolver.simulate_match_teams(_attrs(), _team(), _team(), _tour(),
		BallTuning.new(), InningsTuning.new(), _seeded(31), null, null, rtw)
	var b := MatchResolver.simulate_match_teams(_attrs(), _team(), _team(), _tour(),
		BallTuning.new(), InningsTuning.new(), _seeded(31), null, null, rtw)
	assert_eq(a.outcome, b.outcome)
	assert_eq(a.innings1.total, b.innings1.total)
	assert_eq(a.innings2.total, b.innings2.total)

func test_form_window_raises_win_rate() -> void:
	# Ride the Wave (batting runs window) should help the Player's win-rate.
	var rtw := [JokerEffect.make("rtw", "Ride the Wave", "Common",
		JokerEffect.Side.BATTING, JokerEffect.Target.RUNS, 1.20,
		-1, 1, 120, -1, -1, -1, JokerEffect.Trigger.FORM_BAT, 3)]
	var base_wins := 0; var buff_wins := 0
	for i in range(300):
		if _player_wins(i, []):
			base_wins += 1
		if _player_wins(i, rtw):
			buff_wins += 1
	assert_gt(buff_wins, base_wins, "a Form-triggered runs window should raise win-rate")

func test_determinism_with_bowl_intent_plans() -> void:
	var ats := [JokerEffect.make("ats", "Attack the Stumps", "Common",
		JokerEffect.Side.BOWLING, JokerEffect.Target.WICKET, 1.5, -1, 1, 120, -1, BallResolver.Intent.AGGRESSIVE)]
	var bowl_agg := _all_intent(BallResolver.Intent.AGGRESSIVE)
	var opp_def := _all_intent(BallResolver.Intent.DEFENSIVE)
	var a := MatchResolver.simulate_match_teams(_attrs(), _team(), _team(), _tour(),
		BallTuning.new(), InningsTuning.new(), _seeded(21), null, null, ats, null, bowl_agg, opp_def)
	var b := MatchResolver.simulate_match_teams(_attrs(), _team(), _team(), _tour(),
		BallTuning.new(), InningsTuning.new(), _seeded(21), null, null, ats, null, bowl_agg, opp_def)
	assert_eq(a.outcome, b.outcome)
	assert_eq(a.innings1.total, b.innings1.total)
	assert_eq(a.innings2.total, b.innings2.total)
