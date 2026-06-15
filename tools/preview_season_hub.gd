extends SceneTree

# Dev preview: boot a demo season into the Season Hub, scrub to match 4, render a
# few frames, save a PNG, and quit. Run WITH rendering (not --headless):
#   /Applications/Godot.app/Contents/MacOS/Godot --path . -s tools/preview_season_hub.gd
# Output: docs/mockups/season-hub-built-v1.png

var _hub
var _player: Player
var _career: CareerState
var _season: SeasonResult
var _frames := 0
var _injected := false

func _initialize() -> void:
	_player = Player.new()
	var n := NamePair.new()
	n.first_name = "Bongani"; n.surname = "Kgosi"
	_player.name = n
	_player.city = "Durban"
	_player.country = Country.Code.SA
	_player.tons_balance = 180
	_player.affinity = 4
	var a := Attributes.new()
	a.power = 42.0; a.composure = 33.0; a.attack = 18.0; a.control = 12.0
	_player.attributes = a

	_career = CareerResolver.start_career(0)
	var spec := DifficultyLadder.spec_for(_career.current_level(), 0)
	var team: Team = _career.teams[_career.current_team_index]
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260615
	_season = SeasonResolver.simulate_season(
		_player.attributes, team, _career.opponents_of_current(),
		spec.make_tour(), BallTuning.new(), InningsTuning.new(), rng)

	root.size = Vector2i(390, 844)   # phone-ish portrait; root IS the Window
	_hub = load("res://scenes/season_hub/season_hub.tscn").instantiate()
	root.add_child(_hub)   # _ready is deferred to the first frame in a -s script

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 2 and not _injected:
		# _ready has run by now → @onready node refs are resolved.
		_hub.set_source(_player, _career, _season)
		_hub.step(1); _hub.step(1); _hub.step(1); _hub.step(1)   # scrub to match 4
		_injected = true
	if _frames >= 8:
		var img := root.get_viewport().get_texture().get_image()
		img.save_png("res://docs/mockups/season-hub-built-v1.png")
		print("PREVIEW_SAVED")
		return true   # quit
	return false
