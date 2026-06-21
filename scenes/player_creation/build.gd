extends Control

# Player Creation — Screen 2: Build (hi-fi).
# Receives a PlayerCreationDraft from Identity, lets the user distribute the
# fixed creation budget across 4 attributes, then confirms → persists Player +
# emits confirmed. The screen is built IN CODE on the shared Palette/UIStyle/
# Fonts foundation (player-creation-v2.html "Build" band), so the custom slider
# theming + gradient panels live in one place. Pure UI — no sim/data behaviour
# changed (spec 2026-06-21-player-creation-build-hifi-design.md).

# back_pressed carries the draft so the router can re-hydrate Identity with the
# user's picks intact (spec §4: Back preserves picks).
signal back_pressed(draft: PlayerCreationDraft)
signal confirmed(player: Player)

# Balanced-state mark on the points chip. Verified to render in Barlow (it's a
# dingbat, not an emoji); if a future face tofus it, drop to plain text.
const _BALANCED_MARK := "✓"

# Flavour blurbs, keyed by the 4 real ClassifierLabel.Kind values. Display-only —
# zero impact on the sim (mirrors PlayerNames flavour). Honest, generic one-liners.
const BLURBS := {
	ClassifierLabel.Kind.BATTER:      "A top-order specialist — runs are your trade, the ball an afterthought.",
	ClassifierLabel.Kind.WK_BATTER:   "Gloves and a cool head — you anchor the innings and keep tidy.",
	ClassifierLabel.Kind.BOWLER:      "A frontline bowler who hunts wickets and squeezes the run rate.",
	ClassifierLabel.Kind.ALL_ROUNDER: "Two strings to your bow — you chip in with bat and ball alike.",
}

var _draft: PlayerCreationDraft
var _accent: Color = Palette.COUNTRY_ACCENT_SA

# Nodes built in _build_ui (named members so the scene tests can reach them).
var _kicker_label: Label
var _title_label: Label
var _points_value: Label
var _power_slider: HSlider
var _composure_slider: HSlider
var _attack_slider: HSlider
var _control_slider: HSlider
var _power_readout: Label
var _composure_readout: Label
var _attack_readout: Label
var _control_readout: Label
var _classifier_label: Label
var _classifier_blurb: Label
var _back_btn: Button
var _confirm_btn: Button

func set_draft(draft: PlayerCreationDraft) -> void:
	_draft = draft
	if is_node_ready():
		_push_draft_to_ui()

func _ready() -> void:
	if _draft == null:
		_draft = PlayerCreationDraft.new()
	_accent = Palette.country_set(_draft.country)["accent"]
	_build_ui()
	_push_draft_to_ui()

# ── layout ──────────────────────────────────────────────────────────────────

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Palette.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 13)
	margin.add_child(root)

	root.add_child(_build_header())

	var body := VBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 13)
	root.add_child(body)

	body.add_child(_build_points_bar())
	body.add_child(_build_group("BATTING", Palette.GOLD, [
		["power", "Power", "boundaries"], ["composure", "Composure", "resists dismissal"]]))
	body.add_child(_build_group("BOWLING", Palette.BLUE, [
		["attack", "Attack", "wicket chance"], ["control", "Control", "economy"]]))
	body.add_child(_build_classifier())

	_confirm_btn = Button.new()
	# No emoji — Barlow (the app-wide face) has no cricket-bat glyph, so 🏏 renders
	# as tofu. Plain text reads clean and on-brand.
	_confirm_btn.text = "Begin Career"
	_confirm_btn.add_theme_stylebox_override("normal", UIStyle.cta(Palette.GOLD))
	_confirm_btn.add_theme_stylebox_override("hover", UIStyle.cta(Palette.GOLD.lightened(0.05)))
	_confirm_btn.add_theme_stylebox_override("pressed", UIStyle.cta(Palette.GOLD_DEEP))
	_confirm_btn.add_theme_stylebox_override("disabled", UIStyle.cta(Color(Palette.GOLD.r, Palette.GOLD.g, Palette.GOLD.b, 0.35)))
	_confirm_btn.add_theme_color_override("font_color", Palette.BG)
	_confirm_btn.add_theme_color_override("font_disabled_color", Color(0, 0, 0, 0.5))
	Fonts.weigh(_confirm_btn, Fonts.W_BOLD)
	_confirm_btn.add_theme_font_size_override("font_size", 15)
	_confirm_btn.pressed.connect(_on_confirm_pressed)
	root.add_child(_confirm_btn)

func _build_header() -> Control:
	var panel := PanelContainer.new()
	var cset := Palette.country_set(_draft.country)
	panel.add_theme_stylebox_override("panel", UIStyle.header(cset["grad1"], cset["grad2"], cset["glow"]))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)

	_back_btn = Button.new()
	_back_btn.text = "←"
	_back_btn.custom_minimum_size = Vector2(26, 26)  # match the hub's ⓘ/⚙ corner family
	_back_btn.add_theme_stylebox_override("normal", UIStyle.corner_btn())
	_back_btn.add_theme_stylebox_override("hover", UIStyle.corner_btn())
	_back_btn.add_theme_stylebox_override("pressed", UIStyle.corner_btn())
	_back_btn.add_theme_color_override("font_color", Palette.WHITE_SOFT)
	_back_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_back_btn.pressed.connect(func(): back_pressed.emit(_draft))
	row.add_child(_back_btn)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 2)
	_kicker_label = _lbl("", 10, Color(1, 1, 1, 0.8), Fonts.W_LABEL)
	_title_label = _lbl("Build your game", 19, Color.WHITE, Fonts.W_HEADLINE)
	col.add_child(_kicker_label)
	col.add_child(_title_label)
	row.add_child(col)

	var dots := HBoxContainer.new()
	dots.add_theme_constant_override("separation", 5)
	dots.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dots.add_child(_dot(Color(1, 1, 1, 0.3)))
	dots.add_child(_dot(_accent))
	row.add_child(dots)
	return panel

# Design review #2: the global "spent" progress bar was always full on a valid
# build (every build sums to exactly 44), so it carried no info and read wrong
# ("full" usually = done, here full = correct). Reframed as a balance-status
# chip — the per-slider fills carry "where my points went"; this only shouts when
# the build is invalid. POINTS microlabel + a state-coloured `<sum> / 44` value.
func _build_points_bar() -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIStyle.points_bar())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)
	var lbl := _lbl("POINTS", 9, Palette.WHITE_DIM, Fonts.W_LABEL)
	lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(lbl)
	_points_value = _lbl("", 16, Palette.GREEN, Fonts.W_HEADLINE, true, HORIZONTAL_ALIGNMENT_RIGHT)
	_points_value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_points_value)
	return panel

func _build_group(title: String, icon_col: Color, rows: Array) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIStyle.attr_group())
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 13)
	panel.add_child(col)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 7)
	var ico := Panel.new()
	ico.custom_minimum_size = Vector2(14, 14)
	ico.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ico.add_theme_stylebox_override("panel", UIStyle.group_icon(icon_col))
	head.add_child(ico)
	head.add_child(_lbl(title, 9, Palette.WHITE_SOFT, Fonts.W_LABEL))
	col.add_child(head)

	for r in rows:
		col.add_child(_build_attr_row(r[0], r[1], r[2]))
	return panel

func _build_attr_row(key: String, name_text: String, desc: String) -> Control:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	var head := HBoxContainer.new()
	var name_col := HBoxContainer.new()
	name_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_col.add_theme_constant_override("separation", 6)
	name_col.add_child(_lbl(name_text, 13, Palette.WHITE, Fonts.W_LABEL))
	var desc_lbl := _lbl(desc, 10, Palette.WHITE_DIM, Fonts.W_BODY)
	desc_lbl.size_flags_vertical = Control.SIZE_SHRINK_END
	name_col.add_child(desc_lbl)
	head.add_child(name_col)
	var num := _lbl("", 15, _accent, Fonts.W_BOLD, true, HORIZONTAL_ALIGNMENT_RIGHT)
	head.add_child(num)
	row.add_child(head)

	var slider := HSlider.new()
	slider.min_value = Attributes.CREATION_MIN
	slider.max_value = Attributes.CREATION_MAX
	slider.step = 1
	slider.custom_minimum_size = Vector2(0, 22)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.add_theme_stylebox_override("slider", UIStyle.slider_track())
	slider.add_theme_stylebox_override("grabber_area", UIStyle.slider_fill(_accent))
	slider.add_theme_stylebox_override("grabber_area_highlight", UIStyle.slider_fill(_accent))
	var grab := UIStyle.slider_grabber(_accent)
	slider.add_theme_icon_override("grabber", grab)
	slider.add_theme_icon_override("grabber_highlight", grab)
	slider.value_changed.connect(_on_slider_changed)
	row.add_child(slider)

	match key:
		"power":     _power_slider = slider;     _power_readout = num
		"composure": _composure_slider = slider; _composure_readout = num
		"attack":    _attack_slider = slider;    _attack_readout = num
		"control":   _control_slider = slider;   _control_readout = num
	return row

func _build_classifier() -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIStyle.classifier_panel(_accent))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	panel.add_child(col)
	col.add_child(_lbl("YOU'LL START AS A", 9, Palette.WHITE_DIM, Fonts.W_LABEL))
	_classifier_label = _lbl("", 21, _accent, Fonts.W_HEADLINE)
	col.add_child(_classifier_label)
	_classifier_blurb = _lbl("", 11, Palette.WHITE_MID, Fonts.W_BODY)
	_classifier_blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_classifier_blurb)
	return panel

func _lbl(text: String, size: int, color: Color, weight: int, tabular: bool = false,
		halign: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = halign
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_size_override("font_size", size)
	Fonts.weigh(l, weight, tabular)
	return l

func _dot(col: Color) -> Control:
	var d := ColorRect.new()
	d.color = col
	d.custom_minimum_size = Vector2(7, 7)
	d.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return d

# ── data binding (behaviour preserved from the low-fi screen) ────────────────

func _on_slider_changed(_v: float) -> void:
	_draft.attributes.power     = _power_slider.value
	_draft.attributes.composure = _composure_slider.value
	_draft.attributes.attack    = _attack_slider.value
	_draft.attributes.control   = _control_slider.value
	_refresh()

func _push_draft_to_ui() -> void:
	# set_value_no_signal: writing a slider value normally emits value_changed,
	# which fires _on_slider_changed mid-update and reads the OTHER (not-yet-pushed)
	# sliders back into the draft — corrupting it. Push silently then refresh once.
	_power_slider.set_value_no_signal(_draft.attributes.power)
	_composure_slider.set_value_no_signal(_draft.attributes.composure)
	_attack_slider.set_value_no_signal(_draft.attributes.attack)
	_control_slider.set_value_no_signal(_draft.attributes.control)
	var name_text := _draft.name.display_caps() if _draft.name != null else "NEW PLAYER"
	_kicker_label.text = "NEW PLAYER · %s" % name_text
	_refresh()

func _refresh() -> void:
	# Readouts show the /100 card the player understands (Display), not the raw
	# internal points the budget is spent in (world-scale v2 WS6).
	_power_readout.text     = str(Display.to_card_round(_draft.attributes.power))
	_composure_readout.text = str(Display.to_card_round(_draft.attributes.composure))
	_attack_readout.text    = str(Display.to_card_round(_draft.attributes.attack))
	_control_readout.text   = str(Display.to_card_round(_draft.attributes.control))

	# Balance-status chip (design review #2): GREEN balanced · RED over · GOLD under.
	# Colour via modulate so the whole "<sum> / 44 …" line reads as one state.
	var spent := int(round(_draft.attributes.sum()))
	var total := int(round(Attributes.CREATION_TOTAL))
	var valid := _draft.attributes.is_valid_creation_distribution()
	var base := "%d / %d" % [spent, total]
	if valid:
		_points_value.text = "%s  %s" % [base, _BALANCED_MARK]
		_points_value.modulate = Palette.GREEN
	elif spent > total:
		_points_value.text = "%s · %d over" % [base, spent - total]
		_points_value.modulate = Palette.RED
	else:
		_points_value.text = "%s · %d to spend" % [base, total - spent]
		_points_value.modulate = Palette.GOLD

	var kind := Classifier.classify(_draft.attributes)
	_classifier_label.text = ClassifierLabel.display_name(kind)
	_classifier_blurb.text = BLURBS.get(kind, "")

	_confirm_btn.disabled = not valid

func _on_confirm_pressed() -> void:
	if not _draft.attributes.is_valid_creation_distribution():
		return
	var player := Player.from_draft(_draft)
	SaveManager.save_player(player)
	confirmed.emit(player)
