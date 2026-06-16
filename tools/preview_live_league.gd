extends SceneTree

# Visual harness for the live league loop (spec 2026-06-16 §8). Boots a
# SeasonPlay, auto-plays 3 fixtures, renders the forward-play Season Hub, and
# screenshots it. Run WITH rendering (no --headless), editor closed:
#   /Applications/Godot.app/Contents/MacOS/Godot --path . -s tools/preview_live_league.gd
# Output: docs/mockups/live-league-loop-built-v1.png
# NB: inject in _process at frame 2 (after _ready resolves @onready refs), NOT in
# _initialize — _ready is deferred to the first frame in a -s script.

var _hub
var _player: Player
var _career: CareerState
var _play: SeasonPlay
var _frames := 0
var _injected := false

func _initialize() -> void:
	_player = Player.new()
	var n := NamePair.new()
	n.first_name = "Bongani"; n.surname = "Kgosi"
	_player.name = n
	_player.city = "Durban"
	_player.country = Country.Code.SA
	_player.tons_balance = 120
	_player.affinity = 3
	var a := Attributes.new()
	a.power = 42.0; a.composure = 34.0; a.attack = 30.0; a.control = 24.0
	_player.attributes = a

	_career = CareerResolver.start_career(0)
	var spec := DifficultyLadder.spec_for(_career.current_level(), 0)
	var team: Team = _career.teams[_career.current_team_index]
	_play = SeasonPlay.start(
		_player.attributes, team, _career.opponents_of_current(),
		spec.make_tour(), BallTuning.new(), InningsTuning.new(), 314)
	for k in range(3):
		_play.commit_player_result(_play.make_session().result())

	root.size = Vector2i(390, 844)   # phone-ish portrait; root IS the Window
	_hub = load("res://scenes/season_hub/season_hub.tscn").instantiate()
	root.add_child(_hub)   # _ready is deferred to the first frame in a -s script

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 2 and not _injected:
		_hub.set_play(_player, _career, _play)   # @onready refs resolved by now
		_injected = true
	if _frames >= 8:
		var img := root.get_viewport().get_texture().get_image()
		img.save_png("res://docs/mockups/live-league-loop-built-v1.png")
		print("PREVIEW_SAVED · played %d/7" % _play.played_count())
		return true   # quit
	return false
