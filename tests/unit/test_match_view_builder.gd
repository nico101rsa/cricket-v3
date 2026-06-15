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
