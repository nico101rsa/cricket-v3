extends SceneTree

# Dev preview: mount the hi-fi Player Creation Identity screen with a sample draft,
# render a few frames, save a PNG, quit. Run WITH rendering (not --headless):
#   /Applications/Godot.app/Contents/MacOS/Godot --path . -s tools/preview_player_creation_identity.gd
# Output: docs/mockups/player-creation-identity-built-v1.png + docs/mockups/latest/player-creation-identity.png
# Optional env: CTRY=aus to render the Australia palette swap.

var _scene
var _frames := 0
var _injected := false

func _initialize() -> void:
	root.size = Vector2i(390, 844)
	_scene = load("res://scenes/player_creation/identity.tscn").instantiate()
	root.add_child(_scene)

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 2 and not _injected:
		_scene.set_draft(_make_draft())
		_injected = true
	if _frames >= 8:
		var img := root.get_viewport().get_texture().get_image()
		img.save_png("res://docs/mockups/player-creation-identity-built-v1.png")
		img.save_png("res://docs/mockups/latest/player-creation-identity.png")
		print("PREVIEW_SAVED")
		return true
	return false

func _make_draft() -> PlayerCreationDraft:
	var d := PlayerCreationDraft.new()
	var aus := OS.get_environment("CTRY") == "aus"
	d.country = Country.Code.AUS if aus else Country.Code.SA
	d.city = "Perth" if aus else "Cape Town"
	d.appearance = Appearance.Bucket.MIXED if aus else Appearance.Bucket.WHITE
	var n := NamePair.new()
	if aus:
		n.first_name = "Cooper"; n.surname = "Vale"
	else:
		n.first_name = "Jomo"; n.surname = "Ntini"
	d.name = n
	return d
