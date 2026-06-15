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
