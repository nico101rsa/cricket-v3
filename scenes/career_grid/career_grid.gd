extends Control

# Career Grid screen (nav-shell spec 2026-07-03, Slice 3; mockup section 6,
# ADR 0010 §3): the between-Seasons home. Career header (all counters real),
# the LadderMap, a legend, and START SEASON at the one playable cell. Dumb and
# read-only: renders the CareerState it is given, emits start_season. DN8: no
# node picking — CareerResolver.next_live_cell is the single playable cell.
# DN9: no career-stats block (no career aggregates exist in the domain).
# No emoji.

signal start_season()

func set_career(career: CareerState, player: Player) -> void:
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

	col.add_child(_header(career, player))

	var map := LadderMap.new()
	map.name = "Map"
	map.custom_minimum_size = Vector2(340, 300)   # explicit height — collapse trap
	var cell := CareerResolver.next_live_cell(career)
	map.set_state(career.cell_status, career.level_won, cell, Palette.GOLD_WARN)
	col.add_child(map)

	col.add_child(_legend())

	var cta := Button.new()
	cta.name = "StartBtn"
	cta.text = "START SEASON — %s · %s" % [_level_word(int(cell["level"])).to_upper(),
		str(DifficultyLadder.TOUR_NAMES[int(cell["tour"])]).to_upper()]
	cta.custom_minimum_size = Vector2(0, 52)
	for state in ["normal", "hover", "pressed"]:
		cta.add_theme_stylebox_override(state, UIStyle.cta(Palette.GOLD))
	cta.add_theme_color_override("font_color", Palette.BG)
	cta.add_theme_font_size_override("font_size", 15)
	Fonts.weigh(cta, Fonts.W_HEADLINE)
	cta.pressed.connect(func(): start_season.emit())
	col.add_child(cta)

# Country + ₸ on top; three real counters under it.
func _header(career: CareerState, player: Player) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UIStyle.panel())
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)

	var top := HBoxContainer.new()
	var country := _lbl(Country.display_name(player.country), 15, Palette.WHITE, Fonts.W_HEADLINE)
	country.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(country)
	top.add_child(_lbl("₸ %s" % _thousands(player.tons_balance), 15, Palette.GOLD, Fonts.W_BOLD))
	v.add_child(top)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var lvls_won := 0
	for w in career.level_won:
		if w:
			lvls_won += 1
	for pair: Array in [[str(career.seasons_played), "SEASONS PLAYED"],
			[career.teams[career.current_team_index].team_name, "CURRENT TEAM"],
			["%d / 3" % lvls_won, "LEVELS WON"]]:
		var cell := VBoxContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_child(_lbl(pair[0], 13, Palette.WHITE, Fonts.W_BOLD))
		cell.add_child(_lbl(pair[1], 8, Palette.WHITE_DIM, Fonts.W_LABEL))
		row.add_child(cell)
	v.add_child(row)
	p.add_child(v)
	return p

# Swatch + word per node state (colour swatches, not glyphs — no emoji/tofu).
func _legend() -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	for pair: Array in [[Palette.GREEN_DARK, "BEATEN"], [Palette.GOLD, "WON"],
			[Palette.GOLD_WARN, "HERE"], [Color(Palette.WHITE_DIM, 0.3), "LOCKED"]]:
		var item := HBoxContainer.new()
		item.add_theme_constant_override("separation", 4)
		var sw := ColorRect.new()
		sw.color = pair[0]
		sw.custom_minimum_size = Vector2(10, 10)
		sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		item.add_child(sw)
		item.add_child(_lbl(pair[1], 8, Palette.WHITE_DIM, Fonts.W_LABEL))
		row.add_child(item)
	return row

func _thousands(n: int) -> String:
	var s := str(n)
	var out := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		count += 1
		if count % 3 == 0 and i > 0 and s[i - 1] != "-":
			out = "," + out
	return out

func _level_word(level: int) -> String:
	return ["Club", "City", "Province"][clampi(level, 0, 2)]

func _lbl(txt: String, size: int, col: Color, weight: int) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_color_override("font_color", col)
	l.add_theme_font_size_override("font_size", size)
	Fonts.weigh(l, weight)
	return l
