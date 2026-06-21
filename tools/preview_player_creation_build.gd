extends SceneTree

# Dev preview: mount the hi-fi Player Creation Build screen with a sample draft,
# render a few frames, save a PNG, quit. Run WITH rendering (not --headless):
#   /Applications/Godot.app/Contents/MacOS/Godot --path . -s tools/preview_player_creation_build.gd
# Output: docs/mockups/player-creation-build-built-v1.png + docs/mockups/latest/player-creation-build.png
# Optional env: CTRY=aus to render the Australia palette swap; BUILD=bat|bowl to
# show a non-default classifier.

var _scene
var _frames := 0
var _injected := false

func _initialize() -> void:
	root.size = Vector2i(390, 844)
	_scene = load("res://scenes/player_creation/build.tscn").instantiate()
	root.add_child(_scene)

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 2 and not _injected:
		_scene.set_draft(_make_draft())
		_injected = true
	if _frames >= 8:
		var img := root.get_viewport().get_texture().get_image()
		img.save_png("res://docs/mockups/player-creation-build-built-v1.png")
		img.save_png("res://docs/mockups/latest/player-creation-build.png")
		print("PREVIEW_SAVED")
		return true
	return false

func _make_draft() -> PlayerCreationDraft:
	var d := PlayerCreationDraft.new()
	var aus := OS.get_environment("CTRY") == "aus"
	d.country = Country.Code.AUS if aus else Country.Code.SA
	d.city = "Perth" if aus else "Cape Town"
	d.appearance = Appearance.Bucket.WHITE
	var n := NamePair.new()
	if aus:
		n.first_name = "Cooper"; n.surname = "Vale"
	else:
		n.first_name = "Jomo"; n.surname = "Ntini"
	d.name = n
	# A mildly batting-leaning spread (still summing to the 44 budget) so the
	# sliders sit at different positions and the classifier reads a real label.
	var build := OS.get_environment("BUILD")
	var a := d.attributes
	if build == "bowl":
		a.power = 7.0; a.composure = 7.0; a.attack = 16.0; a.control = 14.0
	elif build == "bat":
		a.power = 16.0; a.composure = 14.0; a.attack = 7.0; a.control = 7.0
	else:
		a.power = 14.0; a.composure = 11.0; a.attack = 10.0; a.control = 9.0
	return d
