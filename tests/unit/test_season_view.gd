extends GutTest

# SeasonView — the read-model the Season Hub renders (spec 2026-06-15-season-hub-replay §4).

func test_defaults_are_empty_and_typed() -> void:
	var v := SeasonView.new()
	assert_eq(v.match_count, 7, "a league season is 7 Player games")
	assert_eq(v.scrub_index, 0, "boots before match 1")
	assert_eq(v.fixtures.size(), 0, "no fixtures until built")
	assert_eq(v.card_matches, 0, "empty card")
	assert_eq(v.tons_balance, 0)

func test_fields_round_trip() -> void:
	var v := SeasonView.new()
	v.player_name = "B. KGOSI"
	v.tour_name = "Flat & Warm"
	v.tons_balance = 120
	v.scrub_index = 3
	assert_eq(v.player_name, "B. KGOSI")
	assert_eq(v.tour_name, "Flat & Warm")
	assert_eq(v.tons_balance, 120)
	assert_eq(v.scrub_index, 3)
