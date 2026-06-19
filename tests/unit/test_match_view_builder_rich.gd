extends GutTest

# build_rich() — the v4 in-match read-model. Numbers are real (from the ball log);
# names are flavour (PlayerNames). Locks the contract the hi-fi scene renders.

func _session() -> MatchSession:
	var a := Attributes.new()
	a.power = 55.0; a.composure = 45.0; a.attack = 35.0; a.control = 30.0
	var career := CareerResolver.start_career(0)
	var team: Team = career.teams[career.current_team_index]
	var opp: Team = career.opponents_of_current()[0]
	var tour := DifficultyLadder.spec_for(career.current_level(), 0).make_tour()
	return MatchSession.start(a, team, opp, tour, 20260615, 1)

# A cursor in the middle of the first innings (a player batting ball, over >= 8).
func _mid_cursor(s: MatchSession) -> int:
	var ev := s.events()
	for c in range(ev.size()):
		var e: Dictionary = ev[c]
		if e["type"] == "ball" and e.get("innings", 1) == 1 and e.get("over", 0) >= 8:
			return c + 1
	return mini(20, ev.size())

func test_mid_innings_has_two_batters_with_real_balls():
	var s := _session()
	var c := _mid_cursor(s)
	var v := MatchViewBuilder.build_rich(s.result(), s.player(), c, "Karoo Kings", "Dusty Plains")
	assert_false(v.striker.is_empty(), "a striker is at the crease")
	assert_false(v.nonstriker.is_empty(), "a non-striker is at the crease")
	assert_true(v.striker["on_strike"], "the striker chip is flagged on-strike")
	assert_gt(int(v.striker["balls"]) + int(v.nonstriker["balls"]), 0, "real balls faced")

func test_score_and_runrate_are_real():
	var s := _session()
	var c := _mid_cursor(s)
	var v := MatchViewBuilder.build_rich(s.result(), s.player(), c, "Karoo Kings", "Dusty Plains")
	assert_string_contains(v.score_big, "/", "score reads runs/wickets")
	assert_ne(v.crr, "", "a current run rate is set")
	assert_eq(v.this_over.size(), 6, "the over grid is always six cells")

func test_player_slot_reads_YOU_others_are_flavour():
	var s := _session()
	var c := _mid_cursor(s)
	var v := MatchViewBuilder.build_rich(s.result(), s.player(), c, "Karoo Kings", "Dusty Plains")
	# Exactly one of the two chips is the player ("YOU"); the other is a flavour name.
	var names := [v.striker.get("name", ""), v.nonstriker.get("name", "")]
	assert_true("YOU" in names, "the player's own chip reads YOU")
	for nm in names:
		assert_ne(nm, "", "no blank batter name")

func test_finished_view_has_both_innings_lines():
	var s := _session()
	var v := MatchViewBuilder.build_rich(s.result(), s.player(), s.events().size(), "Karoo Kings", "Dusty Plains")
	assert_true(v.finished, "cursor at the end is finished")
	assert_eq(v.innings_lines.size(), 2, "both innings summarised on the result")
	assert_eq(v.won, s.result().player_won(), "won flag matches the result")
	assert_eq(v.innings_tag, "RESULT", "result tag set")
