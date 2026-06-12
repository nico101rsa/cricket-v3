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


# --- Offers (DC11/DC16) ---

func _player() -> Player:
	var p := Player.new()
	var a := Attributes.new()
	a.power = 35.0
	a.composure = 30.0
	a.attack = 30.0
	a.control = 30.0
	p.attributes = a
	return p


func test_offers_are_distinct_and_exclude_current_team() -> void:
	var s := CareerResolver.start_career(0)
	var offers := CareerResolver.generate_offers(s, false, _rng(11))
	assert_lte(offers.size(), 3, "at most 3")
	assert_gt(offers.size(), 0, "some offers")
	var seen := {}
	for o in offers:
		assert_ne(o.team_index, s.current_team_index, "never the current team")
		assert_false(seen.has(o.team_index), "distinct teams")
		seen[o.team_index] = true
		assert_eq(o.stars, s.teams[o.team_index].stars, "stars snapshot matches")


func test_cross_level_guarantee_on_fresh_beat() -> void:
	var s := CareerResolver.start_career(0)
	s.mark_beaten(0, 3)   # gate beat unlocks (1,0) — v2 DV5
	for seed_value in [1, 2, 3, 4, 5]:
		var offers := CareerResolver.generate_offers(s, true, _rng(seed_value))
		var has_city := false
		for o in offers:
			if o.level == 1:
				has_city = true
		assert_true(has_city, "fresh beat + unlocked City => City offer (seed %d)" % seed_value)


func test_no_cross_level_offer_while_higher_level_locked() -> void:
	var s := CareerResolver.start_career(0)
	var offers := CareerResolver.generate_offers(s, true, _rng(3))
	for o in offers:
		assert_eq(o.level, 0, "no City teams while City is locked")


func test_down_level_offer_always_present_while_lower_level_unwon() -> void:
	var s := CareerResolver.start_career(0)
	s.mark_beaten(0, 3)
	s.current_team_index = 9   # moved to City; Club unwon
	for seed_value in [1, 2, 3, 4, 5]:
		var offers := CareerResolver.generate_offers(s, false, _rng(seed_value))
		var has_club := false
		for o in offers:
			if o.level == 0:
				has_club = true
		assert_true(has_club, "DC16: Club offer present while Club unwon (seed %d)" % seed_value)


func test_no_down_level_offer_once_lower_level_won() -> void:
	var s := CareerResolver.start_career(0)
	s.mark_beaten(0, 3)
	s.current_team_index = 9
	s.level_won[0] = true
	var offers := CareerResolver.generate_offers(s, false, _rng(2))
	for o in offers:
		assert_ne(o.level, 0, "no Club offers once Club is won")


func test_no_offers_once_complete() -> void:
	var s := CareerResolver.start_career(0)
	s.complete = true
	assert_eq(CareerResolver.generate_offers(s, true, _rng(1)).size(), 0)


func test_accept_offer_moves_team_and_resets_affinity() -> void:
	var s := CareerResolver.start_career(0)
	var p := _player()
	p.affinity = 4
	var o := Offer.new()
	o.team_index = 9
	o.level = 1
	CareerResolver.accept_offer(s, p, o)
	assert_eq(s.current_team_index, 9)
	assert_eq(s.current_level(), 1, "Level follows the Team")
	assert_eq(p.affinity, 0, "Affinity resets on accept")


func test_stay_increments_affinity() -> void:
	var s := CareerResolver.start_career(0)
	var p := _player()
	CareerResolver.stay(s, p)
	CareerResolver.stay(s, p)
	assert_eq(p.affinity, 2)


# --- play_season (DC5/DC8/DC9/DC13) ---

func _play(s: CareerState, p: Player, tour: int, seed_value: int) -> Dictionary:
	return CareerResolver.play_season(
		s, p, tour, BallTuning.new(), InningsTuning.new(), EconomyTuning.new(),
		_rng(seed_value))


func test_play_season_deterministic() -> void:
	var s1 := CareerResolver.start_career(0)
	var s2 := CareerResolver.start_career(0)
	var p1 := _player()
	var p2 := _player()
	var o1 := _play(s1, p1, 0, 99)
	var o2 := _play(s2, p2, 0, 99)
	assert_eq(o1["pay"], o2["pay"], "pay deterministic")
	assert_eq(o1["wins"], o2["wins"], "wins deterministic")
	assert_eq(o1["season"].player_final_position, o2["season"].player_final_position)
	assert_eq(o1["offers"].size(), o2["offers"].size())
	for k in range(o1["offers"].size()):
		assert_eq(o1["offers"][k].team_index, o2["offers"][k].team_index, "offer %d same" % k)


func test_play_season_ticks_counter_and_banks_pay() -> void:
	var s := CareerResolver.start_career(0)
	var p := _player()
	var out := _play(s, p, 0, 7)
	assert_eq(s.seasons_played, 1, "Seasons played ticks win or lose")
	assert_eq(p.tons_balance, out["pay"], "pay banked")
	assert_gt(out["pay"], 0, "a Season always pays something (game fees)")


func test_play_season_pay_reconciles_with_match_pay() -> void:
	var s := CareerResolver.start_career(0)
	var p := _player()
	var etun := EconomyTuning.new()
	var stars_at_play: float = s.teams[s.current_team_index].stars
	var out := _play(s, p, 0, 13)
	var season: SeasonResult = out["season"]
	var expected := 0
	var wins := 0
	var played: Array = season.league.player_matches.duplicate()
	for m in [season.semi1, season.semi2, season.final_match, season.third_place]:
		if not m.innings1.player_line().is_empty() or not m.innings2.player_line().is_empty():
			played.append(m)
	for m in played:
		expected += Economy.match_pay(m, stars_at_play, etun)["total"]
		if m.outcome == MatchResult.Outcome.PLAYER_WIN:
			wins += 1
			expected += Economy.match_win_prize(0, 0, etun)
	expected += Economy.season_prizes(
		season.player_final_position, season.won_final, 0, 0, etun)
	assert_eq(out["pay"], expected, "pay = match pay + win prizes + season prizes")
	assert_eq(out["wins"], wins, "wins reported")


func test_play_season_mutates_stars_at_rollover() -> void:
	var s := CareerResolver.start_career(0)
	var before: Array = []
	for t in s.teams:
		before.append(t.stars)
	var _out := _play(s, _player(), 0, 21)
	var changed := 0
	for k in range(24):
		assert_between(s.teams[k].stars, 0.5, 5.0, "stars clamped")
		if not is_equal_approx(s.teams[k].stars, before[k]):
			changed += 1
	assert_gt(changed, 0, "ADR 0009 mutation fired across the rosters")


func test_play_season_beat_updates_grid() -> void:
	# A strong player on the 2.5-star pick at Club Practise (d=1.0) beats the
	# Season often; find a seed that beats and assert the grid moved.
	var found := false
	for seed_value in range(50):
		var s := CareerResolver.start_career(2)
		var p := _player()
		p.attributes.power = 50.0
		p.attributes.composure = 50.0
		var out := _play(s, p, 0, seed_value)
		if out["season"].beat:
			assert_eq(s.status_of(0, 0), CareerState.CellStatus.BEATEN)
			assert_true(s.is_unlocked(0, 1), "up cell open")
			assert_false(s.is_unlocked(1, 0), "League gate holds — Flat & Warm is not the gate cell")
			found = true
			break
	assert_true(found, "a beating seed exists within 50 at Club Practise")


func test_play_season_locked_cell_is_rejected() -> void:
	var s := CareerResolver.start_career(0)
	var out := CareerResolver.play_season(
		s, _player(), 5, BallTuning.new(), InningsTuning.new(), EconomyTuning.new(), _rng(1))
	assert_true(out.is_empty(), "locked cell returns empty")
	assert_eq(s.seasons_played, 0, "nothing ticked")
