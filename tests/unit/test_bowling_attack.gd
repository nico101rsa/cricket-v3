extends GutTest

func test_pace_attack_tilted_spin_control_tilted() -> void:
	var ba := BowlingAttack.new(31.25, 31.25)  # default tilt 12.5 -> pace (43.75,18.75), spin (18.75,43.75)
	var pace := ba.profile(BowlingPlan.Kind.PACE)
	var spin := ba.profile(BowlingPlan.Kind.SPIN)
	assert_gt(pace.x, pace.y, "pace: attack > control")
	assert_gt(spin.y, spin.x, "spin: control > attack")
	assert_gt(pace.x, spin.x, "pace attack > spin attack")
	assert_gt(spin.y, pace.y, "spin control > pace control")

func test_profiles_floor_at_one_legacy_point() -> void:
	var ba := BowlingAttack.new(6.25, 6.25)  # tilt 12.5 would push negative; must clamp to SCALE
	var pace := ba.profile(BowlingPlan.Kind.PACE)
	var spin := ba.profile(BowlingPlan.Kind.SPIN)
	assert_gte(pace.x, 6.25, "pace attack >= SCALE")
	assert_gte(pace.y, 6.25, "pace control floored at SCALE")
	assert_gte(spin.x, 6.25, "spin attack floored at SCALE")
	assert_gte(spin.y, 6.25, "spin control >= SCALE")
