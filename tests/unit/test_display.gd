extends GutTest

# Display transform (world-scale v2, WS2): internal card/strength -> /100 shown.

func test_anchors_land_on_nicos_targets() -> void:
	assert_almost_eq(Display.to_card(12.5), 13.0, 0.01, "Club average reads 13")
	assert_almost_eq(Display.to_card(37.5), 85.0, 0.01, "Province Premier average reads 85")
	assert_almost_eq(Display.to_card(46.5), 90.0, 0.01, "Province Premier best team reads 90")
	assert_almost_eq(Display.to_card(60.0), 100.0, 0.01, "the cap reads 100")

func test_fresh_hero_reads_about_eleven() -> void:
	# Internal 11 (a weak Club player / fresh hero) shows ~11.
	assert_between(Display.to_card(11.0), 10.0, 12.0)

func test_zero_and_floor() -> void:
	assert_eq(Display.to_card(0.0), 0.0)
	assert_eq(Display.to_card(-5.0), 0.0, "below floor clamps to 0")

func test_monotonic_increasing() -> void:
	var prev := -1.0
	for x in [0.0, 5.0, 12.5, 20.0, 31.25, 37.5, 46.5, 55.0, 60.0]:
		var v := Display.to_card(x)
		assert_gt(v, prev, "monotonic at %.1f" % x)
		prev = v

func test_mid_pro_reads_about_67() -> void:
	# Falls out of the interpolation — an average ★3 pro reads ~67 (recorded).
	assert_almost_eq(Display.to_card(31.25), 67.0, 1.0)

func test_round_helper() -> void:
	assert_eq(Display.to_card_round(60.0), 100)
	assert_eq(Display.to_card_round(12.5), 13)

func test_stars_str_half_stars_render_as_half() -> void:
	# T2 (playtest): 1.5 must NOT round up to two full stars.
	assert_eq(Display.stars_str(1.5), "★½")
	assert_eq(Display.stars_str(2.0), "★★")
	assert_eq(Display.stars_str(3.5), "★★★½")
	assert_eq(Display.stars_str(0.5), "½")
