extends GutTest

# CareerState grid topology + transitions (spec 2026-06-12-career-loop-design.md
# DC4, §3.1). States here are built by hand; start_career() is CareerResolver's
# (and tested in test_career_resolver.gd).

func _state() -> CareerState:
	var s := CareerState.new()
	var stars := [1.5, 2.0, 2.5, 3.0, 3.0, 3.5, 4.0, 4.5]
	for lvl in range(3):
		for k in range(8):
			var t := Team.new()
			t.team_name = "L%d-T%d" % [lvl, k]
			t.stars = stars[k]
			s.teams.append(t)
	var status: Array[int] = []
	for i in range(24):
		status.append(CareerState.CellStatus.LOCKED)
	status[0] = CareerState.CellStatus.UNLOCKED
	s.cell_status = status
	return s


func test_fresh_state_seasons_at_level_zero() -> void:
	var s := CareerState.new()
	assert_eq(s.seasons_at_level, 0, "fresh state has lingered zero Seasons")


func test_fresh_state_only_club_practise_unlocked() -> void:
	var s := _state()
	assert_true(s.is_unlocked(0, 0), "Club Practise open")
	assert_false(s.is_unlocked(0, 1), "next Tour locked")
	assert_false(s.is_unlocked(1, 0), "City locked")
	assert_eq(s.playable_cells(), [0], "one playable cell")


func test_beat_unlocks_next_tour_only_off_gate() -> void:
	# v2 (spec DV5): a non-gate beat unlocks the next Tour, NOT the next League.
	var s := _state()
	s.mark_beaten(0, 0)
	assert_eq(s.status_of(0, 0), CareerState.CellStatus.BEATEN, "cell beaten")
	assert_true(s.is_unlocked(0, 1), "next Tour unlocked")
	assert_false(s.is_unlocked(1, 0), "next League stays locked")
	assert_true(s.is_unlocked(0, 0), "beaten cell stays replayable")


func test_beating_readiness_tour_unlocks_next_league_at_tour1() -> void:
	# Career-line balancing: the next League opens off READINESS_TOUR (Evening
	# Mamba, index 5), NOT the old gate tour 3 — so the rusher climbs most of
	# the league before crossing.
	var s := _state()
	s.cell_status[s.cell_index(0, CareerState.READINESS_TOUR)] = CareerState.CellStatus.UNLOCKED
	s.mark_beaten(0, CareerState.READINESS_TOUR)
	assert_true(s.is_unlocked(0, CareerState.READINESS_TOUR + 1), "next Tour unlocked")
	assert_true(s.is_unlocked(1, 0), "City Flat & Warm unlocked off the readiness tour")
	assert_false(s.is_unlocked(1, 3), "City's own cells beyond Flat & Warm NOT unlocked")


func test_beating_old_gate_tour_no_longer_unlocks_next_league() -> void:
	var s := _state()
	s.cell_status[s.cell_index(0, 3)] = CareerState.CellStatus.UNLOCKED
	s.mark_beaten(0, 3)
	assert_true(s.is_unlocked(0, 4), "next Tour still unlocks")
	assert_false(s.is_unlocked(1, 0), "tour 3 (Day Mixed) no longer opens the next League")


func test_readiness_tour_at_top_level_does_not_crash() -> void:
	var s := _state()
	s.cell_status[s.cell_index(2, CareerState.READINESS_TOUR)] = CareerState.CellStatus.UNLOCKED
	s.mark_beaten(2, CareerState.READINESS_TOUR)   # no level 3 — must not crash
	assert_true(s.is_unlocked(2, CareerState.READINESS_TOUR + 1))


func test_beat_at_edges_clamps() -> void:
	var s := _state()
	s.cell_status[s.cell_index(2, 7)] = CareerState.CellStatus.UNLOCKED
	s.mark_beaten(2, 7)   # no level 3 / tour 8 to unlock — must not crash
	assert_eq(s.status_of(2, 7), CareerState.CellStatus.BEATEN)


func test_province_premium_has_no_level_win_gate() -> void:
	# Nico's ruling 2026-06-12 (career-pacing spec DP1): adjacency unlock is the
	# only requirement — lower Premium wins are an optional trophy chase.
	var s := _state()
	s.cell_status[s.cell_index(2, 7)] = CareerState.CellStatus.UNLOCKED
	assert_true(s.is_unlocked(2, 7), "playable with zero Premium wins")


func test_record_outcome_beat_and_level_win() -> void:
	var s := _state()
	s.record_outcome(0, 0, true, false)
	assert_eq(s.status_of(0, 0), CareerState.CellStatus.BEATEN, "beat recorded")
	s.cell_status[s.cell_index(0, 7)] = CareerState.CellStatus.UNLOCKED
	s.record_outcome(0, 7, true, true)
	assert_true(s.level_won[0], "Premium Final win = Level won")
	assert_false(s.complete, "Club win does not complete the Career")


func test_record_outcome_province_premium_win_completes() -> void:
	var s := _state()
	s.level_won = [true, true, false]
	s.cell_status[s.cell_index(2, 7)] = CareerState.CellStatus.UNLOCKED
	s.record_outcome(2, 7, true, true)
	assert_true(s.level_won[2])
	assert_true(s.complete, "Province Premium win completes the Career")


func test_record_outcome_loss_changes_nothing() -> void:
	var s := _state()
	s.record_outcome(0, 0, false, false)
	assert_eq(s.status_of(0, 0), CareerState.CellStatus.UNLOCKED, "still just unlocked")
	assert_false(s.level_won[0])


func test_current_level_and_rosters() -> void:
	var s := _state()
	s.current_team_index = 10
	assert_eq(s.current_level(), 1, "team 10 is a City team")
	assert_eq(s.roster_of(1).size(), 8)
	var opps := s.opponents_of_current()
	assert_eq(opps.size(), 7, "7 opponents")
	for t in opps:
		assert_ne(t, s.teams[10], "current team not its own opponent")


func test_lowest_star_club_indices() -> void:
	var s := _state()
	assert_eq(s.lowest_star_club_indices(), [0, 1, 2], "the 3 lowest-star Club slots")


func test_any_unlocked_at() -> void:
	var s := _state()
	assert_true(s.any_unlocked_at(0))
	assert_false(s.any_unlocked_at(1))


func test_offer_is_pure_data() -> void:
	var o := Offer.new()
	o.team_index = 9
	o.level = 1
	o.stars = 3.5
	assert_eq(o.team_index, 9)
	assert_eq(o.level, 1)
	assert_eq(o.stars, 3.5)


# --- next_climb_tour (live rush-climb cell selection, spec 2026-06-24 DLC3) ---

func test_next_climb_tour_fresh_is_zero() -> void:
	var s := _state()
	assert_eq(s.next_climb_tour(0), 0, "fresh state: only (0,0) unlocked")


func test_next_climb_tour_advances_after_beat() -> void:
	var s := _state()
	s.mark_beaten(0, 0)   # unlocks (0,1)
	assert_eq(s.next_climb_tour(0), 1, "after beating (0,0): next climb tour is 1")


func test_next_climb_tour_minus_one_when_readiness_cleared() -> void:
	var s := _state()
	for t in range(CareerState.READINESS_TOUR + 1):
		s.mark_beaten(0, t)
	assert_eq(s.next_climb_tour(0), -1, "all climb tours <= READINESS beaten: -1")
