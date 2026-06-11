extends GutTest

func test_default_mults_identical_to_baseline() -> void:
	var tuning := BallTuning.new()
	for i in range(50):
		var r1 := RandomNumberGenerator.new(); r1.seed = i
		var base := BallResolver.resolve_ball(31.25, 31.25, 31.25, 31.25, BallResolver.Intent.BALANCED, tuning, r1)
		var r2 := RandomNumberGenerator.new(); r2.seed = i
		var same := BallResolver.resolve_ball(31.25, 31.25, 31.25, 31.25, BallResolver.Intent.BALANCED, tuning, r2, 1.0, 1.0)
		assert_eq(base.wicket, same.wicket)
		assert_eq(base.runs, same.runs)

func test_lower_wicket_mult_reduces_wickets() -> void:
	var tuning := BallTuning.new()
	var base_outs := 0
	var buff_outs := 0
	for i in range(2000):
		var r1 := RandomNumberGenerator.new(); r1.seed = i
		if BallResolver.resolve_ball(31.25, 31.25, 31.25, 31.25, BallResolver.Intent.BALANCED, tuning, r1).wicket:
			base_outs += 1
		var r2 := RandomNumberGenerator.new(); r2.seed = i
		if BallResolver.resolve_ball(31.25, 31.25, 31.25, 31.25, BallResolver.Intent.BALANCED, tuning, r2, 0.5, 1.0).wicket:
			buff_outs += 1
	assert_lt(buff_outs, base_outs, "halving wicket_mult should reduce wickets")

func test_higher_runs_mult_raises_runs() -> void:
	var tuning := BallTuning.new()
	var base_runs := 0
	var buff_runs := 0
	for i in range(2000):
		var r1 := RandomNumberGenerator.new(); r1.seed = i
		base_runs += BallResolver.resolve_ball(50.0, 50.0, 12.5, 12.5, BallResolver.Intent.BALANCED, tuning, r1).runs
		var r2 := RandomNumberGenerator.new(); r2.seed = i
		buff_runs += BallResolver.resolve_ball(50.0, 50.0, 12.5, 12.5, BallResolver.Intent.BALANCED, tuning, r2, 1.0, 1.5).runs
	assert_gt(buff_runs, base_runs, "higher runs_mult should raise total runs")
