extends GutTest

var tuning: BallTuning

func before_each() -> void:
	tuning = BallTuning.new()

func test_blended_distribution_sums_to_one() -> void:
	for s in [0.0, 0.25, 0.5, 0.75, 1.0]:
		var probs := BallResolver.blended_distribution(s, tuning)
		var total := 0.0
		for p in probs:
			total += p
		assert_almost_eq(total, 1.0, 0.0001, "distribution at s=%f should sum to 1" % s)

func test_blend_endpoints_match_anchor_shapes() -> void:
	# At s=0 the distribution is the defensive anchor, at s=1 the aggressive.
	var defensive := BallResolver.blended_distribution(0.0, tuning)
	var aggressive := BallResolver.blended_distribution(1.0, tuning)
	# index 4 in RUN_VALUES is the value 4 (a boundary): aggressive favours it far more.
	assert_gt(aggressive[4], defensive[4], "aggressive blend has more 4s than defensive")
	# index 0 is a dot: defensive has more dots.
	assert_gt(defensive[0], aggressive[0], "defensive blend has more dots than aggressive")

func test_higher_s_raises_expected_runs() -> void:
	var low := _expected_runs(BallResolver.blended_distribution(0.2, tuning))
	var high := _expected_runs(BallResolver.blended_distribution(0.8, tuning))
	assert_gt(high, low, "higher scoring strength should raise expected runs")

func _expected_runs(probs: Array[float]) -> float:
	var e := 0.0
	for i in BallTuning.RUN_VALUES.size():
		e += BallTuning.RUN_VALUES[i] * probs[i]
	return e
