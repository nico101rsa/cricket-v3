extends Control

# Interactive Match screen (spec §3). Replays a MatchSession's event stream with
# watch controls, a press-anytime Boost button (DI2), and a forced DRS overlay on
# Player dismissals (DI3). boot() is explicit so tests inject without a sim.

signal back

const SPEEDS := [1.0, 2.0, 4.0]
const BASE_TICK := 0.6

var _session: MatchSession
var _team_name := ""
var _opp_name := ""
var _cursor := 0
var _event_count := 0
var _speed_idx := 0
var _playing := false
var _pending_review := {}     # the offer currently shown in the overlay
var _resume_after_review := false   # was autoplay running when the overlay popped?
var _boost_active_over := -1        # over a press is currently boosting (-1 = none)
var _boost_active_innings := -1     # innings that boost belongs to

func _ready() -> void:
	$Root/Controls/StepBack.pressed.connect(func(): pause(); step(-1))
	$Root/Controls/StepFwd.pressed.connect(func(): pause(); step(1))
	$Root/Controls/PlayPause.pressed.connect(_toggle_play)
	$Root/Controls/Speed.pressed.connect(_cycle_speed)
	$Root/Controls/Boost.pressed.connect(_on_boost)
	$Root/Controls/Back.pressed.connect(func(): back.emit())
	$Overlay/OverlayBox/ReviewYes.pressed.connect(_on_review_yes)
	$Overlay/OverlayBox/ReviewNo.pressed.connect(_on_review_no)
	$Tick.timeout.connect(_on_tick)
	$Tick.wait_time = BASE_TICK
	$Overlay.visible = false

func set_session(s: MatchSession, team_name: String, opp_name: String) -> void:
	_session = s
	_team_name = team_name
	_opp_name = opp_name

func boot() -> void:
	if _session == null:
		return
	_cursor = 0
	_event_count = _session.events().size()
	_render()

func event_count() -> int:
	return _event_count

func overlay_visible() -> bool:
	return $Overlay.visible

func boost_enabled() -> bool:
	return not $Root/Controls/Boost.disabled

# Which innings is at the current cursor (for boost routing / budget).
func _innings_at_cursor() -> int:
	for k in range(_cursor, -1, -1):
		if k < _session.events().size():
			var e: Dictionary = _session.events()[k]
			if e.has("innings"):
				return e["innings"]
	return 1

# 1-based within-innings over at the cursor (best effort; for boosting the NEXT over).
func _over_at_cursor() -> int:
	for k in range(_cursor, -1, -1):
		if k < _session.events().size():
			var e: Dictionary = _session.events()[k]
			if e.has("over"):
				return e["over"]
	return 0

func step(delta: int) -> void:
	_cursor = clampi(_cursor + delta, 0, _event_count)
	_render()   # always show the state up to the cursor (the dismissal's context)
	# pause for a DRS offer at the cursor (the event about to be shown)
	var offer := _session.review_offer(_cursor)
	if not offer.is_empty() and delta > 0:
		_pending_review = offer
		_resume_after_review = _playing   # remember to resume after the decision
		_show_overlay(offer)
		pause()
		return
	if _cursor >= _event_count:
		pause()

func seek_to(cursor: int) -> void:
	_cursor = clampi(cursor, 0, _event_count)
	_render()
	var offer := _session.review_offer(_cursor)
	if not offer.is_empty():
		_pending_review = offer
		_show_overlay(offer)

func play() -> void:
	if _cursor >= _event_count: return
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

func _on_boost() -> void:
	var inn := _innings_at_cursor()
	if not _session.can_boost(inn) or _boost_active_over != -1: return
	var next_over := mini(_over_at_cursor() + 1, 20)
	_session.decide_boost(inn, next_over)
	_event_count = _session.events().size()
	_boost_active_over = next_over      # button "charges" until this over plays out
	_boost_active_innings = inn
	_render()

# Boost button state (Nico's recharge feel): ACTIVE (faded) while the boosted over
# is still to play; once the cursor passes it, the button "fills back up" and shows
# the presses left; greyed when the innings budget is spent.
func _update_boost_button() -> void:
	var inn := _innings_at_cursor()
	if _boost_active_over != -1 and (inn != _boost_active_innings or _over_at_cursor() > _boost_active_over):
		_boost_active_over = -1          # boost has played out → recharge
	var btn: Button = $Root/Controls/Boost
	if _boost_active_over != -1:
		btn.disabled = true
		btn.text = "BOOST ON"
	elif _session.can_boost(inn):
		btn.disabled = false
		btn.text = "BOOST (%d)" % _session.presses_left(inn)
	else:
		btn.disabled = true
		btn.text = "BOOST 0"

func _show_overlay(offer: Dictionary) -> void:
	$Overlay/OverlayBox/Prompt.text = "You're given out — Review? (%d left)" % _session.reviews_left()
	$Overlay.visible = true

func _on_review_yes() -> void:
	$Overlay.visible = false
	if not _pending_review.is_empty():
		_session.decide_review(_pending_review["ball_id"])
		_event_count = _session.events().size()
	_pending_review = {}
	_render()   # re-render the (possibly overturned) cursor event
	_resume_play_after_decision()

func _on_review_no() -> void:
	$Overlay.visible = false
	_pending_review = {}
	_render()
	_resume_play_after_decision()

# After a DRS decision, pick up where we left off: if autoplay was running, resume it
# (the next tick steps past the reviewed ball); otherwise stay paused for manual control.
func _resume_play_after_decision() -> void:
	if _resume_after_review and _cursor < _event_count:
		_resume_after_review = false
		play()

func _render() -> void:
	var v := MatchViewBuilder.build(_session.result(), _session.player(), _cursor)
	$Root/Header.text = "%s  v  %s" % [_team_name, _opp_name]
	$Root/Scoreboard.text = "%s   %s" % [v.innings_label, v.batting_score]
	$Root/Target.text = v.target_text
	# When finished, show the result + the Player's own final card; else the live line.
	$Root/CurrentLine.text = ("%s\n%s" % [v.result_text, v.player_summary]) if v.finished else v.current_line
	_update_boost_button()
	var box: VBoxContainer = $Root/FeedBox
	for c in box.get_children():
		c.queue_free()
	for line in v.feed:
		var l := Label.new()
		l.text = line
		box.add_child(l)
