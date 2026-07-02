extends Control

# Pre-Match screen (nav-shell spec 2026-07-03, Slice 1; mockup section 2,
# Q2-locked single opponent portrait). The versus moment between hub PLAY and
# the match. Dumb: renders what it is given, emits start_pressed. DN1: every
# number real (attrs, stars, tour); the danger man is flavour-only. DN2: no
# home/away (the sim has none). DN4: no back — forward flow. No emoji.

signal start_pressed()

const MATCHES := 7   # league fixtures (stakes line denominator)

# view = the hub's SeasonView (real player/team/tour/joker data).
# opp = SeasonPlay.next_player_opponent() ({name, team_index[, stage]}).
# opp_stars = the opponent Team's stars. match_no = played_count()+1 (1-based).
func set_matchup(view: SeasonView, opp: Dictionary, opp_stars: float, match_no: int) -> void:
	var bg := ColorRect.new()
	bg.color = Palette.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(340, 0)
	col.add_theme_constant_override("separation", 14)
	center.add_child(col)

	col.add_child(_versus_header(view, opp, opp_stars, match_no))
	col.add_child(_centered_line(_stakes_text(opp, match_no), Palette.GOLD, 12, Fonts.W_BOLD))
	col.add_child(_centered_line(view.tour_name, Palette.WHITE_DIM, 11, Fonts.W_MEDIUM))
	col.add_child(_panels(view, opp))
	col.add_child(_build_strip(view))

	var cta := Button.new()
	cta.name = "StartBtn"
	cta.text = "TAP TO START"
	cta.custom_minimum_size = Vector2(0, 52)
	for state in ["normal", "hover", "pressed"]:
		cta.add_theme_stylebox_override(state, UIStyle.cta(Palette.GOLD))
	cta.add_theme_color_override("font_color", Palette.BG)
	cta.add_theme_font_size_override("font_size", 16)
	Fonts.weigh(cta, Fonts.W_HEADLINE)
	cta.pressed.connect(func(): start_pressed.emit())
	col.add_child(cta)

# You | VS | them — team names + star ratings + the match tag.
func _versus_header(view: SeasonView, opp: Dictionary, opp_stars: float, match_no: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.add_child(_versus_side("YOU PLAY FOR", view.team_name,
		_stars(view.team_stars), HORIZONTAL_ALIGNMENT_LEFT))
	var vs := _lbl("VS", 22, Palette.GOLD, Fonts.W_HEADLINE)
	vs.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(vs)
	row.add_child(_versus_side(_match_tag(opp, match_no), str(opp.get("name", "")),
		_stars(opp_stars), HORIZONTAL_ALIGNMENT_RIGHT))
	return row

func _versus_side(kicker: String, team: String, stars: String, halign: int) -> Control:
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for spec: Array in [[kicker, 9, Palette.WHITE_DIM, Fonts.W_LABEL],
			[team, 16, Palette.WHITE, Fonts.W_HEADLINE],
			[stars, 11, Palette.GOLD, Fonts.W_MEDIUM]]:
		var l := _lbl(spec[0], spec[1], spec[2], spec[3])
		l.horizontal_alignment = halign
		v.add_child(l)
	return v

func _match_tag(opp: Dictionary, match_no: int) -> String:
	match str(opp.get("stage", "")):
		"semi": return "SEMI-FINAL"
		"final": return "THE FINAL"
		"third": return "3RD-PLACE MATCH"
		_: return "MATCH %d" % match_no

func _stakes_text(opp: Dictionary, match_no: int) -> String:
	match str(opp.get("stage", "")):
		"semi": return "Semi-Final · Win to reach The Final"
		"final": return "The Final · Winner takes the season"
		"third": return "3rd-Place Match"
		_: return "League Match %d of %d · Top 4 advance" % [match_no, MATCHES]

# Your captain (real attrs + affinity) vs their danger man (flavour name only —
# the sim has no named opponents; the number that is real is the team's stars).
func _panels(view: SeasonView, opp: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	var you := _panel_box("YOUR CAPTAIN")
	var you_col: VBoxContainer = you.get_child(0)
	you_col.add_child(_lbl(view.player_name, 14, Palette.WHITE, Fonts.W_BOLD))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	for pair: Array in [["POW", view.power], ["COM", view.composure],
			["ATK", view.attack], ["CTL", view.control]]:
		var cell := VBoxContainer.new()
		cell.add_child(_lbl("%d" % int(round(pair[1])), 13, Palette.WHITE, Fonts.W_BOLD))
		cell.add_child(_lbl(pair[0], 8, Palette.WHITE_DIM, Fonts.W_LABEL))
		grid.add_child(cell)
	you_col.add_child(grid)
	you_col.add_child(_lbl("AFFINITY %d" % view.affinity, 9, Palette.WHITE_DIM, Fonts.W_LABEL))
	row.add_child(you)

	var them := _panel_box("THEIR DANGER MAN")
	var them_col: VBoxContainer = them.get_child(0)
	var danger := _lbl(PlayerNames.upper(str(opp.get("name", "")), view.country, 0),
		14, Palette.WHITE, Fonts.W_BOLD)
	danger.name = "DangerName"
	them_col.add_child(danger)
	them_col.add_child(_lbl("TEAM RATING", 8, Palette.WHITE_DIM, Fonts.W_LABEL))
	row.add_child(them)
	return row

func _panel_box(kicker: String) -> PanelContainer:
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.add_theme_stylebox_override("panel", UIStyle.panel())
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.add_child(_lbl(kicker, 9, Palette.WHITE_DIM, Fonts.W_LABEL))
	p.add_child(v)
	return p

# One line naming the loadout going into this match. Boost is always ready at
# the start of a match (one press per innings), so the pip is static.
func _build_strip(view: SeasonView) -> Control:
	var names: Array = []
	for j in view.jokers:
		names.append(str(j.get("name", "")))
	var txt := "BUILD · " + (" · ".join(PackedStringArray(names)) if not names.is_empty() else "NO JOKERS")
	return _centered_line(txt + " · BOOST READY", Palette.WHITE_DIM, 10, Fonts.W_MEDIUM)

func _centered_line(txt: String, col: Color, size: int, weight: int) -> Label:
	var l := _lbl(txt, size, col, weight)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	return l

func _lbl(txt: String, size: int, col: Color, weight: int) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_color_override("font_color", col)
	l.add_theme_font_size_override("font_size", size)
	Fonts.weigh(l, weight)
	return l

func _stars(stars: float) -> String:
	return "★".repeat(maxi(int(round(stars)), 1)) + " · %.1f" % stars
