extends Control

# Season Outcome screen (live-season-loop Slice 2). Low-fi: shown when the live
# SeasonPlay finishes (season_done()) — surfaces where you finished + the ₸ banked
# this season, with a Continue button back to a fresh season. A hi-fi outcome /
# offers screen is a later presentation rung. Built in code (no .tscn authoring);
# the .tscn is just the root Control + this script.

signal continue_pressed()

func set_outcome(result: SeasonResult, pay: int, wins: int,
		career: CareerState = null, transition: Dictionary = {}) -> void:
	var pos := result.player_final_position
	var made_playoffs := pos <= 4
	var games := 7 + (2 if made_playoffs else 0)

	# Background fills the screen so nothing from the prior scene shows through.
	var bg := ColorRect.new()
	bg.color = Palette.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(300, 0)
	col.add_theme_constant_override("separation", 16)
	center.add_child(col)

	# Kicker
	var kicker := Label.new()
	kicker.name = "Kicker"
	kicker.text = "SEASON COMPLETE"
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kicker.add_theme_color_override("font_color", Palette.WHITE_DIM)
	kicker.add_theme_font_size_override("font_size", 11)
	Fonts.weigh(kicker, Fonts.W_BOLD)
	col.add_child(kicker)

	# Headline — the finish, gold for a podium, muted otherwise.
	var head := Label.new()
	head.name = "Headline"
	head.text = _headline(pos)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_theme_color_override("font_color", Palette.GOLD if pos <= 3 else Palette.WHITE)
	head.add_theme_font_size_override("font_size", 26)
	Fonts.weigh(head, Fonts.W_HEADLINE)
	col.add_child(head)

	# Transition banner — the central "what just happened to the career" line
	# (cleared a tour / promoted a Level / champion / a not-beaten retry). Gold when
	# you advanced. No emoji — Barlow Semi Condensed tofus them.
	var b := _banner_for(transition, career)
	var banner := Label.new()
	banner.name = "Banner"
	banner.text = b["text"]
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	banner.add_theme_color_override("font_color", b["color"])
	banner.add_theme_font_size_override("font_size", 15)
	Fonts.weigh(banner, Fonts.W_BOLD)
	col.add_child(banner)

	# Stats panel: final position, record, ₸ banked.
	var panel := PanelContainer.new()
	panel.name = "StatsPanel"
	panel.add_theme_stylebox_override("panel", UIStyle.panel())
	col.add_child(panel)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 10)
	panel.add_child(rows)
	rows.add_child(_stat_row("FINISHED", _ordinal(pos), Palette.WHITE))
	rows.add_child(_stat_row("RECORD", "%d of %d won" % [wins, games], Palette.WHITE))
	rows.add_child(_stat_row("₸ BANKED", "₸ %d" % pay, Palette.GOLD))

	# Next-up chip — where Continue takes you (next cell, or the Hall of Fame).
	var nextup := Label.new()
	nextup.name = "NextUp"
	nextup.text = _next_up_text(transition)
	nextup.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nextup.add_theme_color_override("font_color", Palette.WHITE_DIM)
	nextup.add_theme_font_size_override("font_size", 11)
	Fonts.weigh(nextup, Fonts.W_MEDIUM)
	col.add_child(nextup)

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

func _stat_row(cap: String, value: String, value_col: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = cap
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_theme_color_override("font_color", Palette.WHITE_DIM)
	l.add_theme_font_size_override("font_size", 11)
	Fonts.weigh(l, Fonts.W_BOLD)
	row.add_child(l)
	var v := Label.new()
	v.text = value
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_theme_color_override("font_color", value_col)
	v.add_theme_font_size_override("font_size", 14)
	Fonts.weigh(v, Fonts.W_BOLD, true)
	row.add_child(v)
	return row

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
