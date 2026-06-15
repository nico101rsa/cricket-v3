extends Control

# Play → Match screen: watch-only, player-centric ball-by-ball replay. Renders a
# MatchView built by MatchViewBuilder at the current cursor; autoplay via a Timer.
# boot() is explicit (not in _ready) so tests inject without a sim. Spec §3, §5.

signal back

const SPEEDS := [1.0, 2.0, 4.0]
const BASE_TICK := 0.6

@onready var _root: VBoxContainer = $Root

var _match: MatchResult
var _player: Player
var _team_name := ""
var _opp_name := ""
var _cursor := 0
var _event_count := 0
var _speed_idx := 0
var _playing := false

func _ready() -> void:
	$Root/Controls/StepBack.pressed.connect(func(): pause(); step(-1))
	$Root/Controls/StepFwd.pressed.connect(func(): pause(); step(1))
	$Root/Controls/PlayPause.pressed.connect(_toggle_play)
	$Root/Controls/Speed.pressed.connect(_cycle_speed)
	$Root/Controls/Back.pressed.connect(func(): back.emit())
	$Tick.timeout.connect(_on_tick)
	$Tick.wait_time = BASE_TICK

func set_match(mr: MatchResult, player: Player, team_name: String, opp_name: String) -> void:
	_match = mr
	_player = player
	_team_name = team_name
	_opp_name = opp_name

func boot() -> void:
	if _match == null:
		return
	_cursor = 0
	_event_count = MatchViewBuilder.build(_match, _player, 0).event_count
	_render()   # boots paused at ball 1 (DM11)

func cursor() -> int:
	return _cursor

func step(delta: int) -> void:
	_cursor = clampi(_cursor + delta, 0, _event_count)
	_render()
	if _cursor >= _event_count:
		pause()

func play() -> void:
	if _cursor >= _event_count:
		return
	_playing = true
	$Tick.start()
	$Root/Controls/PlayPause.text = "Pause"

func pause() -> void:
	_playing = false
	$Tick.stop()
	$Root/Controls/PlayPause.text = "Play"

func set_speed(mult: float) -> void:
	$Tick.wait_time = BASE_TICK / mult

func _toggle_play() -> void:
	if _playing: pause()
	else: play()

func _cycle_speed() -> void:
	_speed_idx = (_speed_idx + 1) % SPEEDS.size()
	set_speed(SPEEDS[_speed_idx])
	$Root/Controls/Speed.text = "%dx" % int(SPEEDS[_speed_idx])

func _on_tick() -> void:
	step(1)

func _render() -> void:
	var v := MatchViewBuilder.build(_match, _player, _cursor)
	$Root/Header.text = "%s  v  %s" % [_team_name, _opp_name]
	$Root/Scoreboard.text = "%s   %s" % [v.innings_label, v.batting_score]
	$Root/Target.text = v.target_text
	$Root/CurrentLine.text = (v.result_text if v.finished else v.current_line)
	var box: VBoxContainer = $Root/FeedBox
	for c in box.get_children():
		c.queue_free()
	for line in v.feed:
		var l := Label.new()
		l.text = line
		box.add_child(l)
