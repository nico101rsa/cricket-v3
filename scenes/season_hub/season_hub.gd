extends Control

# The Season Hub — the game's home screen, hi-fi v2 (spec
# docs/superpowers/specs/2026-06-18-season-hub-hifi-v2-spec.md). A single dense
# screen (no scroll, no league table) built on the shared Palette + UIStyle
# tokens. Renders a SeasonView; never calls resolvers. Boot is explicit (not
# _ready-auto) so tests inject a view without a sim/save.
#
# Hard design rules honoured here: never show raw PWR/COM/ATT/CON (only OVR +
# career averages); position pill shows "—" until a result exists.

const HERO_CAP := preload("res://assets/portraits/hero-cap.png")
const RARITY := {"Common": Palette.COMMON, "Rare": Palette.RARE, "Legendary": Palette.LEGENDARY}
const BOOT_SEED := 20260615
const AFF_FULL := 5.0   # affinity loyalty "full" (seasons-stayed; display-only)

# Tapping a PLAYED fixture opens that match's ball-by-ball replay (main → _push_match).
signal open_match(match_index: int)
# Tapping the CTA on the live path plays your next fixture (main → _play_next).
signal play_next(team_index: int)
# Corner chrome (stubbed in main for now).
signal open_settings()
signal open_info()

@onready var _root: VBoxContainer = $Margin/Root

var _view: SeasonView
var _player: Player
var _career: CareerState
var _season: SeasonResult
var _play: SeasonPlay   # live forward-play driver (null on the scrub/test path)

func _ready() -> void:
	$CornerInfo.pressed.connect(func(): open_info.emit())
	$CornerGear.pressed.connect(func(): open_settings.emit())
	$CornerInfo.add_theme_stylebox_override("normal", UIStyle.corner_btn())
	$CornerGear.add_theme_stylebox_override("normal", UIStyle.corner_btn())
	_root.get_node("CTA").pressed.connect(_on_cta)
	_style_static()

func _on_cta() -> void:
	if _play == null or _play.league_done():
		return
	play_next.emit(_play.next_player_opponent()["team_index"])

# Static chrome + label styling applied once. _render only sets text + colours
# that depend on the live data / country.
func _style_static() -> void:
	_root.get_node("TonsPanel").add_theme_stylebox_override("panel", UIStyle.panel())
	_root.get_node("FixturesPanel").add_theme_stylebox_override("panel", UIStyle.panel())
	_root.get_node("CardPanel").add_theme_stylebox_override("panel", UIStyle.panel())
	_root.get_node("JokersPanel").add_theme_stylebox_override("panel", UIStyle.panel())
	_root.get_node("AffinityPanel").add_theme_stylebox_override("panel", UIStyle.panel())
	_root.get_node("CardPanel/PlayerCard/CardInfo/OvrFormRow/OvrTile").add_theme_stylebox_override("panel", UIStyle.ovr_tile())
	_root.get_node("CardPanel/PlayerCard/CardInfo/CareerArea/EmptyState").add_theme_stylebox_override("panel", UIStyle.joker_slot(false))
	# uppercase dim section labels
	for path in ["TonsPanel/TonsRow/TonsCol/TonsCap", "FixturesPanel/FixturesWrap/FixHead/FixHeader",
			"FixturesPanel/FixturesWrap/FixHead/OpensLabel", "JokersPanel/JokersWrap/JokHead/JokHeader",
			"JokersPanel/JokersWrap/JokHead/JokCount", "AffinityPanel/AffinityRow/AffinityCol/AffinityTop/AffinityLabel",
			"TonsPanel/TonsRow/ContextCol/SeasonLabel", "CardPanel/PlayerCard/CardInfo/RoleLabel"]:
		var l: Label = _root.get_node(path)
		l.add_theme_color_override("font_color", Palette.WHITE_DIM)
		l.add_theme_font_size_override("font_size", 9)
	# big ₸ value
	var tons: Label = _root.get_node("TonsPanel/TonsRow/TonsCol/TonsChip")
	tons.add_theme_color_override("font_color", Palette.GOLD)
	tons.add_theme_font_size_override("font_size", 24)
	# OVR tile text (dark on gold)
	var ovrn: Label = _root.get_node("CardPanel/PlayerCard/CardInfo/OvrFormRow/OvrTile/OvrCol/OvrNum")
	ovrn.add_theme_color_override("font_color", Palette.BG)
	ovrn.add_theme_font_size_override("font_size", 17)
	var ovrc: Label = _root.get_node("CardPanel/PlayerCard/CardInfo/OvrFormRow/OvrTile/OvrCol/OvrCap")
	ovrc.add_theme_color_override("font_color", Palette.BG)
	ovrc.add_theme_font_size_override("font_size", 8)
	# name
	var nm: Label = _root.get_node("CardPanel/PlayerCard/CardInfo/NameLabel")
	nm.add_theme_color_override("font_color", Palette.WHITE)
	nm.add_theme_font_size_override("font_size", 15)
	# empty-state + stat strip text
	var empty_lbl: Label = _root.get_node("CardPanel/PlayerCard/CardInfo/CareerArea/EmptyState/EmptyLabel")
	empty_lbl.add_theme_color_override("font_color", Palette.WHITE_MID)
	empty_lbl.add_theme_font_size_override("font_size", 10)
	_root.get_node("CardPanel/PlayerCard/CardInfo/CareerArea/StatStrip").add_theme_color_override("font_color", Palette.WHITE_SOFT)
	var nextb: Label = _root.get_node("AffinityPanel/AffinityRow/AffinityCol/AffinityTop/NextBonus")
	nextb.add_theme_color_override("font_color", Palette.GOLD)
	nextb.add_theme_font_size_override("font_size", 9)
	_root.get_node("TonsPanel/TonsRow/ContextCol/ProgressLabel").add_theme_color_override("font_color", Palette.WHITE_MID)
	# portrait art + affinity track
	_root.get_node("CardPanel/PlayerCard/Portrait/PortraitTex").texture = HERO_CAP
	_root.get_node("AffinityPanel/AffinityRow/AffinityCol/AffinityBar").add_theme_stylebox_override("background", UIStyle.bar_track())
	# CTA text colours (dark on gold)
	_root.get_node("CTA/CtaCenter/CtaLines/CtaBig").add_theme_color_override("font_color", Palette.BG)
	_root.get_node("CTA/CtaCenter/CtaLines/CtaBig").add_theme_font_size_override("font_size", 16)
	var ctas: Label = _root.get_node("CTA/CtaCenter/CtaLines/CtaSmall")
	ctas.add_theme_color_override("font_color", Color(0, 0, 0, 0.6))
	ctas.add_theme_font_size_override("font_size", 9)

# --- Production boot ---

func boot() -> void:
	if _view != null or _play != null:
		return
	if not SaveManager.has_player():
		return
	var player := SaveManager.load_player()
	var career: CareerState = SaveManager.load_career() if SaveManager.has_career() \
		else CareerResolver.start_career(0)
	var spec := DifficultyLadder.spec_for(career.current_level(), 0)
	var team: Team = career.teams[career.current_team_index]
	var play := SeasonPlay.start(
		player.attributes, team, career.opponents_of_current(),
		spec.make_tour(), BallTuning.new(), InningsTuning.new(), BOOT_SEED, spec)
	set_play(player, career, play)

# --- Sources ---

func set_source(player: Player, career: CareerState, season: SeasonResult) -> void:
	_player = player; _career = career; _season = season
	_rebuild(0)

func set_play(player: Player, career: CareerState, play: SeasonPlay) -> void:
	_player = player; _career = career; _play = play
	set_view(SeasonViewBuilder.build(player, career, play.live_season(), play.played_count()))

func live_play() -> SeasonPlay: return _play
func current_career() -> CareerState: return _career
func has_play_control() -> bool: return _play != null and not _play.league_done()

func _rebuild(index: int) -> void:
	if _player == null or _career == null or _season == null:
		return
	set_view(SeasonViewBuilder.build(_player, _career, _season, index))

func scrub_index() -> int: return _view.scrub_index if _view != null else 0
func season() -> SeasonResult: return _season
func current_view() -> SeasonView: return _view

func step(delta: int) -> void:
	if _view == null:
		return
	_rebuild(clampi(_view.scrub_index + delta, 0, _view.match_count))

# --- Render ---

func set_view(view: SeasonView) -> void:
	_view = view
	_render()

# How many of your fixtures are done (live = committed; scrub = revealed in view).
func _played() -> int:
	if _play != null:
		return _play.played_count()
	var n := 0
	for f in _view.fixtures:
		if f["played"]:
			n += 1
	return n

func _render() -> void:
	if _view == null:
		return
	var cset := Palette.country_set(_view.country)
	_render_topbar(cset)
	_render_tons()
	_render_fixtures(cset)
	_render_card()
	_render_jokers()
	_render_affinity(cset)
	_render_cta(cset)

func _render_topbar(cset: Dictionary) -> void:
	_root.get_node("TopbarPanel").add_theme_stylebox_override("panel",
		UIStyle.header(cset["grad1"], cset["grad2"], cset["glow"]))
	var badge: Label = _root.get_node("TopbarPanel/Header/Badge")
	badge.text = _initials(_view.team_name)
	badge.add_theme_stylebox_override("normal", UIStyle.pill(cset["grad1"].darkened(0.2)))
	badge.add_theme_color_override("font_color", Palette.WHITE)
	var title: Label = _root.get_node("TopbarPanel/Header/TeamId/TitleLabel")
	title.text = _view.team_name
	title.add_theme_color_override("font_color", Palette.WHITE)
	title.add_theme_font_size_override("font_size", 15)
	var stars: Label = _root.get_node("TopbarPanel/Header/TeamId/MetaRow/StarsLabel")
	stars.text = _stars_str(_view.team_stars)
	stars.add_theme_color_override("font_color", Palette.GOLD)
	var chip: Label = _root.get_node("TopbarPanel/Header/TeamId/MetaRow/LevelChip")
	chip.text = _level_word(_view.level).to_upper()
	chip.add_theme_stylebox_override("normal", UIStyle.pill(Color(0, 0, 0, 0.25)))
	chip.add_theme_color_override("font_color", Palette.WHITE_SOFT)
	chip.add_theme_font_size_override("font_size", 9)
	# position pill — "—" / 0 PTS until a result exists (no fake "1st")
	var posn: Label = _root.get_node("TopbarPanel/Header/PosPill/PosNum")
	var pospts: Label = _root.get_node("TopbarPanel/Header/PosPill/PosPts")
	if _played() == 0:
		posn.text = "—"
		pospts.text = "0 PTS"
	else:
		posn.text = _ordinal(_view.player_final_position)
		pospts.text = "%d PTS" % _player_points()
	posn.add_theme_color_override("font_color", Palette.WHITE)
	posn.add_theme_font_size_override("font_size", 17)
	pospts.add_theme_color_override("font_color", Palette.WHITE_MID)
	pospts.add_theme_font_size_override("font_size", 8)
	_root.get_node("TopbarPanel/Header/PosPill").add_theme_stylebox_override("panel", UIStyle.pill(Color(0, 0, 0, 0.28)))

func _render_tons() -> void:
	_root.get_node("TonsPanel/TonsRow/TonsCol/TonsChip").text = "₸ %d" % _view.tons_balance
	_root.get_node("TonsPanel/TonsRow/ContextCol/SeasonLabel").text = "%s · %s" % [
		_level_word(_view.level).to_upper(), _view.tour_name.to_upper()]
	_root.get_node("TonsPanel/TonsRow/ContextCol/ProgressLabel").text = "MATCH %d of %d" % [
		mini(_played() + 1, _view.match_count), _view.match_count]

func _render_fixtures(cset: Dictionary) -> void:
	var box: HBoxContainer = _root.get_node("FixturesPanel/FixturesWrap/FixturesRow/FixturesBox")
	for c in box.get_children():
		c.queue_free()
	var now_idx := _played()   # the about-to-play fixture (0-based)
	for i in range(_view.fixtures.size()):
		var f: Dictionary = _view.fixtures[i]
		var entry := VBoxContainer.new()
		entry.add_theme_constant_override("separation", 2)
		var dot := Button.new()
		dot.name = "Dot"
		dot.custom_minimum_size = Vector2(26, 26)
		var idx := i
		var bg: Color
		var ring := Color(0, 0, 0, 0)
		var label := ""
		var fg := Palette.WHITE_SOFT
		if f["played"]:
			bg = Palette.GREEN_DARK if f["player_won"] else Palette.RED_DARK
			label = "W" if f["player_won"] else "L"
			fg = Palette.WHITE
			dot.pressed.connect(func(): open_match.emit(idx))
		elif i == now_idx:
			bg = cset["grad1"]
			ring = cset["accent"]
			label = "●"
			fg = Palette.WHITE
		else:
			bg = Palette.SURFACE_2
			label = "M%d" % (i + 1)
			fg = Palette.WHITE_DIM
		dot.text = label
		var sb := UIStyle.fixture_dot(bg, ring)
		for st in ["normal", "hover", "pressed", "focus"]:
			dot.add_theme_stylebox_override(st, sb)
		dot.add_theme_color_override("font_color", fg)
		dot.add_theme_color_override("font_color_hover", fg)
		dot.add_theme_font_size_override("font_size", 9)
		entry.add_child(dot)
		var cap := Label.new()
		cap.text = _cap(f["opponent_name"])
		cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cap.add_theme_color_override("font_color", cset["accent"] if i == now_idx else Palette.WHITE_DIM)
		cap.add_theme_font_size_override("font_size", 8)
		entry.add_child(cap)
		box.add_child(entry)
	# stage chips (SF + final) — inert this rung
	var stage: HBoxContainer = _root.get_node("FixturesPanel/FixturesWrap/FixturesRow/StageBox")
	for c in stage.get_children():
		c.queue_free()
	for s in [["SF", "semi"], ["🏆", "final"]]:
		var entry := VBoxContainer.new()
		entry.add_theme_constant_override("separation", 2)
		var chip := Label.new()
		chip.text = s[0]
		chip.custom_minimum_size = Vector2(28, 26)
		chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		chip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		chip.add_theme_stylebox_override("normal", UIStyle.pill(Palette.GOLD_DEEP))
		chip.add_theme_color_override("font_color", Palette.BG)
		chip.add_theme_font_size_override("font_size", 9)
		entry.add_child(chip)
		var cap := Label.new()
		cap.text = s[1]
		cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cap.add_theme_color_override("font_color", Palette.WHITE_DIM)
		cap.add_theme_font_size_override("font_size", 8)
		entry.add_child(cap)
		stage.add_child(entry)

func _render_card() -> void:
	# §16.3 skill-tier ring around the portrait art.
	_root.get_node("CardPanel/PlayerCard/Portrait").add_theme_stylebox_override(
		"panel", UIStyle.portrait_ring(Palette.skill_ring(_view.team_stars)))
	var corner: Label = _root.get_node("CardPanel/PlayerCard/Portrait/StarCorner")
	corner.text = _stars_str(_view.team_stars)
	corner.add_theme_color_override("font_color", Palette.GOLD)
	corner.add_theme_font_size_override("font_size", 11)
	var num: Label = _root.get_node("CardPanel/PlayerCard/Portrait/NumLabel")
	num.text = "—"
	num.add_theme_color_override("font_color", Palette.WHITE_SOFT)
	_root.get_node("CardPanel/PlayerCard/CardInfo/NameLabel").text = _short_name(_view.player_name)
	_root.get_node("CardPanel/PlayerCard/CardInfo/RoleLabel").text = "%s · %s" % [
		_view.city.to_upper(), _role(_view)]
	_root.get_node("CardPanel/PlayerCard/CardInfo/OvrFormRow/OvrTile/OvrCol/OvrNum").text = str(_view.ovr)
	var form_chip: Label = _root.get_node("CardPanel/PlayerCard/CardInfo/OvrFormRow/FormChip")
	form_chip.text = _form_chip(_view.form)
	form_chip.add_theme_stylebox_override("normal", UIStyle.pill(Palette.SURFACE_2))
	form_chip.add_theme_color_override("font_color", Palette.form_glow(_view.form))
	form_chip.add_theme_font_size_override("font_size", 10)
	# career area: empty-state until matches exist (NEVER raw PWR/COM/ATT/CON)
	var empty: PanelContainer = _root.get_node("CardPanel/PlayerCard/CardInfo/CareerArea/EmptyState")
	var strip: Label = _root.get_node("CardPanel/PlayerCard/CardInfo/CareerArea/StatStrip")
	if _view.card_matches == 0:
		empty.visible = true
		strip.visible = false
		empty.get_node("EmptyLabel").text = "No matches yet. Batting & bowling averages appear here once %s have played." % _view.team_name
	else:
		empty.visible = false
		strip.visible = true
		var avg := "%.1f%s" % [_view.card_batting_avg, ("*" if _view.card_dismissals == 0 else "")]
		strip.text = "🏏 %s Avg · %.0f SR     🎯 %d wkts · best %s" % [
			avg, _view.card_strike_rate, _view.card_wickets, _view.card_best_bowling]

func _render_jokers() -> void:
	var box: HBoxContainer = _root.get_node("JokersPanel/JokersWrap/JokersBox")
	for c in box.get_children():
		c.queue_free()
	_root.get_node("JokersPanel/JokersWrap/JokHead/JokCount").text = "%d / 4" % _view.jokers.size()
	for i in range(4):
		var slot := Label.new()
		slot.custom_minimum_size = Vector2(0, 50)
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		slot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		slot.add_theme_font_size_override("font_size", 9)
		if i < _view.jokers.size():
			var j: Dictionary = _view.jokers[i]
			slot.text = j["name"]
			slot.add_theme_stylebox_override("normal", UIStyle.chip(j["rarity"]))
			slot.add_theme_color_override("font_color", RARITY.get(j["rarity"], Palette.WHITE))
		elif i == 3:
			slot.text = "🔒 1ST LEVEL WIN"
			slot.add_theme_stylebox_override("normal", UIStyle.joker_slot(true))
			slot.add_theme_color_override("font_color", Palette.WHITE_DIM)
		else:
			slot.text = "+ WIN TO EARN"
			slot.add_theme_stylebox_override("normal", UIStyle.joker_slot(false))
			slot.add_theme_color_override("font_color", Palette.WHITE_MID)
		box.add_child(slot)

func _render_affinity(cset: Dictionary) -> void:
	_root.get_node("AffinityPanel/AffinityRow/AffinityCol/AffinityTop/AffinityLabel").text = \
		"AFFINITY · %s" % _view.team_name.to_upper()
	var bar: ProgressBar = _root.get_node("AffinityPanel/AffinityRow/AffinityCol/AffinityBar")
	bar.add_theme_stylebox_override("fill", UIStyle.bar_fill(cset["accent"]))
	bar.max_value = AFF_FULL
	bar.value = clampf(float(_view.affinity), 0.0, AFF_FULL)

func _render_cta(cset: Dictionary) -> void:
	_root.get_node("CTA").add_theme_stylebox_override("normal", UIStyle.cta(Palette.GOLD))
	_root.get_node("CTA").add_theme_stylebox_override("hover", UIStyle.cta(Palette.GOLD.lightened(0.05)))
	_root.get_node("CTA").add_theme_stylebox_override("pressed", UIStyle.cta(Palette.GOLD_DEEP))
	var big: Label = _root.get_node("CTA/CtaCenter/CtaLines/CtaBig")
	var small: Label = _root.get_node("CTA/CtaCenter/CtaLines/CtaSmall")
	big.text = ("FIRST MATCH  ▶" if _played() == 0 else "NEXT MATCH  ▶")
	var opp := ""
	if _play != null and not _play.league_done():
		opp = _play.next_player_opponent()["name"]
	elif _played() < _view.fixtures.size():
		opp = _view.fixtures[_played()]["opponent_name"]
	small.text = ("v %s · home" % opp) if not opp.is_empty() else "season complete"

# --- display helpers (display-only; no domain logic) ---

func _initials(s: String) -> String:
	var out := ""
	for word in s.split(" ", false):
		if not word.is_empty():
			out += word[0].to_upper()
	return out.substr(0, 3) if not out.is_empty() else "—"

# "Bongani Kgosi" -> "B. KGOSI"
func _short_name(s: String) -> String:
	var parts := s.split(" ", false)
	if parts.size() < 2:
		return s.to_upper()
	return "%s. %s" % [parts[0][0].to_upper(), parts[parts.size() - 1].to_upper()]

func _cap(name: String) -> String:
	return name.replace(" ", "").substr(0, 3).to_upper()

func _stars_str(stars: float) -> String:
	var full := int(floor(stars))
	var out := "★".repeat(full)
	if (stars - full) >= 0.5:
		out += "½"
	return out if not out.is_empty() else "½"

func _form_chip(form: int) -> String:
	if form >= 2: return "🔥 HOT"
	if form == 1: return "✓ STEADY"
	if form == 0: return "● TIRED"
	return "❄ COLD"

func _role(v: SeasonView) -> String:
	var bat := v.power + v.composure
	var bowl := v.attack + v.control
	if bat > bowl * 1.3: return "TOP-ORDER BAT"
	if bowl > bat * 1.3: return "BOWLER"
	return "ALL-ROUNDER"

func _player_points() -> int:
	for s in _view.standings:
		if s.get("is_player", false):
			return int(s["points"])
	return 0

func _ordinal(n: int) -> String:
	if n <= 0:
		return "—"
	if n % 100 in [11, 12, 13]:
		return "%dth" % n
	match n % 10:
		1: return "%dst" % n
		2: return "%dnd" % n
		3: return "%drd" % n
		_: return "%dth" % n

func _level_word(level: int) -> String:
	return ["Club", "City", "Province"][clampi(level, 0, 2)]
