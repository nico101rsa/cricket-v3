extends SceneTree

# PLAYABLE launcher for the interactive_match scene — opens a real, booted match in
# a window you can drive yourself: Play/step to watch, BOOST to press the Manager
# Boost (both innings), and a DRS "Review?" overlay pops when YOU are given out.
# Unlike preview_interactive_match.gd, this does NOT quit or script any decisions —
# it boots paused at ball 1 and hands you the controls. Close the window to stop.
#
# Run WITH rendering (no --headless), editor CLOSED first:
#   /Applications/Godot.app/Contents/MacOS/Godot --path . -s tools/play_interactive_match.gd

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
	# Player bats first so your batting innings (Boost + DRS) plays out first.
	_session = MatchSession.start(a, team, opp, tour, 20260615, 1)
	_team_name = team.team_name
	get_root().size = Vector2i(390, 844)
	_scene = load("res://scenes/interactive_match/interactive_match.tscn").instantiate()
	get_root().add_child(_scene)

func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 2 and not _injected:
		# _ready has run by now (deferred to frame 1 in a -s script) → buttons wired.
		_scene.set_session(_session, _team_name, "Opponent")
		_scene.boot()          # boots PAUSED at ball 1 — you drive from here
		_injected = true
	return false               # never quit — the window stays interactive
