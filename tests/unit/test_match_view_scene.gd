extends GutTest

# match_view scene: boots from an injected match (no sim), renders, steps, and
# the Back signal fires. Spec §5, §8.

const SCENE := preload("res://scenes/match_view/match_view.tscn")

func _player() -> Player:
	var p := Player.new()
	var n := NamePair.new(); n.first_name = "B"; n.surname = "K"
	p.name = n
	return p

func _ball(over, bio, is_p, p_bat, p_bowl, runs, wkt, total, wkts) -> Dictionary:
	return {"over": over, "ball_in_over": bio, "striker_pos": 3, "is_player": is_p,
		"player_batting": p_bat, "player_bowling": p_bowl, "intent": 0,
		"boost_pressed": false, "wicket": wkt, "runs": runs, "total": total, "wickets": wkts}

func _match() -> MatchResult:
	var m := MatchResult.new()
	m.player_bats_first = true
	m.innings1 = InningsResult.new(10, 1, 3, [], [])
	m.innings2 = InningsResult.new(8, 10, 4, [], [])
	m.outcome = MatchResult.Outcome.PLAYER_WIN
	m.margin_wickets = 9; m.balls_remaining = 110
	m.ball_log_innings1 = [
		_ball(1, 1, true, true, false, 4, false, 4, 0),
		_ball(1, 2, true, true, false, 6, false, 10, 0),
		_ball(1, 3, true, true, false, 0, true, 10, 1)]
	m.ball_log_innings2 = [_ball(1, 1, false, false, true, 0, true, 0, 1)]
	return m

func test_boots_and_renders() -> void:
	var s = SCENE.instantiate()
	add_child_autofree(s)
	s.set_match(_match(), _player(), "Karoo Kings", "Dusty Plains")
	s.boot()
	await get_tree().process_frame
	var feed: VBoxContainer = s.get_node("%Root/FeedBox") if s.has_node("%Root/FeedBox") else s.get_node("Root/FeedBox")
	assert_true(s.is_visible_in_tree(), "scene visible")
	assert_gt(s.size.y, 0, "scene has height")

func test_step_advances_cursor() -> void:
	var s = SCENE.instantiate()
	add_child_autofree(s)
	s.set_match(_match(), _player(), "Karoo Kings", "Dusty Plains")
	s.boot()
	await get_tree().process_frame
	var before: int = s.cursor()
	s.step(1)
	assert_eq(s.cursor(), before + 1, "step(1) advances the cursor")

func test_back_signal_fires() -> void:
	var s = SCENE.instantiate()
	add_child_autofree(s)
	s.set_match(_match(), _player(), "Karoo Kings", "Dusty Plains")
	s.boot()
	watch_signals(s)
	s.get_node("Root/Controls/Back").pressed.emit()
	assert_signal_emitted(s, "back")
