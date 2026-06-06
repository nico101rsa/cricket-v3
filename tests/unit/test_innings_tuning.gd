extends GutTest

func test_strawman_defaults() -> void:
	var t := InningsTuning.new()
	assert_eq(t.over_limit, 20, "T20 over limit")
	assert_eq(t.pos_base, 9.0, "position map base")
	assert_eq(t.pos_span, 8.0, "position map span")
	assert_almost_eq(t.tail_floor, 0.45, 0.0001, "tail floor")
	assert_almost_eq(t.tail_slope, 0.07, 0.0001, "tail slope")

func test_max_balls_is_120() -> void:
	var t := InningsTuning.new()
	assert_eq(t.over_limit * 6, 120, "20 overs -> 120 balls")
