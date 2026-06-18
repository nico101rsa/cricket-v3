extends SceneTree

# Renders the interactive_match scene to a PNG with a BOWLING Key Moment card on screen
# (spec 2026-06-18), so the bowling overlay can be eyeballed. Mirror of
# tools/preview_key_moment.gd, but a spec'd session (opp bats first, adaptive brain →
# rotation on → bowling moments fire) driven to the bowling Powerplay Exit trigger.
# Run WITH rendering (no --headless):
#   /Applications/Godot.app/Contents/MacOS/Godot --path . -s tools/preview_bowling_key_moment.gd

const OUT := "res://docs/mockups/bowling-key-moment-built-v1.png"

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
	var opp: Team = career.opponents_of_current()[6]
	var tour := DifficultyLadder.spec_for(career.current_level(), 0).make_tour()
	var spec := TourSpec.new(); spec.brain_tier = TourSpec.Tier.ADAPTIVE; spec.blend = 1.0
	# force=0: opp bats first (full innings), Player bowls -> bowling moments live.
	_session = MatchSession.start(a, team, opp, tour, 20260615, 0, null, null, spec)
	_team_name = team.team_name
	get_root().size = Vector2i(390, 844)
	_scene = load("res://scenes/interactive_match/interactive_match.tscn").instantiate()
	get_root().add_child(_scene)

func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 2 and not _injected:
		_scene.set_session(_session, _team_name, "Opponent")
		_scene.boot()
		# drive to the bowling Powerplay Exit (over 7) Key Moment cursor
		var c := -1
		for i in range(_session.events().size()):
			var o: Dictionary = _session.key_moment_offer(i)
			if not o.is_empty() and o.get("lever", "") == "bowling" and ("Powerplay" in o["title"]):
				c = i; break
		if c > -1:
			_scene.seek_to(c)
		_injected = true
		print("BOWL_KM_OVERLAY_VISIBLE ", _scene.km_overlay_visible(), " at cursor ", c)
	if _frames >= 8:
		var img := get_root().get_viewport().get_texture().get_image()
		img.save_png(OUT)
		print("PREVIEW_SAVED ", OUT)
		quit()
		return true
	return false
