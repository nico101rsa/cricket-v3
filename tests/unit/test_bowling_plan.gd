extends GutTest

func test_for_over_maps_phases() -> void:
	var plan := BowlingPlan.new()
	plan.powerplay = BowlingPlan.Kind.PACE
	plan.middle = BowlingPlan.Kind.SPIN
	plan.death = BowlingPlan.Kind.PACE
	assert_eq(plan.for_over(1), BowlingPlan.Kind.PACE, "over 1 -> powerplay")
	assert_eq(plan.for_over(6), BowlingPlan.Kind.PACE, "over 6 -> powerplay (boundary)")
	assert_eq(plan.for_over(7), BowlingPlan.Kind.SPIN, "over 7 -> middle (boundary)")
	assert_eq(plan.for_over(15), BowlingPlan.Kind.SPIN, "over 15 -> middle (boundary)")
	assert_eq(plan.for_over(16), BowlingPlan.Kind.PACE, "over 16 -> death (boundary)")
	assert_eq(plan.for_over(20), BowlingPlan.Kind.PACE, "over 20 -> death (boundary)")

func test_factories_and_default() -> void:
	var t := BowlingPlan.textbook()
	assert_eq(t.powerplay, BowlingPlan.Kind.PACE, "textbook powerplay pace")
	assert_eq(t.middle, BowlingPlan.Kind.SPIN, "textbook middle spin")
	assert_eq(t.death, BowlingPlan.Kind.PACE, "textbook death pace")
	var p := BowlingPlan.pace_only()
	assert_eq(p.powerplay, BowlingPlan.Kind.PACE, "pace_only pp")
	assert_eq(p.middle, BowlingPlan.Kind.PACE, "pace_only mid")
	assert_eq(p.death, BowlingPlan.Kind.PACE, "pace_only death")
	var s := BowlingPlan.spin_only()
	assert_eq(s.powerplay, BowlingPlan.Kind.SPIN, "spin_only pp")
	assert_eq(s.middle, BowlingPlan.Kind.SPIN, "spin_only mid")
	assert_eq(s.death, BowlingPlan.Kind.SPIN, "spin_only death")
	# A bare new() must equal the textbook shape.
	var bare := BowlingPlan.new()
	assert_eq(bare.powerplay, t.powerplay, "new() == textbook powerplay")
	assert_eq(bare.middle, t.middle, "new() == textbook middle")
	assert_eq(bare.death, t.death, "new() == textbook death")
