extends GutTest

# CareerResolver — the multi-Season loop (spec 2026-06-12-career-loop-design.md).

func _rng(seed_value: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	return r


func test_start_career_builds_24_teams_with_star_ladder() -> void:
	var s := CareerResolver.start_career(0)
	assert_eq(s.teams.size(), 24, "8 teams x 3 Levels")
	var names := {}
	for lvl in range(3):
		var star_sum := 0.0
		for t in s.roster_of(lvl):
			star_sum += t.stars
			assert_false(t.team_name.is_empty(), "every team named")
			assert_false(names.has(t.team_name), "names distinct: %s" % t.team_name)
			names[t.team_name] = true
		assert_almost_eq(star_sum / 8.0, 3.0, 0.001, "Level %d star mean 3.0" % lvl)


func test_start_career_grid_and_counters_fresh() -> void:
	var s := CareerResolver.start_career(1)
	assert_eq(s.current_team_index, 1, "picked team")
	assert_eq(s.current_level(), 0, "starts at Club")
	assert_eq(s.playable_cells(), [0], "only Club Practise open")
	assert_eq(s.seasons_played, 0)
	assert_false(s.complete)


func test_start_career_rejects_non_underdog_pick() -> void:
	var s := CareerResolver.start_career(7)   # the 4.5-star franchise — not a legal pick
	assert_true(s.current_team_index in s.lowest_star_club_indices(),
		"invalid pick falls back to a lowest-3 slot")
