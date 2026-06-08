extends GutTest

func test_defaults() -> void:
	var rt := RatingTuning.new()
	assert_almost_eq(rt.sr_par, 111.6, 0.0001, "par strike rate default (derived from generic build)")
	assert_almost_eq(rt.rr_par, 6.4, 0.0001, "par economy default (derived from generic build)")
	assert_almost_eq(rt.wicket_value, 10.0, 0.0001, "wicket worth (strawman) default")
