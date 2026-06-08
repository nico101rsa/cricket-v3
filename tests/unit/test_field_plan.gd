extends GutTest

# FieldPlan: per-phase captain field setting, mirror of IntentPlan/BowlingPlan.

func test_for_over_phase_mapping() -> void:
	var p := FieldPlan.new()
	p.powerplay = FieldPlan.Mode.CATCHING
	p.middle = FieldPlan.Mode.DEFENSIVE
	p.death = FieldPlan.Mode.NEUTRAL
	assert_eq(p.for_over(1), FieldPlan.Mode.CATCHING)
	assert_eq(p.for_over(6), FieldPlan.Mode.CATCHING, "over 6 still powerplay")
	assert_eq(p.for_over(7), FieldPlan.Mode.DEFENSIVE, "over 7 is middle")
	assert_eq(p.for_over(15), FieldPlan.Mode.DEFENSIVE, "over 15 still middle")
	assert_eq(p.for_over(16), FieldPlan.Mode.NEUTRAL, "over 16 is death")

func test_neutral_factory() -> void:
	var p := FieldPlan.neutral()
	assert_eq(p.powerplay, FieldPlan.Mode.NEUTRAL)
	assert_eq(p.middle, FieldPlan.Mode.NEUTRAL)
	assert_eq(p.death, FieldPlan.Mode.NEUTRAL)

func test_catching_factory() -> void:
	var p := FieldPlan.catching()
	assert_eq(p.for_over(1), FieldPlan.Mode.CATCHING)
	assert_eq(p.for_over(10), FieldPlan.Mode.CATCHING)
	assert_eq(p.for_over(20), FieldPlan.Mode.CATCHING)

func test_defensive_factory() -> void:
	var p := FieldPlan.defensive()
	assert_eq(p.for_over(1), FieldPlan.Mode.DEFENSIVE)
	assert_eq(p.for_over(10), FieldPlan.Mode.DEFENSIVE)
	assert_eq(p.for_over(20), FieldPlan.Mode.DEFENSIVE)

func test_default_is_neutral() -> void:
	var p := FieldPlan.new()
	assert_eq(p.for_over(1), FieldPlan.Mode.NEUTRAL)
	assert_eq(FieldPlan.Mode.NEUTRAL, 0, "NEUTRAL must be 0 (the matches() default)")
