extends Control

# The Season Hub — the game's home screen, hi-fi v2 (spec
# docs/superpowers/specs/2026-06-18-season-hub-hifi-v2-spec.md). A single dense
# screen (no scroll, no league table) built on the shared Palette + UIStyle
# tokens. Renders a SeasonView; never calls resolvers. Boot is explicit (not
# _ready-auto) so tests inject a view without a sim/save.
#
# Hard design rules honoured here: never show raw PWR/COM/ATT/CON (only OVR +
# career averages); position pill shows "—" until a result exists.

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
var _cell_level: int = 0   # the career cell this live Season is being played at
var _cell_tour: int = 0    # (spec 2026-06-24 — was hardwired to tour 0)

func _ready() -> void:
	$CornerInfo.pressed.connect(func(): open_info.emit())
	$CornerGear.pressed.connect(func(): open_settings.emit())
	$CornerInfo.add_theme_stylebox_override("normal", UIStyle.corner_btn())
	$CornerGear.add_theme_stylebox_override("normal", UIStyle.corner_btn())
	_root.get_node("CTA").pressed.connect(_on_cta)
	_style_static()

func _on_cta() -> void:
	if _play == null:
		return
	var nxt := _play.next_player_opponent()
	if nxt.is_empty():
		return
	play_next.emit(nxt["team_index"])

# Static chrome + label styling applied once. _render only sets text + colours
# that depend on the live data / country.
func _style_static() -> void:
	_root.get_node("TonsPanel").add_theme_stylebox_override("panel", UIStyle.panel())
	_root.get_node("FixturesPanel").add_theme_stylebox_override("panel", UIStyle.panel())
	_root.get_node("CardPanel").add_theme_stylebox_override("panel", UIStyle.panel())
	_root.get_node("JokersPanel").add_theme_stylebox_override("panel", UIStyle.panel())
	_root.get_node("AffinityPanel").add_theme_stylebox_override("panel", UIStyle.panel())
	_root.get_node("SeasonGoal").add_theme_stylebox_override("panel", UIStyle.goal_panel())
	var target := UIStyle.pill(Color(0, 0, 0, 0.35))
	target.set_border_width_all(1); target.border_color = Palette.BORDER
	_root.get_node("SeasonGoal/GoalRow/TargetPill").add_theme_stylebox_override("panel", target)
	# goal strip labels
	var gcap: Label = _root.get_node("SeasonGoal/GoalRow/GoalCol/GoalCap")
	gcap.add_theme_color_override("font_color", Palette.GOLD)
	gcap.add_theme_font_size_override("font_size", 9)
	Fonts.weigh(gcap, Fonts.W_BOLD)
	_root.get_node("SeasonGoal/GoalRow/GoalCol/GoalText").add_theme_color_override("font_color", Palette.WHITE_SOFT)
	_root.get_node("SeasonGoal/GoalRow/GoalCol/GoalText").add_theme_font_size_override("font_size", 12)
	_root.get_node("SeasonGoal/GoalRow/GoalIcon").add_theme_font_size_override("font_size", 18)
	var tnum: Label = _root.get_node("SeasonGoal/GoalRow/TargetPill/TargetCol/TargetNum")
	tnum.add_theme_color_override("font_color", Palette.WHITE)
	tnum.add_theme_font_size_override("font_size", 14)
	Fonts.weigh(tnum, Fonts.W_BOLD, true)
	var tcap: Label = _root.get_node("SeasonGoal/GoalRow/TargetPill/TargetCol/TargetCap")
	tcap.add_theme_color_override("font_color", Palette.GOLD)
	tcap.add_theme_font_size_override("font_size", 8)
	Fonts.weigh(tcap, Fonts.W_BOLD)
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
		Fonts.weigh(l, Fonts.W_BOLD)  # uppercase micro-labels (hub spec: weight 800)
	# big ₸ value
	var tons: Label = _root.get_node("TonsPanel/TonsRow/TonsCol/TonsChip")
	tons.add_theme_color_override("font_color", Palette.GOLD)
	tons.add_theme_font_size_override("font_size", 24)
	Fonts.weigh(tons, Fonts.W_BOLD, true)
	# OVR tile text (dark on gold)
	var ovrn: Label = _root.get_node("CardPanel/PlayerCard/CardInfo/OvrFormRow/OvrTile/OvrCol/OvrNum")
	ovrn.add_theme_color_override("font_color", Palette.BG)
	ovrn.add_theme_font_size_override("font_size", 17)
	Fonts.weigh(ovrn, Fonts.W_BOLD, true)
	var ovrc: Label = _root.get_node("CardPanel/PlayerCard/CardInfo/OvrFormRow/OvrTile/OvrCol/OvrCap")
	ovrc.add_theme_color_override("font_color", Palette.BG)
	ovrc.add_theme_font_size_override("font_size", 8)
	Fonts.weigh(ovrc, Fonts.W_BOLD)
	# name — hub spec: names weight 900 → ExtraBold
	var nm: Label = _root.get_node("CardPanel/PlayerCard/CardInfo/NameLabel")
	nm.add_theme_color_override("font_color", Palette.WHITE)
	nm.add_theme_font_size_override("font_size", 15)
	Fonts.weigh(nm, Fonts.W_HEADLINE)
	# empty-state + stat strip text
	var empty_lbl: Label = _root.get_node("CardPanel/PlayerCard/CardInfo/CareerArea/EmptyState/EmptyLabel")
	empty_lbl.add_theme_color_override("font_color", Palette.WHITE_MID)
	empty_lbl.add_theme_font_size_override("font_size", 10)
	_root.get_node("CardPanel/PlayerCard/CardInfo/CareerArea/StatStrip").add_theme_color_override("font_color", Palette.WHITE_SOFT)
	var nextb: Label = _root.get_node("AffinityPanel/AffinityRow/AffinityCol/AffinityTop/NextBonus")
	nextb.add_theme_color_override("font_color", Palette.GOLD)
	nextb.add_theme_font_size_override("font_size", 9)
	Fonts.weigh(nextb, Fonts.W_BOLD)
	_root.get_node("TonsPanel/TonsRow/ContextCol/ProgressLabel").add_theme_color_override("font_color", Palette.WHITE_MID)
	# affinity track (portrait art is per-view -- set in _render_card)
	_root.get_node("AffinityPanel/AffinityRow/AffinityCol/AffinityBar").add_theme_stylebox_override("background", UIStyle.bar_track())
	# CTA text colours (dark on gold)
	var ctab: Label = _root.get_node("CTA/CtaCenter/CtaLines/CtaBig")
	ctab.add_theme_color_override("font_color", Palette.BG)
	ctab.add_theme_font_size_override("font_size", 16)
	Fonts.weigh(ctab, Fonts.W_BOLD)
	var ctas: Label = _root.get_node("CTA/CtaCenter/CtaLines/CtaSmall")
	ctas.add_theme_color_override("font_color", Color(0, 0, 0, 0.6))
	ctas.add_theme_font_size_override("font_size", 9)
	Fonts.weigh(ctas, Fonts.W_MEDIUM)

# --- Production boot ---

func boot() -> void:
	if _view != null or _play != null:
		return
	if not SaveManager.has_player():
		return
	var player := SaveManager.load_player()
	var fresh := not SaveManager.has_career()
	var career: CareerState = SaveManager.load_career() if not fresh \
		else CareerResolver.start_career(0)
	if fresh:
		SaveManager.save_career(career)   # the live career is now durable (spec 2026-06-24)
	# Cross-session resume (spec 2026-06-23): if a live season is saved, rebuild it by
	# replaying the saved decisions (lossless) instead of starting a fresh one. The
	# saved season is already at next_live_cell(career); set_play re-derives the cell.
	if SaveManager.has_live_season():
		var play := SeasonPlay.from_state(SaveManager.load_live_season(), player, career)
		set_play(player, career, play)
		return
	# Fresh season at the career's next cell (rush-climb), with a seed that varies per
	# Season so re-attempts and later cells differ (DLC6). seasons_played==0 (a brand-new
	# career) keeps the original first-game seed → byte-identical to before.
	var cell := CareerResolver.next_live_cell(career)
	var spec := DifficultyLadder.spec_for(cell["level"], cell["tour"])
	var team: Team = career.teams[career.current_team_index]
	var play := SeasonPlay.start(
		player.attributes, team, career.opponents_of_current(),
		spec.make_tour(), BallTuning.new(), InningsTuning.new(),
		BOOT_SEED + career.seasons_played, spec)
	set_play(player, career, play)

# --- Sources ---

func set_source(player: Player, career: CareerState, season: SeasonResult) -> void:
	_player = player; _career = career; _season = season
	_rebuild(0)

func set_play(player: Player, career: CareerState, play: SeasonPlay) -> void:
	_player = player; _career = career; _play = play
	# The career cell this Season is being played at — stable during a Season (the grid
	# only advances at Season end), so deriving it here matches what boot started with.
	var cell := CareerResolver.next_live_cell(career)
	_cell_level = cell["level"]; _cell_tour = cell["tour"]
	# Bank ₸ on the live path (Slice 3 logic, wired here). Re-bound each set_play to
	# the freshly-loaded player (main saves it after each match), so the balance
	# accrues correctly across the season; the running tally lives on the play.
	var team: Team = career.teams[career.current_team_index]
	play.enable_pay(player, EconomyTuning.new(), team.stars, _cell_level, _cell_tour)
	play.enable_form(player)  # Form + Affinity bonus (spec 2026-07-03 DF6)
	# The live Kit Room (spec 2026-07-02, Rung 2): rebind + init-once; the carry-over
	# joker enters the shop free (V0) and the shop's loadout drives the live jokers
	# (replaces the Rung-1 direct carry-over seeding).
	play.enable_shop(player, EconomyTuning.new(), _cell_level, _cell_tour,
		career.carryover_joker_id)
	set_view(SeasonViewBuilder.build(player, career, play.live_season(),
		play.played_count(), play.shop_owned()))

func live_play() -> SeasonPlay: return _play
func current_career() -> CareerState: return _career
# The (level, tour) of the career cell the current live Season is at.
func current_cell() -> Vector2i: return Vector2i(_cell_level, _cell_tour)
# A player match is pending whenever the live driver names a next opponent —
# league fixture OR playoff knockout (league_done() alone would hide the playoffs).
func has_play_control() -> bool:
	return _play != null and not _play.next_player_opponent().is_empty()

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
	_render_goal()
	_render_cta(cset)

func _render_topbar(cset: Dictionary) -> void:
	_root.get_node("TopbarPanel").add_theme_stylebox_override("panel",
		UIStyle.header(cset["grad1"], cset["grad2"], cset["glow"]))
	var badge: Label = _root.get_node("TopbarPanel/Header/Badge")
	badge.text = _initials(_view.team_name)
	badge.add_theme_stylebox_override("normal", UIStyle.pill(cset["grad1"].darkened(0.2)))
	badge.add_theme_color_override("font_color", Palette.WHITE)
	Fonts.weigh(badge, Fonts.W_BOLD)
	var title: Label = _root.get_node("TopbarPanel/Header/TeamId/TitleLabel")
	title.text = _view.team_name
	title.add_theme_color_override("font_color", Palette.WHITE)
	title.add_theme_font_size_override("font_size", 15)
	Fonts.weigh(title, Fonts.W_HEADLINE)  # hub spec: names weight 900
	var stars: Label = _root.get_node("TopbarPanel/Header/TeamId/MetaRow/StarsLabel")
	stars.text = _stars_str(_view.team_stars)
	stars.add_theme_color_override("font_color", Palette.GOLD)
	var chip: Label = _root.get_node("TopbarPanel/Header/TeamId/MetaRow/LevelChip")
	chip.text = "%s · %s" % [_level_word(_view.level).to_upper(), _conditions().to_upper()]
	chip.add_theme_stylebox_override("normal", UIStyle.pill(Color(0, 0, 0, 0.25)))
	chip.add_theme_color_override("font_color", Palette.WHITE_SOFT)
	chip.add_theme_font_size_override("font_size", 9)
	Fonts.weigh(chip, Fonts.W_BOLD)
	# position pill — "—" / 0 PTS until a result exists (no fake "1st"); dark bg so
	# the dash never floats bare on the green header.
	var posn: Label = _root.get_node("TopbarPanel/Header/PosPill/PosCol/PosNum")
	var pospts: Label = _root.get_node("TopbarPanel/Header/PosPill/PosCol/PosPts")
	if _played() == 0:
		posn.text = "—"
		pospts.text = "0 PTS"
	else:
		posn.text = _ordinal(_view.player_final_position)
		pospts.text = "%d PTS" % _player_points()
	posn.add_theme_color_override("font_color", Palette.WHITE)
	posn.add_theme_font_size_override("font_size", 17)
	Fonts.weigh(posn, Fonts.W_BOLD, true)
	pospts.add_theme_color_override("font_color", Palette.WHITE_MID)
	pospts.add_theme_font_size_override("font_size", 8)
	Fonts.weigh(pospts, Fonts.W_BOLD)
	var pp := UIStyle.pill(Color(0, 0, 0, 0.35))
	pp.set_border_width_all(1)
	pp.border_color = Palette.BORDER
	_root.get_node("TopbarPanel/Header/PosPill").add_theme_stylebox_override("panel", pp)

func _render_tons() -> void:
	_root.get_node("TonsPanel/TonsRow/TonsCol/TonsChip").text = "₸ %d" % _view.tons_balance
	_root.get_node("TonsPanel/TonsRow/ContextCol/SeasonLabel").text = "SEASON %d · %s" % [
		_season_no(), _level_word(_view.level).to_upper()]
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
		Fonts.weigh(dot, Fonts.W_BOLD)
		entry.add_child(dot)
		var cap := Label.new()
		cap.text = _cap(f["opponent_name"])
		cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cap.add_theme_color_override("font_color", cset["accent"] if i == now_idx else Palette.WHITE_DIM)
		cap.add_theme_font_size_override("font_size", 8)
		entry.add_child(cap)
		box.add_child(entry)
	# stage chips (SF + final) — the Player's pending knockout lights up in the
	# playoffs phase (gold + accent ring), otherwise they're a dim "what's next" hint.
	var stage: HBoxContainer = _root.get_node("FixturesPanel/FixturesWrap/FixturesRow/StageBox")
	for c in stage.get_children():
		c.queue_free()
	var active_stage := ""
	if _play != null and _play.phase() == "playoffs":
		active_stage = _play.next_player_opponent().get("stage", "")
	for s in [["SF", "semi"], ["🏆", "final"]]:
		var is_active: bool = s[1] == active_stage or (active_stage == "third" and s[1] == "final")
		var entry := VBoxContainer.new()
		entry.add_theme_constant_override("separation", 2)
		var chip := Label.new()
		chip.text = s[0]
		chip.custom_minimum_size = Vector2(28, 26)
		chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		chip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var chip_box := UIStyle.pill(Palette.GOLD if is_active else Palette.GOLD_DEEP)
		if is_active:
			chip_box.set_border_width_all(2); chip_box.border_color = cset["accent"]
		chip.add_theme_stylebox_override("normal", chip_box)
		chip.add_theme_color_override("font_color", Palette.BG)
		chip.add_theme_font_size_override("font_size", 9)
		Fonts.weigh(chip, Fonts.W_BOLD)
		entry.add_child(chip)
		var cap := Label.new()
		cap.text = ("third" if (active_stage == "third" and s[1] == "final") else s[1])
		cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cap.add_theme_color_override("font_color", cset["accent"] if is_active else Palette.WHITE_DIM)
		cap.add_theme_font_size_override("font_size", 8)
		entry.add_child(cap)
		stage.add_child(entry)

func _render_card() -> void:
	# §16.3 skill-tier ring around the portrait art.
	_root.get_node("CardPanel/PlayerCard/Portrait").add_theme_stylebox_override(
		"panel", UIStyle.portrait_ring(Palette.skill_ring(_view.team_stars)))
	# the face follows appearance bucket x live form band (DP6)
	_root.get_node("CardPanel/PlayerCard/Portrait/PortraitTex").texture = PortraitLibrary.texture_for(_view.appearance, _view.form)
	var corner: Label = _root.get_node("CardPanel/PlayerCard/Portrait/StarCorner")
	corner.text = _stars_str(_view.team_stars)
	corner.add_theme_color_override("font_color", Palette.GOLD)
	corner.add_theme_font_size_override("font_size", 11)
	Fonts.weigh(corner, Fonts.W_BOLD)
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
	Fonts.weigh(form_chip, Fonts.W_BOLD)
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
		Fonts.weigh(slot, Fonts.W_BOLD)
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

# Season Goal strip — what the season is FOR (fills the lower third with stakes).
# Top-4-of-8 reaches the Semi-Final (spec copy; level word is dynamic).
func _render_goal() -> void:
	_root.get_node("SeasonGoal/GoalRow/GoalCol/GoalCap").text = "SEASON GOAL · %s" % _level_word(_view.level).to_upper()

func _render_cta(cset: Dictionary) -> void:
	_root.get_node("CTA").add_theme_stylebox_override("normal", UIStyle.cta(Palette.GOLD))
	_root.get_node("CTA").add_theme_stylebox_override("hover", UIStyle.cta(Palette.GOLD.lightened(0.05)))
	_root.get_node("CTA").add_theme_stylebox_override("pressed", UIStyle.cta(Palette.GOLD_DEEP))
	var big: Label = _root.get_node("CTA/CtaCenter/CtaLines/CtaBig")
	var small: Label = _root.get_node("CTA/CtaCenter/CtaLines/CtaSmall")
	# Playoffs: the CTA names the knockout (semi/final/3rd-place) instead of a fixture.
	if _play != null and _play.phase() == "playoffs":
		var nxt := _play.next_player_opponent()
		var stage: String = nxt.get("stage", "")
		big.text = {
			"semi": "SEMI-FINAL  ▶", "final": "THE FINAL  ▶", "third": "3RD-PLACE  ▶",
		}.get(stage, "PLAYOFF  ▶")
		small.text = "v %s · knockout" % nxt.get("name", "")
		return
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
	return Display.stars_str(stars)

func _form_chip(form: int) -> String:
	return FormBand.label(FormBand.of(form))  # no emoji -- Barlow tofus them (DP7)

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

# Conditions only (tour_name is "Club Flat & Warm" → "Flat & Warm"), so the meta
# chip reads "CLUB · FLAT & WARM" not "CLUB · CLUB FLAT & WARM".
func _conditions() -> String:
	var lvl := _level_word(_view.level)
	var t := _view.tour_name
	if t.begins_with(lvl + " "):
		return t.substr(lvl.length() + 1)
	return t

func _season_no() -> int:
	return (_career.seasons_played + 1) if _career != null else 1
