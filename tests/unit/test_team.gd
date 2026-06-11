extends GutTest

func _tour(mean: float, spread: float, noise: int) -> TourDistribution:
	var t := TourDistribution.new()
	t.mean = mean
	t.spread = spread
	t.noise = noise
	return t

func _team(stars: float) -> Team:
	var tm := Team.new()
	tm.stars = stars
	return tm

func _rng(seed_value: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	return r

func test_stronger_stars_higher_mean_strength() -> void:
	var tour := _tour(31.25, 18.75, 1)
	var strong := _team(5.0)
	var weak := _team(1.0)
	var strong_sum := 0.0
	var weak_sum := 0.0
	var n := 200
	for s in range(n):
		strong_sum += strong.batting_strength(tour, _rng(s))
		weak_sum += weak.batting_strength(tour, _rng(s))
	assert_gt(strong_sum, weak_sum, "5.0 stars derives higher batting than 1.0 stars on average")

func test_noise_bounded_and_floored() -> void:
	var tour := _tour(31.25, 18.75, 1)
	var tm := _team(5.0)            # strength_frac 0.9 -> percentile == 46.25
	for s in range(50):
		var v := tm.bowling_strength(tour, _rng(s))
		assert_true(v >= 40.0 and v <= 52.5, "5.0-star strength within percentile(0.9) +- noise (got %f)" % v)
	# Floor: a tiny band + lowest star can push below one legacy point; must clamp to SCALE.
	var tiny := _tour(6.25, 6.25, 5)     # strength_frac(0.5*) = 0.0 -> percentile = 0.0
	var cellar := _team(0.5)
	for s in range(50):
		assert_true(cellar.batting_strength(tiny, _rng(s)) >= Attributes.SCALE, "strength floored at one legacy point")

func test_zero_noise_matches_percentile() -> void:
	var tour := _tour(31.25, 18.75, 0)
	assert_eq(_team(5.0).batting_strength(tour, _rng(1)), tour.percentile(0.9), "5.0 stars, no noise -> percentile(strength_frac=0.9)")
	assert_eq(_team(0.5).bowling_strength(tour, _rng(1)), tour.percentile(0.0), "0.5 stars, no noise -> percentile(strength_frac=0.0)")

func test_mutate_stars_distribution() -> void:
	var unchanged := 0
	var half := 0
	var full := 0
	var n := 4000
	for s in range(n):
		var tm := _team(3.0)
		tm.mutate_stars(_rng(s))
		var d: float = absf(tm.stars - 3.0)
		if is_equal_approx(d, 0.0):
			unchanged += 1
		elif is_equal_approx(d, 0.5):
			half += 1
		elif is_equal_approx(d, 1.0):
			full += 1
		assert_true(is_equal_approx(fmod(tm.stars, 0.5), 0.0) or is_equal_approx(fmod(tm.stars, 0.5), 0.5),
			"result stays on the 0.5 grid (got %f)" % tm.stars)
	assert_almost_eq(float(unchanged) / n, 0.65, 0.05, "~65%% unchanged")
	assert_almost_eq(float(half) / n, 0.30, 0.05, "~30%% +-0.5")
	assert_almost_eq(float(full) / n, 0.05, 0.05, "~5%% +-1.0")

func test_mutate_stars_clamped() -> void:
	for s in range(200):
		var hi := _team(5.0)
		hi.mutate_stars(_rng(s))
		assert_lte(hi.stars, 5.0, "never above 5.0")
		var lo := _team(0.5)
		lo.mutate_stars(_rng(s))
		assert_gte(lo.stars, 0.5, "never below 0.5")

func test_archetypes_are_valid_125pt_builds() -> void:
	# NPC archetypes keep the 125-point budget but are exempt from the
	# Player-creation per-attribute cap [5,50] (bowling-balance BB5: the
	# BOWLER's 6.25/6.25/56.25/56.25 split steepens the tail so wickets cost
	# more; card-rescale 2026-06-11 = legacy values × 6.25).
	for a in [Team.archetype_batter(), Team.archetype_bowler(), Team.archetype_allrounder()]:
		assert_eq(a.sum(), 125.0, "archetype is a 125-point build")
	var bat := Team.archetype_batter()
	assert_eq([bat.power, bat.composure, bat.attack, bat.control], [50.0, 50.0, 12.5, 12.5], "BATTER 50/50/12.5/12.5")
	var bwl := Team.archetype_bowler()
	assert_eq([bwl.power, bwl.composure, bwl.attack, bwl.control], [6.25, 6.25, 56.25, 56.25], "BOWLER 6.25/6.25/56.25/56.25 (steep tail, BB5)")
	var ar := Team.archetype_allrounder()
	assert_eq([ar.power, ar.composure, ar.attack, ar.control], [31.25, 31.25, 31.25, 31.25], "ALLROUNDER 31.25 x4")

func test_standard_xi_shape_and_point_split() -> void:
	var xi := Team.standard_xi()
	assert_eq(xi.size(), 11, "a full XI of 11 players")
	for i in range(6):
		assert_eq(xi[i].power, 50.0, "slots 1..6 are top-order batters (power 50)")
	assert_eq(xi[6].power, 31.25, "slot 7 is the all-rounder")
	for i in range(7, 11):
		assert_eq(xi[i].power, 6.25, "slots 8..11 are bowlers (power 6.25, steep tail BB5)")
	var bat_pts := 0.0
	var bowl_pts := 0.0
	for p in xi:
		bat_pts += p.power + p.composure
		bowl_pts += p.attack + p.control
	assert_eq(bat_pts, 712.5, "team batting points = 712.5 (legacy 114 x SCALE, BB5 split)")
	assert_eq(bowl_pts, 662.5, "team bowling points = 662.5 (legacy 106 x SCALE, BB5 split)")

func test_build_xi_places_player_at_position() -> void:
	var player := Attributes.new()
	player.power = 43.75; player.composure = 37.5; player.attack = 25.0; player.control = 18.75
	var xi := Team.build_xi(player, 3)
	assert_eq(xi.size(), 11, "still a full XI")
	assert_true(xi[2] == player, "the Player object sits at 1-based position 3")
	var player_slots := 0
	for p in xi:
		if p == player:
			player_slots += 1
	assert_eq(player_slots, 1, "the Player appears exactly once")

# --- Slice 3: batting budget conservation (gap-fill, D11) ---------------------

func _bat_pts(xi: Array) -> float:
	var t := 0.0
	for a in xi:
		t += a.power + a.composure
	return t

func test_build_xi_conserves_team_batting_total() -> void:
	var itun := InningsTuning.new()
	for cfg in [[50.0, 50.0, 12.5, 12.5], [31.25, 31.25, 31.25, 31.25], [12.5, 12.5, 50.0, 50.0], [43.75, 37.5, 25.0, 18.75], [18.75, 18.75, 43.75, 43.75]]:
		var p := Attributes.new()
		p.power = cfg[0]; p.composure = cfg[1]; p.attack = cfg[2]; p.control = cfg[3]
		var ppos := InningsResolver.player_position(p, itun)
		var xi := Team.build_xi(p, ppos)
		assert_almost_eq(_bat_pts(xi), 712.5, 1e-6, "team batting conserved to 712.5 for build %s (BB5 split)" % str(cfg))

func test_build_xi_conserves_fractional_deficit_exactly() -> void:
	# Card-rescale DR9: a build off the legacy grid (e.g. the creation 5-grid)
	# leaves a fractional deficit; the gap-fill's fractional final chunk must
	# conserve it exactly.
	var itun := InningsTuning.new()
	var p := Attributes.new()
	p.power = 35.0; p.composure = 30.0; p.attack = 30.0; p.control = 30.0
	var ppos := InningsResolver.player_position(p, itun)
	var xi := Team.build_xi(p, ppos)
	assert_almost_eq(_bat_pts(xi), 712.5, 1e-6, "fractional deficit conserved exactly")

func test_build_xi_leaves_player_attrs_untouched() -> void:
	var p := Attributes.new()
	p.power = 12.5; p.composure = 12.5; p.attack = 50.0; p.control = 50.0
	var ppos := InningsResolver.player_position(p, InningsTuning.new())
	var xi := Team.build_xi(p, ppos)
	assert_eq(p.power, 12.5, "Player power untouched by gap-fill")
	assert_eq(p.composure, 12.5, "Player composure untouched by gap-fill")
	assert_true(xi[ppos - 1] == p, "Player still at their slot, by reference")

# --- Card-rescale Stage B: the *3-centred star map (DR5) ----------------------

func test_strength_frac_is_star3_centred():
	var t := _team(3.0)
	assert_almost_eq(t.strength_frac(), 0.5, 1e-9, "*3 = the tour centre (the balance anchor)")
	t.stars = 0.5
	assert_almost_eq(t.strength_frac(), 0.0, 1e-9, "*0.5 = band floor")
	t.stars = 5.0
	assert_almost_eq(t.strength_frac(), 0.9, 1e-9, "*5 sits inside the band top")

func test_star3_zero_noise_strength_is_ref_scalar():
	var t := _team(3.0)
	var tour := TourDistribution.new()
	tour.noise = 0
	assert_almost_eq(t.batting_strength(tour, _rng(1)), MatchResolver.REF_SCALAR, 1e-9,
		"a *3 mid-tour team plays its cards at face value")
