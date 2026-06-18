extends GutTest

# MatchViewBuilder.build_events — folds two raw ball-logs into one player-centric
# playback list (player balls individual, others collapsed per over). Spec §4.

func _player() -> Player:
	var p := Player.new()
	var n := NamePair.new(); n.first_name = "Bongani"; n.surname = "Kgosi"
	p.name = n
	return p

# Build a hand-made innings log: `specs` is an array of dicts with the keys the
# sim records. Helper keeps tests readable.
func _ball(over: int, bio: int, is_player: bool, p_bat: bool, p_bowl: bool,
		runs: int, wicket: bool, boost: bool, total: int, wkts: int) -> Dictionary:
	return {"over": over, "ball_in_over": bio, "striker_pos": 3, "is_player": is_player,
		"player_batting": p_bat, "player_bowling": p_bowl, "intent": 0,
		"boost_pressed": boost, "wicket": wicket, "runs": runs, "total": total, "wickets": wkts}

func _match_with_logs(log1: Array, log2: Array, player_first: bool) -> MatchResult:
	var m := MatchResult.new()
	m.player_bats_first = player_first
	m.innings1 = InningsResult.new(log1[-1]["total"], log1[-1]["wickets"], log1.size(), [], [])
	m.innings2 = InningsResult.new(log2[-1]["total"], log2[-1]["wickets"], log2.size(), [], [])
	m.outcome = MatchResult.Outcome.PLAYER_WIN
	m.margin_wickets = 5; m.balls_remaining = 6
	m.ball_log_innings1 = log1
	m.ball_log_innings2 = log2
	return m

func test_player_balls_individual_others_collapsed() -> void:
	# Innings 1 (player batting): over 1 — player faces balls 1,2 (non-striker faces 3),
	# Innings 2 (player bowling over 1): all 3 balls are the player bowling.
	var log1 := [
		_ball(1, 1, true,  true, false, 4, false, true,  4, 0),
		_ball(1, 2, true,  true, false, 1, false, false, 5, 0),
		_ball(1, 3, false, true, false, 0, false, false, 5, 0)]  # non-striker, non-player
	var log2 := [
		_ball(1, 1, false, false, true, 1, false, false, 1, 0),
		_ball(1, 2, false, false, true, 0, true,  false, 1, 1),
		_ball(1, 3, false, false, true, 2, false, false, 3, 1)]
	var m := _match_with_logs(log1, log2, true)
	var events := MatchViewBuilder.build_events(m, _player())
	var balls := events.filter(func(e): return e["type"] == "ball")
	# Player faced 2 + bowled 3 = 5 individual ball events.
	assert_eq(balls.size(), 5, "5 player-involved ball events")
	var overs := events.filter(func(e): return e["type"] == "over")
	assert_eq(overs.size(), 1, "one over-summary for the non-player ball")
	assert_eq(events.filter(func(e): return e["type"] == "innings_break").size(), 1, "one innings break")
	assert_eq(events[-1]["type"], "result", "stream ends with a result event")

func test_result_event_carries_outcome() -> void:
	var log1 := [_ball(1, 1, true, true, false, 4, false, false, 4, 0)]
	var log2 := [_ball(1, 1, false, false, true, 0, true, false, 0, 1)]
	var m := _match_with_logs(log1, log2, true)
	var events := MatchViewBuilder.build_events(m, _player())
	var res: Dictionary = events[-1]
	assert_true(res["player_won"], "result marks the player win")
	assert_string_contains(res["text"], "won by", "result text uses margin phrasing")

func test_result_event_names_the_winner_on_a_loss() -> void:
	# The confusing-result bug: a defending side read the neutral "won by 1 wickets" as
	# its own win. The result line now names who won.
	var log1 := [_ball(1, 1, true, true, false, 4, false, false, 4, 0)]
	var log2 := [_ball(1, 1, false, false, true, 0, true, false, 0, 1)]
	var m := _match_with_logs(log1, log2, true)
	m.outcome = MatchResult.Outcome.OPPONENT_WIN
	m.margin_wickets = 1; m.balls_remaining = 0
	var events := MatchViewBuilder.build_events(m, _player())
	var res: Dictionary = events[-1]
	assert_false(res["player_won"], "marked a loss")
	assert_string_contains(res["text"], "Opponent won", "result text names the opponent as winner")

func test_build_running_score_at_cursor() -> void:
	var log1 := [
		_ball(1, 1, true, true, false, 4, false, false, 4, 0),
		_ball(1, 2, true, true, false, 6, false, false, 10, 0),
		_ball(1, 3, true, true, false, 0, true,  false, 10, 1)]
	var log2 := [_ball(1, 1, false, false, true, 0, true, false, 0, 1)]
	var m := _match_with_logs(log1, log2, true)
	var view := MatchViewBuilder.build(m, _player(), 2)  # after 2 events (2 balls)
	assert_string_contains(view.batting_score, "10/0", "running score reflects 2 balls")
	assert_false(view.finished, "not finished mid-stream")
	assert_gt(view.event_count, 0, "event_count populated")

func test_build_at_end_is_finished_with_result() -> void:
	var log1 := [_ball(1, 1, true, true, false, 4, false, false, 4, 0)]
	var log2 := [_ball(1, 1, false, false, true, 0, true, false, 0, 1)]
	var m := _match_with_logs(log1, log2, true)
	var view := MatchViewBuilder.build(m, _player(), 99)  # past the end → clamps
	assert_true(view.finished, "finished at end of stream")
	assert_string_contains(view.result_text, "won by", "result text present")
	assert_true(view.player_won, "player_won set")

# -- Overs notation (cricket: completed-overs.balls; 6th ball ticks the over over) --

func test_overs_notation_completed_over_reads_dot_zero() -> void:
	# All 6 balls of over 1 -> "1.0" (over complete), NOT "1.6".
	var log1 := [
		_ball(1, 1, true, true, false, 1, false, false, 1, 0),
		_ball(1, 2, true, true, false, 1, false, false, 2, 0),
		_ball(1, 3, true, true, false, 1, false, false, 3, 0),
		_ball(1, 4, true, true, false, 1, false, false, 4, 0),
		_ball(1, 5, true, true, false, 1, false, false, 5, 0),
		_ball(1, 6, true, true, false, 1, false, false, 6, 0)]
	var log2 := [_ball(1, 1, false, false, true, 0, true, false, 0, 1)]
	var m := _match_with_logs(log1, log2, true)
	var view := MatchViewBuilder.build(m, _player(), 6)
	assert_string_contains(view.batting_score, "(1.0)", "6th ball of over 1 reads 1.0")
	assert_false("1.6" in view.batting_score, "never shows a .6")

func test_overs_notation_mid_over() -> void:
	var log1 := [
		_ball(1, 1, true, true, false, 1, false, false, 1, 0),
		_ball(1, 2, true, true, false, 1, false, false, 2, 0)]
	var log2 := [_ball(1, 1, false, false, true, 0, true, false, 0, 1)]
	var m := _match_with_logs(log1, log2, true)
	var view := MatchViewBuilder.build(m, _player(), 2)
	assert_string_contains(view.batting_score, "(0.2)", "2 balls into over 1 reads 0.2")

func test_feed_ball_line_uses_cricket_notation() -> void:
	var log1 := [
		_ball(1, 5, true, true, false, 1, false, false, 5, 0),
		_ball(1, 6, true, true, false, 4, false, false, 9, 0)]
	var log2 := [_ball(1, 1, false, false, true, 0, true, false, 0, 1)]
	var m := _match_with_logs(log1, log2, true)
	var view := MatchViewBuilder.build(m, _player(), 2)
	var joined := "\n".join(view.feed)
	assert_true("1.0  " in joined, "the over-completing ball reads 1.0 in the feed")
	assert_false("1.6" in joined, "the feed never shows a .6")

# -- Your-moment highlights (spec 2026-06-17) -------------------------------

# highlight_text of the build whose cursor sits just after the Nth ball event
# matching `pred`.
func _hl_after(m: MatchResult, pred: Callable) -> String:
	var events := MatchViewBuilder.build_events(m, _player())
	for i in range(events.size()):
		if pred.call(events[i]):
			return MatchViewBuilder.build(m, _player(), i + 1).highlight_text
	return "<no match>"

func test_highlight_four_and_six() -> void:
	var log1 := [_ball(1, 1, true, true, false, 4, false, false, 4, 0),
		_ball(1, 2, true, true, false, 6, false, false, 10, 0)]
	var log2 := [_ball(1, 1, false, false, true, 0, true, false, 0, 1)]
	var m := _match_with_logs(log1, log2, true)
	assert_eq(MatchViewBuilder.build(m, _player(), 1).highlight_text, "FOUR!", "a your-four flashes FOUR!")
	assert_eq(MatchViewBuilder.build(m, _player(), 2).highlight_text, "SIX!", "a your-six flashes SIX!")

func test_highlight_fifty_milestone_wins_over_boundary() -> void:
	var log1: Array = []
	var tot := 0
	for i in range(8):  # eight sixes = 48
		tot += 6
		log1.append(_ball(1, i + 1, true, true, false, 6, false, false, tot, 0))
	tot += 4  # a four brings up 52 (crosses 50)
	log1.append(_ball(2, 3, true, true, false, 4, false, false, tot, 0))
	var log2 := [_ball(1, 1, false, false, true, 0, true, false, 0, 1)]
	var m := _match_with_logs(log1, log2, true)
	var hl := MatchViewBuilder.build(m, _player(), 9).highlight_text
	assert_true(hl.begins_with("FIFTY!"), "the run-bringing-up-50 ball flashes FIFTY! (not FOUR!), got: %s" % hl)

func test_getting_out_is_highlighted() -> void:
	var log1 := [_ball(1, 1, true, true, false, 12, false, false, 12, 0),
		_ball(1, 2, true, true, false, 0, true, false, 12, 1)]
	var log2 := [_ball(1, 1, false, false, true, 0, true, false, 0, 1)]
	var m := _match_with_logs(log1, log2, true)
	assert_true(MatchViewBuilder.build(m, _player(), 2).highlight_text.begins_with("OUT!"), "your dismissal flashes OUT!")

func test_over_summary_event_has_no_highlight() -> void:
	# a teammate ball folds into an "over" summary — not a your-moment, no flash
	var log1 := [_ball(1, 1, false, false, false, 4, false, false, 4, 0),
		_ball(1, 2, true, true, false, 1, false, false, 5, 0)]
	var log2 := [_ball(1, 1, false, false, true, 0, true, false, 0, 1)]
	var m := _match_with_logs(log1, log2, true)
	var hl := _hl_after(m, func(e): return e["type"] == "over")
	assert_eq(hl, "", "an over-summary (teammate balls) does not flash")

func test_bowling_three_and_five_for() -> void:
	var log1 := [_ball(1, 1, true, true, false, 4, false, false, 4, 0)]
	var log2: Array = []
	for i in range(5):  # five player-bowled wickets
		log2.append(_ball(i + 1, 1, false, false, true, 0, true, false, 0, i + 1))
	var m := _match_with_logs(log1, log2, true)
	# innings1: [ball] + innings_break = 2 events; bowling wickets start at index 2
	assert_eq(MatchViewBuilder.build(m, _player(), 3).highlight_text, "WICKET! 1/0", "1st wicket = WICKET!")
	assert_true(MatchViewBuilder.build(m, _player(), 5).highlight_text.begins_with("THREE-FOR!"), "3rd = THREE-FOR!")
	assert_true(MatchViewBuilder.build(m, _player(), 7).highlight_text.begins_with("FIVE-FOR!"), "5th = FIVE-FOR!")
