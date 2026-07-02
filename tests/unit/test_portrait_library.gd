extends GutTest

func test_path_maps_bucket_and_band() -> void:
	assert_eq(PortraitLibrary.path(Appearance.Bucket.WHITE, FormBand.Band.STEADY), "res://assets/portraits/white-steady.png")
	assert_eq(PortraitLibrary.path(Appearance.Bucket.BLACK, FormBand.Band.HOT), "res://assets/portraits/black-hot.png")
	assert_eq(PortraitLibrary.path(Appearance.Bucket.INDIAN, FormBand.Band.COLD), "res://assets/portraits/indian-cold.png")

func test_unknown_inputs_clamp_to_white_steady() -> void:
	assert_eq(PortraitLibrary.path(-1, 99), "res://assets/portraits/white-steady.png")

func test_texture_loads_and_caches_all_16() -> void:
	for bucket in Appearance.all():
		for band in [FormBand.Band.HOT, FormBand.Band.STEADY, FormBand.Band.TIRED, FormBand.Band.COLD]:
			var tex := PortraitLibrary.texture_for(bucket, _form_for(band))
			assert_not_null(tex, PortraitLibrary.path(bucket, band))
			assert_true(tex is Texture2D, PortraitLibrary.path(bucket, band) + " is a Texture2D")
	var a := PortraitLibrary.texture_for(Appearance.Bucket.MIXED, 0)
	var b := PortraitLibrary.texture_for(Appearance.Bucket.MIXED, 1)
	assert_eq(a, b, "same band returns the cached object")

# raw form int that lands in the given band (texture_for takes a raw form, not a band)
func _form_for(band: int) -> int:
	match band:
		FormBand.Band.HOT: return 2
		FormBand.Band.STEADY: return 0
		FormBand.Band.TIRED: return -1
		_: return -2
