extends Control

# The Season Hub — renders a SeasonView (spec 2026-06-15-season-hub-replay §5),
# now in the hi-fi look (spec 2026-06-18-season-hub-hifi §6) built on the shared
# Palette + UIStyle design system. The scene never calls resolvers directly: it
# renders a SeasonView and rebuilds it on scrub. Boot is an explicit boot() the
# router calls — NOT auto-run in _ready — so tests can inject without a sim/save.

const RARITY_COLOR := {
	"Common": Palette.COMMON,
	"Rare": Palette.RARE,
	"Legendary": Palette.LEGENDARY,
}
# Country accent (ADR 0001): SA green, AUS amber. Keyed by Country.Code.
const COUNTRY_ACCENT := {
	Country.Code.SA: Palette.SA,
	Country.Code.AUS: Palette.AUS,
}
const BOOT_SEED := 20260615
const AFF_FULL := 5.0   # affinity loyalty "full" pip count (seasons-stayed; display-only)

# Tapping a PLAYED fixture row opens that match's ball-by-ball replay. main.gd
# wires this to _push_match. Unplayed rows keep scrubbing the season head.
signal open_match(match_index: int)

# Emitted when the player taps PLAY on their next fixture (live forward-play path).
# main.gd pushes the Interactive Match scene; on return it commits the result.
signal play_next(team_index: int)

@onready var _root: VBoxContainer = $Scroll/Margin/Root

var _view: SeasonView
var _player: Player
var _career: CareerState
var _season: SeasonResult
var _play: SeasonPlay   # live forward-play driver (null on the scrub-replay/test path)

func _ready() -> void:
	_root.get_node("ScrubPanel/ScrubBar/PrevBtn").pressed.connect(func(): step(-1))
	_root.get_node("ScrubPanel/ScrubBar/NextBtn").pressed.connect(func(): step(1))
	_style_static()

# Apply the shared panel chrome + static label styling once. _render only touches
# dynamic content + colours that depend on the country accent / star / form.
func _style_static() -> void:
	for panel_name in ["TopbarPanel", "TonsPanel", "FixturesPanel", "CardPanel",
			"JokersPanel", "AffinityPanel", "StandingsPanel", "ScrubPanel"]:
		_root.get_node(panel_name).add_theme_stylebox_override("panel", UIStyle.panel())
	# caps section labels (dim, small)
	for path in ["TonsPanel/TonsRow/TonsCol/TonsCap", "FixturesPanel/FixturesWrap/FixHeader",
			"JokersPanel/JokersWrap/JokHeader", "AffinityPanel/AffinityWrap/AffinityLabel"]:
		var l: Label = _root.get_node(path)
		l.add_theme_color_override("font_color", Palette.WHITE_DIM)
		l.add_theme_font_size_override("font_size", 10)
	# the big ₸ value
	var tons: Label = _root.get_node("TonsPanel/TonsRow/TonsCol/TonsChip")
	tons.add_theme_color_override("font_color", Palette.GOLD)
	tons.add_theme_font_size_override("font_size", 24)
	# context labels dim
	_root.get_node("TonsPanel/TonsRow/ContextCol/ContextLabel").add_theme_color_override("font_color", Palette.WHITE_DIM)
	_root.get_node("TonsPanel/TonsRow/ContextCol/ProgressLabel").add_theme_color_override("font_color", Palette.WHITE_DIM)
	# affinity bar styling
	var bar: ProgressBar = _root.get_node("AffinityPanel/AffinityWrap/AffinityBar")
	bar.add_theme_stylebox_override("background", UIStyle.bar_track())
	bar.max_value = AFF_FULL

# --- Production boot: simulate the saved Player's current cell once. ---

func boot() -> void:
	if _view != null or _play != null:
		return   # a test (or caller) already injected a view/source/play
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

# --- Source + scrub ---

func set_source(player: Player, career: CareerState, season: SeasonResult) -> void:
	_player = player
	_career = career
	_season = season
	_rebuild(0)

func set_play(player: Player, career: CareerState, play: SeasonPlay) -> void:
	_player = player
	_career = career
	_play = play
	_rebuild_live()

func _rebuild_live() -> void:
	if _play == null:
		return
	set_view(SeasonViewBuilder.build(_player, _career, _play.live_season(), _play.played_count()))

func live_play() -> SeasonPlay:
	return _play

func current_career() -> CareerState:
	return _career

func has_play_control() -> bool:
	return _play != null and not _play.league_done() \
		and _root.get_node_or_null("PlayNextBtn") != null

func _rebuild(index: int) -> void:
	if _player == null or _career == null or _season == null:
		return
	set_view(SeasonViewBuilder.build(_player, _career, _season, index))

func scrub_index() -> int:
	return _view.scrub_index if _view != null else 0

func season() -> SeasonResult:
	return _season

func current_view() -> SeasonView:
	return _view

func step(delta: int) -> void:
	if _view == null:
		return
	_rebuild(clampi(_view.scrub_index + delta, 0, _view.match_count))

# --- Render ---

func set_view(view: SeasonView) -> void:
	_view = view
	_render()

func _render() -> void:
	if _view == null:
		return
	var accent: Color = COUNTRY_ACCENT.get(_view.country, Palette.SA)
	_render_topbar(accent)
	_render_tons()
	_render_fixtures(accent)
	_render_play_next(accent)
	_render_card(accent)
	_render_jokers()
	_render_affinity(accent)
	_render_standings(accent)
	_render_scrub()

func _render_topbar(accent: Color) -> void:
	var badge: Label = _root.get_node("TopbarPanel/Header/Badge")
	badge.text = _initials(_view.team_name)
	badge.add_theme_stylebox_override("normal", UIStyle.pill(accent))
	badge.add_theme_color_override("font_color", Palette.WHITE)
	var title: Label = _root.get_node("TopbarPanel/Header/TeamId/TitleLabel")
	title.text = _view.team_name
	title.add_theme_color_override("font_color", accent)
	title.add_theme_font_size_override("font_size", 16)
	var stars: Label = _root.get_node("TopbarPanel/Header/TeamId/StarsLabel")
	stars.text = _stars_str(_view.team_stars)
	stars.add_theme_color_override("font_color", Palette.GOLD)
	var pos: Label = _root.get_node("TopbarPanel/Header/PosPill")
	pos.text = _position_text()
	pos.add_theme_stylebox_override("normal", UIStyle.pill(Palette.SURFACE))
	pos.add_theme_color_override("font_color", Palette.WHITE)

func _render_tons() -> void:
	_root.get_node("TonsPanel/TonsRow/TonsCol/TonsChip").text = "₸ %d" % _view.tons_balance
	_root.get_node("TonsPanel/TonsRow/ContextCol/ContextLabel").text = "%s · %s · %s" % [
		_level_word(_view.level), _view.tour_name, _view.difficulty_label]
	var n: int = _play.played_count() if _play != null else _view.scrub_index
	_root.get_node("TonsPanel/TonsRow/ContextCol/ProgressLabel").text = "MATCH %d / %d" % [n, _view.match_count]

func _render_fixtures(accent: Color) -> void:
	var box: HBoxContainer = _root.get_node("FixturesPanel/FixturesWrap/FixturesBox")
	for c in box.get_children():
		c.queue_free()
	for i in range(_view.fixtures.size()):
		var f: Dictionary = _view.fixtures[i]
		var btn := Button.new()   # tappable: played -> open replay, else -> scrub head
		var idx := i
		var cap := _cap(f["opponent_name"])
		var bg: Color
		var fg := Palette.WHITE
		if f["played"]:
			bg = accent if f["player_won"] else Palette.DANGER
			btn.text = "%s %s" % ["W" if f["player_won"] else "L", cap]
			btn.pressed.connect(func(): open_match.emit(idx))
		else:
			bg = Palette.SURFACE
			fg = Palette.WHITE_DIM
			btn.text = "M%d %s" % [i + 1, cap]
			btn.pressed.connect(func(): _rebuild(idx))
		var sb := UIStyle.pill(bg.darkened(0.15) if f["played"] else bg)
		if i == _view.scrub_index:
			sb.set_border_width_all(2)
			sb.border_color = Palette.GOLD
		for state in ["normal", "hover", "pressed", "focus"]:
			btn.add_theme_stylebox_override(state, sb)
		btn.add_theme_color_override("font_color", fg)
		btn.add_theme_font_size_override("font_size", 11)
		box.add_child(btn)

# The next-fixture PLAY CTA (live forward-play path only). Solid accent tile via
# UIStyle.cta — a direct child of Root (kept here so has_play_control()'s
# get_node_or_null("PlayNextBtn") finds it), placed just above the scrub bar.
func _render_play_next(accent: Color) -> void:
	var existing := _root.get_node_or_null("PlayNextBtn")
	if existing != null:
		existing.queue_free()
	if _play == null or _play.league_done():
		return
	var nxt := _play.next_player_opponent()
	var btn := Button.new()
	btn.name = "PlayNextBtn"
	btn.text = "Next Match  ▶   v %s" % nxt["name"]
	btn.size_flags_horizontal = Control.SIZE_FILL
	var sb := UIStyle.cta(accent)
	for state in ["normal", "hover", "pressed", "focus"]:
		btn.add_theme_stylebox_override(state, sb)
	btn.add_theme_color_override("font_color", Palette.WHITE)
	btn.add_theme_font_size_override("font_size", 16)
	var idx: int = nxt["team_index"]
	btn.pressed.connect(func(): play_next.emit(idx))
	_root.add_child(btn)
	_root.move_child(btn, _root.get_node("ScrubPanel").get_index())

func _render_card(accent: Color) -> void:
	# §16.3 portrait frame: skill-tier bg + Form-coloured glow border.
	var skill := Palette.skill_bg(_view.team_stars)
	var glow := Palette.form_glow(_view.form)
	var portrait: Panel = _root.get_node("CardPanel/PlayerCard/Portrait")
	portrait.add_theme_stylebox_override("panel", UIStyle.portrait_frame(skill, glow))
	var num: Label = portrait.get_node("NumLabel")
	num.text = _initials(_view.player_name)
	num.add_theme_font_size_override("font_size", 22)
	# dark text on light tiers, white on the charcoal rookie tier.
	num.add_theme_color_override("font_color",
		Palette.WHITE if skill.get_luminance() < 0.4 else Palette.BG)
	var corner: Label = portrait.get_node("StarsCorner")
	corner.text = _stars_str(_view.team_stars)
	corner.add_theme_color_override("font_color", Palette.GOLD)
	corner.add_theme_font_size_override("font_size", 9)

	_root.get_node("CardPanel/PlayerCard/CardInfo/NameLabel").text = "%s · %s" % [_view.player_name, _view.city]
	var ovr: Label = _root.get_node("CardPanel/PlayerCard/CardInfo/OvrFormRow/OvrLabel")
	ovr.text = "OVR %d" % _view.ovr
	ovr.add_theme_color_override("font_color", Palette.GOLD)
	var form_chip: Label = _root.get_node("CardPanel/PlayerCard/CardInfo/OvrFormRow/FormChip")
	form_chip.text = _form_chip(_view.form)
	form_chip.add_theme_color_override("font_color", Palette.form_glow(_view.form))

	var career_lbl: Label = _root.get_node("CardPanel/PlayerCard/CardInfo/CareerLabel")
	if _view.card_matches == 0:
		career_lbl.text = "no matches yet"
	else:
		var avg_txt := "%.1f%s" % [_view.card_batting_avg, ("*" if _view.card_dismissals == 0 else "")]
		career_lbl.text = "🏏 %s avg · %.0f SR    🎯 %d wkts · best %s" % [
			avg_txt, _view.card_strike_rate, _view.card_wickets, _view.card_best_bowling]
	career_lbl.add_theme_color_override("font_color", Palette.WHITE_DIM)
	_root.get_node("CardPanel/PlayerCard/CardInfo/AttrLabel").text = "PWR %d  COM %d  ATT %d  CON %d" % [
		int(_view.power), int(_view.composure), int(_view.attack), int(_view.control)]

func _render_jokers() -> void:
	var box: HBoxContainer = _root.get_node("JokersPanel/JokersWrap/JokersBox")
	for c in box.get_children():
		c.queue_free()
	_root.get_node("JokersPanel/JokersWrap/JokHeader").text = "JOKERS BENCH   %d / 4" % _view.jokers.size()
	for j in _view.jokers:
		var chip := Label.new()
		chip.text = " %s " % j["name"]
		chip.add_theme_stylebox_override("normal", UIStyle.chip(j["rarity"]))
		chip.add_theme_color_override("font_color", RARITY_COLOR.get(j["rarity"], Palette.WHITE))
		chip.add_theme_font_size_override("font_size", 11)
		box.add_child(chip)
	# empty slots up to 4
	for _i in range(4 - _view.jokers.size()):
		var empty := Label.new()
		empty.text = "  +  "
		empty.add_theme_stylebox_override("normal", UIStyle.chip("Common"))
		empty.add_theme_color_override("font_color", Palette.WHITE_DIM)
		empty.add_theme_font_size_override("font_size", 11)
		box.add_child(empty)

func _render_affinity(accent: Color) -> void:
	_root.get_node("AffinityPanel/AffinityWrap/AffinityLabel").text = "AFFINITY · %s · %d" % [_view.team_name, _view.affinity]
	var bar: ProgressBar = _root.get_node("AffinityPanel/AffinityWrap/AffinityBar")
	bar.add_theme_stylebox_override("fill", UIStyle.bar_fill(accent))
	bar.value = clampf(float(_view.affinity), 0.0, AFF_FULL)

func _render_standings(accent: Color) -> void:
	var box: VBoxContainer = _root.get_node("StandingsPanel/StandingsWrap/StandingsBox")
	for c in box.get_children():
		c.queue_free()
	var head := Label.new()
	head.text = "FINAL TABLE" if _play == null else "LEAGUE TABLE · your matches %d/7" % _play.played_count()
	head.add_theme_color_override("font_color", Palette.WHITE_DIM)
	head.add_theme_font_size_override("font_size", 10)
	box.add_child(head)
	for i in range(_view.standings.size()):
		var s: Dictionary = _view.standings[i]
		var row := Label.new()
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.text = "%d. %s  %dpts  NRR %+.2f" % [i + 1, s["team_name"], s["points"], s["nrr"]]
		row.add_theme_color_override("font_color", Palette.GOLD if s["is_player"] else Palette.WHITE)
		box.add_child(row)

func _render_scrub() -> void:
	_root.get_node("ScrubPanel/ScrubBar/ScrubLabel").text = "Match %d / %d" % [_view.scrub_index, _view.match_count]

# --- small display helpers (display-only; no domain logic) ---

# Player/team initials for the badge + portrait glyph ("Cape Gulls" -> "CG").
func _initials(s: String) -> String:
	var out := ""
	for word in s.split(" ", false):
		if not word.is_empty():
			out += word[0].to_upper()
	return out.substr(0, 3) if not out.is_empty() else "—"

# 3-letter fixture cap ("Dusty Plains" -> "dus").
func _cap(name: String) -> String:
	return name.replace(" ", "").substr(0, 3).to_lower()

# ★ rating string from a float star count (half-star aware).
func _stars_str(stars: float) -> String:
	var full := int(floor(stars))
	var half := (stars - full) >= 0.5
	var out := "★".repeat(full)
	if half:
		out += "½"
	return out if not out.is_empty() else "☆"

# Form chip label from the SeasonView.form int (display-only banding, matches Palette).
func _form_chip(form: int) -> String:
	if form >= 2: return "🔥 Hot"
	if form == 1: return "✓ Steady"
	if form == 0: return "· Tired"
	return "❄ Cold"

# Position pill text: "3rd · 6 pts" from player_final_position + the player's points row.
func _position_text() -> String:
	if _view.player_final_position <= 0:
		return "—"
	var pts := -1
	for s in _view.standings:
		if s.get("is_player", false):
			pts = int(s["points"])
			break
	if pts < 0:
		return _ordinal(_view.player_final_position)
	return "%s · %d pts" % [_ordinal(_view.player_final_position), pts]

func _ordinal(n: int) -> String:
	if n % 100 in [11, 12, 13]:
		return "%dth" % n
	match n % 10:
		1: return "%dst" % n
		2: return "%dnd" % n
		3: return "%drd" % n
		_: return "%dth" % n

func _level_word(level: int) -> String:
	return ["Club", "City", "Province"][clampi(level, 0, 2)]
