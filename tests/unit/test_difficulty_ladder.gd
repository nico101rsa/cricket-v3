extends GutTest

# E3 (spec 2026-06-12-difficulty-ladder-7cE3-design.md): the codified canon
# difficulty sheet + per-cell TourSpec rows.


func test_tour_spec_mean_frac_endpoints() -> void:
	assert_almost_eq(TourSpec.mean_frac(1.0), 0.4, 0.0001)
	assert_almost_eq(TourSpec.mean_frac(12.0), 1.3, 0.0001)


func test_tour_spec_make_tour_arithmetic() -> void:
	var spec := TourSpec.new()
	spec.d = 12.0
	var tour := spec.make_tour()
	assert_almost_eq(tour.mean, 1.3 * 31.25, 0.001)
	assert_almost_eq(tour.spread, 0.3 * tour.mean, 0.001)


func test_tour_spec_mid_anchor_matches_ref_scalar() -> void:
	assert_almost_eq(TourSpec.MID_MEAN, MatchResolver.REF_SCALAR, 0.0001)


func test_ladder_has_24_cells_with_canon_bands() -> void:
	var cells := DifficultyLadder.all()
	assert_eq(cells.size(), 24)
	# Canon bands (CONTEXT.md): Club 1-8, City 2-10, Province 3-12.
	var lo := [1.0, 2.0, 3.0]
	var hi := [8.0, 10.0, 12.0]
	for lvl in range(3):
		assert_almost_eq(DifficultyLadder.spec_for(lvl, 0).d, lo[lvl], 0.0001)
		assert_almost_eq(DifficultyLadder.spec_for(lvl, 7).d, hi[lvl], 0.0001)


func test_ladder_d_monotone_within_level_with_canon_jumps() -> void:
	for lvl in range(3):
		for t in range(1, 8):
			assert_gt(DifficultyLadder.spec_for(lvl, t).d, DifficultyLadder.spec_for(lvl, t - 1).d)
		# Deliberate jumps at Home->Away (index 3->4) and ->Premium (6->7).
		assert_gte(DifficultyLadder.spec_for(lvl, 4).d - DifficultyLadder.spec_for(lvl, 3).d, 2.0)
		assert_gte(DifficultyLadder.spec_for(lvl, 7).d - DifficultyLadder.spec_for(lvl, 6).d, 2.0)


func test_ladder_levels_overlap() -> void:
	# A higher Level's Practise is gentler than the Level below's Away tours.
	for lvl in range(2):
		assert_lt(DifficultyLadder.spec_for(lvl + 1, 0).d, DifficultyLadder.spec_for(lvl, 4).d)


func test_ladder_brain_progression() -> void:
	var club_practise := DifficultyLadder.spec_for(0, 0)
	assert_eq(club_practise.brain_tier, TourSpec.Tier.NAIVE)
	assert_almost_eq(club_practise.blend, 1.0, 0.0001)
	var club_premium := DifficultyLadder.spec_for(0, 7)
	assert_eq(club_premium.brain_tier, TourSpec.Tier.STATIC_EQ)
	assert_almost_eq(club_premium.blend, 0.5, 0.0001)
	var province_premium := DifficultyLadder.spec_for(2, 7)
	assert_eq(province_premium.brain_tier, TourSpec.Tier.ADAPTIVE)
	assert_almost_eq(province_premium.blend, 1.0, 0.0001)


func test_ladder_star_field_shape() -> void:
	var spec := DifficultyLadder.spec_for(1, 3)
	assert_eq(spec.opp_stars.size(), 7)
	var total := 0.0
	for s in spec.opp_stars:
		total += s
	assert_almost_eq(total / 7.0, 3.0, 0.0001)
