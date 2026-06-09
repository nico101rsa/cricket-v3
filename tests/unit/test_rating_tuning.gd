extends GutTest

func test_defaults() -> void:
	var rt := RatingTuning.new()
	# Re-derived/solved in Slice 3 calibration against the conserved-roster world (spec §9.5.3).
	assert_almost_eq(rt.sr_par, 107.4, 0.0001, "par strike rate default (derived from generic build)")
	assert_almost_eq(rt.rr_par, 9.0, 0.0001, "par economy default (derived from generic build)")
	assert_almost_eq(rt.wicket_value, 2.0, 0.0001, "wicket worth (solved batter=bowler) default")
