extends GutTest

# Bowling-balance rung (spec 2026-06-11-bowling-balance-design.md).

func test_phase_of_maps_boundaries() -> void:
	assert_eq(IntentPlan.phase_of(1), 0, "over 1 -> powerplay")
	assert_eq(IntentPlan.phase_of(6), 0, "over 6 -> powerplay (boundary)")
	assert_eq(IntentPlan.phase_of(7), 1, "over 7 -> middle (boundary)")
	assert_eq(IntentPlan.phase_of(15), 1, "over 15 -> middle (boundary)")
	assert_eq(IntentPlan.phase_of(16), 2, "over 16 -> death (boundary)")
	assert_eq(IntentPlan.phase_of(20), 2, "over 20 -> death")

func test_for_over_unchanged_by_refactor() -> void:
	var t := IntentPlan.textbook()
	assert_eq(t.for_over(6), BallResolver.Intent.AGGRESSIVE, "textbook over 6 aggressive")
	assert_eq(t.for_over(7), BallResolver.Intent.BALANCED, "textbook over 7 balanced")
	assert_eq(t.for_over(16), BallResolver.Intent.AGGRESSIVE, "textbook over 16 aggressive")

func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng

# bowler_kind = -1 must ignore the matchup tables entirely (BB9).
func test_resolve_ball_kind_default_is_byte_identical() -> void:
	var t := BallTuning.new()
	t.matchup_w_spin = [5.0, 5.0, 5.0]  # poison: would near-guarantee wickets if read
	t.matchup_w_pace = [5.0, 5.0, 5.0]
	for seed_value in range(1, 200):
		var a := BallResolver.resolve_ball(5, 5, 5.0, 5.0, BallResolver.Intent.AGGRESSIVE, t, _rng(seed_value))
		var b := BallResolver.resolve_ball(5, 5, 5.0, 5.0, BallResolver.Intent.AGGRESSIVE, t, _rng(seed_value), 1.0, 1.0, -1)
		assert_eq(a.wicket, b.wicket, "wicket identical (seed %d)" % seed_value)
		assert_eq(a.runs, b.runs, "runs identical (seed %d)" % seed_value)

# Slogging spin out-dies slogging pace at equal stats (default strawman table).
func test_aggressive_vs_spin_out_dies_aggressive_vs_pace() -> void:
	var t := BallTuning.new()
	var pace_w := 0
	var spin_w := 0
	for seed_value in range(1, 4001):
		if BallResolver.resolve_ball(5, 5, 5.0, 5.0, BallResolver.Intent.AGGRESSIVE, t, _rng(seed_value), 1.0, 1.0, BowlingPlan.Kind.PACE).wicket:
			pace_w += 1
		if BallResolver.resolve_ball(5, 5, 5.0, 5.0, BallResolver.Intent.AGGRESSIVE, t, _rng(seed_value), 1.0, 1.0, BowlingPlan.Kind.SPIN).wicket:
			spin_w += 1
	assert_gt(spin_w, pace_w, "AGG-vs-spin (%d) takes more wickets than AGG-vs-pace (%d)" % [spin_w, pace_w])

# The term reads the table by intent: zero entries = no shift.
func test_matchup_zero_entries_do_not_shift() -> void:
	var t := BallTuning.new()
	for seed_value in range(1, 200):
		var a := BallResolver.resolve_ball(5, 5, 5.0, 5.0, BallResolver.Intent.BALANCED, t, _rng(seed_value), 1.0, 1.0, -1)
		var b := BallResolver.resolve_ball(5, 5, 5.0, 5.0, BallResolver.Intent.BALANCED, t, _rng(seed_value), 1.0, 1.0, BowlingPlan.Kind.SPIN)
		assert_eq(a.wicket, b.wicket, "BAL-vs-spin default 0.0 -> identical (seed %d)" % seed_value)
		assert_eq(a.runs, b.runs, "runs identical (seed %d)" % seed_value)
