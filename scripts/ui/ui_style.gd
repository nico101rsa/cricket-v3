class_name UIStyle
extends RefCounted

# Code-built StyleBoxFlat factory + theme helpers (Season Hub hi-fi v2 spec).
# Static so any scene calls UIStyle.panel() etc. without an instance. Every colour
# comes from Palette — the scene holds no hardcoded hex.

const PANEL_RADIUS := 11
const CARD_RADIUS := 9
const BTN_RADIUS := 13

static func _box(bg: Color, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	return sb

# Raised surface panel: bg surface, 1px border, radius 11, content margin 9v × 11h.
static func panel() -> StyleBoxFlat:
	var sb := _box(Palette.SURFACE, PANEL_RADIUS)
	sb.set_border_width_all(1)
	sb.border_color = Palette.BORDER
	sb.content_margin_left = 11; sb.content_margin_right = 11
	sb.content_margin_top = 9; sb.content_margin_bottom = 9
	return sb

# Country-gradient header (approximated as a solid blend + a country-glow drop
# shadow — StyleBoxFlat has no gradient, but supports shadow_color/shadow_size).
static func header(grad1: Color, grad2: Color, glow: Color) -> StyleBoxFlat:
	var sb := _box(grad1.lerp(grad2, 0.45), PANEL_RADIUS)
	sb.content_margin_left = 11; sb.content_margin_right = 11
	sb.content_margin_top = 10; sb.content_margin_bottom = 10
	sb.shadow_color = glow
	sb.shadow_size = 10
	return sb

# Rounded chip / pill (meta chip, position pill, badge).
static func pill(bg: Color) -> StyleBoxFlat:
	var sb := _box(bg, 7)
	sb.content_margin_left = 8; sb.content_margin_right = 8
	sb.content_margin_top = 3; sb.content_margin_bottom = 3
	return sb

# Gold OVR tile (the rounded square holding the OVR number).
static func ovr_tile() -> StyleBoxFlat:
	var sb := _box(Palette.GOLD, CARD_RADIUS)
	sb.content_margin_left = 9; sb.content_margin_right = 9
	sb.content_margin_top = 4; sb.content_margin_bottom = 4
	return sb

# Portrait skill-tier RING: transparent fill, coloured 3px border, radius 9. The
# portrait art (TextureRect) sits behind; this frames it.
static func portrait_ring(ring: Color) -> StyleBoxFlat:
	var sb := _box(Color(0, 0, 0, 0), CARD_RADIUS)
	sb.set_border_width_all(3)
	sb.border_color = ring
	return sb

# Joker slot: empty (dashed approximated as a thin strong border over surface-2);
# `locked` dims it for the "1st Level win" slot.
static func joker_slot(locked: bool) -> StyleBoxFlat:
	var sb := _box(Palette.SURFACE_2 if not locked else Palette.SURFACE, CARD_RADIUS)
	sb.set_border_width_all(1)
	sb.border_color = Palette.BORDER if not locked else Palette.BORDER_STRONG
	sb.content_margin_left = 6; sb.content_margin_right = 6
	sb.content_margin_top = 10; sb.content_margin_bottom = 10
	return sb

# Filled joker chip with a rarity-coloured left accent.
static func chip(rarity: String) -> StyleBoxFlat:
	var col: Color = {
		"Common": Palette.COMMON, "Rare": Palette.RARE, "Legendary": Palette.LEGENDARY,
	}.get(rarity, Palette.WHITE)
	var sb := _box(Palette.SURFACE_2, CARD_RADIUS)
	sb.border_width_left = 4
	sb.border_color = col
	sb.content_margin_left = 8; sb.content_margin_right = 8
	sb.content_margin_top = 5; sb.content_margin_bottom = 5
	return sb

# Primary CTA tile (solid accent; radius 13, tall). Pass Palette.GOLD for the hub.
static func cta(accent: Color) -> StyleBoxFlat:
	var sb := _box(accent, BTN_RADIUS)
	sb.content_margin_top = 12; sb.content_margin_bottom = 12
	return sb

# Season-goal strip: faint gold tint, gold border (stakes, not filler).
static func goal_panel() -> StyleBoxFlat:
	var sb := _box(Color(Palette.GOLD.r, Palette.GOLD.g, Palette.GOLD.b, 0.06), PANEL_RADIUS)
	sb.set_border_width_all(1)
	sb.border_color = Color(Palette.GOLD.r, Palette.GOLD.g, Palette.GOLD.b, 0.5)
	sb.content_margin_left = 11; sb.content_margin_right = 11
	sb.content_margin_top = 9; sb.content_margin_bottom = 9
	return sb

# Round 26×26 corner button (ⓘ / ⚙).
static func corner_btn() -> StyleBoxFlat:
	var sb := _box(Palette.SURFACE_2, 13)
	sb.set_border_width_all(1)
	sb.border_color = Palette.BORDER
	return sb

# Circular fixture dot. `ring` non-transparent adds the current-match accent ring.
static func fixture_dot(bg: Color, ring: Color = Color(0, 0, 0, 0)) -> StyleBoxFlat:
	var sb := _box(bg, 13)
	if ring.a > 0.0:
		sb.set_border_width_all(2)
		sb.border_color = ring
	return sb

# Affinity bar track + fill.
static func bar_track() -> StyleBoxFlat:
	return _box(Palette.SURFACE_3, 4)

static func bar_fill(accent: Color) -> StyleBoxFlat:
	return _box(accent, 4)

# --- In-match scene tokens (docs/design-inbox/in-match.md) -------------------

# Opponent-tinted bowler row: bg accent@0.12, border accent@0.5, radius 9.
static func team_row(accent: Color) -> StyleBoxFlat:
	var sb := _box(Color(accent.r, accent.g, accent.b, 0.12), CARD_RADIUS)
	sb.set_border_width_all(1)
	sb.border_color = Color(accent.r, accent.g, accent.b, 0.5)
	sb.content_margin_left = 9; sb.content_margin_right = 9
	sb.content_margin_top = 7; sb.content_margin_bottom = 7
	return sb

# One ball cell in the "this over" grid, filled by outcome kind.
# kind ∈ dot / run / four / six / wicket / pending.
static func ball_cell(kind: String) -> StyleBoxFlat:
	var bg: Color = {
		"dot": Palette.SURFACE_2,
		"run": Color(Palette.BLUE.r, Palette.BLUE.g, Palette.BLUE.b, 0.22),
		"four": Palette.GOLD,
		"six": Palette.GREEN_DARK,
		"wicket": Palette.RED,
		"pending": Color(Palette.SURFACE_2.r, Palette.SURFACE_2.g, Palette.SURFACE_2.b, 0.40),
	}.get(kind, Palette.SURFACE_2)
	return _box(bg, 6)

# Text colour to pair with a ball_cell of the same kind.
static func ball_cell_text(kind: String) -> Color:
	match kind:
		"four": return Color("000000")
		"six", "wicket": return Color("ffffff")
		"run": return Color("9ec5ff")
		_: return Palette.WHITE_DIM

# Dock auto-sim bar shell: accent-tinted (bg accent@0.12, border accent@0.4), radius 13.
static func autosim_bar(accent: Color) -> StyleBoxFlat:
	var sb := _box(Color(accent.r, accent.g, accent.b, 0.12), BTN_RADIUS)
	sb.set_border_width_all(1)
	sb.border_color = Color(accent.r, accent.g, accent.b, 0.4)
	sb.content_margin_left = 12; sb.content_margin_right = 12
	sb.content_margin_top = 8; sb.content_margin_bottom = 8
	return sb

# Round 60×60 BOOST control: solid green + green glow (radial gradient approximated).
static func boost_button() -> StyleBoxFlat:
	var sb := _box(Palette.GREEN_DARK, 30)
	sb.set_border_width_all(2)
	sb.border_color = Palette.GREEN_DARK
	sb.shadow_color = Palette.form_glow(2)
	sb.shadow_size = 10
	return sb

# Gold count badge on the BOOST button.
static func boost_badge() -> StyleBoxFlat:
	var sb := _box(Palette.GOLD, 11)
	sb.set_border_width_all(2)
	sb.border_color = Palette.GREEN_DARK
	return sb

# Overlay scrim (a dim, not an unload).
static func scrim() -> StyleBoxFlat:
	return _box(Color(0, 0, 0, 0.78), 0)

# Overlay top banner by kind: moment=gold, boost=green, drs=blue.
static func banner(kind: String) -> StyleBoxFlat:
	var bg: Color = {
		"moment": Palette.GOLD_WARN, "boost": Palette.GREEN_DARK, "drs": Palette.BLUE,
	}.get(kind, Palette.GOLD_WARN)
	var sb := _box(bg, CARD_RADIUS)
	sb.content_margin_top = 8; sb.content_margin_bottom = 8
	sb.content_margin_left = 8; sb.content_margin_right = 8
	return sb

# Dramatic overlay card by kind (moment/drs = green-black, boost = deeper green).
static func moment_card(kind: String) -> StyleBoxFlat:
	var top: Color = Palette.MOMENT_BOOST_1 if kind == "boost" else Palette.MOMENT_1
	var bot: Color = Palette.MOMENT_BOOST_2 if kind == "boost" else Palette.MOMENT_2
	var sb := _box(top.lerp(bot, 0.5), BTN_RADIUS)
	sb.set_border_width_all(1)
	sb.border_color = Palette.BORDER
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 8
	sb.content_margin_left = 14; sb.content_margin_right = 14
	sb.content_margin_top = 14; sb.content_margin_bottom = 14
	return sb

# A two-option choice button on a moment card; accent tints the border + verb.
static func choice_btn(accent: Color) -> StyleBoxFlat:
	var sb := _box(Color(accent.r, accent.g, accent.b, 0.14), CARD_RADIUS)
	sb.set_border_width_all(1)
	sb.border_color = Color(accent.r, accent.g, accent.b, 0.55)
	sb.content_margin_left = 11; sb.content_margin_right = 11
	sb.content_margin_top = 11; sb.content_margin_bottom = 11
	return sb

# --- Player-creation Build scene tokens (player-creation-v2.html "Build" band) -

# Points bar / attribute group: a flat surface panel, faint border, snug padding.
static func attr_group() -> StyleBoxFlat:
	var sb := _box(Palette.SURFACE, PANEL_RADIUS)
	sb.set_border_width_all(1)
	sb.border_color = Palette.BORDER
	sb.content_margin_left = 12; sb.content_margin_right = 12
	sb.content_margin_top = 11; sb.content_margin_bottom = 12
	return sb

static func points_bar() -> StyleBoxFlat:
	var sb := attr_group()
	sb.content_margin_top = 10; sb.content_margin_bottom = 10
	return sb

# Classifier panel: faint accent-tinted surface, accent border, a soft accent
# glow (StyleBoxFlat shadow is outer — reads as the "inner glow" halo here).
static func classifier_panel(accent: Color) -> StyleBoxFlat:
	var sb := _box(Color(accent.r, accent.g, accent.b, 0.07), 12)
	sb.set_border_width_all(1)
	sb.border_color = accent
	sb.shadow_color = Color(accent.r, accent.g, accent.b, 0.22)
	sb.shadow_size = 8
	sb.content_margin_left = 14; sb.content_margin_right = 14
	sb.content_margin_top = 12; sb.content_margin_bottom = 12
	return sb

# Custom HSlider groove + fill. The groove is a grey rounded 8px bar; the fill
# (the "grabber_area" slot) is the country-gradient accent left of the thumb.
# Both carry 4px top/bottom content margin so the 8px bars line up vertically.
static func slider_track() -> StyleBoxFlat:
	var sb := _box(Palette.SURFACE_3, 5)
	sb.content_margin_top = 4; sb.content_margin_bottom = 4
	return sb

static func slider_fill(accent: Color) -> StyleBoxFlat:
	var sb := _box(accent, 5)
	sb.content_margin_top = 4; sb.content_margin_bottom = 4
	return sb

# Circular HSlider thumb: white fill, 3px accent ring, generated as a texture
# (the grabber theme slot is an icon, not a stylebox). 22px reads crisp at the
# 390-wide design size.
static func slider_grabber(accent: Color) -> ImageTexture:
	var d := 22
	var img := Image.create(d, d, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := (d - 1) / 2.0
	var r_out := d / 2.0
	var r_in := r_out - 3.0
	for y in d:
		for x in d:
			var dist := Vector2(x - c, y - c).length()
			if dist <= r_in:
				img.set_pixel(x, y, Color(1, 1, 1, 1))
			elif dist <= r_out:
				img.set_pixel(x, y, accent)
	return ImageTexture.create_from_image(img)

# Small rounded group icon (gold for batting, blue for bowling) — a filled chip.
static func group_icon(col: Color) -> StyleBoxFlat:
	return _box(col, 4)
