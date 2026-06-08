extends GutTest

func test_summary_stats() -> void:
	var d := Distribution.new([2, 4, 4, 4, 5, 5, 7, 9])
	assert_eq(d.count(), 8, "count")
	assert_almost_eq(d.mean(), 5.0, 0.0001, "mean")
	assert_almost_eq(d.sd(), 2.0, 0.0001, "population sd")
	assert_almost_eq(d.minimum(), 2.0, 0.0001, "min")
	assert_almost_eq(d.maximum(), 9.0, 0.0001, "max")

func test_empty_is_safe() -> void:
	var d := Distribution.new([])
	assert_eq(d.count(), 0, "empty count")
	assert_almost_eq(d.mean(), 0.0, 0.0001, "empty mean 0")
	assert_almost_eq(d.minimum(), 0.0, 0.0001, "empty min 0")
	assert_almost_eq(d.maximum(), 0.0, 0.0001, "empty max 0")

func test_histogram_bins_and_clamps() -> void:
	# bins over [0,10): values 1,3,5,7,9 land one per bin (width 2).
	var d := Distribution.new([1, 3, 5, 7, 9])
	var h := d.histogram(5, 0.0, 10.0)
	assert_eq(h.size(), 5, "5 bins")
	assert_eq(h, [1, 1, 1, 1, 1], "one per bin")
	# Out-of-range clamps into the end bins; counts still sum to count().
	var d2 := Distribution.new([-4, 1, 99])
	var h2 := d2.histogram(5, 0.0, 10.0)
	assert_eq(h2[0], 2, "negative + low value in bottom bin")
	assert_eq(h2[4], 1, "huge value in top bin")
	var total := 0
	for c in h2:
		total += c
	assert_eq(total, d2.count(), "histogram counts sum to count")
