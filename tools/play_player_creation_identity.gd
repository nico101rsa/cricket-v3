extends SceneTree

# Interactive harness: mount the REAL hi-fi Identity screen in a window so you can
# toggle country, pick a city + appearance, and re-roll the name. Non-destructive —
# it just shows Screen 1 (tapping Next would advance to Build, but this harness
# mounts Identity alone, so there's nothing to persist).
#   /Applications/Godot.app/Contents/MacOS/Godot --path . -s tools/play_player_creation_identity.gd
# Close the window to exit. Starts BLANK (cold start) — make the picks yourself.

func _initialize() -> void:
	root.size = Vector2i(390, 844)
	root.title = "Identity screen — pick country / city / look, re-roll the name"
	var scene = load("res://scenes/player_creation/identity.tscn").instantiate()
	root.add_child(scene)
