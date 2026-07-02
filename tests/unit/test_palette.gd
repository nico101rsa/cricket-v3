extends GutTest

# Palette — the single source of truth for colour / design tokens (hi-fi v2 spec).

func test_core_constants_present() -> void:
	assert_eq(Palette.GOLD, Color("ffd166"))
	assert_eq(Palette.BG, Color("0f0f14"))
	assert_eq(Palette.LEGENDARY, Color("ffc23c"))

func test_skill_ring_tiers_by_stars() -> void:
	assert_eq(Palette.skill_ring(4.5), Palette.SKILL_4, "elite gold")
	assert_eq(Palette.skill_ring(3.0), Palette.SKILL_3, "default blue 3-star")
	assert_eq(Palette.skill_ring(2.0), Palette.SKILL_2, "silver 2-star")
	assert_eq(Palette.skill_ring(0.5), Palette.SKILL_1, "half-star reads as 1-star charcoal")

func test_form_glow_maps_each_band() -> void:
	# form ints (DP3): >=2 hot, 0..1 steady, -1 tired, <=-2 cold (display-only mapping).
	assert_eq(Palette.form_glow(3), Palette.FORM_HOT)
	assert_eq(Palette.form_glow(1), Palette.FORM_STEADY)
	assert_eq(Palette.form_glow(0), Palette.FORM_STEADY)
	assert_eq(Palette.form_glow(-1), Palette.FORM_TIRED)
	assert_eq(Palette.form_glow(-2), Palette.FORM_COLD)

func test_country_set_swaps_the_four_tokens() -> void:
	var sa := Palette.country_set(Country.Code.SA)
	assert_eq(sa["grad1"], Palette.COUNTRY_1_SA, "SA header gradient start")
	assert_eq(sa["accent"], Palette.COUNTRY_ACCENT_SA, "SA accent")
	var aus := Palette.country_set(Country.Code.AUS)
	assert_eq(aus["grad1"], Palette.COUNTRY_1_AUS, "AUS reskin gradient start")
	assert_ne(aus["accent"], sa["accent"], "accent differs by country")
