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
