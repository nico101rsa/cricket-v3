extends GutTest

# The /100 card-scale ledger (card-rescale spec DR1-DR3): attribute-axis dials
# are the legacy 1-8-era values × Attributes.SCALE; logistic gains are ÷ SCALE.
# If one of these fails, a dial moved without its scale partner.

func test_scale_factor_is_50_over_8():
	assert_eq(Attributes.SCALE, 6.25)

func test_ball_gains_divide_by_scale():
	var t := BallTuning.new()
	assert_almost_eq(t.k_w * Attributes.SCALE, 0.24, 1e-9)
	assert_almost_eq(t.k_r * Attributes.SCALE, 0.34, 1e-9)

func test_logit_difference_matches_legacy():
	# k_new x (scaled diff) == k_old x (legacy diff): the behaviour-preservation theorem
	var t := BallTuning.new()
	assert_almost_eq(t.k_w * (31.25 - 50.0), 0.24 * (5.0 - 8.0), 1e-9)
	assert_almost_eq(t.k_r * (50.0 - 31.25), 0.34 * (8.0 - 5.0), 1e-9)

func test_tour_and_tilt_dials_scale():
	var tour := TourDistribution.new()
	assert_eq(tour.mean, 31.25)
	assert_eq(tour.spread, 9.375)
	assert_eq(tour.noise_step, 6.25)
	assert_eq(BowlingAttack.DEFAULT_TILT, 12.5)

func test_phase_bonus_scales():
	var itun := InningsTuning.new()
	assert_eq(itun.pace_phase_bonus, [9.375, -9.375, 9.375] as Array[float])
	assert_eq(itun.spin_phase_bonus, [-9.375, 9.375, -9.375] as Array[float])

func test_creation_constants():
	# World-scale v2 WS3: fresh-hero budget shrank to 44, range [3, 25].
	assert_eq(Attributes.CREATION_TOTAL, 44.0)
	assert_eq(Attributes.CREATION_MAX, 25.0)
	assert_eq(Attributes.CREATION_MIN, 3.0)
