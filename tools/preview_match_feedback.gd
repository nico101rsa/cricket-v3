extends SceneTree

# Eyeball the match-feedback polish: (1) the your-moment Flash on a boundary, and
# (2) the DRS review-outcome popup. Saves two PNGs. Run WITH rendering (no --headless).
#   /Applications/Godot.app/Contents/MacOS/Godot --path . -s tools/preview_match_feedback.gd

const OUT_FLASH := "res://docs/mockups/match-flash-built-v1.png"
const OUT_REVIEW := "res://docs/mockups/review-outcome-built-v1.png"

var _scene
var _session
var _team_name := ""
var _frames := 0
var _phase := 0

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

func _boundary_cursor() -> int:
	for i in range(_session.events().size()):
		var e: Dictionary = _session.events()[i]
		if e["type"] == "ball" and e.get("player_batting", false) and (e["runs"] == 4 or e["runs"] == 6):
			return i
	return -1

func _dismissal_cursor() -> int:
	for i in range(_session.events().size()):
		var e: Dictionary = _session.events()[i]
		if e["type"] == "ball" and e.get("player_batting", false) and e["wicket"]:
			return i
	return -1

func _save(path: String) -> void:
	get_root().get_viewport().get_texture().get_image().save_png(path)

func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 2:
		_scene.set_session(_session, _team_name, "Opponent")
		_scene.boot()
		var bc := _boundary_cursor()
		_scene.seek_to(bc + 1)   # highlight is for the just-shown ball
		print("FLASH_TEXT '", _scene.flash_text(), "' at ", bc)
	elif _frames == 6:
		_save(OUT_FLASH); print("SAVED ", OUT_FLASH)
		# now the review outcome popup
		var dc := _dismissal_cursor()
		_scene.seek_to(dc)
		_scene.review_yes()
		print("REVIEW_OK_VISIBLE ", _scene.review_ok_visible(), " overlay ", _scene.overlay_visible())
	elif _frames >= 10:
		_save(OUT_REVIEW); print("SAVED ", OUT_REVIEW)
		quit()
		return true
	return false
