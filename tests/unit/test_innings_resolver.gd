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
