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

# DF3: with a high-success DRS, a derived (non-hero) innings still gets reviews on
# dismissals -> fewer wickets fall than with no DRS. Pre-fix this was hero-only, so
# a null-player innings got ZERO reviews; now any dismissal can be reviewed.
func test_drs_reviews_any_dismissal_not_just_hero() -> void:
	var hi := DRSPolicy.new()
	hi.base_reviews = 50      # effectively unlimited for the test
	hi.base_p = 1.0           # always overturns
	var no_drs := InningsResolver.simulate_innings(
		null, 5, 5.0, 5.0, _tuning(), _itun(), _rng(42))
	var with_drs := InningsResolver.simulate_innings(
		null, 5, 5.0, 5.0, _tuning(), _itun(), _rng(42), 0, null, null, null,
		0, 0, 0, [], true, null, null, null, hi)
	assert_lt(with_drs.wickets, no_drs.wickets,
		"team-wide DRS should save non-hero batters too")

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
func test_opponent_drs_saves_opponent_wickets() -> void:
	var hi := DRSPolicy.new()
	hi.base_reviews = 50
	hi.base_p = 1.0
	var base := InningsResolver.simulate_innings(
		null, 5, 5.0, 5.0, _tuning(), _itun(), _rng(7), 0, null, null, null,
		0, 0, 0, [], false)
	var saved := InningsResolver.simulate_innings(
		null, 5, 5.0, 5.0, _tuning(), _itun(), _rng(7), 0, null, null, null,
		0, 0, 0, [], false, null, null, null, null, null, [], 0, null, hi)
	assert_lt(saved.wickets, base.wickets, "opponent DRS should save opponent batters")

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
	t.mean = 5; t.spread = 1.5; t.noise = 1
	return t

func _attrs() -> Attributes:
	var a := Attributes.new()
	a.power = 5; a.composure = 5; a.attack = 5; a.control = 5
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
