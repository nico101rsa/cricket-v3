extends Control

# Season Outcome screen, hi-fi skin (outcome-hifi spec 2026-07-03, DO1-DO6).
# Shown when the live SeasonPlay finishes (after the Offers pick, before the
# Career Grid): country-gradient header band (kicker + headline), the career
# transition strip (gold celebration on promoted/complete), season stat tiles,
# next-up pill, gold Continue. Presentation only — banner wording, routing and
# the continue_pressed signal are the PR #101/#104/#107 behaviour, unchanged.
# Built in code; the .tscn is just the root Control + this script. No emoji.

signal continue_pressed()

func set_outcome(result: SeasonResult, pay: int, wins: int,
		career: CareerState = null, transition: Dictionary = {},
		country: int = Country.Code.SA) -> void:
	var pos := result.player_final_position
	var made_playoffs := pos <= 4
	var games := 7 + (2 if made_playoffs else 0)
	var cset := Palette.country_set(country)

	# Background fills the screen so nothing from the prior scene shows through.
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

	col.add_child(_header_band(pos, cset))
	col.add_child(_transition_strip(transition, career))
	col.add_child(_stat_tiles(pos, wins, games, pay))
	col.add_child(_next_up_pill(transition))

	# Continue CTA.
	var cta := Button.new()
	cta.name = "ContinueBtn"
	cta.text = _cta_text(transition)
	cta.custom_minimum_size = Vector2(0, 52)
	cta.add_theme_stylebox_override("normal", UIStyle.cta(Palette.GOLD))
	cta.add_theme_stylebox_override("hover", UIStyle.cta(Palette.GOLD.lightened(0.05)))
	cta.add_theme_stylebox_override("pressed", UIStyle.cta(Palette.GOLD_DEEP))
	cta.add_theme_color_override("font_color", Palette.BG)
	cta.add_theme_font_size_override("font_size", 15)
	Fonts.weigh(cta, Fonts.W_BOLD)
	cta.pressed.connect(func(): continue_pressed.emit())
	col.add_child(cta)

# Country-gradient band: kicker over the big finish headline (Identity/hub idiom).
func _header_band(pos: int, cset: Dictionary) -> Control:
	var band := PanelContainer.new()
	band.name = "HeaderBand"
	band.add_theme_stylebox_override("panel",
		UIStyle.header(cset["grad1"], cset["grad2"], cset["glow"]))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	var kicker := _centered("SEASON COMPLETE", 11, Palette.WHITE_SOFT, Fonts.W_LABEL)
	kicker.name = "Kicker"
	v.add_child(kicker)
	var head := _centered(_headline(pos), 26,
		Palette.GOLD if pos <= 3 else Palette.WHITE, Fonts.W_HEADLINE)
	head.name = "Headline"
	head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(head)
	band.add_child(v)
	return band

# The career-consequence strip. Promoted/complete celebrate on the gold panel
# (Result-screen champion idiom, dark text); everything else is a surface strip
# in the banner's own colour (DO2). Wording from _banner_for, unchanged.
func _transition_strip(transition: Dictionary, career: CareerState) -> Control:
	var b := _banner_for(transition, career)
	var celebrate: bool = transition.get("complete", false) \
		or transition.get("promoted", false)
	var strip := PanelContainer.new()
	strip.name = "TransitionStrip"
	strip.add_theme_stylebox_override("panel",
		UIStyle.cta(Palette.GOLD) if celebrate else UIStyle.panel())
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 1)
	var banner := _centered(b["text"], 15,
		Palette.BG if celebrate else b["color"], Fonts.W_BOLD)
	banner.name = "Banner"
	banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(banner)
	# Sub-line only on a promotion — the complete banner already says it all.
	if celebrate and not transition.get("complete", false):
		v.add_child(_centered("YOUR CAREER MOVES UP", 9, Palette.BG, Fonts.W_MEDIUM))
	strip.add_child(v)
	return strip

# Season stat tiles: value-over-label cells (Result perf-grid idiom, DO6).
func _stat_tiles(pos: int, wins: int, games: int, pay: int) -> Control:
	var panel := PanelContainer.new()
	panel.name = "StatsPanel"
	panel.add_theme_stylebox_override("panel", UIStyle.panel())
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	for spec: Array in [[_ordinal(pos), "FINISHED", Palette.WHITE],
			["%d of %d won" % [wins, games], "RECORD", Palette.WHITE],
			["₸ %d" % pay, "BANKED", Palette.GOLD]]:
		var cell := VBoxContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var val := _centered(spec[0], 16, spec[2], Fonts.W_BOLD)
		Fonts.weigh(val, Fonts.W_BOLD, true)
		cell.add_child(val)
		cell.add_child(_centered(spec[1], 8, Palette.WHITE_DIM, Fonts.W_LABEL))
		grid.add_child(cell)
	panel.add_child(grid)
	return panel

# Where Continue takes you, as a centred pill chip.
func _next_up_pill(transition: Dictionary) -> Control:
	var wrap := CenterContainer.new()
	var pill := PanelContainer.new()
	pill.add_theme_stylebox_override("panel", UIStyle.pill(Palette.SURFACE_2))
	var l := _centered(_next_up_text(transition), 11, Palette.WHITE_DIM, Fonts.W_MEDIUM)
	l.name = "NextUp"
	pill.add_child(l)
	wrap.add_child(pill)
	return wrap

func _centered(txt: String, size: int, col: Color, weight: int) -> Label:
	var l := Label.new()
	l.text = txt
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", col)
	l.add_theme_font_size_override("font_size", size)
	Fonts.weigh(l, weight)
	return l

func _headline(pos: int) -> String:
	match pos:
		1: return "CHAMPIONS"
		2: return "RUNNERS-UP"
		3: return "3RD PLACE"
		4: return "SEMI-FINAL EXIT"
		_: return "MISSED THE PLAYOFFS"

# The career-transition banner (spec 2026-06-24; offers cases 2026-07-02).
# Reads the descriptor returned by CareerResolver.finish_live_advance. Tours
# are 1-indexed for display.
func _banner_for(t: Dictionary, career: CareerState) -> Dictionary:
	if t.get("complete", false):
		return {"text": "PROVINCE CHAMPIONS · CAREER COMPLETE", "color": Palette.GOLD}
	if t.get("promoted", false):
		return {"text": "PROMOTED TO %s" % _level_word(t.get("to_level", 0)).to_upper(),
			"color": Palette.GOLD}
	if int(t.get("to_level", 0)) < int(t.get("from_level", 0)):
		return {"text": "MOVED DOWN TO %s" % _level_word(t.get("to_level", 0)).to_upper(),
			"color": Palette.WHITE}
	if t.get("team_changed", false):
		return {"text": "SIGNED FOR %s" % _new_team_name(career), "color": Palette.WHITE}
	if t.get("beat", false):
		return {"text": "%s · TOUR %d CLEARED" %
			[_level_word(t.get("from_level", 0)).to_upper(), int(t.get("tour", 0)) + 1],
			"color": Palette.WHITE}
	return {"text": "MISSED OUT · ANOTHER GO", "color": Palette.WHITE_DIM}

func _next_up_text(t: Dictionary) -> String:
	if t.get("complete", false):
		return "NEXT: HALL OF FAME"
	return "NEXT: %s · TOUR %d" % [
		_level_word(t.get("next_level", 0)).to_upper(), int(t.get("next_tour", 0)) + 1]

func _cta_text(t: Dictionary) -> String:
	return "ENTER THE HALL OF FAME  >" if t.get("complete", false) else "CONTINUE  >"

func _new_team_name(career: CareerState) -> String:
	if career == null:
		return "A NEW TEAM"
	return career.teams[career.current_team_index].team_name.to_upper()

func _level_word(level: int) -> String:
	return ["Club", "City", "Province"][clampi(level, 0, 2)]

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
