extends SceneTree

# Renders the match_view scene for a real captured match to a PNG. Run WITH
# rendering (no --headless): inject after a frame because @onready isn't resolved
# in a -s script's _initialize. Spec §7.
#   /Applications/Godot.app/Contents/MacOS/Godot --path . -s tools/preview_match_view.gd

const OUT := "res://docs/mockups/match-view-built-v1.png"

func _initialize() -> void:
	var a := Attributes.new()
	a.power = 55.0; a.composure = 45.0; a.attack = 35.0; a.control = 30.0
	var career := CareerResolver.start_career(0)
	var team: Team = career.teams[career.current_team_index]
	var rng := RandomNumberGenerator.new(); rng.seed = 20260615
	var season := SeasonResolver.simulate_season(
		a, team, career.opponents_of_current(),
		DifficultyLadder.spec_for(career.current_level(), 0).make_tour(),
		BallTuning.new(), InningsTuning.new(), rng,
		null, null, null, [], Callable(), true)
	var player := Player.new()
	var n := NamePair.new(); n.first_name = "Bongani"; n.surname = "Kgosi"
	player.name = n; player.attributes = a
	var mr: MatchResult = season.league.player_matches[0]

	# --- findings tally (printed for spec §10) ---
	print("CAPTURE log1=", mr.ball_log_innings1.size(), " log2=", mr.ball_log_innings2.size())
	var events := MatchViewBuilder.build_events(mr, player)
	var tally := {"ball": 0, "over": 0, "innings_break": 0, "result": 0}
	var player_bat := 0
	var player_bowl := 0
	for e in events:
		var t: String = e["type"]
		tally[t] = tally.get(t, 0) + 1
		if t == "ball":
			if e["player_batting"]: player_bat += 1
			if e["player_bowling"]: player_bowl += 1
	print("EVENTS total=", events.size(), " ", tally,
		" player_bat=", player_bat, " player_bowl=", player_bowl)
	# ---------------------------------------------

	_mr = mr
	_player = player
	_team_name = team.team_name
	get_root().size = Vector2i(390, 844)   # phone-ish portrait; root IS the Window
	_scene = load("res://scenes/match_view/match_view.tscn").instantiate()
	get_root().add_child(_scene)   # _ready is deferred to the first frame in a -s script

var _scene
var _mr: MatchResult
var _player: Player
var _team_name := ""
var _frames := 0
var _injected := false

func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 2 and not _injected:
		# _ready has run by now → signals connected, $Tick etc. resolved.
		_scene.set_match(_mr, _player, _team_name, "Opponent")
		_scene.boot()
		# advance the cursor into the match for a representative frame
		for i in range(12):
			_scene.step(1)
		_injected = true
	if _frames >= 8:
		var img := get_root().get_viewport().get_texture().get_image()
		img.save_png(OUT)
		print("PREVIEW_SAVED")
		quit()
		return true
	return false
