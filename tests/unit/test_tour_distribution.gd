extends GutTest

func _tour(mean: int, spread: int, noise: int = 1) -> TourDistribution:
	var t := TourDistribution.new()
	t.mean = mean
	t.spread = spread
	t.noise = noise
	return t

func test_endpoints_and_midpoint() -> void:
	var t := _tour(5, 3)
	assert_eq(t.percentile(0.0), 2, "frac 0 -> mean - spread")
	assert_eq(t.percentile(1.0), 8, "frac 1 -> mean + spread")
	assert_eq(t.percentile(0.5), 5, "frac 0.5 -> mean")

func test_monotonic_non_decreasing() -> void:
	var t := _tour(5, 3)
	var prev := t.percentile(0.0)
	for i in range(1, 11):
		var cur := t.percentile(i / 10.0)
		assert_true(cur >= prev, "percentile non-decreasing at frac %f" % (i / 10.0))
		prev = cur

func test_out_of_range_frac_clamps() -> void:
	var t := _tour(5, 3)
	assert_eq(t.percentile(-1.0), t.percentile(0.0), "frac below 0 clamps to 0")
	assert_eq(t.percentile(2.0), t.percentile(1.0), "frac above 1 clamps to 1")
