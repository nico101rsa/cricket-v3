extends GutTest

func test_presses_on() -> void:
	var p := BoostPlan.at([1, 16])
	assert_true(p.presses_on(1))
	assert_true(p.presses_on(16))
	assert_false(p.presses_on(7))

func test_at_factory_defaults() -> void:
	var p := BoostPlan.at([5])
	assert_eq(p.press_overs, [5])
	assert_almost_eq(p.base_mult, 1.22, 0.0001)   # T9 gate re-tune (spec §9)
	assert_eq(p.base_n, 6)

func test_empty_plan_presses_nowhere() -> void:
	var p := BoostPlan.new()
	assert_false(p.presses_on(1))

# DW13 (spec 2026-07-04): innings-aware pairs. A live session's press in innings 1
# must NOT fire in innings 2 (the old flat list double-fired every press).
func test_for_innings_filters_pairs() -> void:
	var p := BoostPlan.new()
	p.press_pairs = [[1, 5], [2, 16]]
	assert_eq(p.for_innings(1).press_overs, [5], "innings 1 keeps only its press")
	assert_eq(p.for_innings(2).press_overs, [16], "innings 2 keeps only its press")
	assert_almost_eq(p.for_innings(1).base_mult, p.base_mult, 0.0001, "params carried")

func test_for_innings_flat_plan_unchanged() -> void:
	# Headless flat plans (BoostPlan.at) intentionally fire in BOTH innings —
	# that's how boost jokers were priced. Empty pairs -> the plan itself.
	var p := BoostPlan.at([1, 10, 16])
	assert_eq(p.for_innings(1), p, "flat plan passes through untouched")
	assert_eq(p.for_innings(2), p, "flat plan passes through untouched")
