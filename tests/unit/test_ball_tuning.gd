extends GutTest

func test_run_values_are_the_outcome_alphabet() -> void:
	assert_eq(BallTuning.RUN_VALUES, [0, 1, 2, 3, 4, 6])

func test_defaults_are_present_and_aligned() -> void:
	var t := BallTuning.new()
	# Intent arrays are [defensive, balanced, aggressive].
	assert_eq(t.intent_w.size(), 3, "intent_w must have 3 bands")
	assert_eq(t.intent_r.size(), 3, "intent_r must have 3 bands")
	assert_eq(t.intent_w[1], 0.0, "balanced wicket shift is 0")
	assert_eq(t.intent_r[1], 0.0, "balanced runs shift is 0")
	# Distributions align to RUN_VALUES.
	assert_eq(t.def_dist.size(), BallTuning.RUN_VALUES.size())
	assert_eq(t.agg_dist.size(), BallTuning.RUN_VALUES.size())

func test_anchor_distributions_each_sum_to_one() -> void:
	var t := BallTuning.new()
	var dsum := 0.0
	for p in t.def_dist:
		dsum += p
	assert_almost_eq(dsum, 1.0, 0.0001, "def_dist should sum to 1")
	var asum := 0.0
	for p in t.agg_dist:
		asum += p
	assert_almost_eq(asum, 1.0, 0.0001, "agg_dist should sum to 1")

func test_aggressive_band_is_riskier_and_higher_scoring() -> void:
	var t := BallTuning.new()
	assert_gt(t.intent_w[2], t.intent_w[0], "aggressive raises wicket odds vs defensive")
	assert_gt(t.intent_r[2], t.intent_r[0], "aggressive raises scoring vs defensive")
