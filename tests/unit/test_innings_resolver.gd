extends GutTest

var tuning: BallTuning
var itun: InningsTuning

func before_each() -> void:
	tuning = BallTuning.new()
	itun = InningsTuning.new()

func _attrs(power: int, comp: int, attack: int, control: int) -> Attributes:
	var a := Attributes.new()
	a.power = power
	a.composure = comp
	a.attack = attack
	a.control = control
	return a

func test_pure_batter_bats_top_order() -> void:
	# 8/8/2/2: batting 16 vs bowling 4 -> share 0.8 -> pos round(9-6.4)=3
	var pos := InningsResolver.player_position(_attrs(8, 8, 2, 2), itun)
	assert_lte(pos, 3, "pure batter opens / top order")

func test_pure_bowler_bats_tail() -> void:
	# 2/2/8/8: share 0.2 -> pos round(9-1.6)=7
	var pos := InningsResolver.player_position(_attrs(2, 2, 8, 8), itun)
	assert_gte(pos, 7, "pure bowler bats the tail")

func test_even_build_bats_middle() -> void:
	var pos := InningsResolver.player_position(_attrs(5, 5, 5, 5), itun)
	assert_eq(pos, 5, "even build -> #5")

func test_position_clamped_to_range() -> void:
	var pos := InningsResolver.player_position(_attrs(8, 8, 1, 1), itun)
	assert_between(pos, 1, 9, "position stays in 1..9")

func test_tail_factor_full_at_top_floors_at_bottom() -> void:
	assert_almost_eq(InningsResolver.partner_factor(1, itun), 1.0, 0.0001, "opener at full strength")
	# pos 11: 1 - 10*0.07 = 0.30, below floor 0.45 -> clamped to floor
	assert_almost_eq(InningsResolver.partner_factor(11, itun), 0.45, 0.0001, "#11 floored")
	assert_gt(InningsResolver.partner_factor(2, itun), InningsResolver.partner_factor(8, itun), "tail weakens down the order")

func _make_rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng

func _sim(attrs: Attributes, partner: int, oa: int, oc: int, seed_value: int) -> InningsResult:
	return InningsResolver.simulate_innings(attrs, partner, oa, oc, tuning, itun, _make_rng(seed_value))

func test_same_seed_gives_identical_innings() -> void:
	var a := _attrs(5, 5, 5, 5)
	var r1 := _sim(a, 5, 5, 5, 4242)
	var r2 := _sim(a, 5, 5, 5, 4242)
	assert_eq(r1.total, r2.total, "total deterministic")
	assert_eq(r1.wickets, r2.wickets, "wickets deterministic")
	assert_eq(r1.balls, r2.balls, "balls deterministic")
	assert_eq(r1.fall_of_wickets.size(), r2.fall_of_wickets.size(), "fall sequence deterministic")

func test_termination_bounds() -> void:
	for seed_value in range(1, 60):
		var r := _sim(_attrs(5, 5, 5, 5), 5, 5, 5, seed_value)
		assert_lte(r.balls, 120, "<= 120 balls at seed %d" % seed_value)
		assert_lte(r.wickets, 10, "<= 10 wickets at seed %d" % seed_value)
		assert_eq(r.batters.size(), 11, "always 11 batters")

func test_all_out_stops_immediately() -> void:
	var seen_all_out := false
	for seed_value in range(1, 40):
		var r := _sim(_attrs(2, 2, 8, 8), 2, 14, 14, seed_value)
		if r.wickets == 10:
			seen_all_out = true
			assert_lt(r.balls, 120, "all out should end before 120 balls (seed %d)" % seed_value)
	assert_true(seen_all_out, "a brutal mismatch should bowl the side out in some seeds")

func _avg_player_balls(attrs: Attributes, n: int) -> float:
	var total := 0
	for seed_value in range(1, n + 1):
		total += _sim(attrs, 5, 5, 5, seed_value).player_line()["balls"]
	return float(total) / n

func test_participation_responds_to_build() -> void:
	var batter_balls := _avg_player_balls(_attrs(8, 8, 2, 2), 60)
	var bowler_balls := _avg_player_balls(_attrs(2, 2, 8, 8), 60)
	assert_gt(batter_balls, bowler_balls, "a batter-build Player faces more balls than a bowler-build Player")

func _avg_total(attrs: Attributes, partner: int, oa: int, oc: int, it: InningsTuning, n: int) -> float:
	var total := 0
	for seed_value in range(1, n + 1):
		total += InningsResolver.simulate_innings(attrs, partner, oa, oc, tuning, it, _make_rng(seed_value)).total
	return float(total) / n

func test_weakening_tail_drags_total_down() -> void:
	var flat := InningsTuning.new()
	flat.tail_floor = 1.0
	flat.tail_slope = 0.0
	var with_tail := _avg_total(_attrs(5, 5, 5, 5), 5, 5, 5, itun, 80)
	var flat_total := _avg_total(_attrs(5, 5, 5, 5), 5, 5, 5, flat, 80)
	assert_lt(with_tail, flat_total, "a weakening tail lowers the average total")

func test_even_contest_total_in_sane_t20_band() -> void:
	var avg := _avg_total(_attrs(5, 5, 5, 5), 5, 5, 5, itun, 200)
	assert_between(avg, 110.0, 175.0, "even-contest T20 total lands in a believable band (got %f)" % avg)

func test_player_line_integrity() -> void:
	var r := _sim(_attrs(8, 8, 2, 2), 5, 5, 5, 77)
	var line := r.player_line()
	assert_lte(line["runs"], r.total, "Player runs <= team total")
	assert_lte(line["balls"], r.balls, "Player balls <= team balls")

func test_strike_rotation_and_ball_accounting() -> void:
	var r := _sim(_attrs(5, 5, 5, 5), 5, 5, 5, 2024)
	# Every delivery is charged to exactly one batter.
	var summed := 0
	for b in r.batters:
		summed += b["balls"]
	assert_eq(summed, r.balls, "every ball is accounted to exactly one batter")
	# Strike rotated: the non-striking opener faced deliveries, which can only
	# happen via an odd-run swap or an end-of-over swap.
	var faced := 0
	for b in r.batters:
		if b["balls"] > 0:
			faced += 1
	assert_gt(faced, 1, "strike rotates across the partnership (more than one batter faces)")

func test_null_player_builds_all_derived() -> void:
	var r := InningsResolver.simulate_innings(null, 6, 5, 5, tuning, itun, _make_rng(7))
	assert_eq(r.batters.size(), 11, "still an 11-strong order")
	assert_eq(r.player_line(), {}, "no statted Player -> empty player line")
	for b in r.batters:
		assert_false(b["is_player"], "no batter flagged as the Player")
	assert_lte(r.balls, 120, "terminates within 120 balls")
	assert_lte(r.wickets, 10, "never more than 10 wickets")

func test_default_target_matches_explicit_zero() -> void:
	# Backward compat: the new trailing target defaults to 0 (no chase) and must
	# reproduce the rung-2 behaviour exactly.
	var a := _attrs(5, 5, 5, 5)
	var r1 := InningsResolver.simulate_innings(a, 5, 5, 5, tuning, itun, _make_rng(99))
	var r2 := InningsResolver.simulate_innings(a, 5, 5, 5, tuning, itun, _make_rng(99), 0)
	assert_eq(r1.total, r2.total, "total unchanged by explicit target=0")
	assert_eq(r1.wickets, r2.wickets, "wickets unchanged")
	assert_eq(r1.balls, r2.balls, "balls unchanged")

func test_chase_stops_when_target_reached() -> void:
	# A tiny target must be chased down well before 120 balls and without losing
	# all 10 wickets (even contest averages ~141, so target 10 falls quickly).
	var a := _attrs(5, 5, 5, 5)
	var saw_early := false
	for sv in range(1, 40):
		var r := InningsResolver.simulate_innings(a, 5, 5, 5, tuning, itun, _make_rng(sv), 10)
		if r.total >= 10:
			assert_lt(r.balls, 120, "reaching a tiny target stops the chase early (seed %d)" % sv)
			assert_lt(r.wickets, 10, "a chased-down target isn't an all-out (seed %d)" % sv)
			saw_early = true
	assert_true(saw_early, "a tiny target should be chased down in some seeds")

func _rng(seed_value: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	return r

func test_null_plan_matches_balanced_baseline() -> void:
	# A null plan must reproduce the pre-rung-4a BALANCED behaviour exactly.
	var a := _attrs(5, 5, 5, 5)
	var base := InningsResolver.simulate_innings(a, 5, 5, 5, tuning, itun, _rng(7), 0, null)
	var balanced := InningsResolver.simulate_innings(
		a, 5, 5, 5, tuning, itun, _rng(7), 0, IntentPlan.balanced())
	assert_eq(base.total, balanced.total, "null plan == balanced() plan total")
	assert_eq(base.wickets, balanced.wickets, "null plan == balanced() plan wickets")
	assert_eq(base.balls, balanced.balls, "null plan == balanced() plan balls")

func test_innings_deterministic_with_plan() -> void:
	var a := _attrs(5, 5, 5, 5)
	var r1 := InningsResolver.simulate_innings(
		a, 5, 5, 5, tuning, itun, _rng(99), 0, IntentPlan.textbook())
	var r2 := InningsResolver.simulate_innings(
		a, 5, 5, 5, tuning, itun, _rng(99), 0, IntentPlan.textbook())
	assert_eq(r1.total, r2.total, "same seed + plan -> same total")
	assert_eq(r1.wickets, r2.wickets, "same seed + plan -> same wickets")

func test_aggressive_outscores_and_outdies_defensive() -> void:
	# Coupling check: aggression scores faster AND loses more wickets.
	var a := _attrs(5, 5, 5, 5)
	var agg := IntentPlan.new()
	agg.powerplay = BallResolver.Intent.AGGRESSIVE
	agg.middle = BallResolver.Intent.AGGRESSIVE
	agg.death = BallResolver.Intent.AGGRESSIVE
	var def := IntentPlan.new()
	def.powerplay = BallResolver.Intent.DEFENSIVE
	def.middle = BallResolver.Intent.DEFENSIVE
	def.death = BallResolver.Intent.DEFENSIVE
	var agg_runs := 0
	var agg_wkts := 0
	var def_runs := 0
	var def_wkts := 0
	for sv in range(1, 41):
		var ra := InningsResolver.simulate_innings(a, 5, 5, 5, tuning, itun, _rng(sv), 0, agg)
		var rd := InningsResolver.simulate_innings(a, 5, 5, 5, tuning, itun, _rng(sv), 0, def)
		agg_runs += ra.total
		agg_wkts += ra.wickets
		def_runs += rd.total
		def_wkts += rd.wickets
	assert_gt(agg_runs, def_runs, "aggressive scores more over 40 innings")
	assert_gt(agg_wkts, def_wkts, "aggressive loses more wickets over 40 innings")
