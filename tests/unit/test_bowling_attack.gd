extends GutTest

func test_pace_attack_tilted_spin_control_tilted() -> void:
	var ba := BowlingAttack.new(5, 5)  # default tilt 2 -> pace (7,3), spin (3,7)
	var pace := ba.profile(BowlingPlan.Kind.PACE)
	var spin := ba.profile(BowlingPlan.Kind.SPIN)
	assert_gt(pace.x, pace.y, "pace: attack > control")
	assert_gt(spin.y, spin.x, "spin: control > attack")
	assert_gt(pace.x, spin.x, "pace attack > spin attack")
	assert_gt(spin.y, pace.y, "spin control > pace control")

func test_profiles_floor_at_one() -> void:
	var ba := BowlingAttack.new(1, 1)  # tilt 2 would push to -1; must clamp to 1
	var pace := ba.profile(BowlingPlan.Kind.PACE)
	var spin := ba.profile(BowlingPlan.Kind.SPIN)
	assert_gte(pace.x, 1, "pace attack >= 1")
	assert_gte(pace.y, 1, "pace control floored at 1")
	assert_gte(spin.x, 1, "spin attack floored at 1")
	assert_gte(spin.y, 1, "spin control >= 1")
