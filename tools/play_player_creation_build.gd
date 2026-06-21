extends SceneTree

# Interactive harness: mount the REAL hi-fi Build screen in a window so you can
# drag the sliders and feel it. Non-destructive — SaveManager is pointed at a
# throwaway path, so hitting "Begin Career" won't touch your real career.
#   /Applications/Godot.app/Contents/MacOS/Godot --path . -s tools/play_player_creation_build.gd
# Close the window to exit.

func _initialize() -> void:
	root.size = Vector2i(390, 844)
	root.title = "Build screen — drag the sliders (throwaway save)"
	SaveManager.player_save_path = "user://_harness_creation_build.tres"

	var d := PlayerCreationDraft.new()
	d.country = Country.Code.SA
	d.city = "Cape Town"
	d.appearance = Appearance.Bucket.WHITE
	var n := NamePair.new()
	n.first_name = "Jomo"; n.surname = "Ntini"
	d.name = n
	d.attributes.power = 14.0; d.attributes.composure = 11.0
	d.attributes.attack = 10.0; d.attributes.control = 9.0

	var scene = load("res://scenes/player_creation/build.tscn").instantiate()
	scene.set_draft(d)
	root.add_child(scene)
