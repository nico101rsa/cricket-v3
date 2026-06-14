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


# A Club state with the gate (T3) beaten so a City cross-up Offer is legal.
func _club_with_cross_offer() -> Array:
	var state := CareerResolver.start_career(0)
	state.record_outcome(0, CareerState.READINESS_TOUR, true, false)
	var up := Offer.new()
	up.team_index = CareerState.TEAMS_PER_LEVEL   # first City slot
	up.level = 1
	up.stars = 3.0
	return [state, up]


func _fresh_player() -> Player:
	var p := Player.new()
	var a := Attributes.new()
	a.power = 11.0
	a.composure = 11.0
	a.attack = 11.0
	a.control = 11.0
	p.attributes = a
	return p


func test_rush_offer_accepts_cross_up_immediately() -> void:
	var pair := _club_with_cross_offer()
	var state: CareerState = pair[0]
	var up: Offer = pair[1]
	# rush crosses the moment a higher Level is offered, even without level_won.
	assert_eq(CareerPolicy.choose_offer("rush", state, [up], _fresh_player()), up)


func test_rush_offer_stays_when_no_higher_offer() -> void:
	var state := CareerResolver.start_career(0)
	assert_null(CareerPolicy.choose_offer("rush", state, [], _fresh_player()))


func test_farm_offer_stays_until_card_maxed() -> void:
	var pair := _club_with_cross_offer()
	var state: CareerState = pair[0]
	var up: Offer = pair[1]
	var player := _fresh_player()
	# Under-built card → farm stays.
	assert_null(CareerPolicy.choose_offer("farm", state, [up], player))
	# Max the card → farm now crosses.
	for a in ["power", "composure", "attack", "control"]:
		player.attributes.set(a, ShopResolver.ATTR_CAP)
	assert_eq(CareerPolicy.choose_offer("farm", state, [up], player), up)


func test_trophy_offer_stays_until_level_won() -> void:
	var pair := _club_with_cross_offer()
	var state: CareerState = pair[0]
	var up: Offer = pair[1]
	var player := _fresh_player()
	# Club Premier not yet won → trophy stays.
	assert_null(CareerPolicy.choose_offer("trophy", state, [up], player))
	# Win Club's Premier final → trophy crosses.
	state.level_won[0] = true
	assert_eq(CareerPolicy.choose_offer("trophy", state, [up], player), up)


func test_no_pole_accepts_a_down_offer() -> void:
	# A down Offer (lower Level) is never accepted by any pole, even when every
	# cross-condition is satisfied.
	var state := CareerResolver.start_career(0)
	state.current_team_index = CareerState.TEAMS_PER_LEVEL   # sit in City (Level 1)
	state.level_won[1] = true
	var player := _fresh_player()
	for a in ["power", "composure", "attack", "control"]:
		player.attributes.set(a, ShopResolver.ATTR_CAP)
	var down := Offer.new()
	down.team_index = 0
	down.level = 0
	down.stars = 1.5
	for kind in CareerPolicy.KINDS:
		assert_null(CareerPolicy.choose_offer(kind, state, [down], player))


# --- farm-trigger fix (career-line balancing): cross on maxed-OR-FARM_MIN_SEASONS ---

func _maxed_player() -> Player:
	var p := _fresh_player()
	for a in ["power", "composure", "attack", "control"]:
		p.attributes.set(a, ShopResolver.ATTR_CAP)
	return p

func test_farm_crosses_after_min_seasons_even_unmaxed() -> void:
	var s := CareerState.new()
	var p := _fresh_player()   # card well below the cap
	s.seasons_at_level = CareerPolicy.FARM_MIN_SEASONS
	assert_true(CareerPolicy._wants_to_cross("farm", s, p),
		"farm crosses once it has lingered FARM_MIN_SEASONS, even unmaxed")

func test_farm_holds_before_min_seasons_when_unmaxed() -> void:
	var s := CareerState.new()
	var p := _fresh_player()
	s.seasons_at_level = CareerPolicy.FARM_MIN_SEASONS - 1
	assert_false(CareerPolicy._wants_to_cross("farm", s, p),
		"farm holds while under the linger cap and unmaxed")

func test_farm_crosses_immediately_when_maxed() -> void:
	var s := CareerState.new()
	var p := _maxed_player()
	s.seasons_at_level = 0
	assert_true(CareerPolicy._wants_to_cross("farm", s, p),
		"a maxed card crosses without waiting for the linger cap")
