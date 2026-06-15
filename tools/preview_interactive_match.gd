extends SceneTree

# Renders the interactive_match scene to a PNG, scripting a Boost + advancing to a
# DRS decision so the shot shows a real interactive moment. Run WITH rendering
# (no --headless): inject in _process frame 2 because @onready isn't resolved in a
# -s script's _initialize. Spec §8.
#   /Applications/Godot.app/Contents/MacOS/Godot --path . -s tools/preview_interactive_match.gd

const OUT := "res://docs/mockups/interactive-match-built-v1.png"

var _scene
var _session
var _team_name := ""
var _frames := 0
var _injected := false

func _initialize() -> void:
	var a := Attributes.new()
	a.power = 55.0; a.composure = 45.0; a.attack = 35.0; a.control = 30.0
	var career := CareerResolver.start_career(0)
	var team: Team = career.teams[career.current_team_index]
	var opp: Team = career.opponents_of_current()[0]
	var tour := DifficultyLadder.spec_for(career.current_level(), 0).make_tour()
	_session = MatchSession.start(a, team, opp, tour, 20260615, 1)
	# SHOWCASE (scripted for the shot): a Boost on over 5 of the batting innings.
	_session.decide_boost(1, 5)
	_team_name = team.team_name
	get_root().size = Vector2i(390, 844)
	_scene = load("res://scenes/interactive_match/interactive_match.tscn").instantiate()
	get_root().add_child(_scene)

func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 2 and not _injected:
		_scene.set_session(_session, _team_name, "Opponent")
		_scene.boot()
		# advance to the first Player dismissal so the DRS overlay is on screen
		var ev: Array = _session.events()
		var c := -1
		for i in range(ev.size()):
			if ev[i]["type"] == "ball" and ev[i].get("player_batting", false) and ev[i]["wicket"]:
				c = i; break
		if c > -1:
			_scene.seek_to(c)
		else:
			for i in range(14): _scene.step(1)
		_injected = true
	if _frames >= 8:
		var img := get_root().get_viewport().get_texture().get_image()
		img.save_png(OUT)
		print("PREVIEW_SAVED ", OUT)
		quit()
		return true
	return false
