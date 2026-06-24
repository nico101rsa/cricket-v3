extends SceneTree

# Dev preview for the live-career-advance Outcome screen (spec 2026-06-24). Renders
# the four transition states so Nico can eyeball the re-skin + the new banner / next-up:
#   1. cleared  — beat a mid tour, climb continues   (white banner)
#   2. promoted — beat the readiness tour, crossed up (gold banner)
#   3. champion — won the Province Premier, complete  (gold banner → Hall of Fame)
#   4. missed   — finished outside the top 3, retry   (dim banner)
# Run WITH rendering (not --headless):
#   /Applications/Godot.app/Contents/MacOS/Godot --path . -s tools/preview_outcome.gd
# Output: docs/mockups/outcome-{cleared,promoted,champion,missed}-v1.png

const OutcomeScene = preload("res://scenes/outcome/outcome.tscn")

var _frames := 0
var _stage := 0
var _outcome
var _states: Array = []

func _initialize() -> void:
	root.size = Vector2i(390, 844)
	_states = [
		{"name": "cleared", "pos": 2, "pay": 318, "wins": 5,
			"t": {"beat": true, "promoted": false, "from_level": 0, "tour": 3,
				"to_level": 0, "complete": false, "next_level": 0, "next_tour": 4}},
		{"name": "promoted", "pos": 1, "pay": 506, "wins": 8,
			"t": {"beat": true, "promoted": true, "from_level": 0, "tour": 6,
				"to_level": 1, "complete": false, "next_level": 1, "next_tour": 0}},
		{"name": "champion", "pos": 1, "pay": 940, "wins": 9,
			"t": {"beat": true, "promoted": false, "from_level": 2, "tour": 7,
				"to_level": 2, "complete": true, "next_level": 2, "next_tour": 7}},
		{"name": "missed", "pos": 6, "pay": 188, "wins": 3,
			"t": {"beat": false, "promoted": false, "from_level": 1, "tour": 2,
				"to_level": 1, "complete": false, "next_level": 1, "next_tour": 2}},
	]
	_mount(0)

func _mount(i: int) -> void:
	var st: Dictionary = _states[i]
	_outcome = OutcomeScene.instantiate()
	root.add_child(_outcome)
	var sr := SeasonResult.new()
	sr.player_final_position = st["pos"]
	sr.beat = st["pos"] <= 3
	sr.won_final = st["pos"] == 1
	_outcome.set_outcome(sr, st["pay"], st["wins"], null, st["t"])

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames >= 6:
		var st: Dictionary = _states[_stage]
		var path := "res://docs/mockups/outcome-%s-v1.png" % st["name"]
		var img := root.get_viewport().get_texture().get_image()
		img.save_png(path)
		print("SAVED ", path)
		_outcome.queue_free()
		_stage += 1
		_frames = 0
		if _stage >= _states.size():
			print("PREVIEW_SAVED")
			return true
		# Mount the next state on the following frame (after the freed one clears).
		call_deferred("_mount", _stage)
	return false
