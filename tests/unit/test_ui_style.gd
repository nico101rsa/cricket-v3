extends GutTest

# UIStyle — code-built StyleBoxFlat factory (testable; chosen over a .tres Theme).

func test_panel_box_uses_surface_and_radius() -> void:
	var sb := UIStyle.panel()
	assert_true(sb is StyleBoxFlat)
	assert_eq(sb.bg_color, Palette.SURFACE)
	assert_eq(sb.corner_radius_top_left, 8)

func test_cta_box_takes_accent() -> void:
	var sb := UIStyle.cta(Palette.SA)
	assert_eq(sb.bg_color, Palette.SA)
	assert_eq(sb.corner_radius_top_left, 10)

func test_chip_border_colour_by_rarity() -> void:
	assert_eq(UIStyle.chip("Legendary").border_color, Palette.LEGENDARY)
	assert_eq(UIStyle.chip("Rare").border_color, Palette.RARE)
	assert_eq(UIStyle.chip("Common").border_color, Palette.COMMON)

func test_portrait_frame_bg_and_glow() -> void:
	var sb := UIStyle.portrait_frame(Palette.SKILL_3, Palette.FORM_HOT)
	assert_eq(sb.bg_color, Palette.SKILL_3, "skill bg fill")
	assert_eq(sb.border_color, Palette.FORM_HOT, "form glow border")

func test_bar_fill_takes_accent() -> void:
	assert_eq(UIStyle.bar_fill(Palette.AUS).bg_color, Palette.AUS)
