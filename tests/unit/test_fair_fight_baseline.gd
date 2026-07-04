extends GutTest

# Fair-fight baseline (spec 2026-06-09): team-wide DRS, 2 reviews, opponent base
# boost + DRS. resolve_ball owns the RNG draw order; same seed -> same result.

func _tuning() -> BallTuning:
	return BallTuning.new()

func _itun() -> InningsTuning:
	return InningsTuning.new()

func _rng(seed_val: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_val
	return r

# DF3: with a forced-success DRS, a derived (non-hero) innings still gets reviews
# on MOMENT dismissals (spec 2026-07-04: reviewable flavour + set/death gate) ->
# fewer wickets fall than with no DRS. Summed over seeds so at least some innings
# produce qualifying moments.
func test_drs_reviews_any_dismissal_not_just_hero() -> void:
	var no_sum := 0
	var with_sum := 0
	for seed_value in range(40, 55):
		var hi := DRSPolicy.new()
		hi.base_reviews = 50            # effectively unlimited for the test
		hi.moment_p_override = 1.0      # every attempted review overturns
		no_sum += InningsResolver.simulate_innings(
			null, 5, 5.0, 5.0, _tuning(), _itun(), _rng(seed_value)).wickets
		with_sum += InningsResolver.simulate_innings(
			null, 5, 5.0, 5.0, _tuning(), _itun(), _rng(seed_value), 0, null, null, null,
			0, 0, 0, [], true, null, null, null, hi).wickets
	assert_lt(with_sum, no_sum,
		"team-wide DRS moments should save non-hero batters too (%d < %d over 15 seeds)" % [with_sum, no_sum])

# DF3: real T20 allows 2 unsuccessful reviews per innings.
func test_default_review_count_is_two() -> void:
	assert_eq(DRSPolicy.new().base_reviews, 2, "base_reviews default should be 2 (T20 rule)")

# DF4: the opponent's own boost buffs the opponent's batting innings (more runs).
# Summed over 30 paired seeds (was a single seed-7 innings, which tied 109-109
# when the bowling-balance rung re-pegged base_r — a one-seed coin flip).
func test_opponent_boost_lifts_opponent_innings() -> void:
	var boost := BoostPlan.at([1, 10, 16])
	# player_is_batting = false -> this is the opponent's batting innings.
	var base_sum := 0
	var boosted_sum := 0
	for seed_value in range(1, 31):
		base_sum += InningsResolver.simulate_innings(
			null, 5, 5.0, 5.0, _tuning(), _itun(), _rng(seed_value), 0, null, null, null,
			0, 0, 0, [], false).total
		boosted_sum += InningsResolver.simulate_innings(
			null, 5, 5.0, 5.0, _tuning(), _itun(), _rng(seed_value), 0, null, null, null,
			0, 0, 0, [], false, null, null, null, null, null, [], 0, boost, null).total
	assert_gt(boosted_sum, base_sum, "opponent boost should lift the opponent's score")

# DF5: the opponent reviews to survive its own dismissals (base rule, no jokers).
# Moment-gated since spec 2026-07-04 -> summed over seeds so qualifying moments occur.
func test_opponent_drs_saves_opponent_wickets() -> void:
	var base_sum := 0
	var saved_sum := 0
	for seed_value in range(1, 16):
		var hi := DRSPolicy.new()
		hi.base_reviews = 50
		hi.moment_p_override = 1.0
		base_sum += InningsResolver.simulate_innings(
			null, 5, 5.0, 5.0, _tuning(), _itun(), _rng(seed_value), 0, null, null, null,
			0, 0, 0, [], false).wickets
		saved_sum += InningsResolver.simulate_innings(
			null, 5, 5.0, 5.0, _tuning(), _itun(), _rng(seed_value), 0, null, null, null,
			0, 0, 0, [], false, null, null, null, null, null, [], 0, null, hi).wickets
	assert_lt(saved_sum, base_sum,
		"opponent DRS moments should save opponent batters (%d < %d over 15 seeds)" % [saved_sum, base_sum])

# DF5: the opponent also reviews to CLAIM while bowling — a Player dot can be
# overturned to a wicket. Use a strong batting side vs weak bowling so the base case
# is NOT bowled out; then a claim-everything DRS (base_p=1.0) knocks it over.
# (player_is_batting defaults to true here.)
func test_opponent_claim_review_takes_player_wickets() -> void:
	var hi := DRSPolicy.new()
	hi.base_reviews = 50
	hi.base_p = 1.0
	var base := InningsResolver.simulate_innings(
		null, 12, 2.0, 2.0, _tuning(), _itun(), _rng(7))
	var claimed := InningsResolver.simulate_innings(
		null, 12, 2.0, 2.0, _tuning(), _itun(), _rng(7), 0, null, null, null,
		0, 0, 0, [], true, null, null, null, null, null, [], 0, null, hi)
	assert_gt(claimed.wickets, base.wickets, "opponent claim-review should take Player wickets")

# DRS team-wide fix (spec 2026-06-10, DD6): the PLAYER slot's claim review must
# fire on ALL overs, even with ZERO hero-bowled overs. Opponent batting innings
# (player_is_batting=false), player_bowler_overs=0, claim-everything Player DRS
# -> more opponent wickets than the no-DRS base. Pre-fix the player_bowling gate
# made this structurally impossible (0 hero overs -> 0 claims).
func test_player_claim_review_is_team_wide() -> void:
	var hi := DRSPolicy.new()
	hi.base_reviews = 50
	hi.base_p = 1.0
	var base := InningsResolver.simulate_innings(
		null, 12, 2.0, 2.0, _tuning(), _itun(), _rng(7), 0, null, null, null,
		0, 0, 0, [], false)
	var claimed := InningsResolver.simulate_innings(
		null, 12, 2.0, 2.0, _tuning(), _itun(), _rng(7), 0, null, null, null,
		0, 0, 0, [], false, null, null, null, hi)
	assert_gt(claimed.wickets, base.wickets,
		"Player claim-review should take opponent wickets on non-hero overs")

func _tour() -> TourDistribution:
	var t := TourDistribution.new()
	t.mean = 31.25; t.spread = 9.375
	return t

func _attrs() -> Attributes:
	var a := Attributes.new()
	a.power = 31.25; a.composure = 31.25; a.attack = 31.25; a.control = 31.25
	return a

# DF2: the opponent's tools are wired through the match (both innings). A strong
# opponent batting boost (runs x2 all innings) makes the opponent post far more, so
# the Player wins much less — an unmistakable directional check that the opponent
# tooling reaches the sim. (The *base* boost is a small lever; this exaggerates it to
# prove the plumbing. Runs, not wickets, decide the match — at even strength neither
# side is bowled out, so a wicket-only lever like DRS barely moves the result; the
# opponent DRS wiring is verified at the innings level and threads identically.)
func test_opponent_boost_reaches_the_match() -> void:
	var strong_boost := BoostPlan.new()
	strong_boost.press_overs = [1]
	strong_boost.base_mult = 2.0   # x2 runs
	strong_boost.base_n = 120      # whole innings
	var pt := Team.new(); pt.stars = 3.0
	var ot := Team.new(); ot.stars = 3.0
	var wins_passive := 0
	var wins_armed := 0
	for i in 120:
		var rp := _rng(1000 + i)
		var mp := MatchResolver.simulate_match_teams(_attrs(), pt, ot, _tour(),
			_tuning(), _itun(), rp)
		if mp.outcome == MatchResult.Outcome.PLAYER_WIN: wins_passive += 1
		var ra := _rng(1000 + i)
		var ma := MatchResolver.simulate_match_teams(_attrs(), pt, ot, _tour(),
			_tuning(), _itun(), ra, null, null, [], null, null, null, null, null, null, strong_boost, null)
		if ma.outcome == MatchResult.Outcome.PLAYER_WIN: wins_armed += 1
	assert_lt(wins_armed, wins_passive, "a strong opponent boost should sharply lower the Player win-rate")

# T9 (spec 2026-07-04 DW3/DW8): the resolver logs the PLAYER meter's fill and
# drain state per ball. A press at over 2 (ball 7, log index 6) locks off a full
# meter (fill still 1.0 at the instant of the press); the meter then drains over
# exactly base_n=6 balls, landing empty at over 3's first ball (index 12), which
# is also the first recharging tick.
func test_log_carries_meter_fill_and_drain() -> void:
	var boost := BoostPlan.at([2])
	var log := []
	InningsResolver.simulate_innings(
		null, 5, 5.0, 5.0, _tuning(), _itun(), _rng(7), 0, null, null, null,
		0, 0, 0, [], true, null, null, boost, null, null, [], 1.0, null, null, log)
	assert_gte(log.size(), 13, "innings should run past over 3 for this seed")
	assert_almost_eq(log[0]["boost_fill"], 1.0, 0.001, "over 1, no press yet -> full meter")
	assert_false(log[0]["boost_draining"], "over 1 -> not draining")
	assert_true(log[6]["boost_pressed"], "over 2 ball 1 -> press fires")
	assert_true(log[6]["boost_draining"], "just pressed -> draining")
	assert_almost_eq(log[6]["boost_fill"], 1.0, 0.001, "press locks from a still-full meter")
	assert_almost_eq(log[12]["boost_fill"], 0.0, 0.001, "6-ball drain done by over 3 ball 1")
	assert_false(log[12]["boost_draining"], "drain window closed -> recharging, not draining")

# T9/DW5: a second press attempted while the meter is still draining (fill 0,
# below MIN_PRESS_FILL) is a no-op — try_press returns {} and boost_pressed stays
# false for that ball.
func test_press_while_draining_is_ignored_by_resolver() -> void:
	var boost := BoostPlan.at([2, 3])
	var log := []
	InningsResolver.simulate_innings(
		null, 5, 5.0, 5.0, _tuning(), _itun(), _rng(7), 0, null, null, null,
		0, 0, 0, [], true, null, null, boost, null, null, [], 1.0, null, null, log)
	assert_gte(log.size(), 13, "innings should run past over 3 for this seed")
	assert_false(log[12]["boost_pressed"], "over-3 press on an empty meter is a no-op (DW5)")

# T9/DW13: MatchResolver must route innings-aware press_pairs so a live session
# press fires only in its own innings. A flat plan (press_overs, no pairs) has no
# innings concept and — being applied via for_innings passthrough — still presses
# in BOTH innings (the pre-existing, byte-identical flat behaviour). A pairs plan
# scoped to innings 1 must NOT also fire in innings 2.
func test_press_pairs_do_not_double_fire_across_innings() -> void:
	var flat := BoostPlan.new()
	flat.press_overs = [1]
	flat.base_mult = 2.0
	flat.base_n = 120

	var paired := BoostPlan.new()
	paired.press_pairs = [[1, 1]]
	paired.base_mult = 2.0
	paired.base_n = 120

	var log1_flat := []
	var log2_flat := []
	var ra := _rng(2026)
	var ma := MatchResolver.simulate_match_teams(_attrs(), Team.new(), Team.new(), _tour(),
		_tuning(), _itun(), ra, null, null, [], null, null, null, flat, null, null, null, null,
		1, null, log1_flat, log2_flat)

	var log1_paired := []
	var log2_paired := []
	var rb := _rng(2026)
	var mb := MatchResolver.simulate_match_teams(_attrs(), Team.new(), Team.new(), _tour(),
		_tuning(), _itun(), rb, null, null, [], null, null, null, paired, null, null, null, null,
		1, null, log1_paired, log2_paired)

	assert_eq(ma.innings1.total, mb.innings1.total,
		"same seed + same innings-1 press -> identical innings-1 totals")
	assert_true(log2_flat[0]["boost_pressed"], "flat plan leaks its press into innings 2")
	assert_false(log2_paired[0]["boost_pressed"], "paired plan stays scoped to innings 1 only")
