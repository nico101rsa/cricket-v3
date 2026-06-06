extends GutTest

func test_defaults_to_no_wicket_no_runs() -> void:
	var o := BallOutcome.new()
	assert_false(o.wicket, "default should be not-out")
	assert_eq(o.runs, 0, "default runs should be 0")

func test_stores_wicket_and_runs() -> void:
	var o := BallOutcome.new(true, 0)
	assert_true(o.wicket)
	assert_eq(o.runs, 0)
	var scored := BallOutcome.new(false, 4)
	assert_false(scored.wicket)
	assert_eq(scored.runs, 4)
