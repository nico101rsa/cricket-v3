extends GutTest

# Difficulty sheet v2 (spec 2026-06-12-difficulty-sheet-v2-design.md DV1-DV3,
# superseding the E3 v1 sheet): condition-named tours, linear ramp + Premier
# jump, bands Club 1-10 / City 5-15 / Province 9-20.


func test_tour_spec_mean_frac_endpoints() -> void:
	# Career-fidelity CF4 (2026-06-13): span 0.40-1.20, solved on the roster-path
	# felt env (Club T1 ~128, Province Premier ~155 — Nico's top anchor).
	assert_almost_eq(TourSpec.mean_frac(1.0), 0.4, 0.0001)
	assert_almost_eq(TourSpec.mean_frac(20.0), 1.2, 0.0001)


func test_tour_spec_make_tour_arithmetic() -> void:
	var spec := TourSpec.new()
	spec.d = 20.0
	var tour := spec.make_tour()
	assert_almost_eq(tour.mean, 1.2 * 31.25, 0.001)
	assert_almost_eq(tour.spread, 0.3 * tour.mean, 0.001)


func test_tour_spec_mid_anchor_matches_ref_scalar() -> void:
	assert_almost_eq(TourSpec.MID_MEAN, MatchResolver.REF_SCALAR, 0.0001)


func test_ladder_has_24_cells_with_v2_bands() -> void:
	var cells := DifficultyLadder.all()
	assert_eq(cells.size(), 24)
	# v2 bands (spec DV1): Club 1-10, City 5-15, Province 9-20.
	var lo := [1.0, 5.0, 9.0]
	var hi := [10.0, 15.0, 20.0]
	for lvl in range(3):
		assert_almost_eq(DifficultyLadder.spec_for(lvl, 0).d, lo[lvl], 0.0001)
		assert_almost_eq(DifficultyLadder.spec_for(lvl, 7).d, hi[lvl], 0.0001)


func test_ladder_d_linear_ramp_with_premier_jump() -> void:
	for lvl in range(3):
		# Linear 1-step ramp across tours 1-7 (indices 0-6)...
		for t in range(1, 7):
			assert_almost_eq(
				DifficultyLadder.spec_for(lvl, t).d - DifficultyLadder.spec_for(lvl, t - 1).d,
				1.0, 0.0001)
		# ...then the jump into Premier (spec DV1: +3 / +4 / +5 by Level).
		assert_gte(DifficultyLadder.spec_for(lvl, 7).d - DifficultyLadder.spec_for(lvl, 6).d, 3.0)


func test_ladder_overlap_anchors_are_exact() -> void:
	# Nico's structural anchor (spec DV2): next Level's Tour 1 == this Level's
	# Tour 5 (same d => identical sim).
	for lvl in range(2):
		assert_almost_eq(
			DifficultyLadder.spec_for(lvl + 1, 0).d,
			DifficultyLadder.spec_for(lvl, 4).d, 0.0001)


func test_ladder_brain_progression() -> void:
	# v2 brain map (spec DV3).
	var club_t1 := DifficultyLadder.spec_for(0, 0)
	assert_eq(club_t1.brain_tier, TourSpec.Tier.NAIVE)
	assert_almost_eq(club_t1.blend, 1.0, 0.0001)
	var club_premier := DifficultyLadder.spec_for(0, 7)        # d10
	assert_eq(club_premier.brain_tier, TourSpec.Tier.TEXTBOOK)
	assert_almost_eq(club_premier.blend, 1.0, 0.0001)
	var city_premier := DifficultyLadder.spec_for(1, 7)        # d15
	assert_eq(city_premier.brain_tier, TourSpec.Tier.STATIC_EQ)
	assert_almost_eq(city_premier.blend, 1.0, 0.0001)
	var province_premier := DifficultyLadder.spec_for(2, 7)    # d20
	assert_eq(province_premier.brain_tier, TourSpec.Tier.ADAPTIVE)
	assert_almost_eq(province_premier.blend, 1.0, 0.0001)


func test_ladder_v2_tour_names() -> void:
	# Condition flavours (spec DV1; names-only this rung, DV4).
	assert_eq(DifficultyLadder.TOUR_NAMES, [
		"Flat & Warm", "Spin", "Green Mamba", "Day Mixed",
		"Evening Spin", "Evening Mamba", "Evening Mixed", "Premier",
	])
	assert_eq(DifficultyLadder.spec_for(0, 3).cell_name, "Club Day Mixed")


func test_ladder_star_field_shape() -> void:
	var spec := DifficultyLadder.spec_for(1, 3)
	assert_eq(spec.opp_stars.size(), 7)
	var total := 0.0
	for s in spec.opp_stars:
		total += s
	assert_almost_eq(total / 7.0, 3.0, 0.0001)
