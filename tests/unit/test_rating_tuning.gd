extends GutTest

func test_defaults() -> void:
	var rt := RatingTuning.new()
	assert_almost_eq(rt.sr_par, 120.0, 0.0001, "par strike rate default")
	assert_almost_eq(rt.rr_par, 7.5, 0.0001, "par economy default")
	assert_almost_eq(rt.wicket_value, 10.0, 0.0001, "wicket worth (strawman) default")
