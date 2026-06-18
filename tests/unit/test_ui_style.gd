extends GutTest

# UIStyle — code-built StyleBoxFlat factory (testable; chosen over a .tres Theme).

func test_panel_box_uses_surface_and_radius() -> void:
	var sb := UIStyle.panel()
	assert_true(sb is StyleBoxFlat)
	assert_eq(sb.bg_color, Palette.SURFACE)
	assert_eq(sb.corner_radius_top_left, UIStyle.PANEL_RADIUS)

func test_header_blends_gradient_and_carries_glow_shadow() -> void:
	var sb := UIStyle.header(Palette.COUNTRY_1_SA, Palette.COUNTRY_2_SA, Palette.COUNTRY_GLOW_SA)
	assert_eq(sb.shadow_color, Palette.COUNTRY_GLOW_SA, "country glow shadow")
	assert_gt(sb.shadow_size, 0, "shadow present")

func test_cta_box_takes_accent() -> void:
	var sb := UIStyle.cta(Palette.GOLD)
	assert_eq(sb.bg_color, Palette.GOLD)
	assert_eq(sb.corner_radius_top_left, UIStyle.BTN_RADIUS)

func test_ovr_tile_is_gold() -> void:
	assert_eq(UIStyle.ovr_tile().bg_color, Palette.GOLD)

func test_chip_border_colour_by_rarity() -> void:
	assert_eq(UIStyle.chip("Legendary").border_color, Palette.LEGENDARY)
	assert_eq(UIStyle.chip("Rare").border_color, Palette.RARE)
	assert_eq(UIStyle.chip("Common").border_color, Palette.COMMON)

func test_portrait_ring_is_tier_coloured_border() -> void:
	var sb := UIStyle.portrait_ring(Palette.SKILL_3)
	assert_eq(sb.border_color, Palette.SKILL_3, "ring = tier colour")
	assert_eq(sb.bg_color.a, 0.0, "transparent fill (art shows through)")

func test_fixture_dot_current_gets_ring() -> void:
	var plain := UIStyle.fixture_dot(Palette.SURFACE_2)
	assert_eq(plain.border_width_left, 0, "neutral dot has no ring")
	var current := UIStyle.fixture_dot(Palette.COUNTRY_1_SA, Palette.COUNTRY_ACCENT_SA)
	assert_gt(current.border_width_left, 0, "current dot has accent ring")

func test_bar_fill_takes_accent() -> void:
	assert_eq(UIStyle.bar_fill(Palette.COUNTRY_ACCENT_SA).bg_color, Palette.COUNTRY_ACCENT_SA)
