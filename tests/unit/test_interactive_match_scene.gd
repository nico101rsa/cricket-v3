extends GutTest

# interactive_match scene — overlay appears on a Player-dismissal cursor; Boost button.

var _scene

func _make_session() -> MatchSession:
	var a := Attributes.new()
	a.power = 55.0; a.composure = 45.0; a.attack = 35.0; a.control = 30.0
	var career := CareerResolver.start_career(0)
	var team: Team = career.teams[career.current_team_index]
	var opp: Team = career.opponents_of_current()[0]
	var tour := DifficultyLadder.spec_for(career.current_level(), 0).make_tour()
	return MatchSession.start(a, team, opp, tour, 20260615, 1)

func before_each():
	_scene = load("res://scenes/interactive_match/interactive_match.tscn").instantiate()
	add_child_autofree(_scene)
	await get_tree().process_frame

func test_boots_and_renders():
	var s := _make_session()
	_scene.set_session(s, "Karoo Kings", "Opponent")
	_scene.boot()
	assert_gt(_scene.event_count(), 0, "event stream loaded")
	# Run-rate chart present + visible (the numeric placeholder is replaced).
	var chart: Node = _scene.find_child("RunRateChart", true, false)
	assert_not_null(chart, "run-rate chart mounted in the match screen")
	assert_gt(chart.size.y, 0.0, "chart not collapsed")

func test_overlay_appears_at_a_dismissal():
	var s := _make_session()
	var ev := s.events()
	var c := -1
	for i in range(ev.size()):
		if ev[i]["type"] == "ball" and ev[i].get("player_batting", false) and ev[i]["wicket"]:
			c = i; break
	assert_gt(c, -1, "dismissal exists")
	_scene.set_session(s, "Karoo Kings", "Opponent")
	_scene.boot()
	_scene.seek_to(c)
	assert_true(_scene.overlay_visible(), "DRS overlay shown at a dismissal")

func test_boost_button_enabled_with_budget():
	var s := _make_session()
	_scene.set_session(s, "Karoo Kings", "Opponent")
	_scene.boot()
	assert_true(_scene.boost_enabled(), "boost available at start")

func _km_cursor(s: MatchSession, kind: String) -> int:
	for c in range(s.events().size()):
		var o := s.key_moment_offer(c)
		if not o.is_empty() and (kind in o["title"]):
			return c
	return -1

func test_km_overlay_appears_at_a_trigger():
	var s := _make_session()
	var c := _km_cursor(s, "Powerplay")
	assert_gt(c, -1, "a Powerplay Exit moment exists")
	_scene.set_session(s, "Karoo Kings", "Opponent")
	_scene.boot()
	_scene.seek_to(c)
	assert_true(_scene.km_overlay_visible(), "KM card shown at the trigger")

func test_km_choice_changes_event_stream():
	var s := _make_session()
	var c := _km_cursor(s, "Powerplay")
	var before := s.result().innings1.total
	_scene.set_session(s, "Karoo Kings", "Opponent")
	_scene.boot()
	_scene.seek_to(c)
	_scene.km_press(1)   # the second option (Hunt = AGGRESSIVE)
	assert_false(_scene.km_overlay_visible(), "overlay hides after a choice")
	assert_ne(s.result().innings1.total, before, "the choice re-simulated the match")

# -- Bowling Key Moments (spec 2026-06-18): the same overlay serves a bowling moment;
# km_press must route by lever (decide_bowling_key_moment via the choice's `kind`).
func _bowl_spec_session() -> MatchSession:
	var a := Attributes.new()
	a.power = 55.0; a.composure = 45.0; a.attack = 35.0; a.control = 30.0
	var career := CareerResolver.start_career(0)
	var team: Team = career.teams[career.current_team_index]
	var opp: Team = career.opponents_of_current()[6]
	var tour := DifficultyLadder.spec_for(career.current_level(), 0).make_tour()
	var spec := TourSpec.new(); spec.brain_tier = TourSpec.Tier.ADAPTIVE; spec.blend = 1.0
	return MatchSession.start(a, team, opp, tour, 20260615, 0, null, null, spec)

func _bowl_km_cursor(s: MatchSession, kind: String) -> int:
	for c in range(s.events().size()):
		var o := s.key_moment_offer(c)
		if not o.is_empty() and o.get("lever", "") == "bowling" and (kind in o["title"]):
			return c
	return -1

func test_bowling_km_overlay_decides_via_kind():
	var s := _bowl_spec_session()
	var c := _bowl_km_cursor(s, "Death")
	assert_gt(c, -1, "a bowling Death Defence moment exists")
	var before := s.result().ball_log_innings1.duplicate(true)
	_scene.set_session(s, "Karoo Kings", "Opponent")
	_scene.boot()
	_scene.seek_to(c)
	assert_true(_scene.km_overlay_visible(), "the bowling KM overlay is showing")
	_scene.km_press(1)   # Death Defence option B = Spin
	assert_false(_scene.km_overlay_visible(), "overlay closes after the pick")
	assert_ne(s.result().ball_log_innings1, before, "the bowling pick re-simulated the opposition innings")

func _first_player_dismissal(s: MatchSession) -> int:
	for i in range(s.events().size()):
		var e: Dictionary = s.events()[i]
		if e["type"] == "ball" and e.get("player_batting", false) and e["wicket"]:
			return i
	return -1

func test_review_popup_shows_outcome_then_ok_resumes():
	var s := _make_session()
	var c := _first_player_dismissal(s)
	assert_gt(c, -1, "a player dismissal exists")
	_scene.set_session(s, "Karoo Kings", "Opponent")
	_scene.boot()
	_scene.seek_to(c)
	assert_true(_scene.overlay_visible(), "review overlay shown at the dismissal")
	_scene.review_yes()
	assert_true(_scene.overlay_visible(), "overlay stays up showing the outcome")
	assert_true(_scene.review_ok_visible(), "an OK button is shown after the decision")
	_scene.review_ok()
	assert_false(_scene.overlay_visible(), "OK dismisses the overlay")

func test_flash_label_shows_your_boundary():
	var s := _make_session()
	var c := -1
	for i in range(s.events().size()):
		var e: Dictionary = s.events()[i]
		if e["type"] == "ball" and e.get("player_batting", false) and (e["runs"] == 4 or e["runs"] == 6):
			c = i; break
	if c == -1:
		assert_true(true, "no player boundary in this seed — nothing to flash")
		return
	_scene.set_session(s, "Karoo Kings", "Opponent")
	_scene.boot()
	_scene.seek_to(c + 1)   # render through the boundary; highlight is for the just-shown ball
	assert_ne(_scene.flash_text(), "", "the flash label shows a your-moment after a boundary")
