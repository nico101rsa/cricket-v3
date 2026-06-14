extends GutTest

# E4 climb-strategy unit tests (spec 2026-06-14-e4-career-line-search-design.md §6).


func _fresh_club_state() -> CareerState:
	# Club, only Tour 0 unlocked — the start of a career.
	return CareerResolver.start_career(0)


func test_rush_choose_tour_is_lowest_unbeaten() -> void:
	var state := _fresh_club_state()
	# Only T0 unlocked → that is the lowest unbeaten unlocked tour.
	assert_eq(CareerPolicy.choose_tour("rush", state), 0)
	# Beat T0 → T1 unlocks; lowest unbeaten is now T1.
	state.record_outcome(0, 0, true, false)
	assert_eq(CareerPolicy.choose_tour("rush", state), 1)


func test_farm_choose_tour_is_highest_unlocked() -> void:
	var state := _fresh_club_state()
	state.record_outcome(0, 0, true, false)   # unlock T1
	state.record_outcome(0, 1, true, false)   # unlock T2
	# Highest unlocked tour is T2 (farm replays the richest cell).
	assert_eq(CareerPolicy.choose_tour("farm", state), 2)


func test_trophy_choose_tour_is_lowest_unbeaten() -> void:
	var state := _fresh_club_state()
	state.record_outcome(0, 0, true, false)
	# trophy climbs lowest-unbeaten just like rush (they differ on OFFERS).
	assert_eq(CareerPolicy.choose_tour("trophy", state), 1)


func test_choose_tour_all_beaten_replays_premier() -> void:
	var state := _fresh_club_state()
	for t in range(CareerState.TOURS):
		state.record_outcome(0, t, true, false)   # beat every tour, no final win
	# No unbeaten cell left → fall back to the Premier (T7) to chase the final.
	assert_eq(CareerPolicy.choose_tour("rush", state), CareerState.PREMIER_TOUR)
	assert_eq(CareerPolicy.choose_tour("trophy", state), CareerState.PREMIER_TOUR)
