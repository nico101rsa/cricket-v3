extends SceneTree

# Dev preview: boot a live forward-play season into the hi-fi Season Hub, play a
# few fixtures (so the running table + gold "Next Match ▶" CTA show), render a few
# frames, save a PNG, quit. Run WITH rendering (not --headless):
#   /Applications/Godot.app/Contents/MacOS/Godot --path . -s tools/preview_season_hub_hifi.gd
# Output: docs/mockups/season-hub-hifi-built-v1.png

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
	_player.tons_balance = 180
	_player.affinity = 4
	var a := Attributes.new()
	a.power = 42.0; a.composure = 33.0; a.attack = 18.0; a.control = 12.0
	_player.attributes = a

	_career = CareerResolver.start_career(0)
	var spec := DifficultyLadder.spec_for(_career.current_level(), 0)
	var team: Team = _career.teams[_career.current_team_index]
	_play = SeasonPlay.start(
		_player.attributes, team, _career.opponents_of_current(),
		spec.make_tour(), BallTuning.new(), InningsTuning.new(), 20260615, spec)
	# Season start (Match 1, no games played) — matches the reference image.

	root.size = Vector2i(390, 844)
	_hub = load("res://scenes/season_hub/season_hub.tscn").instantiate()
	root.add_child(_hub)

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 2 and not _injected:
		_hub.set_play(_player, _career, _play)
		_injected = true
	if _frames >= 8:
		var img := root.get_viewport().get_texture().get_image()
		# Versioned build proof + a STABLE "latest" path the design track always reads.
		img.save_png("res://docs/mockups/season-hub-hifi-v2-built.png")
		img.save_png("res://docs/mockups/latest/season-hub.png")
		print("PREVIEW_SAVED")
		return true
	return false
