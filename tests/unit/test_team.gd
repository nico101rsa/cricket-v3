extends GutTest

func _tour(mean: int, spread: int, noise: int) -> TourDistribution:
	var t := TourDistribution.new()
	t.mean = mean
	t.spread = spread
	t.noise = noise
	return t

func _team(stars: float) -> Team:
	var tm := Team.new()
	tm.stars = stars
	return tm

func _rng(seed_value: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	return r

func test_stronger_stars_higher_mean_strength() -> void:
	var tour := _tour(5, 3, 1)
	var strong := _team(5.0)
	var weak := _team(1.0)
	var strong_sum := 0
	var weak_sum := 0
	var n := 200
	for s in range(n):
		strong_sum += strong.batting_strength(tour, _rng(s))
		weak_sum += weak.batting_strength(tour, _rng(s))
	assert_gt(strong_sum, weak_sum, "5.0 stars derives higher batting than 1.0 stars on average")

func test_noise_bounded_and_floored() -> void:
	var tour := _tour(5, 3, 1)
	var tm := _team(5.0)            # percentile(1.0) == 8
	for s in range(50):
		var v := tm.bowling_strength(tour, _rng(s))
		assert_true(v >= 7 and v <= 9, "5.0-star strength within mean+spread +- noise (got %d)" % v)
	# Floor: a tiny band + lowest star can push below 1; must clamp to 1.
	var tiny := _tour(1, 1, 5)     # percentile(0.1) == roundi(1 + (0.1-0.5)*2*1) == 0
	var cellar := _team(0.5)
	for s in range(50):
		assert_true(cellar.batting_strength(tiny, _rng(s)) >= 1, "strength floored at 1")

func test_zero_noise_matches_percentile() -> void:
	var tour := _tour(5, 3, 0)
	assert_eq(_team(5.0).batting_strength(tour, _rng(1)), tour.percentile(1.0), "5.0 stars, no noise -> percentile(1.0)")
	assert_eq(_team(0.5).bowling_strength(tour, _rng(1)), tour.percentile(0.1), "0.5 stars, no noise -> percentile(0.1)")
