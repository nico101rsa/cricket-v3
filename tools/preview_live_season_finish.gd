extends SceneTree

# Dev preview for live-season-loop Slice 2 (UI wiring). Renders the two NEW states:
#   1. the Season Hub in the PLAYOFFS phase (knockout PLAY tile + lit stage chip)
#   2. the end-of-season OUTCOME screen (finish + ₸ banked)
# Run WITH rendering (not --headless):
#   /Applications/Godot.app/Contents/MacOS/Godot --path . -s tools/preview_live_season_finish.gd
# Output: docs/mockups/live-season-playoffs-hub-v1.png + live-season-outcome-v1.png

var _player: Player
var _career: CareerState
var _play: SeasonPlay
var _hub
var _outcome
var _frames := 0
var _stage := 0   # 0 = hub, 1 = outcome

func _initialize() -> void:
	_player = Player.new()
	var n := NamePair.new(); n.first_name = "Bongani"; n.surname = "Kgosi"
	_player.name = n; _player.city = "Durban"; _player.country = Country.Code.SA
	_player.tons_balance = 180; _player.affinity = 4
	var a := Attributes.new()
	a.power = 42.0; a.composure = 33.0; a.attack = 18.0; a.control = 12.0
	_player.attributes = a

	_career = CareerResolver.start_career(0)
	# Strong team vs weak opponents → reaches top-4 deterministically (seed 20260616).
	var team: Team = _career.teams[_career.current_team_index]
	team.stars = 4.5
	var opps: Array = _career.opponents_of_current()
	for o in opps:
		o.stars = 1.5
	var spec := DifficultyLadder.spec_for(_career.current_level(), 0)
	_play = SeasonPlay.start(_player.attributes, team, opps,
		spec.make_tour(), BallTuning.new(), InningsTuning.new(), 20260616, spec)
	# Enable pay before the league (as boot() does in the real game) so the outcome
	# screen reflects the whole season's ₸ + wins, not just the post-set_play tail.
	_play.enable_pay(_player, EconomyTuning.new(), team.stars, _career.current_level(), 0)
	for k in range(7):
		_play.commit_player_result(_play.make_session().result())
	print("PHASE after league: ", _play.phase())

	root.size = Vector2i(390, 844)
	_hub = load("res://scenes/season_hub/season_hub.tscn").instantiate()
	root.add_child(_hub)

func _process(_delta: float) -> bool:
	_frames += 1
	if _stage == 0:
		if _frames == 2:
			_hub.set_play(_player, _career, _play)
		if _frames >= 8:
			_save("res://docs/mockups/live-season-playoffs-hub-v1.png")
			# Finish the season (auto-play both player knockouts) → outcome screen.
			while not _play.season_done() and not _play.next_player_opponent().is_empty():
				_play.commit_player_result(_play.make_session().result())
			print("FINAL POSITION: ", _play.season_result().player_final_position,
				" · BANKED ₸", _play.pay_so_far(), " · WINS ", _play.season_wins())
			_hub.queue_free()
			_outcome = load("res://scenes/outcome/outcome.tscn").instantiate()
			root.add_child(_outcome)
			_stage = 1
			_frames = 0
		return false
	# stage 1 — outcome
	if _frames == 2:
		_outcome.set_outcome(_play.season_result(), _play.pay_so_far(), _play.season_wins())
	if _frames >= 8:
		_save("res://docs/mockups/live-season-outcome-v1.png")
		print("PREVIEW_SAVED")
		return true
	return false

func _save(path: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(path)
	print("SAVED ", path)
