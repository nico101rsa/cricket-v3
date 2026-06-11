extends GutTest

# E3 (spec §3.3): the opponent-brain factory. Tier literals are the measured
# self-play equilibria; NAIVE draws a uniform static policy.


func test_textbook_plans_are_the_textbook_factories() -> void:
	var plans := OpponentBrain.draw_plans(TourSpec.Tier.TEXTBOOK, 1.0, null)
	var ip: IntentPlan = plans[0]
	var bp: BowlingPlan = plans[1]
	assert_eq(ip.for_over(3), BallResolver.Intent.AGGRESSIVE)
	assert_eq(ip.for_over(10), BallResolver.Intent.BALANCED)
	assert_eq(bp.for_over(10), BowlingPlan.Kind.SPIN)
	assert_eq(ip.chase_up_rr, -1.0, "static tiers carry no state rules")


func test_static_eq_literal() -> void:
	var plans := OpponentBrain.draw_plans(TourSpec.Tier.STATIC_EQ, 1.0, null)
	var ip: IntentPlan = plans[0]
	var bp: BowlingPlan = plans[1]
	# B/A/B·P/S/P (E1/bowling-balance equilibrium).
	assert_eq(ip.for_over(3), BallResolver.Intent.BALANCED)
	assert_eq(ip.for_over(10), BallResolver.Intent.AGGRESSIVE)
	assert_eq(ip.for_over(18), BallResolver.Intent.BALANCED)
	assert_eq(bp.for_over(3), BowlingPlan.Kind.PACE)
	assert_eq(bp.for_over(10), BowlingPlan.Kind.SPIN)
	assert_eq(ip.collapse_wkts, -1)


func test_adaptive_eq_literal_carries_rules() -> void:
	var plans := OpponentBrain.draw_plans(TourSpec.Tier.ADAPTIVE, 1.0, null)
	var ip: IntentPlan = plans[0]
	assert_eq(ip.for_over(3), BallResolver.Intent.BALANCED)
	assert_eq(ip.for_over(10), BallResolver.Intent.AGGRESSIVE)
	assert_eq(ip.for_over(18), BallResolver.Intent.BALANCED)
	assert_true(ip.chase_up_rr > 0.0, "adaptive brain reads the chase")
	assert_true(ip.collapse_wkts > 0, "adaptive brain protects a collapse")


func test_naive_is_seed_deterministic_and_legal() -> void:
	var a := RandomNumberGenerator.new()
	a.seed = 7
	var b := RandomNumberGenerator.new()
	b.seed = 7
	var pa := OpponentBrain.draw_plans(TourSpec.Tier.NAIVE, 1.0, a)
	var pb := OpponentBrain.draw_plans(TourSpec.Tier.NAIVE, 1.0, b)
	for over in [3, 10, 18]:
		assert_eq(pa[0].for_over(over), pb[0].for_over(over))
		assert_eq(pa[1].for_over(over), pb[1].for_over(over))
		assert_true(pa[0].for_over(over) >= BallResolver.Intent.DEFENSIVE)
		assert_true(pa[0].for_over(over) <= BallResolver.Intent.AGGRESSIVE)


func test_full_blend_consumes_no_rng_for_fixed_tiers() -> void:
	var a := RandomNumberGenerator.new()
	a.seed = 11
	var b := RandomNumberGenerator.new()
	b.seed = 11
	OpponentBrain.draw_plans(TourSpec.Tier.STATIC_EQ, 1.0, a)
	assert_eq(a.randf(), b.randf(), "blend 1.0 on a fixed tier must not touch the rng")


func test_blend_downgrades_about_half_the_time() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 13
	var downgraded := 0
	for i in range(200):
		var plans := OpponentBrain.draw_plans(TourSpec.Tier.STATIC_EQ, 0.5, rng)
		var ip: IntentPlan = plans[0]
		# STATIC_EQ mid = AGGRESSIVE; the tier below (TEXTBOOK) mid = BALANCED.
		if ip.for_over(10) == BallResolver.Intent.BALANCED:
			downgraded += 1
	assert_between(downgraded, 60, 140)
