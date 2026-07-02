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
