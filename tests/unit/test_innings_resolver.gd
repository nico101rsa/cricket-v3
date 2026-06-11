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

func test_pure_batter_bowls_no_overs() -> void:
	# 8/8/2/2: share 0.2 -> 8*0.2 - 2.5 = -0.9 -> round -1 -> clamp 0
	assert_eq(InningsResolver.player_overs(_attrs(8, 8, 2, 2), itun), 0, "specialist batter doesn't bowl")

func test_even_build_bowls_full_quota() -> void:
	# 5/5/5/5: share 0.5 -> 13*0.5 - 2.6 = 3.9 -> round 4 (a real all-rounder bowls out)
	assert_eq(InningsResolver.player_overs(_attrs(5, 5, 5, 5), itun), 4, "all-rounder bowls the full 4-over quota (authenticity)")

func test_batting_ish_build_bowls_somewhat() -> void:
	# 7/7/3/3: share 0.3 -> 13*0.3 - 2.6 = 1.3 -> round 1 (bowls somewhat, not zero — DA5)
	assert_eq(InningsResolver.player_overs(_attrs(7, 7, 3, 3), itun), 1, "a 7/7 bowls somewhat (~1 over), not zero")

func test_pure_bowler_bowls_full_quota() -> void:
	# 2/2/8/8: share 0.8 -> 8*0.8 - 2.5 = 3.9 -> round 4 (== max)
	assert_eq(InningsResolver.player_overs(_attrs(2, 2, 8, 8), itun), 4, "specialist bowler bowls the full quota")

func test_overs_monotonic_in_bowling_share() -> void:
	var batter := InningsResolver.player_overs(_attrs(8, 8, 2, 2), itun)
	var mid := InningsResolver.player_overs(_attrs(5, 5, 5, 5), itun)
	var bowler := InningsResolver.player_overs(_attrs(2, 2, 8, 8), itun)
	assert_lte(batter, mid, "more bowling share never fewer overs (batter<=mid)")
	assert_lte(mid, bowler, "more bowling share never fewer overs (mid<=bowler)")

func test_bowling_over_set_evenly_spaced() -> void:
	assert_eq(InningsResolver.player_bowling_overs(0, 20), [], "zero overs -> empty set")
	var set4 := InningsResolver.player_bowling_overs(4, 20)
	assert_eq(set4.size(), 4, "4 overs -> 4 entries")
	# distinct + within 1..20
	var seen := {}
	for o in set4:
		assert_between(o, 1, 20, "over %d within innings" % o)
		assert_false(seen.has(o), "overs distinct")
		seen[o] = true

func test_player_bowler_off_matches_baseline() -> void:
	# New trailing params default to off -> byte-identical to a call without them.
	var base := InningsResolver.simulate_innings(null, 5, 5, 5, tuning, itun, _make_rng(777))
	var off := InningsResolver.simulate_innings(null, 5, 5, 5, tuning, itun, _make_rng(777), 0, null, null, null, 0, 0, 0)
	assert_eq(base.total, off.total, "off-by-default total identical")
	assert_eq(base.wickets, off.wickets, "off-by-default wickets identical")
	assert_eq(base.balls, off.balls, "off-by-default balls identical")

func _avg_conceded(p_attack: int, p_control: int, n: int) -> float:
	# Opposition (null Player) batting at strength 5 vs a team bowling 5/5, where the
	# Player bowls 4 overs at (p_attack, p_control). Paired seeds across the two arms.
	var total := 0
	for seed_value in range(1, n + 1):
		total += InningsResolver.simulate_innings(
			null, 5, 5, 5, tuning, itun, _make_rng(seed_value),
			0, null, null, null, p_attack, p_control, 4).total
	return float(total) / n

func test_strong_player_bowler_concedes_fewer_runs() -> void:
	var weak := _avg_conceded(2, 2, 80)
	var strong := _avg_conceded(8, 8, 80)
	assert_lt(strong, weak, "a strong Player bowler concedes fewer runs than a weak one")

func test_innings_deterministic_with_player_bowler() -> void:
	var r1 := InningsResolver.simulate_innings(null, 5, 5, 5, tuning, itun, _make_rng(99), 0, null, null, null, 8, 8, 4)
	var r2 := InningsResolver.simulate_innings(null, 5, 5, 5, tuning, itun, _make_rng(99), 0, null, null, null, 8, 8, 4)
	assert_eq(r1.total, r2.total, "deterministic total")
	assert_eq(r1.wickets, r2.wickets, "deterministic wickets")

func test_player_bowling_figures_zero_when_not_bowling() -> void:
	var r := InningsResolver.simulate_innings(null, 5, 5, 5, tuning, itun, _make_rng(5))
	assert_eq(r.player_bowl_balls, 0, "no balls bowled when Player isn't bowling")
	assert_eq(r.player_bowl_wickets, 0, "no wickets")
	assert_eq(r.player_bowl_runs, 0, "no runs conceded")

func test_player_bowling_figures_bounds_and_consistency() -> void:
	# Player bowls 4 overs; figures stay within the innings and within the quota.
	for seed_value in range(1, 40):
		var r := InningsResolver.simulate_innings(
			null, 5, 5, 5, tuning, itun, _make_rng(seed_value), 0, null, null, null, 7, 7, 4)
		assert_lte(r.player_bowl_balls, 24, "<= 4 overs bowled (seed %d)" % seed_value)
		assert_lte(r.player_bowl_wickets, r.wickets, "Player wickets <= innings wickets (seed %d)" % seed_value)
		assert_lte(r.player_bowl_runs, r.total, "Player runs conceded <= innings total (seed %d)" % seed_value)

func _avg_player_economy(p_attack: int, p_control: int, n: int) -> float:
	var runs := 0
	var balls := 0
	for seed_value in range(1, n + 1):
		var r := InningsResolver.simulate_innings(
			null, 5, 5, 5, tuning, itun, _make_rng(seed_value), 0, null, null, null, p_attack, p_control, 4)
		runs += r.player_bowl_runs
		balls += r.player_bowl_balls
	return 6.0 * runs / balls  # runs per over

func test_strong_player_bowler_has_better_economy() -> void:
	var weak := _avg_player_economy(2, 2, 60)
	var strong := _avg_player_economy(8, 8, 60)
	assert_lt(strong, weak, "a strong Player bowler concedes fewer runs per over than a weak one")

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

func test_null_bowling_matches_scalar_baseline() -> void:
	# No bowling_attack/plan must reproduce the constant-pair (rung 4a) result.
	var a := _attrs(5, 5, 5, 5)
	var base := InningsResolver.simulate_innings(a, 5, 5, 5, tuning, itun, _rng(7))
	var explicit := InningsResolver.simulate_innings(
		a, 5, 5, 5, tuning, itun, _rng(7), 0, null, null, null)
	assert_eq(base.total, explicit.total, "null bowling == scalar total")
	assert_eq(base.wickets, explicit.wickets, "null bowling == scalar wickets")
	assert_eq(base.balls, explicit.balls, "null bowling == scalar balls")

func test_innings_deterministic_with_rotation() -> void:
	var a := _attrs(5, 5, 5, 5)
	var ba := BowlingAttack.new(5, 5)
	var r1 := InningsResolver.simulate_innings(
		a, 5, 5, 5, tuning, itun, _rng(99), 0, null, ba, BowlingPlan.textbook())
	var r2 := InningsResolver.simulate_innings(
		a, 5, 5, 5, tuning, itun, _rng(99), 0, null, ba, BowlingPlan.textbook())
	assert_eq(r1.total, r2.total, "same seed + rotation -> same total")
	assert_eq(r1.wickets, r2.wickets, "same seed + rotation -> same wickets")

func test_pace_takes_more_wickets_at_higher_run_rate_than_spin() -> void:
	# Intent held BALANCED (null) to isolate the bowling tilt. Pace = more
	# wickets AND higher run RATE (not total: more wickets can end an innings
	# early and truncate the total).
	var a := _attrs(5, 5, 5, 5)
	var ba := BowlingAttack.new(5, 5)
	var pace := BowlingPlan.pace_only()
	var spin := BowlingPlan.spin_only()
	var pace_runs := 0
	var pace_balls := 0
	var pace_wkts := 0
	var spin_runs := 0
	var spin_balls := 0
	var spin_wkts := 0
	for sv in range(1, 41):
		var rp := InningsResolver.simulate_innings(a, 5, 5, 5, tuning, itun, _rng(sv), 0, null, ba, pace)
		var rs := InningsResolver.simulate_innings(a, 5, 5, 5, tuning, itun, _rng(sv), 0, null, ba, spin)
		pace_runs += rp.total
		pace_balls += rp.balls
		pace_wkts += rp.wickets
		spin_runs += rs.total
		spin_balls += rs.balls
		spin_wkts += rs.wickets
	assert_gt(pace_wkts, spin_wkts, "pace takes more wickets over 40 innings")
	var pace_rate := float(pace_runs) / float(pace_balls)
	var spin_rate := float(spin_runs) / float(spin_balls)
	assert_gt(pace_rate, spin_rate, "pace concedes a higher run rate than spin")

# --- Slice 2: _build_batters real-roster path ---------------------------------

func test_build_batters_clone_path_unchanged_when_no_roster() -> void:
	var batters := InningsResolver._build_batters(null, 5, itun)
	assert_eq(batters.size(), 11, "11 batters")
	assert_eq(batters[0]["power"], 5, "opener clone == partner_batting * factor(1)=1.0")
	assert_lt(batters[10]["power"], batters[0]["power"], "tail weaker than opener (clone path)")

func test_build_batters_uses_real_roster_individuals() -> void:
	var roster := Team.standard_xi()
	var batters := InningsResolver._build_batters(null, 5, itun, roster, 0)
	assert_eq(batters.size(), 11, "11 batters")
	assert_eq(batters[0]["power"], 8, "top order is a real BATTER (power 8, no tail-scaling)")
	assert_eq(batters[0]["composure"], 8, "composure also from the archetype")
	assert_eq(batters[10]["power"], 1, "tail is a real BOWLER (power 1, steep tail BB5)")
	for b in batters:
		assert_false(b["is_player"], "opposition roster has no Player slot")

func test_build_batters_offset_applied_and_floored() -> void:
	var roster := Team.standard_xi()
	var up := InningsResolver._build_batters(null, 5, itun, roster, 2)
	assert_eq(up[0]["power"], 10, "offset lifts the top order (8+2)")
	assert_eq(up[10]["power"], 3, "offset lifts the tail (1+2)")
	var down := InningsResolver._build_batters(null, 5, itun, roster, -5)
	assert_eq(down[10]["power"], 1, "power floored at 1 (1-5 clamped)")

func test_build_batters_flags_player_by_identity() -> void:
	var player := _attrs(8, 8, 2, 2)            # pure batter -> position 3
	var ppos := InningsResolver.player_position(player, itun)
	var roster := Team.build_xi(player, ppos)
	var batters := InningsResolver._build_batters(player, 5, itun, roster, 0)
	assert_true(batters[ppos - 1]["is_player"], "the Player slot is flagged at ppos")
	var player_flags := 0
	for b in batters:
		if b["is_player"]:
			player_flags += 1
	assert_eq(player_flags, 1, "exactly one Player slot")

# --- Slice 2: simulate_innings roster threading -------------------------------

func test_simulate_innings_roster_default_unchanged() -> void:
	var a := _attrs(5, 5, 5, 5)
	var rng1 := RandomNumberGenerator.new(); rng1.seed = 99
	var rng2 := RandomNumberGenerator.new(); rng2.seed = 99
	var base := InningsResolver.simulate_innings(a, 5, 5, 5, tuning, itun, rng1)
	var same := InningsResolver.simulate_innings(a, 5, 5, 5, tuning, itun, rng2, 0,
		null, null, null, 0, 0, 0, [], true, null, null, null, null, null, [], 0)
	assert_eq(base.total, same.total, "empty roster == old behaviour (total)")
	assert_eq(base.wickets, same.wickets, "empty roster == old behaviour (wickets)")

func test_simulate_innings_roster_is_deterministic() -> void:
	var roster := Team.standard_xi()
	var rng1 := RandomNumberGenerator.new(); rng1.seed = 7
	var rng2 := RandomNumberGenerator.new(); rng2.seed = 7
	var r1 := InningsResolver.simulate_innings(null, 5, 5, 5, tuning, itun, rng1, 0,
		null, null, null, 0, 0, 0, [], false, null, null, null, null, null, roster, 0)
	var r2 := InningsResolver.simulate_innings(null, 5, 5, 5, tuning, itun, rng2, 0,
		null, null, null, 0, 0, 0, [], false, null, null, null, null, null, roster, 0)
	assert_eq(r1.total, r2.total, "roster innings deterministic")

func test_simulate_innings_real_roster_outscores_weak_clone() -> void:
	var roster := Team.standard_xi()
	var roster_runs := 0
	var clone_runs := 0
	for s in range(40):
		var rr := RandomNumberGenerator.new(); rr.seed = s
		roster_runs += InningsResolver.simulate_innings(null, 2, 5, 5, tuning, itun, rr, 0,
			null, null, null, 0, 0, 0, [], false, null, null, null, null, null, roster, 0).total
		var cr := RandomNumberGenerator.new(); cr.seed = s
		clone_runs += InningsResolver.simulate_innings(null, 2, 5, 5, tuning, itun, cr).total
	assert_gt(roster_runs, clone_runs, "real top-order roster outscores a weak flat clone")
