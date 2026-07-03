extends GutTest

# DF5 -- FormState threads the sim; null = byte-identical (the rest of the suite,
# unmodified, is that proof). These tests pin direction + determinism, not magnitude
# (the DF10 sweep owns magnitudes).

func _attrs() -> Attributes:
	var a := Attributes.new()
	a.power = 40; a.composure = 35; a.attack = 25; a.control = 25
	return a

func _run_match(seed_v: int, fs: FormState) -> MatchResult:
	var rng := RandomNumberGenerator.new(); rng.seed = seed_v
	var t := Team.new(); t.stars = 3.0
	var o := Team.new(); o.stars = 3.0
	return MatchResolver.simulate_match_teams(
		_attrs(), t, o, TourDistribution.new(), BallTuning.new(), InningsTuning.new(), rng,
		null, null, [], null, null, null, null, null, null, null, null,
		-1, null, null, null, fs)

func test_null_form_state_reports_neutral_end() -> void:
	var m := _run_match(41, null)
	assert_almost_eq(m.form_end, 0.0, 0.0001, "no form threading -> neutral form_end")

func test_form_end_is_deterministic_and_moves() -> void:
	var a := _run_match(41, FormState.make(0.0))
	var b := _run_match(41, FormState.make(0.0))
	assert_almost_eq(a.form_end, b.form_end, 0.0001, "same seed + start -> same form_end")
	assert_ne(a.form_end, 0.0, "a full T20 moves form off neutral")

func _player_runs(m: MatchResult) -> int:
	var inns: InningsResult = m.innings1 if m.player_bats_first else m.innings2
	return inns.player_line().get("runs", 0)

func test_start_points_shift_the_match() -> void:
	# Deterministic seeds, aggregated: any single seed can be a duck in both arms
	# (seed 97 is), but over 20 seeds hot (x1.15) must outscore cold (x0.8).
	var hot_total := 0
	var cold_total := 0
	for seed_v in range(90, 110):
		hot_total += _player_runs(_run_match(seed_v, FormState.make(3.0)))
		cold_total += _player_runs(_run_match(seed_v, FormState.make(-3.0)))
	assert_gt(hot_total, cold_total, "x1.15 vs x0.8 shows up in the player's aggregate runs")

func test_base_mult_alone_shifts_the_match() -> void:
	var plain_total := 0
	var buffed_total := 0
	for seed_v in range(90, 110):
		plain_total += _player_runs(_run_match(seed_v, FormState.make(0.0, 1.0)))
		buffed_total += _player_runs(_run_match(seed_v, FormState.make(0.0, 1.10)))
	assert_gt(buffed_total, plain_total, "the Affinity base mult shows up in aggregate")
