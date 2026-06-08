extends GutTest

func test_presses_on() -> void:
	var p := BoostPlan.at([1, 16])
	assert_true(p.presses_on(1))
	assert_true(p.presses_on(16))
	assert_false(p.presses_on(7))

func test_at_factory_defaults() -> void:
	var p := BoostPlan.at([5])
	assert_eq(p.press_overs, [5])
	assert_almost_eq(p.base_mult, 1.15, 0.0001)
	assert_eq(p.base_n, 6)

func test_empty_plan_presses_nowhere() -> void:
	var p := BoostPlan.new()
	assert_false(p.presses_on(1))
