extends GutTest

# DRS decision moments (spec 2026-07-04 DT1-DT3): dismissal flavour + per-moment
# success odds are HASH-derived from (batting side, over, ball) -- deterministic,
# no RNG consumption, stable across re-sims.

func test_flavour_is_deterministic() -> void:
	for i in range(5):
		assert_eq(DRSMoments.flavour_of(true, 7, 3), DRSMoments.flavour_of(true, 7, 3))
	assert_ne(DRSMoments.flavour_of(true, 7, 3) + "|" + DRSMoments.flavour_of(false, 7, 3) \
		+ "|" + DRSMoments.flavour_of(true, 8, 3), "", "sides/overs hash independently")

func test_flavour_weights_roughly_hold() -> void:
	# DT1 weights: caught 35, bowled 22, lbw 18, caught_behind 15, run_out 7, stumped 3.
	var counts := {}
	var n := 0
	for over in range(1, 21):
		for bio in range(1, 7):
			for salt in range(25):
				var f := DRSMoments.flavour_of(salt % 2 == 0, over + salt * 20, bio)
				counts[f] = counts.get(f, 0) + 1
				n += 1
	var want := {"caught": 0.35, "bowled": 0.22, "lbw": 0.18,
		"caught_behind": 0.15, "run_out": 0.07, "stumped": 0.03}
	for f in want:
		var share: float = float(counts.get(f, 0)) / n
		assert_almost_eq(share, want[f], 0.03, "%s share ~%.2f (got %.3f of N=%d)" % [f, want[f], share, n])

func test_reviewable_set() -> void:
	assert_true(DRSMoments.is_reviewable("lbw"))
	assert_true(DRSMoments.is_reviewable("caught_behind"))
	for f in ["caught", "bowled", "run_out", "stumped"]:
		assert_false(DRSMoments.is_reviewable(f), "%s is not reviewable-looking" % f)

func test_moment_p_range_and_determinism() -> void:
	var lo := 1.0
	var hi := 0.0
	var sum := 0.0
	var n := 0
	for over in range(1, 21):
		for bio in range(1, 7):
			for side in [true, false]:
				var p := DRSMoments.moment_p(side, over, bio)
				assert_eq(p, DRSMoments.moment_p(side, over, bio), "p is stable")
				lo = minf(lo, p); hi = maxf(hi, p); sum += p; n += 1
	assert_gte(lo, DRSMoments.P_LO, "p never below 0.20")
	assert_lte(hi, DRSMoments.P_LO + DRSMoments.P_SPAN, "p never above 0.70")
	assert_almost_eq(sum / n, 0.45, 0.05, "mean p ~0.45 over %d cells" % n)
	assert_gt(hi - lo, 0.3, "p actually varies across moments")

func test_moment_gate_table() -> void:
	# DT2: reviewable flavour AND (set: faced >= 10 balls, OR death: over >= 19).
	assert_true(DRSMoments.is_moment("lbw", 10, 8), "set batter, reviewable")
	assert_true(DRSMoments.is_moment("caught_behind", 0, 19), "death overs, fresh batter")
	assert_true(DRSMoments.is_moment("lbw", 25, 20), "set + death")
	assert_false(DRSMoments.is_moment("lbw", 9, 8), "not set, not death")
	assert_false(DRSMoments.is_moment("bowled", 30, 20), "not reviewable-looking")
	assert_false(DRSMoments.is_moment("caught", 10, 19), "caught in the deep is out")

func test_consts() -> void:
	assert_eq(DRSMoments.SET_BALLS, 10)
	assert_eq(DRSMoments.DEATH_OVER, 19)
	assert_almost_eq(DRSMoments.AI_BURN_P, 0.35, 0.0001)
