extends Control

# Player Creation — Screen 1: Identity (hi-fi).
# The portrait-anchored "Who are you?" screen: country toggle · city · appearance
# picker · name & re-roll. Built IN CODE on the shared Palette/UIStyle/Fonts
# foundation (player-creation-v2.html "Identity" band), mirroring the Build screen
# (PRs #94/#95). Owns the in-progress PlayerCreationDraft and hands it to Build on
# Next. Pure UI — all Screen-1 behaviour is carried over byte-for-byte from the
# low-fi screen (spec 2026-06-21-player-creation-identity-hifi-design.md).

signal advance_to_build(draft: PlayerCreationDraft)

const _HERO_PORTRAIT := preload("res://assets/portraits/hero-cap.png")

var _draft: PlayerCreationDraft
var _rng: RandomNumberGenerator
var _accent: Color = Palette.COUNTRY_ACCENT_SA

# Nodes built in _build_ui (named members so the scene tests can reach them).
var _header_panel: PanelContainer
var _active_dot: ColorRect
var _kicker_label: Label
var _title_label: Label
var _hero_portrait: TextureRect
var _name_label: Label
var _name_sub: Label
var _reroll_btn: Button
var _country_sa_btn: Button
var _country_aus_btn: Button
var _city_dropdown: OptionButton
var _appearance_picker: AppearancePicker
var _next_btn: Button

# Called by the router when navigating BACK from Build, so the screen re-hydrates
# from the in-progress draft instead of starting blank (spec §4: Back preserves picks).
func set_draft(draft: PlayerCreationDraft) -> void:
	_draft = draft
	if is_node_ready():
		_apply_accent()
		_refresh_all()

func _ready() -> void:
	if _draft == null:
		_draft = PlayerCreationDraft.new()  # fresh cold-start; set_draft() not used
	_rng = RandomNumberGenerator.new()
	_rng.randomize()
	_build_ui()
	_apply_accent()
	_refresh_all()  # doubles as hydration — paints whatever the draft currently holds

# ── layout ───────────────────────────────────────────────────────────────────

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
	body.add_theme_constant_override("separation", 14)
	root.add_child(body)

	body.add_child(_build_hero())
	body.add_child(_build_name_block())
	body.add_child(_build_country_toggle())
	body.add_child(_build_city_pill())
	body.add_child(_build_appearance())

	_next_btn = Button.new()
	# Arrow is a dingbat (renders in Barlow); no emoji in the CTA — the app-wide
	# face has no emoji glyphs (the Build rung learned this).
	_next_btn.text = "Next — Build your game  →"
	_next_btn.add_theme_stylebox_override("normal", UIStyle.cta(Palette.GOLD))
	_next_btn.add_theme_stylebox_override("hover", UIStyle.cta(Palette.GOLD.lightened(0.05)))
	_next_btn.add_theme_stylebox_override("pressed", UIStyle.cta(Palette.GOLD_DEEP))
	_next_btn.add_theme_stylebox_override("disabled", UIStyle.cta(Color(Palette.GOLD.r, Palette.GOLD.g, Palette.GOLD.b, 0.35)))
	_next_btn.add_theme_color_override("font_color", Palette.BG)
	_next_btn.add_theme_color_override("font_disabled_color", Color(0, 0, 0, 0.5))
	Fonts.weigh(_next_btn, Fonts.W_BOLD)
	_next_btn.add_theme_font_size_override("font_size", 15)
	_next_btn.pressed.connect(_on_next_pressed)
	root.add_child(_next_btn)

func _build_header() -> Control:
	var panel := PanelContainer.new()
	_header_panel = panel
	var cset := Palette.country_set(_draft.country)
	panel.add_theme_stylebox_override("panel", UIStyle.header(cset["grad1"], cset["grad2"], cset["glow"]))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 2)
	_kicker_label = _lbl("NEW PLAYER", 10, Color(1, 1, 1, 0.8), Fonts.W_LABEL)
	_title_label = _lbl("Who are you?", 19, Color.WHITE, Fonts.W_HEADLINE)
	col.add_child(_kicker_label)
	col.add_child(_title_label)
	row.add_child(col)

	# Step dots — Identity is step 1 (dot 1 ON), the inverse of Build.
	var dots := HBoxContainer.new()
	dots.add_theme_constant_override("separation", 5)
	dots.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_active_dot = _dot(_accent)
	dots.add_child(_active_dot)
	dots.add_child(_dot(Color(1, 1, 1, 0.3)))
	row.add_child(dots)
	return panel

func _build_hero() -> Control:
	var panel := PanelContainer.new()
	panel.name = "HeroPanel"
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var cset := Palette.country_set(_draft.country)
	panel.add_theme_stylebox_override("panel", UIStyle.hero_panel(cset["grad1"], cset["grad2"], cset["glow"], _accent))

	_hero_portrait = TextureRect.new()
	_hero_portrait.texture = _HERO_PORTRAIT
	_hero_portrait.custom_minimum_size = Vector2(132, 158)
	_hero_portrait.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_hero_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	panel.add_child(_hero_portrait)
	return panel

func _build_name_block() -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 1)
	_name_label = _lbl("—", 22, Color.WHITE, Fonts.W_HEADLINE, false, HORIZONTAL_ALIGNMENT_CENTER)
	_name_sub = _lbl("", 11, Palette.WHITE_DIM, Fonts.W_BODY, false, HORIZONTAL_ALIGNMENT_CENTER)
	col.add_child(_name_label)
	col.add_child(_name_sub)
	row.add_child(col)

	_reroll_btn = Button.new()
	_reroll_btn.text = "↻"  # dingbat — re-roll; 🎲 would tofu in Barlow
	_reroll_btn.custom_minimum_size = Vector2(30, 30)
	_reroll_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_reroll_btn.add_theme_stylebox_override("normal", UIStyle.corner_btn())
	_reroll_btn.add_theme_stylebox_override("hover", UIStyle.corner_btn())
	_reroll_btn.add_theme_stylebox_override("pressed", UIStyle.corner_btn())
	_reroll_btn.add_theme_stylebox_override("disabled", UIStyle.corner_btn())
	_reroll_btn.add_theme_color_override("font_color", _accent)
	_reroll_btn.add_theme_color_override("font_disabled_color", Palette.WHITE_DIM)
	_reroll_btn.add_theme_font_size_override("font_size", 16)
	_reroll_btn.pressed.connect(_on_reroll_pressed)
	row.add_child(_reroll_btn)
	return row

func _build_country_toggle() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 9)
	_country_sa_btn = _seg_button("SOUTH AFRICA")
	_country_aus_btn = _seg_button("AUSTRALIA")
	_country_sa_btn.pressed.connect(_on_country_pressed.bind(Country.Code.SA))
	_country_aus_btn.pressed.connect(_on_country_pressed.bind(Country.Code.AUS))
	row.add_child(_country_sa_btn)
	row.add_child(_country_aus_btn)
	return row

func _seg_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 12)
	Fonts.weigh(b, Fonts.W_LABEL)
	return b

func _build_city_pill() -> Control:
	_city_dropdown = OptionButton.new()
	_city_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		_city_dropdown.add_theme_stylebox_override(state, UIStyle.field_pill())
	_city_dropdown.add_theme_color_override("font_color", Palette.WHITE)
	_city_dropdown.add_theme_color_override("font_disabled_color", Palette.WHITE_DIM)
	_city_dropdown.add_theme_font_size_override("font_size", 13)
	Fonts.weigh(_city_dropdown, Fonts.W_MEDIUM)
	_city_dropdown.item_selected.connect(_on_city_selected)
	return _city_dropdown

func _build_appearance() -> Control:
	_appearance_picker = AppearancePicker.new()
	_appearance_picker.alignment = BoxContainer.ALIGNMENT_CENTER
	_appearance_picker.appearance_selected.connect(_on_appearance_selected)
	return _appearance_picker

# ── helpers ──────────────────────────────────────────────────────────────────

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

func _apply_accent() -> void:
	_accent = Palette.country_set(_draft.country)["accent"]
	# The picker's hi-fi ring follows the country accent.
	if _appearance_picker != null:
		_appearance_picker.apply_hifi(_accent)

# ── interaction (behaviour preserved from the low-fi screen) ──────────────────

func _on_country_pressed(c: int) -> void:
	if _draft.country == c:
		# Re-pressing the active toggle must stay pressed, not un-toggle.
		_refresh_country_buttons()
		return
	_draft.country = c
	_draft.city = ""                          # spec §4 Screen 1: City resets on Country change
	_apply_accent()                           # accent + picker ring follow the country
	_reroll_name_if_possible()                # name bank slice changed
	_refresh_header()
	_refresh_hero()
	_refresh_country_buttons()
	_refresh_city_dropdown()
	_refresh_appearance_picker()              # picker enables now that a Country exists
	_refresh_name_label()
	_refresh_next_enabled()

func _on_city_selected(idx: int) -> void:
	if idx <= 0:
		_draft.city = ""
	else:
		_draft.city = _city_dropdown.get_item_text(idx)
	_refresh_name_label()                     # the name sub shows "City · Country"
	_refresh_next_enabled()

func _on_appearance_selected(bucket: int) -> void:
	_draft.appearance = bucket
	_reroll_name_if_possible()                # name bank slice changed
	_refresh_next_enabled()

func _on_reroll_pressed() -> void:
	_reroll_name_if_possible()

func _on_next_pressed() -> void:
	if _draft.identity_complete():
		advance_to_build.emit(_draft)

func _reroll_name_if_possible() -> void:
	if _draft.country < 0 or _draft.appearance < 0:
		_draft.name = null
	else:
		_draft.name = NameGenerator.generate(_draft.country, _draft.appearance, _rng)
	_refresh_name_label()

# ── refreshers ───────────────────────────────────────────────────────────────

func _refresh_all() -> void:
	_refresh_header()
	_refresh_hero()
	_refresh_country_buttons()
	_refresh_city_dropdown()
	_refresh_appearance_picker()
	_refresh_name_label()
	_refresh_next_enabled()

func _refresh_header() -> void:
	if _header_panel == null:
		return
	var cset := Palette.country_set(_draft.country)
	_header_panel.add_theme_stylebox_override("panel", UIStyle.header(cset["grad1"], cset["grad2"], cset["glow"]))
	_active_dot.color = _accent  # re-tint the active step dot to the current accent

func _refresh_hero() -> void:
	var panel := _hero_portrait.get_parent() as PanelContainer
	var cset := Palette.country_set(_draft.country)
	panel.add_theme_stylebox_override("panel", UIStyle.hero_panel(cset["grad1"], cset["grad2"], cset["glow"], _accent))

func _refresh_country_buttons() -> void:
	_style_seg(_country_sa_btn, _draft.country == Country.Code.SA)
	_style_seg(_country_aus_btn, _draft.country == Country.Code.AUS)

func _style_seg(btn: Button, on: bool) -> void:
	btn.button_pressed = on
	var cset := Palette.country_set(_draft.country)
	var sb: StyleBoxFlat
	if on:
		sb = UIStyle.seg_btn_on(cset["grad1"], cset["grad2"], cset["accent"])
		btn.add_theme_color_override("font_color", Palette.WHITE)
		btn.add_theme_color_override("font_pressed_color", Palette.WHITE)
	else:
		sb = UIStyle.seg_btn_off()
		btn.add_theme_color_override("font_color", Palette.WHITE_MID)
		btn.add_theme_color_override("font_pressed_color", Palette.WHITE_MID)
	for state in ["normal", "hover", "pressed", "focus"]:
		btn.add_theme_stylebox_override(state, sb)

func _refresh_city_dropdown() -> void:
	_city_dropdown.clear()
	_city_dropdown.add_item("— Select a city —", 0)
	_city_dropdown.set_item_disabled(0, true)
	_city_dropdown.disabled = (_draft.country < 0)
	if _draft.country >= 0:
		var city_list := Cities.for_country(_draft.country)
		for c in city_list:
			_city_dropdown.add_item(c)
		# Honour a city already on the draft (hydration on Back); else show placeholder.
		# Cities sit at dropdown index 1..N because the placeholder occupies index 0.
		var idx := city_list.find(_draft.city)
		_city_dropdown.select(idx + 1 if idx >= 0 else 0)

func _refresh_appearance_picker() -> void:
	# Spec §4: Appearance is disabled until a Country is picked.
	_appearance_picker.set_enabled(_draft.country >= 0)
	# Restore the selection ring on hydration without re-rolling the name.
	if _draft.appearance >= 0:
		_appearance_picker.set_selected_silent(_draft.appearance)

func _refresh_name_label() -> void:
	if _draft.name == null:
		_name_label.text = "—"
		_name_sub.text = ""
		_reroll_btn.disabled = true
	else:
		_name_label.text = _draft.name.display_caps()
		_name_sub.text = _city_country_sub()
		_reroll_btn.disabled = false

# "City · Country" (title case) for the name sub; country alone before a city pick.
func _city_country_sub() -> String:
	var country_name := Country.display_name(_draft.country).capitalize()
	if _draft.city == "":
		return country_name
	return "%s · %s" % [_draft.city, country_name]

func _refresh_next_enabled() -> void:
	_next_btn.disabled = not _draft.identity_complete()
