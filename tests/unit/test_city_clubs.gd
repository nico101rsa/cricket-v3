extends GutTest

# T11 city clubs (spec 2026-07-04 DCC3/DCC9): every creation city has a bank of
# 8 club names; quality rules unit-enforced; unknown city falls back to canon.

func test_every_city_has_a_bank():
	for city in Cities.SA + Cities.AUS:
		assert_true(CityClubs.has_bank(city), "%s has a club bank" % city)
		assert_eq(CityClubs.bank(city).size(), 8, "%s bank has 8 clubs" % city)

func test_bank_quality_rules():
	var placeholders := []
	for lvl_names in CareerResolver.TEAM_NAMES:
		placeholders.append_array(lvl_names)
	for city in Cities.SA + Cities.AUS:
		var seen := {}
		for nm in CityClubs.bank(city):
			assert_false(seen.has(nm), "%s: '%s' unique within the city" % [city, nm])
			seen[nm] = true
			assert_lte(nm.length(), 22, "%s: '%s' fits the hub header (DCC9)" % [city, nm])
			assert_false(nm in placeholders, "%s: '%s' not a TEAM_NAMES placeholder" % [city, nm])

func test_unknown_city_falls_back_to_placeholder_club_bank():
	assert_eq(CityClubs.bank(""), CareerResolver.TEAM_NAMES[0], "empty city -> canon names")
	assert_eq(CityClubs.bank("Atlantis"), CareerResolver.TEAM_NAMES[0], "unknown city -> canon names")
	assert_false(CityClubs.has_bank(""), "no bank claimed for empty")

func test_start_career_with_city_names_the_club_level():
	var state := CareerResolver.start_career(1, "Pretoria")
	for k in range(CareerState.TEAMS_PER_LEVEL):
		assert_eq(state.teams[k].team_name, CityClubs.bank("Pretoria")[k],
			"Club slot %d named from the Pretoria bank (DCC1)" % k)
	assert_eq(state.teams[CareerState.TEAMS_PER_LEVEL].team_name,
		CareerResolver.TEAM_NAMES[1][0], "City level keeps placeholder names")
	for k in range(CareerState.TEAMS_PER_LEVEL):
		assert_eq(state.teams[k].stars, CareerResolver.STAR_LADDER[k], "ladder unchanged")
	assert_eq(state.current_team_index, 1, "picked slot honoured")

func test_start_career_without_city_is_byte_identical():
	var state := CareerResolver.start_career(0)
	for k in range(CareerState.TEAMS_PER_LEVEL):
		assert_eq(state.teams[k].team_name, CareerResolver.TEAM_NAMES[0][k],
			"no city -> canon placeholder names (DCC2)")

func test_club_slot_rides_draft_to_player():
	var d := PlayerCreationDraft.new()
	d.country = Country.Code.SA
	d.city = "Pretoria"
	d.appearance = 0
	d.name = NamePair.new()
	d.club_slot = 2
	var p := Player.from_draft(d)
	assert_eq(p.club_slot, 2, "club_slot copied at creation")
	assert_eq(Player.new().club_slot, 0, "old saves default to slot 0 (DCC7)")
