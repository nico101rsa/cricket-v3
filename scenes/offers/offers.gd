extends Control

# The Offers screen (spec 2026-07-02-offers-screen-design.md, DO6) — season
# end, between the carry-over election and the Outcome: pick a team offer or
# stay. Low-fi in-house skin (Palette/UIStyle/Fonts), code-built like the
# Outcome screen. Dumb: renders what it is given, emits the pick, no domain
# math. No emoji (Barlow tofus them).

signal offer_picked(offer)   # the tapped Offer row, or null = STAY

func set_offers(career: CareerState, offers: Array) -> void:
	var current: Team = career.teams[career.current_team_index]
	var cur_level := career.current_level()

	var bg := ColorRect.new()
	bg.color = Palette.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(320, 0)
	col.add_theme_constant_override("separation", 14)
	center.add_child(col)

	var kicker := Label.new()
	kicker.name = "Kicker"
	kicker.text = "OFF-SEASON"
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kicker.add_theme_color_override("font_color", Palette.WHITE_DIM)
	kicker.add_theme_font_size_override("font_size", 11)
	Fonts.weigh(kicker, Fonts.W_BOLD)
	col.add_child(kicker)

	var title := Label.new()
	title.name = "Title"
	title.text = "Offers are in"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Palette.WHITE)
	title.add_theme_font_size_override("font_size", 26)
	Fonts.weigh(title, Fonts.W_HEADLINE)
	col.add_child(title)

	var cur := Label.new()
	cur.name = "CurrentTeam"
	cur.text = "You're with %s · %s" % [current.team_name, _level_word(cur_level)]
	cur.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cur.add_theme_color_override("font_color", Palette.WHITE_DIM)
	cur.add_theme_font_size_override("font_size", 12)
	Fonts.weigh(cur, Fonts.W_MEDIUM)
	col.add_child(cur)

	for i in range(offers.size()):
		col.add_child(_offer_button(i, offers[i], cur_level, career))

	col.add_child(_stay_button(current))

# One offer row: team name over "LEVEL · n.n★ [· TAG]". Gold skin on a step up.
func _offer_button(i: int, offer: Offer, cur_level: int, career: CareerState) -> Button:
	var team: Team = career.teams[offer.team_index]
	var up := offer.level > cur_level
	var tag := ""
	if up:
		tag = " · STEP UP"
	elif offer.level < cur_level:
		tag = " · DROP DOWN"
	var sub := "%s · %.1f★%s" % [_level_word(offer.level).to_upper(), offer.stars, tag]
	var b := _two_line_btn(team.team_name, sub,
		Palette.BG if up else Palette.WHITE,
		UIStyle.cta(Palette.GOLD) if up else UIStyle.panel())
	b.name = "OfferBtn%d" % i
	b.pressed.connect(func(): offer_picked.emit(offer))
	return b

func _stay_button(current: Team) -> Button:
	var b := _two_line_btn("Stay with %s" % current.team_name, "LOYALTY +1",
		Palette.WHITE_DIM, UIStyle.panel())
	b.name = "StayBtn"
	b.pressed.connect(func(): offer_picked.emit(null))
	return b

# A Button whose face is two stacked Labels (a bare Button doesn't wrap \n).
func _two_line_btn(top: String, sub: String, top_col: Color, box: StyleBox) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 56)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for state in ["normal", "hover", "pressed"]:
		b.add_theme_stylebox_override(state, box)
	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top_l := Label.new()
	top_l.text = top
	top_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top_l.add_theme_color_override("font_color", top_col)
	top_l.add_theme_font_size_override("font_size", 14)
	top_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Fonts.weigh(top_l, Fonts.W_BOLD)
	vb.add_child(top_l)
	var sub_l := Label.new()
	sub_l.text = sub
	sub_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_l.add_theme_color_override("font_color", top_col if top_col == Palette.BG else Palette.WHITE_DIM)
	sub_l.add_theme_font_size_override("font_size", 10)
	sub_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Fonts.weigh(sub_l, Fonts.W_MEDIUM)
	vb.add_child(sub_l)
	b.add_child(vb)
	return b

func _level_word(level: int) -> String:
	return ["Club", "City", "Province"][clampi(level, 0, 2)]
