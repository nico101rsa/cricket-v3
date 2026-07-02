extends SceneTree

# Dev preview for the Pre-Match screen (nav-shell spec 2026-07-03, Slice 1):
# renders the versus moment with real SeasonView data. Run WITH rendering:
#   /Applications/Godot.app/Contents/MacOS/Godot --path . -s tools/preview_pre_match.gd
# Output: docs/mockups/pre-match-v1.png (league) + pre-match-semi-v1.png
# (STAGE=semi env renders the playoff variant).

var _frames := 0
var _out := "pre-match-v1.png"

func _initialize() -> void:
	var v := SeasonView.new()
	v.team_name = "Cape Gulls"
	v.team_stars = 2.5
	v.tour_name = "Club Flat & Warm"
	v.country = Country.Code.SA
	v.player_name = "K. Mthembu"
	v.power = 40.0
	v.composure = 35.0
	v.attack = 30.0
	v.control = 20.0
	v.affinity = 3
	v.jokers = [
		{"id": "review_master", "name": "Review Master", "rarity": "common"},
		{"id": "snicko", "name": "Snicko", "rarity": "rare"},
	]
	var opp := {"name": "Karoo Kings", "team_index": 3}
	var match_no := 4
	if OS.get_environment("STAGE") == "semi":
		opp["stage"] = "semi"
		_out = "pre-match-semi-v1.png"
	root.size = Vector2i(390, 844)
	var screen = load("res://scenes/pre_match/pre_match.tscn").instantiate()
	root.add_child(screen)
	screen.set_matchup(v, opp, 3.5, match_no)

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames >= 8:
		var img := root.get_texture().get_image()
		img.save_png(ProjectSettings.globalize_path("res://docs/mockups/" + _out))
		print("SAVED docs/mockups/" + _out)
		return true
	return false
