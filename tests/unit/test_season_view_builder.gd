extends GutTest

# SeasonViewBuilder — pure builder of the hub read-model
# (spec 2026-06-15-season-hub-replay §3, §6).

func _player() -> Player:
	var p := Player.new()
	var n := NamePair.new()
	n.first_name = "Bongani"; n.surname = "Kgosi"
	p.name = n
	p.city = "Durban"
	p.country = Country.Code.SA
	p.tons_balance = 120
	p.affinity = 3
	var a := Attributes.new()
	a.power = 40.0; a.composure = 30.0; a.attack = 20.0; a.control = 10.0
	p.attributes = a
	return p

func _career() -> CareerState:
	# A real fresh career; player team = current_team_index, opponents = the rest.
	return CareerResolver.start_career(0)

func test_form_carries_raw_points_to_the_view() -> void:
	# T6: the hub bands raw form points, so the view carries the float, not the
	# rounded int (-0.75 used to arrive as -1 and wear the TIRED face).
	var p := _player()
	p.set_form_points(-0.75)
	var v := SeasonViewBuilder.build(p, _career(), _empty_season(), 0)
	assert_almost_eq(v.form, -0.75, 0.0001, "view.form is the raw points")

func _empty_season() -> SeasonResult:
	var sr := SeasonResult.new()
	var lr := LeagueResult.new()
	lr.standings = []
	lr.player_matches = []
	sr.league = lr
	return sr

func _match(player_first: bool, won: bool) -> MatchResult:
	var m := MatchResult.new()
	m.player_bats_first = player_first
	var bat := InningsResult.new(150, 5, 120, [], [
		{"position": 3, "is_player": true, "runs": 40, "balls": 28, "out": true}])
	var bowl := InningsResult.new(140, 8, 120, [], [], 2, 26, 24)  # player 2/26 in 24 balls
	if player_first:
		m.innings1 = bat; m.innings2 = bowl
	else:
		m.innings1 = bowl; m.innings2 = bat
	# Outcome is a nested enum on MatchResult: { PLAYER_WIN, OPPONENT_WIN, TIE }.
	m.outcome = MatchResult.Outcome.PLAYER_WIN if won else MatchResult.Outcome.OPPONENT_WIN
	return m

func _season_with(n_matches: int) -> SeasonResult:
	var sr := SeasonResult.new()
	var lr := LeagueResult.new()
	var pms: Array = []
	for i in range(n_matches):
		pms.append(_match(i % 2 == 0, i % 3 != 0))
	lr.player_matches = pms
	lr.standings = []
	sr.league = lr
	return sr

func _row(team_index: int, played: int, points: int, rf: int, bf: int, ra: int, ba: int) -> StandingsRow:
	var r := StandingsRow.new()
	r.team_index = team_index; r.played = played; r.points = points
	r.runs_for = rf; r.balls_for = bf; r.runs_against = ra; r.balls_against = ba
	return r

# --- Context / snapshot (Task 2) ---

func test_context_and_snapshot() -> void:
	var p := _player()
	var cs := _career()
	var v := SeasonViewBuilder.build(p, cs, _empty_season(), 0)
	assert_eq(v.player_name, p.name.display_caps(), "name from Player")
	assert_eq(v.city, "Durban")
	assert_eq(v.country, Country.Code.SA)
	assert_eq(v.tons_balance, 120, "tons passthrough")
	assert_eq(v.affinity, 3, "affinity passthrough")
	assert_almost_eq(v.power, 40.0, 0.001)
	assert_eq(v.team_name, cs.teams[cs.current_team_index].team_name)
	assert_false(v.tour_name.is_empty(), "tour name from DifficultyLadder")

func test_ovr_is_attribute_mean_rounded() -> void:
	var v := SeasonViewBuilder.build(_player(), _career(), _empty_season(), 0)
	# (40 + 30 + 20 + 10) / 4 = 25
	assert_eq(v.ovr, 25, "OVR = rounded mean of the four attributes")

# --- Fixtures chain (Task 3) ---

func test_fixtures_chain_length_and_played_flag() -> void:
	var v := SeasonViewBuilder.build(_player(), _career(), _season_with(7), 3)
	assert_eq(v.fixtures.size(), 7, "7 league fixtures")
	assert_true(v.fixtures[2]["played"], "match 3 (index 2) is before the scrub head")
	assert_false(v.fixtures[3]["played"], "match 4 (index 3) is pending at scrub_index 3")
	assert_false(v.fixtures[0]["opponent_name"].is_empty(), "opponent named")

func test_played_fixture_carries_result_text() -> void:
	var v := SeasonViewBuilder.build(_player(), _career(), _season_with(7), 7)
	for f in v.fixtures:
		assert_true(f["played"], "all played at scrub_index 7")
		assert_false(f["score_text"].is_empty(), "played fixture shows a score line")

# --- Final standings (Task 4) ---

func test_standings_mapped_with_name_and_nrr_and_player_flag() -> void:
	var cs := _career()
	var sr := _season_with(0)
	sr.league.standings = [
		_row(0, 7, 10, 1200, 840, 1100, 840),  # player team (index 0)
		_row(1, 7, 8, 1100, 840, 1150, 840),
	]
	sr.league.player_position = 1
	sr.player_final_position = 1
	var v := SeasonViewBuilder.build(_player(), cs, sr, 7)
	assert_eq(v.standings.size(), 2)
	assert_eq(v.standings[0]["team_name"], cs.teams[0].team_name, "name resolved from team_index")
	assert_true(v.standings[0]["is_player"], "team_index 0 is the Player")
	assert_eq(v.player_final_position, 1)
	# NRR for row 0: 1200/140 - 1100/140 = 8.571 - 7.857 = 0.714
	assert_almost_eq(v.standings[0]["nrr"], 0.714, 0.01)

# --- Career card fold (Task 5) ---

func test_card_empty_at_scrub_zero() -> void:
	var v := SeasonViewBuilder.build(_player(), _career(), _season_with(7), 0)
	assert_eq(v.card_matches, 0)
	assert_eq(v.card_runs, 0)
	assert_eq(v.card_best_bowling, "—", "no figures yet — sentinel, not 0/0")

func test_card_folds_batting_and_bowling() -> void:
	# 3 matches scrubbed: each bat 40 off 28 (out), bowl 2/26 off 24.
	var v := SeasonViewBuilder.build(_player(), _career(), _season_with(7), 3)
	assert_eq(v.card_matches, 3)
	assert_eq(v.card_runs, 120, "3 x 40")
	assert_eq(v.card_balls_faced, 84, "3 x 28")
	assert_eq(v.card_dismissals, 3, "out each time")
	assert_eq(v.card_high_score, 40)
	assert_almost_eq(v.card_batting_avg, 40.0, 0.01, "120 / 3")
	assert_almost_eq(v.card_strike_rate, 142.857, 0.01, "100 * 120 / 84")
	assert_eq(v.card_wickets, 6, "3 x 2")
	assert_eq(v.card_runs_conceded, 78, "3 x 26")
	assert_eq(v.card_balls_bowled, 72, "3 x 24")
	assert_almost_eq(v.card_economy, 6.5, 0.01, "78 / (72/6)")
	assert_eq(v.card_best_bowling, "2/26", "best (most wickets, fewest runs)")

# --- Jokers (Task 6) ---

func test_jokers_empty_when_no_carryover() -> void:
	var cs := _career()
	cs.carryover_joker_id = ""
	var v := SeasonViewBuilder.build(_player(), cs, _season_with(0), 0)
	assert_eq(v.jokers.size(), 0, "fresh career, no carry-over")

func test_carryover_joker_resolves_name_and_rarity() -> void:
	var cs := _career()
	var groups := JokerCatalog.implemented_groups()
	var first_id: String = groups[0]["id"]
	cs.carryover_joker_id = first_id
	var v := SeasonViewBuilder.build(_player(), cs, _season_with(0), 0)
	assert_eq(v.jokers.size(), 1)
	assert_eq(v.jokers[0]["id"], first_id)
	assert_eq(v.jokers[0]["name"], groups[0]["jname"])
	assert_eq(v.jokers[0]["rarity"], groups[0]["rarity"])
