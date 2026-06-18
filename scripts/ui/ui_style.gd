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
