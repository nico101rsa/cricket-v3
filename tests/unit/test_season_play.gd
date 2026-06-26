extends GutTest

# SeasonPlay — the live LEAGUE-phase driver for the forward-play Season Hub
# (spec 2026-06-16-live-league-loop). Pure: no scene tree, no SaveManager.

func _opps() -> Array:
	var out: Array = []
	for k in range(7):
		var t := Team.new()
		t.team_name = "Opp %d" % (k + 1)
		t.stars = 2.5
		out.append(t)
	return out

func _player_team() -> Team:
	var t := Team.new()
	t.team_name = "My XI"
	t.stars = 2.5
	return t

func _tour() -> TourDistribution:
	return TourDistribution.new()

func _start() -> SeasonPlay:
	return SeasonPlay.start(Attributes.new(), _player_team(), _opps(),
		_tour(), BallTuning.new(), InningsTuning.new(), 20260616)

# --- Task 1: construction + schedule ---

func test_start_schedules_seven_player_fixtures() -> void:
	var sp := _start()
	assert_eq(sp.total_player_fixtures(), 7, "7 league fixtures")
	assert_eq(sp.played_count(), 0, "none played at start")
	assert_false(sp.league_done(), "league not done at start")

func test_next_player_opponent_is_first_opponent() -> void:
	var sp := _start()
	var nxt := sp.next_player_opponent()
	assert_eq(nxt["name"], "Opp 1", "fixtures run in opponents order")
	assert_eq(nxt["team_index"], 1, "team_index 1 = first opponent")

# --- Task 2: AI resolution + running standings ---

func test_standings_has_eight_rows_and_is_sorted() -> void:
	var sp := _start()
	var lg := sp.live_league()
	assert_eq(lg.standings.size(), 8, "all 8 teams in the table")
	for i in range(lg.standings.size() - 1):
		assert_true(lg.standings[i].points >= lg.standings[i + 1].points,
			"standings sorted by points desc")

func test_no_ai_revealed_before_first_game() -> void:
	var sp := _start()
	var lg := sp.live_league()
	var total_played := 0
	for r in lg.standings:
		total_played += r.played
	assert_eq(total_played, 0, "nothing revealed before you play")

# --- Task 3: make_session + commit + determinism ---

func test_make_session_then_commit_advances() -> void:
	var sp := _start()
	var sess := sp.make_session()
	assert_not_null(sess, "a MatchSession for the next fixture")
	sp.commit_player_result(sess.result())
	assert_eq(sp.played_count(), 1, "one player game played")
	assert_eq(sp.next_player_opponent()["name"], "Opp 2", "advanced to opponent 2")

func test_full_league_finishes() -> void:
	var sp := _start()
	for k in range(7):
		sp.commit_player_result(sp.make_session().result())
	assert_true(sp.league_done(), "league done after 7 games")
	assert_ne(sp.phase(), "league", "moved past the league phase (into playoffs or done)")
	assert_eq(sp.live_league().standings.size(), 8, "final table intact")

func test_determinism_same_seed_same_table() -> void:
	var a := _start()
	var b := _start()
	for k in range(3):
		a.commit_player_result(a.make_session().result())
		b.commit_player_result(b.make_session().result())
	var ta := a.live_league().standings
	var tb := b.live_league().standings
	for i in range(8):
		assert_eq(ta[i].team_index, tb[i].team_index, "row %d team matches" % i)
		assert_eq(ta[i].points, tb[i].points, "row %d points match" % i)

func test_revealed_ai_grows_with_play() -> void:
	var sp := _start()
	sp.commit_player_result(sp.make_session().result())
	var total_played := 0
	for r in sp.live_league().standings:
		total_played += r.played
	# After 1 game: 3 AI fixtures (6 team-appearances) + your 1 game (2) = 8.
	assert_eq(total_played, 8, "3 AI + 1 player game revealed after game 1")

# --- Interactive opponent-brain floor (2026-06-18) ---
# The marquee 1-v-1 opponent always plays at least competent textbook cricket: the
# sub-textbook naive blend (a league-realism device) just hands a random, easily-beaten
# opponent and inflated the underdog's win-rate. Difficulty still SCALES above textbook.

func test_interactive_opponent_floored_to_textbook() -> void:
	var weak := TourSpec.new()
	weak.brain_tier = TourSpec.Tier.TEXTBOOK
	weak.blend = 0.4   # the actual Club entry tour: 60% random plays
	var f := SeasonPlay._floored_spec(weak)
	assert_eq(f.brain_tier, TourSpec.Tier.TEXTBOOK, "stays textbook")
	assert_eq(f.blend, 1.0, "naive blend removed -> full textbook (opponent never plays randomly)")

func test_interactive_opponent_keeps_higher_tier_scaling() -> void:
	var hard := TourSpec.new()
	hard.brain_tier = TourSpec.Tier.ADAPTIVE
	hard.blend = 0.5
	var f := SeasonPlay._floored_spec(hard)
	assert_eq(f.brain_tier, TourSpec.Tier.ADAPTIVE, "tier above textbook preserved (difficulty scales)")
	assert_eq(f.blend, 0.5, "blend above textbook preserved")

func test_floored_spec_passes_through_null() -> void:
	assert_null(SeasonPlay._floored_spec(null), "no spec -> no brain (unchanged)")

# --- Slice 1: live playoffs (spec 2026-06-22-live-season-loop-finish) ---
# Strong player (4.5★ team vs 1.5★ opponents) makes top-4 and plays knockouts;
# weak player (1.5★ vs 4.5★) misses the cut and the bracket auto-resolves.

func _team(name: String, stars: float) -> Team:
	var t := Team.new()
	t.team_name = name
	t.stars = stars
	return t

func _opps_at(stars: float) -> Array:
	var out: Array = []
	for k in range(7):
		out.append(_team("Opp %d" % (k + 1), stars))
	return out

func _start_strong() -> SeasonPlay:
	return SeasonPlay.start(Attributes.new(), _team("My XI", 4.5), _opps_at(1.5),
		_tour(), BallTuning.new(), InningsTuning.new(), 20260616)

func _start_weak() -> SeasonPlay:
	return SeasonPlay.start(Attributes.new(), _team("My XI", 1.5), _opps_at(4.5),
		_tour(), BallTuning.new(), InningsTuning.new(), 20260616)

func _play_league(sp: SeasonPlay) -> void:
	for k in range(7):
		sp.commit_player_result(sp.make_session().result())

func _play_player_knockouts(sp: SeasonPlay) -> void:
	while not sp.season_done() and not sp.next_player_opponent().is_empty():
		sp.commit_player_result(sp.make_session().result())

func test_league_phase_at_start() -> void:
	assert_eq(_start().phase(), "league", "starts in the league phase")

func test_strong_player_enters_playoffs_with_semi() -> void:
	var sp := _start_strong()
	_play_league(sp)
	assert_true(sp.league_done(), "league done after 7")
	assert_true(sp.live_league().made_playoffs, "strong player should make top-4")
	assert_eq(sp.phase(), "playoffs", "enters playoffs")
	var nxt := sp.next_player_opponent()
	assert_eq(nxt.get("stage", ""), "semi", "first knockout is the semi-final")
	assert_true(nxt.has("team_index"), "names a bracket opponent")

func test_semi_advances_to_final_or_third() -> void:
	var sp := _start_strong()
	_play_league(sp)
	assert_true(sp.live_league().made_playoffs, "precondition: in playoffs")
	var r := sp.make_session().result()
	sp.commit_player_result(r)
	var won := r.outcome == MatchResult.Outcome.PLAYER_WIN
	var stage: String = sp.next_player_opponent().get("stage", "")
	assert_eq(stage, "final" if won else "third",
		"won SF -> Final, lost SF -> 3rd-place playoff")

func test_strong_player_completes_season() -> void:
	var sp := _start_strong()
	_play_league(sp)
	_play_player_knockouts(sp)
	assert_true(sp.season_done(), "season done after both player knockouts")
	assert_eq(sp.phase(), "done", "phase is done")
	assert_eq(sp.next_player_opponent(), {}, "nothing left to play")

func test_weak_player_auto_resolves_after_league() -> void:
	var sp := _start_weak()
	_play_league(sp)
	assert_true(sp.league_done(), "league done")
	assert_false(sp.live_league().made_playoffs, "weak player misses top-4")
	assert_true(sp.season_done(), "bracket auto-resolves immediately")
	assert_eq(sp.phase(), "done", "straight to done")
	assert_eq(sp.next_player_opponent(), {}, "no playoff to play")
	var pos := sp.season_result().player_final_position
	assert_true(pos >= 5 and pos <= 8, "finished 5th-8th, got %d" % pos)

func test_season_result_is_complete() -> void:
	var sp := _start_strong()
	_play_league(sp)
	_play_player_knockouts(sp)
	var sr := sp.season_result()
	assert_not_null(sr.semi1, "semi1 present")
	assert_not_null(sr.semi2, "semi2 present")
	assert_not_null(sr.final_match, "final present")
	assert_not_null(sr.third_place, "third-place present")
	assert_eq(sr.final_order.size(), 8, "8 finishing positions")
	var seen := {}
	for x in sr.final_order:
		seen[x] = true
	assert_eq(seen.size(), 8, "all 8 teams distinct in the order")
	var pos := sr.player_final_position
	assert_true(pos >= 1 and pos <= 8, "player placed 1-8")
	assert_eq(sr.beat, pos <= 3, "beat == top-3 finish")
	assert_eq(sr.won_final, pos == 1, "won_final == 1st")

func test_playoff_determinism() -> void:
	var a := _start_strong()
	var b := _start_strong()
	_play_league(a); _play_player_knockouts(a)
	_play_league(b); _play_player_knockouts(b)
	assert_eq(a.season_result().final_order, b.season_result().final_order,
		"same seed + same (no-decision) play -> same finishing order")

# --- Slice 3: ₸ pay banking on the live path ---
# Mirrors CareerResolver._settle_matches: each played match banks match_pay +
# match_win_prize (on a win); season_prizes added once at season end. Disabled
# until enable_pay() is called -> byte-identical to the pre-pay live path.

func test_pay_disabled_by_default() -> void:
	var sp := _start_strong()
	_play_league(sp)
	assert_eq(sp.pay_so_far(), 0, "no pay tracked unless enable_pay() is called")

func test_pay_banks_into_player_balance() -> void:
	var sp := _start_strong()
	var p := Player.new()
	sp.enable_pay(p, EconomyTuning.new(), 4.5, 0, 0)
	_play_league(sp)
	assert_gt(sp.pay_so_far(), 0, "league pay accrued")
	assert_eq(p.tons_balance, sp.pay_so_far(), "player balance == pay tally")

func test_season_prizes_added_on_finish() -> void:
	var sp := _start_strong()
	var p := Player.new()
	sp.enable_pay(p, EconomyTuning.new(), 4.5, 0, 0)
	_play_league(sp)
	var after_league := sp.pay_so_far()
	_play_player_knockouts(sp)
	assert_true(sp.season_done(), "season done")
	assert_gt(sp.pay_so_far(), after_league, "playoff pay + season prizes added at the end")
	assert_eq(p.tons_balance, sp.pay_so_far(), "balance stays in sync through the playoffs")

func test_season_wins_counted() -> void:
	var sp := _start_strong()
	sp.enable_pay(Player.new(), EconomyTuning.new(), 4.5, 0, 0)
	_play_league(sp)
	_play_player_knockouts(sp)
	assert_gt(sp.season_wins(), 0, "a strong player wins games")

func test_weak_player_still_banks_league_pay() -> void:
	var sp := _start_weak()
	var p := Player.new()
	sp.enable_pay(p, EconomyTuning.new(), 1.5, 0, 0)
	_play_league(sp)
	assert_true(sp.season_done(), "auto-resolved (out of top-4)")
	assert_gt(sp.pay_so_far(), 0, "still earns the game fee + performance pay")
	assert_eq(p.tons_balance, sp.pay_so_far(), "balance in sync")

# --- Slice 4: replay-from-decisions (cross-session save, spec 2026-06-23) ---
# The whole season is reproducible from the seed + the per-match player decisions.
# decisions_log() records one entry per committed player match; replay() rebuilds an
# identical SeasonPlay from that log (the determinism the save system relies on).

func _cell_inputs() -> Dictionary:
	var career := CareerResolver.start_career(0)
	var spec := DifficultyLadder.spec_for(career.current_level(), 0)
	var a := Attributes.new()
	a.power = 60.0; a.composure = 50.0; a.attack = 30.0; a.control = 25.0
	return {
		"attrs": a,
		"team": career.teams[career.current_team_index],
		"opps": career.opponents_of_current(),
		"tour": spec.make_tour(),
		"spec": spec,
		"level": career.current_level(),
	}

func _drive_with_decisions(sp: SeasonPlay) -> void:
	while not sp.season_done() and not sp.next_player_opponent().is_empty():
		var sess := sp.make_session()
		sess.decide_boost(1, 3)
		sess.decide_key_moment(7, BallResolver.Intent.AGGRESSIVE)
		sp.commit_player_result(sess.result(), sess.export_decisions())

func test_decisions_log_records_one_entry_per_player_match() -> void:
	var sp := _start()
	sp.commit_player_result(sp.make_session().result(), {"presses": [[1, 3]]})
	sp.commit_player_result(sp.make_session().result(), {"presses": [[1, 5]]})
	assert_eq(sp.decisions_log().size(), 2, "one decision entry per committed match")
	assert_eq(sp.decisions_log()[0]["presses"], [[1, 3]], "entries kept in commit order")

func test_seed_accessor_exposes_the_season_seed() -> void:
	assert_eq(_start().seed(), 20260616, "the season's base seed")

func test_restore_pay_tally_sets_running_totals() -> void:
	var sp := _start()
	sp.restore_pay_tally(517, 4)
	assert_eq(sp.pay_so_far(), 517, "pay tally restored")
	assert_eq(sp.season_wins(), 4, "win count restored")

func test_replay_from_decisions_reproduces_the_whole_season() -> void:
	var c := _cell_inputs()
	var seed := 20260616
	var sp := SeasonPlay.start(c["attrs"], c["team"], c["opps"], c["tour"],
		BallTuning.new(), InningsTuning.new(), seed, c["spec"])
	sp.enable_pay(Player.new(), EconomyTuning.new(), c["team"].stars, c["level"], 0)
	_drive_with_decisions(sp)
	assert_true(sp.season_done(), "the driven season finished")

	var sp2 := SeasonPlay.replay(c["attrs"], c["team"], c["opps"], c["tour"],
		BallTuning.new(), InningsTuning.new(), seed, c["spec"], sp.decisions_log())
	sp2.restore_pay_tally(sp.pay_so_far(), sp.season_wins())

	assert_eq(sp2.phase(), "done", "replay reaches the same phase")
	assert_eq(sp2.season_result().final_order, sp.season_result().final_order,
		"replay reconstructs the identical final order")
	assert_eq(sp2.season_result().player_final_position,
		sp.season_result().player_final_position, "and the same finishing position")
	assert_eq(sp2.pay_so_far(), sp.pay_so_far(), "and the same banked ₸")
	assert_eq(sp2.season_wins(), sp.season_wins(), "and the same win count")

func test_replay_without_decisions_matches_a_bare_season() -> void:
	# An empty-decisions drive replayed from its log == the same bare season.
	var c := _cell_inputs()
	var seed := 314159
	var sp := SeasonPlay.start(c["attrs"], c["team"], c["opps"], c["tour"],
		BallTuning.new(), InningsTuning.new(), seed, c["spec"])
	while not sp.season_done() and not sp.next_player_opponent().is_empty():
		sp.commit_player_result(sp.make_session().result(), {})
	var sp2 := SeasonPlay.replay(c["attrs"], c["team"], c["opps"], c["tour"],
		BallTuning.new(), InningsTuning.new(), seed, c["spec"], sp.decisions_log())
	assert_eq(sp2.season_result().final_order, sp.season_result().final_order,
		"a no-decision season replays identically too")

# Full cross-session resume through disk: drive a season with a real Player +
# CareerState, to_state -> SaveManager save -> load -> from_state, and prove the
# resumed driver is identical. This is the end-to-end "quit and relaunch" path.
const _SaveManagerScript = preload("res://scripts/services/save_manager.gd")

func test_full_disk_resume_reproduces_the_season() -> void:
	var career := CareerResolver.start_career(0)
	var spec := DifficultyLadder.spec_for(career.current_level(), 0)
	var team: Team = career.teams[career.current_team_index]
	var player := Player.new()
	player.attributes = Attributes.new()
	player.attributes.power = 60.0; player.attributes.composure = 50.0
	player.attributes.attack = 30.0; player.attributes.control = 25.0
	var seed := 20260616

	var sp := SeasonPlay.start(player.attributes, team, career.opponents_of_current(),
		spec.make_tour(), BallTuning.new(), InningsTuning.new(), seed, spec)
	sp.enable_pay(player, EconomyTuning.new(), team.stars, career.current_level(), 0)
	_drive_with_decisions(sp)
	assert_true(sp.season_done(), "driven season finished")

	# Persist the in-progress state to disk and read it back fresh.
	var sm = _SaveManagerScript.new()
	sm.live_season_save_path = "user://_test_resume_live_season.tres"
	sm.clear_live_season()
	sm.save_live_season(sp.to_state(career.current_level(), 0))
	var state = sm.load_live_season()
	assert_not_null(state, "state read back from disk")

	# Resume against the same Player + CareerState (which are persisted separately).
	var resumed := SeasonPlay.from_state(state, player, career)
	assert_eq(resumed.season_result().final_order, sp.season_result().final_order,
		"a disk round-trip resumes the identical season")
	assert_eq(resumed.pay_so_far(), sp.pay_so_far(), "and the same banked ₸")
	assert_eq(resumed.season_wins(), sp.season_wins(), "and the same win count")

	sm.clear_live_season()
	sm.free()


# --- Player jokers reach the live driver's matches (spec 2026-06-26, Rung 1) ---

func _season_at(seed: int) -> SeasonPlay:
	# A modest player vs the Club opponents — weak enough that early wickets fall, so a
	# powerplay survival joker (block_the_shine) actually bites (a 4.5★ team never loses
	# early wickets, leaving the wicket-mult inert).
	var a := Attributes.new()
	a.power = 55.0; a.composure = 45.0; a.attack = 35.0; a.control = 30.0
	var career := CareerResolver.start_career(0)
	return SeasonPlay.start(a, career.teams[career.current_team_index],
		career.opponents_of_current(),
		DifficultyLadder.spec_for(0, 0).make_tour(), BallTuning.new(), InningsTuning.new(), seed)

func _player_innings_runs(sp: SeasonPlay) -> int:
	var r := sp.make_session().result()
	return r.innings1.total if r.player_bats_first else r.innings2.total

func test_set_player_jokers_lifts_league_batting_total() -> void:
	var effects := JokerCatalog.effects_of_ids(["block_the_shine"])
	var sum_base := 0
	var sum_joker := 0
	for s in range(8):
		var base := _season_at(3300 + s)
		var jk := _season_at(3300 + s)
		jk.set_player_jokers(effects)
		for i in range(7):
			sum_base += _player_innings_runs(base)
			base.commit_player_result(base.make_session().result())
		for i in range(7):
			sum_joker += _player_innings_runs(jk)
			jk.commit_player_result(jk.make_session().result())
	assert_gt(sum_joker, sum_base, "owned joker fires across the live league fixtures")
