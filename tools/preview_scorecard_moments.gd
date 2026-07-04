extends SceneTree

# Renders the T10 scorecard moments for eyeballing: (1) the mini strip at the
# Player's first involvement, (2) the innings-break full scorecard overlay.
#   /Applications/Godot.app/Contents/MacOS/Godot --path . -s tools/preview_scorecard_moments.gd
const OUT_STRIP := "res://docs/mockups/scorecard-moment-strip-v1.png"
const OUT_BREAK := "res://docs/mockups/innings-break-v1.png"

var _scene
var _session
var _frames := 0

func _initialize() -> void:
	var a := Attributes.new()
	a.power = 55.0; a.composure = 45.0; a.attack = 35.0; a.control = 30.0
	var career := CareerResolver.start_career(0)
	var team: Team = career.teams[career.current_team_index]
	var opp: Team = career.opponents_of_current()[0]
	var tour := DifficultyLadder.spec_for(career.current_level(), 0).make_tour()
	_session = MatchSession.start(a, team, opp, tour, 20260615, 1)
	get_root().size = Vector2i(390, 844)
	_scene = load("res://scenes/interactive_match/interactive_match.tscn").instantiate()
	get_root().add_child(_scene)

func _save(path: String) -> void:
	var img := get_root().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(path))
	print("saved ", path)

func _process(_dt: float) -> bool:
	_frames += 1
	if _frames == 2:
		_scene.set_session(_session, "Karoo Kings", "Riverside")
		_scene.boot()
		var c := -1
		for k in range(1, _session.events().size() + 1):
			var m := MatchViewBuilder.moment_at(_session.result(), _session.player(), k)
			if not m.is_empty():
				c = k
				break
		_scene.seek_to(c - 1)
		_scene.step(1)
	elif _frames == 6:
		_save(OUT_STRIP)
		var ev: Array = _session.events()
		for i in range(ev.size()):
			if ev[i]["type"] == "innings_break":
				_scene.seek_to(i + 1)
				break
	elif _frames == 10:
		_save(OUT_BREAK)
		quit()
	return false
