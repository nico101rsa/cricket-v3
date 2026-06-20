extends SceneTree

# Renders the v4 in-match scene to PNGs (auto-sim, key-moment, result) so the build
# can be eyeballed against docs/design-inbox/in-match-reference.png. Run WITH
# rendering (no --headless); inject in _process frame 2 (@onready not resolved in a
# -s script's _initialize).
#   /Applications/Godot.app/Contents/MacOS/Godot --path . -s tools/preview_interactive_match.gd
const OUT_LATEST := "res://docs/mockups/latest/in-match.png"
const OUT_AUTOSIM := "res://docs/mockups/in-match-hifi-built-autosim.png"
const OUT_KM := "res://docs/mockups/in-match-hifi-built-keymoment.png"
const OUT_KM_BOWL := "res://docs/mockups/in-match-hifi-built-keymoment-bowling.png"
const OUT_DRS := "res://docs/mockups/in-match-hifi-built-drs.png"
const OUT_RESULT := "res://docs/mockups/in-match-hifi-built-result.png"

var _scene
var _session
var _bowl_session
var _team: Team
var _opp: Team
var _bowl_opp: Team
var _frames := 0
var _km_cursor := -1

func _initialize() -> void:
	var a := Attributes.new()
	a.power = 55.0; a.composure = 45.0; a.attack = 35.0; a.control = 30.0
	var career := CareerResolver.start_career(0)
	_team = career.teams[career.current_team_index]
	_opp = career.opponents_of_current()[0]
	var tour := DifficultyLadder.spec_for(career.current_level(), 0).make_tour()
	_session = MatchSession.start(a, _team, _opp, tour, 20260615, 1)
	# A second session with rotation ON so bowling Key Moments fire (for the bowling shot).
	_bowl_opp = career.opponents_of_current()[6]
	var spec := TourSpec.new(); spec.brain_tier = TourSpec.Tier.ADAPTIVE; spec.blend = 1.0
	_bowl_session = MatchSession.start(a, _team, _bowl_opp, tour, 20260615, 0, null, null, spec)
	get_root().size = Vector2i(390, 844)
	_scene = load("res://scenes/interactive_match/interactive_match.tscn").instantiate()
	get_root().add_child(_scene)

func _save(path: String) -> void:
	var img := get_root().get_viewport().get_texture().get_image()
	img.save_png(path)
	print("PREVIEW_SAVED ", path)

func _find_km() -> int:
	for c in range(_session.events().size()):
		if not _session.key_moment_offer(c).is_empty():
			return c
	return -1

# Step to a mid-innings cursor that does NOT pop an overlay (clean auto-sim shot).
func _autosim_cursor() -> int:
	var ev: Array = _session.events()
	for c in range(ev.size()):
		var e: Dictionary = ev[c]
		if e["type"] == "ball" and e.get("innings", 1) == 1 and e.get("over", 0) >= 9:
			if _session.key_moment_offer(c).is_empty() and _session.review_offer(c).is_empty():
				return c
	return mini(20, ev.size() - 1)

func _process(_d: float) -> bool:
	_frames += 1
	match _frames:
		2:
			_scene.set_session(_session, _team.team_name, _opp.team_name,
				_team.stars, _opp.stars, Country.Code.SA, Country.Code.AUS)
			_scene.boot()
			_scene.seek_to(_autosim_cursor())
		4:
			_save(OUT_AUTOSIM); _save(OUT_LATEST)
			_km_cursor = _find_km()
			if _km_cursor > -1: _scene.seek_to(_km_cursor)
		6:
			_save(OUT_KM)
			_scene.seek_to(_session.events().size())   # to the result
		8:
			_save(OUT_RESULT)
			# Swap to the rotation-on session + seek to a bowling Key Moment.
			_scene.set_session(_bowl_session, _team.team_name, _bowl_opp.team_name,
				_team.stars, _bowl_opp.stars, Country.Code.SA, Country.Code.AUS)
			_scene.boot()
			for c in range(_bowl_session.events().size()):
				var o: Dictionary = _bowl_session.key_moment_offer(c)
				if not o.is_empty() and o.get("lever", "") == "bowling":
					_scene.seek_to(c); break
		10:
			_save(OUT_KM_BOWL)
			# Back to the batting session, seek to the first Player dismissal (DRS card).
			_scene.set_session(_session, _team.team_name, _opp.team_name,
				_team.stars, _opp.stars, Country.Code.SA, Country.Code.AUS)
			_scene.boot()
			var ev: Array = _session.events()
			for i in range(ev.size()):
				var e: Dictionary = ev[i]
				if e["type"] == "ball" and e.get("player_batting", false) and e["wicket"]:
					_scene.seek_to(i); break
		12:
			_save(OUT_DRS)
			quit()
			return true
	return false
