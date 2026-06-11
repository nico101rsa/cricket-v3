extends GutTest

# Bowling-balance rung (spec 2026-06-11-bowling-balance-design.md).

var _bt := BallTuning.new()
var _it := InningsTuning.new()

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
		var a := BallResolver.resolve_ball(31.25, 31.25, 31.25, 31.25, BallResolver.Intent.AGGRESSIVE, t, _rng(seed_value))
		var b := BallResolver.resolve_ball(31.25, 31.25, 31.25, 31.25, BallResolver.Intent.AGGRESSIVE, t, _rng(seed_value), 1.0, 1.0, -1)
		assert_eq(a.wicket, b.wicket, "wicket identical (seed %d)" % seed_value)
		assert_eq(a.runs, b.runs, "runs identical (seed %d)" % seed_value)

# Slogging spin out-dies slogging pace at equal stats (default strawman table).
func test_aggressive_vs_spin_out_dies_aggressive_vs_pace() -> void:
	var t := BallTuning.new()
	var pace_w := 0
	var spin_w := 0
	for seed_value in range(1, 4001):
		if BallResolver.resolve_ball(31.25, 31.25, 31.25, 31.25, BallResolver.Intent.AGGRESSIVE, t, _rng(seed_value), 1.0, 1.0, BowlingPlan.Kind.PACE).wicket:
			pace_w += 1
		if BallResolver.resolve_ball(31.25, 31.25, 31.25, 31.25, BallResolver.Intent.AGGRESSIVE, t, _rng(seed_value), 1.0, 1.0, BowlingPlan.Kind.SPIN).wicket:
			spin_w += 1
	assert_gt(spin_w, pace_w, "AGG-vs-spin (%d) takes more wickets than AGG-vs-pace (%d)" % [spin_w, pace_w])

# The term reads the table by intent: zero entries = no shift.
func test_matchup_zero_entries_do_not_shift() -> void:
	var t := BallTuning.new()
	for seed_value in range(1, 200):
		var a := BallResolver.resolve_ball(31.25, 31.25, 31.25, 31.25, BallResolver.Intent.BALANCED, t, _rng(seed_value), 1.0, 1.0, -1)
		var b := BallResolver.resolve_ball(31.25, 31.25, 31.25, 31.25, BallResolver.Intent.BALANCED, t, _rng(seed_value), 1.0, 1.0, BowlingPlan.Kind.SPIN)
		assert_eq(a.wicket, b.wicket, "BAL-vs-spin default 0.0 -> identical (seed %d)" % seed_value)
		assert_eq(a.runs, b.runs, "runs identical (seed %d)" % seed_value)

# Helper-level: the phase bonus lands on both stats, 0.5 safety floor (DR8).
func test_phased_profile_applies_kind_phase_bonus() -> void:
	var atk := BowlingAttack.new(31.25, 31.25)  # pace (43.75,18.75) / spin (18.75,43.75)
	var it := InningsTuning.new()
	it.pace_phase_bonus = [4.375, -4.375, 4.375]
	it.spin_phase_bonus = [-4.375, 4.375, -4.375]
	var pp_pace := InningsResolver.phased_profile(atk, BowlingPlan.Kind.PACE, 3, it)
	assert_almost_eq(pp_pace.x, 48.125, 0.001, "pace PP attack 43.75 + 4.375")
	assert_almost_eq(pp_pace.y, 23.125, 0.001, "pace PP control 18.75 + 4.375")
	var mid_pace := InningsResolver.phased_profile(atk, BowlingPlan.Kind.PACE, 10, it)
	assert_almost_eq(mid_pace.x, 39.375, 0.001, "pace middle attack 43.75 - 4.375")
	var mid_spin := InningsResolver.phased_profile(atk, BowlingPlan.Kind.SPIN, 10, it)
	assert_almost_eq(mid_spin.y, 48.125, 0.001, "spin middle control 43.75 + 4.375")
	it.spin_phase_bonus = [-56.25, 0.0, 0.0]
	var floored := InningsResolver.phased_profile(atk, BowlingPlan.Kind.SPIN, 1, it)
	assert_almost_eq(floored.x, 0.5, 0.001, "0.5 safety floor only (card-rescale DR8)")

# BB4 (reversed): the hero bowls WITHIN the rotation — their overs inherit the
# plan kind's phase bonus, else bowling-capable builds pay a hidden tax.
func test_hero_overs_inherit_phase_bonus() -> void:
	var poisoned := InningsTuning.new()
	poisoned.spin_phase_bonus = [9.0, 9.0, 9.0]  # only reachable via the hero's overs below
	poisoned.pace_phase_bonus = [9.0, 9.0, 9.0]
	var atk := BowlingAttack.new(31.25, 31.25)
	var differs := false
	for seed_value in range(1, 20):
		# Hero bowls 4 overs inside an all-spin rotation; if their overs ignored
		# the phase dials, poisoning them could still differ via team overs — so
		# compare against a run where ONLY team overs see the poison (hero stats
		# huge so hero-over outcomes dominate the divergence).
		var a := InningsResolver.simulate_innings(null, 31.25, 31.25, 31.25, _bt, _it, _rng(seed_value), 0, null, atk, BowlingPlan.spin_only(), 50.0, 50.0, 4)
		var b := InningsResolver.simulate_innings(null, 31.25, 31.25, 31.25, _bt, poisoned, _rng(seed_value), 0, null, atk, BowlingPlan.spin_only(), 50.0, 50.0, 4)
		if a.player_bowl_runs != b.player_bowl_runs or a.player_bowl_wickets != b.player_bowl_wickets:
			differs = true
	assert_true(differs, "the phase dials must reach the hero's own overs (BB4 reversed)")

# Scalar path (no bowling plan) must not read the new dials at all (BB9).
func test_scalar_innings_ignores_phase_dials() -> void:
	var poisoned := InningsTuning.new()
	poisoned.pace_phase_bonus = [9.0, 9.0, 9.0]
	poisoned.spin_phase_bonus = [-9.0, -9.0, -9.0]
	for seed_value in range(1, 30):
		var a := InningsResolver.simulate_innings(null, 31.25, 31.25, 31.25, _bt, _it, _rng(seed_value))
		var b := InningsResolver.simulate_innings(null, 31.25, 31.25, 31.25, _bt, poisoned, _rng(seed_value))
		assert_eq(a.total, b.total, "scalar total identical (seed %d)" % seed_value)
		assert_eq(a.wickets, b.wickets, "scalar wickets identical (seed %d)" % seed_value)

# Directional (the real-benchmark shape, defaults on): pace out-wickets spin in
# a pure-Powerplay innings (over_limit = 6).
func test_pace_takes_more_powerplay_wickets_than_spin() -> void:
	var it := InningsTuning.new()
	it.over_limit = 6
	var atk := BowlingAttack.new(31.25, 31.25)
	var pace_w := 0
	var spin_w := 0
	for seed_value in range(1, 61):
		pace_w += InningsResolver.simulate_innings(null, 31.25, 31.25, 31.25, _bt, it, _rng(seed_value), 0, null, atk, BowlingPlan.pace_only()).wickets
		spin_w += InningsResolver.simulate_innings(null, 31.25, 31.25, 31.25, _bt, it, _rng(seed_value), 0, null, atk, BowlingPlan.spin_only()).wickets
	assert_gt(pace_w, spin_w, "PP: pace wickets (%d) > spin wickets (%d)" % [pace_w, spin_w])

# Directional: a spin middle (textbook P/S/P) concedes less than all-pace.
func test_spin_middle_concedes_less_than_pace_middle() -> void:
	var atk := BowlingAttack.new(31.25, 31.25)
	var psp := 0
	var ppp := 0
	for seed_value in range(1, 61):
		psp += InningsResolver.simulate_innings(null, 31.25, 31.25, 31.25, _bt, _it, _rng(seed_value), 0, null, atk, BowlingPlan.textbook()).total
		ppp += InningsResolver.simulate_innings(null, 31.25, 31.25, 31.25, _bt, _it, _rng(seed_value), 0, null, atk, BowlingPlan.pace_only()).total
	assert_lt(psp, ppp, "P/S/P conceded (%d) < P/P/P conceded (%d)" % [psp, ppp])

# BB5 lever 1 — archetype sharpening conserves the 125-point build equality.
func test_archetypes_remain_125_point_builds() -> void:
	for a in [Team.archetype_batter(), Team.archetype_bowler(), Team.archetype_allrounder()]:
		assert_eq(a.power + a.composure + a.attack + a.control, 125.0, "every archetype is exactly 125 points")

# Tail-only steepening (BB5 final form): BOWLER bats 6.25/6.25, BATTER 50/50 —
# the fully-sharpened 9/9 top order blew the build-equality spread (spec §10).
func test_steep_tail_final_form() -> void:
	var bat := Team.archetype_batter()
	var bowl := Team.archetype_bowler()
	assert_eq(bat.power, 50.0, "batter power stays 50 (no top sharpening)")
	assert_eq(bowl.power, 6.25, "bowler bats 6.25 (steep tail)")
	assert_eq(bowl.attack, 56.25, "bowler bowls 56.25 (125-pt budget kept)")

# BB11 — per-phase runs on InningsResult (scoring-environment probe + future
# score worm). The three buckets must always sum to the innings total.
func test_phase_runs_sum_to_total() -> void:
	for seed_value in range(1, 30):
		var r := InningsResolver.simulate_innings(null, 31.25, 31.25, 31.25, _bt, _it, _rng(seed_value))
		assert_eq(r.phase_runs[0] + r.phase_runs[1] + r.phase_runs[2], r.total,
			"phase runs sum to total (seed %d)" % seed_value)

func test_phase_runs_default_zeros() -> void:
	var r := InningsResult.new()
	assert_eq(r.phase_runs, [0, 0, 0], "bare InningsResult has zeroed phase buckets")
