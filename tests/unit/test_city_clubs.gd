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
