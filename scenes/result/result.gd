extends Control

# Result screen (nav-shell spec 2026-07-03, Slice 2; mockup section 5). The
# post-match payoff moment: verdict, broadcast scoreline, the Player's numbers,
# the tons earned (base + perf [+ win prize] = total, bank), and a handoff CTA
# that names where Continue goes (Kit Room / season end / hub). Dumb: renders
# what it is given. DN5 champion variant on a Final win; DN7 no KM recap or
# delta bars (no such domain concepts). No emoji.

signal continue_pressed()

# mr: the committed match. match_no: 1-based league number (unused in playoffs).
# stage: "" | "semi" | "final" | "third". pay: {"base","perf","prize","total"}
# (prize 0 on a loss; total includes it). bank: Player.tons_balance after
# banking. dest: "" | "KIT ROOM" | "SEASON END". champion: {} or
# {level_word, tour_name} — the Final-win celebration (DN5).
func set_result(mr: MatchResult, team_name: String, opp_name: String,
		match_no: int, stage: String, pay: Dictionary, bank: int,
		dest: String, champion: Dictionary) -> void:
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

	var won := mr.player_won()
	col.add_child(_centered(_kicker_text(match_no, stage), 10, Palette.WHITE_DIM, Fonts.W_LABEL))
	var verdict := _centered(mr.result_line_for_player().to_upper(), 22,
		Palette.GREEN if won else Palette.RED, Fonts.W_HEADLINE)
	verdict.autowrap_mode = TextServer.AUTOWRAP_WORD
	col.add_child(verdict)
	col.add_child(_scoreline(mr, team_name, opp_name))
	if not champion.is_empty():
		col.add_child(_champion_panel(champion))
	col.add_child(_perf_panel(mr))
	col.add_child(_tons_panel(pay, bank, won))

	var cta := Button.new()
	cta.name = "ContinueBtn"
	cta.text = "CONTINUE" if dest == "" else "CONTINUE — %s" % dest
	cta.custom_minimum_size = Vector2(0, 52)
	for state in ["normal", "hover", "pressed"]:
		cta.add_theme_stylebox_override(state, UIStyle.cta(Palette.GOLD))
	cta.add_theme_color_override("font_color", Palette.BG)
	cta.add_theme_font_size_override("font_size", 15)
	Fonts.weigh(cta, Fonts.W_HEADLINE)
	cta.pressed.connect(func(): continue_pressed.emit())
	col.add_child(cta)

func _kicker_text(match_no: int, stage: String) -> String:
	match stage:
		"semi": return "SEMI-FINAL · RESULT"
		"final": return "THE FINAL · RESULT"
		"third": return "3RD-PLACE MATCH · RESULT"
		_: return "MATCH %d · RESULT" % match_no

# Broadcast scoreline: both innings in played order, the winner's side gold.
func _scoreline(mr: MatchResult, team_name: String, opp_name: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var first_is_player := mr.player_bats_first
	var won := mr.player_won()
	row.add_child(_score_side(team_name if first_is_player else opp_name,
		mr.innings1, first_is_player == won, HORIZONTAL_ALIGNMENT_LEFT))
	var mid := _centered("def." if mr.margin_runs > 0 else "chased", 10,
		Palette.WHITE_DIM, Fonts.W_MEDIUM)
	mid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(mid)
	row.add_child(_score_side(opp_name if first_is_player else team_name,
		mr.innings2, first_is_player != won, HORIZONTAL_ALIGNMENT_RIGHT))
	return row

func _score_side(name_: String, inn: InningsResult, winner: bool, halign: int) -> Control:
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for spec: Array in [[name_, 12, Palette.WHITE if winner else Palette.WHITE_MID, Fonts.W_BOLD],
			["%d/%d" % [inn.total, inn.wickets], 20,
				Palette.GOLD if winner else Palette.WHITE_MID, Fonts.W_HEADLINE],
			["(%s ov)" % _overs(inn.balls), 9, Palette.WHITE_DIM, Fonts.W_MEDIUM]]:
		var l := _lbl(spec[0], spec[1], spec[2], spec[3])
		l.horizontal_alignment = halign
		v.add_child(l)
	return v

func _overs(balls: int) -> String:
	if balls % 6 == 0:
		return str(balls / 6)
	return "%d.%d" % [balls / 6, balls % 6]

# Gold trophy panel on a Final win: the beaten cell, named (DN5).
func _champion_panel(champion: Dictionary) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UIStyle.cta(Palette.GOLD))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	for spec: Array in [["CHAMPIONS", 18, Fonts.W_HEADLINE],
			["%s · %s" % [str(champion.get("level_word", "")).to_upper(),
				str(champion.get("tour_name", "")).to_upper()], 11, Fonts.W_BOLD],
			["Season beaten", 9, Fonts.W_MEDIUM]]:
		var l := _lbl(spec[0], spec[1], Palette.BG, spec[2])
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(l)
	p.add_child(v)
	return p

# The Player's numbers: batting from the innings holding the player line,
# bowling from the other one. Every value real (DN1); tiles the data can't
# honestly fill (4s/6s, KMs won) are dropped, not faked (DN7).
func _perf_panel(mr: MatchResult) -> Control:
	var bat := mr.innings1
	var bowl := mr.innings2
	if bat.player_line().is_empty():
		bat = mr.innings2
		bowl = mr.innings1
	var line := bat.player_line()
	var runs := int(line.get("runs", 0))
	var balls := int(line.get("balls", 0))
	var out_ := bool(line.get("out", true))
	var sr := "%d" % int(round(runs * 100.0 / balls)) if balls > 0 else "—"
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UIStyle.panel())
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.add_child(_lbl("YOUR MATCH", 9, Palette.WHITE_DIM, Fonts.W_LABEL))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 18)
	for pair: Array in [["%d%s" % [runs, "" if out_ else "*"], "RUNS"],
			[str(balls), "BALLS"], [sr, "SR"],
			["%d/%d" % [bowl.player_bowl_wickets, bowl.player_bowl_runs]
				if bowl.player_bowl_balls > 0 else "—", "BOWL"]]:
		var cell := VBoxContainer.new()
		cell.add_child(_lbl(pair[0], 16, Palette.WHITE, Fonts.W_BOLD))
		cell.add_child(_lbl(pair[1], 8, Palette.WHITE_DIM, Fonts.W_LABEL))
		grid.add_child(cell)
	v.add_child(grid)
	p.add_child(v)
	return p

# The tons earned: gold hero total, the breakdown line, the new bank balance.
func _tons_panel(pay: Dictionary, bank: int, won: bool) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UIStyle.panel())
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	var hero := _lbl("+%d" % int(pay.get("total", 0)), 26, Palette.GOLD, Fonts.W_HEADLINE)
	hero.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(hero)
	var brk := "base %d + perf %d" % [int(pay.get("base", 0)), int(pay.get("perf", 0))]
	if won and int(pay.get("prize", 0)) > 0:
		brk += " + win prize %d" % int(pay.get("prize", 0))
	var brk_l := _centered(brk, 10, Palette.WHITE_MID, Fonts.W_MEDIUM)
	v.add_child(brk_l)
	v.add_child(_centered("bank now %s" % _thousands(bank), 10, Palette.WHITE_DIM, Fonts.W_MEDIUM))
	p.add_child(v)
	return p

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

func _centered(txt: String, size: int, col: Color, weight: int) -> Label:
	var l := _lbl(txt, size, col, weight)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

func _lbl(txt: String, size: int, col: Color, weight: int) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_color_override("font_color", col)
	l.add_theme_font_size_override("font_size", size)
	Fonts.weigh(l, weight)
	return l
