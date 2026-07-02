extends SceneTree

# Dev preview for the Result screen (nav-shell spec 2026-07-03, Slice 2):
# renders the post-match payoff with representative data. Run WITH rendering:
#   /Applications/Godot.app/Contents/MacOS/Godot --path . -s tools/preview_result.gd
# Output: docs/mockups/result-v1.png (league win) + result-final-v1.png
# (VARIANT=final env renders the champion celebration).

var _frames := 0
var _out := "result-v1.png"

func _initialize() -> void:
	var bat := InningsResult.new(174, 6, 120, [], [
		{"is_player": true, "runs": 68, "balls": 41, "out": false}])
	var bowl := InningsResult.new(151, 8, 120, [], [], 1, 19, 24)
	var mr := MatchResult.new()
	mr.innings1 = bat
	mr.innings2 = bowl
	mr.player_bats_first = true
	mr.outcome = MatchResult.Outcome.PLAYER_WIN
	mr.margin_runs = 23
	var stage := ""
	var match_no := 4
	var dest := "KIT ROOM"
	var champion := {}
	if OS.get_environment("VARIANT") == "final":
		stage = "final"
		dest = "SEASON END"
		champion = {"level_word": "Club", "tour_name": "Club Premier"}
		_out = "result-final-v1.png"
	root.size = Vector2i(390, 844)
	var screen = load("res://scenes/result/result.tscn").instantiate()
	root.add_child(screen)
	screen.set_result(mr, "Cape Gulls", "Karoo Kings", match_no, stage,
		{"base": 50, "perf": 18, "prize": 55, "total": 123}, 1308, dest, champion)

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames >= 8:
		var img := root.get_texture().get_image()
		img.save_png(ProjectSettings.globalize_path("res://docs/mockups/" + _out))
		print("SAVED docs/mockups/" + _out)
		return true
	return false
