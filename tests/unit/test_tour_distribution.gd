extends GutTest

func _tour(mean: float, spread: float, noise_frac: float = 1.0) -> TourDistribution:
	var t := TourDistribution.new()
	t.mean = mean
	t.spread = spread
	t.noise_frac = noise_frac
	return t

func test_endpoints_and_midpoint() -> void:
	var t := _tour(31.25, 18.75)
	assert_eq(t.percentile(0.0), 12.5, "frac 0 -> mean - spread")
	assert_eq(t.percentile(1.0), 50.0, "frac 1 -> mean + spread")
	assert_eq(t.percentile(0.5), 31.25, "frac 0.5 -> mean")

func test_monotonic_non_decreasing() -> void:
	var t := _tour(31.25, 18.75)
	var prev := t.percentile(0.0)
	for i in range(1, 11):
		var cur := t.percentile(i / 10.0)
		assert_true(cur >= prev, "percentile non-decreasing at frac %f" % (i / 10.0))
		prev = cur

func test_out_of_range_frac_clamps() -> void:
	var t := _tour(31.25, 18.75)
	assert_eq(t.percentile(-1.0), t.percentile(0.0), "frac below 0 clamps to 0")
	assert_eq(t.percentile(2.0), t.percentile(1.0), "frac above 1 clamps to 1")

func test_percentile_is_continuous() -> void:
	# Card-rescale Stage B (DR5): the legacy integer-grid snap is gone.
	var t := TourDistribution.new()
	assert_almost_eq(t.percentile(0.5), 31.25, 1e-9, "centre = mean")
	assert_almost_eq(t.percentile(0.6), 33.125, 1e-9, "no grid snap between points")
