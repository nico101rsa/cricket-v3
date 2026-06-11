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

func _make_rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng

func _wicket_rate(power: float, comp: float, attack: float, control: float, intent: int, seed_value: int, n: int) -> float:
	var rng := _make_rng(seed_value)
	var wickets := 0
	for i in n:
		if BallResolver.resolve_ball(power, comp, attack, control, intent, tuning, rng).wicket:
			wickets += 1
	return float(wickets) / n

func _mean_runs_when_surviving(power: float, comp: float, attack: float, control: float, intent: int, seed_value: int, n: int) -> float:
	var rng := _make_rng(seed_value)
	var total := 0
	var balls := 0
	for i in n:
		var o := BallResolver.resolve_ball(power, comp, attack, control, intent, tuning, rng)
		if not o.wicket:
			total += o.runs
			balls += 1
	return float(total) / balls

func test_same_seed_gives_identical_sequence() -> void:
	var rng_a := _make_rng(12345)
	var rng_b := _make_rng(12345)
	for i in 200:
		var a := BallResolver.resolve_ball(31.25, 31.25, 31.25, 31.25, BallResolver.Intent.BALANCED, tuning, rng_a)
		var b := BallResolver.resolve_ball(31.25, 31.25, 31.25, 31.25, BallResolver.Intent.BALANCED, tuning, rng_b)
		assert_eq(a.wicket, b.wicket, "wicket should match at ball %d" % i)
		assert_eq(a.runs, b.runs, "runs should match at ball %d" % i)

func test_runs_in_alphabet_and_wicket_scores_zero() -> void:
	var rng := _make_rng(999)
	for i in 500:
		var o := BallResolver.resolve_ball(37.5, 37.5, 37.5, 37.5, BallResolver.Intent.BALANCED, tuning, rng)
		assert_true(o.runs in [0, 1, 2, 3, 4, 6], "runs %d not in alphabet" % o.runs)
		if o.wicket:
			assert_eq(o.runs, 0, "a wicket must score 0")

func test_even_contest_wicket_rate_near_baseline() -> void:
	var rate := _wicket_rate(31.25, 31.25, 31.25, 31.25, BallResolver.Intent.BALANCED, 2024, 20000)
	assert_almost_eq(rate, 0.035, 0.008, "even-contest wicket rate should be ~3.5%")

func test_higher_attack_raises_wicket_rate() -> void:
	var low := _wicket_rate(31.25, 31.25, 25.0, 31.25, BallResolver.Intent.BALANCED, 77, 20000)
	var high := _wicket_rate(31.25, 31.25, 56.25, 31.25, BallResolver.Intent.BALANCED, 77, 20000)
	assert_gt(high, low, "more bowler Attack should raise the wicket rate")

func test_higher_power_raises_mean_runs() -> void:
	var low := _mean_runs_when_surviving(25.0, 31.25, 31.25, 31.25, BallResolver.Intent.BALANCED, 88, 20000)
	var high := _mean_runs_when_surviving(56.25, 31.25, 31.25, 31.25, BallResolver.Intent.BALANCED, 88, 20000)
	assert_gt(high, low, "more batter Power should raise mean runs")

func test_aggressive_intent_raises_both_wickets_and_runs() -> void:
	var def_w := _wicket_rate(31.25, 31.25, 31.25, 31.25, BallResolver.Intent.DEFENSIVE, 55, 20000)
	var agg_w := _wicket_rate(31.25, 31.25, 31.25, 31.25, BallResolver.Intent.AGGRESSIVE, 55, 20000)
	assert_gt(agg_w, def_w, "aggressive should raise the wicket rate")
	var def_r := _mean_runs_when_surviving(31.25, 31.25, 31.25, 31.25, BallResolver.Intent.DEFENSIVE, 66, 20000)
	var agg_r := _mean_runs_when_surviving(31.25, 31.25, 31.25, 31.25, BallResolver.Intent.AGGRESSIVE, 66, 20000)
	assert_gt(agg_r, def_r, "aggressive should raise mean runs")

func test_extreme_mismatch_stays_valid() -> void:
	var rng := _make_rng(3)
	for i in 200:
		var o := BallResolver.resolve_ball(618.75, 618.75, 6.25, 6.25, BallResolver.Intent.AGGRESSIVE, tuning, rng)
		assert_true(o.runs in [0, 1, 2, 3, 4, 6])
	var rng2 := _make_rng(4)
	for i in 200:
		var o := BallResolver.resolve_ball(6.25, 6.25, 618.75, 618.75, BallResolver.Intent.DEFENSIVE, tuning, rng2)
		assert_true(o.runs in [0, 1, 2, 3, 4, 6])
