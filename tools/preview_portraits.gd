extends SceneTree

# Dev preview for the portrait pipeline (spec 2026-07-03). Renders the full 4x4
# runtime portrait matrix in-engine -- rows = appearance buckets (lightest ->
# darkest), columns = form bands (HOT / STEADY / TIRED / COLD) -- so Nico can
# eyeball what PortraitLibrary actually serves, with row/column labels.
# Run WITH rendering (not --headless):
#   /Applications/Godot.app/Contents/MacOS/Godot --path . -s tools/preview_portraits.gd
# Output: docs/mockups/portraits-in-engine-v1.png

var _frames := 0

const BANDS := [FormBand.Band.HOT, FormBand.Band.STEADY, FormBand.Band.TIRED, FormBand.Band.COLD]
const BAND_FORM := {FormBand.Band.HOT: 2, FormBand.Band.STEADY: 0, FormBand.Band.TIRED: -1, FormBand.Band.COLD: -2}
const BUCKET_NAMES := ["WHITE", "MIXED", "INDIAN", "BLACK"]

func _initialize() -> void:
	# project window is fixed 390x844 -- size tiles to fit it
	var bg := ColorRect.new()
	bg.color = Palette.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)

	var grid := GridContainer.new()
	grid.columns = 5
	grid.position = Vector2(8, 10)
	grid.add_theme_constant_override("h_separation", 5)
	grid.add_theme_constant_override("v_separation", 5)
	root.add_child(grid)

	grid.add_child(_lbl(""))  # corner
	for band in BANDS:
		grid.add_child(_lbl(FormBand.label(band)))
	for bucket in Appearance.all():
		grid.add_child(_lbl(BUCKET_NAMES[bucket]))
		for band in BANDS:
			var tex := TextureRect.new()
			tex.texture = PortraitLibrary.texture_for(bucket, BAND_FORM[band])
			tex.custom_minimum_size = Vector2(74, 88)
			tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			grid.add_child(tex)

func _lbl(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.custom_minimum_size = Vector2(52, 20)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", Palette.GOLD)
	l.add_theme_font_size_override("font_size", 10)
	Fonts.weigh(l, Fonts.W_BOLD)
	return l

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames >= 6:
		var img := root.get_viewport().get_texture().get_image()
		img.save_png("res://docs/mockups/portraits-in-engine-v1.png")
		print("PREVIEW_SAVED res://docs/mockups/portraits-in-engine-v1.png")
		return true
	return false
