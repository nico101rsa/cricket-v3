extends GutTest

# Palette — the single source of truth for colour (DESIGN_HANDOFF §8 / §16.3).

func test_core_constants_present() -> void:
	assert_eq(Palette.GOLD, Color("ffd166"))
	assert_eq(Palette.BG, Color("1a1a22"))
	assert_eq(Palette.LEGENDARY, Color("ffc23c"))

func test_skill_bg_tiers_by_stars() -> void:
	assert_eq(Palette.skill_bg(4.5), Palette.SKILL_4, "elite")
	assert_eq(Palette.skill_bg(3.0), Palette.SKILL_3, "default 3-star")
	assert_eq(Palette.skill_bg(2.0), Palette.SKILL_2, "2-star")
	assert_eq(Palette.skill_bg(1.0), Palette.SKILL_1, "rookie")

func test_form_glow_maps_each_band() -> void:
	# form ints: >=2 hot, ==1 steady, ==0 tired, <0 cold (display-only mapping).
	assert_eq(Palette.form_glow(3), Palette.FORM_HOT)
	assert_eq(Palette.form_glow(1), Palette.FORM_STEADY)
	assert_eq(Palette.form_glow(0), Palette.FORM_TIRED)
	assert_eq(Palette.form_glow(-1), Palette.FORM_COLD)
