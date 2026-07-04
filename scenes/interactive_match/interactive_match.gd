extends Control

# Interactive Match screen — v4 hi-fi (docs/design-inbox/in-match.md). Replays a
# MatchSession event stream as a live scorecard with a collapsed auto-sim bar + round
# Boost (Nico's call: no discrete step buttons — step/seek stay under the hood), a
# Key Moment card, and a DRS overlay on Player dismissals. The UI is built in code
# from Palette/UIStyle (like the Season Hub); boot() is explicit so tests inject
# without a sim. Player NAMES on screen are flavour (PlayerNames); all numbers real.

signal back

const SPEEDS := [1.0, 2.0, 4.0]
const BASE_TICK := 0.6
const FLASH_HOLD := 1.5

var _session: MatchSession
var _team_name := ""
var _opp_name := ""
var _my_stars := 2.5
var _opp_stars := 2.5
var _my_code := 0
var _opp_code := 1
var _cursor := 0
var _event_count := 0
var _speed_idx := 0
var _playing := false
var _pending_review := {}
var _resume_after_review := false
var _pending_km := {}
var _resume_after_km := false
var _flash := ""

# Node refs (built in _build_ui).
var _root: VBoxContainer
var _bat_badge: Label; var _bat_name: Label; var _opp_name_lbl: Label; var _opp_badge: Label
var _header: PanelContainer
var _score_big: Label; var _score_meta: Label; var _tag_sub: Label; var _target_big: Label; var _target_sub: Label
var _batters: HBoxContainer
var _bowler_row: PanelContainer; var _bowl_lbl: Label; var _bowl_name: Label; var _bowl_stat: Label; var _bowl_fig: Label
var _comm_chip: Label; var _comm_lbl: Label
var _body: Control; var _body_vbox: VBoxContainer
var _chart: RunRateChart
var _over_grid: GridContainer
var _pship_names: Label; var _pship_runs: Label; var _pship_bar: ProgressBar
var _autosim_bar: Button; var _play_lbl: Label; var _speed_lbl: Label; var _sim_progress: ProgressBar
var _boost_btn: Button; var _boost_badge: Label
var _moment_strip: PanelContainer; var _moment_title: Label; var _moment_sub: Label; var _moment_score: Label
var _result_box: VBoxContainer
var _overlay: Control; var _ov_banner: Label; var _ov_body: VBoxContainer; var _ov_ok_shown := false
var _km_overlay: Control; var _km_banner: Label; var _km_body: VBoxContainer
var _break_overlay: Control; var _break_banner: Label; var _break_body: VBoxContainer
var _resume_after_break := false
var _tick: Timer; var _flash_timer: Timer

# ---------------------------------------------------------------- build helpers

# Default weight is Barlow Bold (/800) — design's dominant face for this scoreboard
# (scores, names, figures, verbs, micro-labels). Pass a lighter `weight` for body /
# meta / panel labels, and `tabular` for numbers so they don't jiggle while ticking.
func _lbl(txt: String, size: int, col: Color, halign: int = HORIZONTAL_ALIGNMENT_LEFT,
		weight: int = Fonts.W_BOLD, tabular: bool = false) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.horizontal_alignment = halign
	Fonts.weigh(l, weight, tabular)
	return l

func _spacer() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c

func _panel(sb: StyleBoxFlat) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", sb)
	return p

func _badge(text: String, bg: Color, fg: Color) -> Label:
	var l := _lbl(text, 9, fg, HORIZONTAL_ALIGNMENT_CENTER)
	l.add_theme_stylebox_override("normal", UIStyle.pill(bg))
	l.custom_minimum_size = Vector2(22, 22)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l

func _ready() -> void:
	_build_ui()
	_tick = Timer.new(); _tick.wait_time = BASE_TICK; _tick.one_shot = false
	add_child(_tick); _tick.timeout.connect(_on_tick)
	_flash_timer = Timer.new(); _flash_timer.one_shot = true
	add_child(_flash_timer); _flash_timer.timeout.connect(_on_flash_done)

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Palette.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	_root = VBoxContainer.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.offset_left = 13; _root.offset_top = 13; _root.offset_right = -13; _root.offset_bottom = -13
	_root.add_theme_constant_override("separation", 7)
	add_child(_root)

	_build_header()
	_build_scorebar()
	_batters = HBoxContainer.new()
	_batters.add_theme_constant_override("separation", 7)
	_root.add_child(_batters)
	_build_bowler_row()
	_build_commentary()
	_build_body()
	_build_result_box()
	_build_overlays()

func _build_header() -> void:
	var my_set := Palette.country_set(_my_code)
	_header = _panel(UIStyle.header(my_set.grad1, my_set.grad2, my_set.glow))
	var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 8)
	_bat_badge = _badge("KK", Color(0, 0, 0, 0.28), Palette.COUNTRY_ACCENT_SA)
	_bat_name = _lbl("KAROO KINGS", 13, Palette.WHITE)
	_opp_name_lbl = _lbl("OPPONENT", 13, Palette.WHITE_SOFT, HORIZONTAL_ALIGNMENT_RIGHT)
	_opp_badge = _badge("OP", Color(0, 0, 0, 0.28), Palette.country_set(_opp_code).accent)
	h.add_child(_bat_badge); h.add_child(_bat_name)
	h.add_child(_lbl("vs", 11, Palette.WHITE_MID, HORIZONTAL_ALIGNMENT_LEFT, Fonts.W_MEDIUM))
	h.add_child(_spacer())
	h.add_child(_opp_name_lbl); h.add_child(_opp_badge)
	_header.add_child(h)
	_root.add_child(_header)

func _build_scorebar() -> void:
	var sb := UIStyle.panel()
	sb.border_color = Color(Palette.COUNTRY_1_SA.r, Palette.COUNTRY_1_SA.g, Palette.COUNTRY_1_SA.b, 0.4)
	var p := _panel(sb)
	var h := HBoxContainer.new()
	var left := VBoxContainer.new()
	_score_big = _lbl("0/0", 30, Palette.GOLD, HORIZONTAL_ALIGNMENT_LEFT, Fonts.W_BOLD, true)
	_score_meta = _lbl("0.0 OV · CRR 0.0", 11, Palette.WHITE_MID, HORIZONTAL_ALIGNMENT_LEFT, Fonts.W_MEDIUM, true)
	left.add_child(_score_big); left.add_child(_score_meta)
	var right := VBoxContainer.new()
	_tag_sub = _lbl("1ST INNINGS", 10, Palette.COUNTRY_ACCENT_SA, HORIZONTAL_ALIGNMENT_RIGHT)
	_target_big = _lbl("", 19, Palette.WHITE, HORIZONTAL_ALIGNMENT_RIGHT, Fonts.W_BOLD, true)
	_target_sub = _lbl("", 10, Palette.WHITE_DIM, HORIZONTAL_ALIGNMENT_RIGHT)
	right.add_child(_tag_sub); right.add_child(_target_big); right.add_child(_target_sub)
	h.add_child(left); h.add_child(_spacer()); h.add_child(right)
	p.add_child(h)
	_root.add_child(p)

func _build_bowler_row() -> void:
	_bowler_row = _panel(UIStyle.team_row(Palette.country_set(_opp_code).accent))
	var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 9)
	_bowl_lbl = _lbl("BOWL", 9, Palette.country_set(_opp_code).accent)
	_bowl_name = _lbl("—", 13, Palette.country_set(_opp_code).accent)
	_bowl_stat = _lbl("", 10, Palette.WHITE_MID)
	# Right side = the real ECON, labelled (no fabricated per-bowler wkts/runs).
	var econ_box := VBoxContainer.new()
	econ_box.alignment = BoxContainer.ALIGNMENT_END
	var econ_cap := _lbl("ECON", 8, Palette.WHITE_DIM, HORIZONTAL_ALIGNMENT_RIGHT, Fonts.W_LABEL)
	_bowl_fig = _lbl("0.0", 15, Palette.WHITE, HORIZONTAL_ALIGNMENT_RIGHT, Fonts.W_BOLD, true)
	econ_box.add_child(econ_cap); econ_box.add_child(_bowl_fig)
	h.add_child(_bowl_lbl); h.add_child(_bowl_name); h.add_child(_bowl_stat)
	h.add_child(_spacer()); h.add_child(econ_box)
	_bowler_row.add_child(h)
	_root.add_child(_bowler_row)

func _build_commentary() -> void:
	var sb := UIStyle.panel()
	sb.border_width_left = 3; sb.border_color = Palette.GOLD_WARN
	var p := _panel(sb)
	var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 8)
	_comm_chip = _lbl("ZU", 8, Color(0, 0, 0))
	_comm_chip.add_theme_stylebox_override("normal", UIStyle.pill(Palette.GOLD_WARN))
	_comm_lbl = _lbl("", 11, Palette.WHITE_SOFT, HORIZONTAL_ALIGNMENT_LEFT, Fonts.W_BODY)
	h.add_child(_comm_chip); h.add_child(_comm_lbl)
	p.add_child(h)
	_root.add_child(p)

func _build_body() -> void:
	_body = Control.new()
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_root.add_child(_body)
	_body_vbox = VBoxContainer.new()
	_body_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_body_vbox.add_theme_constant_override("separation", 7)
	_body.add_child(_body_vbox)

	# Run-rate chart (hero viz) — replaces the old numeric run-rate panel. The CRR
	# number still lives in the scorebar meta (v.score_meta "… CRR x.x").
	var rr := _panel(UIStyle.panel())
	var rv := VBoxContainer.new()
	rv.add_child(_lbl("RUN RATE", 9, Palette.WHITE_DIM, HORIZONTAL_ALIGNMENT_LEFT, Fonts.W_LABEL))
	_chart = RunRateChart.new()
	_chart.name = "RunRateChart"
	_chart.custom_minimum_size = Vector2(0, 180)
	_chart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rv.add_child(_chart)
	rr.add_child(rv)
	_body_vbox.add_child(rr)

	# This over viz
	var to := _panel(UIStyle.panel())
	var tv := VBoxContainer.new()
	tv.add_child(_lbl("THIS OVER", 9, Palette.WHITE_DIM, HORIZONTAL_ALIGNMENT_LEFT, Fonts.W_LABEL))
	_over_grid = GridContainer.new(); _over_grid.columns = 6
	_over_grid.add_theme_constant_override("h_separation", 6)
	tv.add_child(_over_grid)
	to.add_child(tv)
	_body_vbox.add_child(to)

	# Partnership viz
	var pp := _panel(UIStyle.panel())
	var pv := VBoxContainer.new()
	pv.add_child(_lbl("PARTNERSHIP", 9, Palette.WHITE_DIM, HORIZONTAL_ALIGNMENT_LEFT, Fonts.W_LABEL))
	var ph := HBoxContainer.new()
	_pship_names = _lbl("—", 12, Palette.WHITE_SOFT)
	_pship_runs = _lbl("", 12, Palette.GOLD, HORIZONTAL_ALIGNMENT_RIGHT, Fonts.W_BOLD, true)
	ph.add_child(_pship_names); ph.add_child(_spacer()); ph.add_child(_pship_runs)
	pv.add_child(ph)
	_pship_bar = _mk_bar(Palette.COUNTRY_ACCENT_SA)
	pv.add_child(_pship_bar)
	pp.add_child(pv)
	_body_vbox.add_child(pp)

	_body_vbox.add_child(_spacer())

	# T10 mini scorecard strip (DSC4/DSC5) — hidden until a moment fires.
	_moment_strip = _panel(UIStyle.goal_panel())
	_moment_strip.visible = false
	var mh := HBoxContainer.new(); mh.add_theme_constant_override("separation", 10)
	var mv := VBoxContainer.new()
	_moment_title = _lbl("", 13, Palette.GOLD)
	_moment_sub = _lbl("", 10, Palette.WHITE_MID, HORIZONTAL_ALIGNMENT_LEFT, Fonts.W_MEDIUM)
	mv.add_child(_moment_title); mv.add_child(_moment_sub)
	_moment_score = _lbl("", 15, Palette.WHITE, HORIZONTAL_ALIGNMENT_RIGHT, Fonts.W_BOLD, true)
	mh.add_child(mv); mh.add_child(_spacer()); mh.add_child(_moment_score)
	_moment_strip.add_child(mh)
	_body_vbox.add_child(_moment_strip)

	_build_dock()

func _mk_bar(accent: Color) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size = Vector2(0, 8)
	b.add_theme_stylebox_override("background", UIStyle.bar_track())
	b.add_theme_stylebox_override("fill", UIStyle.bar_fill(accent))
	return b

func _build_dock() -> void:
	var dock := HBoxContainer.new(); dock.add_theme_constant_override("separation", 12)
	_autosim_bar = Button.new()
	_autosim_bar.flat = true
	_autosim_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_autosim_bar.custom_minimum_size = Vector2(0, 56)
	_autosim_bar.add_theme_stylebox_override("normal", UIStyle.autosim_bar(Palette.COUNTRY_ACCENT_SA))
	_autosim_bar.add_theme_stylebox_override("hover", UIStyle.autosim_bar(Palette.COUNTRY_ACCENT_SA))
	_autosim_bar.add_theme_stylebox_override("pressed", UIStyle.autosim_bar(Palette.COUNTRY_ACCENT_SA))
	_autosim_bar.pressed.connect(_toggle_play)
	var ah := HBoxContainer.new()
	ah.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ah.offset_left = 12; ah.offset_right = -12
	ah.add_theme_constant_override("separation", 10)
	ah.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_play_lbl = _lbl("▶▶", 14, Palette.COUNTRY_ACCENT_SA)
	_sim_progress = _mk_bar(Palette.COUNTRY_ACCENT_SA)
	_sim_progress.custom_minimum_size = Vector2(0, 5)
	_sim_progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sim_progress.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_speed_lbl = _lbl("1×", 11, Palette.WHITE_MID)
	ah.add_child(_play_lbl); ah.add_child(_sim_progress); ah.add_child(_speed_lbl)
	_autosim_bar.add_child(ah)

	# Speed cycle button (small, right of the bar) + Boost.
	var speed_btn := Button.new()
	speed_btn.text = "»"; speed_btn.custom_minimum_size = Vector2(34, 56)
	speed_btn.pressed.connect(_cycle_speed)

	var boost_wrap := Control.new()
	boost_wrap.custom_minimum_size = Vector2(60, 60)
	_boost_btn = Button.new()
	_boost_btn.text = "⚡\nBOOST"
	_boost_btn.add_theme_font_size_override("font_size", 9)
	_boost_btn.add_theme_color_override("font_color", Palette.WHITE)
	Fonts.weigh(_boost_btn, Fonts.W_BOLD)
	_boost_btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_boost_btn.add_theme_stylebox_override("normal", UIStyle.boost_button())
	_boost_btn.add_theme_stylebox_override("hover", UIStyle.boost_button())
	_boost_btn.add_theme_stylebox_override("pressed", UIStyle.boost_button())
	_boost_btn.pressed.connect(_on_boost)
	boost_wrap.add_child(_boost_btn)
	_boost_badge = _lbl("100%", 9, Color(0, 0, 0), HORIZONTAL_ALIGNMENT_CENTER)
	_boost_badge.add_theme_stylebox_override("normal", UIStyle.boost_badge())
	_boost_badge.custom_minimum_size = Vector2(30, 22)
	_boost_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_boost_badge.position = Vector2(36, -4)
	boost_wrap.add_child(_boost_badge)

	dock.add_child(_autosim_bar); dock.add_child(speed_btn); dock.add_child(boost_wrap)
	_body_vbox.add_child(dock)

func _build_result_box() -> void:
	_result_box = VBoxContainer.new()
	_result_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_result_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_result_box.add_theme_constant_override("separation", 10)
	_result_box.visible = false
	_body.add_child(_result_box)

func _build_overlays() -> void:
	_overlay = _make_overlay_root()
	add_child(_overlay)
	_ov_body = _overlay.get_node("Center/Card/V") as VBoxContainer
	_ov_body.add_theme_constant_override("separation", 0)
	_ov_banner = _overlay.get_node("Center/Banner") as Label
	_overlay.visible = false

	_km_overlay = _make_overlay_root()
	add_child(_km_overlay)
	_km_body = _km_overlay.get_node("Center/Card/V") as VBoxContainer
	_km_body.add_theme_constant_override("separation", 0)
	_km_banner = _km_overlay.get_node("Center/Banner") as Label
	_km_overlay.visible = false

	_break_overlay = _make_overlay_root()
	add_child(_break_overlay)
	_break_body = _break_overlay.get_node("Center/Card/V") as VBoxContainer
	_break_body.add_theme_constant_override("separation", 4)
	_break_banner = _break_overlay.get_node("Center/Banner") as Label
	_break_overlay.visible = false

func _make_overlay_root() -> Control:
	var o := Control.new()
	o.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var scrim := ColorRect.new()
	scrim.color = Color(0, 0, 0, 0.78)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	o.add_child(scrim)
	var center := VBoxContainer.new()
	center.name = "Center"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.offset_left = 20; center.offset_top = 120; center.offset_right = -20; center.offset_bottom = -120
	center.add_theme_constant_override("separation", 9)
	o.add_child(center)
	var banner := _lbl("", 13, Color(0, 0, 0), HORIZONTAL_ALIGNMENT_CENTER)
	banner.name = "Banner"
	banner.add_theme_stylebox_override("normal", UIStyle.banner("moment"))
	center.add_child(banner)
	var card := _panel(UIStyle.moment_card("moment"))
	card.name = "Card"
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new(); v.name = "V"; v.add_theme_constant_override("separation", 9)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(v)
	center.add_child(card)
	return o

func _choice(txt: String, accent: Color) -> Button:
	var b := Button.new()
	b.text = txt
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 14)
	b.add_theme_color_override("font_color", Palette.WHITE)
	Fonts.weigh(b, Fonts.W_BOLD)
	b.add_theme_stylebox_override("normal", UIStyle.choice_btn(accent))
	b.add_theme_stylebox_override("hover", UIStyle.choice_btn(accent))
	b.add_theme_stylebox_override("pressed", UIStyle.choice_btn(accent))
	return b

# ---------------------------------------------------------------- public API

func set_session(s: MatchSession, team_name: String, opp_name: String,
		my_stars: float = 2.5, opp_stars: float = 2.5, my_code: int = 0, opp_code: int = 1) -> void:
	_session = s
	_team_name = team_name
	_opp_name = opp_name
	_my_stars = my_stars; _opp_stars = opp_stars
	_my_code = my_code; _opp_code = opp_code

func boot() -> void:
	if _session == null:
		return
	_cursor = 0
	_event_count = _session.events().size()
	_render()

func event_count() -> int:
	return _event_count

func overlay_visible() -> bool:
	return _overlay.visible

func km_overlay_visible() -> bool:
	return _km_overlay.visible

func boost_enabled() -> bool:
	return not _boost_btn.disabled

func review_ok_visible() -> bool:
	return _ov_ok_shown

func flash_text() -> String:
	return _flash

# ---------------------------------------------------------------- playback

func _innings_at_cursor() -> int:
	for k in range(_cursor, -1, -1):
		if k < _session.events().size():
			var e: Dictionary = _session.events()[k]
			if e.has("innings"):
				return e["innings"]
	return 1

func _over_at_cursor() -> int:
	for k in range(_cursor, -1, -1):
		if k < _session.events().size():
			var e: Dictionary = _session.events()[k]
			if e.has("over"):
				return e["over"]
	return 0

func step(delta: int) -> void:
	_cursor = clampi(_cursor + delta, 0, _event_count)
	_render()
	if delta > 0:
		var km := _session.key_moment_offer(_cursor)
		if not km.is_empty():
			_pending_km = km
			_resume_after_km = _playing
			_show_km_overlay(km)
			pause()
			return
		var offer := _session.review_offer(_cursor)
		if not offer.is_empty():
			_pending_review = offer
			_resume_after_review = _playing
			_show_overlay(offer)
			pause()
			return
		if _cursor >= 1 and _session.events()[_cursor - 1]["type"] == "innings_break":
			_resume_after_break = _playing
			_show_break_overlay()
			pause()
			return
		var m := MatchViewBuilder.moment_at(_session.result(), _session.player(), _cursor)
		if not m.is_empty():
			_show_moment_strip(m)
			if _playing:
				_tick.stop()
				_flash_timer.start(FLASH_HOLD)
				return
		if _flash != "" and _playing:
			_tick.stop()
			_flash_timer.start(FLASH_HOLD)
			return
	if _cursor >= _event_count:
		pause()

func seek_to(cursor: int) -> void:
	_cursor = clampi(cursor, 0, _event_count)
	_render()
	# Scrubbing to a non-trigger cursor clears any overlay left showing.
	_overlay.visible = false
	_km_overlay.visible = false
	_break_overlay.visible = false
	var km := _session.key_moment_offer(_cursor)
	if not km.is_empty():
		_pending_km = km
		_show_km_overlay(km)
		return
	var offer := _session.review_offer(_cursor)
	if not offer.is_empty():
		_pending_review = offer
		_show_overlay(offer)
		return
	if _cursor >= 1 and _cursor <= _session.events().size() \
			and _session.events()[_cursor - 1]["type"] == "innings_break":
		_show_break_overlay()

func play() -> void:
	if _cursor >= _event_count: return
	_playing = true
	_tick.start()
	_play_lbl.text = "⏸"

func pause() -> void:
	_playing = false
	_tick.stop()
	_play_lbl.text = "▶▶"

func set_speed(mult: float) -> void:
	_tick.wait_time = BASE_TICK / mult

func _toggle_play() -> void:
	if _playing: pause()
	else: play()

func _cycle_speed() -> void:
	_speed_idx = (_speed_idx + 1) % SPEEDS.size()
	set_speed(SPEEDS[_speed_idx])
	_speed_lbl.text = "%d×" % int(SPEEDS[_speed_idx])

func _on_tick() -> void:
	step(1)

func _on_flash_done() -> void:
	if _playing:
		_tick.start()

# ---------------------------------------------------------------- boost

func _on_boost() -> void:
	var inn := _innings_at_cursor()
	var next_over := mini(_over_at_cursor() + 1, 20)
	if not _session.can_boost(inn, next_over):
		return
	_session.decide_boost(inn, next_over)
	_event_count = _session.events().size()
	_render()

func _update_boost_button() -> void:
	var st := _session.boost_state(_cursor)
	if st["draining"]:
		_boost_btn.disabled = true
		_boost_badge.text = "ON"
		return
	var inn := _innings_at_cursor()
	var next_over := mini(_over_at_cursor() + 1, 20)
	_boost_btn.disabled = not _session.can_boost(inn, next_over)
	_boost_badge.text = "%d%%" % roundi(st["fill"] * 100.0)

# T10 mini scorecard strip: title/sub from moment_at, live score + context from
# the already-built MatchView (DSC5 - no new numbers).
func _show_moment_strip(m: Dictionary) -> void:
	var v := MatchViewBuilder.build_rich(_session.result(), _session.player(), _cursor,
		_team_name, _opp_name, _my_stars, _opp_stars, _my_code, _opp_code)
	_moment_title.text = m["title"]
	var ctx := ""
	if m["kind"] == "you_bowl":
		ctx = v.current_line
	elif not v.striker.is_empty() and not v.nonstriker.is_empty():
		ctx = "%s %d* & %s %d*" % [v.striker["name"], v.striker["runs"],
			v.nonstriker["name"], v.nonstriker["runs"]]
	_moment_sub.text = m["sub"] if ctx == "" else "%s · %s" % [m["sub"], ctx]
	_moment_score.text = "%s (%s)" % [v.score_big, v.score_meta.get_slice(" · ", 0)]
	_moment_strip.visible = true

func moment_strip_visible() -> bool:
	return _moment_strip.visible

# ---------------------------------------------------------------- DRS overlay

# DRS card (v4): reuses the Key Moment skeleton (ctx → actor → glyph → narr →
# choices), blue banner, actor = the dismissed player, accept=RED / review=BLUE.
func _show_overlay(_offer: Dictionary) -> void:
	_ov_ok_shown = false
	_ov_banner.text = "📺 DRS REVIEW"
	_ov_banner.add_theme_stylebox_override("normal", UIStyle.banner("drs"))
	_overlay.get_node("Center/Card").add_theme_stylebox_override("panel", UIStyle.moment_card("drs"))
	_build_drs_body()
	_overlay.visible = true

# DRS decision moment card (spec 2026-07-04 DT8): names who fell + the dismissal
# flavour, and SHOWS the drawn overturn odds on the REVIEW button — the number on
# the card is exactly the number the re-sim rolls.
func _build_drs_body() -> void:
	for c in _ov_body.get_children(): c.queue_free()
	var v := MatchViewBuilder.build_rich(_session.result(), _session.player(), _cursor,
		_team_name, _opp_name, _my_stars, _opp_stars, _my_code, _opp_code)
	var reviews := _session.reviews_left()
	var m := _pending_review
	var flavour_label: String = "LBW" if m.get("flavour", "") == "lbw" else "CAUGHT BEHIND"
	_ov_body.add_child(_lbl("%s · DRS REVIEW" % v.score_big, 10, Palette.BLUE, HORIZONTAL_ALIGNMENT_CENTER))
	# The dismissed batter: the hero's own card, or a teammate chip from the offer.
	var actor: Dictionary
	var caption := "Given out %s" % flavour_label
	if bool(m.get("is_player", true)):
		actor = v.player_bat
	else:
		var surname := PlayerNames.for_position(_team_name, _my_code, int(m.get("batter_pos", 3)))
		actor = {"name": PlayerNames.upper(_team_name, _my_code, int(m.get("batter_pos", 3))),
			"badge": PlayerNames.badge(surname),
			"runs": int(m.get("batter_runs", 0)), "balls": int(m.get("batter_balls", 0)),
			"ovr": 0, "stars": _my_stars}
		caption = "Your No.%d · given out %s" % [int(m.get("batter_pos", 3)), flavour_label]
	if int(m.get("batter_balls", 0)) >= DRSMoments.SET_BALLS:
		caption += " · was set"
	_ov_body.add_child(_actor_card(actor, caption))
	var glyph := _lbl("📺", 42, Palette.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	glyph.size_flags_vertical = Control.SIZE_EXPAND_FILL
	glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_ov_body.add_child(glyph)
	var narr := RichTextLabel.new()
	narr.bbcode_enabled = true; narr.fit_content = true; narr.scroll_active = false
	narr.autowrap_mode = TextServer.AUTOWRAP_WORD
	narr.add_theme_font_size_override("normal_font_size", 13)
	narr.add_theme_font_override("normal_font", Fonts.italic())  # narration = body italic
	narr.add_theme_color_override("default_color", Palette.WHITE_SOFT)
	var who := "you" if bool(m.get("is_player", true)) else "your batter"
	var hold_line := "Burn the review now, or hold it?" if not bool(m.get("death", false)) \
		else "Last overs — use it or lose it."
	narr.text = "[center]Umpire's given %s [color=#ffd166]out[/color] — %s. %s[/center]" \
		% [who, flavour_label.to_lower(), hold_line]
	_ov_body.add_child(narr)
	var ch := HBoxContainer.new(); ch.add_theme_constant_override("separation", 8)
	ch.add_child(_two_line_btn("ACCEPT", "Take the walk", Palette.RED, review_no))
	var pct := int(round(float(m.get("p_shown", 0.0)) * 100.0))
	var stake := ("%d%% to overturn · %d left" % [pct, reviews]) if reviews > 0 else "No reviews left"
	var review_btn := _two_line_btn("REVIEW", stake, Palette.BLUE, review_yes)
	review_btn.disabled = reviews <= 0
	ch.add_child(review_btn)
	_ov_body.add_child(ch)

func _build_drs_outcome(msg: String, success: bool, detail: String) -> void:
	for c in _ov_body.get_children(): c.queue_free()
	_ov_body.add_child(_spacer())
	_ov_body.add_child(_lbl(msg, 24, Palette.GREEN if success else Palette.RED, HORIZONTAL_ALIGNMENT_CENTER))
	_ov_body.add_child(_lbl(detail, 11, Palette.WHITE_MID, HORIZONTAL_ALIGNMENT_CENTER))
	_ov_body.add_child(_spacer())
	_ov_body.add_child(_two_line_btn("OK", "", Palette.SURFACE_2, review_ok))

func review_yes() -> void:
	if not _pending_review.is_empty():
		var bid: Array = _pending_review["ball_id"]
		_session.decide_review(bid)
		_event_count = _session.events().size()
		var success := not _session.ball_is_wicket(bid)
		var msg := "✅ NOT OUT" if success else "❌ STILL OUT"
		var detail := ("Ultra-edge: no contact · review retained" if success
			else "Umpire's call stands — %d review%s left" % [_session.reviews_left(), "" if _session.reviews_left() == 1 else "s"])
		_build_drs_outcome(msg, success, detail)
		_ov_ok_shown = true
	_pending_review = {}
	_render()

func review_no() -> void:
	_overlay.visible = false
	_pending_review = {}
	_render()
	_resume_play_after_decision()

func review_ok() -> void:
	_overlay.visible = false
	_ov_ok_shown = false
	_render()
	_resume_play_after_decision()

func _resume_play_after_decision() -> void:
	if _resume_after_review and _cursor < _event_count:
		_resume_after_review = false
		play()

# ---------------------------------------------------------------- Key Moment

func _show_km_overlay(km: Dictionary) -> void:
	var lever: String = km.get("lever", "intent")
	_km_banner.text = "🎯 KEY MOMENT" if lever == "bowling" else "⚡ KEY MOMENT ⚡"
	_km_banner.add_theme_stylebox_override("normal", UIStyle.banner("moment"))
	_km_overlay.get_node("Center/Card").add_theme_stylebox_override("panel", UIStyle.moment_card("moment"))
	_build_km_body(km, lever)
	_km_overlay.visible = true

# The enriched card body (in-match v2 amendment): ctx → actor mini-card → scene
# glyph (expand row) → narration → two choices with stake sublabels. Rebuilt each show.
func _build_km_body(km: Dictionary, lever: String) -> void:
	for c in _km_body.get_children(): c.queue_free()
	var v := MatchViewBuilder.build_rich(_session.result(), _session.player(), _cursor,
		_team_name, _opp_name, _my_stars, _opp_stars, _my_code, _opp_code)
	var ct := _km_content(km, lever)
	var from_over: int = km.get("from_over", 7)
	# Ctx
	var ctx := _lbl("%s · %d OVERS LEFT · %s" % [v.score_big, maxi(21 - from_over, 0), ct["phase"]],
		10, Palette.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_km_body.add_child(ctx)
	# Actor mini-card (bowler for bowling moments, on-strike batter otherwise)
	var actor: Dictionary = v.bowler if lever == "bowling" else v.striker
	_km_body.add_child(_actor_card(actor, ct["job"]))
	# Scene glyph — the only expanding row (eats the slack, no dead gap)
	var glyph := _lbl(ct["glyph"], 42, Palette.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	glyph.size_flags_vertical = Control.SIZE_EXPAND_FILL
	glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_km_body.add_child(glyph)
	# Narration (RichText so the named options highlight gold)
	var narr := RichTextLabel.new()
	narr.bbcode_enabled = true; narr.fit_content = true; narr.scroll_active = false
	narr.autowrap_mode = TextServer.AUTOWRAP_WORD
	narr.add_theme_font_size_override("normal_font_size", 13)
	narr.add_theme_font_override("normal_font", Fonts.italic())  # narration = body italic
	narr.add_theme_color_override("default_color", Palette.WHITE_SOFT)
	narr.text = "[center]%s[/center]" % ct["narr"]
	_km_body.add_child(narr)
	# Choices (each carries its real offer index so display order can differ from the
	# offer order — bowling always shows PACE-left / SPIN-right regardless of offer order)
	var ch := HBoxContainer.new(); ch.add_theme_constant_override("separation", 8)
	for cc in ct["choices"]:
		var idx: int = cc["idx"]
		ch.add_child(_two_line_btn(cc["verb"], cc["stake"], cc["accent"], func(): km_press(idx)))
	_km_body.add_child(ch)

# The actor mini-card: portrait ring (real ★ tier) + name + job tag + real stats.
# Works for any actor dict (batter → runs/balls, bowler → econ); shared by KM + DRS.
func _actor_card(actor: Dictionary, job: String) -> PanelContainer:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.45); sb.set_corner_radius_all(9)
	sb.content_margin_left = 10; sb.content_margin_right = 10
	sb.content_margin_top = 10; sb.content_margin_bottom = 10
	var p := _panel(sb)
	var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 12)
	var ring := _panel(UIStyle.portrait_ring(Palette.skill_ring(actor.get("stars", 2.5))))
	ring.custom_minimum_size = Vector2(62, 78)
	var ini := _lbl(actor.get("badge", ""), 15, Palette.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	ini.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ring.add_child(ini)
	var vb := VBoxContainer.new(); vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(_lbl(actor.get("name", "—"), 17, Palette.GOLD))
	vb.add_child(_lbl(job, 10, Palette.WHITE_MID))
	# "skill N", not "OVR N" -- Nico read OVR as an over number (playtest T3).
	# Teammates carry no modelled skill (ovr 0) -- omit the tag rather than "skill 0".
	var skill_tag: String = " · skill %d" % actor.get("ovr", 0) if int(actor.get("ovr", 0)) > 0 else ""
	var stats: String = ("econ %s%s" % [actor.get("econ", "0.0"), skill_tag]) if actor.has("econ") \
		else "%d (%d)%s" % [actor.get("runs", 0), actor.get("balls", 0), skill_tag]
	vb.add_child(_lbl(stats, 9, Palette.WHITE_DIM))
	h.add_child(ring); h.add_child(vb)
	p.add_child(h)
	return p

# A two-line choice tile (verb + stake); the whole tile is the tap target. Shared
# by KM choices and DRS accept/review.
func _two_line_btn(verb: String, stake: String, accent: Color, on_press: Callable) -> Button:
	var b := Button.new()
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 54)
	b.add_theme_stylebox_override("normal", UIStyle.choice_btn(accent))
	b.add_theme_stylebox_override("hover", UIStyle.choice_btn(accent))
	b.add_theme_stylebox_override("pressed", UIStyle.choice_btn(accent))
	b.pressed.connect(on_press)
	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var verb_l := _lbl(verb, 14, Palette.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	verb_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(verb_l)
	if stake != "":
		var stake_l := _lbl(stake, 9, Palette.WHITE_MID, HORIZONTAL_ALIGNMENT_CENTER)
		stake_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(stake_l)
	b.add_child(vb)
	return b

# Card copy per moment type. Batting verbs/stakes are design's v2 copy (the mechanic
# = intent band, so the label is free to change). Bowling keeps the REAL pace/spin
# labels (the lever that re-sims) — design's attack/contain framing is a different
# mechanic, flagged in the review, not a label swap.
func _km_content(km: Dictionary, lever: String) -> Dictionary:
	var title: String = km["title"]
	var glyph := title.substr(0, title.find(" ")) if title.find(" ") > 0 else "⚡"
	const G := "[color=#ffd166]%s[/color]"
	if lever == "bowling":
		return _bowling_content(km, glyph, title)
	var verbs: Array; var stakes: Array; var phase: String; var job: String; var narr: String
	if "Wicket Crisis" in title:
		phase = "REBUILD"; job = "On strike · steady the ship"
		narr = "Wicket down. %s and protect the innings, or %s and seize the momentum?" % [G % "Rebuild", G % "counter-attack"]
		verbs = ["REBUILD", "COUNTER →"]; stakes = ["Protect wickets", "Seize momentum"]
	elif "Death Plan" in title:
		phase = "DEATH"; job = "On strike · time to accelerate"
		narr = "Death overs. %s for a reliable 50+, or %s and go boom-or-bust?" % [G % "Twos & fours", G % "six-or-bust"]
		verbs = ["2s & 4s", "BIG HITS →"]; stakes = ["Reliable 50+", "Boom or bust"]
	else:
		phase = "MIDDLE"; job = "On strike · set the tempo"
		narr = "Powerplay's done. %s and build a platform, or %s and keep the rate climbing?" % [G % "Anchor", G % "hunt"]
		verbs = ["ANCHOR", "HUNT →"]; stakes = ["Build a platform", "Chase the rate"]
	return {"glyph": glyph, "phase": phase, "job": job, "narr": narr, "choices": [
		{"verb": verbs[0], "stake": stakes[0], "accent": Palette.BLUE, "idx": 0},
		{"verb": verbs[1], "stake": stakes[1], "accent": Palette.RED, "idx": 1}]}

# Bowling KM (v3.1): the real lever is Pace vs Spin. Display PACE-left (blue) /
# SPIN-right (red) regardless of the offer's internal order, mapping each tile to its
# true offer index by kind so the press selects the right mechanic.
func _bowling_content(km: Dictionary, glyph: String, title: String) -> Dictionary:
	var pace_idx := 0; var spin_idx := 1
	for i in range(km["choices"].size()):
		if km["choices"][i].get("kind", -1) == BowlingPlan.Kind.SPIN: spin_idx = i
		else: pace_idx = i
	const G := "[color=#ffd166]%s[/color]"
	var narr: String; var pace_stake: String; var spin_stake: String
	if "New Batsman" in title:
		narr = "New man in. Test him with %s and bounce, or %s to tie him down early?" % [G % "pace", G % "spin"]
		pace_stake = "Test with bounce"; spin_stake = "Tie him down"
	elif "Death Defence" in title:
		narr = "Defending at the death. Back your %s for yorkers, or %s to take the pace off?" % [G % "pace", G % "spin"]
		pace_stake = "Yorkers"; spin_stake = "Take pace off"
	else:
		narr = "Powerplay over. Bang in %s and hit the deck, or bring %s to choke the middle?" % [G % "pace", G % "spin"]
		pace_stake = "Hit the deck"; spin_stake = "Choke the middle"
	return {"glyph": glyph, "phase": "BOWLING", "job": "Your over · set the plan", "narr": narr, "choices": [
		{"verb": "PACE", "stake": pace_stake, "accent": Palette.BLUE, "idx": pace_idx},
		{"verb": "SPIN →", "stake": spin_stake, "accent": Palette.RED, "idx": spin_idx}]}

func km_press(i: int) -> void:
	_km_overlay.visible = false
	if not _pending_km.is_empty():
		var lever: String = _pending_km.get("lever", "intent")
		if lever == "bowling":
			var kind: int = _pending_km["choices"][i]["kind"]
			_session.decide_bowling_key_moment(_pending_km["from_over"], kind)
		else:
			var band: int = _pending_km["choices"][i]["band"]
			_session.decide_key_moment(_pending_km["from_over"], band)
		_event_count = _session.events().size()
	_pending_km = {}
	_render()
	if _resume_after_km and _cursor < _event_count:
		_resume_after_km = false
		play()

# ---------------------------------------------------------------- innings break

# Full first-innings scorecard + commentary (T10, DSC6-DSC9). Text-only banner
# (DSC10 - no emoji in new copy).
func _show_break_overlay() -> void:
	_break_banner.text = "INNINGS BREAK"
	_break_banner.add_theme_stylebox_override("normal", UIStyle.banner("moment"))
	_break_overlay.get_node("Center/Card").add_theme_stylebox_override("panel", UIStyle.moment_card("moment"))
	for c in _break_body.get_children(): c.queue_free()
	var mr := _session.result()
	var bat_team := _team_name if mr.player_bats_first else _opp_name
	var bat_code := _my_code if mr.player_bats_first else _opp_code
	var chase_team := _opp_name if mr.player_bats_first else _team_name
	var card := MatchViewBuilder.build_scorecard(mr, _session.player(), bat_team, bat_code, chase_team)
	_break_body.add_child(_lbl(card["header"], 13, Palette.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	for r in card["rows"]:
		var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 8)
		var nm := _lbl(r["name"], 11, Palette.GOLD if r["is_player"] else Palette.WHITE_SOFT)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(nm)
		h.add_child(_lbl(r["how"], 9, Palette.WHITE_DIM, HORIZONTAL_ALIGNMENT_RIGHT, Fonts.W_MEDIUM))
		var sc := _lbl("%d (%d)" % [r["runs"], r["balls"]], 11, Palette.WHITE, HORIZONTAL_ALIGNMENT_RIGHT, Fonts.W_BOLD, true)
		sc.custom_minimum_size = Vector2(58, 0)
		h.add_child(sc)
		_break_body.add_child(h)
	if card["dnb"] != "":
		_break_body.add_child(_lbl(card["dnb"], 9, Palette.WHITE_DIM))
	var narr := RichTextLabel.new()
	narr.bbcode_enabled = true; narr.fit_content = true; narr.scroll_active = false
	narr.autowrap_mode = TextServer.AUTOWRAP_WORD
	narr.add_theme_font_size_override("normal_font_size", 12)
	narr.add_theme_font_override("normal_font", Fonts.italic())
	narr.add_theme_color_override("default_color", Palette.WHITE_SOFT)
	narr.size_flags_vertical = Control.SIZE_EXPAND_FILL
	narr.text = "[center]%s[/center]" % card["commentary"]
	_break_body.add_child(narr)
	_break_body.add_child(_two_line_btn("CONTINUE", "Start the chase", Palette.GOLD, break_continue))
	_break_overlay.visible = true

func break_continue() -> void:
	_break_overlay.visible = false
	_render()
	if _resume_after_break and _cursor < _event_count:
		_resume_after_break = false
		play()

func break_overlay_visible() -> bool:
	return _break_overlay.visible

# ---------------------------------------------------------------- render

func _render() -> void:
	var v := MatchViewBuilder.build_rich(_session.result(), _session.player(), _cursor,
		_team_name, _opp_name, _my_stars, _opp_stars, _my_code, _opp_code)
	_flash = v.highlight_text
	_moment_strip.visible = false

	# Header
	_bat_name.text = _team_name.to_upper()
	_opp_name_lbl.text = _opp_name.to_upper()
	_bat_badge.text = PlayerNames.badge(_team_name)
	_opp_badge.text = PlayerNames.badge(_opp_name)

	# Scorebar
	_score_big.text = v.score_big
	_score_meta.text = v.score_meta
	_tag_sub.text = v.innings_tag
	_target_big.text = v.target_big
	_target_sub.text = v.target_sub

	if v.finished:
		_render_result(v)
		_update_boost_button()
		_set_sim_progress()
		return
	_batters.visible = true; _bowler_row.visible = true; _body_vbox.visible = true; _result_box.visible = false

	_render_batters(v)
	# Bowler row
	if v.bowler:
		_bowl_name.text = v.bowler.get("name", "—")
		_bowl_stat.text = _stars_str(v.bowler.get("stars", 2.5))
		_bowl_fig.text = v.bowler.get("econ", "0.0")
	# Commentary
	_comm_chip.text = v.lang
	_comm_lbl.text = v.commentary
	# Run-rate chart
	var chart_accent: Color = Palette.country_set(v.my_code)["accent"]
	_chart.set_data(v.chart, chart_accent)
	# This over
	for c in _over_grid.get_children(): c.queue_free()
	for cell in v.this_over:
		_over_grid.add_child(_ball_cell(cell))
	# Partnership
	if v.partnership:
		_pship_names.text = v.partnership.get("names", "—")
		_pship_runs.text = "%d (%d)" % [v.partnership.get("runs", 0), v.partnership.get("balls", 0)]
		_pship_bar.value = v.partnership.get("frac", 0.0) * 100.0
	else:
		_pship_names.text = "—"; _pship_runs.text = ""; _pship_bar.value = 0

	_update_boost_button()
	_set_sim_progress()

func _set_sim_progress() -> void:
	_sim_progress.value = (float(_cursor) / maxf(_event_count, 1.0)) * 100.0

func _render_batters(v: MatchView) -> void:
	for c in _batters.get_children(): c.queue_free()
	_batters.add_child(_batter_chip(v.striker))
	_batters.add_child(_batter_chip(v.nonstriker))

func _batter_chip(b: Dictionary) -> PanelContainer:
	var on: bool = b.get("on_strike", false)
	var p := _panel(UIStyle.goal_panel() if on else UIStyle.panel())
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 9)
	var ring := _panel(UIStyle.portrait_ring(Palette.skill_ring(b.get("stars", 2.5))))
	ring.custom_minimum_size = Vector2(30, 36)
	var ini := _lbl(b.get("badge", ""), 11, Palette.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	ini.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ring.add_child(ini)
	var vb := VBoxContainer.new()
	var nm := _lbl(b.get("name", "—"), 13, Palette.GOLD if on else Palette.WHITE)
	var rn := _lbl("%s%d* (%d)" % ["★ " if on else "", b.get("runs", 0), b.get("balls", 0)], 11, Palette.WHITE_MID, HORIZONTAL_ALIGNMENT_LEFT, Fonts.W_BOLD, true)
	vb.add_child(nm); vb.add_child(rn)
	h.add_child(ring); h.add_child(vb)
	p.add_child(h)
	return p

func _ball_cell(cell: Dictionary) -> Control:
	var kind: String = cell.get("kind", "dot")
	var p := _panel(UIStyle.ball_cell(kind))
	p.custom_minimum_size = Vector2(38, 38)
	var l := _lbl(cell.get("label", "·"), 14, UIStyle.ball_cell_text(kind), HORIZONTAL_ALIGNMENT_CENTER, Fonts.W_BOLD, true)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	p.add_child(l)
	return p

func _render_result(v: MatchView) -> void:
	_batters.visible = false; _bowler_row.visible = false; _body_vbox.visible = false
	_result_box.visible = true
	for c in _result_box.get_children(): c.queue_free()
	_tag_sub.text = "RESULT"
	_score_big.text = "WON" if v.won else "LOST"
	_score_big.add_theme_color_override("font_color", Palette.GREEN if v.won else Palette.RED)
	_target_big.text = "+1" if v.won else ""
	_target_sub.text = "LEAGUE POINT" if v.won else ""
	_comm_lbl.text = v.commentary

	var head := _lbl(v.result_text, 22, Palette.GREEN if v.won else Palette.RED, HORIZONTAL_ALIGNMENT_CENTER, Fonts.W_HEADLINE)
	head.autowrap_mode = TextServer.AUTOWRAP_WORD
	head.size_flags_horizontal = Control.SIZE_FILL
	_result_box.add_child(head)
	for line in v.innings_lines:
		var row := _panel(UIStyle.panel())
		row.size_flags_horizontal = Control.SIZE_FILL
		var h := HBoxContainer.new()
		var lab := _lbl(line.get("label", ""), 13, Palette.WHITE)
		lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(lab)
		h.add_child(_lbl(line.get("score", ""), 13, Palette.GOLD, HORIZONTAL_ALIGNMENT_RIGHT))
		row.add_child(h)
		_result_box.add_child(row)
	var cta := _choice("CONTINUE ▶", Palette.GOLD)
	cta.add_theme_color_override("font_color", Color("1a1205"))
	cta.pressed.connect(func(): back.emit())
	_result_box.add_child(cta)

func _stars_str(stars: float) -> String:
	var n := int(round(stars))
	return "★".repeat(maxi(n, 1))
