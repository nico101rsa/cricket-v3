extends GutTest

func _tour(mean: int, spread: int, noise: int) -> TourDistribution:
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
	var tour := _tour(5, 3, 1)
	var strong := _team(5.0)
	var weak := _team(1.0)
	var strong_sum := 0
	var weak_sum := 0
	var n := 200
	for s in range(n):
		strong_sum += strong.batting_strength(tour, _rng(s))
		weak_sum += weak.batting_strength(tour, _rng(s))
	assert_gt(strong_sum, weak_sum, "5.0 stars derives higher batting than 1.0 stars on average")

func test_noise_bounded_and_floored() -> void:
	var tour := _tour(5, 3, 1)
	var tm := _team(5.0)            # percentile(1.0) == 8
	for s in range(50):
		var v := tm.bowling_strength(tour, _rng(s))
		assert_true(v >= 7 and v <= 9, "5.0-star strength within mean+spread +- noise (got %d)" % v)
	# Floor: a tiny band + lowest star can push below 1; must clamp to 1.
	var tiny := _tour(1, 1, 5)     # percentile(0.1) == roundi(1 + (0.1-0.5)*2*1) == 0
	var cellar := _team(0.5)
	for s in range(50):
		assert_true(cellar.batting_strength(tiny, _rng(s)) >= 1, "strength floored at 1")

func test_zero_noise_matches_percentile() -> void:
	var tour := _tour(5, 3, 0)
	assert_eq(_team(5.0).batting_strength(tour, _rng(1)), tour.percentile(1.0), "5.0 stars, no noise -> percentile(1.0)")
	assert_eq(_team(0.5).bowling_strength(tour, _rng(1)), tour.percentile(0.1), "0.5 stars, no noise -> percentile(0.1)")

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

func test_archetypes_are_valid_20pt_builds() -> void:
	for a in [Team.archetype_batter(), Team.archetype_bowler(), Team.archetype_allrounder()]:
		assert_eq(a.sum(), 20, "archetype is a 20-point build")
		assert_true(a.is_valid_creation_distribution(), "archetype is a legal distribution")
	var bat := Team.archetype_batter()
	assert_eq([bat.power, bat.composure, bat.attack, bat.control], [8, 8, 2, 2], "BATTER 8/8/2/2")
	var bwl := Team.archetype_bowler()
	assert_eq([bwl.power, bwl.composure, bwl.attack, bwl.control], [2, 2, 8, 8], "BOWLER 2/2/8/8")
	var ar := Team.archetype_allrounder()
	assert_eq([ar.power, ar.composure, ar.attack, ar.control], [5, 5, 5, 5], "ALLROUNDER 5/5/5/5")

func test_standard_xi_shape_and_point_split() -> void:
	var xi := Team.standard_xi()
	assert_eq(xi.size(), 11, "a full XI of 11 players")
	for i in range(6):
		assert_eq(xi[i].power, 8, "slots 1..6 are top-order batters (power 8)")
	assert_eq(xi[6].power, 5, "slot 7 is the all-rounder")
	for i in range(7, 11):
		assert_eq(xi[i].power, 2, "slots 8..11 are bowlers (power 2)")
	var bat_pts := 0
	var bowl_pts := 0
	for p in xi:
		bat_pts += p.power + p.composure
		bowl_pts += p.attack + p.control
	assert_eq(bat_pts, 122, "team batting points = 122 (spec target)")
	assert_eq(bowl_pts, 98, "team bowling points = 98 (spec target)")

func test_build_xi_places_player_at_position() -> void:
	var player := Attributes.new()
	player.power = 7; player.composure = 6; player.attack = 4; player.control = 3
	var xi := Team.build_xi(player, 3)
	assert_eq(xi.size(), 11, "still a full XI")
	assert_true(xi[2] == player, "the Player object sits at 1-based position 3")
	var player_slots := 0
	for p in xi:
		if p == player:
			player_slots += 1
	assert_eq(player_slots, 1, "the Player appears exactly once")

# --- Slice 3: batting budget conservation (gap-fill, D11) ---------------------

func _bat_pts(xi: Array) -> int:
	var t := 0
	for a in xi:
		t += a.power + a.composure
	return t

func test_build_xi_conserves_team_batting_to_122() -> void:
	var itun := InningsTuning.new()
	for cfg in [[8, 8, 2, 2], [5, 5, 5, 5], [2, 2, 8, 8], [7, 6, 4, 3], [3, 3, 7, 7]]:
		var p := Attributes.new()
		p.power = cfg[0]; p.composure = cfg[1]; p.attack = cfg[2]; p.control = cfg[3]
		var ppos := InningsResolver.player_position(p, itun)
		var xi := Team.build_xi(p, ppos)
		assert_eq(_bat_pts(xi), 122, "team batting conserved to 122 for build %s" % str(cfg))

func test_build_xi_leaves_player_attrs_untouched() -> void:
	var p := Attributes.new()
	p.power = 2; p.composure = 2; p.attack = 8; p.control = 8
	var ppos := InningsResolver.player_position(p, InningsTuning.new())
	var xi := Team.build_xi(p, ppos)
	assert_eq(p.power, 2, "Player power untouched by gap-fill")
	assert_eq(p.composure, 2, "Player composure untouched by gap-fill")
	assert_true(xi[ppos - 1] == p, "Player still at their slot, by reference")
