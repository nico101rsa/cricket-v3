extends SceneTree

# Renders the interactive_match scene to a PNG with a Key Moment card on screen,
# so the overlay can be eyeballed (unit tests can't catch an invisible overlay —
# see the flat-Button / blank-window lessons). Drives to the Powerplay Exit trigger.
# Run WITH rendering (no --headless): inject in _process frame 2 because @onready
# isn't resolved in a -s script's _initialize.
#   /Applications/Godot.app/Contents/MacOS/Godot --path . -s tools/preview_key_moment.gd

const OUT := "res://docs/mockups/key-moment-built-v1.png"

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
	_team_name = team.team_name
	get_root().size = Vector2i(390, 844)
	_scene = load("res://scenes/interactive_match/interactive_match.tscn").instantiate()
	get_root().add_child(_scene)

func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 2 and not _injected:
		_scene.set_session(_session, _team_name, "Opponent")
		_scene.boot()
		# drive to the Powerplay Exit Key Moment cursor
		var c := -1
		for i in range(_session.events().size()):
			var o: Dictionary = _session.key_moment_offer(i)
			if not o.is_empty() and ("Powerplay" in o["title"]):
				c = i; break
		if c > -1:
			_scene.seek_to(c)
		_injected = true
		print("KM_OVERLAY_VISIBLE ", _scene.km_overlay_visible(), " at cursor ", c)
	if _frames >= 8:
		var img := get_root().get_viewport().get_texture().get_image()
		img.save_png(OUT)
		print("PREVIEW_SAVED ", OUT)
		quit()
		return true
	return false
