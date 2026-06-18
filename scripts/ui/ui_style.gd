class_name UIStyle
extends RefCounted

# Code-built StyleBoxFlat factory + theme helpers (spec DH1). Static so any scene
# calls UIStyle.panel() etc. without an instance. Every colour comes from Palette.

static func _box(bg: Color, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	return sb

# Raised surface panel (8px radius, subtle border, breathing-room margins).
static func panel() -> StyleBoxFlat:
	var sb := _box(Palette.SURFACE, 8)
	sb.set_border_width_all(1)
	sb.border_color = Palette.BORDER
	sb.content_margin_left = 11; sb.content_margin_right = 11
	sb.content_margin_top = 9; sb.content_margin_bottom = 9
	return sb

# Rounded chip / pill (position pill, fixture dots, team badge).
static func pill(bg: Color) -> StyleBoxFlat:
	var sb := _box(bg, 8)
	sb.content_margin_left = 8; sb.content_margin_right = 8
	sb.content_margin_top = 3; sb.content_margin_bottom = 3
	return sb

# Joker chip with a rarity-coloured border (left accent).
static func chip(rarity: String) -> StyleBoxFlat:
	var col: Color = {
		"Common": Palette.COMMON, "Rare": Palette.RARE, "Legendary": Palette.LEGENDARY,
	}.get(rarity, Palette.WHITE)
	var sb := _box(Palette.SURFACE, 8)
	sb.border_width_left = 4
	sb.border_color = col
	sb.content_margin_left = 8; sb.content_margin_right = 8
	sb.content_margin_top = 5; sb.content_margin_bottom = 5
	return sb

# Primary CTA tile (solid accent; the "Next Match ▶" button).
static func cta(accent: Color) -> StyleBoxFlat:
	var sb := _box(accent, 10)
	sb.content_margin_top = 12; sb.content_margin_bottom = 12
	return sb

# §16.3 portrait: skill-tier bg fill + Form-coloured glow border.
static func portrait_frame(skill_bg: Color, glow: Color) -> StyleBoxFlat:
	var sb := _box(skill_bg, 12)
	sb.set_border_width_all(3)
	sb.border_color = glow
	return sb

# Affinity bar track + fill.
static func bar_track() -> StyleBoxFlat:
	return _box(Palette.BORDER, 4)

static func bar_fill(accent: Color) -> StyleBoxFlat:
	return _box(accent, 4)
