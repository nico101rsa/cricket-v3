extends GutTest

# DP3: canonical banding -- HOT >=2, STEADY 0..1, TIRED == -1, COLD <= -2.
# Fixes the latent bug where a fresh player (form 0) displayed as TIRED.

func test_banding_table() -> void:
	assert_eq(FormBand.of(3), FormBand.Band.HOT)
	assert_eq(FormBand.of(2), FormBand.Band.HOT)
	assert_eq(FormBand.of(1), FormBand.Band.STEADY)
	assert_eq(FormBand.of(0), FormBand.Band.STEADY, "fresh player reads STEADY")
	assert_eq(FormBand.of(-1), FormBand.Band.TIRED)
	assert_eq(FormBand.of(-2), FormBand.Band.COLD)
	assert_eq(FormBand.of(-5), FormBand.Band.COLD)

func test_banding_on_raw_points() -> void:
	# T6 (playtest): one bad game (dismissed -0.5 + dot streak -0.25 = -0.75) must NOT
	# read TIRED. Bands sit on raw points, not a rounded int: STEADY covers > -1.0,
	# TIRED > -2.0, COLD the rest; HOT keeps its old effective boundary (>= 1.5).
	assert_eq(FormBand.of(-0.75), FormBand.Band.STEADY, "one bad game stays STEADY")
	assert_eq(FormBand.of(-0.99), FormBand.Band.STEADY)
	assert_eq(FormBand.of(-1.0), FormBand.Band.TIRED, "STEADY covers points > -1.0 only")
	assert_eq(FormBand.of(-1.99), FormBand.Band.TIRED)
	assert_eq(FormBand.of(-2.0), FormBand.Band.COLD)
	assert_eq(FormBand.of(1.49), FormBand.Band.STEADY)
	assert_eq(FormBand.of(1.5), FormBand.Band.HOT, "1.5 points is HOT, same as the old roundi")

func test_keys_and_labels() -> void:
	assert_eq(FormBand.key(FormBand.Band.HOT), "hot")
	assert_eq(FormBand.key(FormBand.Band.STEADY), "steady")
	assert_eq(FormBand.key(FormBand.Band.TIRED), "tired")
	assert_eq(FormBand.key(FormBand.Band.COLD), "cold")
	assert_eq(FormBand.label(FormBand.Band.HOT), "HOT")
	assert_eq(FormBand.label(FormBand.Band.COLD), "COLD")

func test_palette_glow_follows_formband() -> void:
	assert_eq(Palette.form_glow(0), Palette.FORM_STEADY, "0 is STEADY now, not TIRED")
	assert_eq(Palette.form_glow(-1), Palette.FORM_TIRED)
	assert_eq(Palette.form_glow(-2), Palette.FORM_COLD)
	assert_eq(Palette.form_glow(2), Palette.FORM_HOT)
