extends SceneTree

# Repro harness: load the REAL main.tscn (which boots the saved player's hub),
# at a window size to reproduce Nico's clipping report. Renders, screenshots, quits.
#   /Applications/Godot.app/Contents/MacOS/Godot --path . -s tools/repro_main_hub.gd
# Output: /tmp/repro_hub_<W>x<H>.png for a couple of sizes.

var _main
var _frames := 0
var _shots := [Vector2i(390, 844), Vector2i(480, 900), Vector2i(640, 940)]
var _i := 0

func _initialize() -> void:
	root.size = _shots[0]
	_main = load("res://scenes/main.tscn").instantiate()
	root.add_child(_main)

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames % 6 == 0:
		var size: Vector2i = _shots[_i]
		var img := root.get_viewport().get_texture().get_image()
		img.save_png("/tmp/repro_hub_%dx%d.png" % [size.x, size.y])
		print("SHOT %dx%d" % [size.x, size.y])
		_i += 1
		if _i >= _shots.size():
			return true
		root.size = _shots[_i]
	return false
