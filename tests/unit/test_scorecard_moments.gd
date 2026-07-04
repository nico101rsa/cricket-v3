extends GutTest

# T10 scorecard moments (spec 2026-07-04 DSC2/3/7/8/9): moment_at triggers +
# build_scorecard. Uses a real MatchSession so every trigger sits on real data.

func _mk() -> MatchSession:
	var a := Attributes.new()
	a.power = 55.0; a.composure = 45.0; a.attack = 35.0; a.control = 30.0
	var career := CareerResolver.start_career(0)
	var team: Team = career.teams[career.current_team_index]
	var opp: Team = career.opponents_of_current()[0]
	var tour := DifficultyLadder.spec_for(career.current_level(), 0).make_tour()
	return MatchSession.start(a, team, opp, tour, 20260615, 1)

func _first_cursor(ev: Array, innings: int, pred: Callable) -> int:
	for i in range(ev.size()):
		var e: Dictionary = ev[i]
		if e["type"] != "ball" and e["type"] != "over":
			continue
		if e["innings"] != innings:
			continue
		if pred.call(e):
			return i + 1
	return -1

func test_you_bat_fires_at_first_player_batting_event():
	var s := _mk()
	var ev := s.events()
	var found := false
	for innings in [1, 2]:
		var c := _first_cursor(ev, innings, func(e): return e["type"] == "ball" and e.get("player_batting", false))
		if c == -1:
			continue
		found = true
		var m := MatchViewBuilder.moment_at(s.result(), s.player(), c)
		assert_eq(m.get("kind", ""), "you_bat", "you_bat fires at the Player's first batting ball (innings %d)" % innings)
		assert_ne(m.get("title", ""), "", "strip title present")
	assert_true(found, "the Player batted somewhere in this match")

func test_you_bowl_fires_at_first_player_bowling_event():
	var s := _mk()
	var ev := s.events()
	for innings in [1, 2]:
		var c := _first_cursor(ev, innings, func(e): return e["type"] == "ball" and e.get("player_bowling", false))
		if c == -1:
			continue
		var m := MatchViewBuilder.moment_at(s.result(), s.player(), c)
		assert_eq(m.get("kind", ""), "you_bowl", "you_bowl fires at the Player's first bowling ball (innings %d)" % innings)

func test_powerplay_fires_only_at_innings1_start_when_not_a_player_ball():
	var s := _mk()
	var ev := s.events()
	var e0: Dictionary = ev[0]
	var m1 := MatchViewBuilder.moment_at(s.result(), s.player(), 1)
	if e0["type"] == "ball" and (e0.get("player_batting", false) or e0.get("player_bowling", false)):
		assert_true(m1["kind"] in ["you_bat", "you_bowl"], "player involvement outranks powerplay (DSC2)")
	else:
		assert_eq(m1.get("kind", ""), "powerplay", "powerplay fires at cursor 1")
	# never in innings 2 (DSC3)
	for i in range(ev.size()):
		var m := MatchViewBuilder.moment_at(s.result(), s.player(), i + 1)
		if m.get("kind", "") == "powerplay":
			assert_eq(ev[i]["innings"], 1, "powerplay strip is innings-1 only")

func test_death_fires_at_first_over16_event_per_innings():
	var s := _mk()
	var ev := s.events()
	for innings in [1, 2]:
		var c := _first_cursor(ev, innings, func(e): return e.get("over", 0) >= 16)
		if c == -1:
			continue
		var m := MatchViewBuilder.moment_at(s.result(), s.player(), c)
		# a same-cursor player-involvement collision legitimately outranks death (DSC2)
		if m.get("kind", "") in ["you_bat", "you_bowl"]:
			continue
		assert_eq(m.get("kind", ""), "death", "death strip at over 16 (innings %d)" % innings)

func test_scorecard_rows_reconcile_with_the_innings():
	var s := _mk()
	var mr := s.result()
	var card := MatchViewBuilder.build_scorecard(mr, s.player(), "Karoo Kings", 0, "Riverside")
	var run_sum := 0
	var outs := 0
	var player_rows := 0
	for r in card["rows"]:
		run_sum += r["runs"]
		if r["out"]:
			outs += 1
		if r["is_player"]:
			player_rows += 1
	assert_eq(run_sum, mr.innings1.total, "row runs sum to the innings total")
	assert_eq(outs, mr.innings1.wickets, "out rows match the wicket count")
	assert_eq(player_rows, 1 if mr.player_bats_first else 0, "YOU row iff the Player's team batted first")
	assert_string_contains(card["header"], "%d/%d" % [mr.innings1.total, mr.innings1.wickets])

func test_scorecard_dismissals_match_drs_flavours():
	var s := _mk()
	var mr := s.result()
	var card := MatchViewBuilder.build_scorecard(mr, s.player(), "Karoo Kings", 0, "Riverside")
	var how_by_pos := {}
	for r in card["rows"]:
		if r["out"]:
			how_by_pos[r["pos"]] = r["how"]
	for f in mr.innings1.fall_of_wickets:
		var ballno: int = f["ball"]
		var over := ((ballno - 1) / 6) + 1
		var bio := ((ballno - 1) % 6) + 1
		var expect := MatchViewBuilder._how_str(DRSMoments.flavour_of(mr.player_bats_first, over, bio))
		assert_eq(how_by_pos.get(f["batter"], ""), expect,
			"scorecard dismissal agrees with the T8 flavour hash (pos %d)" % f["batter"])

func test_scorecard_dnb_and_not_out_rows():
	var s := _mk()
	var mr := s.result()
	var card := MatchViewBuilder.build_scorecard(mr, s.player(), "Karoo Kings", 0, "Riverside")
	var came_in: int = mini(mr.innings1.wickets + 2, 11)
	assert_eq(card["rows"].size(), came_in, "rows = everyone who came to the crease, in order")
	for r in card["rows"]:
		if not r["out"]:
			assert_eq(r["how"], "not out", "in but not dismissed reads not out")
	if came_in < 11:
		assert_ne(card["dnb"], "", "DNB line lists the rest")

func test_scorecard_commentary_carries_real_numbers():
	var s := _mk()
	var mr := s.result()
	var card := MatchViewBuilder.build_scorecard(mr, s.player(), "Karoo Kings", 0, "Riverside")
	var req := (mr.innings1.total + 1) * 6.0 / 120.0
	assert_string_contains(card["commentary"], str(mr.innings1.total), "total quoted")
	assert_string_contains(card["commentary"], "%.1f an over" % req, "required rate quoted (DSC9)")
	assert_false("par" in card["commentary"].to_lower(), "no par judgement (DSC9)")

func test_each_kind_fires_at_most_once_per_innings_and_non_ball_events_are_empty():
	var s := _mk()
	var ev := s.events()
	var counts := {}
	for i in range(ev.size()):
		var m := MatchViewBuilder.moment_at(s.result(), s.player(), i + 1)
		var t: String = ev[i]["type"]
		if t == "innings_break" or t == "result":
			assert_true(m.is_empty(), "no strip on %s events" % t)
		if m.is_empty():
			continue
		var key := "%s|%d" % [m["kind"], ev[i]["innings"]]
		counts[key] = counts.get(key, 0) + 1
	for key in counts:
		assert_eq(counts[key], 1, "%s fires exactly once" % key)

func test_chase_backdrop_at_break_cursor_is_unstarted():
	# Regression: at cursor = innings_break + 1 the rich view must show the chase
	# at 0/0 (0.0 OV), not the walked-to-the-end second innings (result spoiler
	# behind the T10 break overlay).
	var s := _mk()
	var ev := s.events()
	var bi := -1
	for i in range(ev.size()):
		if ev[i]["type"] == "innings_break":
			bi = i
			break
	assert_gt(bi, -1, "innings break exists")
	var v := MatchViewBuilder.build_rich(s.result(), s.player(), bi + 1, "Karoo Kings", "Riverside")
	assert_eq(v.score_big, "0/0", "chase not started at the break")
	assert_true(v.score_meta.begins_with("0.0 OV"), "no overs bowled yet in the chase")
