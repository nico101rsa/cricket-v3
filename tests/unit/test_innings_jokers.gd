extends GutTest

func _attrs() -> Attributes:
	var a := Attributes.new()
	a.power = 5; a.composure = 5; a.attack = 5; a.control = 5
	return a

func _strong_batting_reducer() -> Array:
	# Synthetic always-on batting wicket-reducer — a clean directional signal.
	return [JokerEffect.make("t", "T", "Common", JokerEffect.Side.BATTING, JokerEffect.Target.WICKET, 0.5)]

func test_empty_jokers_equals_baseline() -> void:
	var tuning := BallTuning.new(); var itun := InningsTuning.new()
	var a := _attrs()
	for i in range(20):
		var r1 := RandomNumberGenerator.new(); r1.seed = i
		var base := InningsResolver.simulate_innings(a, 5, 5, 5, tuning, itun, r1)
		var r2 := RandomNumberGenerator.new(); r2.seed = i
		var same := InningsResolver.simulate_innings(a, 5, 5, 5, tuning, itun, r2, 0, null, null, null, 0, 0, 0, [], true)
		assert_eq(base.total, same.total)
		assert_eq(base.wickets, same.wickets)
		assert_eq(base.balls, same.balls)

func test_batting_wicket_reducer_lowers_wickets() -> void:
	var tuning := BallTuning.new(); var itun := InningsTuning.new()
	var a := _attrs()
	var jk := _strong_batting_reducer()
	var base_w := 0; var buff_w := 0
	for i in range(200):
		var r1 := RandomNumberGenerator.new(); r1.seed = i
		base_w += InningsResolver.simulate_innings(a, 5, 5, 5, tuning, itun, r1).wickets
		var r2 := RandomNumberGenerator.new(); r2.seed = i
		buff_w += InningsResolver.simulate_innings(a, 5, 5, 5, tuning, itun, r2, 0, null, null, null, 0, 0, 0, jk, true).wickets
	assert_lt(buff_w, base_w, "a batting wicket-reducer should lower total wickets")

func test_determinism_with_jokers() -> void:
	var tuning := BallTuning.new(); var itun := InningsTuning.new()
	var a := _attrs()
	var jk := _strong_batting_reducer()
	var r1 := RandomNumberGenerator.new(); r1.seed = 42
	var first := InningsResolver.simulate_innings(a, 5, 5, 5, tuning, itun, r1, 0, null, null, null, 0, 0, 0, jk, true)
	var r2 := RandomNumberGenerator.new(); r2.seed = 42
	var second := InningsResolver.simulate_innings(a, 5, 5, 5, tuning, itun, r2, 0, null, null, null, 0, 0, 0, jk, true)
	assert_eq(first.total, second.total)
	assert_eq(first.wickets, second.wickets)
	assert_eq(first.balls, second.balls)

func _catching_wicket_booster() -> Array:
	# Cordon-Killer shape: bowling, field = Catching, strong wicket boost (directional signal).
	return [JokerEffect.make("ck", "CK", "Common", JokerEffect.Side.BOWLING,
		JokerEffect.Target.WICKET, 2.0, -1, 1, 120, FieldPlan.Mode.CATCHING)]

func test_null_field_plan_equals_no_field() -> void:
	var tuning := BallTuning.new(); var itun := InningsTuning.new()
	var jk := _catching_wicket_booster()
	for i in range(20):
		# Owner bowling (player_is_batting=false); null field_plan -> field joker inert -> == no jokers.
		var r1 := RandomNumberGenerator.new(); r1.seed = i
		var base := InningsResolver.simulate_innings(null, 5, 5, 5, tuning, itun, r1)
		var r2 := RandomNumberGenerator.new(); r2.seed = i
		var same := InningsResolver.simulate_innings(null, 5, 5, 5, tuning, itun, r2, 0, null, null, null, 0, 0, 0, jk, false, null)
		assert_eq(base.wickets, same.wickets)
		assert_eq(base.total, same.total)

func test_catching_field_joker_raises_wickets() -> void:
	var tuning := BallTuning.new(); var itun := InningsTuning.new()
	var jk := _catching_wicket_booster()
	var neutral_w := 0; var catching_w := 0
	for i in range(200):
		var r1 := RandomNumberGenerator.new(); r1.seed = i
		neutral_w += InningsResolver.simulate_innings(null, 5, 5, 5, tuning, itun, r1, 0, null, null, null, 0, 0, 0, jk, false, FieldPlan.neutral()).wickets
		var r2 := RandomNumberGenerator.new(); r2.seed = i
		catching_w += InningsResolver.simulate_innings(null, 5, 5, 5, tuning, itun, r2, 0, null, null, null, 0, 0, 0, jk, false, FieldPlan.catching()).wickets
	assert_gt(catching_w, neutral_w, "a catching-field wicket booster should raise wickets when the field is catching")

func test_determinism_with_field_plan() -> void:
	var tuning := BallTuning.new(); var itun := InningsTuning.new()
	var jk := _catching_wicket_booster()
	var r1 := RandomNumberGenerator.new(); r1.seed = 9
	var first := InningsResolver.simulate_innings(null, 5, 5, 5, tuning, itun, r1, 0, null, null, null, 0, 0, 0, jk, false, FieldPlan.catching())
	var r2 := RandomNumberGenerator.new(); r2.seed = 9
	var second := InningsResolver.simulate_innings(null, 5, 5, 5, tuning, itun, r2, 0, null, null, null, 0, 0, 0, jk, false, FieldPlan.catching())
	assert_eq(first.total, second.total)
	assert_eq(first.wickets, second.wickets)
	assert_eq(first.balls, second.balls)

# --- C2b: bowling-captain intent ---

func _all_aggressive() -> IntentPlan:
	var p := IntentPlan.new()
	p.powerplay = BallResolver.Intent.AGGRESSIVE
	p.middle = BallResolver.Intent.AGGRESSIVE
	p.death = BallResolver.Intent.AGGRESSIVE
	return p

func _bowl_intent_wicket_booster() -> Array:
	# Attack-the-Stumps shape: bowling, gated on bowl_intent = Aggressive, strong wicket boost.
	return [JokerEffect.make("ats", "ATS", "Common", JokerEffect.Side.BOWLING,
		JokerEffect.Target.WICKET, 2.0, -1, 1, 120, -1, BallResolver.Intent.AGGRESSIVE)]

func test_bowl_intent_joker_raises_wickets() -> void:
	var tuning := BallTuning.new(); var itun := InningsTuning.new()
	var jk := _bowl_intent_wicket_booster()
	var bip := _all_aggressive()
	var off_w := 0; var on_w := 0
	for i in range(200):
		# No bowl_intent plan -> joker inert.
		var r1 := RandomNumberGenerator.new(); r1.seed = i
		off_w += InningsResolver.simulate_innings(null, 5, 5, 5, tuning, itun, r1, 0, null, null, null, 0, 0, 0, jk, false, null, null).wickets
		# Aggressive bowl_intent plan -> joker fires.
		var r2 := RandomNumberGenerator.new(); r2.seed = i
		on_w += InningsResolver.simulate_innings(null, 5, 5, 5, tuning, itun, r2, 0, null, null, null, 0, 0, 0, jk, false, null, bip).wickets
	assert_gt(on_w, off_w, "an Aggressive-bowl-intent wicket booster should raise wickets when the captain is Aggressive")

func test_determinism_with_bowl_intent_plan() -> void:
	var tuning := BallTuning.new(); var itun := InningsTuning.new()
	var jk := _bowl_intent_wicket_booster()
	var bip := _all_aggressive()
	var r1 := RandomNumberGenerator.new(); r1.seed = 13
	var first := InningsResolver.simulate_innings(null, 5, 5, 5, tuning, itun, r1, 0, null, null, null, 0, 0, 0, jk, false, null, bip)
	var r2 := RandomNumberGenerator.new(); r2.seed = 13
	var second := InningsResolver.simulate_innings(null, 5, 5, 5, tuning, itun, r2, 0, null, null, null, 0, 0, 0, jk, false, null, bip)
	assert_eq(first.total, second.total)
	assert_eq(first.wickets, second.wickets)
	assert_eq(first.balls, second.balls)

# --- C2c: Form-event windowed buffs ---

func _ride_the_wave() -> Array:
	# FORM_BAT: a Player boundary -> runs x1.20 for 3 balls.
	return [JokerEffect.make("rtw", "Ride the Wave", "Common",
		JokerEffect.Side.BATTING, JokerEffect.Target.RUNS, 1.20,
		-1, 1, 120, -1, -1, -1, JokerEffect.Trigger.FORM_BAT, 3)]

func _wicket_maiden() -> Array:
	# FORM_BOWL: a Player wicket while bowling -> wicket x1.30 for 6 balls.
	return [JokerEffect.make("wm", "Wicket Maiden", "Rare",
		JokerEffect.Side.BOWLING, JokerEffect.Target.WICKET, 1.30,
		-1, 1, 120, -1, -1, -1, JokerEffect.Trigger.FORM_BOWL, 6)]

func test_ride_the_wave_raises_player_runs() -> void:
	# An aggressive Player who hits boundaries triggers the runs window -> more runs.
	var tuning := BallTuning.new(); var itun := InningsTuning.new()
	var a := _attrs(); a.power = 8; a.composure = 8  # high power -> boundaries -> Form events
	var agg := IntentPlan.new()
	agg.powerplay = BallResolver.Intent.AGGRESSIVE
	agg.middle = BallResolver.Intent.AGGRESSIVE
	agg.death = BallResolver.Intent.AGGRESSIVE
	var jk := _ride_the_wave()
	var base_r := 0; var buff_r := 0
	for i in range(200):
		var r1 := RandomNumberGenerator.new(); r1.seed = i
		base_r += InningsResolver.simulate_innings(a, 5, 5, 5, tuning, itun, r1, 0, agg, null, null, 0, 0, 0, [], true).total
		var r2 := RandomNumberGenerator.new(); r2.seed = i
		buff_r += InningsResolver.simulate_innings(a, 5, 5, 5, tuning, itun, r2, 0, agg, null, null, 0, 0, 0, jk, true).total
	assert_gt(buff_r, base_r, "a boundary-triggered runs window should raise the total")

func test_wicket_maiden_raises_opposition_wickets() -> void:
	# Player bowling some overs; a Player wicket triggers a wicket window -> more wickets.
	var tuning := BallTuning.new(); var itun := InningsTuning.new()
	var jk := _wicket_maiden()
	var base_w := 0; var buff_w := 0
	for i in range(200):
		# player_bowler_overs = 4 so the Player bowls and can take wickets.
		var r1 := RandomNumberGenerator.new(); r1.seed = i
		base_w += InningsResolver.simulate_innings(null, 5, 5, 5, tuning, itun, r1, 0, null, null, null, 8, 8, 4, [], false).wickets
		var r2 := RandomNumberGenerator.new(); r2.seed = i
		buff_w += InningsResolver.simulate_innings(null, 5, 5, 5, tuning, itun, r2, 0, null, null, null, 8, 8, 4, jk, false).wickets
	assert_gt(buff_w, base_w, "a wicket-triggered wicket window should raise total wickets")

func test_determinism_with_trigger_jokers() -> void:
	var tuning := BallTuning.new(); var itun := InningsTuning.new()
	var a := _attrs(); a.power = 8
	var jk := _ride_the_wave()
	var r1 := RandomNumberGenerator.new(); r1.seed = 5
	var first := InningsResolver.simulate_innings(a, 5, 5, 5, tuning, itun, r1, 0, null, null, null, 0, 0, 0, jk, true)
	var r2 := RandomNumberGenerator.new(); r2.seed = 5
	var second := InningsResolver.simulate_innings(a, 5, 5, 5, tuning, itun, r2, 0, null, null, null, 0, 0, 0, jk, true)
	assert_eq(first.total, second.total)
	assert_eq(first.wickets, second.wickets)
	assert_eq(first.balls, second.balls)

# --- C2d: setNextBowler windows + The Trap ---

func _pace_pack_strong() -> Array:
	# CHANGE_PACE shape, strong wicket boost for a clean directional signal.
	return [JokerEffect.make("pp", "Pace Pack", "Common", JokerEffect.Side.BOWLING,
		JokerEffect.Target.WICKET, 2.0, -1, 1, 120, -1, -1, -1, JokerEffect.Trigger.CHANGE_PACE, 6)]

func _the_trap_strong() -> Array:
	# Stateless: catching field + spin bowler, strong wicket boost.
	return [JokerEffect.make("trap", "The Trap", "Rare", JokerEffect.Side.BOWLING,
		JokerEffect.Target.WICKET, 1.5, -1, 1, 120, FieldPlan.Mode.CATCHING, -1, -1,
		JokerEffect.Trigger.NONE, 0, BowlingPlan.Kind.SPIN)]

func test_pace_pack_raises_opposition_wickets() -> void:
	# Player bowling an all-pace plan: a change at overs 1/7/16 fires the wicket window.
	var tuning := BallTuning.new(); var itun := InningsTuning.new()
	var plan := BowlingPlan.pace_only()
	var jk := _pace_pack_strong()
	var base_w := 0; var buff_w := 0
	for i in range(200):
		var r1 := RandomNumberGenerator.new(); r1.seed = i
		base_w += InningsResolver.simulate_innings(null, 5, 5, 5, tuning, itun, r1, 0, null, null, plan, 0, 0, 0, [], false).wickets
		var r2 := RandomNumberGenerator.new(); r2.seed = i
		buff_w += InningsResolver.simulate_innings(null, 5, 5, 5, tuning, itun, r2, 0, null, null, plan, 0, 0, 0, jk, false).wickets
	assert_gt(buff_w, base_w, "a pace-change wicket window should raise opposition wickets")

func test_the_trap_raises_wickets_under_catching_spin() -> void:
	var tuning := BallTuning.new(); var itun := InningsTuning.new()
	var plan := BowlingPlan.spin_only()
	var field := FieldPlan.catching()
	var jk := _the_trap_strong()
	var base_w := 0; var buff_w := 0
	for i in range(200):
		var r1 := RandomNumberGenerator.new(); r1.seed = i
		base_w += InningsResolver.simulate_innings(null, 5, 5, 5, tuning, itun, r1, 0, null, null, plan, 0, 0, 0, [], false, field).wickets
		var r2 := RandomNumberGenerator.new(); r2.seed = i
		buff_w += InningsResolver.simulate_innings(null, 5, 5, 5, tuning, itun, r2, 0, null, null, plan, 0, 0, 0, jk, false, field).wickets
	assert_gt(buff_w, base_w, "The Trap should raise wickets when the field is catching and the bowler is spin")

# --- C2f: DRS ---

func test_drs_lowers_player_dismissals() -> void:
	# A review-to-survive policy means the Player is dismissed less often.
	var tuning := BallTuning.new(); var itun := InningsTuning.new()
	var a := _attrs()
	var policy := DRSPolicy.new()  # base 1 review, p 0.4
	# Track how often the Player batter is out across many innings.
	var base_out := 0; var drs_out := 0
	for i in range(200):
		var r1 := RandomNumberGenerator.new(); r1.seed = i
		base_out += _player_out_count(InningsResolver.simulate_innings(a, 5, 5, 5, tuning, itun, r1, 0, null, null, null, 0, 0, 0, [], true, null, null, null, null))
		var r2 := RandomNumberGenerator.new(); r2.seed = i
		drs_out += _player_out_count(InningsResolver.simulate_innings(a, 5, 5, 5, tuning, itun, r2, 0, null, null, null, 0, 0, 0, [], true, null, null, null, policy))
	assert_lt(drs_out, base_out, "DRS review-to-survive should lower Player dismissals")

func _player_out_count(res: InningsResult) -> int:
	for b in res.batters:
		if b.get("is_player", false) and b.get("out", false):
			return 1
	return 0

func test_determinism_with_drs_policy() -> void:
	var tuning := BallTuning.new(); var itun := InningsTuning.new()
	var a := _attrs()
	var policy := DRSPolicy.new()
	var r1 := RandomNumberGenerator.new(); r1.seed = 29
	var first := InningsResolver.simulate_innings(a, 5, 5, 5, tuning, itun, r1, 0, null, null, null, 0, 0, 0, [], true, null, null, null, policy)
	var r2 := RandomNumberGenerator.new(); r2.seed = 29
	var second := InningsResolver.simulate_innings(a, 5, 5, 5, tuning, itun, r2, 0, null, null, null, 0, 0, 0, [], true, null, null, null, policy)
	assert_eq(first.total, second.total)
	assert_eq(first.wickets, second.wickets)

func test_null_drs_policy_is_baseline() -> void:
	# No DRSPolicy -> no review attempts -> byte-identical to the default call.
	var tuning := BallTuning.new(); var itun := InningsTuning.new()
	var a := _attrs()
	for i in range(20):
		var r1 := RandomNumberGenerator.new(); r1.seed = i
		var base := InningsResolver.simulate_innings(a, 5, 5, 5, tuning, itun, r1)
		var r2 := RandomNumberGenerator.new(); r2.seed = i
		var same := InningsResolver.simulate_innings(a, 5, 5, 5, tuning, itun, r2, 0, null, null, null, 0, 0, 0, [], true, null, null, null, null)
		assert_eq(base.total, same.total)
		assert_eq(base.wickets, same.wickets)

# --- C2e: Manager Boost ---

func test_boost_plan_raises_player_runs() -> void:
	# A press in the powerplay buffs the Player's batting -> more runs.
	var tuning := BallTuning.new(); var itun := InningsTuning.new()
	var a := _attrs()
	var plan := BoostPlan.at([1, 3])
	var base_r := 0; var boost_r := 0
	for i in range(200):
		var r1 := RandomNumberGenerator.new(); r1.seed = i
		base_r += InningsResolver.simulate_innings(a, 5, 5, 5, tuning, itun, r1, 0, null, null, null, 0, 0, 0, [], true, null, null, null).total
		var r2 := RandomNumberGenerator.new(); r2.seed = i
		boost_r += InningsResolver.simulate_innings(a, 5, 5, 5, tuning, itun, r2, 0, null, null, null, 0, 0, 0, [], true, null, null, plan).total
	assert_gt(boost_r, base_r, "a Manager Boost press should raise the Player's runs")

func test_determinism_with_boost_plan() -> void:
	var tuning := BallTuning.new(); var itun := InningsTuning.new()
	var a := _attrs()
	var plan := BoostPlan.at([1, 10])
	var r1 := RandomNumberGenerator.new(); r1.seed = 23
	var first := InningsResolver.simulate_innings(a, 5, 5, 5, tuning, itun, r1, 0, null, null, null, 0, 0, 0, [], true, null, null, plan)
	var r2 := RandomNumberGenerator.new(); r2.seed = 23
	var second := InningsResolver.simulate_innings(a, 5, 5, 5, tuning, itun, r2, 0, null, null, null, 0, 0, 0, [], true, null, null, plan)
	assert_eq(first.total, second.total)
	assert_eq(first.wickets, second.wickets)

func test_determinism_with_change_jokers() -> void:
	var tuning := BallTuning.new(); var itun := InningsTuning.new()
	var plan := BowlingPlan.pace_only()
	var jk := _pace_pack_strong()
	var r1 := RandomNumberGenerator.new(); r1.seed = 17
	var first := InningsResolver.simulate_innings(null, 5, 5, 5, tuning, itun, r1, 0, null, null, plan, 0, 0, 0, jk, false)
	var r2 := RandomNumberGenerator.new(); r2.seed = 17
	var second := InningsResolver.simulate_innings(null, 5, 5, 5, tuning, itun, r2, 0, null, null, plan, 0, 0, 0, jk, false)
	assert_eq(first.total, second.total)
	assert_eq(first.wickets, second.wickets)
	assert_eq(first.balls, second.balls)
